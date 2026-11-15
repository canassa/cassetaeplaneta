//! Not in the original (`Fixes.sauna_arcade_rules`): the game's clock and phases around `sim.Sim`,
//! without the Game: the READY beat, the pauses of a ghost eaten and of a catch, Pacman's death, the
//! restart, the wanted direction and its grace time. `glue.zig` runs it against SAUNA's score, waves
//! and window; the planner (`plan.zig`) runs the same code against a counter, so a planned script
//! is exactly the game's.
//!
//! The clock: the game's frame 0 is at `t0` (ms), and a tick at `now` runs the frames that are due,
//! `elapsed * 60 / 1000` (one or two a 16-ms tick), so the speeds hold whatever the timer's jitter.

const std = @import("std");
const sim = @import("sim.zig");
const maze = @import("maze.zig");
const Dir = sim.Dir;

/// At most this many frames run in a tick (a stalled page does not run the game in bursts).
pub const max_frames_per_tick = 6;
/// How long a direction released before it could be taken stays wanted.
pub const want_grace_ms = 400;
/// The READY beat at the start and after a death, and the pauses, in frames.
pub const ready_frames = 60;
pub const eat_pause_frames = 30;
pub const catch_pause_frames = 30;
/// Pacman's death: frames per picture of the strip (110 ms in the original), pictures, the hold.
pub const death_frame_len = 7;
pub const death_pictures = 6;
pub const death_hold = 12;

pub const Phase = enum {
    /// Before the game starts (the controls screen is up, or the scene has not started).
    waiting,
    /// The READY beat: everything stands.
    ready,
    play,
    /// A ghost was eaten: everything stands a moment.
    eat_pause,
    /// Pacman was caught: everything stands, then he dies alone.
    catch_pause,
    dying,
    /// The window is closing (the last dot, the last life, Esc).
    over,
};

pub const Driver = struct {
    sim: sim.Sim,
    phase: Phase = .waiting,
    phase_left: u32 = 0,
    /// The clock: the sim's frame 0 is at `t0` (ms); `done` frames have run.
    t0: u32 = 0,
    done: u32 = 0,
    /// Keys held (up, left, down, right), the direction wanted, and when a released one lapses.
    held: [4]bool = @splat(false),
    want: ?Dir = null,
    want_until: ?u32 = null,
    /// Pacman's death: frames into the strip.
    death_at: u32 = 0,
    /// Set when the actors jump (a restart): the picture does not move between the two places.
    snap: bool = true,
    /// Frames ran in the last tick.
    ran: bool = false,

    pub fn init(tiles: *const maze.Tiles, dots_left: u16) Driver {
        return .{ .sim = sim.Sim.init(tiles, dots_left) };
    }

    /// The game starts now.
    pub fn start(d: *Driver, now: u32) void {
        if (d.phase != .waiting) return;
        d.t0 = now;
        d.done = 0;
        d.phase = .ready;
        d.phase_left = ready_frames;
    }

    pub fn press(d: *Driver, dir: Dir) void {
        d.held[@backingInt(dir)] = true;
        d.want = dir;
        d.want_until = null;
    }

    pub fn release(d: *Driver, dir: Dir, now: u32) void {
        d.held[@backingInt(dir)] = false;
        if (d.want != dir) return;
        // Another key still held is wanted instead; else the direction lapses after a grace time (a
        // tap before a junction still turns there).
        for (sim.all_dirs) |o| {
            if (d.held[@backingInt(o)]) {
                d.want = o;
                d.want_until = null;
                return;
            }
        }
        d.want_until = now +% want_grace_ms;
    }

    fn wantNow(d: *Driver, now: u32) ?Dir {
        if (d.want_until) |u| {
            if (@as(i32, @bitCast(now -% u)) >= 0) {
                d.want = null;
                d.want_until = null;
            }
        }
        return d.want;
    }

    /// Runs the frames due at `now`. `fx` answers what happens to the game:
    /// `dot(sim.DotEvent) bool` (false: the last dot, the game is won), `frightEnded()`,
    /// `caught() bool` (false: the last life, the game is lost), `ghostEaten()`.
    pub fn tick(d: *Driver, now: u32, fx: anytype) void {
        d.ran = false;
        if (d.phase == .waiting or d.phase == .over) return;
        const elapsed: u64 = now -% d.t0;
        var due: u32 = @intCast(elapsed * sim.frames_per_second / 1000);
        // A stall (the page was hidden): the game goes on from now, not in a burst.
        if (due > d.done + max_frames_per_tick) {
            d.done = due - 1;
            d.t0 = now -% @as(u32, @intCast(@as(u64, d.done) * 1000 / sim.frames_per_second));
            due = @intCast(@as(u64, now -% d.t0) * sim.frames_per_second / 1000);
        }
        while (d.done < due and d.phase != .over) {
            d.frame(now, fx);
            d.done += 1;
            d.ran = true;
        }
    }

    /// The game time of frame number `done` (ms).
    pub fn frameMs(d: *const Driver) u32 {
        return d.t0 +% @as(u32, @intCast(@as(u64, d.done) * 1000 / sim.frames_per_second));
    }

    fn frame(d: *Driver, now: u32, fx: anytype) void {
        switch (d.phase) {
            .waiting, .over => {},
            .ready, .eat_pause => {
                d.phase_left -= 1;
                if (d.phase_left == 0) d.phase = .play;
            },
            .catch_pause => {
                d.phase_left -= 1;
                if (d.phase_left == 0) {
                    d.phase = .dying;
                    d.death_at = 0;
                }
            },
            .dying => {
                d.death_at += 1;
                if (d.death_at >= death_frame_len * death_pictures + death_hold) d.restart();
            },
            .play => d.play(d.wantNow(now), fx),
        }
    }

    fn play(d: *Driver, want: ?Dir, fx: anytype) void {
        var ev: sim.Events = .{};
        d.sim.frame(want, &ev);
        for (ev.dots[0..ev.dot_count]) |dot| {
            if (!fx.dot(dot)) {
                d.phase = .over;
                return;
            }
        }
        if (ev.fright_ended) fx.frightEnded();
        if (ev.caught) {
            if (!fx.caught()) {
                d.phase = .over;
                return;
            }
            d.phase = .catch_pause;
            d.phase_left = catch_pause_frames;
            return;
        }
        if (ev.anyEaten()) {
            fx.ghostEaten();
            d.phase = .eat_pause;
            d.phase_left = eat_pause_frames;
        }
    }

    /// After a death: Pacman and the ghosts back at their places, the clocks of the level
    /// restarted; the dots stay eaten.
    fn restart(d: *Driver) void {
        d.sim.restart();
        d.want = null;
        d.want_until = null;
        d.held = @splat(false);
        d.phase = .ready;
        d.phase_left = ready_frames;
        d.snap = true;
    }
};

