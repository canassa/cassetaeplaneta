//! Port unit `score` (module) of INV.EXE. g_score and the waves: the 8 wave helpers (+100 invader, +500 saucer, -500 cannon), the score box (inv_draw_score, inv_blit_score_box).
//!
//! See docs/inv/DESIGN.md "How to port an INV unit". Each function
//! carries `// @orig <seg:xxxx> <name>` with the INV address.
//!
//! The far cdecl `(hwnd, backdrop)` helpers take only the backdrop: the
//! GetDC/ReleaseDC pair around the blit has no counterpart (the platform
//! blits to the screen), and the palette calls of the blit are the platform's.

const std = @import("std");
const Game = @import("core/game.zig").Game;
const world = @import("core/world.zig");
const Backdrop = world.Backdrop;
const platform = @import("../platform/platform.zig");
const dib = @import("dib.zig");
const sound = @import("sound.zig");
const Wave = platform.Wave;

fn play(g: *Game, wave: ?Wave) void {
    _ = sound.play(g, 0, wave);
}

// @orig 1068:3304 inv_play_shot_wave
/// `tiroes2.wav`: the shot.
pub fn playShotWave(g: *Game) void {
    play(g, g.shotWave);
}

// @orig 1068:332a inv_score_invader_hit
/// An invader was killed: `explos.wav`, score + 100, the box.
pub fn invaderHit(g: *Game, bd: *Backdrop) void {
    play(g, g.explosWave);
    g.score +%= 100;
    drawScore(g, bd);
    blitScoreBox(g, bd);
}

// @orig 1068:3384 inv_play_explo5_wave
/// `explo5.WAV`: the cannon's shot and a bomb met.
pub fn playExplo5Wave(g: *Game) void {
    play(g, g.explo5Wave);
}

// @orig 1068:33aa inv_score_saucer_hit
/// The saucer was hit: `explo1.wav`, score + 500, the box.
pub fn saucerHit(g: *Game, bd: *Backdrop) void {
    play(g, g.explo1Wave);
    g.score +%= 500;
    drawScore(g, bd);
    blitScoreBox(g, bd);
}

// @orig 1068:3405 inv_score_cannon_hit
/// A bomb hit the cannon: `brocha3.wav`, score - 500 (no clamp: it goes
/// negative), the box.
pub fn cannonHit(g: *Game, bd: *Backdrop) void {
    play(g, g.cannonHitWave);
    g.score -%= 500;
    drawScore(g, bd);
    blitScoreBox(g, bd);
}

// @orig 1068:3460 inv_play_march_wave
/// `marcha.wav`: once per formation tick.
pub fn playMarchWave(g: *Game) void {
    play(g, g.marchWave);
}

// @orig 1068:3486 inv_play_descend_wave
/// `desceniv.wav`: a column descended to a new lowest y.
pub fn playDescendWave(g: *Game) void {
    play(g, g.descendWave);
}

// @orig 1068:34ac inv_play_saucer_wave
/// `nave.wav`: the saucer launches.
pub fn playSaucerWave(g: *Game) void {
    play(g, g.saucerWave);
}

// @orig 1068:34d2 inv_blit_score_box
/// WinGBitBlt of the 192 x 20 score box at (416, 437) from the backdrop to
/// the window (SelectPalette/RealizePalette are the platform's).
pub fn blitScoreBox(g: *Game, bd: *Backdrop) void {
    g.plat.wingBitBlt(0x1a0, 0x1b5, 0xc0, 0x14, bd.surface(), 0x1a0, 0x1b5);
}

// @orig 1068:351d inv_draw_score
/// Restores the score box (416, 437, 192 x 20) from the background onto the
/// backdrop (key `g_unk00A8`), then draws `sprintf(" %04d", score)` or, for
/// a negative score, `sprintf("-%04d", -score)`, one `TextOut` per character
/// (the leading space too) at x = 460 + 32 i, y = 445, colour 0xedeeee,
/// transparent.
pub fn drawScore(g: *Game, bd: *Backdrop) void {
    if (bd.background) |bg| {
        if (bd.pixels.len != 0) {
            _ = dib.copyTransparent(&bd.bmiHeader, bd.pixels, 0x1a0, 0x1b5, bg.bits, &bg.header, 0x1a0, 0x1b5, 0xc0, 0x14, g.unk00A8) catch |e|
                std.debug.panic("inv score: score box restore left its buffers ({s})", .{@errorName(e)});
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
    try std.testing.expectEqualStrings(" 0100", formatScore(&b, 100));
    try std.testing.expectEqualStrings("-0500", formatScore(&b, -500));
    try std.testing.expectEqualStrings("--32768", formatScore(&b, std.math.minInt(i16)));
}
