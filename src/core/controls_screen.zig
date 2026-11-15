//! The Corrigida's controls screens (not port units, no original code): a
//! darkened panel with a yellow frame, the game's name, one key cap (or a
//! few) and what it does per row, the goal and how to start, in the system
//! font, drawn into a program's 8-bit surface with its own palette. The
//! fights (`fight_controls.zig`) and JARDIM (`jardim/controls.zig`) each
//! give it their rows; when and how the screen goes is theirs.

const std = @import("std");
const platform = @import("../platform/platform.zig");
const Platform = platform.Platform;
const Surface = platform.Surface;

pub const Rect = struct { x: i16, y: i16, w: i16, h: i16 };

/// A key cap: an arrow, or a key named by its label.
pub const Cap = enum { left, right, up, down, a, s, d, f, w, e, q, n1, n2, n3, pgup, home, end, insert, shift, ctrl, space, esc };

pub const Row = struct { caps: []const Cap, text: []const u8 };

/// What one screen shows. The texts are Windows-1252 (the system font's),
/// not UTF-8.
pub const Spec = struct {
    panel: Rect,
    title: []const u8,
    subtitle: []const u8 = "Controles",
    rows: []const Row,
    /// The caps' column and the texts' column, from the panel's left.
    caps_x: i16 = 70,
    text_x: i16 = 180,
    /// Space between the rows.
    row_gap: i16 = 6,
    goal: []const []const u8,
    start: []const u8 = start_text,
};

pub const start_text = "Aperte uma tecla ou clique para come\xe7ar";

// COLORREFs (0x00BBGGRR), matched to the surface's palette.
const yellow: u32 = 0x0000ffff;
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

fn centred(plat: Platform, s: Surface, r: Rect, y: i32, color: u32, t: []const u8) void {
    text(plat, s, r.x + @divTrunc(r.w - textWidth(plat, t), 2), y, color, t);
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

pub const cap_h: i32 = 22;

fn capLabel(c: Cap) []const u8 {
    return switch (c) {
        .a => "A",
        .s => "S",
        .d => "D",
        .f => "F",
        .w => "W",
        .e => "E",
        .q => "Q",
        .n1 => "1",
        .n2 => "2",
        .n3 => "3",
        .pgup => "PgUp",
        .home => "Home",
        .end => "End",
        .insert => "Insert",
        .shift => "Shift",
        .ctrl => "Ctrl",
        .space => "Espa\xe7o",
        .esc => "Esc",
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

/// Draws the screen into `s`: the panel darkened, a yellow frame, the
/// title, "Controles", a row of caps and its text per row, the goal and
/// how to start.
pub fn draw(plat: Platform, s: Surface, spec: Spec) void {
    const r = spec.panel;
    const fh: i32 = @intCast(plat.textExtent("A") >> 16);
    dim(s, r.x, r.y, r.w, r.h);
    frame(s, r.x + 4, r.y + 4, r.w - 8, r.h - 8, 2, nearest(s.colors, yellow));
    var y: i32 = r.y + 18;
    centred(plat, s, r, y, yellow, spec.title);
    y += fh + 4;
    centred(plat, s, r, y, grey, spec.subtitle);
    y += fh + 14;
    const caps_x: i32 = r.x + spec.caps_x;
    const text_x: i32 = r.x + spec.text_x;
    for (spec.rows) |row| {
        var x = caps_x;
        for (row.caps) |c| x += cap(plat, s, x, y, c, fh) + 6;
        text(plat, s, text_x, y + @divTrunc(cap_h - fh, 2), white, row.text);
        y += cap_h + spec.row_gap;
    }
    y += 10;
    for (spec.goal) |line| {
        centred(plat, s, r, y, white, line);
        y += fh + 2;
    }
    centred(plat, s, r, r.y + r.h - 18 - fh, yellow, spec.start);
}
