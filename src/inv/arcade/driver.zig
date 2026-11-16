//! Not in the original (`Fixes.inv_arcade_rules`): the clock and the keys around `sim.Sim`, without
//! the Game: the READY beat, the keys held, the tap shorter than a frame. `glue.zig` runs it against
//! INV's score, waves and window; the bot (`bot.zig`) runs the same code against a counter, so a
//! game the bot plays is exactly the game's.
//!
//! The clock: the game's frame 0 is at `t0` (ms), and a tick at `now` runs the frames that are due,
//! `elapsed * 60 / 1000` (none, one or two a 16-ms tick), so the speeds hold whatever the timer's
//! jitter. The keys a tick sees are the ones held at it.

const std = @import("std");
const sim = @import("sim.zig");

/// At most this many frames run in a tick (a stalled page does not run the game in bursts).
pub const max_frames_per_tick = 6;
/// Everything stands this long at the start (the arcade's prompt, shortened).
pub const ready_frames = 30;

pub const Phase = enum {
    /// Before the game starts (the controls screen is up, or the scene has not started).
    waiting,
    ready,
    run,
    /// The game is over (the win or the loss has been reported).
    over,
};

pub const Key = enum { left, right, fire };

pub const Driver = struct {
    sim: sim.Sim,
    phase: Phase = .waiting,
    ready_left: u32 = 0,
    /// The clock: frame 0 is at `t0` (ms); `done` frames have run.
    t0: u32 = 0,
    done: u32 = 0,
    left: bool = false,
    right: bool = false,
    /// The direction pressed last, which wins while both are held.
    last: i2 = 0,
    fire: bool = false,
    /// A press since the last frame: it counts as held for that frame even if released.
    fire_tap: bool = false,
    /// The game time of the frame that ran last (ms), and whether a tick ran any.
    frame_ms: u32 = 0,
    ran: bool = false,

    pub fn init() Driver {
        return .{ .sim = sim.Sim.init() };
    }

    pub fn start(d: *Driver, now: u32) void {
        if (d.phase != .waiting) return;
        d.t0 = now;
        d.done = 0;
        d.frame_ms = now;
        d.phase = .ready;
        d.ready_left = ready_frames;
    }

    pub fn key(d: *Driver, k: Key, down: bool) void {
        switch (k) {
            .left => {
                d.left = down;
                if (down) d.last = -1 else if (d.right) d.last = 1;
            },
            .right => {
                d.right = down;
                if (down) d.last = 1 else if (d.left) d.last = -1;
            },
            .fire => {
                if (down and !d.fire) d.fire_tap = true;
                d.fire = down;
            },
        }
        if (!d.left and !d.right) d.last = 0;
    }

    fn input(d: *const Driver) sim.Input {
        const dir: i2 = if (d.left and d.right) d.last else if (d.left) -1 else if (d.right) 1 else 0;
        return .{ .dir = dir, .fire = d.fire or d.fire_tap };
    }

    /// Runs the frames due at `now`. `fx.frame(*const sim.Sim, sim.Events)` is told each one.
    pub fn tick(d: *Driver, now: u32, fx: anytype) void {
        d.ran = false;
        if (d.phase == .waiting or d.phase == .over) return;
        const elapsed: u64 = now -% d.t0;
        var due: u32 = @intCast(elapsed * sim.fps / 1000);
        // A stall (the page was hidden): the game goes on from now, not in a burst.
        if (due > d.done + max_frames_per_tick) {
            d.done = due - 1;
            d.t0 = now -% @as(u32, @intCast(@as(u64, d.done) * 1000 / sim.fps));
            due = @intCast(@as(u64, now -% d.t0) * sim.fps / 1000);
        }
        while (d.done < due and d.phase != .over) {
            d.frame(fx);
            d.done += 1;
            d.ran = true;
        }
    }

    /// The game time of frame number `n` (ms).
    pub fn frameTime(d: *const Driver, n: u32) u32 {
        return d.t0 +% @as(u32, @intCast(@as(u64, n) * 1000 / sim.fps));
    }

    fn frame(d: *Driver, fx: anytype) void {
        d.frame_ms = d.frameTime(d.done);
        switch (d.phase) {
            .waiting, .over => {},
            .ready => {
                d.ready_left -= 1;
                if (d.ready_left == 0) d.phase = .run;
            },
            .run => {
                var ev: sim.Events = .{};
                d.sim.frame(d.input(), &ev);
                d.fire_tap = false;
                fx.frame(&d.sim, ev);
                if (d.sim.mode == .over) d.phase = .over;
            },
        }
    }
};

const Counter = struct {
    frames: u32 = 0,
    fired: u32 = 0,
    pub fn frame(c: *Counter, _: *const sim.Sim, ev: sim.Events) void {
        c.frames += 1;
        if (ev.fired) c.fired += 1;
    }
};

test "the clock: the game starts after the READY beat and runs 60 frames a second by the clock" {
    var d = Driver.init();
    var c: Counter = .{};
    d.start(1000);
    var now: u32 = 1000;
    while (now < 3000) : (now += 16) d.tick(now, &c);
    // 2 s = 120 frames, the first 30 of them READY.
    try std.testing.expectEqual(Phase.run, d.phase);
    try std.testing.expect(c.frames >= 88 and c.frames <= 90);
}

test "a tap shorter than a frame still fires; a held button fires once" {
    var d = Driver.init();
    var c: Counter = .{};
    d.start(0);
    var now: u32 = 0;
    while (d.phase != .run) : (now += 16) d.tick(now, &c);
    d.key(.fire, true);
    d.key(.fire, false);
    d.tick(now, &c);
    now += 16;
    d.tick(now, &c);
    try std.testing.expectEqual(@as(u32, 1), c.fired);
    // Held through the end of the shot: still one.
    d.key(.fire, true);
    while (now < 6000) : (now += 16) d.tick(now, &c);
    try std.testing.expectEqual(@as(u32, 1), c.fired);
}

test "both arrows held: the one pressed last wins; releasing it hands the move to the other" {
    var d = Driver.init();
    d.key(.left, true);
    try std.testing.expectEqual(@as(i2, -1), d.input().dir);
    d.key(.right, true);
    try std.testing.expectEqual(@as(i2, 1), d.input().dir);
    d.key(.right, false);
    try std.testing.expectEqual(@as(i2, -1), d.input().dir);
    d.key(.left, false);
    try std.testing.expectEqual(@as(i2, 0), d.input().dir);
}
