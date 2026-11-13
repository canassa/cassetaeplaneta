//! Port unit `dib` (module). BMP loading, palette remap, 8-bit row blitters (32-bit segment) and the RLE sprite blitter.
//!
//! The original passes DIBs as far pointers into global memory blocks and
//! walks them with "huge" pointer arithmetic (`__AHSHIFT`). The port uses
//! flat byte slices: a destination or source is `(header, bits)` and every
//! offset is a plain index into `bits`. Geometry is computed with the
//! original's 16-bit `int` arithmetic; the row blitters work on 32-bit
//! offsets like the 32-bit segment-1000 code does.
//!
//! The original never bounds-checks the offsets it computes. Where a slice
//! access would fall outside the buffer (malformed header, corrupt RLE
//! data), the port returns `error.LimitExceeded` instead of corrupting memory.

const std = @import("std");
const object = @import("core/object.zig");
const cstr = @import("core/cstr.zig");
const Fixes = @import("core/fixes.zig").Fixes;
const platform = @import("platform/platform.zig");
const Platform = platform.Platform;

pub const Dib = object.Dib;
pub const BitmapInfoHeader = object.BitmapInfoHeader;
pub const RgbQuad = object.RgbQuad;

pub const Error = error{ LimitExceeded, Fatal };

/// Row length in bytes, 4-byte aligned: `((width * bitCount + 0x1f) & 0xffe7) >> 3`
/// in 16-bit arithmetic (the `AND AL,0xe7` only touches the low byte).
fn rowStride(width: i32, bit_count: u16) u16 {
    const w: u16 = @truncate(@as(u32, @bitCast(width)));
    const x: u16 = (w *% bit_count) +% 0x1f;
    return (x & 0xffe7) >> 3;
}

/// Number of colour table entries as the original counts them (`biClrUsed`,
/// or `1 << bitCount` for up to 8 bits when it is 0), as a 16-bit `int`.
fn colorCount(h: *const BitmapInfoHeader) u16 {
    if (h.biClrUsed == 0 and h.biBitCount < 9) {
        return @as(u16, 1) << @intCast(h.biBitCount & 0x1f);
    }
    return @truncate(h.biClrUsed);
}

/// A rectangle as Win16 `RECT` (all `int`).
const Rc = struct { left: i16, top: i16, right: i16, bottom: i16 };

/// USER `IntersectRect`: true (and `out` set) when the intersection is not
/// empty.
fn intersectRect(a: Rc, b: Rc, out: *Rc) bool {
    const r: Rc = .{
        .left = @max(a.left, b.left),
        .top = @max(a.top, b.top),
        .right = @min(a.right, b.right),
        .bottom = @min(a.bottom, b.bottom),
    };
    if (r.left >= r.right or r.top >= r.bottom) {
        out.* = .{ .left = 0, .top = 0, .right = 0, .bottom = 0 };
        return false;
    }
    out.* = r;
    return true;
}

/// Index of the first byte of a `width` x `height` pixel block starting at
/// `off`, rows `stride` apart: checks both ends against `len`.
fn checkBlock(len: usize, off: i64, width: i64, height: i64, stride: i64) Error!void {
    if (width <= 0 or height <= 0) return;
    const last = off + stride * (height - 1);
    const lo = @min(off, last);
    const hi = @max(off, last) + width;
    if (lo < 0 or hi > len) return error.LimitExceeded;
}

