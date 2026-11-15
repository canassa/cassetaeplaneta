//! Not in the original (`Fixes.sauna_arcade_rules`): the arcade game's rules, as a pure simulation.
//!
//! Level 1 of Pac-Man (docs/sauna/PACMAN.md) on SAUNA's tile grid (`maze.zig`). It runs in the
//! arcade's own units: 60 frames a second, a tile of 8 "arcade pixels" (one arcade pixel is 2 screen
//! pixels; tile (a, b) has its centre at (8 a, 8 b) and holds the pixels 8 a - 3 .. 8 a + 4), the
//! speed-control table of 16 frames, two sub-steps a frame. So the arcade's timings and windows
//! (cornering: 3 pixels before the centre and 4 after, entering from the left) hold, scaled by two
//! on the screen. The tile of an actor is the one that holds its centre.
//!
//! No Game, no platform: `Sim.frame` takes the wanted direction and returns the events
//! (dots eaten, ghosts eaten, Pacman caught); `glue.zig` makes the game of them. The state is
//! copyable, so a planner can look ahead.

const std = @import("std");
const maze = @import("maze.zig");

/// Directions in the order the arcade breaks ties: up, left, down, right.
pub const Dir = enum(u2) {
    up,
    left,
    down,
    right,

    pub fn dx(d: Dir) i32 {
        return switch (d) {
            .left => -1,
            .right => 1,
            else => 0,
        };
    }
    pub fn dy(d: Dir) i32 {
        return switch (d) {
            .up => -1,
            .down => 1,
            else => 0,
        };
    }
    pub fn opposite(d: Dir) Dir {
        return @fromBackingInt(@intCast(@backingInt(d) +% 2));
    }
    pub fn horizontal(d: Dir) bool {
        return d == .left or d == .right;
    }
};

pub const all_dirs = [4]Dir{ .up, .left, .down, .right };

pub const frames_per_second = 60;
/// Arcade pixels in a tile.
pub const tile_px = 8;

/// Which tile holds the arcade pixel coordinate `p` (3 pixels before the centre, 4 after).
pub fn tileOf(p: i32) i32 {
    return @divFloor(p + 3, tile_px);
}

/// `p`'s distance to the centre of its tile (positive: the centre is ahead in the positive direction).
pub fn distToMid(p: i32) i32 {
    return tile_px * tileOf(p) - p;
}

// ---- level 1's speed-control table (docs/sauna/PACMAN.md): steps on each of 16 frames ----

const pac_normal = "1111111111111111";
const pac_fright = "1111211111112111";
const ghost_normal = "0111111111111111";
const ghost_fright = "0110110101101101";
const ghost_house = "0101010101010101"; // the tunnel's: also leaving and pacing in the house
const ghost_elroy1 = "1111111111111111";
const ghost_elroy2 = "1111111121111111";

fn steps(table: *const [16]u8, frames: u32) u32 {
    return table[frames % 16] - '0';
}

// ---- the places ----

/// Where the ghosts start and the house's geometry, in arcade pixels.
const door_x = 8 * maze.door.a;
const door_exit_y = 8 * (maze.door.b - 1); // the tile above the door: where a ghost comes out
const home_top_y = 120;
const home_bottom_y = 128;
const pen_y = 124;

pub const Kind = enum(u2) { blinky, pinky, inky, clyde };

/// The scatter corners: tiles outside the maze beyond each corner, as the arcade's.
pub const corner = [4]maze.Tile{
    .{ .a = 37, .b = -2 }, // Blinky: top right
    .{ .a = 3, .b = -2 }, // Pinky: top left
    .{ .a = 39, .b = 30 }, // Inky: bottom right
    .{ .a = 1, .b = 30 }, // Clyde: bottom left
};

/// The arcade's overflow bug: facing up, Pinky's and Inky's targets are also that many tiles to the left.
pub const up_overflow = true;

// ---- level 1's schedule and counters, scaled from the arcade's 244 dots to SAUNA's 100 ----

pub const Cmd = enum { scatter, chase };

/// Frames at which the command changes (7, 20, 7, 20, 5, 20, 5 seconds): to chase, scatter, ...
const wave_frames = [7]u32{ 7 * 60, 27 * 60, 34 * 60, 54 * 60, 59 * 60, 79 * 60, 84 * 60 };

/// Frightened time (6 s) and its flashes (5: ten intervals of 14 frames at the end).
pub const fright_frames = 6 * 60;
pub const flashes = 5;
const flash_interval = 14;

