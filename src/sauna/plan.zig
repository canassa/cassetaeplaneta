//! Dev tool, not part of the game: plans a SAUNA arcade win as an input script
//! (`zig build sauna-plan -- --start MS [--beam N] [--depth N] [--danger N] [--bonus N] [--min-eaten N]`, driven by
//! `tools/sauna_plan.py --arcade`).
//!
//! The game is deterministic: the sim has no randomness but the frightened ghosts' generator, which
//! restarts from a fixed seed, and the planner runs the very `driver.Driver` the game does, tick by
//! tick (a tick every 16 ms from the start `--start`, where the controls screen came down), so a
//! planned key press lands where the plan has it. It searches by beam: at each tile Pacman enters it
//! tries going on, and each other open way (a press of that arrow, which the driver keeps wanted for
//! 400 ms after its release), runs on to the next tile, ranks the nodes by dots eaten (and ghosts
//! eaten), less time and less nearness of a ghost, and keeps the best `--beam`. Output: the script's
//! lines on stdout (times in ms from 0 = `--start`, shifted by it), then `# result`.

const std = @import("std");
const sim = @import("arcade/sim.zig");
const maze = @import("arcade/maze.zig");
const driver = @import("arcade/driver.zig");
const game = @import("core/maze_data.zig");
const Dir = sim.Dir;

const tick_ms = 16;
/// A key press is made this long before a tick (between two ticks).
const press_lead = 8;
const key_ms = 50;

const Key = struct { tick: u32, dir: Dir };

const Fx = struct {
    left: *const u16,
    dots: u32 = 0,
    eaten: u32 = 0,
    caught: bool = false,

    pub fn dot(f: *Fx, _: sim.DotEvent) bool {
        f.dots += 1;
        return f.left.* != 0;
    }
    pub fn frightEnded(_: *Fx) void {}
    pub fn caughtFn(f: *Fx) bool {
        f.caught = true;
        return false;
    }
    pub fn ghostEaten(f: *Fx) void {
        f.eaten += 1;
    }
};

/// The driver's effects (`caught` is a name clash with the field).
const Effects = struct {
    f: *Fx,
    pub fn dot(e: Effects, d: sim.DotEvent) bool {
        return e.f.dot(d);
    }
    pub fn frightEnded(e: Effects) void {
        e.f.frightEnded();
    }
    pub fn caught(e: Effects) bool {
        return e.f.caughtFn();
    }
    pub fn ghostEaten(e: Effects) void {
        e.f.ghostEaten();
    }
};

const Node = struct {
    drv: driver.Driver,
    /// Ticks done.
    k: u32 = 0,
    dots: u32 = 0,
    eaten: u32 = 0,
    won: bool = false,
    /// The release of the last press: (tick boundary, direction).
    release_at: ?u32 = null,
    release_dir: Dir = .up,
    hist: u32 = 0,
    rank: i64 = 0,
};

const Hist = struct { parent: u32, key: ?Key };

fn tileOfPac(d: *const driver.Driver) maze.Tile {
    return .{ .a = sim.tileOf(d.sim.pac.x), .b = sim.tileOf(d.sim.pac.y) };
}

/// One tick of the game at 16 ms steps from 0, with the pending release applied first.
fn stepTick(n: *Node, fx: *Fx) void {
    const now: u32 = (n.k + 1) * tick_ms;
    if (n.release_at) |r| if (r <= now) {
        n.drv.release(n.release_dir, r);
        n.release_at = null;
    };
    const e: Effects = .{ .f = fx };
    n.drv.tick(now, e);
    n.k += 1;
}

/// Steps along the maze from Pacman's tile to the nearest dot left (a breadth-first search).
fn nearestDot(tiles: *const maze.Tiles, n: *const Node) i64 {
    var dist: [maze.h][maze.w]i16 = undefined;
    for (&dist) |*row| row.* = @splat(-1);
    var queue: [maze.h * maze.w]maze.Tile = undefined;
    var qh: usize = 0;
    var qt: usize = 0;
    const p = tileOfPac(&n.drv);
    if (p.a < 0 or p.b < 0 or p.a >= maze.w or p.b >= maze.h) return 0;
    dist[@intCast(p.b)][@intCast(p.a)] = 0;
    queue[qt] = p;
    qt += 1;
    while (qh < qt) {
        const t = queue[qh];
        qh += 1;
        const d = dist[@intCast(t.b)][@intCast(t.a)];
        if (n.drv.sim.dots[@intCast(t.b)][@intCast(t.a)] != 0) return d;
        for (sim.all_dirs) |dir| {
            const na = t.a + dir.dx();
            const nb = t.b + dir.dy();
            if (!tiles.isFloor(na, nb)) continue;
            if (dist[@intCast(nb)][@intCast(na)] >= 0) continue;
            dist[@intCast(nb)][@intCast(na)] = d + 1;
            queue[qt] = .{ .a = na, .b = nb };
            qt += 1;
        }
    }
    return 0;
}

