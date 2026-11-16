//! `Fixes.encaixe_tall_board` (Corrigida, docs/encaixe/GAME.md "Tall board"):
//! a 10 x 20 well of 22-pixel cells, like classic Tetris, instead of the
//! original's 11 x 14 cells of 32 pixels. This file is only for the new
//! rules; the original's board code is untouched and runs without the flag.
//!
//! The well holds the locked cells only (the falling piece is a mask over
//! it, the original writes it into the board). The shapes are the original's
//! `te_piece_spawn_shape` / `te_piece_rotate` cells in the sprite's 4 x 4
//! frame; the sprites (128 x 128 per rotation) are scaled to 88 x 88 once, at
//! load. A move or rotation is refused when a cell would leave the well or
//! enter a locked one (no wall kicks, as in the original; with
//! `Fixes.encaixe_wall_kicks` a blocked rotation tries `kicks`).

const std = @import("std");
const object = @import("core/object.zig");
const Object = object.Object;
const Dib = object.Dib;
const RgbQuad = object.RgbQuad;

pub const cols: i16 = 10;
pub const rows: i16 = 20;
/// Pixels per cell.
pub const cell: i16 = 22;
/// Top-left of the well's inside in the 640 x 480 picture.
pub const origin_x: i16 = 40;
pub const origin_y: i16 = 4;
/// The column of a new piece's 4 x 4 frame (the shapes use 3 or 4 of them).
pub const spawn_col: i16 = 3;
/// Pixels per cell in the "next piece" box.
pub const mini_cell: i16 = 18;
/// The "next piece" box: its frame and the label's top.
pub const box_x: i16 = 272;
pub const box_y: i16 = 16;
pub const box_w: i16 = 96;
pub const box_h: i16 = 100;

/// Cells of each kind and rotation in the 4 x 4 frame: bit `row * 4 + col`.
pub const masks: [6][4]u16 = .{
    .{ 0x2227, 0x08f8, 0x7222, 0x01f1 },
    .{ 0x0027, 0x0232, 0x0072, 0x0131 },
    .{ 0x0223, 0x0074, 0x0311, 0x0017 },
    .{ 0x0113, 0x0047, 0x0322, 0x0071 },
    .{ 0x1111, 0x000f, 0x1111, 0x000f },
    .{ 0x0033, 0x0033, 0x0033, 0x0033 },
};

pub const State = struct {
    /// Locked cells, `board[row][col]`.
    board: [rows][cols]bool = @splat(@splat(false)),
    /// The falling piece's rotation (the sprite's frame follows a tick later).
    rot: u8 = 0,
    /// The picture's well colour (the black the original draws its well in).
    fill: u8 = 0,
    /// The kinds' sprites at `mini_cell`, for the next-piece box.
    mini: [6]?*Dib = @splat(null),
};

fn kindOf(kind: i16) usize {
    return @intCast(std.math.clamp(kind, 0, 5));
}

fn mask(kind: i16, rot: u8) u16 {
    return masks[kindOf(kind)][rot & 3];
}

/// True when the shape fits with its frame's top-left at (col, row).
pub fn fits(s: *const State, kind: i16, rot: u8, col: i16, row: i16) bool {
    const m = mask(kind, rot);
    for (0..4) |r| {
        for (0..4) |c| {
            if (m & (@as(u16, 1) << @intCast(r * 4 + c)) == 0) continue;
            const cc = col + @as(i16, @intCast(c));
            const rr = row + @as(i16, @intCast(r));
            if (cc < 0 or cc >= cols or rr < 0 or rr >= rows) return false;
            if (s.board[@intCast(rr)][@intCast(cc)]) return false;
        }
    }
    return true;
}

/// An offset a blocked rotation is tried at (`Fixes.encaixe_wall_kicks`).
pub const Kick = struct { dx: i16, dy: i16 };

/// The kicks, in order: a column left, a column right, two left, two right
/// (the two-column ones for the long pieces only, kinds 0 and 4), then one
/// row up, up and left, up and right. The first that fits is taken.
pub const kicks = [_]Kick{
    .{ .dx = -1, .dy = 0 }, .{ .dx = 1, .dy = 0 },
    .{ .dx = -2, .dy = 0 }, .{ .dx = 2, .dy = 0 },
    .{ .dx = 0, .dy = -1 }, .{ .dx = -1, .dy = -1 },
    .{ .dx = 1, .dy = -1 },
};