/// Personal dot limits for Inky and Clyde (arcade 30, 60 of 244), the global counter's for Pinky,
/// Inky, Clyde (7, 17, 32), Cruise Elroy's (20, 10 left): the arcade's numbers times 100 / 244.
const personal_limit = [4]u32{ 0, 0, 12, 25 };
const global_limit = [4]u32{ 0, 3, 7, 13 };
const elroy1_left = 8;
const elroy2_left = 4;
/// Pac-Man eating nothing for this long releases the next ghost.
const release_timeout = 4 * 60;

// ---- state ----

pub const Mode = enum { outside, pacing, leaving };

pub const Pac = struct {
    x: i32 = 0,
    y: i32 = 0,
    /// The position at the previous frame (the picture is drawn between the two).
    px: i32 = 0,
    py: i32 = 0,
    dir: Dir = .left,
    stopped: bool = false,
    /// Frames still to stand after a dot (1) or a cork (3).
    pause: u32 = 0,
    /// Steps taken: the mouth opens and closes with them.
    steps: u32 = 0,
    frames: u32 = 0,
};

pub const Ghost = struct {
    kind: Kind,
    x: i32 = 0,
    y: i32 = 0,
    px: i32 = 0,
    py: i32 = 0,
    /// The direction it moves, and the one it has decided to take at the next tile centre.
    dir: Dir = .left,
    face: Dir = .left,
    mode: Mode = .outside,
    scared: bool = false,
    sig_reverse: bool = false,
    sig_leave: bool = false,
    /// Blinky's Cruise Elroy stage (0, 1, 2).
    elroy: u2 = 0,
    frames: u32 = 0,
    /// The tile it aims for (for the debug picture).
    target: maze.Tile = .{ .a = 0, .b = 0 },
};

pub const DotEvent = struct { a: i32, b: i32, cork: bool };

/// What one frame did.
pub const Events = struct {
    dots: [4]DotEvent = undefined,
    dot_count: u8 = 0,
    eaten: [4]bool = @splat(false),
    caught: bool = false,
    /// The corks' time ran out this frame.
    fright_ended: bool = false,
    /// A cork was eaten this frame.
    fright_started: bool = false,

    pub fn anyEaten(e: Events) bool {
        for (e.eaten) |x| if (x) return true;
        return false;
    }
};

