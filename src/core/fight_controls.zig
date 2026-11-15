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

// ---- the screen ------------------------------------------------------------

pub const Fight = enum { salgin, xilindro };

/// The panel, in the window (and backdrop) coordinates: under the clock and
/// the energy bar (y 20-38), over most of the arena band.
pub const panel = struct {
    pub const x: i16 = 100;
    pub const y: i16 = 60;
    pub const w: i16 = 440;
    pub const h: i16 = 368;
};

const Cap = enum { left, right, up, down, a, s, d, f, pgup, home, end, insert };

const Row = struct { caps: []const Cap, text: []const u8 };

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
const start_text = "Aperte uma tecla ou clique para come\xe7ar";

// COLORREFs (0x00BBGGRR), matched to the backdrop's palette.
const yellow: u32 = 0x0000ffff; // the clock's
const white: u32 = 0x00ffffff;
const grey: u32 = 0x00c0c0c0;
const cap_fill: u32 = 0x00303030;

/// The palette index nearest to `color` (a COLORREF), as GDI picks it.
pub fn nearest(colors: *const [256]platform.RgbQuad, color: u32) u8 {
    const r: i32 = @intCast(color & 0xff);
    const g: i32 = @intCast(color >> 8 & 0xff);
    const b: i32 = @intCast(color >> 16 & 0xff);
    var best: u8 = 0;
    var best_d: i32 = std.math.maxInt(i32);
    for (colors, 0..) |q, i| {
        const dr = r - q.red;
        const dg = g - q.green;
        const db = b - q.blue;
        const d = dr * dr + dg * dg + db * db;
        if (d < best_d) {
            best_d = d;
            best = @intCast(i);
        }
    }
    return best;
}

fn pixel(s: Surface, x: i32, y: i32) ?*u8 {
    if (x < 0 or y < 0 or x >= s.width or y >= s.height) return null;
    const row: usize = @intCast(if (s.bottom_up) @as(i32, s.height) - 1 - y else y);
    const i = row * s.stride() + @as(usize, @intCast(x));
    return if (i < s.pixels.len) &s.pixels[i] else null;
}

pub fn fill(s: Surface, x: i32, y: i32, w: i32, h: i32, index: u8) void {
    var j: i32 = y;
    while (j < y + h) : (j += 1) {
        var i: i32 = x;
        while (i < x + w) : (i += 1) if (pixel(s, i, j)) |p| {
            p.* = index;
        };
    }
}

fn frame(s: Surface, x: i32, y: i32, w: i32, h: i32, t: i32, index: u8) void {
    fill(s, x, y, w, t, index);
    fill(s, x, y + h - t, w, t, index);
    fill(s, x, y, t, h, index);
    fill(s, x + w - t, y, t, h, index);
}

/// Darkens the rectangle: every pixel to the palette's nearest colour at a
/// fifth of its brightness.
fn dim(s: Surface, x: i32, y: i32, w: i32, h: i32) void {
    var lut: [256]u8 = undefined;
    for (&lut, s.colors) |*l, q| {
        const c = @as(u32, q.red / 5) | @as(u32, q.green / 5) << 8 | @as(u32, q.blue / 5) << 16;
        l.* = nearest(s.colors, c);
    }
    var j: i32 = y;
    while (j < y + h) : (j += 1) {
        var i: i32 = x;
        while (i < x + w) : (i += 1) if (pixel(s, i, j)) |p| {
            p.* = lut[p.*];
        };
    }
}

fn textWidth(plat: Platform, t: []const u8) i32 {
    return @intCast(plat.textExtent(t) & 0xffff);
}

fn text(plat: Platform, s: Surface, x: i32, y: i32, color: u32, t: []const u8) void {
    _ = plat.textOut(s, .{ .color = color, .bk_mode = .transparent }, @intCast(x), @intCast(y), t);
}

fn centred(plat: Platform, s: Surface, y: i32, color: u32, t: []const u8) void {
    text(plat, s, panel.x + @divTrunc(panel.w - textWidth(plat, t), 2), y, color, t);
}

/// An arrow (a filled triangle) pointing `dir`, centred on (cx, cy).
fn arrow(s: Surface, cx: i32, cy: i32, dir: Cap, index: u8) void {
    var k: i32 = 0;
    while (k < 6) : (k += 1) {
        // Row k of the triangle: 2k+1 pixels wide, from the tip.
        switch (dir) {
            .left => fill(s, cx - 3 + k, cy - k, 1, 2 * k + 1, index),
            .right => fill(s, cx + 3 - k, cy - k, 1, 2 * k + 1, index),
            .up => fill(s, cx - k, cy - 3 + k, 2 * k + 1, 1, index),
            .down => fill(s, cx - k, cy + 3 - k, 2 * k + 1, 1, index),
            else => unreachable,
        }
    }
}

const cap_h: i32 = 22;

fn capLabel(c: Cap) []const u8 {
    return switch (c) {
        .a => "A",
        .s => "S",
        .d => "D",
        .f => "F",
        .pgup => "PgUp",
        .home => "Home",
        .end => "End",
        .insert => "Insert",
        .left, .right, .up, .down => "",
    };
}

/// A key cap at (x, y); its width.
fn cap(plat: Platform, s: Surface, x: i32, y: i32, c: Cap, fh: i32) i32 {
    const label = capLabel(c);
    const w: i32 = if (label.len == 0) 26 else @max(26, textWidth(plat, label) + 12);
    fill(s, x, y, w, cap_h, nearest(s.colors, cap_fill));
    frame(s, x, y, w, cap_h, 1, nearest(s.colors, grey));
    if (label.len == 0) {
        arrow(s, x + @divTrunc(w, 2), y + @divTrunc(cap_h, 2), c, nearest(s.colors, white));
    } else {
        text(plat, s, x + @divTrunc(w - textWidth(plat, label), 2), y + @divTrunc(cap_h - fh, 2), white, label);
    }
    return w;
}

/// Draws the screen into `s` (the backdrop): the panel darkened, a yellow
/// frame, the fight's name, a key cap and what it does per move, the goal
/// and how to start, in the system font (as the clock).
pub fn draw(plat: Platform, s: Surface, fight: Fight, asdf: bool) void {
    const fh: i32 = @intCast(plat.textExtent("A") >> 16);
    dim(s, panel.x, panel.y, panel.w, panel.h);
    frame(s, panel.x + 4, panel.y + 4, panel.w - 8, panel.h - 8, 2, nearest(s.colors, yellow));
    var y: i32 = panel.y + 18;
    centred(plat, s, y, yellow, title(fight));
    y += fh + 4;
    centred(plat, s, y, grey, "Controles");
    y += fh + 14;
    const caps_x: i32 = panel.x + 70;
    const text_x: i32 = panel.x + 180;
    for (rows(fight, asdf)) |r| {
        var x = caps_x;
        for (r.caps) |c| x += cap(plat, s, x, y, c, fh) + 6;
        text(plat, s, text_x, y + @divTrunc(cap_h - fh, 2), white, r.text);
        y += cap_h + 6;
    }
    y += 10;
    for (goal) |line| {
        centred(plat, s, y, white, line);
        y += fh + 2;
    }
    centred(plat, s, panel.y + panel.h - 18 - fh, yellow, start_text);
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
