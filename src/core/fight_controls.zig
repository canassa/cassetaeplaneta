//! The fights' Corrigida additions (SALGIN and XILINDRO, which share the
//! engine; not port units, no original code): the A/S/D/F key layout
//! (`fight_keys_asdf`) and the controls screen shown before the round
//! starts (`fight_controls_screen`). docs/salgin/DESIGN.md "Decisions".
//!
//! Both work in front of the scene handler (`arena.handleMessage` of each
//! program): `gate` translates the new keys into the 1995 keys whose move
//! they do, so the game logic is untouched, and while the screen is up it
//! keeps the input, the timers and the handler's clock block from the
//! fight. The screen is drawn into the backdrop, so a WM_PAINT shows it
//! too; the program restores the panel's rectangle when it goes.

const std = @import("std");
const msg = @import("msg.zig");
const Msg = msg.Msg;
const wm = msg.wm;
const Fixes = @import("fixes.zig").Fixes;
const platform = @import("../platform/platform.zig");
const screen = @import("controls_screen.zig");
const Platform = platform.Platform;
const Surface = platform.Surface;

const vk_pgup: u16 = 0x21;
const vk_end: u16 = 0x23;
const vk_home: u16 = 0x24;
const vk_up: u16 = 0x26;
const vk_down: u16 = 0x28;
const vk_insert: u16 = 0x2d;
pub const vk_a: u16 = 0x41;
pub const vk_d: u16 = 0x44;
pub const vk_f: u16 = 0x46;
pub const vk_s: u16 = 0x53;

/// `fight_keys_asdf`: the key pressed to the 1995 key whose move it does.
/// Up jumps (Insert), Down blocks (End), A punches (PgUp), S is the middle
/// kick (Up: XILINDRO's chute médio, SALGIN's voadora), D the high kick
/// (Home: XILINDRO's chute alto, SALGIN's salto), F the sweep (Down). The
/// other keys, the old PgUp, Home, End and Insert included, stay.
pub fn translate(vk: u16) u16 {
    return switch (vk) {
        vk_up => vk_insert,
        vk_down => vk_end,
        vk_a => vk_pgup,
        vk_s => vk_up,
        vk_d => vk_home,
        vk_f => vk_down,
        else => vk,
    };
}

/// The key to press for the 1995 key `vk`'s move when `fight_keys_asdf` is on
/// (the inverse of `translate`; the player bot, `core/fight_bot.zig`, thinks
/// in the 1995 keys).
pub fn untranslate(vk: u16) u16 {
    return switch (vk) {
        vk_insert => vk_up,
        vk_end => vk_down,
        vk_pgup => vk_a,
        vk_up => vk_s,
        vk_home => vk_d,
        vk_down => vk_f,
        else => vk,
    };
}

/// The frozen intro after the screen goes (the arcade fighters' "ROUND 1...
/// FIGHT!"): PORRADA is shown, the opponent and the clock stand and the
/// keys do nothing for this long, then the round starts. One place to
/// change it.
pub const start_delay_ms: u32 = 2000;

pub const Phase = enum {
    /// The round runs (the Original's only phase).
    fight,
    /// The controls screen is up.
    screen,
    /// The screen went down: PORRADA until `State.fight_starts_at`.
    intro,
};

/// The screen's and the intro's state, in each fight's `Game`.
pub const State = struct {
    phase: Phase = .fight,
    /// When the screen went up (WM_CREATE).
    shown_at: u32 = 0,
    /// When the intro ends and the round starts (`start_delay_ms` after
    /// the screen went down).
    fight_starts_at: u32 = 0,
    /// The key that took the screen down: its repeats and its release are
    /// kept from the fight.
    held_key: ?u16 = null,

    /// The round has not started: the screen or the intro is up.
    pub fn waiting(st: *const State) bool {
        return st.phase != .fight;
    }
};

pub const Gate = union(enum) {
    /// To the handler (keys translated). `frozen`: the round has not
    /// started, so the handler runs only the message's own case, without
    /// the clock block and the beat.
    pass: struct { m: Msg, frozen: bool },
    /// Handled: nothing to do.
    swallow,
    /// The screen just went down: the intro (PORRADA, `start_delay_ms`)
    /// begins.
    dismissed,
    /// The intro just ended: the round starts now. The fight's clock stamps
    /// move on by these many ms (the time since WM_CREATE), so the round
    /// plays as the original's from its WM_CREATE.
    started: u32,
};