pub const Sim = struct {
    tiles: *const maze.Tiles,
    /// The dots still there (`tiles.dots` as it was at the start, then eaten).
    dots: [maze.h][maze.w]u8,
    dots_left: u16,
    pac: Pac = .{},
    ghosts: [4]Ghost = undefined,
    cmd: Cmd = .scatter,
    cmd_frame: u32 = 0,
    /// Frames the corks have been on, if they are.
    fright_on: bool = false,
    fright_count: u32 = 0,
    /// The ghost release: personal counters, or the global one after a death.
    global_mode: bool = false,
    personal: [4]u32 = @splat(0),
    global: u32 = 0,
    since_dot: u32 = 0,
    /// After a death Blinky is no Elroy until Clyde leaves the house.
    elroy_wait_clyde: bool = false,
    rng: u32 = rng_seed,
    frame_no: u32 = 0,

    const rng_seed: u32 = 0x2f6e2b1;

    pub fn init(tiles: *const maze.Tiles, dots_left: u16) Sim {
        var s: Sim = .{ .tiles = tiles, .dots = tiles.dots, .dots_left = dots_left };
        s.restart();
        s.elroy_wait_clyde = false;
        s.global_mode = false;
        return s;
    }

    /// Everything back to its start (a new game, or a death): the dots stay as they are.
    pub fn restart(s: *Sim) void {
        s.pac = .{
            .x = 8 * maze.pac_start.a,
            .y = 8 * maze.pac_start.b,
            .dir = .left,
        };
        s.pac.px = s.pac.x;
        s.pac.py = s.pac.y;
        const home = [4]struct { x: i32, y: i32, mode: Mode, dir: Dir }{
            .{ .x = door_x, .y = door_exit_y, .mode = .outside, .dir = .left },
            .{ .x = door_x, .y = pen_y, .mode = .pacing, .dir = .down },
            .{ .x = door_x - 16, .y = pen_y, .mode = .pacing, .dir = .up },
            .{ .x = door_x + 16, .y = pen_y, .mode = .pacing, .dir = .up },
        };
        for (&s.ghosts, home, 0..) |*g, hm, i| {
            g.* = .{ .kind = @fromBackingInt(@intCast(i)), .x = hm.x, .y = hm.y, .px = hm.x, .py = hm.y, .dir = hm.dir, .face = hm.dir, .mode = hm.mode };
        }
        s.cmd = .scatter;
        s.cmd_frame = 0;
        s.fright_on = false;
        s.fright_count = 0;
        s.personal = @splat(0);
        s.global = 0;
        s.global_mode = true;
        s.since_dot = 0;
        s.elroy_wait_clyde = true;
        s.rng = rng_seed;
        s.frame_no = 0;
    }

    fn tilePac(s: *const Sim) maze.Tile {
        return .{ .a = tileOf(s.pac.x), .b = tileOf(s.pac.y) };
    }

    fn tileGhost(g: *const Ghost) maze.Tile {
        return .{ .a = tileOf(g.x), .b = tileOf(g.y) };
    }

    fn isFloor(s: *const Sim, a: i32, b: i32) bool {
        return s.tiles.isFloor(a, b);
    }

    /// Pacman's speed now.
    fn pacSteps(s: *const Sim) u32 {
        return steps(if (s.fright_on) pac_fright else pac_normal, s.pac.frames);
    }

    fn ghostSteps(s: *const Sim, g: *const Ghost) u32 {
        if (g.mode != .outside) return steps(ghost_house, g.frames);
        if (g.scared) return steps(ghost_fright, g.frames);
        _ = s;
        return switch (g.elroy) {
            1 => steps(ghost_elroy1, g.frames),
            2 => steps(ghost_elroy2, g.frames),
            0 => steps(ghost_normal, g.frames),
            3 => unreachable,
        };
    }

    /// One frame (a sixtieth of a second) with `want` held on the joystick (null: centred).
    pub fn frame(s: *Sim, want: ?Dir, ev: *Events) void {
        ev.* = .{};
        s.pac.px = s.pac.x;
        s.pac.py = s.pac.y;
        for (&s.ghosts) |*g| {
            g.px = g.x;
            g.py = g.y;
        }
        for (0..2) |j| {
            s.updatePac(@intCast(j), want, ev);
            for (&s.ghosts) |*g| s.updateGhost(g, @intCast(j));
            s.collide(ev);
            if (ev.caught) return;
        }
        s.updateCommander();
        s.updateReleaser();
        s.updateElroy();
        s.updateFright(ev);
        s.pac.frames +%= 1;
        for (&s.ghosts) |*g| g.frames +%= 1;
        s.frame_no +%= 1;
    }

    // ---- Pac-Man ----

    fn updatePac(s: *Sim, j: u32, want: ?Dir, ev: *Events) void {
        const n = s.pacSteps();
        if (j >= n) return;
        const p = &s.pac;
        if (p.pause > 0) {
            if (j == n - 1) p.pause -= 1;
            return;
        }
        // Step: stop at the centre of a tile when the one ahead is wall; else one pixel ahead and
        // one toward the centre line of the lane (the arcade's cut of a corner).
        const t = s.tilePac();
        const dm_a = if (p.dir.horizontal()) distToMid(p.x) else distToMid(p.y);
        if (dm_a == 0 and !s.isFloor(t.a + p.dir.dx(), t.b + p.dir.dy())) p.stopped = true;
        if (!p.stopped) {
            if (p.dir.horizontal()) {
                p.x += p.dir.dx();
                p.y += std.math.sign(distToMid(p.y));
            } else {
                p.y += p.dir.dy();
                p.x += std.math.sign(distToMid(p.x));
            }
            p.steps +%= 1;
        }
        // Steer: a wanted direction that is open from this tile is taken at once, before or after
        // the centre (the pre-turn and post-turn).
        if (want) |wd| {
            const t2 = s.tilePac();
            if (s.isFloor(t2.a + wd.dx(), t2.b + wd.dy())) {
                p.dir = wd;
                p.stopped = false;
            }
        }
        // Eat.
        const t3 = s.tilePac();
        if (t3.a >= 0 and t3.b >= 0 and t3.a < maze.w and t3.b < maze.h) {
            const cell = &s.dots[@intCast(t3.b)][@intCast(t3.a)];
            if (cell.* != 0) {
                const cork = cell.* == 2;
                cell.* = 0;
                s.dots_left -= 1;
                p.pause = if (cork) 3 else 1;
                if (ev.dot_count < ev.dots.len) {
                    ev.dots[ev.dot_count] = .{ .a = t3.a, .b = t3.b, .cork = cork };
                    ev.dot_count += 1;
                }
                s.onDotEaten();
                if (cork) s.energize(ev);
            }
        }
    }

    // ---- the ghosts ----

    fn updateGhost(s: *Sim, g: *Ghost, j: u32) void {
        if (j >= s.ghostSteps(g)) return;
        g.x += g.dir.dx();
        g.y += g.dir.dy();
        s.steerGhost(g);
    }

    /// The four neighbours of tile (a, b) that are floor (for the ghost heading `dir`, never the
    /// one behind it unless it is the only way out).
    fn openTiles(s: *const Sim, a: i32, b: i32, dir: Dir) [4]bool {
        var open: [4]bool = undefined;
        var n: u32 = 0;
        for (all_dirs, 0..) |d, i| {
            open[i] = s.isFloor(a + d.dx(), b + d.dy());
            if (open[i]) n += 1;
        }
        if (n > 1) open[@backingInt(dir.opposite())] = false;
        return open;
    }

    /// The open direction whose tile is nearest the target (ties: the first, up, left, down, right).
    fn nearest(a: i32, b: i32, target: maze.Tile, open: [4]bool, fallback: Dir) Dir {
        var best: ?Dir = null;
        var best_d: i64 = std.math.maxInt(i64);
        for (all_dirs, 0..) |d, i| {
            if (!open[i]) continue;
            const dxx: i64 = a + d.dx() - target.a;
            const dyy: i64 = b + d.dy() - target.b;
            const dist = dxx * dxx + dyy * dyy;
            if (dist < best_d) {
                best_d = dist;
                best = d;
            }
        }
        return best orelse fallback;
    }

    fn random(s: *Sim) u32 {
        s.rng = s.rng *% 1664525 +% 1013904223;
        return s.rng >> 16;
    }

    /// The tile a ghost aims for now.
    pub fn targetOf(s: *const Sim, g: *const Ghost) maze.Tile {
        if (g.elroy == 0 and s.cmd == .scatter) return corner[@backingInt(g.kind)];
        const pt = s.tilePac();
        const d = s.pac.dir;
        const left_extra: i32 = if (up_overflow and d == .up) 1 else 0;
        switch (g.kind) {
            .blinky => return pt,
            .pinky => return .{
                .a = pt.a + 4 * d.dx() - 4 * left_extra,
                .b = pt.b + 4 * d.dy(),
            },
            .inky => {
                const pivot_a = pt.a + 2 * d.dx() - 2 * left_extra;
                const pivot_b = pt.b + 2 * d.dy();
                const bl = tileGhost(&s.ghosts[0]);
                return .{ .a = bl.a + 2 * (pivot_a - bl.a), .b = bl.b + 2 * (pivot_b - bl.b) };
            },
            .clyde => {
                const gt = tileGhost(g);
                const dxx = pt.a - gt.a;
                const dyy = pt.b - gt.b;
                if (dxx * dxx + dyy * dyy >= 64) return pt;
                return corner[@backingInt(g.kind)];
            },
        }
    }

    fn steerGhost(s: *Sim, g: *Ghost) void {
        s.homeSteer(g);
        if (g.mode != .outside) return;
        const t = tileGhost(g);
        const dmx = distToMid(g.x);
        const dmy = distToMid(g.y);
        if (dmx == 0 and dmy == 0) {
            // At the centre of a tile: a reversal is taken, then the direction decided at the previous tile.
            if (g.sig_reverse) {
                g.face = g.dir.opposite();
                g.sig_reverse = false;
            }
            g.dir = g.face;
        } else if ((g.dir == .right and dmx == -1) or (g.dir == .left and dmx == 1) or
            (g.dir == .up and dmy == 1) or (g.dir == .down and dmy == -1))
        {
            // One pixel past the centre: decide the exit from the next tile.
            const na = t.a + g.dir.dx();
            const nb = t.b + g.dir.dy();
            const open = s.openTiles(na, nb, g.dir);
            if (g.scared) {
                var d: u32 = s.random() % 4;
                var guard: u32 = 0;
                while (!open[d] and guard < 4) : (guard += 1) d = (d + 1) % 4;
                g.face = if (open[d]) all_dirs[d] else g.dir;
            } else {
                g.target = s.targetOf(g);
                g.face = nearest(na, nb, g.target, open, g.dir);
            }
        }
    }

    /// Bobbing in the house, and the way out: sideways to the door's column, up to the tile above it.
    fn homeSteer(s: *Sim, g: *Ghost) void {
        _ = s;
        switch (g.mode) {
            .pacing => {
                if (g.sig_leave) {
                    g.sig_leave = false;
                    g.mode = .leaving;
                    g.dir = if (g.x == door_x) .up else if (g.x < door_x) .right else .left;
                } else if (g.y <= home_top_y) {
                    g.dir = .down;
                } else if (g.y >= home_bottom_y) {
                    g.dir = .up;
                }
                g.face = g.dir;
            },
            .leaving => {
                if (g.x == door_x) {
                    if (g.y <= door_exit_y) {
                        g.mode = .outside;
                        g.dir = .left;
                    } else {
                        g.dir = .up;
                    }
                    g.face = g.dir;
                }
            },
            .outside => {},
        }
    }

    /// A ghost eaten: back in the house at its place, leaving at once.
    fn sendHome(s: *Sim, g: *Ghost) void {
        _ = s;
        const i = @backingInt(g.kind);
        const x: i32 = switch (g.kind) {
            .blinky, .pinky => door_x,
            .inky => door_x - 16,
            .clyde => door_x + 16,
        };
        _ = i;
        g.x = x;
        g.y = pen_y;
        g.px = g.x;
        g.py = g.y;
        g.mode = .pacing;
        g.dir = .up;
        g.face = .up;
        g.scared = false;
        g.sig_reverse = false;
        g.sig_leave = true;
    }

    fn collide(s: *Sim, ev: *Events) void {
        const pt = s.tilePac();
        var dead = false;
        for (&s.ghosts, 0..) |*g, i| {
            if (g.mode != .outside) continue;
            const gt = tileGhost(g);
            if (gt.a != pt.a or gt.b != pt.b) continue;
            if (g.scared) {
                ev.eaten[i] = true;
                s.sendHome(g);
            } else {
                dead = true;
            }
        }
        if (dead) ev.caught = true;
    }

    // ---- the clocks ----

    fn reverseAll(s: *Sim) void {
        for (&s.ghosts) |*g| if (g.mode == .outside) {
            g.sig_reverse = true;
        };
    }

    fn updateCommander(s: *Sim) void {
        if (s.fright_on) return;
        for (wave_frames, 0..) |f, i| {
            if (s.cmd_frame == f) {
                s.cmd = if (i % 2 == 0) .chase else .scatter;
                s.reverseAll();
            }
        }
        s.cmd_frame +%= 1;
    }

    fn energize(s: *Sim, ev: *Events) void {
        s.fright_on = true;
        s.fright_count = 0;
        ev.fright_started = true;
        s.reverseAll();
        for (&s.ghosts) |*g| g.scared = true;
    }

    fn updateFright(s: *Sim, ev: *Events) void {
        if (!s.fright_on) return;
        if (s.fright_count >= fright_frames) {
            s.fright_on = false;
            s.fright_count = 0;
            ev.fright_ended = true;
            for (&s.ghosts) |*g| g.scared = false;
        } else {
            s.fright_count += 1;
        }
    }

    /// The frightened ghosts flash (show their normal picture) at the end of the corks' time.
    pub fn flashOn(s: *const Sim) bool {
        if (!s.fright_on) return false;
        const i = (fright_frames - s.fright_count) / flash_interval;
        return i <= 2 * flashes - 1 and i % 2 == 0;
    }

    // ---- the house ----

    fn onDotEaten(s: *Sim) void {
        s.since_dot = 0;
        if (s.global_mode) {
            s.global += 1;
        } else {
            for (1..4) |i| {
                if (s.ghosts[i].mode == .pacing) {
                    s.personal[i] += 1;
                    break;
                }
            }
        }
    }

    fn updateReleaser(s: *Sim) void {
        if (!s.global_mode) {
            for (1..4) |i| {
                const g = &s.ghosts[i];
                if (g.mode == .pacing) {
                    if (s.personal[i] >= personal_limit[i]) {
                        g.sig_leave = true;
                        return;
                    }
                    break;
                }
            }
        } else {
            for (1..4) |i| {
                const g = &s.ghosts[i];
                if (s.global == global_limit[i] and g.mode == .pacing) {
                    if (i == 3) {
                        s.global = 0;
                        s.global_mode = false;
                    }
                    g.sig_leave = true;
                    return;
                }
            }
        }
        if (s.since_dot > release_timeout) {
            s.since_dot = 0;
            for (1..4) |i| {
                if (s.ghosts[i].mode == .pacing) {
                    s.ghosts[i].sig_leave = true;
                    break;
                }
            }
        } else {
            s.since_dot += 1;
        }
    }

    fn updateElroy(s: *Sim) void {
        const b = &s.ghosts[0];
        if (s.elroy_wait_clyde and s.ghosts[3].mode != .pacing) s.elroy_wait_clyde = false;
        b.elroy = if (s.elroy_wait_clyde) 0 else if (s.dots_left <= elroy2_left) 2 else if (s.dots_left <= elroy1_left) 1 else 0;
    }

    // ---- what a picture needs ----

    /// Pacman's mouth: shut or open, by the steps he has taken.
    pub fn pacFrame(s: *const Sim) u1 {
        return @truncate(s.pac.steps / 4);
    }
};

