//! The fights' smooth motion (SALGIN and XILINDRO, which share the engine;
//! a Corrigida addition, `fight_smooth_motion`, the owner's decision; not a
//! port unit, no original code). The presentation-only mechanism of TIRO's
//! `tiro/smooth.zig`: the host asks for the picture to present
//! (`host.Program.view`, at the backend's frame rate) and gets a copy of
//! the window's screen in which the arena band is rebuilt with each fighter
//! drawn between where the screen last showed it and where it is now.
//!
//! Every move of a fighter happens in one go: the walk's 32-px step per
//! 200-ms beat (the opponent's approach, the fighter's step per press), the
//! opponent's 100-px jump back after its move or a reel, XILINDRO's 100-px
//! recoil after a landed blow, the Right clamp. The screen shows a move only
//! when `redrawArena` (the beat, a key-up, an end tick) restores the band
//! and blits it, so that is where `noteDrawn` sees it: the fighter's x
//! changed since the last redraw. The move is then shown over one beat
//! (`beat_ms`) from where the picture showed the fighter at that moment
//! (so a move that starts while another is shown carries on from it):
//! - a step (at most `step_px`) linearly: consecutive steps chain into a
//!   constant walking speed (32 px per 200 ms, 160 px/s);
//! - a jump (more than `step_px`: the jump back, the recoil, the clamp)
//!   eased out: it leaves at once and fast, as the blow or the end of the
//!   move that caused it, and slows into its landing, which reads as a hop
//!   rather than a slide; spread linearly the 100 px would look like a
//!   fast walk with no walking frames.
//! The picture lags the game by at most one beat. The animation frames are
//! the game's, one per beat (there is no in-between art). The positions,
//! reach checks, hits, energies, timers, randomness and results are the
//! game's: nothing here writes game state, and the screen and the backdrop
//! are never drawn into.
//!
//! The picture: the band (y 0x8c, 640 x 0x127) is rebuilt as
//! `redrawArena` does it, in a scratch copy of the backdrop (the band as it
//! is, the background band over it with the sprite key, the PORRADA banner
//! while it shows, the opponent, the fighter in front), then copied over a
//! copy of the screen. The clock, the energy tiles and the F9 overlay lie
//! above the band and come from the screen as the game drew them.

const std = @import("std");
const platform = @import("../platform/platform.zig");
const Screen = platform.Screen;

/// One beat: the handler's (`> 199` ms since the last; the 50-ms timer
/// makes it 200 ms).
pub const beat_ms: u32 = 200;
/// The longest move shown as a walking step; anything longer is a jump.
pub const step_px: i16 = 32;

/// `redrawArena`'s band: y 0x8c, 640 x 0x127.
pub const band_y: i16 = 0x8c;
pub const band_w: i16 = 0x280;
pub const band_h: i16 = 0x127;

/// One fighter's last move as the screen showed it.
pub const Track = struct {
    valid: bool = false,
    /// Where the picture showed it when the move was drawn.
    from: i16 = 0,
    /// Its x then (the game's).
    to: i16 = 0,
    /// When (the platform's ticks).
    at: u32 = 0,
    /// A jump (eased out) rather than a step (linear).
    jump: bool = false,

    /// `redrawArena` draws the fighter at `x`: a move if it moved.
    pub fn note(t: *Track, x: i16, now: u32) void {
        if (!t.valid) {
            t.* = .{ .valid = true, .from = x, .to = x, .at = now };
            return;
        }
        if (x == t.to) return;
        const from = t.shownAt(now) orelse t.to;
        const d = @as(i32, x) - t.to;
        t.* = .{ .valid = true, .from = from, .to = x, .at = now, .jump = @abs(d) > step_px };
    }

    /// Where it is shown at `now`, or null: at its x (no move shown).
    pub fn shownAt(t: *const Track, now: u32) ?i16 {
        if (!t.valid or t.from == t.to) return null;
        const since: i32 = @bitCast(now -% t.at);
        if (since < 0 or since >= beat_ms) return null;
        const p = progress(since, t.jump);
        const x = t.from + @divTrunc((@as(i32, t.to) - t.from) * p, 1024);
        if (x == t.to) return null;
        return @intCast(x);
    }
};

/// The fraction (of 1024) of the move made `since` ms into the beat: linear
/// for a step, ease-out (quadratic, 1 - (1 - s)^2) for a jump.
pub fn progress(since: i32, jump: bool) i32 {
    const s = @divTrunc(since * 1024, @as(i32, beat_ms));
    if (!jump) return s;
    const r = 1024 - s;
    return 1024 - @divTrunc(r * r, 1024);
}

/// Each fight's `Game.smooth`.
pub const State = struct {
    fighter: Track = .{},
    opponent: Track = .{},
    /// The presented picture and a scratch copy of the backdrop's bitmap,
    /// made at the first `view` that needs them.
    screen: ?*Screen = null,
    scratch: []u8 = &.{},

    pub fn deinit(s: *State, gpa: std.mem.Allocator) void {
        if (s.screen) |scr| gpa.destroy(scr);
        gpa.free(s.scratch);
        s.* = .{};
    }
};

/// `redrawArena` drew both fighters (`fight_smooth_motion` only).
pub fn noteDrawn(s: *State, fighter_x: i16, opponent_x: i16, now: u32) void {
    s.fighter.note(fighter_x, now);
    s.opponent.note(opponent_x, now);
}

