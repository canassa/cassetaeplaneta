//! Port unit `scaled` (module) of JARDIM.EXE. The scaled DIB copies: `dib_blit_scaled_column` and
//! `dib_stretch_copy_transparent` with their 32-bit cores 1000:0024 (the wall column, depth
//! shading) and 1018:0024 (the transparent sprite stretch; BUGS.md J5).
//!
//! The two cores are transcribed from the `objdump -mi386` listings of their segments (Ghidra
//! decodes them as 16-bit): 32-bit wrapping arithmetic, `SAR` as `>>` on `i32`, the loop-counter
//! tests exactly as compiled. Their memory is a pair of slices standing for the two selectors
//! (destination and source); an access outside a slice is the original's segment-limit fault
//! (`error.Fault`: reads and writes in the original's order, so the bytes written before it match).
//! The 16-bit wrappers compute the offsets and strides the cores take (the huge-pointer arithmetic
//! the original keeps after the live call is dead) and panic on a fault naming its BUGS.md entry;
//! their `try…` forms return `error.Fault`, for the tests.
//!
//! Bits slices start at the far pointer's offset: the original adds the pointer's offset word to
//! the computed start (`dstBits & 0xffff`), here always 0 (a DIB's bits are a slice of their own).
//! Proved against the original in tools/oracle (`tools/oracle/jardim32.py`, vectors in
//! `src/jardim/testdata/`).

const std = @import("std");
const Fixes = @import("../core/fixes.zig").Fixes;
const object = @import("core/object.zig");

pub const BitmapInfoHeader = object.BitmapInfoHeader;

pub const Error = error{Fault};

// ---- memory: the selectors' limits ----

fn rdDword(mem: []const u8, off: u32) Error!u32 {
    if (@as(u64, off) + 4 > mem.len) return error.Fault;
    return std.mem.readInt(u32, mem[off..][0..4], .little);
}

fn wrDword(mem: []u8, off: u32, v: u32) Error!void {
    if (@as(u64, off) + 4 > mem.len) return error.Fault;
    std.mem.writeInt(u32, mem[off..][0..4], v, .little);
}

fn rdByte(mem: []const u8, off: u32) Error!u8 {
    if (off >= mem.len) return error.Fault;
    return mem[off];
}

fn wrByte(mem: []u8, off: u32, v: u8) Error!void {
    if (off >= mem.len) return error.Fault;
    mem[off] = v;
}

/// `add reg, imm32` of a signed step.
fn step(off: u32, by: i32) u32 {
    return off +% @as(u32, @bitCast(by));
}

// @orig 1000:0024 blit_scaled_column
/// Copies ONE source column of 4 pixels (a dword per row) into `dst_rows` destination rows with
/// nearest-row scaling and depth shading: every dword gets `delta` added, `delta` =
/// `shade_levels * shade_step` when `dist > shade_levels << 6`, else `(dist >> 6) * shade_step`
/// (the 16-bit caller always passes 3 and 0x17171717). `src_rows` >= `dst_rows` is the minify
/// Bresenham (writes row 0, then once per step; one row more than the slice when 2D < S; a
/// `src_rows` of 1 would loop 2^32 times: it runs until the first access outside the slice);
/// `src_rows` < `dst_rows` magnifies, clipped by assuming the view window is `src_rows` tall
/// (skip = ((D - S) >> 1) + (D & 1), then exactly S rows). Offsets and strides are the 32-bit
/// values the caller computed; strides are signed byte steps per row.
pub fn blitScaledColumn(
    dst: []u8,
    dst_off: u32,
    src: []const u8,
    src_off: u32,
    dst_rows: i32,
    src_rows: i32,
    dst_stride: i32,
    src_stride: i32,
    dist: i32,
    shade_levels: i32,
    shade_step: i32,
) Error!void {
    var si = src_off;
    var di = dst_off;
    const delta: u32 = if (dist > shade_levels << 6)
        @bitCast(shade_step *% shade_levels)
    else
        @bitCast((dist >> 6) *% shade_step);

    if (src_rows >= dst_rows) {
        // 0x71: minify.
        const two_d = dst_rows << 1; // [bp-4]
        var d = two_d -% src_rows; // edx
        const d2 = d -% src_rows; // [bp-8]
        try wrDword(dst, di, (try rdDword(src, si)) +% delta);
        var count: u32 = @bitCast(src_rows -% 1); // ecx, tested after `loop` decrements it
        while (true) {
            if (d > 0) {
                d +%= d2;
                si = step(si, src_stride);
                di = step(di, dst_stride);
                try wrDword(dst, di, (try rdDword(src, si)) +% delta);
            } else {
                d +%= two_d;
                si = step(si, src_stride);
            }
            count -%= 1;
            if (count == 0) break;
        }
    } else {
        // 0xb1: magnify.
        const m2s = -%(src_rows << 1); // [bp-0xc]
        var d = m2s +% dst_rows; // edx
        const db = dst_rows +% d; // [bp-8] = 2D - 2S
        const skip = ((dst_rows -% src_rows) >> 1) +% (dst_rows & 1); // [bp-0x14]
        if (skip > 0) {
            di +%= @bitCast((skip -% 1) *% dst_stride);
            const num = src_rows *% skip; // imul low half, then cltd
            if (dst_rows == 0) return error.Fault; // #DE
            const q = @divTrunc(@as(i64, num), @as(i64, dst_rows));
            if (q > std.math.maxInt(i32)) return error.Fault; // #DE (quotient overflow)
            si +%= @bitCast(@as(i32, @intCast(q)) *% src_stride);
        }
        var count: u32 = @bitCast(src_rows); // ecx = [bp+0x1a]
        while (true) {
            if (d <= 0) {
                d +%= db;
                si = step(si, src_stride);
                di = step(di, dst_stride);
            } else {
                d +%= m2s;
                di = step(di, dst_stride);
            }
            try wrDword(dst, di, (try rdDword(src, si)) +% delta);
            count -%= 1;
            if (count == 0) break;
        }
    }
}