// ---- tests ----

const game = @import("../core/maze_data.zig");

fn testSim(tiles: *const maze.Tiles) Sim {
    return Sim.init(tiles, 100);
}

test "tileOf: 3 pixels before the centre, 4 after" {
    try std.testing.expectEqual(@as(i32, 20), tileOf(160));
    try std.testing.expectEqual(@as(i32, 20), tileOf(157));
    try std.testing.expectEqual(@as(i32, 19), tileOf(156));
    try std.testing.expectEqual(@as(i32, 20), tileOf(164));
    try std.testing.expectEqual(@as(i32, 21), tileOf(165));
    try std.testing.expectEqual(@as(i32, 0), distToMid(160 - 8 * 20));
    try std.testing.expectEqual(@as(i32, 3), distToMid(157));
    try std.testing.expectEqual(@as(i32, -4), distToMid(164));
}

test "speeds: Pac-Man 60 px/s, ghosts 56.25, frightened ghosts 37.5, level 1's table" {
    var sum_pac: u32 = 0;
    var sum_ghost: u32 = 0;
    var sum_fright: u32 = 0;
    var sum_house: u32 = 0;
    for (0..16) |f| {
        sum_pac += steps(pac_normal, @intCast(f));
        sum_ghost += steps(ghost_normal, @intCast(f));
        sum_fright += steps(ghost_fright, @intCast(f));
        sum_house += steps(ghost_house, @intCast(f));
    }
    try std.testing.expectEqual(@as(u32, 16), sum_pac); // 16 steps in 16 frames: 60 px/s
    try std.testing.expectEqual(@as(u32, 15), sum_ghost); // 56.25
    try std.testing.expectEqual(@as(u32, 10), sum_fright); // 37.5
    try std.testing.expectEqual(@as(u32, 8), sum_house); // 30
}

