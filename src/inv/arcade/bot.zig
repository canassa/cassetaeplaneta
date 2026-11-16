//! Dev tool, not part of the game: a player for the Corrigida's arcade INV, to see how beatable it is
//! (`zig build inv-bot -- --games 200 --reaction 400`, driven by `tools/inv_bot.py`).
//!
//! It plays the very `driver.Driver` the game runs, a tick every 16 ms, with the keys a player has
//! (LEFT and RIGHT held, SPACE tapped) and what a player sees: the screen as it was `--reaction` ms
//! ago (a ring of the game's state), never the future. From that it
//!
//! - dodges: each bomb in sight is carried forward to now at its speed, and the cannon keeps out of
//!   the stretch of x the bomb would hit it in (with a margin) for as long as the bomb is within
//!   75 frames of the cannon's row; it steps to the nearest free x and does not walk through one;
//! - aims: it picks the lane (the shot's x) whose first target is the lowest invader, not under a
//!   bunker, leading the rack's march; the saucer, when the lane to it is clear;
//! - fires when the shot is free and the lane is under the cannon (within a tolerance that varies
//!   from decision to decision, as a hand does).
//!
//! `--emit FILE` writes the keys of one game (`--seed`) as an input script for the headless harness.

const std = @import("std");
const sim = @import("sim.zig");
const driver = @import("driver.zig");
const bunker = @import("bunker.zig");

const tick_ms = 16;
/// A key press is made this long before a tick (between two ticks).
const press_lead = 8;
const ring_len = 64;
const max_ms = 240_000;

const Params = struct {
    /// How long a new threat (a bomb, the saucer) takes to be answered.
    reaction_ms: u32 = 400,
    jitter_ms: u32 = 100,
    /// How stale the picture is that it aims by (a hand tracks what moves; it lags only a little).
    aim_ms: u32 = 100,
    /// A hand's error in the lane it picks (px), redrawn every decision.
    sloppy: i32 = 0,
    /// The share (%) of its decisions (every 0.25 to 0.7 s) in which it does not look at the bombs at all:
    /// it is aiming, or watching the saucer.
    lapse: i32 = 0,
    /// No keys at all (the baseline).
    passive: bool = false,
    seed: u64 = 1,
    /// Does it go for the saucer?
    saucer: bool = true,
    /// Does it hide under the bunkers? (No: it keeps out of the way of the bombs only.)
    margin: i32 = 4,
};

const Key = struct { at: u32, key: driver.Key, ms: u32 };

const Result = struct {
    won: bool = false,
    landed: bool = false,
    frames: u32 = 0,
    lives_lost: u32 = 0,
    shots: u32 = 0,
    hits: u32 = 0,
    saucers: u32 = 0,
    score: i32 = 0,
    alive_at_end: u8 = 0,
    bunkers_left: usize = 0,
    ms: u32 = 0,
    most_bombs: u32 = 0,
};

const Stats = struct {
    r: Result = .{},
    trace: bool = false,
    pub fn frame(st: *Stats, s: *const sim.Sim, ev: sim.Events) void {
        st.r.frames += 1;
        if (st.trace) {
            const ms = (driver.ready_frames + st.r.frames) * 1000 / sim.fps;
            if (ev.saucer_launch) std.debug.print("{d} ms: saucer launched\n", .{ms});
            if (ev.saucer_hit) std.debug.print("{d} ms: saucer hit (shots {d})\n", .{ ms, s.shot_count });
            if (ev.cannon_hit) std.debug.print("{d} ms: cannon hit, {d} lives left\n", .{ ms, s.lives });
            if (ev.descend) std.debug.print("{d} ms: the rack drops ({d} left)\n", .{ ms, s.alive });
            if (ev.invader_hit) std.debug.print("{d} ms: invader hit, {d} left, cannon x {d}, score {d}\n", .{ ms, s.alive, s.cannonX(), st.r.score + ev.score });
            if (ev.fired) std.debug.print("{d} ms: fired, cannon x {d}\n", .{ ms, s.cannonX() });
            if (ev.bomb_shot) std.debug.print("{d} ms: a shot meets a bomb\n", .{ms});
        }
        st.r.score += ev.score;
        if (ev.fired) st.r.shots += 1;
        if (ev.invader_hit) st.r.hits += 1;
        if (ev.saucer_hit) st.r.saucers += 1;
        if (ev.cannon_hit) st.r.lives_lost += 1;
        if (ev.landed) st.r.landed = true;
        if (ev.won) st.r.won = true;
        var n: u32 = 0;
        for (s.bombs) |b| {
            if (b.state == .fall) n += 1;
        }
        st.r.most_bombs = @max(st.r.most_bombs, n);
    }
};