/// The state shared by the passes of `blitScaledSpriteTransparent`.
const Sprite = struct {
    dst: []u8,
    src: []const u8,
    key: u8,
    si: u32,
    di: u32,

    /// `mov al,[esi]; cmp al,cl; je skip; mov es:[edi],al`
    fn px(s: *Sprite) Error!void {
        const c = try rdByte(s.src, s.si);
        if (c != s.key) try wrByte(s.dst, s.di, c);
    }
};

// @orig 1018:0024 blit_scaled_sprite_transparent
/// Column-by-column 2-D Bresenham stretch of a `src_w` x `src_h` source to `dst_w` x `dst_h`
/// (pixels equal to `key` are not drawn), `clip_w1` and `clip_h1` being the clip's width and
/// height minus one. The first pixel of the source is at `src_off`, rows `src_step` apart; the
/// destination's at `dst_off`, rows `dst_step` apart. The routine decrements all six extents
/// first. Columns go dst-wise (`src_w' >= dst_w'` minify: the clip is not honoured) or src-wise;
/// within a column the rows likewise, and the magnifying row loop counts `clip_h1 - 1` rows
/// down: BUGS.md J5 (a clip height of 2 starts it at 0, so it never ends: it runs until the
/// first access outside the slices, `error.Fault`). With `fixes.jardim_sprite_last_rows` the
/// loop of 0 draws the two rows left instead.
pub fn blitScaledSpriteTransparent(
    dst: []u8,
    dst_off: u32,
    dst_w: i32,
    dst_h: i32,
    clip_w1: i32,
    clip_h1: i32,
    dst_step: i32,
    src: []const u8,
    src_off: u32,
    src_w: i32,
    src_h: i32,
    src_step: i32,
    key: u8,
    fixes: Fixes,
) Error!void {
    var s: Sprite = .{ .dst = dst, .src = src, .key = key, .si = src_off, .di = dst_off };
    var si0 = src_off; // [bp-0x30]
    var di0 = dst_off; // [bp-0x2c]
    if (clip_h1 == 0 or clip_w1 == 0) return;
    const src_h1 = src_h -% 1; // [bp+0xe]
    const dst_h1 = dst_h -% 1; // [bp+0x2a]
    const clip_h2 = clip_h1 -% 1; // [bp+0x22]
    var src_w1 = src_w -% 1; // [bp+0x12], a counter in the loops
    var dst_w1 = dst_w -% 1; // [bp+0x2e], a counter
    var clip_w2 = clip_w1 -% 1; // [bp+0x26], a counter

    // The row pass is the same for both column variants and chosen by the same compare.
    const inner_min = !(src_h1 < dst_h1);
    const f4 = dst_h1 << 1; // minify: [bp-0xc]
    const f0 = f4 -% src_h1 -% src_h1; // [bp-0x10]
    const fc_min = f4 -% src_h1; // [bp-4] at the start of a column
    const ec = -%(src_h1 << 1); // magnify: [bp-0x14]
    const f0_mag = ec +% dst_h1 +% dst_h1; // [bp-0x10]
    const fc_mag = ec +% dst_h1; // [bp-4]

    const Pass = struct {
        fn run(
            p: *Sprite,
            min: bool,
            sh: i32,
            dh: i32,
            ch: i32,
            f4_: i32,
            f0_: i32,
            fc: i32,
            ec_: i32,
            sstep: i32,
            dstep: i32,
            fix: bool,
        ) Error!void {
            if (min) {
                // 0xa2: minify rows (stops after src_h' steps or dst_h' rows).
                var d = fc; // [bp-4]
                var srcleft: i32 = sh; // [bp-0x24]
                var dleft: i32 = dh; // [bp-0x28]
                try p.px();
                while (true) {
                    const e = srcleft;
                    srcleft -%= 1;
                    if (e == 0) break;
                    if (dleft == 0) break;
                    if (d > 0) {
                        d +%= f0_;
                        p.si = step(p.si, sstep);
                        p.di = step(p.di, dstep);
                        dleft -%= 1;
                        try p.px();
                    } else {
                        d +%= f4_;
                        p.si = step(p.si, sstep);
                    }
                }
            } else {
                // 0x155: magnify rows, `ch` (the clip height minus 2) of them. J5: with 0 the
                // counter goes -1, -2, ... and never reaches 0 again.
                var d = fc;
                var srcleft: i32 = sh; // [bp-0x24]
                var count: i32 = ch; // [bp-0x28]
                if (count == 0 and fix) count = 2;
                try p.px();
                while (true) {
                    count -%= 1;
                    if (count == 0) break;
                    if (d <= 0) {
                        d +%= f0_;
                        if (srcleft != 0) {
                            p.si = step(p.si, sstep);
                            srcleft -%= 1;
                        }
                        p.di = step(p.di, dstep);
                    } else {
                        d +%= ec_;
                        p.di = step(p.di, dstep);
                    }
                    try p.px();
                }
            }
        }
    };
    const fix = fixes.jardim_sprite_last_rows;
    const min = inner_min;
    const fc = if (min) fc_min else fc_mag;
    const f0v = if (min) f0 else f0_mag;

    if (!(src_w1 < dst_w1)) {
        // 0x82: the destination columns step (src_w' >= dst_w').
        const e8 = dst_w1 << 1; // [bp-0x18]
        var d_o = e8 -% src_w1; // [bp-8]
        const e4 = d_o -% src_w1; // [bp-0x1c]
        while (true) {
            try Pass.run(&s, min, src_h1, dst_h1, clip_h2, f4, f0v, fc, ec, src_step, dst_step, fix);
            // 0x10b: the next column.
            while (true) {
                const e = src_w1;
                src_w1 -%= 1;
                if (e == 0) return;
                if (dst_w1 == 0) return;
                if (d_o > 0) {
                    d_o +%= e4;
                    si0 +%= 1;
                    s.si = si0;
                    di0 +%= 1;
                    s.di = di0;
                    dst_w1 -%= 1;
                    break;
                }
                d_o +%= e8;
                si0 +%= 1;
            }
        }
    } else {
        // 0x211: the source columns step (src_w' < dst_w'); the clip counts the columns.
        const e0 = -%(src_w1 << 1); // [bp-0x20]
        var d_o = e0 +% dst_w1; // [bp-8]
        const e4 = d_o +% dst_w1; // [bp-0x1c]
        while (true) {
            try Pass.run(&s, min, src_h1, dst_h1, clip_h2, f4, f0v, fc, ec, src_step, dst_step, fix);
            // 0x29e / 0x364: the next column.
            const e = clip_w2;
            clip_w2 -%= 1;
            if (e == 0) return;
            if (d_o > 0) {
                d_o +%= e0;
                di0 +%= 1;
                s.di = di0;
                s.si = si0;
            } else {
                d_o +%= e4;
                if (src_w1 != 0) {
                    si0 +%= 1;
                    s.si = si0;
                    src_w1 -%= 1;
                }
                di0 +%= 1;
                s.di = di0;
            }
        }
    }
}