/// Ranks a node: dots first, then ghosts eaten, then speed and the way to the next dot; and a
/// ghost that is near is bad.
fn rank(tiles: *const maze.Tiles, n: *const Node, bonus: i64, danger: i64) i64 {
    var r: i64 = @as(i64, n.dots) * 1000 + @as(i64, n.eaten) * bonus - @as(i64, n.k) - nearestDot(tiles, n) * 6;
    const p = tileOfPac(&n.drv);
    for (n.drv.sim.ghosts) |g| {
        if (g.mode != .outside or g.scared) continue;
        const d = @abs(sim.tileOf(g.x) - p.a) + @abs(sim.tileOf(g.y) - p.b);
        if (d < 6) r -= @as(i64, 6 - d) * danger;
    }
    return r;
}

fn lessThan(_: void, a: Node, b: Node) bool {
    return a.rank > b.rank;
}

/// What one option did: the node after it (at the next tile, or at a pause, or the end).
const Step = struct { node: Node, key: ?Key, caught: bool };

fn options(tiles: *const maze.Tiles, n: *const Node, buf: *[5]?Dir) []?Dir {
    const here = tileOfPac(&n.drv);
    const cur = n.drv.sim.pac.dir;
    var no: usize = 0;
    // Keep on (no key) when the way ahead is open, else each open way.
    if (tiles.isFloor(here.a + cur.dx(), here.b + cur.dy())) {
        buf[no] = null;
        no += 1;
    }
    for (sim.all_dirs) |d| {
        if (d == cur) continue;
        if (!tiles.isFloor(here.a + d.dx(), here.b + d.dy())) continue;
        buf[no] = d;
        no += 1;
    }
    return buf[0..no];
}

/// Takes option `opt` at node `n`'s tile and runs on to the next tile.
fn advance(n: *const Node, opt: ?Dir) Step {
    const here = tileOfPac(&n.drv);
    var c = n.*;
    var fx: Fx = .{ .left = &c.drv.sim.dots_left };
    var key: ?Key = null;
    if (opt) |d| {
        // Pressed between this tick and the next, released 50 ms later.
        c.drv.press(d);
        c.release_at = c.k * tick_ms + press_lead + key_ms;
        c.release_dir = d;
        key = .{ .tick = c.k, .dir = d };
    }
    var guard: u32 = 0;
    while (guard < 90) : (guard += 1) {
        stepTick(&c, &fx);
        if (fx.caught or c.drv.phase == .over) break;
        if (c.drv.phase == .play) {
            const t = tileOfPac(&c.drv);
            if (t.a != here.a or t.b != here.b) break;
        }
    }
    c.dots = n.dots + fx.dots;
    c.eaten = n.eaten + fx.eaten;
    if (c.drv.phase == .over and !fx.caught) c.won = true;
    return .{ .node = c, .key = key, .caught = fx.caught or (c.drv.phase != .play and !c.won) };
}

/// Some way of going on for `depth` more tiles in which Pacman is not caught.
fn survives(tiles: *const maze.Tiles, n: *const Node, depth: u32) bool {
    if (depth == 0 or n.won) return true;
    var buf: [5]?Dir = undefined;
    for (options(tiles, n, &buf)) |opt| {
        const st = advance(n, opt);
        if (st.caught) continue;
        if (survives(tiles, &st.node, depth - 1)) return true;
    }
    return false;
}