// @orig 1000:0114 dib_rows_copy32
/// Copies `height` rows of `width` bytes from `src[src_off..]` to
/// `dst[dst_off..]`; the row pointers advance by `src_stride` and
/// `dst_stride` (signed: a top-down destination walks upwards).
///
/// Original bug B12: each row is copied four bytes at a time unconditionally,
/// but the last `width & 3` bytes go through the transparent variant's loop
/// with the key (AH) left at 0, so index 0 is not copied there. Fixed by
/// `fixes.opaque_copy_black_tail`.
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
    if (width == 0) return;
    if (width < 0 or height <= 0) return error.LimitExceeded;
    try checkBlock(dst.len, dst_off, width, height, dst_stride);
    try checkBlock(src.len, src_off, width, height, src_stride);
    const w: usize = @intCast(width);
    const body = w & ~@as(usize, 3);
    var d: i64 = dst_off;
    var s: i64 = src_off;
    var rows: i32 = height;
    while (rows != 0) : (rows -= 1) {
        const du: usize = @intCast(d);
        const su: usize = @intCast(s);
        @memcpy(dst[du..][0..body], src[su..][0..body]);
        for (body..w) |i| {
            const c = src[su + i];
            if (c != 0 or fixes.opaque_copy_black_tail) dst[du + i] = c;
        }
        d += dst_stride;
        s += src_stride;
    }
}

// @orig 1000:0024 dib_rows_copy_transparent32
/// Like `rowsCopy32`, but source bytes equal to `key` are not copied (all
/// `width` bytes of every row are tested).
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
    if (width == 0) return;
    if (width < 0 or height <= 0) return error.LimitExceeded;
    try checkBlock(dst.len, dst_off, width, height, dst_stride);
    try checkBlock(src.len, src_off, width, height, src_stride);
    const w: usize = @intCast(width);
    var d: i64 = dst_off;
    var s: i64 = src_off;
    var rows: i32 = height;
    while (rows != 0) : (rows -= 1) {
        const du: usize = @intCast(d);
        const su: usize = @intCast(s);
        for (0..w) |i| {
            const c = src[su + i];
            if (c != key) dst[du + i] = c;
        }
        d += dst_stride;
        s += src_stride;
    }
}

/// The geometry shared by `copy` and `copyTransparent`.
const Plan = struct {
    dst_off: i32,
    src_off: i32,
    width: i32,
    height: i32,
    src_stride: i32,
    dst_stride: i32,
};

/// Clips the rectangle (`x_dst`, `y_dst`, `w`, `cx`) to the destination and
/// computes where the first row (the bottom one) starts. Null: nothing to
/// draw. `src_h` is the source's height; `y_src`/`x_src` offset into it.
fn plan(
    dst_hdr: *const BitmapInfoHeader,
    src_hdr: *const BitmapInfoHeader,
    x_dst: i16,
    y_dst: i16,
    x_src: i16,
    y_src: i16,
    w: i16,
    cx: i16,
) ?Plan {
    var dst_h: i16 = @truncate(dst_hdr.biHeight);
    const src_h: i16 = @truncate(src_hdr.biHeight);
    var dir: i16 = 1;
    const rect: Rc = .{ .left = x_dst, .top = y_dst, .right = x_dst +% w, .bottom = y_dst +% cx };
    if (dst_h < 0) {
        dir = -1;
        dst_h = -%dst_h;
    }
    const clip: Rc = .{ .left = 0, .top = 0, .right = @truncate(dst_hdr.biWidth), .bottom = dst_h };
    var out: Rc = undefined;
    if (!intersectRect(clip, rect, &out)) return null;

    const dst_stride: i32 = rowStride(dst_hdr.biWidth, dst_hdr.biBitCount);
    const src_stride: i32 = rowStride(src_hdr.biWidth, src_hdr.biBitCount);
    const w_out: i16 = out.right -% out.left;
    const h_out: i16 = out.bottom -% out.top;

    // Source: the memory row of the rectangle's bottom picture row.
    const t: i16 = h_out -% y_dst +% out.top +% y_src;
    const src_row: i32 = @as(i32, src_h) - @as(i32, t);
    const x_off: i16 = out.left -% x_dst +% x_src;
    const src_off: i32 = @as(i32, x_off) +% src_row *% src_stride;

    // Destination: the same row, counted from the bottom (or the top, for a
    // top-down DIB, whose stride is then negative).
    var dst_step: i32 = dst_stride;
    var dst_row: i32 = undefined;
    if (dir < 0) {
        dst_step = -dst_stride;
        dst_row = out.bottom -% 1;
    } else {
        dst_row = @as(i32, dst_h) - @as(i32, out.top +% h_out);
    }
    const dst_off: i32 = @as(i32, out.left) +% dst_stride *% dst_row;
    return .{
        .dst_off = dst_off,
        .src_off = src_off,
        .width = w_out,
        .height = h_out,
        .src_stride = src_stride,
        .dst_stride = dst_step,
    };
}

