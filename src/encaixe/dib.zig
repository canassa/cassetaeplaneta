//! Port unit `dib` (module) of ENCAIXE.EXE. DIB loading and the row blitters (1000 is NOITE's byte-identical 32-bit segment).
//!
//! The DIB helpers of ENCAIXE (1008:1bde-2138) are NOITE's `dib_copy_transparent`,
//! `dib_copy`, `clear_system_palette` and `read_dib_info`, recompiled in the
//! small model: the same C (the decompiles and the instruction streams were
//! compared; only the frame offsets, the near returns and the DS prologue
//! differ), so they call NOITE's `src/dib.zig`. `load_dib` differs (no
//! `pan\bmp` fallback, a resource fallback instead) and is written here.
//!
//! Bug B12 (opaque row copy skips index 0 in the last `width & 3` columns of
//! each row) is in segment 1000, so ENCAIXE has it too: `fixes.opaque_copy_black_tail`.
//! Bug B13 (`load_dib` leaves the file open when it is not a DIB) is also in
//! ENCAIXE's `load_dib`: `fixes.close_unreadable_dib`.

const std = @import("std");
const noite_dib = @import("../dib.zig");
const cstr = @import("../core/cstr.zig");
const Fixes = @import("../core/fixes.zig").Fixes;
const platform = @import("../platform/platform.zig");
const Platform = platform.Platform;
const object = @import("core/object.zig");

pub const Dib = object.Dib;
pub const BitmapInfoHeader = object.BitmapInfoHeader;
pub const Error = noite_dib.Error;

// @orig 1000:0114 dib_rows_copy32
/// Copies `height` rows of `width` bytes, row pointers advancing by the
/// signed strides. Original bug B12 behind `fixes.opaque_copy_black_tail`
/// (see the file header).
pub fn rowsCopy32(
    dst: []u8,
    dst_off: i32,
    src: []const u8,
    src_off: i32,
    width: i32,
    height: i32,
    src_stride: i32,
    dst_stride: i32,
    fixes: Fixes,
) Error!void {
    return noite_dib.rowsCopy32(dst, dst_off, src, src_off, width, height, src_stride, dst_stride, fixes);
}

// @orig 1000:0024 dib_rows_copy_transparent32
/// Like `rowsCopy32`, skipping source bytes equal to `key`.
pub fn rowsCopyTransparent32(
    dst: []u8,
    dst_off: i32,
    src: []const u8,
    src_off: i32,
    width: i32,
    height: i32,
    src_stride: i32,
    dst_stride: i32,
    key: u8,
) Error!void {
    return noite_dib.rowsCopyTransparent32(dst, dst_off, src, src_off, width, height, src_stride, dst_stride, key);
}

// @orig 1008:1bde dib_copy_transparent
/// Copies the `width` x `height` rectangle at (`x_src`, `y_src`) of the 8-bit
/// DIB `src` to (`x_dst`, `y_dst`) of `dst`, clipped to the destination,
/// skipping source pixels equal to `key`. True if anything was drawn.
/// `dst_bits` starts at the destination's first pixel (the original ignores
/// the offset word of that pointer).
pub fn copyTransparent(
    dst_hdr: *const BitmapInfoHeader,
    dst_bits: []u8,
    x_dst: i16,
    y_dst: i16,
    src_bits: []const u8,
    src_hdr: *const BitmapInfoHeader,
    x_src: i16,
    y_src: i16,
    width: i16,
    height: i16,
    key: u8,
) Error!bool {
    return noite_dib.copyTransparent(dst_hdr, dst_bits, x_dst, y_dst, src_bits, src_hdr, x_src, y_src, width, height, key);
}

// @orig 1008:1dbe dib_copy
/// Copies the whole 8-bit DIB `src` to (`x_dst`, `y_dst`) of `dst`, clipped to
/// the destination. True if anything was drawn. Subject to B12.
pub fn copy(
    dst_hdr: *const BitmapInfoHeader,
    dst_bits: []u8,
    x_dst: i16,
    y_dst: i16,
    src_bits: []const u8,
    src_hdr: *const BitmapInfoHeader,
    fixes: Fixes,
) Error!bool {
    return noite_dib.copy(dst_hdr, dst_bits, x_dst, y_dst, src_bits, src_hdr, fixes);
}

// @orig 1008:1f64 clear_system_palette
/// Realizes an all-black PC_NOCOLLAPSE palette on the screen DC to reset the
/// system palette. The platform's screen starts black with the static
/// colours: nothing to do.
pub fn clearSystemPalette() void {}

// @orig 1008:2138 read_dib_info
/// Reads a DIB's header and colour table from the open file `fh` (a BMP file
/// or a bare DIB), converting an OS/2 core header, and leaves the file at the
/// pixel data. Returns a `Dib` with empty `bits`, or null on failure.
pub fn readDibInfo(plat: Platform, fh: ?platform.File) ?Dib {
    return noite_dib.readDibInfo(plat, fh);
}