const Want = struct { dir: i2 = 0, fire: bool = false };

const Bot = struct {
    p: Params,
    rng: std.Random.DefaultPrng,
    ring: [ring_len]sim.Sim = undefined,
    n: u32 = 0,
    /// The reaction in ticks of this decision, and the tolerance.
    delay: u32 = 25,
    tol: i32 = 10,
    redo_at: u32 = 0,
    noise: i32 = 0,
    looking: bool = true,
    fire_until: u32 = 0,
    cooldown_until: u32 = 0,
    want: Want = .{},

    fn init(p: Params) Bot {
        return .{ .p = p, .rng = std.Random.DefaultPrng.init(p.seed) };
    }

    fn push(b: *Bot, s: *const sim.Sim) void {
        b.ring[b.n % ring_len] = s.*;
        b.n += 1;
    }

    fn seenAt(b: *const Bot, delay: u32) *const sim.Sim {
        const back = @min(delay, b.n - 1);
        return &b.ring[(b.n - 1 - back) % ring_len];
    }

    fn aimDelay(b: *const Bot) u32 {
        return b.p.aim_ms / tick_ms;
    }

    /// How far the rack has moved by `frames` from now: it goes at its step a march (a march is as
    /// many frames as invaders left), turning at the walls.
    fn rackShift(s: *const sim.Sim, frames: i32) i32 {
        var minx: i32 = std.math.maxInt(i32);
        var maxx: i32 = std.math.minInt(i32);
        for (s.inv) |iv| {
            if (!iv.alive) continue;
            minx = @min(minx, iv.x);
            maxx = @max(maxx, iv.x);
        }
        if (minx > maxx) return 0;
        const left_room: i32 = minx + sim.inv_vis_l - sim.wall_l;
        const right_room: i32 = sim.wall_r - (maxx + sim.inv_vis_r);
        const alive: i32 = @max(s.alive, 1);
        var dirv: i32 = if (s.rack_dx < 0) -1 else 1;
        var sh: i32 = 0;
        var fr: i32 = 0;
        var acc: i32 = 0;
        while (fr < frames) : (fr += 1) {
            acc += @intCast(@abs(s.rack_dx));
            // One step of the march per `alive` frames.
            while (acc >= alive) : (acc -= alive) {
                sh += dirv;
                if (dirv > 0 and sh >= right_room) dirv = -1;
                if (dirv < 0 and -sh >= left_room) dirv = 1;
            }
        }
        return sh;
    }

    fn rand(b: *Bot, lo: i32, hi: i32) i32 {
        return lo + @as(i32, @intCast(b.rng.random().uintLessThan(u32, @intCast(hi - lo + 1))));
    }

    const Zone = struct { lo: i32, hi: i32, tt: i32 };

    /// The stretches of the cannon's x a bomb in sight would hit it in, with the frames before it
    /// arrives.
    fn zones(b: *Bot, s: *const sim.Sim, out: *[3]Zone) usize {
        var k: usize = 0;
        const fast = s.alive < sim.bomb_fast_below;
        const speed: i32 = if (fast) sim.bomb_speed_fast else sim.bomb_speed;
        const ahead: i32 = @intCast(b.delay);
        for (s.bombs) |bm| {
            if (bm.state != .fall) continue;
            const y_now = bm.y + speed * ahead;
            const bottom = (y_now >> 8) + sim.bomb_h;
            const tt = @divTrunc((sim.cannon_y - bottom) * 256, speed);
            if (tt > 75) continue;
            const x0 = bm.x + 1;
            const x1 = bm.x + 10;
            out[k] = .{ .lo = x0 - 63 - b.p.margin, .hi = x1 - 1 + b.p.margin, .tt = @max(tt, 0) };
            k += 1;
        }
        return k;
    }

    fn inZone(zs: []const Zone, cx: i32) bool {
        for (zs) |z| if (cx >= z.lo and cx <= z.hi) return true;
        return false;
    }

    fn laneBlocked(s: *const sim.Sim, lane: i32) bool {
        for (s.bunkers) |bk| {
            if (bk.touch(lane - 1, bk.y, lane + 1, bk.bottom() - 1).n > 0) return true;
        }
        return false;
    }

    /// Would a shot up `lane`, fired now, hit an invader? Each invader is carried to where the march
    /// will have it when the shot gets there.
    fn willHit(b: *const Bot, s: *const sim.Sim, lane: i32) bool {
        const lag: i32 = @intCast(b.aimDelay());
        for (s.inv) |iv| {
            if (!iv.alive) continue;
            const fly = @divTrunc(sim.cannon_y - 18 - (iv.y + 17), 7);
            const x = iv.x + rackShift(s, fly + lag);
            if (lane >= x + sim.inv_vis_l + 8 and lane <= x + sim.inv_vis_r - 8) return true;
        }
        return false;
    }

    /// Where to stand to shoot: the lowest invader (nearest the cannon among equals), led by the
    /// march, at a lane no bunker blocks; or the saucer, if the lane to it is clear.
    fn aim(b: *Bot, s: *const sim.Sim, cx: i32) ?struct { x: i32, saucer: bool } {
        const lag: i32 = @intCast(b.aimDelay());
        if (b.p.saucer and s.saucer.state == .fly) {
            const fly: i32 = @divTrunc(sim.cannon_y - 18 - (sim.saucer_y + 16), 7);
            const sx = (s.saucer.x >> 8) + 30;
            const moved = @divTrunc(s.saucer.dir * sim.saucer_speed * (fly + lag), 256);
            const lane2 = sx + moved;
            if (lane2 > 40 and lane2 < 600 and !laneBlocked(s, lane2) and !b.willHit(s, lane2)) {
                return .{ .x = lane2 - 32 + b.noise, .saucer = true };
            }
        }
        var best: ?i32 = null;
        var best_cost: i32 = std.math.maxInt(i32);
        for (s.inv) |iv| {
            if (!iv.alive) continue;
            const fly = @divTrunc(sim.cannon_y - 18 - (iv.y + 17), 7);
            const walk = @divTrunc(@as(i32, @intCast(@abs(iv.x + 44 - 32 - cx))), 3);
            const x = iv.x + rackShift(s, fly + lag + walk);
            // The lane: the middle of the invader, or a little to either side where a bunker is in the way.
            for ([_]i32{ 0, 16, -16, 30, -30 }) |off| {
                const lane = x + 44 + off;
                if (lane < 40 or lane > 600 or laneBlocked(s, lane)) continue;
                const cost = @as(i32, @intCast(@abs(lane - 32 - cx))) - 2 * iv.y;
                if (cost < best_cost) {
                    best_cost = cost;
                    best = lane - 32 + b.noise;
                }
                break;
            }
        }
        if (best) |x| return .{ .x = x, .saucer = false };
        return null;
    }

    /// A rack this fast cannot be followed (the cannon is slower): stand where a lane is free and fire as
    /// it comes.
    fn rackFast(s: *const sim.Sim) bool {
        return @abs(s.rack_dx) * 10 >= 25 * @as(i32, @max(s.alive, 1));
    }

    /// The cannon's x to wait at: the nearest lane that no bunker blocks and that an invader's sweep
    /// of the screen passes over (the invaders go between the walls, so some lanes they never reach).
    fn standingX(s: *const sim.Sim, cx: i32) i32 {
        var minx: i32 = std.math.maxInt(i32);
        var maxx: i32 = std.math.minInt(i32);
        for (s.inv) |iv| {
            if (!iv.alive) continue;
            minx = @min(minx, iv.x);
            maxx = @max(maxx, iv.x);
        }
        if (minx > maxx) return cx;
        const left_room: i32 = minx + sim.inv_vis_l - sim.wall_l;
        const right_room: i32 = sim.wall_r - (maxx + sim.inv_vis_r);
        var best: i32 = cx;
        var best_d: i32 = std.math.maxInt(i32);
        var lane: i32 = 60;
        while (lane <= 580) : (lane += 4) {
            if (laneBlocked(s, lane)) continue;
            // Some invader's visible stretch, over its whole sweep, holds the lane (with a margin).
            var covered = false;
            for (s.inv) |iv| {
                if (!iv.alive) continue;
                if (lane >= iv.x - left_room + sim.inv_vis_l + 12 and lane <= iv.x + right_room + sim.inv_vis_r - 12) covered = true;
            }
            if (!covered) continue;
            const dd: i32 = @intCast(@abs(lane - 32 - cx));
            if (dd < best_d) {
                best_d = dd;
                best = lane - 32;
            }
        }
        return best;
    }

    fn decide(b: *Bot, d: *const driver.Driver, tick: u32) Want {
        if (tick >= b.redo_at) {
            const ms: i32 = @as(i32, @intCast(b.p.reaction_ms)) + b.rand(-@as(i32, @intCast(b.p.jitter_ms)), @intCast(b.p.jitter_ms));
            b.delay = @intCast(@max(1, @divTrunc(ms, tick_ms)));
            b.tol = b.rand(6, 16);
            b.noise = if (b.p.sloppy > 0) b.rand(-b.p.sloppy, b.p.sloppy) else 0;
            b.looking = b.rand(0, 99) >= b.p.lapse;
            b.redo_at = tick + @as(u32, @intCast(b.rand(15, 40)));
        }
        const s = b.seenAt(b.delay);
        const sa = b.seenAt(b.aimDelay());
        const me = &d.sim;
        const cx = me.cannonX();
        var w: Want = .{};
        if (me.mode != .play) return w;

        var zs_buf: [3]Zone = undefined;
        const nz = if (b.looking) b.zones(s, &zs_buf) else 0;
        const zs = zs_buf[0..nz];
        // The free stretch around the cannon's x: from the nearest zone edge on each side.
        var lo: i32 = sim.cannon_min_x;
        var hi: i32 = sim.cannon_max_x;
        if (inZone(zs, cx)) {
            // Out of the way: the nearest free x on either side.
            var left_free: i32 = cx;
            while (left_free >= sim.cannon_min_x and inZone(zs, left_free)) left_free -= 2;
            var right_free: i32 = cx;
            while (right_free <= sim.cannon_max_x and inZone(zs, right_free)) right_free += 2;
            const l_ok = left_free >= sim.cannon_min_x;
            const r_ok = right_free <= sim.cannon_max_x;
            const target = if (l_ok and r_ok)
                (if (cx - left_free <= right_free - cx) left_free else right_free)
            else if (l_ok) left_free else right_free;
            w.dir = if (target < cx) -1 else 1;
            // Still fire if the lane is right.
            w.fire = b.fireNow(sa, d, cx);
            return w;
        }
        for (zs) |z| {
            if (z.hi < cx) lo = @max(lo, z.hi + 2);
            if (z.lo > cx) hi = @min(hi, z.lo - 2);
        }
        const fast = rackFast(sa);
        const want_x: ?i32 = if (b.p.saucer and sa.saucer.state == .fly) (if (b.aim(sa, cx)) |a| (if (a.saucer) a.x else null) else null) else null;
        if (want_x orelse (if (fast) standingX(sa, cx) else if (b.aim(sa, cx)) |a| a.x else null)) |x| {
            const target = std.math.clamp(x, lo, hi);
            const diff = target - cx;
            if (diff > 3) w.dir = 1 else if (diff < -3) w.dir = -1;
        }
        w.fire = b.fireNow(sa, d, cx);
        return w;
    }

    /// Is the shot free, and would a shot from the cannon's lane hit something?
    fn fireNow(b: *Bot, s: *const sim.Sim, d: *const driver.Driver, cx: i32) bool {
        if (s.shot.state != .none or d.sim.shot.state != .none) return false;
        if (b.n < b.cooldown_until) return false;
        const lane = cx + 32 + b.noise;
        if (laneBlocked(s, lane)) return false;
        if (b.p.saucer and s.saucer.state == .fly) {
            if (b.aim(s, cx)) |a| if (a.saucer and @abs(a.x - cx) <= b.tol) return true;
        }
        return b.willHit(s, lane);
    }
};