/// Opens the screen (`fight_controls_screen`): from now on `gate` keeps
/// the fight waiting.
pub fn open(st: *State, now: u32) void {
    st.* = .{ .phase = .screen, .shown_at = now };
}

/// The input and the timers, kept from the fight while it waits.
fn isInput(id: u16) bool {
    return switch (id) {
        wm.keydown, wm.keyup, wm.mousemove, wm.lbuttondown, wm.lbuttonup, wm.rbuttondown, wm.rbuttonup, wm.systimer => true,
        else => false,
    };
}

pub fn gate(st: *State, fixes: Fixes, m: Msg, now: u32) Gate {
    switch (st.phase) {
        .screen => switch (m.id) {
            // Any key (Enter, Space, a pad button) or a click.
            wm.keydown, wm.lbuttondown, wm.rbuttondown => {
                st.phase = .intro;
                st.fight_starts_at = now +% start_delay_ms;
                st.held_key = if (m.id == wm.keydown) m.wparam else null;
                return .dismissed;
            },
            else => return if (isInput(m.id)) .swallow else .{ .pass = .{ .m = m, .frozen = true } },
        },
        .intro => if (@as(i32, @bitCast(now -% st.fight_starts_at)) >= 0) {
            // This message (whatever it is) is the round's first.
            st.phase = .fight;
            return .{ .started = now -% st.shown_at };
        } else {
            if (m.id == wm.keyup and st.held_key == m.wparam) st.held_key = null;
            return if (isInput(m.id)) .swallow else .{ .pass = .{ .m = m, .frozen = true } };
        },
        .fight => {},
    }
    if (st.held_key) |k| if ((m.id == wm.keydown or m.id == wm.keyup) and m.wparam == k) {
        if (m.id == wm.keyup) st.held_key = null;
        return .swallow;
    };
    var out = m;
    if (fixes.fight_keys_asdf and (m.id == wm.keydown or m.id == wm.keyup)) out.wparam = translate(m.wparam);
    return .{ .pass = .{ .m = out, .frozen = false } };
}

// ---- the screen ----------------------------------------------------------

pub const Fight = enum { salgin, xilindro };

/// The panel, in the window (and backdrop) coordinates: under the clock and
/// the energy bar (y 20-38), over most of the arena band.
pub const panel = struct {
    pub const x: i16 = 100;
    pub const y: i16 = 60;
    pub const w: i16 = 440;
    pub const h: i16 = 368;
};

const Row = screen.Row;

/// The fair fight's overlay (`fight_fair.zig`) draws with the screen's helpers.
pub const nearest = screen.nearest;
pub const fill = screen.fill;

// The texts are Windows-1252 (the system font's), not UTF-8.
fn rows(fight: Fight, asdf: bool) []const Row {
    const walk: Row = .{ .caps = &.{ .left, .right }, .text = "andar" };
    return switch (fight) {
        .xilindro => if (asdf) &[_]Row{
            walk,
            .{ .caps = &.{.up}, .text = "pular" },
            .{ .caps = &.{.down}, .text = "defender" },
            .{ .caps = &.{.a}, .text = "soco" },
            .{ .caps = &.{.s}, .text = "chute m\xe9dio" },
            .{ .caps = &.{.d}, .text = "chute alto" },
            .{ .caps = &.{.f}, .text = "rasteira" },
        } else &[_]Row{
            walk,
            .{ .caps = &.{.insert}, .text = "pular" },
            .{ .caps = &.{.end}, .text = "defender" },
            .{ .caps = &.{.pgup}, .text = "soco" },
            .{ .caps = &.{.up}, .text = "chute m\xe9dio" },
            .{ .caps = &.{.home}, .text = "chute alto" },
            .{ .caps = &.{.down}, .text = "rasteira" },
        },
        .salgin => if (asdf) &[_]Row{
            walk,
            .{ .caps = &.{.up}, .text = "pular" },
            .{ .caps = &.{.down}, .text = "defender" },
            .{ .caps = &.{.a}, .text = "soco" },
            .{ .caps = &.{.s}, .text = "voadora" },
            .{ .caps = &.{.d}, .text = "salto (chute pulando)" },
            .{ .caps = &.{.f}, .text = "rasteira" },
        } else &[_]Row{
            walk,
            .{ .caps = &.{.insert}, .text = "pular" },
            .{ .caps = &.{.end}, .text = "defender" },
            .{ .caps = &.{.pgup}, .text = "soco" },
            .{ .caps = &.{.up}, .text = "voadora" },
            .{ .caps = &.{.home}, .text = "salto (chute pulando)" },
            .{ .caps = &.{.down}, .text = "rasteira" },
        },
    };
}