// ---- the 16-bit wrappers ----

/// `((width * bitCount + 0x1f) & 0xffe7) >> 3` in 16-bit arithmetic.
fn rowStride(width: i32, bit_count: u16) u16 {
    const w: u16 = @truncate(@as(u32, @bitCast(width)));
    const x: u16 = (w *% bit_count) +% 0x1f;
    return (x & 0xffe7) >> 3;
}

fn sext(v: i16) i32 {
    return v;
}

fn lo16(v: i32) i16 {
    return @truncate(v);
}

/// `_aFldiv` of a 32-bit product by a sign-extended word (a zero divisor is the divide fault).
fn ldiv16(num: i32, den: i16) Error!i16 {
    if (den == 0) return error.Fault;
    return lo16(@divTrunc(num, @as(i32, den)));
}

/// Win16 IntersectRect: the intersection, or null when empty.
const Rc = struct { left: i16, top: i16, right: i16, bottom: i16 };

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

// @orig 1068:0000 dib_blit_scaled_column
/// The 4-px-wide wall/door column blit: the column of the source frame that starts `tex_row`
/// rows from its top and is `tex_h` rows tall, at pixel column `tex_col`, scaled into `slice_h`
/// rows of the destination from (`x`, `y`) with the depth shading of `dist`
/// (`blitScaledColumn`). No clipping here. `dst_hdr`/`src_hdr` are the DIB headers (a negative
/// `biHeight` is a top-down destination), `*_bits` the pixel rows. Always returns 1; a fault of
/// the original (BUGS.md "Latent (JARDIM)": a 1-row source loops 2^32 times) is a panic.
pub fn dibBlitScaledColumn(
    dst_hdr: *const BitmapInfoHeader,
    dst_bits: []u8,
    x: i16,
    y: i16,
    slice_h: i16,
    src_bits: []const u8,
    src_hdr: *const BitmapInfoHeader,
    tex_col: i16,
    tex_row: i16,
    tex_h: i16,
    dist: i32,
) bool {
    tryDibBlitScaledColumn(dst_hdr, dst_bits, x, y, slice_h, src_bits, src_hdr, tex_col, tex_row, tex_h, dist) catch
        @panic("BUGS.md latent (JARDIM): blit_scaled_column ran off its selector (1-row source or wild slice)");
    return true;
}

