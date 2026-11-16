//! Drawing a fight into an 8-bit, top-down 640x480 picture (the presented
//! `platform.Screen`): the character's palette is mapped to the nearest
//! entries of the screen's palette (the game's own: the minigame's 256
//! colours are fixed), frames are drawn at the character's scale,
//! mirrored when facing left.

const std = @import("std");
const platform = @import("../../platform/platform.zig");
const character = @import("character.zig");
const Character = character.Character;

pub const w = platform.screen_width;
pub const h = platform.screen_height;

pub const Lut = [256]u8;

pub fn nearest(pal: *const [256]platform.Rgb, r: i32, g: i32, b: i32) u8 {
    var best: u8 = 0;
    var best_d: i32 = std.math.maxInt(i32);
    for (pal, 0..) |p, i| {
        const dr = r - p.r;
        const dg = g - p.g;
        const db = b - p.b;
        // A little weight for green, as the eye.
        const d = dr * dr * 3 + dg * dg * 4 + db * db * 2;
        if (d < best_d) {
            best_d = d;
            best = @intCast(i);
        }
    }
    return best;
}

/// The character's palette indices to the screen palette's (index 0, the
/// transparent one, stays 0 and is never drawn).
pub fn buildLut(c: *const Character, pal: *const [256]platform.Rgb, out: *Lut) void {
    out.* = @splat(0);
    for (c.palette(), 0..) |rgb, i| {
        if (i == 0 or i >= 256) continue;
        out[i] = nearest(pal, rgb[0], rgb[1], rgb[2]);
    }
}

/// Draws `f` with its anchor at screen (`x`, `y`) (y the ground), facing
/// right or, with `flip`, left. Out-of-picture pixels are clipped.
pub fn drawFrame(dst: []u8, c: *const Character, lut: *const Lut, f: *const character.Frame, x: i32, y: i32, flip: bool) void {
    // A source pixel covers the destination pixels from the floor of its
    // edge to the floor of the next: no gaps at a fractional scale.
    const s = c.scale_fp;
    const src = c.pixels(f);
    var sy: i32 = 0;
    while (sy < f.h) : (sy += 1) {
        const ry = f.oy + sy;
        const py0 = y + @divFloor(ry * s, 256);
        const py1 = y + @divFloor((ry + 1) * s, 256);
        var sx: i32 = 0;
        while (sx < f.w) : (sx += 1) {
            const v = src[@as(usize, @intCast(sy)) * f.w + @as(usize, @intCast(sx))];
            if (v == 0) continue;
            const rx = f.ox + sx;
            const a = @divFloor(rx * s, 256);
            const b = @divFloor((rx + 1) * s, 256);
            const px0 = if (flip) x - b else x + a;
            const px1 = if (flip) x - a else x + b;
            const col = lut[v];
            var py = @max(py0, 0);
            while (py < @min(py1, h)) : (py += 1) {
                var px = @max(px0, 0);
                while (px < @min(px1, w)) : (px += 1) {
                    dst[@as(usize, @intCast(py)) * w + @as(usize, @intCast(px))] = col;
                }
            }
        }
    }
}

pub fn fillRect(dst: []u8, x0: i32, y0: i32, x1: i32, y1: i32, col: u8) void {
    var y = @max(0, y0);
    while (y < @min(h, y1)) : (y += 1) {
        var x = @max(0, x0);
        while (x < @min(w, x1)) : (x += 1) dst[@as(usize, @intCast(y)) * w + @as(usize, @intCast(x))] = col;
    }
}

pub fn rectOutline(dst: []u8, x0: i32, y0: i32, x1: i32, y1: i32, col: u8) void {
    fillRect(dst, x0, y0, x1, y0 + 1, col);
    fillRect(dst, x0, y1 - 1, x1, y1, col);
    fillRect(dst, x0, y0, x0 + 1, y1, col);
    fillRect(dst, x1 - 1, y0, x1, y1, col);
}
