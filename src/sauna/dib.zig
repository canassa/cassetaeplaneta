//! Port unit `dib` (module) of SAUNA.EXE. DIB loading, copies and the row blitters (1000:0148/0234 are NOITE's 32-bit row copies; the RLE copies of 1000/1008/1068/1088 are dead).
//!
//! Same source as TIRO's `dib`. The disassembly of `dib_copy_transparent`,
//! `dib_copy`, `clear_system_palette`, `load_dib` and `read_dib_info` was
//! compared with SALGIN's/TIRO's (same instructions; only addresses, the
//! `__AHSHIFT` thunk constant and frame offsets differ), so the copies and
//! `read_dib_info` call NOITE's `src/dib.zig`. The two 32-bit row copies
//! were compared byte by byte (`objdump -mi386`) with TIRO's: the same code
//! with the same bug B12 (the last `width & 3` columns skip index 0); the
//! body copy is one `rep movsd` here and unrolled byte moves in TIRO, and
//! TIRO's transparent copy has a `jz/xchg` no-op more; same effect.
//! `load_dib` is written here as in TIRO. `dib_copy_rect` is NOT TIRO's:
//! SAUNA's clamps the rectangle to the source (as `dib_copy_transparent`)
//! and never negates the height; it is `dib_copy_transparent`'s geometry
//! ending in the opaque `dib_rows_copy32`, written here.
//!
//! Bug B12 (opaque row copy skips index 0 in the last `width & 3` columns of
//! each row): `fixes.opaque_copy_black_tail`. Bug B13 (`load_dib` leaves the
//! file open when it is not a DIB): `fixes.close_unreadable_dib`.

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

// @orig 1000:0234 dib_rows_copy32
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

// @orig 1000:0148 dib_rows_copy_transparent32
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

// @orig 1010:0000 dib_copy_transparent
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

// @orig 1010:04b4 dib_copy
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

/// A rectangle as Win16 `RECT` (all `int`).
const Rc = struct { left: i16, top: i16, right: i16, bottom: i16 };

/// USER `IntersectRect`: the intersection, or null (the original's 0) when
/// it is empty.
fn intersectRect(a: Rc, b: Rc) ?Rc {
    const r: Rc = .{
        .left = @max(a.left, b.left),
        .top = @max(a.top, b.top),
        .right = @min(a.right, b.right),
        .bottom = @min(a.bottom, b.bottom),
    };
    if (r.left >= r.right or r.top >= r.bottom) return null;
    return r;
}

/// `((width * bitCount + 0x1f) & 0xffe7) >> 3` in 16-bit arithmetic.
fn rowStride(width: i32, bit_count: u16) u16 {
    const w: u16 = @truncate(@as(u32, @bitCast(width)));
    const x: u16 = (w *% bit_count) +% 0x1f;
    return (x & 0xffe7) >> 3;
}

// @orig 1010:06f1 dib_copy_rect
/// Opaque copy of the `width` x `height` rectangle at (`x_src`, `y_src`) of
/// the 8-bit DIB `src` to (`x_dst`, `y_dst`) of `dst`: the rectangle is
/// clamped to the source (`width` to `biWidth - x_src`, `height` to
/// `biHeight - y_src`), clipped to the destination, and copied by
/// `dib_rows_copy32` (subject to B12). True if anything was drawn. The
/// geometry is `dib_copy_transparent`'s. The original's last parameter is
/// unused and not taken.
pub fn copyRect(
    dst_hdr: *const BitmapInfoHeader,
    dst_bits: []u8,
    x_dst: i16,
    y_dst: i16,
    src_bits: []const u8,
    src_hdr: *const BitmapInfoHeader,
    x_src: i16,
    y_src: i16,
    width_in: i16,
    height_in: i16,
    fixes: Fixes,
) Error!bool {
    var width = width_in;
    var height = height_in;
    var dst_h: i16 = @truncate(dst_hdr.biHeight);
    var dir: i16 = 1;
    const src_w: i16 = @truncate(src_hdr.biWidth);
    const src_h: i16 = @truncate(src_hdr.biHeight);
    if (src_w < width +% x_src) width = src_w -% x_src;
    if (src_h < height +% y_src) height = src_h -% y_src;
    const want: Rc = .{ .left = x_dst, .top = y_dst, .right = width +% x_dst, .bottom = height +% y_dst };
    if (dst_h < 0) {
        dir = -1;
        dst_h = -%dst_h;
    }
    const bounds: Rc = .{ .left = 0, .top = 0, .right = @truncate(dst_hdr.biWidth), .bottom = dst_h };
    const out = intersectRect(bounds, want) orelse return false;

    const dst_stride: i32 = rowStride(dst_hdr.biWidth, dst_hdr.biBitCount);
    const src_stride: i32 = rowStride(src_hdr.biWidth, src_hdr.biBitCount);
    const w_out: i16 = out.right -% out.left;
    const h_out: i16 = out.bottom -% out.top;
    const off_x: i16 = out.left -% x_dst;
    const off_y: i16 = out.top -% y_dst;
    const e: i16 = off_x +% x_src;
    const t: i16 = (off_y +% y_src) +% h_out;
    const src_off: i32 = @as(i32, e) +% (@as(i32, src_h) - @as(i32, t)) *% src_stride;

    var dst_step: i32 = dst_stride;
    var dst_row: i32 = undefined;
    if (dir < 0) {
        dst_step = -dst_stride;
        dst_row = out.bottom -% 1;
    } else {
        dst_row = @as(i32, dst_h) - @as(i32, out.top +% h_out);
    }
    const dst_off: i32 = @as(i32, out.left) +% dst_stride *% dst_row;
    try rowsCopy32(dst_bits, dst_off, src_bits, src_off, w_out, h_out, src_stride, dst_step, fixes);
    return true;
}

