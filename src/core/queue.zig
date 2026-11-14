//! The Win16 message queue the original runs on, emulated so the port
//! delivers messages in the same order (docs/DESIGN.md "Events and timing").
//!
//! `GetMessage` order in Windows 3.1: posted messages (FIFO), then input
//! from the system queue (mouse moves coalesced), then WM_PAINT, then timer
//! messages. Timers (SetTimer → WM_TIMER, SetSystemTimer → WM_SYSTIMER) do
//! not queue up: a due timer yields one message when nothing else is
//! pending, and is rearmed from the time it was delivered. Sent messages
//! never enter the queue (`Game.send` dispatches them at once).
//!
//! What is not certain yet (verify with traces): the posted-queue capacity
//! (Win 3.1 default is 8 unless SetMessageQueue is called; NOITE.EXE does
//! not call it), the order of several timers due at once (table order
//! here) and whether rearming counts from delivery or from expiry.

const std = @import("std");
const Msg = @import("msg.zig").Msg;
const wm = @import("msg.zig").wm;

/// Win 3.1's default application queue size; PostMessage fails when full.
pub const post_capacity = 8;
pub const input_capacity = 64;
pub const max_timers = 32;

pub const TimerKind = enum(u1) { normal, system };

pub const Timer = struct {
    kind: TimerKind,
    id: u16,
    period: u32,
    due: u32,
};

pub const Queue = struct {
    posted: Ring(post_capacity) = .{},
    input: Ring(input_capacity) = .{},
    timers: [max_timers]Timer = undefined,
    timer_count: usize = 0,
    paint_pending: bool = false,
    /// PostQuitMessage was called: WM_QUIT comes after the posted messages.
    quit_pending: bool = false,

    /// PostMessage to the main window; false when the queue is full (the
    /// original ignores the result, so the message is simply lost).
    pub fn post(q: *Queue, m: Msg) bool {
        return q.posted.push(m);
    }

    /// Removes the posted messages `id` (not Windows: for a fix, BUGS.md
    /// B37); the others keep their order. Returns how many went.
    pub fn dropPosted(q: *Queue, id: u16) usize {
        var kept: Ring(post_capacity) = .{};
        var dropped: usize = 0;
        while (q.posted.pop()) |m| {
            if (m.id == id) dropped += 1 else _ = kept.push(m);
        }
        q.posted = kept;
        return dropped;
    }

    /// Input from the platform. Consecutive mouse moves coalesce.
    pub fn postInput(q: *Queue, m: Msg) void {
        if (m.id == wm.mousemove and q.input.len > 0) {
            const last = q.input.lastPtr();
            if (last.id == wm.mousemove) {
                last.* = m;
                return;
            }
        }
        _ = q.input.push(m);
    }

    /// The Windows 3.1 timer tick (18.2 Hz): a timer cannot fire more often.
    pub const tick_ms = 55;

    /// SetTimer / SetSystemTimer: (re)arms `id` of that kind. A zero period
    /// (INI objects with PerTimer 0) fires once per system tick, as on
    /// Windows, instead of on every queue read.
    pub fn setTimer(q: *Queue, kind: TimerKind, id: u16, period: u32, now: u32) bool {
        const period_ms = if (period == 0) tick_ms else period;
        for (q.timers[0..q.timer_count]) |*t| {
            if (t.kind == kind and t.id == id) {
                t.period = period_ms;
                t.due = now +% period_ms;
                return true;
            }
        }
        if (q.timer_count == max_timers) return false;
        q.timers[q.timer_count] = .{ .kind = kind, .id = id, .period = period_ms, .due = now +% period_ms };
        q.timer_count += 1;
        return true;
    }

    /// KillTimer / KillSystemTimer; false if there was no such timer.
    pub fn killTimer(q: *Queue, kind: TimerKind, id: u16) bool {
        for (q.timers[0..q.timer_count], 0..) |t, i| {
            if (t.kind == kind and t.id == id) {
                std.mem.copyForwards(Timer, q.timers[i .. q.timer_count - 1], q.timers[i + 1 .. q.timer_count]);
                q.timer_count -= 1;
                return true;
            }
        }
        return false;
    }

    /// The armed timer `id` of that kind, or null.
    pub fn findTimer(q: *const Queue, kind: TimerKind, id: u16) ?Timer {
        for (q.timers[0..q.timer_count]) |t| {
            if (t.kind == kind and t.id == id) return t;
        }
        return null;
    }

    /// The next message GetMessage/PeekMessage would return at `now`.
    pub fn next(q: *Queue, now: u32) ?Msg {
        if (q.posted.pop()) |m| return m;
        if (q.quit_pending) {
            q.quit_pending = false;
            return .{ .id = wm.quit };
        }
        if (q.input.pop()) |m| return m;
        if (q.paint_pending) {
            q.paint_pending = false;
            return .{ .id = wm.paint };
        }
        for (q.timers[0..q.timer_count]) |*t| {
            if (@as(i32, @bitCast(now -% t.due)) >= 0) {
                t.due = now +% t.period;
                return .{
                    .id = if (t.kind == .system) wm.systimer else wm.timer,
                    .wparam = t.id,
                };
            }
        }
        return null;
    }

    /// When the earliest timer is due (for the platform's wait), or null.
    pub fn nextDue(q: *const Queue) ?u32 {
        var best: ?u32 = null;
        for (q.timers[0..q.timer_count]) |t| {
            if (best == null or @as(i32, @bitCast(t.due -% best.?)) < 0) best = t.due;
        }
        return best;
    }
};

