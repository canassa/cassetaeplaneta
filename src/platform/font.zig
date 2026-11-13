//! GDI system-font replacement: reads a Windows 3.x `.FON` (e.g. VGASYS.FON)
//! and draws text into an 8-bit palettized framebuffer.
//! A `.FON` is an NE executable; its resources of type 0x8008 are FNT fonts.
//! An FNT (v2: 118-byte header, glyph entries u16 width + u16 offset; v3: 148
//! bytes, u16 width + u32 offset) stores each glyph as ceil(width/8) column
//! strips of `pixHeight` bytes, MSB = leftmost pixel.

const std = @import("std");

pub const Error = error{InvalidFont} || std.mem.Allocator.Error;

pub const Font = struct {
    /// Owned copy of the FNT resource bytes.
    data: []u8,
    version: u16,
    ascent: u16,
    pix_height: u16,
    first_char: u8,
    last_char: u8,
    /// Relative to `first_char`.
    default_char: u8,
    break_char: u8,
    /// Byte offset of the glyph table inside `data`.
    table_off: usize,

    /// Parses the first 0x8008 (font) resource of a `.FON` file.
    pub fn parse(gpa: std.mem.Allocator, fon_bytes: []const u8) Error!Font {
        const d = fon_bytes;
        const ne: usize = try rd32(d, 0x3c);
        if (ne > d.len or d.len - ne < 0x40 or d[ne] != 'N' or d[ne + 1] != 'E') return error.InvalidFont;
        const rt: usize = ne + try rd16(d, ne + 0x24);
        const shift = try rd16(d, rt);
        if (shift > 15) return error.InvalidFont;
        var p = rt + 2;
        const fnt: []const u8 = found: while (true) {
            const type_id = try rd16(d, p);
            if (type_id == 0) return error.InvalidFont;
            const count = try rd16(d, p + 2);
            p += 8;
            if (type_id == 0x8008 and count > 0) {
                const off = @as(usize, try rd16(d, p)) << @intCast(shift);
                const len = @as(usize, try rd16(d, p + 2)) << @intCast(shift);
                if (off > d.len or len > d.len - off) return error.InvalidFont;
                break :found d[off..][0..len];
            }
            p += @as(usize, count) * 12;
        };

        const version = try rd16(fnt, 0);
        const hdr: usize = switch (version) {
            0x200 => 118,
            0x300 => 148,
            else => return error.InvalidFont,
        };
        if (fnt.len < hdr) return error.InvalidFont;
        var f: Font = .{
            .data = undefined,
            .version = version,
            .ascent = try rd16(fnt, 74),
            .pix_height = try rd16(fnt, 88),
            .first_char = fnt[95],
            .last_char = fnt[96],
            .default_char = fnt[97],
            .break_char = fnt[98],
            .table_off = hdr,
        };
        if (f.last_char < f.first_char or f.default_char > f.last_char - f.first_char) return error.InvalidFont;
        // Validate every glyph so drawing never reads out of bounds.
        const n = @as(usize, f.last_char - f.first_char) + 1;
        if (fnt.len < hdr + n * f.entrySize()) return error.InvalidFont;
        for (0..n) |i| {
            const g = f.entryIn(fnt, i);
            const size = (@as(usize, g.width) + 7) / 8 * f.pix_height;
            if (g.offset > fnt.len or size > fnt.len - g.offset) return error.InvalidFont;
        }
        f.data = try gpa.dupe(u8, fnt);
        return f;
    }

    pub fn deinit(f: *Font, gpa: std.mem.Allocator) void {
        gpa.free(f.data);
        f.* = undefined;
    }

    pub fn height(f: *const Font) u16 {
        return f.pix_height;
    }

    pub fn charWidth(f: *const Font, c: u8) u16 {
        return f.glyph(c).width;
    }

    /// GetTextExtent: total advance width and the cell height.
    pub fn extent(f: *const Font, text: []const u8) struct { w: u16, h: u16 } {
        var w: u16 = 0;
        for (text) |c| w +%= f.charWidth(c);
        return .{ .w = w, .h = f.pix_height };
    }

    /// TextOut at (x, y) = top-left of the cell, clipped to the buffer. Foreground pixels get `fg`;
    /// when `bg` is non-null (GDI OPAQUE, the default bk mode) the whole cell box of each char is filled with it first.
    /// `bottom_up`: row 0 of `pixels` is the bottom picture row (a DIB with
    /// positive biHeight); y still counts from the top.
    pub fn draw(f: *const Font, pixels: []u8, width: usize, height_: usize, bottom_up: bool, x: i16, y: i16, fg: u8, bg: ?u8, text: []const u8) void {
        const rows = @min(height_, if (width == 0) 0 else pixels.len / width);
        var cx: i32 = x;
        for (text) |c| {
            const g = f.glyph(c);
            const strip = f.data[g.offset..];
            for (0..f.pix_height) |gy| {
                const py = @as(i32, y) + @as(i32, @intCast(gy));
                if (py < 0 or py >= rows) continue;
                const mem_row: usize = if (bottom_up) rows - 1 - @as(usize, @intCast(py)) else @intCast(py);
                const row = pixels[mem_row * width ..][0..width];
                for (0..g.width) |gx| {
                    const px = cx + @as(i32, @intCast(gx));
                    if (px < 0 or px >= width) continue;
                    const b = strip[(gx / 8) * f.pix_height + gy];
                    const on = b & (@as(u8, 0x80) >> @intCast(gx % 8)) != 0;
                    if (on) {
                        row[@intCast(px)] = fg;
                    } else if (bg) |v| {
                        row[@intCast(px)] = v;
                    }
                }
            }
            cx += g.width;
        }
    }

    const Glyph = struct { width: u16, offset: usize };

    fn entrySize(f: *const Font) usize {
        return if (f.version == 0x200) 4 else 6;
    }

    fn entryIn(f: *const Font, fnt: []const u8, i: usize) Glyph {
        const e = fnt[f.table_off + i * f.entrySize() ..];
        const width = std.mem.readInt(u16, e[0..2], .little);
        const offset: usize = if (f.version == 0x200)
            std.mem.readInt(u16, e[2..4], .little)
        else
            std.mem.readInt(u32, e[2..6], .little);
        return .{ .width = width, .offset = offset };
    }

    fn glyph(f: *const Font, c: u8) Glyph {
        const i: usize = if (c < f.first_char or c > f.last_char) f.default_char else c - f.first_char;
        return f.entryIn(f.data, i);
    }
};