// @orig 1010:0000 dib_copy_transparent
/// Copies the `width` x `height` rectangle at (`x_src`, `y_src`) of the 8-bit
/// DIB `src` to (`x_dst`, `y_dst`) of `dst`, clipped to the destination,
/// skipping source pixels equal to `key`. Returns true if anything was drawn.
/// `dst_bits` starts at the destination's first pixel (the original ignores
/// the offset of that pointer).
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
    const src_w: i16 = @truncate(src_hdr.biWidth);
    const src_h: i16 = @truncate(src_hdr.biHeight);
    var w = width;
    if (width +% x_src > src_w) w = src_w -% x_src;
    var cx = height;
    if (height +% y_src > src_h) cx = src_h -% y_src;
    const p = plan(dst_hdr, src_hdr, x_dst, y_dst, x_src, y_src, w, cx) orelse return false;
    try rowsCopyTransparent32(dst_bits, p.dst_off, src_bits, p.src_off, p.width, p.height, p.src_stride, p.dst_stride, key);
    return true;
}

// @orig 1010:01e0 dib_copy
/// Copies the whole 8-bit DIB `src` to (`x_dst`, `y_dst`) of `dst`, clipped to
/// the destination. Returns true if anything was drawn. Subject to bug B12
/// (see `rowsCopy32`).
pub fn copy(
    dst_hdr: *const BitmapInfoHeader,
    dst_bits: []u8,
    x_dst: i16,
    y_dst: i16,
    src_bits: []const u8,
    src_hdr: *const BitmapInfoHeader,
    fixes: Fixes,
) Error!bool {
    const w: i16 = @truncate(src_hdr.biWidth);
    const h: i16 = @truncate(src_hdr.biHeight);
    const p = plan(dst_hdr, src_hdr, x_dst, y_dst, 0, 0, w, h) orelse return false;
    try rowsCopy32(dst_bits, p.dst_off, src_bits, p.src_off, p.width, p.height, p.src_stride, p.dst_stride, fixes);
    return true;
}

/// The Win16 `_splitpath` file name part (no drive, directory or extension).
fn splitFname(path: []const u8) []const u8 {
    var start: usize = 0;
    if (path.len >= 2 and path[1] == ':') start = 2;
    if (std.mem.lastIndexOfAny(u8, path, "\\/")) |i| start = i + 1;
    const rest = path[start..];
    const dot = std.mem.lastIndexOfScalar(u8, rest, '.') orelse rest.len;
    return rest[0..dot];
}