/// `dibBlitScaledColumn` returning `error.Fault` where the original faults.
pub fn tryDibBlitScaledColumn(
    dst_hdr: *const BitmapInfoHeader,
    dst_bits: []u8,
    x: i16,
    y: i16,
    slice_h: i16,
    src_bits: []const u8,
    src_hdr: *const BitmapInfoHeader,
    tex_col: i16,
    tex_row: i16,
    tex_h: i16,
    dist: i32,
) Error!void {
    const dst_height: i16 = lo16(dst_hdr.biHeight);
    const src_height: i16 = lo16(src_hdr.biHeight);
    var dst_stride: i32 = rowStride(dst_hdr.biWidth, dst_hdr.biBitCount); // zero-extended
    const src_stride: i16 = @bitCast(rowStride(src_hdr.biWidth, src_hdr.biBitCount)); // CWD: signed

    const bottom_src: i16 = tex_h +% tex_row;
    const src_start: i32 = (sext(src_height) -% sext(bottom_src)) *% sext(src_stride);
    var dst_start: i32 = undefined;
    if (dst_height < 0) {
        dst_start = sext(slice_h +% y -% 1) *% dst_stride;
        dst_start +%= sext(x);
        dst_stride = -dst_stride;
    } else {
        const bottom: i16 = slice_h +% y;
        dst_start = (sext(dst_height) -% sext(bottom)) *% dst_stride;
        dst_start +%= sext(x);
    }
    try blitScaledColumn(
        dst_bits,
        @bitCast(dst_start),
        src_bits,
        @bitCast(src_start +% sext(tex_col)),
        sext(slice_h),
        sext(tex_h),
        dst_stride,
        sext(src_stride),
        dist,
        3,
        0x17171717,
    );
}