test "a released key lapses after the grace time; another held key is wanted instead" {
    const tiles = maze.Tiles.build(&@import("../core/maze_data.zig").initial_maze);
    var d = Driver.init(&tiles, 99);
    d.press(.up);
    d.release(.up, 1000);
    try std.testing.expectEqual(Dir.up, d.wantNow(1000 + want_grace_ms - 1).?);
    try std.testing.expect(d.wantNow(1000 + want_grace_ms) == null);
    d.press(.left);
    d.press(.down);
    d.release(.down, 5000);
    try std.testing.expectEqual(Dir.left, d.wantNow(9000).?);
}

const Counter = struct {
    dots: u32 = 0,
    caught: u32 = 0,
    eaten: u32 = 0,
    fn dot(c: *Counter, _: sim.DotEvent) bool {
        c.dots += 1;
        return true;
    }
    fn frightEnded(_: *Counter) void {}
    fn caughtFn(c: *Counter) bool {
        c.caught += 1;
        return c.caught < 3;
    }
    fn ghostEaten(c: *Counter) void {
        c.eaten += 1;
    }
};

const TestFx = struct {
    c: *Counter,
    pub fn dot(f: TestFx, e: sim.DotEvent) bool {
        return f.c.dot(e);
    }
    pub fn frightEnded(f: TestFx) void {
        f.c.frightEnded();
    }
    pub fn caught(f: TestFx) bool {
        return f.c.caughtFn();
    }
    pub fn ghostEaten(f: TestFx) void {
        f.c.ghostEaten();
    }
};

test "the clock: the game starts after the READY beat and runs 60 frames a second by the clock" {
    const tiles = maze.Tiles.build(&@import("../core/maze_data.zig").initial_maze);
    var d = Driver.init(&tiles, 99);
    var c: Counter = .{};
    const fx: TestFx = .{ .c = &c };
    d.start(1000);
    var now: u32 = 1000;
    while (now < 1000 + 1000 + 1000) : (now += 16) d.tick(now, fx);
    // A second of READY, then a second of play: Pacman has run about 60 arcade pixels (dots slow him).
    try std.testing.expectEqual(Phase.play, d.phase);
    const run = 8 * 20 - d.sim.pac.x;
    try std.testing.expect(run >= 48 and run <= 60);
}