fn isLong(kind: i16) bool {
    const k = kindOf(kind);
    return k == 0 or k == 4;
}

/// The first of `kicks` at which `kind` in rotation `rot` fits from (col, row).
pub fn findKick(s: *const State, kind: i16, rot: u8, col: i16, row: i16) ?Kick {
    for (kicks) |k| {
        if ((k.dx == 2 or k.dx == -2) and !isLong(kind)) continue;
        if (fits(s, kind, rot, col + k.dx, row + k.dy)) return k;
    }
    return null;
}

/// The piece cannot step down.
pub fn resting(s: *const State, obj: *const Object) bool {
    return !fits(s, obj.curStrip, s.rot, obj.piece.column, obj.piece.row + 1);
}

/// One step in `dir` (1 left, 2 right, 4 rotate, 8 down), te_piece_try_step's
/// contract: 1 moved, 0 refused; a down step sets `canFall` to its result.
pub fn step(s: *State, obj: *Object, dir: i16, wall_kicks: bool) i16 {
    const p = &obj.piece;
    p.unk4E = 0;
    switch (dir) {
        1 => {
            if (!fits(s, obj.curStrip, s.rot, p.column - 1, p.row)) return 0;
            p.column -= 1;
        },
        2 => {
            if (!fits(s, obj.curStrip, s.rot, p.column + 1, p.row)) return 0;
            p.column += 1;
        },
        4 => {
            const next = (s.rot + 1) & 3;
            if (!fits(s, obj.curStrip, next, p.column, p.row)) {
                if (!wall_kicks) return 0;
                const k = findKick(s, obj.curStrip, next, p.column, p.row) orelse return 0;
                p.column += k.dx;
                p.row += k.dy;
            }
            s.rot = next;
        },
        8 => {
            const ok = fits(s, obj.curStrip, s.rot, p.column, p.row + 1);
            p.canFall = @intFromBool(ok);
            if (!ok) return 0;
            p.row += 1;
        },
        else => return 0,
    }
    return 1;
}

/// Locks the piece into the well.
pub fn stamp(s: *State, obj: *const Object) void {
    const m = mask(obj.curStrip, s.rot);
    for (0..4) |r| {
        for (0..4) |c| {
            if (m & (@as(u16, 1) << @intCast(r * 4 + c)) == 0) continue;
            const cc = obj.piece.column + @as(i16, @intCast(c));
            const rr = obj.piece.row + @as(i16, @intCast(r));
            if (cc < 0 or cc >= cols or rr < 0 or rr >= rows) continue;
            s.board[@intCast(rr)][@intCast(cc)] = true;
        }
    }
}

pub fn rowFull(s: *const State, row: i16) bool {
    for (s.board[@intCast(row)]) |c| if (!c) return false;
    return true;
}

/// Removes `row`: every row above moves one down, the top one is empty.
pub fn removeRow(s: *State, row: i16) void {
    var r: usize = @intCast(row);
    while (r > 0) : (r -= 1) s.board[r] = s.board[r - 1];
    s.board[0] = @splat(false);
}

/// The piece's top-left on the screen.
pub fn pixelX(col: i16) i16 {
    return origin_x + col * cell;
}

pub fn pixelY(row: i16) i16 {
    return origin_y + row * cell;
}

// ---- pictures ----

fn nearest(colors: *const [256]RgbQuad, r: f32, g: f32, b: f32, skip: ?u8) u8 {
    var best: u8 = 0;
    var best_d: f32 = std.math.floatMax(f32);
    for (colors, 0..) |c, i| {
        if (skip != null and skip.? == i) continue;
        const dr = r - @as(f32, @floatFromInt(c.red));
        const dg = g - @as(f32, @floatFromInt(c.green));
        const db = b - @as(f32, @floatFromInt(c.blue));
        const d = dr * dr * 0.3 + dg * dg * 0.59 + db * db * 0.11;
        if (d < best_d) {
            best_d = d;
            best = @intCast(i);
        }
    }
    return best;
}