test "Pac-Man runs left from his start at 60 arcade pixels a second and stops at a wall" {
    const tiles = maze.Tiles.build(&game.initial_maze);
    var s = testSim(&tiles);
    var ev: Events = .{};
    const x0 = s.pac.x;
    for (0..60) |_| s.frame(null, &ev);
    // A second: 60 pixels less the dot stops (the dot rows).
    try std.testing.expect(x0 - s.pac.x >= 54 and x0 - s.pac.x <= 60);
    // He goes on to the wall at the end of the row and stands there.
    for (0..600) |_| s.frame(null, &ev);
    try std.testing.expect(s.pac.stopped);
    try std.testing.expectEqual(@as(i32, 8 * 5), s.pac.x);
}

/// Pacman on the row of his start (b = 20) at pixel x going `dir`, with nothing wanted.
fn pacOnRow(tiles: *const maze.Tiles, x: i32, dir: Dir) Sim {
    var s = testSim(tiles);
    s.pac.x = x;
    s.pac.y = 8 * 20;
    s.pac.px = x;
    s.pac.py = s.pac.y;
    s.pac.dir = dir;
    s.dots = @splat(@splat(0));
    return s;
}

/// Runs with `want` held from the first frame until the direction changes; the x of the turn,
/// or null when he does not turn in 20 frames. `path` gets the x of each frame from the turn on.
fn turnX(s: *Sim, want: Dir, path: *std.ArrayList(i32)) !?i32 {
    var ev: Events = .{};
    var turned: ?i32 = null;
    for (0..20) |_| {
        s.frame(want, &ev);
        if (turned == null and s.pac.dir == want) turned = s.pac.x;
        if (turned != null) try path.append(std.testing.allocator, s.pac.x);
    }
    return turned;
}

