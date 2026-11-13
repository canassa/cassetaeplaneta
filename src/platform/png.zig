//! Frame dumps for the test harness: the 640×480 8-bit screen and its
//! palette as an indexed-colour PNG (or a BMP when the name ends in `.bmp`).
//! Platform/debug code, not a port unit.

const std = @import("std");
const p = @import("platform.zig");
const flate = std.compress.flate;

/// Encodes `scr` as an 8-bit palette PNG into `out`.
pub fn encodePng(gpa: std.mem.Allocator, scr: *const p.Screen, out: *std.ArrayList(u8)) !void {
    const w = p.screen_width;
    const h = p.screen_height;
    try out.appendSlice(gpa, "\x89PNG\r\n\x1a\n");

    var ihdr: [13]u8 = undefined;
    std.mem.writeInt(u32, ihdr[0..4], w, .big);
    std.mem.writeInt(u32, ihdr[4..8], h, .big);
    ihdr[8] = 8; // bit depth
    ihdr[9] = 3; // indexed colour
    ihdr[10] = 0;
    ihdr[11] = 0;
    ihdr[12] = 0;
    try chunk(gpa, out, "IHDR", &ihdr);

    var plte: [768]u8 = undefined;
    for (scr.palette, 0..) |c, i| {
        plte[i * 3] = c.r;
        plte[i * 3 + 1] = c.g;
        plte[i * 3 + 2] = c.b;
    }
    try chunk(gpa, out, "PLTE", &plte);

    // Raw scanlines (filter byte 0 + the row), zlib-compressed.
    const raw = try gpa.alloc(u8, (w + 1) * h);
    defer gpa.free(raw);
    for (0..h) |y| {
        raw[y * (w + 1)] = 0;
        @memcpy(raw[y * (w + 1) + 1 ..][0..w], scr.pixels[y * w ..][0..w]);
    }
    var z: std.Io.Writer.Allocating = try .initCapacity(gpa, 64 * 1024);
    defer z.deinit();
    const window = try gpa.alloc(u8, flate.max_window_len);
    defer gpa.free(window);
    var c = try flate.Compress.init(&z.writer, window, .zlib, .level_1);
    try c.writer.writeAll(raw);
    try c.finish();
    try chunk(gpa, out, "IDAT", z.written());
    try chunk(gpa, out, "IEND", "");
}

fn chunk(gpa: std.mem.Allocator, out: *std.ArrayList(u8), kind: *const [4]u8, data: []const u8) !void {
    var len: [4]u8 = undefined;
    std.mem.writeInt(u32, &len, @intCast(data.len), .big);
    try out.appendSlice(gpa, &len);
    try out.appendSlice(gpa, kind);
    try out.appendSlice(gpa, data);
    var crc = std.hash.Crc32.init();
    crc.update(kind);
    crc.update(data);
    var sum: [4]u8 = undefined;
    std.mem.writeInt(u32, &sum, crc.final(), .big);
    try out.appendSlice(gpa, &sum);
}

/// Encodes `scr` as an 8-bit bottom-up BMP into `out`.
pub fn encodeBmp(gpa: std.mem.Allocator, scr: *const p.Screen, out: *std.ArrayList(u8)) !void {
    const w = p.screen_width;
    const h = p.screen_height;
    const offset: u32 = 14 + 40 + 1024;
    var hdr: [offset]u8 = @splat(0);
    hdr[0] = 'B';
    hdr[1] = 'M';
    std.mem.writeInt(u32, hdr[2..6], offset + w * h, .little);
    std.mem.writeInt(u32, hdr[10..14], offset, .little);
    std.mem.writeInt(u32, hdr[14..18], 40, .little);
    std.mem.writeInt(i32, hdr[18..22], w, .little);
    std.mem.writeInt(i32, hdr[22..26], h, .little);
    std.mem.writeInt(u16, hdr[26..28], 1, .little);
    std.mem.writeInt(u16, hdr[28..30], 8, .little);
    std.mem.writeInt(u32, hdr[46..50], 256, .little);
    for (scr.palette, 0..) |c, i| {
        hdr[54 + i * 4] = c.b;
        hdr[54 + i * 4 + 1] = c.g;
        hdr[54 + i * 4 + 2] = c.r;
    }
    try out.appendSlice(gpa, &hdr);
    var y: usize = h;
    while (y > 0) {
        y -= 1;
        try out.appendSlice(gpa, scr.pixels[y * w ..][0..w]);
    }
}

test "a dumped PNG starts with the signature and an IHDR" {
    const gpa = std.testing.allocator;
    const scr = try gpa.create(p.Screen);
    defer gpa.destroy(scr);
    scr.* = .{};
    var out: std.ArrayList(u8) = .empty;
    defer out.deinit(gpa);
    try encodePng(gpa, scr, &out);
    try std.testing.expectEqualSlices(u8, "\x89PNG\r\n\x1a\n", out.items[0..8]);
    try std.testing.expectEqualSlices(u8, "IHDR", out.items[12..16]);
}