fn rowOf(d: *const Dib, y: usize, h: usize) usize {
    return if (d.header.biHeight > 0) h - 1 - y else y;
}

/// A sprite strip (frames stacked, `frames` of `src_w` x `src_w`) scaled to
/// frames of `size` x `size`: each new pixel averages the source pixels it
/// covers (area filter), transparent where over half of them are the
/// `trans` colour, else the palette colour nearest to the average.
pub fn scaleStrip(gpa: std.mem.Allocator, src: *const Dib, frames: usize, size: i16, trans: u8) ?*Dib {
    const sw: usize = @intCast(src.header.biWidth);
    const sh: usize = @intCast(@abs(src.header.biHeight));
    const sstride = (sw + 3) & ~@as(usize, 3);
    const fh = sh / frames;
    const ow: usize = @intCast(size);
    const ostride = (ow + 3) & ~@as(usize, 3);
    const oh = ow * frames;
    const out = gpa.create(Dib) catch return null;
    const bits = gpa.alloc(u8, ostride * oh) catch {
        gpa.destroy(out);
        return null;
    };
    out.* = src.*;
    out.bits = bits;
    out.header.biWidth = @intCast(ow);
    out.header.biHeight = if (src.header.biHeight > 0) @intCast(oh) else -@as(i32, @intCast(oh));
    out.header.biSizeImage = @intCast(bits.len);
    const fx: f32 = @as(f32, @floatFromInt(sw)) / @as(f32, @floatFromInt(ow));
    const fy: f32 = @as(f32, @floatFromInt(fh)) / @as(f32, @floatFromInt(ow));
    for (0..frames) |f| {
        for (0..ow) |dy| {
            for (0..ow) |dx| {
                const x0 = @as(f32, @floatFromInt(dx)) * fx;
                const x1 = x0 + fx;
                const y0 = @as(f32, @floatFromInt(dy)) * fy;
                const y1 = y0 + fy;
                var total: f32 = 0;
                var opaque_w: f32 = 0;
                var sr: f32 = 0;
                var sg: f32 = 0;
                var sb: f32 = 0;
                var y: usize = @intFromFloat(y0);
                while (@as(f32, @floatFromInt(y)) < y1 and y < fh) : (y += 1) {
                    const wy = @min(y1, @as(f32, @floatFromInt(y + 1))) - @max(y0, @as(f32, @floatFromInt(y)));
                    var x: usize = @intFromFloat(x0);
                    while (@as(f32, @floatFromInt(x)) < x1 and x < sw) : (x += 1) {
                        const wx = @min(x1, @as(f32, @floatFromInt(x + 1))) - @max(x0, @as(f32, @floatFromInt(x)));
                        const w = wx * wy;
                        total += w;
                        const idx = src.bits[rowOf(src, f * fh + y, sh) * sstride + x];
                        if (idx == trans) continue;
                        const c = src.colors[idx];
                        opaque_w += w;
                        sr += w * @as(f32, @floatFromInt(c.red));
                        sg += w * @as(f32, @floatFromInt(c.green));
                        sb += w * @as(f32, @floatFromInt(c.blue));
                    }
                }
                const v: u8 = if (opaque_w * 2 <= total or opaque_w == 0)
                    trans
                else
                    nearest(&src.colors, sr / opaque_w, sg / opaque_w, sb / opaque_w, trans);
                bits[rowOf(out, f * ow + dy, oh) * ostride + dx] = v;
            }
        }
    }
    return out;
}

fn put(bg: *Dib, x: i32, y: i32, v: u8) void {
    const w: usize = @intCast(bg.header.biWidth);
    const h: usize = @intCast(@abs(bg.header.biHeight));
    if (x < 0 or y < 0 or x >= w or y >= h) return;
    bg.bits[rowOf(bg, @intCast(y), h) * ((w + 3) & ~@as(usize, 3)) + @as(usize, @intCast(x))] = v;
}

fn get(bg: *const Dib, x: i32, y: i32) u8 {
    const w: usize = @intCast(bg.header.biWidth);
    const h: usize = @intCast(@abs(bg.header.biHeight));
    return bg.bits[rowOf(bg, @intCast(y), h) * ((w + 3) & ~@as(usize, 3)) + @as(usize, @intCast(x))];
}