test "cornering: the pre-turn is 4 pixels from the right, 3 from the left, and the corner is cut" {
    const tiles = maze.Tiles.build(&game.initial_maze);
    // The junction at tile 14 (x = 112, up open from (14, 20)).
    var path: std.ArrayList(i32) = .empty;
    defer path.deinit(std.testing.allocator);
    var from_right = pacOnRow(&tiles, 8 * 14 + 20, .left);
    try std.testing.expectEqual(@as(?i32, 8 * 14 + 4), try turnX(&from_right, .up, &path));
    // He is at the centre line when he has gone 4 pixels up: x moved 1 per pixel (the 45 degrees).
    try std.testing.expectEqual(@as(i32, 8 * 14), from_right.pac.x);
    try std.testing.expect(from_right.pac.y < 8 * 20);
    path.clearRetainingCapacity();
    var from_left = pacOnRow(&tiles, 8 * 14 - 20, .right);
    try std.testing.expectEqual(@as(?i32, 8 * 14 - 3), try turnX(&from_left, .up, &path));
    try std.testing.expectEqual(@as(i32, 8 * 14), from_left.pac.x);
}

test "a post-turn: the up wanted for the step that ends 4 pixels after the centre going right still turns; one more and it is the next tile" {
    const tiles = maze.Tiles.build(&game.initial_maze);
    var ev: Events = .{};
    var s = pacOnRow(&tiles, 8 * 14 - 8, .right);
    // Run to 3 pixels past the centre with nothing wanted, then want up: the step ends 4 past it;
    // he turns, and drifts back to the centre line.
    while (s.pac.x < 8 * 14 + 3) s.frame(null, &ev);
    s.frame(.up, &ev);
    try std.testing.expectEqual(Dir.up, s.pac.dir);
    for (0..8) |_| s.frame(.up, &ev);
    try std.testing.expectEqual(@as(i32, 8 * 14), s.pac.x);
    // One pixel more and the step ends in the next tile, where up is wall: he goes on right.
    var late = pacOnRow(&tiles, 8 * 14 - 8, .right);
    while (late.pac.x < 8 * 14 + 4) late.frame(null, &ev);
    late.frame(.up, &ev);
    try std.testing.expectEqual(Dir.right, late.pac.dir);
}