/// The file name part of `path`, without directory or extension (for
/// `Dib.name`, which is not in the original).
fn baseName(path: []const u8) []const u8 {
    var start: usize = 0;
    if (path.len >= 2 and path[1] == ':') start = 2;
    if (std.mem.lastIndexOfAny(u8, path, "\\/")) |i| start = i + 1;
    const rest = path[start..];
    const dot = std.mem.lastIndexOfScalar(u8, rest, '.') orelse rest.len;
    return rest[0..dot];
}

// @orig 1008:1fe4 load_dib
/// Loads a DIB (header, colours and pixels) from the file `name` (OpenFile:
/// as given, no search directory). The original then tries a type-2
/// (RT_BITMAP) resource of that name; the port has no resources. Returns
/// null if not found, unreadable or out of memory.
///
/// When the file opens but is not a readable DIB, the original returns
/// without closing it (B13; `fixes.close_unreadable_dib` closes it).
pub fn loadDib(gpa: std.mem.Allocator, plat: Platform, fixes: Fixes, name: []const u8) ?*Dib {
    const nm = cstr.slice(name);
    const f = plat.open(nm, .read) orelse return null;
    var info = readDibInfo(plat, f) orelse {
        if (fixes.close_unreadable_dib) plat.close(f);
        return null;
    };
    const dib = gpa.create(Dib) catch {
        plat.close(f);
        return null;
    };
    const bits = gpa.alloc(u8, info.header.biSizeImage) catch {
        gpa.destroy(dib);
        plat.close(f);
        return null;
    };
    _ = plat.read(f, bits);
    info.bits = bits;
    dib.* = info;
    cstr.copy(&dib.name, baseName(nm));
    plat.close(f);
    return dib;
}

const testing = std.testing;
const headless = @import("../platform/headless.zig");

fn hdr(w: i32, h: i32) BitmapInfoHeader {
    return .{ .biWidth = w, .biHeight = h, .biBitCount = 8 };
}

// @orig 1008:1dbe dib_copy oracle=documented
test "copy places a bottom-up DIB by picture coordinates" {
    var dst: [32]u8 = @splat(0);
    const src = [_]u8{ 1, 2, 3, 4, 5, 6, 7, 8 };
    const dh = hdr(8, 4);
    const sh = hdr(4, 2);
    try testing.expect(try copy(&dh, &dst, 1, 1, &src, &sh, .{}));
    try testing.expectEqualSlices(u8, &.{ 0, 1, 2, 3, 4, 0, 0, 0 }, dst[8..16]);
    try testing.expectEqualSlices(u8, &.{ 0, 5, 6, 7, 8, 0, 0, 0 }, dst[16..24]);
}

// @orig 1000:0114 dib_rows_copy32 oracle=documented
test "opaque copy skips index 0 in the last columns (B12) unless fixed" {
    const src = [_]u8{ 1, 0, 2, 0, 3, 0, 0 };
    var dst: [7]u8 = @splat(9);
    try rowsCopy32(&dst, 0, &src, 0, 7, 1, 7, 7, .{});
    try testing.expectEqualSlices(u8, &.{ 1, 0, 2, 0, 3, 9, 9 }, &dst);
    dst = @splat(9);
    try rowsCopy32(&dst, 0, &src, 0, 7, 1, 7, 7, .{ .opaque_copy_black_tail = true });
    try testing.expectEqualSlices(u8, &.{ 1, 0, 2, 0, 3, 0, 0 }, &dst);
}

// @orig 1008:1bde dib_copy_transparent oracle=documented
test "copyTransparent skips the key colour" {
    var dst: [16]u8 = @splat(9);
    const src = [_]u8{ 5, 7, 5, 7, 7, 5, 7, 5 };
    const dh = hdr(4, 4);
    const sh = hdr(4, 2);
    try testing.expect(try copyTransparent(&dh, &dst, 0, 0, &src, &sh, 0, 0, 4, 2, 7));
    try testing.expectEqualSlices(u8, &.{ 5, 9, 5, 9 }, dst[8..12]);
}

// @orig 1008:1fe4 load_dib oracle=asset
test "loadDib reads an ENCAIXE bitmap from the disc" {
    var h = headless.Headless.init(testing.allocator, testing.io, .{});
    defer h.deinit();
    const plat = h.platform();
    const file = try std.Io.Dir.cwd().readFileAlloc(testing.io, "assets/ENCAIXE/PANEL.BMP", testing.allocator, .limited(1 << 24));
    defer testing.allocator.free(file);
    const dib = loadDib(testing.allocator, plat, .{}, "\\ENCAIXE\\PANEL.BMP") orelse return error.TestUnexpectedResult;
    defer {
        testing.allocator.free(dib.bits);
        testing.allocator.destroy(dib);
    }
    const off = std.mem.readInt(u32, file[10..14], .little);
    try testing.expectEqual(std.mem.readInt(i32, file[18..22], .little), dib.header.biWidth);
    try testing.expectEqualSlices(u8, file[off..][0..dib.bits.len], dib.bits);
    try testing.expect(loadDib(testing.allocator, plat, .{}, "nosuch.bmp") == null);
}