/// Not in the original (`jardim_texture_per_pixel`): `blitScaledColumn`'s row stepping with
/// each of the 4 destination pixels of a row read from its own source column: `src_off` is
/// the first byte of the source row, `cols` the 4 columns. The shading is added per byte.
pub fn blitScaledColumnPerPixel(
    dst: []u8,
    dst_off: u32,
    src: []const u8,
    src_off: u32,
    cols: [4]u8,
    dst_rows: i32,
    src_rows: i32,
    dst_stride: i32,
    src_stride: i32,
    dist: i32,
) Error!void {
    const k: i32 = if (dist > 3 << 6) 3 else dist >> 6;
    const delta: u8 = @intCast(k * 0x17);
    const Row = struct {
        fn copy(d: []u8, di: u32, s_: []const u8, si: u32, c: [4]u8, add: u8) Error!void {
            for (c, 0..) |col, i| try wrByte(d, di +% @as(u32, @intCast(i)), (try rdByte(s_, si +% col)) +% add);
        }
    };
    var si = src_off;
    var di = dst_off;
    if (src_rows <= 1 or dst_rows <= 0) return;
    if (src_rows >= dst_rows) {
        const two_d = dst_rows << 1;
        var d = two_d -% src_rows;
        const d2 = d -% src_rows;
        try Row.copy(dst, di, src, si, cols, delta);
        var count: i32 = src_rows - 1;
        while (count > 0) : (count -= 1) {
            if (d > 0) {
                d +%= d2;
                si = step(si, src_stride);
                di = step(di, dst_stride);
                try Row.copy(dst, di, src, si, cols, delta);
            } else {
                d +%= two_d;
                si = step(si, src_stride);
            }
        }
    } else {
        const m2s = -%(src_rows << 1);
        var d = m2s +% dst_rows;
        const db = dst_rows +% d;
        const skip = ((dst_rows -% src_rows) >> 1) +% (dst_rows & 1);
        if (skip > 0) {
            di +%= @bitCast((skip -% 1) *% dst_stride);
            const q: i64 = @divTrunc(@as(i64, src_rows) * skip, dst_rows);
            si +%= @bitCast(@as(i32, @intCast(q)) *% src_stride);
        }
        var count: i32 = src_rows;
        while (count > 0) : (count -= 1) {
            if (d <= 0) {
                d +%= db;
                si = step(si, src_stride);
                di = step(di, dst_stride);
            } else {
                d +%= m2s;
                di = step(di, dst_stride);
            }
            try Row.copy(dst, di, src, si, cols, delta);
        }
    }
}

/// Not in the original (`jardim_texture_per_pixel`): `dibBlitScaledColumn`'s offsets for
/// `blitScaledColumnPerPixel` (the 4 pixels from the texture columns `cols`).
pub fn dibBlitScaledColumnPerPixel(
    dst_hdr: *const BitmapInfoHeader,
    dst_bits: []u8,
    x: i16,
    y: i16,
    slice_h: i16,
    src_bits: []const u8,
    src_hdr: *const BitmapInfoHeader,
    cols: [4]u8,
    tex_row: i16,
    tex_h: i16,
    dist: i32,
) void {
    const dst_height: i32 = dst_hdr.biHeight;
    var dst_stride: i32 = rowStride(dst_hdr.biWidth, dst_hdr.biBitCount);
    const src_stride: i32 = @as(i16, @bitCast(rowStride(src_hdr.biWidth, src_hdr.biBitCount)));
    const src_start: i32 = (src_hdr.biHeight - (@as(i32, tex_h) + tex_row)) * src_stride;
    var dst_start: i32 = undefined;
    if (dst_height < 0) {
        dst_start = (@as(i32, slice_h) + y - 1) * dst_stride + x;
        dst_stride = -dst_stride;
    } else {
        dst_start = (dst_height - (@as(i32, slice_h) + y)) * dst_stride + x;
    }
    blitScaledColumnPerPixel(dst_bits, @bitCast(dst_start), src_bits, @bitCast(src_start), cols, slice_h, tex_h, dst_stride, src_stride, dist) catch
        @panic("jardim scaled: the per-pixel wall column left its buffers");
}

// @orig 1068:1336 dib_stretch_copy_transparent
/// Clipped, stretched, transparent copy of the `src_w` x `src_h` rectangle at (`src_x`, `src_y`)
/// of the 8-bit DIB `src_bits`/`src_hdr` to the `dst_w` x `dst_h` rectangle at (`dst_x`,
/// `dst_y`) of `dst_bits`/`dst_hdr`; `key` is the transparent colour. True when the
/// destination clip is non-empty (something was drawn), else false. Clamps the source
/// rectangle to the source bitmap (scaling the destination size), moves a negative `dst_x`/`dst_y`
/// into the source offset (the destination is shifted, not cut), clips to the destination, and
/// calls `blitScaledSpriteTransparent` with the clip extents minus one. BUGS.md J5 is a panic
/// here unless `fixes.jardim_sprite_last_rows`; a zero divisor of the clamps (a divide fault) and the other faults of the original panic the same.
pub fn dibStretchCopyTransparent(
    dst_hdr: *const BitmapInfoHeader,
    dst_bits: []u8,
    dst_x: i16,
    dst_y: i16,
    dst_w: i16,
    dst_h: i16,
    src_bits: []const u8,
    src_hdr: *const BitmapInfoHeader,
    src_x: i16,
    src_y: i16,
    src_w: i16,
    src_h: i16,
    key: u8,
    fixes: Fixes,
) bool {
    return tryDibStretchCopyTransparent(dst_hdr, dst_bits, dst_x, dst_y, dst_w, dst_h, src_bits, src_hdr, src_x, src_y, src_w, src_h, key, fixes) catch
        @panic("BUGS.md J5: blit_scaled_sprite_transparent ran off its selector (a magnified sprite with its top on row 478)");
}