fn Ring(comptime cap: usize) type {
    return struct {
        items: [cap]Msg = undefined,
        head: usize = 0,
        len: usize = 0,

        const Self = @This();
        fn push(r: *Self, m: Msg) bool {
            if (r.len == cap) return false;
            r.items[(r.head + r.len) % cap] = m;
            r.len += 1;
            return true;
        }
        fn pop(r: *Self) ?Msg {
            if (r.len == 0) return null;
            const m = r.items[r.head];
            r.head = (r.head + 1) % cap;
            r.len -= 1;
            return m;
        }
        fn lastPtr(r: *Self) *Msg {
            return &r.items[(r.head + r.len - 1) % cap];
        }
    };
}

test "posted before input before paint before timers" {
    var q: Queue = .{};
    try std.testing.expect(q.setTimer(.system, 1, 50, 0));
    q.paint_pending = true;
    q.postInput(.{ .id = wm.mousemove, .lparam = 1 });
    q.postInput(.{ .id = wm.mousemove, .lparam = 2 });
    try std.testing.expect(q.post(.{ .id = 0x401 }));
    try std.testing.expectEqual(@as(u16, 0x401), q.next(60).?.id);
    const move = q.next(60).?;
    try std.testing.expectEqual(wm.mousemove, move.id);
    try std.testing.expectEqual(@as(i32, 2), move.lparam);
    try std.testing.expectEqual(wm.paint, q.next(60).?.id);
    try std.testing.expectEqual(wm.systimer, q.next(60).?.id);
    try std.testing.expectEqual(@as(?Msg, null), q.next(60));
    try std.testing.expectEqual(@as(?u32, 110), q.nextDue());
}

test "the posted queue holds eight messages" {
    var q: Queue = .{};
    for (0..post_capacity) |_| try std.testing.expect(q.post(.{ .id = 0x405 }));
    try std.testing.expect(!q.post(.{ .id = 0x405 }));
}

test "WM_QUIT comes after the posted messages, before input" {
    var q: Queue = .{};
    try std.testing.expect(q.post(.{ .id = 0x401 }));
    q.quit_pending = true;
    q.postInput(.{ .id = wm.mousemove });
    try std.testing.expectEqual(@as(u16, 0x401), q.next(0).?.id);
    try std.testing.expectEqual(wm.quit, q.next(0).?.id);
    try std.testing.expectEqual(wm.mousemove, q.next(0).?.id);
}

test "a timer missed for a long time fires once (Windows coalesces WM_TIMER)" {
    var q: Queue = .{};
    try std.testing.expect(q.setTimer(.normal, 0x14, 100, 0));
    try std.testing.expectEqual(wm.timer, q.next(10_000).?.id);
    try std.testing.expectEqual(@as(?Msg, null), q.next(10_000));
    try std.testing.expectEqual(@as(?u32, 10_100), q.nextDue());
}

test "dropPosted removes one kind and keeps the order of the rest" {
    var q: Queue = .{};
    _ = q.post(.{ .id = 0x403, .wparam = 1 });
    _ = q.post(.{ .id = 0x402, .wparam = 1 });
    _ = q.post(.{ .id = 0x403, .wparam = 2 });
    _ = q.post(.{ .id = 0x402 });
    try std.testing.expectEqual(@as(usize, 2), q.dropPosted(0x402));
    try std.testing.expectEqual(@as(u16, 1), q.next(0).?.wparam);
    try std.testing.expectEqual(@as(u16, 2), q.next(0).?.wparam);
    try std.testing.expectEqual(@as(?Msg, null), q.next(0));
}