// @orig 1010:05d8 read_dib_info
/// Reads a DIB's header and colour table from the open file `fh` (a BMP file
/// or a bare DIB), converting an OS/2 core header, and leaves the file
/// positioned at the pixel data. Returns a `Dib` with empty `bits`, or null
/// on failure. The original allocates `biSize + 4 * colours` bytes; the port
/// holds at most 256 colours and a 40-byte header (anything else fails).
pub fn readDibInfo(plat: Platform, fh: ?platform.File) ?Dib {
    const f = fh orelse return null;
    const pos = plat.seek(f, 0, .cur);
    var bf: [14]u8 = undefined;
    if (plat.read(f, &bf) != 14) return null;
    var bf_off_bits: u32 = std.mem.readInt(u32, bf[10..14], .little);
    if (std.mem.readInt(u16, bf[0..2], .little) != 0x4d42) {
        bf_off_bits = 0;
        _ = plat.seek(f, pos, .set);
    }
    var raw: [40]u8 = undefined;
    if (plat.read(f, &raw) != 40) return null;
    var bi = std.mem.bytesToValue(BitmapInfoHeader, &raw);
    const core = (bi.biSize & 0xffff) == 0xc;
    if (core) {
        const bw: i16 = @bitCast(std.mem.readInt(u16, raw[4..6], .little));
        const bh: i16 = @bitCast(std.mem.readInt(u16, raw[6..8], .little));
        bi = .{
            .biSize = 0x28,
            .biWidth = bw,
            .biHeight = bh,
            .biPlanes = std.mem.readInt(u16, raw[8..10], .little),
            .biBitCount = std.mem.readInt(u16, raw[10..12], .little),
            .biCompression = 0,
            .biSizeImage = 0,
            .biXPelsPerMeter = 0,
            .biYPelsPerMeter = 0,
            .biClrUsed = 0,
            .biClrImportant = 0,
        };
        _ = plat.seek(f, -28, .cur);
    } else if (bi.biSize != 0x28) return null;

    const n = colorCount(&bi);
    if (bi.biSizeImage == 0) {
        bi.biSizeImage = @as(u32, rowStride(bi.biWidth, bi.biBitCount)) *%
            @as(u32, @as(u16, @truncate(@as(u32, @bitCast(bi.biHeight)))));
    }
    if (bi.biClrUsed == 0) {
        bi.biClrUsed = if (bi.biBitCount < 9) @as(u32, 1) << @intCast(bi.biBitCount & 0x1f) else 0;
    }
    if (n > 256) return null;

    var dib: Dib = .{ .header = bi, .colors = @splat(.{}), .bits = &.{} };
    if (n != 0) {
        if (core) {
            // RGBTRIPLE table: widened to RGBQUADs.
            var tri: [768]u8 = @splat(0);
            _ = plat.read(f, tri[0 .. @as(usize, n) * 3]);
            for (0..n) |i| {
                dib.colors[i] = .{ .blue = tri[i * 3], .green = tri[i * 3 + 1], .red = tri[i * 3 + 2], .reserved = 0 };
            }
        } else {
            _ = plat.read(f, std.mem.sliceAsBytes(dib.colors[0..n]));
        }
    }
    if (bf_off_bits != 0) {
        _ = plat.seek(f, @bitCast(bf_off_bits +% @as(u32, @bitCast(pos))), .set);
    }
    return dib;
}

// @orig 1010:041c load_dib
/// Loads a DIB (header, colours and pixels) from the file `name`, or else
/// from `<drive_cd>pan\bmp\<name without path and extension>.bmp`
/// (`drive_cd` is `g_driveCD`). Returns null if not found or out of memory.
/// The original also tries a bitmap resource of that name between the two;
/// the port has no resources.
///
/// When the file opens but is not a readable DIB, the original returns without
/// closing it (BUGS.md B13; `fixes.close_unreadable_dib` closes it). The
/// fallback path is formatted into `path_buf` (`g.dibPathBuf`, 50 bytes in
/// the original, unchecked: a longer path is `error.LimitExceeded`).
pub fn loadDib(gpa: std.mem.Allocator, plat: Platform, fixes: Fixes, path_buf: []u8, drive_cd: []const u8, name: []const u8) Error!?*Dib {
    const nm = cstr.slice(name);
    var fh = plat.open(nm, .read);
    if (fh == null) {
        const cd = cstr.slice(drive_cd);
        const fname = splitFname(nm);
        if (cd.len + "pan\\bmp\\".len + fname.len + ".bmp".len >= path_buf.len) return error.LimitExceeded;
        const path = cstr.print(path_buf, "{s}pan\\bmp\\{s}.bmp", .{ cd, fname });
        fh = plat.open(path, .read);
        if (fh == null) return null;
    }
    const f = fh.?;
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
    plat.close(f);
    return dib;
}

// @orig 1010:0832 dib_remap8
/// Translates every byte of an 8-bit pixel buffer through `map`.
pub fn remap8(bits: []u8, map: *const [256]u8) void {
    for (bits) |*b| b.* = map[b.*];
}