// @orig 1018:0000 clear_system_palette
/// Realizes an all-black PC_NOCOLLAPSE palette on the screen DC to reset the
/// system palette. The platform's screen starts black with the static
/// colours: nothing to do.
pub fn clearSystemPalette() void {}

// @orig 1018:02e0 read_dib_info
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

// @orig 1018:0105 load_dib
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

// @orig 1010:04b4 dib_copy oracle=documented
test "copy places a bottom-up DIB by picture coordinates" {
    var dst: [32]u8 = @splat(0);
    const src = [_]u8{ 1, 2, 3, 4, 5, 6, 7, 8 };
    const dh = hdr(8, 4);
    const sh = hdr(4, 2);
    try testing.expect(try copy(&dh, &dst, 1, 1, &src, &sh, .{}));
    try testing.expectEqualSlices(u8, &.{ 0, 1, 2, 3, 4, 0, 0, 0 }, dst[8..16]);
    try testing.expectEqualSlices(u8, &.{ 0, 5, 6, 7, 8, 0, 0, 0 }, dst[16..24]);
}

// @orig 1000:0234 dib_rows_copy32 oracle=documented
test "opaque copy skips index 0 in the last columns (B12) unless fixed" {
    const src = [_]u8{ 1, 0, 2, 0, 3, 0, 0 };
    var dst: [7]u8 = @splat(9);
    try rowsCopy32(&dst, 0, &src, 0, 7, 1, 7, 7, .{});
    try testing.expectEqualSlices(u8, &.{ 1, 0, 2, 0, 3, 9, 9 }, &dst);
    dst = @splat(9);
    try rowsCopy32(&dst, 0, &src, 0, 7, 1, 7, 7, .{ .opaque_copy_black_tail = true });
    try testing.expectEqualSlices(u8, &.{ 1, 0, 2, 0, 3, 0, 0 }, &dst);
}

// @orig 1010:06f1 dib_copy_rect oracle=documented
test "copyRect copies a sub-rectangle, opaque" {
    var dst: [32]u8 = @splat(9);
    // 4x2 source, bottom row first in memory.
    const src = [_]u8{ 1, 2, 3, 4, 5, 6, 7, 8 };
    const dh = hdr(8, 4);
    const sh = hdr(4, 2);
    // The whole source, placed at (0, 0): the same picture as `copy`.
    try testing.expect(try copyRect(&dh, &dst, 0, 0, &src, &sh, 0, 0, 4, 2, .{}));
    try testing.expectEqualSlices(u8, &.{ 1, 2, 3, 4 }, dst[16..20]);
    try testing.expectEqualSlices(u8, &.{ 5, 6, 7, 8 }, dst[24..28]);
    // Clamped to the source: asking for more than it has copies the same.
    dst = @splat(9);
    try testing.expect(try copyRect(&dh, &dst, 0, 0, &src, &sh, 0, 0, 9, 9, .{}));
    try testing.expectEqualSlices(u8, &.{ 1, 2, 3, 4, 9 }, dst[16..21]);
    // Entirely outside the destination.
    try testing.expect(!try copyRect(&dh, &dst, 20, 0, &src, &sh, 0, 0, 4, 2, .{}));
}

// @orig 1010:0000 dib_copy_transparent oracle=documented
test "copyTransparent skips the key colour" {
    var dst: [16]u8 = @splat(9);
    const src = [_]u8{ 5, 7, 5, 7, 7, 5, 7, 5 };
    const dh = hdr(4, 4);
    const sh = hdr(4, 2);
    try testing.expect(try copyTransparent(&dh, &dst, 0, 0, &src, &sh, 0, 0, 4, 2, 7));
    try testing.expectEqualSlices(u8, &.{ 5, 9, 5, 9 }, dst[8..12]);
}

// @orig 1018:0105 load_dib oracle=asset
test "loadDib reads a SAUNA bitmap from the disc" {
    var h = headless.Headless.init(testing.allocator, testing.io, .{});
    defer h.deinit();
    const plat = h.platform();
    const file = try std.Io.Dir.cwd().readFileAlloc(testing.io, "assets/SAUNA/3FPAC.BMP", testing.allocator, .limited(1 << 24));
    defer testing.allocator.free(file);
    const dib = loadDib(testing.allocator, plat, .{}, "\\SAUNA\\3FPAC.BMP") orelse return error.TestUnexpectedResult;
    defer {
        testing.allocator.free(dib.bits);
        testing.allocator.destroy(dib);
    }
    const off = std.mem.readInt(u32, file[10..14], .little);
    try testing.expectEqual(std.mem.readInt(i32, file[18..22], .little), dib.header.biWidth);
    try testing.expectEqualSlices(u8, file[off..][0..dib.bits.len], dib.bits);
    try testing.expect(loadDib(testing.allocator, plat, .{}, "nosuch.bmp") == null);
}