test "a wanted direction that is blocked is kept until it opens (buffered input)" {
    const tiles = maze.Tiles.build(&game.initial_maze);
    var s = testSim(&tiles);
    var ev: Events = .{};
    // Want up from the start: the first junction with an exit up takes him there without a stop.
    var stops: u32 = 0;
    for (0..200) |_| {
        s.frame(.up, &ev);
        if (s.pac.stopped) stops += 1;
        if (s.pac.dir == .up) break;
    }
    try std.testing.expectEqual(Dir.up, s.pac.dir);
    try std.testing.expectEqual(@as(u32, 0), stops);
}

test "ghost targets: Blinky on Pac-Man, Pinky 4 ahead (up: also 4 left), Inky from Blinky, Clyde by distance" {
    const tiles = maze.Tiles.build(&game.initial_maze);
    var s = testSim(&tiles);
    s.cmd = .chase;
    s.pac.x = 8 * 20;
    s.pac.y = 8 * 20;
    s.pac.dir = .left;
    const bl = &s.ghosts[0];
    bl.x = 8 * 10;
    bl.y = 8 * 8;
    try std.testing.expectEqual(maze.Tile{ .a = 20, .b = 20 }, s.targetOf(&s.ghosts[0]));
    try std.testing.expectEqual(maze.Tile{ .a = 16, .b = 20 }, s.targetOf(&s.ghosts[1]));
    // Inky: 2 ahead of Pac-Man = (18, 20); Blinky (10, 8): the vector doubled from Blinky.
    try std.testing.expectEqual(maze.Tile{ .a = 10 + 2 * 8, .b = 8 + 2 * 12 }, s.targetOf(&s.ghosts[2]));
    s.pac.dir = .up;
    try std.testing.expectEqual(maze.Tile{ .a = 16, .b = 16 }, s.targetOf(&s.ghosts[1]));
    // Clyde far away (more than 8 tiles) targets Pac-Man, near his corner.
    s.ghosts[3].x = 8 * 2;
    s.ghosts[3].y = 8 * 2;
    try std.testing.expectEqual(maze.Tile{ .a = 20, .b = 20 }, s.targetOf(&s.ghosts[3]));
    s.ghosts[3].x = 8 * 18;
    s.ghosts[3].y = 8 * 20;
    try std.testing.expectEqual(corner[3], s.targetOf(&s.ghosts[3]));
    // Scatter: the corners.
    s.cmd = .scatter;
    try std.testing.expectEqual(corner[0], s.targetOf(&s.ghosts[0]));
    // Cruise Elroy chases in scatter.
    s.ghosts[0].elroy = 1;
    try std.testing.expectEqual(maze.Tile{ .a = 20, .b = 20 }, s.targetOf(&s.ghosts[0]));
}