// @orig 1010:088c dib_remap4
/// Translates both nibbles of every byte of a 4-bit pixel buffer through
/// `map` (entries are used as given: `map[lo] | map[hi] << 4`, as a byte).
pub fn remap4(bits: []u8, map: *const [256]u8) void {
    for (bits) |*b| b.* = map[b.* & 0xf] | (map[b.* >> 4] << 4);
}

// @orig 1010:08fc dib_remap_rle8
/// Translates the pixel values of RLE8-compressed `bits` through `map`,
/// leaving the run codes alone. Stops at the end-of-bitmap code; the original
/// has no size limit, so data without one returns `error.LimitExceeded`.
pub fn remapRle8(bits: []u8, map: *const [256]u8) Error!void {
    var p: usize = 0;
    while (true) {
        if (p + 1 >= bits.len) return error.LimitExceeded;
        const count = bits[p];
        const value = bits[p + 1];
        if (count != 0) {
            // Encoded run: one pixel value.
            bits[p + 1] = map[value];
            p += 2;
            continue;
        }
        p += 2;
        switch (value) {
            0 => {}, // end of line
            1 => return, // end of bitmap
            2 => p += 2, // delta
            else => {
                // Absolute run of `value` pixels, padded to a word.
                if (p + value > bits.len) return error.LimitExceeded;
                for (bits[p..][0..value]) |*b| b.* = map[b.*];
                p += value;
                if (value & 1 != 0) p += 1;
            },
        }
    }
}

// @orig 1010:09d0 hmemmove_backward
/// Copies `count` bytes from `src` to `dst`, last byte first (so an
/// overlapping move to a higher address is safe).
pub fn hmemmoveBackward(dst: []u8, src: []const u8, count: u32) Error!void {
    if (count > dst.len or count > src.len) return error.LimitExceeded;
    var i: usize = count;
    while (i != 0) {
        i -= 1;
        dst[i] = src[i];
    }
}

fn rleWord(rle: []const u8, off: i64) Error!u16 {
    if (off < 0 or off + 2 > rle.len) return error.LimitExceeded;
    const o: usize = @intCast(off);
    return std.mem.readInt(u16, rle[o..][0..2], .little);
}

// @orig 1018:b78a rle_blit_transparent
/// Draws the run-length encoded sprite `rle` (rows of `{len, type}` runs) onto
/// the destination DIB, clipped to it. Only the clipping and the walk over the
/// run table are ported: the literal-run copy in the original is a near call
/// to 1018:00ac, the middle of an unrelated instruction (BUGS.md L1), so
/// reaching a literal run (type 2) returns `error.Fatal` where the original
/// would crash. Nothing else it does is visible, so the destination
/// pointer arithmetic is not carried out. The source DIB and `key` arguments
/// are not read by the original either.
pub fn rleBlitTransparent(
    dst_hdr: *const BitmapInfoHeader,
    x_dst: i16,
    y_dst: i16,
    rle: []const u8,
    x_src: i16,
    y_src: i16,
    width: i16,
    height: i16,
) Error!void {
    const dst_w: u16 = @truncate(@as(u32, @bitCast(dst_hdr.biWidth)));
    var dst_h: i16 = @truncate(dst_hdr.biHeight);
    if (dst_h < 0) dst_h = -%dst_h;
    var w = width;
    var h = height;
    var xd = x_dst;
    var yd = y_dst;
    var skip_x: i16 = undefined;
    var skip_y: i16 = undefined;

    if (xd < 0) {
        if (-%xd > x_src) {
            w +%= xd;
            skip_x = -%xd;
            xd = 0;
        } else {
            w -%= x_src;
            skip_x = x_src;
            xd +%= x_src;
        }
    } else {
        w -%= x_src;
        skip_x = x_src;
    }
    if (dst_w < @as(u16, @bitCast(w +% xd))) w = @as(i16, @bitCast(dst_w)) -% xd;

    if (yd < 0) {
        if (-%yd > y_src) {
            h +%= yd;
            skip_y = -%yd;
            yd = 0;
        } else {
            h -%= y_src;
            skip_y = y_src;
            yd +%= y_src;
        }
    } else {
        h -%= y_src;
        skip_y = y_src;
    }
    if (h +% yd > dst_h) h = dst_h -% yd;

    if (!(h > 0 and w > 0)) return;

    var row: i64 = 0; // offset of the current row record in `rle`
    var i: i16 = skip_y;
    while (i > 0) : (i -= 1) {
        row += @as(i16, @bitCast(try rleWord(rle, row)));
    }
    var rows: i16 = h;
    while (rows != 0) : (rows -%= 1) {
        var run: i64 = row + 4;
        var acc: i16 = 0;
        if (skip_x > acc) {
            while (true) {
                const len = try rleWord(rle, run);
                const kind = try rleWord(rle, run + 2);
                acc +%= @bitCast(len);
                if (acc > skip_x) {
                    // The visible tail of a run that straddles the left edge.
                    if (kind == 2) return error.Fatal;
                }
                if (kind == 2) run += @as(i16, @bitCast(len));
                run += 4;
                if (!(acc < skip_x)) break;
            }
        }
        acc -%= skip_x;
        while (acc < w) {
            const len = try rleWord(rle, run);
            const kind = try rleWord(rle, run + 2);
            if (kind == 2) return error.Fatal;
            run += 4;
            acc +%= @bitCast(len);
        }
        row += @as(i16, @bitCast(try rleWord(rle, row)));
    }
}