fn rd16(d: []const u8, off: usize) error{InvalidFont}!u16 {
    if (off > d.len or d.len - off < 2) return error.InvalidFont;
    return std.mem.readInt(u16, d[off..][0..2], .little);
}

fn rd32(d: []const u8, off: usize) error{InvalidFont}!u32 {
    if (off > d.len or d.len - off < 4) return error.InvalidFont;
    return std.mem.readInt(u32, d[off..][0..4], .little);
}

fn loadSystem(gpa: std.mem.Allocator) !Font {
    const bytes = try std.Io.Dir.cwd().readFileAlloc(std.testing.io, "assets/MSSVGA/VGASYS.FON", gpa, .limited(1 << 20));
    defer gpa.free(bytes);
    return Font.parse(gpa, bytes);
}

test "VGASYS metrics" {
    const gpa = std.testing.allocator;
    var f = try loadSystem(gpa);
    defer f.deinit(gpa);
    try std.testing.expectEqual(16, f.height());
    for ("0123456789") |c| try std.testing.expectEqual(8, f.charWidth(c));
    try std.testing.expectEqual(4, f.charWidth(' '));
    try std.testing.expectEqual(14, f.charWidth('W'));
    // Below firstChar (32): falls back to defaultChar (32 + 96 = 128).
    try std.testing.expectEqual(f.charWidth(128), f.charWidth(1));
    const e = f.extent("Pontos:0123");
    try std.testing.expectEqual(81, e.w);
    try std.testing.expectEqual(16, e.h);
}

test "malformed data errors" {
    const gpa = std.testing.allocator;
    try std.testing.expectError(error.InvalidFont, Font.parse(gpa, ""));
    var bad: [0x40]u8 = @splat(0);
    bad[0x3c] = 0xff;
    bad[0x3d] = 0xff;
    try std.testing.expectError(error.InvalidFont, Font.parse(gpa, &bad));
    const bytes = try std.Io.Dir.cwd().readFileAlloc(std.testing.io, "assets/MSSVGA/VGASYS.FON", gpa, .limited(1 << 20));
    defer gpa.free(bytes);
    for ([_]usize{ 0x40, 0x100, 0x400, bytes.len - 100 }) |n|
        if (Font.parse(gpa, bytes[0..n])) |ok| {
            var g = ok;
            g.deinit(gpa);
        } else |_| {};
}

test "draw W: box, opaque vs transparent" {
    const gpa = std.testing.allocator;
    var f = try loadSystem(gpa);
    defer f.deinit(gpa);
    const W = 40;
    const H = 30;
    var buf: [W * H]u8 = @splat(0);
    f.draw(&buf, W, H, false, 5, 7, 9, null, "W");
    var lit: usize = 0;
    for (0..H) |py| for (0..W) |px| {
        const v = buf[py * W + px];
        const inside = px >= 5 and px < 5 + 14 and py >= 7 and py < 7 + 16;
        if (v == 9) lit += 1;
        if (!inside) try std.testing.expectEqual(0, v);
        try std.testing.expect(v == 0 or v == 9);
    };
    try std.testing.expect(lit > 10);

    var buf2: [W * H]u8 = @splat(0);
    f.draw(&buf2, W, H, false, 5, 7, 9, 3, "W");
    for (0..H) |py| for (0..W) |px| {
        const inside = px >= 5 and px < 19 and py >= 7 and py < 23;
        const v = buf2[py * W + px];
        if (inside) {
            try std.testing.expect(v == 9 or v == 3);
            try std.testing.expectEqual(buf[py * W + px] == 9, v == 9);
        } else try std.testing.expectEqual(0, v);
    };
}

test "draw clips" {
    const gpa = std.testing.allocator;
    var f = try loadSystem(gpa);
    defer f.deinit(gpa);
    const W = 20;
    const H = 20;
    var ref: [W * H]u8 = @splat(0);
    f.draw(&ref, W, H, false, 0, 0, 1, 2, "W");
    // Negative x/y: shifted copy of the reference cell.
    var buf: [W * H]u8 = @splat(0);
    f.draw(&buf, W, H, false, -3, -5, 1, 2, "W");
    for (0..H) |py| for (0..W) |px| {
        const want: u8 = if (px < 11 and py < 11) ref[(py + 5) * W + px + 3] else 0;
        try std.testing.expectEqual(want, buf[py * W + px]);
    };
    // Right/bottom edges and fully off-screen: no panic, nothing outside.
    var b2: [W * H]u8 = @splat(0);
    f.draw(&b2, W, H, false, 15, 10, 1, 2, "WWW");
    for (0..H) |py| for (0..W) |px| {
        const want: u8 = if (px >= 15 and py >= 10) ref[(py - 10) * W + px - 15] else 0;
        try std.testing.expectEqual(want, b2[py * W + px]);
    };
    f.draw(&b2, W, H, false, -32768, 32767, 1, 2, "Pontos");
    f.draw(&b2, W, H, false, 32000, -32000, 1, 2, "Pontos");
}
