//! Port unit `score` (module) of INFERNO.EXE. the score box and its changes:
//! inferno_lose_life (-500, a life, WM_DESTROY at 0: BUGS.md H3),
//! +150/+300/+100, blit and draw.
//!
//! See docs/inferno/DESIGN.md "How to port an INFERNO unit". Each function
//! carries `// @orig <seg:xxxx> <name>` with the INFERNO address.

const std = @import("std");
const platform = @import("../platform/platform.zig");
const dib = @import("dib.zig");
const sound = @import("sound.zig");
const msg = @import("../core/msg.zig");
const Msg = msg.Msg;
const Game = @import("core/game.zig").Game;
const object = @import("core/object.zig");
const Object = object.Object;
const ObjectList = object.ObjectList;
const Frame = object.Frame;
const FrameCell = object.FrameCell;
const BitmapInfoHeader = object.BitmapInfoHeader;
const world = @import("core/world.zig");
const Backdrop = world.Backdrop;
const Scene = world.Scene;
const Condition = world.Condition;
const RectQuery = world.RectQuery;

// @orig 1068:58b2 inferno_lose_life
/// A hazard hit: `sonicmor.wav`, score - 500 (16-bit, no clamp: it goes
/// negative), the box, one life less; at 0 the game posts itself WM_DESTROY
/// (BUGS.md H3: no 0x40a, NOITE sees the window gone). There is no test for
/// 0 first: a call at 0 lives gives -1 and posts nothing. With
/// `inferno_loss_reports` the loss reports (0, score - 1000) first. hwnd
/// dropped.
pub fn loseLife(g: *Game, bd: *Backdrop) void {
    _ = sound.play(g, 0, g.deathWave);
    g.score -%= 500;
    drawScore(g, bd);
    blitScoreBox(g, bd);
    g.lives -%= 1;
    if (g.lives == 0) {
        if (g.fixes.inferno_loss_reports and g.noiteWnd != 0) {
            _ = g.plat.postTo(g.noiteWnd, .{ .id = msg.noite.minigame_result, .wparam = 0, .lparam = @as(i32, g.score) - 1000 });
        }
        _ = g.post(.{ .id = msg.wm.destroy });
    }
}

// @orig 1068:5930 inferno_score_add_150
/// `sonicpul.wav`, score + 150, the box (hwnd dropped).
pub fn add150(g: *Game, bd: *Backdrop) void {
    _ = sound.play(g, 0, g.pickupWave);
    g.score +%= 150;
    drawScore(g, bd);
    blitScoreBox(g, bd);
}

// @orig 1068:5991 inferno_score_add_300
/// `sonicmag.wav`, score + 300, the box (hwnd dropped).
pub fn add300(g: *Game, bd: *Backdrop) void {
    _ = sound.play(g, 0, g.magWave);
    g.score +%= 300;
    drawScore(g, bd);
    blitScoreBox(g, bd);
}

// @orig 1068:59f2 inferno_score_add_100
/// `sonicpul.wav` (its second handle), score + 100, the box (hwnd dropped).
pub fn add100(g: *Game, bd: *Backdrop) void {
    _ = sound.play(g, 0, g.pickupWave2);
    g.score +%= 100;
    drawScore(g, bd);
    blitScoreBox(g, bd);
}

// @orig 1068:5a52 inferno_blit_score_box
/// WinGBitBlt of the 192 x 32 score box at (416, 400) from the backdrop to
/// the window (the palette calls and the DC are the platform's).
pub fn blitScoreBox(g: *Game, bd: *Backdrop) void {
    g.plat.wingBitBlt(0x1a0, 400, 0xc0, 0x20, bd.surface(), 0x1a0, 400);
}

// @orig 1068:5a9f inferno_draw_score
/// Restores the score box (416, 400, 192 x 32) from the background onto the
/// backdrop (key `g_unk0082`), then draws `sprintf(" %04d", score)` or, for
/// a negative score, `sprintf("-%04d", -score)`, one `TextOut` per character
/// (the leading space too) at x = 460 + 32 i, y = 408, near white (0xEDEEEE),
/// transparent.
pub fn drawScore(g: *Game, bd: *Backdrop) void {
    if (bd.background) |bg| {
        if (bd.pixels.len != 0) {
            _ = dib.copyTransparent(&bd.bmiHeader, bd.pixels, 0x1a0, 400, bg.bits, &bg.header, 0x1a0, 400, 0xc0, 0x20, g.unk0082) catch |e|
                std.debug.panic("inferno score: score box restore left its buffers ({s})", .{@errorName(e)});
        }
    }
    const style: platform.TextStyle = .{ .color = 0xedeeee, .bk_mode = .transparent };
    var buf: [16]u8 = undefined;
    const text = formatScore(&buf, g.score);
    var x: i16 = 0x1cc;
    for (0..text.len) |i| {
        _ = g.plat.textOut(bd.surface(), style, x, 0x198, text[i..][0..1]);
        x +%= 0x20;
    }
}

/// `sprintf(text, "-%04d", -score)` or `" %04d"`; for -32768 the negation
/// wraps to -32768 again and `%04d` prints "-32768".
fn formatScore(buf: *[16]u8, score: i16) []const u8 {
    if (score < 0) {
        const v: i16 = 0 -% score;
        const sign: []const u8 = if (v < 0) "-" else "";
        return std.fmt.bufPrint(buf, "-{s}{d:0>4}", .{ sign, @abs(v) }) catch unreachable;
    }
    return std.fmt.bufPrint(buf, " {d:0>4}", .{@as(u16, @intCast(score))}) catch unreachable;
}

test "formatScore is sprintf's" {
    var b: [16]u8 = undefined;
    try std.testing.expectEqualStrings(" 0000", formatScore(&b, 0));
    try std.testing.expectEqualStrings("-0150", formatScore(&b, -150));
    try std.testing.expectEqualStrings("--32768", formatScore(&b, std.math.minInt(i16)));
}

test "every function compiles" {
    std.testing.refAllDecls(@This());
}