/// `dibStretchCopyTransparent` returning `error.Fault` where the original faults.
pub fn tryDibStretchCopyTransparent(
    dst_hdr: *const BitmapInfoHeader,
    dst_bits: []u8,
    dst_x_in: i16,
    dst_y_in: i16,
    dst_w_in: i16,
    dst_h_in: i16,
    src_bits: []const u8,
    src_hdr: *const BitmapInfoHeader,
    src_x_in: i16,
    src_y_in: i16,
    src_w_in: i16,
    src_h_in: i16,
    key: u8,
    fixes: Fixes,
) Error!bool {
    var dst_x = dst_x_in;
    var dst_y = dst_y_in;
    var dst_w = dst_w_in;
    var dst_h = dst_h_in;
    var src_x = src_x_in;
    var src_y = src_y_in;
    var src_w = src_w_in;
    var src_h = src_h_in;
    var dir: i16 = 1; // [bp-0x10]
    var dst_height: i16 = lo16(dst_hdr.biHeight); // [bp-0x12], later |height|
    const src_width: i16 = lo16(src_hdr.biWidth);
    const src_height: i16 = lo16(src_hdr.biHeight);

    // (1) clamp the source rectangle to the source bitmap
    if (src_w +% src_x > src_width) {
        const w1: i16 = src_width -% src_x;
        dst_w = try ldiv16(sext(w1) *% sext(dst_w), src_w);
        src_w = w1;
    }
    if (src_h +% src_y > src_height) {
        const h1: i16 = src_height -% src_y;
        dst_h = try ldiv16(sext(h1) *% sext(dst_h), src_h);
        src_h = h1;
    }
    // (2) a destination left of / above the bitmap shifts the source offset
    if (dst_x < 0) {
        src_x +%= try ldiv16(sext(-%dst_x) *% sext(src_w), dst_w);
        dst_x = 0;
    }
    if (dst_y < 0) {
        src_y +%= try ldiv16(sext(-%dst_y) *% sext(src_h), dst_h);
        dst_y = 0;
    }
    const rect: Rc = .{ .left = dst_x, .top = dst_y, .right = dst_w +% dst_x, .bottom = dst_h +% dst_y };
    if (dst_height < 0) {
        dir = -1;
        dst_height = -%dst_height;
    }
    const clip: Rc = .{ .left = 0, .top = 0, .right = lo16(dst_hdr.biWidth), .bottom = dst_height };
    // (3) clip to the destination
    const out = intersectRect(clip, rect) orelse return false;

    const dst_stride: u16 = rowStride(dst_hdr.biWidth, dst_hdr.biBitCount);
    const src_stride: u16 = rowStride(src_hdr.biWidth, src_hdr.biBitCount);
    const a: i16 = out.left -% dst_x; // [bp-8]
    const c: i16 = out.top -% dst_y; // [bp-0xa]
    const clip_w1: i16 = (out.right -% out.left) -% 1; // [bp-0x18]
    const clip_h1: i16 = (out.bottom -% out.top) -% 1; // [bp-0x1c]
    const local_e: i16 = a +% src_x; // [bp-0xc]
    const local_10: i16 = c +% src_y; // [bp-0xe]
    // The source start: the memory row of the rectangle's bottom picture row.
    const src_row: i32 = sext(src_height) -% sext(local_10 +% 1);
    const src_start: i32 = src_row *% @as(i32, src_stride) +% sext(local_e);

    var dst_step: i32 = dst_stride;
    var dst_start: i32 = undefined;
    if (dir < 0) {
        dst_start = sext(out.top) *% @as(i32, dst_stride) +% sext(out.left);
    } else {
        const dst_row: i32 = sext(dst_height) -% sext(out.top +% 1);
        dst_start = @as(i32, dst_stride) *% dst_row +% sext(out.left);
        dst_step = -dst_step;
    }
    try blitScaledSpriteTransparent(
        dst_bits,
        @bitCast(dst_start),
        sext(dst_w),
        sext(dst_h),
        sext(clip_w1),
        sext(clip_h1),
        dst_step,
        src_bits,
        @bitCast(src_start),
        sext(src_w),
        sext(src_h),
        -@as(i32, src_stride),
        key,
        fixes,
    );
    return true;
}

// ---- tests: vectors from the original run in tools/oracle (tools/oracle/jardim32.py) ----