// ---- tests ----

const testing = std.testing;
const headless = @import("platform/headless.zig");

fn hdr(w: i32, h: i32) BitmapInfoHeader {
    return .{ .biWidth = w, .biHeight = h, .biBitCount = 8 };
}

// @orig 1010:01e0 dib_copy oracle=documented
test "copy places a bottom-up DIB by picture coordinates" {
    // dst 8x4 (rows of 8), src 4x2 at (1,1): picture row 1 is memory row 2.
    var dst: [32]u8 = @splat(0);
    const src = [_]u8{ 1, 2, 3, 4, 5, 6, 7, 8 }; // memory row 0, then row 1
    const dh = hdr(8, 4);
    const sh = hdr(4, 2);
    try testing.expect(try copy(&dh, &dst, 1, 1, &src, &sh, .{}));
    // src memory row 0 is the picture's bottom row, picture y = 2 = dst memory row 1.
    try testing.expectEqualSlices(u8, &.{ 0, 1, 2, 3, 4, 0, 0, 0 }, dst[8..16]);
    try testing.expectEqualSlices(u8, &.{ 0, 5, 6, 7, 8, 0, 0, 0 }, dst[16..24]);
    try testing.expectEqual(@as(u8, 0), dst[0]);
    try testing.expectEqual(@as(u8, 0), dst[24]);
}

// @orig 1010:01e0 dib_copy oracle=documented
test "copy clips to the destination and reports nothing drawn" {
    var dst: [16]u8 = @splat(9);
    const src = [_]u8{ 1, 2, 3, 4, 1, 2, 3, 4 };
    const dh = hdr(4, 4);
    const sh = hdr(4, 2);
    try testing.expect(!try copy(&dh, &dst, 10, 0, &src, &sh, .{}));
    try testing.expect(!try copy(&dh, &dst, 0, -2, &src, &sh, .{}));
    // Hanging off the left edge: only the right two columns are drawn.
    try testing.expect(try copy(&dh, &dst, -2, 2, &src, &sh, .{}));
    try testing.expectEqualSlices(u8, &.{ 3, 4, 9, 9 }, dst[0..4]);
}