pub fn main(init: std.process.Init) !void {
    const gpa = init.gpa;
    var start: u32 = 1100;
    var beam: usize = 400;
    var bonus: i64 = 0;
    var danger: i64 = 120;
    var depth: u32 = 6;
    var min_eaten: u32 = 0;
    var it = init.minimal.args.iterate();
    _ = it.next();
    while (it.next()) |a| {
        if (std.mem.eql(u8, a, "--start")) {
            start = try std.fmt.parseInt(u32, it.next() orelse return error.MissingValue, 10);
        } else if (std.mem.eql(u8, a, "--beam")) {
            beam = try std.fmt.parseInt(usize, it.next() orelse return error.MissingValue, 10);
        } else if (std.mem.eql(u8, a, "--danger")) {
            danger = try std.fmt.parseInt(i64, it.next() orelse return error.MissingValue, 10);
        } else if (std.mem.eql(u8, a, "--depth")) {
            depth = try std.fmt.parseInt(u32, it.next() orelse return error.MissingValue, 10);
        } else if (std.mem.eql(u8, a, "--min-eaten")) {
            min_eaten = try std.fmt.parseInt(u32, it.next() orelse return error.MissingValue, 10);
        } else if (std.mem.eql(u8, a, "--bonus")) {
            bonus = try std.fmt.parseInt(i64, it.next() orelse return error.MissingValue, 10);
        } else return error.BadArgument;
    }

    // The game's maze as it is when the game starts: the dot under Pacman's start is eaten.
    var m = game.initial_maze;
    m[maze.pac_start.b - 1][maze.pac_start.a - 1] = ' ';
    const tiles = maze.Tiles.build(&m);

    var hist: std.ArrayList(Hist) = .empty;
    defer hist.deinit(gpa);
    try hist.append(gpa, .{ .parent = 0, .key = null });

    var frontier: std.ArrayList(Node) = .empty;
    defer frontier.deinit(gpa);
    var next: std.ArrayList(Node) = .empty;
    defer next.deinit(gpa);
    var keyed: std.ArrayList(Key) = .empty;
    defer keyed.deinit(gpa);

    var root: Node = .{ .drv = driver.Driver.init(&tiles, tiles.dot_count) };
    root.drv.start(0);
    // Through the READY beat.
    var fx0: Fx = .{ .left = &root.drv.sim.dots_left };
    while (root.drv.phase != .play) stepTick(&root, &fx0);
    try frontier.append(gpa, root);

    // The candidates of a layer remember how they came.
    const Cand = struct { node: Node, parent: u32, key: ?Key };
    var cands: std.ArrayList(Cand) = .empty;
    defer cands.deinit(gpa);

    var best: ?Node = null;
    var layer: u32 = 0;
    var max_dots: u32 = 0;
    while (frontier.items.len > 0 and layer < 4000) : (layer += 1) {
        cands.clearRetainingCapacity();
        for (frontier.items) |*n| {
            var buf: [5]?Dir = undefined;
            for (options(&tiles, n, &buf)) |opt| {
                const st = advance(n, opt);
                if (st.caught) continue;
                var c = st.node;
                if (c.won and c.eaten < min_eaten) continue;
                if (c.won) {
                    c.hist = @intCast(hist.items.len);
                    try hist.append(gpa, .{ .parent = n.hist, .key = st.key });
                    if (best == null or c.k < best.?.k) best = c;
                    continue;
                }
                c.rank = rank(&tiles, &c, bonus, danger);
                try cands.append(gpa, .{ .node = c, .parent = n.hist, .key = st.key });
            }
        }
        if (best != null) break;
        std.mem.sort(Cand, cands.items, {}, struct {
            fn lt(_: void, a: Cand, b: Cand) bool {
                return a.node.rank > b.node.rank;
            }
        }.lt);
        next.clearRetainingCapacity();
        for (cands.items) |cd| {
            if (next.items.len >= beam) break;
            if (!survives(&tiles, &cd.node, depth)) continue;
            var c = cd.node;
            c.hist = @intCast(hist.items.len);
            try hist.append(gpa, .{ .parent = cd.parent, .key = cd.key });
            max_dots = @max(max_dots, c.dots);
            try next.append(gpa, c);
        }
        std.mem.swap(std.ArrayList(Node), &frontier, &next);
    }

    var buf: [1 << 14]u8 = undefined;
    var fw = std.Io.File.stdout().writer(init.io, &buf);
    const w = &fw.interface;
    const win = best orelse {
        try w.print("# no win found in {d} layers (frontier {d}), most dots {d}\n", .{ layer, frontier.items.len, max_dots });
        try w.flush();
        return error.NoWin;
    };
    // The keys, root to leaf.
    var keys: std.ArrayList(Key) = .empty;
    defer keys.deinit(gpa);
    var h = win.hist;
    while (h != 0) : (h = hist.items[h].parent) {
        if (hist.items[h].key) |k| try keys.append(gpa, k);
    }
    std.mem.reverse(Key, keys.items);
    try w.print("# plan: {d} keys, the last dot at {d} ms after the start, {d} ghosts eaten\n", .{ keys.items.len, win.k * tick_ms, win.eaten });
    for (keys.items) |k| {
        try w.print("{d} key {s}\n", .{ start + k.tick * tick_ms + press_lead, @tagName(k.dir) });
    }
    // 96 peanuts, +100 for the dot under his start, 500 a ghost; +1000 for the win.
    try w.print("# result won {d}\n", .{@as(i64, 9600) + 1000 + @as(i64, win.eaten) * 500});
    try w.print("# end {d}\n", .{start + win.k * tick_ms});
    try w.flush();
}