fn play(p: Params, emit: ?*std.ArrayList(Key), gpa: std.mem.Allocator, trace: bool) !Result {
    var d = driver.Driver.init();
    var st: Stats = .{ .trace = trace };
    var bot = Bot.init(p);
    d.start(0);
    var now: u32 = 0;
    var tick: u32 = 0;
    var held: Want = .{};
    var fire_ticks: u32 = 0;
    var started: [3]?u32 = .{ null, null, null };
    while (d.phase != .over and now < max_ms) {
        now += tick_ms;
        tick += 1;
        bot.push(&d.sim);
        if (d.phase == .run) {
            var w = if (p.passive) Want{} else bot.decide(&d, tick);
            // A tap: down for 3 ticks, then a pause of a few (a hand).
            if (fire_ticks > 0) {
                fire_ticks -= 1;
                w.fire = true;
            } else if (w.fire) {
                fire_ticks = 2;
                bot.cooldown_until = bot.n + @as(u32, @intCast(bot.rand(0, 8)));
            }
            const lk: bool = w.dir < 0;
            const rk: bool = w.dir > 0;
            const was_l = held.dir < 0;
            const was_r = held.dir > 0;
            const at = now - press_lead;
            if (lk != was_l) {
                d.key(.left, lk);
                try note(emit, gpa, &started[0], .left, lk, at);
            }
            if (rk != was_r) {
                d.key(.right, rk);
                try note(emit, gpa, &started[1], .right, rk, at);
            }
            if (w.fire != held.fire) {
                d.key(.fire, w.fire);
                try note(emit, gpa, &started[2], .fire, w.fire, at);
            }
            held = .{ .dir = w.dir, .fire = w.fire };
        }
        d.tick(now, &st);
    }
    st.r.ms = now;
    st.r.alive_at_end = d.sim.alive;
    var n: usize = 0;
    for (d.sim.bunkers) |bk| n += bk.count();
    st.r.bunkers_left = n;
    return st.r;
}