/// The picture to present at `now` (`host.Program.view`) for a fight's
/// game `g`, or null for the screen itself: the flag is off, the controls
/// screen is up, or no fighter is between two positions. `P` is the
/// program's namespace: `render.drawDirtyTo`, `dib.copyTransparent` and
/// `hud.bannerShown`.
pub fn view(comptime P: type, g: anytype, now: u32) ?*const Screen {
    if (!g.fixes.fight_smooth_motion) return null;
    if (g.controls.phase == .screen) return null;
    const s = &g.smooth;
    const f = g.fighter orelse return null;
    const o = g.opponent orelse return null;
    const fx = s.fighter.shownAt(now);
    const ox = s.opponent.shownAt(now);
    if (fx == null and ox == null) return null;
    const scene = g.scene orelse return null;
    const bd = scene.backdrop orelse return null;
    const bg = bd.background orelse return null;
    if (bd.pixels.len == 0) return null;

    if (s.screen == null) s.screen = g.gpa.create(Screen) catch return null;
    if (s.scratch.len != bd.pixels.len) {
        g.gpa.free(s.scratch);
        s.scratch = g.gpa.alloc(u8, bd.pixels.len) catch {
            s.scratch = &.{};
            return null;
        };
    }
    const layout = Layout.of(bd.bmiHeader.biWidth, bd.bmiHeader.biHeight);
    const y0: i32 = band_y;
    const y1: i32 = @min(@as(i32, band_y) + band_h, layout.height);
    // The band as the backdrop holds it, then `redrawArena`'s restore.
    var y = y0;
    while (y < y1) : (y += 1) {
        const off = layout.offset(0, y);
        const len = @min(layout.stride, s.scratch.len - off);
        @memcpy(s.scratch[off..][0..len], bd.pixels[off..][0..len]);
    }
    _ = P.dib.copyTransparent(&bd.bmiHeader, s.scratch, 0, band_y, bg.bits, &bg.header, 0, band_y, band_w, band_h, g.unk00A8) catch return null;
    if (P.hud.bannerShown(g, scene)) {
        if (g.banner) |b| P.render.drawDirtyTo(g, b, &bd.bmiHeader, s.scratch);
    }
    drawAt(P, g, bd, o, ox);
    drawAt(P, g, bd, f, fx);

    const out = s.screen.?;
    const scr = g.plat.screen();
    out.pixels = scr.pixels;
    out.palette = scr.palette;
    out.overlay = scr.overlay;
    y = y0;
    while (y < y1) : (y += 1) {
        const sy = y - bd.originY;
        if (sy < 0 or sy >= platform.screen_height) continue;
        const row = layout.offset(0, y);
        const w: usize = @intCast(@min(layout.width, platform.screen_width));
        const dst = @as(usize, @intCast(sy)) * platform.screen_width;
        if (bd.originX != 0 or row + w > s.scratch.len) continue;
        @memcpy(out.pixels[dst..][0..w], s.scratch[row..][0..w]);
    }
    return out;
}

/// The fighter's current frame drawn into the scratch bitmap at `x` (its
/// own x when null), on a copy of it (the game's object is not touched).
fn drawAt(comptime P: type, g: anytype, bd: anytype, obj: anytype, x: ?i16) void {
    var copy = obj.*;
    if (x) |v| copy.x = v;
    P.render.drawDirtyTo(g, &copy, &bd.bmiHeader, g.smooth.scratch);
}

/// An 8-bit DIB's rows: 4-byte aligned, bottom-up for a positive height.
const Layout = struct {
    width: i32,
    height: i32,
    stride: usize,
    bottom_up: bool,

    fn of(w: i32, h: i32) Layout {
        return .{
            .width = w,
            .height = @intCast(@abs(h)),
            .stride = (@as(usize, @intCast(w)) + 3) & ~@as(usize, 3),
            .bottom_up = h > 0,
        };
    }

    /// The byte of pixel (x, y), y counted from the top.
    fn offset(l: Layout, x: i32, y: i32) usize {
        const row: usize = @intCast(if (l.bottom_up) l.height - 1 - y else y);
        return row * l.stride + @as(usize, @intCast(x));
    }
};

test "a step is shown linearly over the beat" {
    var t: Track = .{};
    t.note(200, 1000);
    try std.testing.expectEqual(@as(?i16, null), t.shownAt(1050));
    t.note(168, 1000);
    try std.testing.expectEqual(@as(?i16, 200), t.shownAt(1000));
    try std.testing.expectEqual(@as(?i16, 184), t.shownAt(1100));
    try std.testing.expectEqual(@as(?i16, 176), t.shownAt(1150));
    try std.testing.expectEqual(@as(?i16, null), t.shownAt(1200));
}

test "a jump is eased out and a new move starts where the picture is" {
    var t: Track = .{};
    t.note(300, 0);
    t.note(400, 0);
    try std.testing.expect(t.jump);
    // Half the beat: three quarters of the way.
    try std.testing.expectEqual(@as(?i16, 375), t.shownAt(100));
    // A step back interrupts it at 375: it starts there, linear.
    t.note(368, 100);
    try std.testing.expectEqual(@as(?i16, 375), t.shownAt(100));
    try std.testing.expect(!t.jump);
}