fn rect(bg: *Dib, x: i32, y: i32, w: i32, h: i32, v: u8) void {
    var yy = y;
    while (yy < y + h) : (yy += 1) {
        var xx = x;
        while (xx < x + w) : (xx += 1) put(bg, xx, yy, v);
    }
}

/// A 3-pixel frame (dark, light, dark) around the inside rectangle.
fn frame(bg: *Dib, x: i32, y: i32, w: i32, h: i32, dark: u8, light: u8) void {
    rect(bg, x - 3, y - 3, w + 6, h + 6, dark);
    rect(bg, x - 2, y - 2, w + 4, h + 4, light);
    rect(bg, x - 1, y - 1, w + 2, h + 2, dark);
}

/// Draws the new well and the next-piece box on the background picture, in
/// the art's greys: a framed black well of 10 x 20 cells, a framed box to its
/// right (inside the black area the original's 11 x 14 well left).
pub fn paintBackground(s: *State, bg: *Dib) void {
    const black = get(bg, 100, 100);
    s.fill = black;
    const dark = nearest(&bg.colors, 56, 56, 56, null);
    const light = nearest(&bg.colors, 176, 176, 176, null);
    // The old well's black, then the frames (their insides black).
    rect(bg, 32, 0, 352, 448, black);
    const wx: i32 = origin_x;
    const wy: i32 = origin_y;
    frame(bg, wx, wy, cols * cell, rows * cell, dark, light);
    rect(bg, wx, wy, cols * cell, rows * cell, black);
    frame(bg, box_x, box_y, box_w, box_h, dark, light);
    rect(bg, box_x, box_y, box_w, box_h, black);
}

test "the shapes keep the original's cell counts and fit the 4 x 4 frame" {
    for (masks, 0..) |m, k| {
        for (m) |v| try std.testing.expectEqual(@popCount(m[0]), @popCount(v));
        try std.testing.expectEqual(@as(u5, if (k == 0) 6 else 4), @popCount(m[0]));
    }
}

test "fits: the walls, the floor and locked cells refuse" {
    var s: State = .{};
    // O piece: 2 x 2 at columns 0-1.
    try std.testing.expect(fits(&s, 5, 0, 0, 0));
    try std.testing.expect(!fits(&s, 5, 0, -1, 0));
    try std.testing.expect(!fits(&s, 5, 0, cols - 1, 0));
    try std.testing.expect(fits(&s, 5, 0, cols - 2, rows - 2));
    try std.testing.expect(!fits(&s, 5, 0, 0, rows - 1));
    s.board[10][1] = true;
    try std.testing.expect(!fits(&s, 5, 0, 0, 9));
    try std.testing.expect(fits(&s, 5, 0, 2, 9));
}

fn kickObj(kind: i16, col: i16, row: i16) Object {
    var o: Object = .{ .kind = .piece };
    o.curStrip = kind;
    o.piece.column = col;
    o.piece.row = row;
    return o;
}

test "kick: the right wall (the vertical I turns, two columns left)" {
    var s: State = .{};
    var o = kickObj(4, 8, 5);
    try std.testing.expectEqual(@as(i16, 0), step(&s, &o, 4, false));
    try std.testing.expectEqual(@as(i16, 1), step(&s, &o, 4, true));
    try std.testing.expectEqual(@as(i16, 6), o.piece.column);
    try std.testing.expectEqual(@as(i16, 5), o.piece.row);
    try std.testing.expectEqual(@as(u8, 1), s.rot);
    // A 3-wide piece needs one column only (never the two-column kicks).
    s.rot = 1;
    var j = kickObj(1, 8, 5);
    try std.testing.expectEqual(@as(i16, 1), step(&s, &j, 4, true));
    try std.testing.expectEqual(@as(i16, 7), j.piece.column);
}