fn note(emit: ?*std.ArrayList(Key), gpa: std.mem.Allocator, started: *?u32, k: driver.Key, down: bool, at: u32) !void {
    const list = emit orelse return;
    if (down) {
        started.* = at;
    } else if (started.*) |s| {
        // The release comes a millisecond before the next press (so a key repeat of this one cannot land
        // between a press of the other and this release).
        try list.append(gpa, .{ .at = s, .key = k, .ms = at - s - 1 });
        started.* = null;
    }
}

pub fn main(init: std.process.Init) !void {
    const gpa = init.gpa;
    var p: Params = .{};
    var games: u32 = 100;
    var emit_path: ?[]const u8 = null;
    var verbose = false;
    var trace = false;
    var start: u32 = 1000;
    var it = init.minimal.args.iterate();
    _ = it.next();
    while (it.next()) |a| {
        if (std.mem.eql(u8, a, "--games")) {
            games = try std.fmt.parseInt(u32, it.next() orelse return error.MissingValue, 10);
        } else if (std.mem.eql(u8, a, "--reaction")) {
            p.reaction_ms = try std.fmt.parseInt(u32, it.next() orelse return error.MissingValue, 10);
        } else if (std.mem.eql(u8, a, "--jitter")) {
            p.jitter_ms = try std.fmt.parseInt(u32, it.next() orelse return error.MissingValue, 10);
        } else if (std.mem.eql(u8, a, "--aim")) {
            p.aim_ms = try std.fmt.parseInt(u32, it.next() orelse return error.MissingValue, 10);
        } else if (std.mem.eql(u8, a, "--sloppy")) {
            p.sloppy = try std.fmt.parseInt(i32, it.next() orelse return error.MissingValue, 10);
        } else if (std.mem.eql(u8, a, "--passive")) {
            p.passive = true;
        } else if (std.mem.eql(u8, a, "--lapse")) {
            p.lapse = try std.fmt.parseInt(i32, it.next() orelse return error.MissingValue, 10);
        } else if (std.mem.eql(u8, a, "--seed")) {
            p.seed = try std.fmt.parseInt(u64, it.next() orelse return error.MissingValue, 10);
        } else if (std.mem.eql(u8, a, "--margin")) {
            p.margin = try std.fmt.parseInt(i32, it.next() orelse return error.MissingValue, 10);
        } else if (std.mem.eql(u8, a, "--no-saucer")) {
            p.saucer = false;
        } else if (std.mem.eql(u8, a, "--start")) {
            start = try std.fmt.parseInt(u32, it.next() orelse return error.MissingValue, 10);
        } else if (std.mem.eql(u8, a, "--emit")) {
            emit_path = it.next() orelse return error.MissingValue;
        } else if (std.mem.eql(u8, a, "--trace")) {
            trace = true;
        } else if (std.mem.eql(u8, a, "--verbose")) {
            verbose = true;
        } else return error.BadArgument;
    }

    var buf: [1 << 14]u8 = undefined;
    var fw = std.Io.File.stdout().writer(init.io, &buf);
    const w = &fw.interface;

    if (emit_path) |path| {
        var keys: std.ArrayList(Key) = .empty;
        defer keys.deinit(gpa);
        const r = try play(p, &keys, gpa, trace);
        std.mem.sort(Key, keys.items, {}, struct {
            fn lt(_: void, a: Key, b: Key) bool {
                return a.at < b.at;
            }
        }.lt);
        var out: std.Io.Writer.Allocating = .init(gpa);
        defer out.deinit();
        const ow = &out.writer;
        try ow.print("# the bot's keys (tools/inv_bot.py: reaction {d} ms, seed {d}); {s} at {d} ms after the start, score {d}\n", .{ p.reaction_ms, p.seed, if (r.won) "won" else "lost", r.ms, r.score });
        // A key takes the controls screen down (and is no move); the game's clock starts then.
        try ow.print("{d} key return\n", .{start});
        for (keys.items) |k| {
            const name = switch (k.key) {
                .left => "left",
                .right => "right",
                .fire => "space",
            };
            try ow.print("{d} hold {s} {d}\n", .{ start + k.at, name, k.ms });
        }
        try ow.print("# result {s} {d}\n", .{ if (r.won) "won" else "lost", r.score });
        try ow.print("# end {d}\n", .{start + r.ms});
        try std.Io.Dir.cwd().writeFile(init.io, .{ .sub_path = path, .data = out.written() });
        try w.print("{s} at {d} ms, score {d}, lives lost {d}, shots {d}, hits {d}, saucers {d}\n", .{ if (r.won) "won" else "lost", r.ms, r.score, r.lives_lost, r.shots, r.hits, r.saucers });
        try w.flush();
        return;
    }

    var won: u32 = 0;
    var landed: u32 = 0;
    var lives: u64 = 0;
    var shots: u64 = 0;
    var hits: u64 = 0;
    var saucers: u64 = 0;
    var score: i64 = 0;
    var win_ms: u64 = 0;
    var all_ms: u64 = 0;
    var bunk: u64 = 0;
    var lost_alive: u64 = 0;
    var lost_n: u32 = 0;
    var most3: u32 = 0;
    var g: u32 = 0;
    while (g < games) : (g += 1) {
        var q = p;
        q.seed = p.seed + g;
        const r = try play(q, null, gpa, false);
        if (verbose) try w.print("game {d}: {s} {d} ms score {d} lives lost {d} shots {d} hits {d} saucers {d} left {d}\n", .{ g, if (r.won) "won" else "lost", r.ms, r.score, r.lives_lost, r.shots, r.hits, r.saucers, r.alive_at_end });
        if (r.won) {
            won += 1;
            win_ms += r.ms;
        } else {
            lost_n += 1;
            lost_alive += r.alive_at_end;
        }
        if (r.landed) landed += 1;
        lives += r.lives_lost;
        shots += r.shots;
        hits += r.hits;
        saucers += r.saucers;
        score += r.score;
        all_ms += r.ms;
        bunk += r.bunkers_left;
        if (r.most_bombs >= 3) most3 += 1;
    }
    const gf: f64 = @floatFromInt(games);
    try w.print("reaction {d} ms (+-{d}), {d} games\n", .{ p.reaction_ms, p.jitter_ms, games });
    try w.print("won {d} ({d:.0} %), lost by landing {d}\n", .{ won, 100.0 * @as(f64, @floatFromInt(won)) / gf, landed });
    try w.print("lives lost per game {d:.2}, shots {d:.1}, hits {d:.1} (accuracy {d:.0} %), saucers hit {d:.2}\n", .{
        @as(f64, @floatFromInt(lives)) / gf,
        @as(f64, @floatFromInt(shots)) / gf,
        @as(f64, @floatFromInt(hits)) / gf,
        if (shots > 0) 100.0 * @as(f64, @floatFromInt(hits)) / @as(f64, @floatFromInt(shots)) else 0.0,
        @as(f64, @floatFromInt(saucers)) / gf,
    });
    try w.print("time {d:.1} s (a win {d:.1} s), score {d:.0}, bunker blocks left {d:.0} of 1212, games with 3 bombs at once {d}\n", .{
        @as(f64, @floatFromInt(all_ms)) / gf / 1000.0,
        if (won > 0) @as(f64, @floatFromInt(win_ms)) / @as(f64, @floatFromInt(won)) / 1000.0 else 0.0,
        @as(f64, @floatFromInt(score)) / gf,
        @as(f64, @floatFromInt(bunk)) / gf,
        most3,
    });
    if (lost_n > 0) try w.print("invaders left in the lost games: {d:.1}\n", .{@as(f64, @floatFromInt(lost_alive)) / @as(f64, @floatFromInt(lost_n))});
    try w.flush();
}