test "the schedule: scatter 7 s, chase 20, ... and the ghosts reverse at each change" {
    const tiles = maze.Tiles.build(&game.initial_maze);
    var s = testSim(&tiles);
    var ev: Events = .{};
    var changes: [8]u32 = undefined;
    var n: usize = 0;
    var last = s.cmd;
    // Pac-Man stands far away (no dot eaten, no catch): the clock runs.
    s.pac.stopped = true;
    s.pac.x = -1000;
    s.pac.y = -1000;
    for (0..90 * 60) |f| {
        s.frame(null, &ev);
        if (s.cmd != last) {
            last = s.cmd;
            changes[n] = @intCast(f);
            n += 1;
        }
    }
    try std.testing.expectEqual(@as(usize, 7), n);
    // The clock moves a frame after the check: 420, 1620, 2040, 3240, 3540, 4740, 5040.
    const want = [7]u32{ 420, 1620, 2040, 3240, 3540, 4740, 5040 };
    for (want, changes[0..7]) |wf, cf| try std.testing.expect(cf >= wf - 1 and cf <= wf + 1);
    try std.testing.expectEqual(Cmd.chase, s.cmd);
}

test "ghosts leave the house in order: Pinky at once, Inky after 12 dots, Clyde after 25 more" {
    const tiles = maze.Tiles.build(&game.initial_maze);
    var s = testSim(&tiles);
    s.global_mode = false;
    s.elroy_wait_clyde = false;
    var ev: Events = .{};
    s.pac.stopped = true;
    for (0..30) |_| s.frame(null, &ev);
    try std.testing.expect(s.ghosts[1].mode != .pacing);
    try std.testing.expect(s.ghosts[2].mode == .pacing and s.ghosts[3].mode == .pacing);
    // Twelve dots (counted by the release rule) free Inky (while Pinky has left).
    for (0..12) |_| s.onDotEaten();
    for (0..5) |_| s.frame(null, &ev);
    try std.testing.expect(s.ghosts[2].mode != .pacing or s.ghosts[2].sig_leave);
}

test "frightened: a cork turns the ghosts around, they go at 50 %, and are eaten for the house" {
    const tiles = maze.Tiles.build(&game.initial_maze);
    var s = testSim(&tiles);
    var ev: Events = .{};
    s.energize(&ev);
    try std.testing.expect(s.fright_on and s.ghosts[0].scared and ev.fright_started);
    try std.testing.expect(s.ghosts[0].sig_reverse);
    // Blinky (outside) on Pac-Man's tile: eaten, back in the house, leaving at once.
    s.ghosts[0].x = s.pac.x;
    s.ghosts[0].y = s.pac.y;
    s.collide(&ev);
    try std.testing.expect(ev.eaten[0] and !ev.caught);
    try std.testing.expect(s.ghosts[0].mode == .pacing and s.ghosts[0].sig_leave and !s.ghosts[0].scared);
    // Time runs out after 6 seconds.
    var ended = false;
    for (0..fright_frames + 2) |_| {
        s.frame(null, &ev);
        if (ev.fright_ended) ended = true;
        if (ev.caught) break;
    }
    try std.testing.expect(ended or ev.caught);
}

test "a ghost never reverses on its own and never turns before a tile's centre" {
    const tiles = maze.Tiles.build(&game.initial_maze);
    var s = testSim(&tiles);
    var ev: Events = .{};
    s.cmd = .chase;
    s.pac.stopped = true;
    s.pac.x = -1000;
    s.pac.y = -1000;
    var prev_dir: Dir = s.ghosts[0].dir;
    var prev_x = s.ghosts[0].x;
    var prev_y = s.ghosts[0].y;
    // The first 400 frames: no change of mode (a reversal) yet.
    for (0..400) |_| {
        s.frame(null, &ev);
        if (ev.caught) break;
        const g = &s.ghosts[0];
        if (g.mode != .outside) continue;
        // One pixel at most per frame step, and the direction changes only at a tile centre.
        try std.testing.expect(@abs(g.x - prev_x) + @abs(g.y - prev_y) <= 2);
        if (g.dir != prev_dir and !g.sig_reverse) {
            try std.testing.expect(distToMid(g.x) == 0 and distToMid(g.y) == 0);
            try std.testing.expect(g.dir != prev_dir.opposite());
        }
        prev_dir = g.dir;
        prev_x = g.x;
        prev_y = g.y;
    }
}