test "kick: next to the left wall and a stack (a column right)" {
    var s: State = .{};
    // Kind 1, rotation 2 at column 0 hits the stack's cell (row 6, column 0);
    // a column left is outside the well, a column right is free.
    s.board[6][0] = true;
    const k = findKick(&s, 1, 2, 0, 5).?;
    try std.testing.expectEqual(@as(i16, 1), k.dx);
    try std.testing.expectEqual(@as(i16, 0), k.dy);
    // The long I never gets the two-column kick of a shorter piece's list
    // before the one-column ones.
    try std.testing.expectEqual(@as(i16, -1), findKick(&s, 4, 1, 7, 5).?.dx);
}

test "kick: next to a stack on the right (a column left)" {
    var s: State = .{};
    // Kind 1, rotation 1 -> 2 at column 4: rotation 2 needs (row 6, column 6).
    s.board[6][6] = true;
    var o = kickObj(1, 4, 5);
    s.rot = 1;
    try std.testing.expectEqual(@as(i16, 1), step(&s, &o, 4, true));
    try std.testing.expectEqual(@as(i16, 3), o.piece.column);
    try std.testing.expectEqual(@as(i16, 5), o.piece.row);
}

test "kick: on the floor the piece goes one row up" {
    var s: State = .{};
    var o = kickObj(1, 4, rows - 2);
    try std.testing.expectEqual(@as(i16, 0), step(&s, &o, 4, false));
    try std.testing.expectEqual(@as(i16, 1), step(&s, &o, 4, true));
    try std.testing.expectEqual(@as(i16, 4), o.piece.column);
    try std.testing.expectEqual(@as(i16, rows - 3), o.piece.row);
    try std.testing.expectEqual(@as(u8, 1), s.rot);
}

test "kick: nothing fits, the rotation is refused" {
    var s: State = .{};
    s.board[rows - 3] = @splat(true);
    var o = kickObj(1, 4, rows - 2);
    try std.testing.expectEqual(@as(i16, 0), step(&s, &o, 4, true));
    try std.testing.expectEqual(@as(i16, 4), o.piece.column);
    try std.testing.expectEqual(@as(i16, rows - 2), o.piece.row);
    try std.testing.expectEqual(@as(u8, 0), s.rot);
}

test "removeRow moves the rows above down" {
    var s: State = .{};
    s.board[3][2] = true;
    s.board[5] = @splat(true);
    try std.testing.expect(rowFull(&s, 5));
    removeRow(&s, 5);
    try std.testing.expect(s.board[4][2]);
    try std.testing.expect(!s.board[3][2]);
    try std.testing.expect(!rowFull(&s, 5));
}

test "scaleStrip: area filter, transparent stays transparent, frames stay apart" {
    const gpa = std.testing.allocator;
    var src: Dib = undefined;
    src.header = .{ .biWidth = 128, .biHeight = 512, .biBitCount = 8 };
    src.colors = @splat(.{});
    src.colors[1] = .{ .red = 200, .green = 0, .blue = 0 };
    src.colors[2] = .{ .red = 0, .green = 0, .blue = 200 };
    const bits = try gpa.alloc(u8, 128 * 512);
    defer gpa.free(bits);
    @memset(bits, 11);
    src.bits = bits;
    // Picture frame 0: the left half red; frame 1: all blue (bottom-up rows).
    for (0..128) |y| {
        for (0..64) |x| bits[(511 - y) * 128 + x] = 1;
        for (0..128) |x| bits[(511 - (128 + y)) * 128 + x] = 2;
    }
    const out = scaleStrip(gpa, &src, 4, 88, 11) orelse return error.TestUnexpectedResult;
    defer {
        gpa.free(out.bits);
        gpa.destroy(out);
    }
    try std.testing.expectEqual(@as(i32, 88), out.header.biWidth);
    try std.testing.expectEqual(@as(i32, 352), out.header.biHeight);
    const at = struct {
        fn f(d: *const Dib, x: usize, y: usize) u8 {
            return d.bits[(351 - y) * 88 + x];
        }
    }.f;
    try std.testing.expectEqual(@as(u8, 1), at(out, 10, 10));
    try std.testing.expectEqual(@as(u8, 11), at(out, 80, 10));
    try std.testing.expectEqual(@as(u8, 2), at(out, 80, 88 + 10));
    try std.testing.expectEqual(@as(u8, 11), at(out, 10, 2 * 88 + 10));
}