fn title(fight: Fight) []const u8 {
    return switch (fight) {
        .xilindro => "XILINDRO",
        .salgin => "PORRADA NA SALA DE GIN\xc1STICA",
    };
}

const goal = [_][]const u8{
    "Ven\xe7a por nocaute, ou tenha pelo menos tanta",
    "energia quanto o advers\xe1rio quando o rel\xf3gio",
    "de 90 segundos chegar a zero.",
};

/// Draws the screen into `s` (the backdrop): `controls_screen.draw` with
/// the fight's name, its moves and the goal.
pub fn draw(plat: Platform, s: Surface, fight: Fight, asdf: bool) void {
    screen.draw(plat, s, .{
        .panel = .{ .x = panel.x, .y = panel.y, .w = panel.w, .h = panel.h },
        .title = title(fight),
        .rows = rows(fight, asdf),
        .goal = &goal,
    });
}

test "the new keys do the 1995 keys' moves" {
    try std.testing.expectEqual(vk_insert, translate(vk_up));
    try std.testing.expectEqual(vk_end, translate(vk_down));
    try std.testing.expectEqual(vk_pgup, translate(vk_a));
    try std.testing.expectEqual(vk_up, translate(vk_s));
    try std.testing.expectEqual(vk_home, translate(vk_d));
    try std.testing.expectEqual(vk_down, translate(vk_f));
    try std.testing.expectEqual(@as(u16, 0x25), translate(0x25));
    try std.testing.expectEqual(vk_pgup, translate(vk_pgup));
}

test "untranslate undoes translate for the eight moves" {
    for ([_]u16{ vk_insert, vk_end, vk_pgup, vk_up, vk_home, vk_down, 0x25, 0x27 }) |k| {
        try std.testing.expectEqual(k, translate(untranslate(k)));
    }
}

test "the screen and the intro keep the fight, then the round starts" {
    var st: State = .{};
    const on = Fixes.all();
    open(&st, 1000);
    try std.testing.expectEqual(Gate.swallow, gate(&st, on, .{ .id = wm.systimer }, 1050));
    const act = gate(&st, on, .{ .id = wm.activate, .wparam = 1 }, 1060);
    try std.testing.expect(act.pass.frozen);
    try std.testing.expectEqual(Gate.dismissed, gate(&st, on, .{ .id = wm.keydown, .wparam = 0x0d }, 1250));
    // The intro: keys and timers do nothing.
    try std.testing.expectEqual(Gate.swallow, gate(&st, on, .{ .id = wm.keydown, .wparam = vk_s }, 1300));
    try std.testing.expectEqual(Gate.swallow, gate(&st, on, .{ .id = wm.keyup, .wparam = vk_s }, 1350));
    try std.testing.expectEqual(Gate.swallow, gate(&st, on, .{ .id = wm.systimer }, 3200));
    try std.testing.expectEqual(@as(u32, 2250), gate(&st, on, .{ .id = wm.systimer }, 3250).started);
    // Enter was held: its repeat and release stay out of the fight.
    try std.testing.expectEqual(Gate.swallow, gate(&st, on, .{ .id = wm.keydown, .wparam = 0x0d }, 3280));
    try std.testing.expectEqual(Gate.swallow, gate(&st, on, .{ .id = wm.keyup, .wparam = 0x0d }, 3300));
    const s = gate(&st, on, .{ .id = wm.keydown, .wparam = vk_s }, 3400);
    try std.testing.expect(!s.pass.frozen);
    try std.testing.expectEqual(vk_up, s.pass.m.wparam);
    const orig = gate(&st, .{}, .{ .id = wm.keydown, .wparam = vk_up }, 3500);
    try std.testing.expectEqual(vk_up, orig.pass.m.wparam);
}