const testing = std.testing;
const col_cases = @import("testdata/blit_scaled_column.zig");
const spr_cases = @import("testdata/blit_scaled_sprite_transparent.zig");
const wcol_cases = @import("testdata/dib_blit_scaled_column.zig");
const wspr_cases = @import("testdata/dib_stretch_copy_transparent.zig");

const COL_FILL = 12288;
const SPR_FILL = 8192;

/// The generator's source pattern: byte i = ((i*A + B) >> 13) & mask, B = seed * 0x85EBCA6B.
fn fillSrc(buf: []u8, seed: u32, fill: usize, mask: u8) void {
    @memset(buf, 0);
    const b: u32 = seed *% 0x85EBCA6B;
    for (buf[0..fill], 0..) |*p, i| {
        const v: u32 = (@as(u32, @intCast(i)) *% 0x9E3779B1 +% b) >> 13;
        p.* = @as(u8, @truncate(v)) & mask;
    }
}

const Bufs = struct {
    dst: [0x10000]u8 = undefined,
    src: [0x10000]u8 = undefined,
};

fn crc(dst: []const u8) u32 {
    return std.hash.Crc32.hash(dst);
}

fn hdr(w: i32, h: i32) BitmapInfoHeader {
    return .{ .biWidth = w, .biHeight = h };
}

// @orig 1000:0024 blit_scaled_column oracle=emulated
test "blit_scaled_column against the original" {
    const bufs = try testing.allocator.create(Bufs);
    defer testing.allocator.destroy(bufs);
    for (col_cases.cases, 0..) |c, n| {
        fillSrc(&bufs.src, c.seed, COL_FILL, 0xff);
        @memset(&bufs.dst, 0xee);
        const r = blitScaledColumn(&bufs.dst, c.dst_off, &bufs.src, c.src_off, c.dst_rows, c.src_rows, c.dst_stride, c.src_stride, c.dist, 3, 0x17171717);
        testing.expectEqual(c.fault, std.meta.isError(r)) catch |e| {
            std.debug.print("case {d} (seed {d}) fault\n", .{ n, c.seed });
            return e;
        };
        testing.expectEqual(c.crc, crc(&bufs.dst)) catch |e| {
            std.debug.print("case {d} (seed {d}) crc\n", .{ n, c.seed });
            return e;
        };
    }
}

// @orig 1018:0024 blit_scaled_sprite_transparent oracle=emulated
test "blit_scaled_sprite_transparent against the original (J5 faults included)" {
    const bufs = try testing.allocator.create(Bufs);
    defer testing.allocator.destroy(bufs);
    var faults: usize = 0;
    for (spr_cases.cases, 0..) |c, n| {
        fillSrc(&bufs.src, c.seed, SPR_FILL, 0x0f);
        @memset(&bufs.dst, 0xee);
        const r = blitScaledSpriteTransparent(&bufs.dst, c.dst_off, c.dst_w, c.dst_h, c.clip_w1, c.clip_h1, c.dst_step, &bufs.src, c.src_off, c.src_w, c.src_h, c.src_step, c.key, .{});
        if (c.fault) faults += 1;
        testing.expectEqual(c.fault, std.meta.isError(r)) catch |e| {
            std.debug.print("case {d} (seed {d}) fault\n", .{ n, c.seed });
            return e;
        };
        testing.expectEqual(c.crc, crc(&bufs.dst)) catch |e| {
            std.debug.print("case {d} (seed {d}) crc\n", .{ n, c.seed });
            return e;
        };
    }
    try testing.expect(faults > 0);
}

test "J5: a clip of two rows faults in the original, draws both rows with the fix" {
    const bufs = try testing.allocator.create(Bufs);
    defer testing.allocator.destroy(bufs);
    fillSrc(&bufs.src, 3, SPR_FILL, 0x0f);
    @memset(&bufs.src, 1); // no pixel is the key 10
    // magnify 4x4 -> 8x8, clip 8 x 2 (clip_h1 = 1), destination top-down from row 0
    @memset(&bufs.dst, 0xee);
    const off: u32 = 64 * 8;
    try testing.expectError(error.Fault, blitScaledSpriteTransparent(&bufs.dst, off, 8, 8, 7, 1, -64, &bufs.src, 100, 4, 4, -16, 10, .{}));
    @memset(&bufs.dst, 0xee);
    try blitScaledSpriteTransparent(&bufs.dst, off, 8, 8, 7, 1, -64, &bufs.src, 100, 4, 4, -16, 10, .{ .jardim_sprite_last_rows = true });
    // two rows of the first (clip_w) 7 columns... columns are dst-wise or src-wise; both rows drawn
    var drawn: usize = 0;
    for (bufs.dst) |b| drawn += @intFromBool(b == 1);
    try testing.expect(drawn >= 2);
    try testing.expectEqual(@as(u8, 1), bufs.dst[off]);
    try testing.expectEqual(@as(u8, 1), bufs.dst[off - 64]);
    try testing.expectEqual(@as(u8, 0xee), bufs.dst[off - 128]);
}