// @orig 1000:0114 dib_rows_copy32 oracle=documented
test "opaque copy skips index 0 in the last columns (B12) unless fixed" {
    const src = [_]u8{ 1, 0, 2, 0, 3, 0, 0 }; // width 7: 4 + 3 tail
    var dst: [7]u8 = @splat(9);
    try rowsCopy32(&dst, 0, &src, 0, 7, 1, 7, 7, .{});
    try testing.expectEqualSlices(u8, &.{ 1, 0, 2, 0, 3, 9, 9 }, &dst);
    dst = @splat(9);
    try rowsCopy32(&dst, 0, &src, 0, 7, 1, 7, 7, .{ .opaque_copy_black_tail = true });
    try testing.expectEqualSlices(u8, &.{ 1, 0, 2, 0, 3, 0, 0 }, &dst);
}

// @orig 1010:0000 dib_copy_transparent oracle=documented
test "copyTransparent skips the key colour" {
    var dst: [16]u8 = @splat(9);
    const src = [_]u8{ 5, 7, 5, 7, 7, 5, 7, 5 };
    const dh = hdr(4, 4);
    const sh = hdr(4, 2);
    try testing.expect(try copyTransparent(&dh, &dst, 0, 0, &src, &sh, 0, 0, 4, 2, 7));
    try testing.expectEqualSlices(u8, &.{ 5, 9, 5, 9 }, dst[8..12]);
    try testing.expectEqualSlices(u8, &.{ 9, 5, 9, 5 }, dst[12..16]);
}

// @orig 1010:041c load_dib oracle=asset
test "loadDib reads a bmp from the disc" {
    var h = headless.Headless.init(testing.allocator, testing.io, .{});
    defer h.deinit();
    const plat = h.platform();
    const file = try std.Io.Dir.cwd().readFileAlloc(testing.io, "assets/ABERT.BMP", testing.allocator, .limited(1 << 24));
    defer testing.allocator.free(file);
    var path_buf: [50]u8 = undefined;
    const dib = try loadDib(testing.allocator, plat, .{}, &path_buf, "", "\\ABERT.BMP") orelse return error.TestUnexpectedResult;
    defer {
        testing.allocator.free(dib.bits);
        testing.allocator.destroy(dib);
    }
    const off = std.mem.readInt(u32, file[10..14], .little);
    try testing.expectEqual(std.mem.readInt(i32, file[18..22], .little), dib.header.biWidth);
    try testing.expectEqual(std.mem.readInt(i32, file[22..26], .little), dib.header.biHeight);
    try testing.expectEqualSlices(u8, file[54..58], std.mem.asBytes(&dib.colors[0]));
    try testing.expectEqualSlices(u8, file[off..][0..dib.bits.len], dib.bits);
    // The pan\bmp fallback finds the same bitmap by name.
    try testing.expect(try loadDib(testing.allocator, plat, .{}, &path_buf, "\\", "nosuch.bmp") == null);
}

// @orig 1010:09d0 hmemmove_backward oracle=documented
test "hmemmoveBackward is overlap safe moving up" {
    var buf = [_]u8{ 1, 2, 3, 4, 0, 0 };
    try hmemmoveBackward(buf[2..], buf[0..], 4);
    try testing.expectEqualSlices(u8, &.{ 1, 2, 1, 2, 3, 4 }, &buf);
}

// @orig 1010:08fc dib_remap_rle8 oracle=documented
test "remap helpers translate pixels but not run codes" {
    var map: [256]u8 = undefined;
    for (&map, 0..) |*m, i| m.* = @intCast((i + 1) & 0xff);
    var rle = [_]u8{ 3, 10, 0, 3, 20, 21, 22, 0, 0, 0, 0, 1 };
    try remapRle8(&rle, &map);
    try testing.expectEqualSlices(u8, &.{ 3, 11, 0, 3, 21, 22, 23, 0, 0, 0, 0, 1 }, &rle);
    var b = [_]u8{ 0x12, 0xff };
    remap4(&b, &map);
    try testing.expectEqualSlices(u8, &.{ 0x23, 0x10 }, &b);
    remap8(&b, &map);
    try testing.expectEqualSlices(u8, &.{ 0x24, 0x11 }, &b);
}
