//! Corrigida (BUGS.md B53, `Fixes.sprite_key_specks`): fills the stray
//! colour-11 pixels inside sprite art. Every object is drawn with palette
//! index 11 (`g.unk001C`) as the transparent colour, and many sprite
//! bitmaps have index-11 pixels inside the picture (a palette-reduction
//! accident against their blue backdrop): the game shows the scene through
//! them. `src/data/key_specks.tsv` lists every such pixel, each reviewed by
//! hand (`tools/key_review.py` makes the list and the review sheets);
//! `loadDib` writes the `fill` index into the listed pixels decided `fill`
//! of the bitmap it has just read. No heuristic runs here: only the list.

const std = @import("std");
const object = @import("core/object.zig");
const BitmapInfoHeader = object.BitmapInfoHeader;

/// The reviewed list: `file x y fill decision kind reason`, tab separated,
/// `#` comments and a header line.
const table = @embedFile("data/key_specks.tsv");

/// The transparent index the list was made for (`g.unk001C`).
const key: u8 = 0x0b;

/// Whether `path` (as `loadDib` opened it: any case, `\` or `/`, with the
/// CD root in front) names the disc file `file` (lower case, `/`).
fn sameFile(path: []const u8, file: []const u8) bool {
    if (path.len < file.len) return false;
    const tail = path[path.len - file.len ..];
    for (tail, file) |a, b| {
        const c = if (a == '\\') '/' else std.ascii.toLower(a);
        if (c != b) return false;
    }
    if (path.len == file.len) return true;
    const before = path[path.len - file.len - 1];
    return before == '\\' or before == '/' or before == ':';
}

/// Writes the listed fills of `path` into its 8-bit pixels `bits`
/// (described by `hdr`, bottom-up unless the height is negative). A pixel
/// is written only if it still holds the key. Returns the number written.
pub fn apply(path: []const u8, hdr: *const BitmapInfoHeader, bits: []u8) usize {
    if (hdr.biBitCount != 8 or hdr.biCompression != 0) return 0;
    const w: usize = @intCast(@max(hdr.biWidth, 0));
    const h: usize = @intCast(@abs(hdr.biHeight));
    const stride = (w + 3) & ~@as(usize, 3);
    var n: usize = 0;
    var lines = std.mem.splitScalar(u8, table, '\n');
    while (lines.next()) |line| {
        if (line.len == 0 or line[0] == '#') continue;
        var f = std.mem.splitScalar(u8, line, '\t');
        const file = f.next() orelse continue;
        if (!sameFile(path, file)) continue;
        const x = std.fmt.parseInt(usize, f.next() orelse continue, 10) catch continue;
        const y = std.fmt.parseInt(usize, f.next() orelse continue, 10) catch continue;
        const fill = std.fmt.parseInt(u8, f.next() orelse continue, 10) catch continue;
        if (!std.mem.eql(u8, f.next() orelse continue, "fill")) continue;
        if (x >= w or y >= h) continue;
        const row = if (hdr.biHeight > 0) h - 1 - y else y;
        const i = row * stride + x;
        if (i >= bits.len or bits[i] != key) continue;
        bits[i] = fill;
        n += 1;
    }
    return n;
}

test "sameFile matches the disc path at a separator, in any case" {
    try std.testing.expect(sameFile("\\FASE1\\1FSALA\\1OMESA.BMP", "fase1/1fsala/1omesa.bmp"));
    try std.testing.expect(sameFile("D:\\fase1/1fsala\\1omesa.bmp", "fase1/1fsala/1omesa.bmp"));
    try std.testing.expect(!sameFile("\\xfase1\\1fsala\\1omesa.bmp", "fase1/1fsala/1omesa.bmp"));
    try std.testing.expect(!sameFile("\\1omesa.bmp", "fase1/1fsala/1omesa.bmp"));
}

test "the coffee table's holes are filled with the fix and kept without it" {
    const testing = std.testing;
    const dib = @import("dib.zig");
    const headless = @import("platform/headless.zig");
    var hl = headless.Headless.init(testing.allocator, testing.io, .{});
    defer hl.deinit();
    const plat = hl.platform();
    var path_buf: [50]u8 = undefined;
    const name = "\\fase1\\1fsala\\1omesa.bmp";
    const orig = try dib.loadDib(testing.allocator, plat, .{}, &path_buf, "\\", name) orelse return error.TestUnexpectedResult;
    defer {
        testing.allocator.free(orig.bits);
        testing.allocator.destroy(orig);
    }
    const fixed = try dib.loadDib(testing.allocator, plat, .{ .sprite_key_specks = true }, &path_buf, "\\", name) orelse return error.TestUnexpectedResult;
    defer {
        testing.allocator.free(fixed.bits);
        testing.allocator.destroy(fixed);
    }
    const h: usize = @intCast(orig.header.biHeight);
    const stride = (@as(usize, @intCast(orig.header.biWidth)) + 3) & ~@as(usize, 3);
    var listed: usize = 0;
    var lines = std.mem.splitScalar(u8, table, '\n');
    while (lines.next()) |line| {
        var f = std.mem.splitScalar(u8, line, '\t');
        if (!std.mem.eql(u8, f.next() orelse continue, "fase1/1fsala/1omesa.bmp")) continue;
        const x = try std.fmt.parseInt(usize, f.next().?, 10);
        const y = try std.fmt.parseInt(usize, f.next().?, 10);
        const fill = try std.fmt.parseInt(u8, f.next().?, 10);
        try testing.expectEqualStrings("fill", f.next().?);
        const i = (h - 1 - y) * stride + x;
        try testing.expectEqual(key, orig.bits[i]);
        try testing.expectEqual(fill, fixed.bits[i]);
        listed += 1;
    }
    try testing.expectEqual(26, listed);
    // Nothing else changes.
    var diff: usize = 0;
    for (orig.bits, fixed.bits) |a, b| diff += @intFromBool(a != b);
    try testing.expectEqual(listed, diff);
}
