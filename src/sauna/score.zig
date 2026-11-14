//! Port unit `score` (module) of SAUNA.EXE. the score and its waves: a peanut (+100), a ghost eaten (+500), a life lost (-500, the third sends WM_DESTROY), the power waves, the score box (BUGS.md P8).
//!
//! See docs/sauna/DESIGN.md "How to port a SAUNA unit". Each function
//! carries `// @orig <seg:xxxx> <name>` with the SAUNA address.

const std = @import("std");
const platform = @import("../platform/platform.zig");
const msg = @import("../core/msg.zig");
const Game = @import("core/game.zig").Game;
const world = @import("core/world.zig");
const Backdrop = world.Backdrop;
const dib = @import("dib.zig");
const sound = @import("sound.zig");

// @orig 1080:4082 sauna_eat_ghost
/// A ghost is eaten: `pacman4.wav`, score + 500 (no clamp), the box. The
/// ghost is moved by the caller. hwnd/hdc dropped (the platform's screen).
pub fn eatGhost(g: *Game, bd: *Backdrop) void {
    _ = sound.play(g, 0, g.eatGhostWave);
    g.score +%= 500;
    drawScore(g, bd);
    blitScoreBox(g, bd);
}

// @orig 1080:40e3 sauna_power_waves
/// A cork was eaten: `pacman2.wav` once, then `control.wav` looped; the loop
/// is the one with a notify window (any non-zero hwnd; the port has one).
pub fn powerWaves(g: *Game) void {
    _ = sound.play(g, 0, g.powerWave);
    _ = sound.playLoop(g, 1, g.powerLoopWave);
}

// @orig 1080:411c sauna_eat_peanut
/// A peanut was eaten: `pacman.wav`, score + 100, the box.
pub fn eatPeanut(g: *Game, bd: *Backdrop) void {
    _ = sound.play(g, 0, g.eatPeanutWave);
    g.score +%= 100;
    drawScore(g, bd);
    blitScoreBox(g, bd);
}

// @orig 1080:417c sauna_lose_life
/// Pacman was caught: `pacman3.wav`, `--lives`; at 0 SendMessage(WM_DESTROY)
/// (the loss; no -500, and the rest of this function still runs), else
/// score - 500. Then the box.
pub fn loseLife(g: *Game, bd: *Backdrop) void {
    _ = sound.play(g, 0, g.caughtWave);
    g.lives -%= 1;
    if (g.lives == 0) {
        _ = g.send(.{ .id = msg.wm.destroy });
    } else {
        g.score -%= 500;
    }
    drawScore(g, bd);
    blitScoreBox(g, bd);
}

// @orig 1080:41fd sauna_power_stop_wave
/// End of power: flushes `control.wav`'s channel (hwnd ignored by the original).
pub fn powerStopWave(g: *Game) void {
    sound.stop(g, g.powerLoopWave);
}

// @orig 1080:4221 sauna_blit_score_box
/// WinGBitBlt of the 192 x 20 score box at (416, 437) from the backdrop to
/// the window (the palette calls are the platform's).
pub fn blitScoreBox(g: *Game, bd: *Backdrop) void {
    g.plat.wingBitBlt(0x1a0, 0x1b5, 0xc0, 0x14, bd.surface(), 0x1a0, 0x1b5);
}

// @orig 1080:426e sauna_draw_score
/// Restores the score box (416, 437, 192 x 20) from the background onto the
/// backdrop (key `g_transparentColor`), then draws `sprintf(" %04d", score)`
/// or, for a negative score, `sprintf("-%04d", -score)`, one `TextOut` per
/// character (the leading space too) at x = 460 + 32 i, y = 445, near white
/// (0xEDEEEE), transparent.
pub fn drawScore(g: *Game, bd: *Backdrop) void {
    if (bd.background) |bg| {
        if (bd.pixels.len != 0) {
            _ = dib.copyTransparent(&bd.bmiHeader, bd.pixels, 0x1a0, 0x1b5, bg.bits, &bg.header, 0x1a0, 0x1b5, 0xc0, 0x14, @truncate(g.transparentColor)) catch |e|
                std.debug.panic("sauna score: score box restore left its buffers ({s})", .{@errorName(e)});
        }
    }
    const style: platform.TextStyle = .{ .color = 0xedeeee, .bk_mode = .transparent };
    var buf: [16]u8 = undefined;
    const text = formatScore(&buf, g.score);
    var x: i16 = 0x1cc;
    for (0..text.len) |i| {
        _ = g.plat.textOut(bd.surface(), style, x, 0x1bd, text[i..][0..1]);
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