// @orig 1068:0000 dib_blit_scaled_column oracle=emulated
test "dib_blit_scaled_column against the original" {
    const bufs = try testing.allocator.create(Bufs);
    defer testing.allocator.destroy(bufs);
    for (wcol_cases.cases, 0..) |c, n| {
        fillSrc(&bufs.src, c.seed, COL_FILL, 0xff);
        @memset(&bufs.dst, 0xee);
        const r = tryDibBlitScaledColumn(&hdr(c.dst_w, c.dst_h), &bufs.dst, c.x, c.y, c.slice_h, &bufs.src, &hdr(c.src_w, c.src_h), c.tex_col, c.tex_row, c.tex_h, c.dist);
        testing.expectEqual(c.fault, std.meta.isError(r)) catch |e| {
            std.debug.print("case {d} (seed {d}) fault\n", .{ n, c.seed });
            return e;
        };
        testing.expectEqual(c.crc, crc(&bufs.dst)) catch |e| {
            std.debug.print("case {d} (seed {d}) crc\n", .{ n, c.seed });
            return e;
        };
    }
}

test "the per-pixel wall column draws the original's rows, each pixel from its own column" {
    const bufs = try testing.allocator.create(Bufs);
    defer testing.allocator.destroy(bufs);
    // A 32-wide texture whose texel is its column + 1; slices shorter and taller than it.
    for (&bufs.src, 0..) |*p, i| p.* = @intCast(i % 32 + 1);
    const src_hdr = hdr(32, 600);
    const dst_hdr = hdr(64, -480);
    for ([_]i16{ 37, 150, 299, 300, 301, 302, 451 }) |h| {
        const top: i16 = 42 + @divTrunc(300 - h, 2);
        @memset(&bufs.dst, 0xee);
        try tryDibBlitScaledColumn(&dst_hdr, &bufs.dst, 8, top, h, &bufs.src, &src_hdr, 8, 0, 300, 70);
        const want = try testing.allocator.dupe(u8, bufs.dst[0 .. 64 * 480]);
        defer testing.allocator.free(want);
        @memset(&bufs.dst, 0xee);
        dibBlitScaledColumnPerPixel(&dst_hdr, &bufs.dst, 8, top, h, &bufs.src, &src_hdr, .{ 8, 9, 10, 11 }, 0, 300, 70);
        try testing.expectEqualSlices(u8, want, bufs.dst[0 .. 64 * 480]);
        @memset(&bufs.dst, 0xee);
        dibBlitScaledColumnPerPixel(&dst_hdr, &bufs.dst, 8, top, h, &bufs.src, &src_hdr, .{ 3, 3, 30, 0 }, 0, 300, 70);
        const row: usize = 192 * 64 + 8;
        try testing.expectEqualSlices(u8, &.{ 4 + 0x17, 4 + 0x17, 31 + 0x17, 1 + 0x17 }, bufs.dst[row..][0..4]);
    }
}

// @orig 1068:1336 dib_stretch_copy_transparent oracle=emulated
test "dib_stretch_copy_transparent against the original" {
    const bufs = try testing.allocator.create(Bufs);
    defer testing.allocator.destroy(bufs);
    for (wspr_cases.cases, 0..) |c, n| {
        fillSrc(&bufs.src, c.seed, SPR_FILL, 0x0f);
        @memset(&bufs.dst, 0xee);
        const r = tryDibStretchCopyTransparent(&hdr(c.dst_w, c.dst_h), &bufs.dst, c.dst_x, c.dst_y, c.dw, c.dh, &bufs.src, &hdr(c.src_w, c.src_h), c.src_x, c.src_y, c.sw, c.sh, c.key, .{});
        testing.expectEqual(c.fault, std.meta.isError(r)) catch |e| {
            std.debug.print("case {d} (seed {d}) fault\n", .{ n, c.seed });
            return e;
        };
        if (r) |drew| {
            try testing.expectEqual(c.drew, drew);
        } else |_| {}
        testing.expectEqual(c.crc, crc(&bufs.dst)) catch |e| {
            std.debug.print("case {d} (seed {d}) crc\n", .{ n, c.seed });
            return e;
        };
    }
}
