//! Decoder for the game's AVI files (platform code, replaces MCI avivideo).
//!
//! Every shipped AVI is RIFF `AVI ` with one video stream of fourcc `AFLC`
//! (Autodesk FLIC): each video chunk (`00dc`) in `movi` is one FLC frame
//! (magic 0xF1FA) whose subchunks patch the previous frame. The video `strf`
//! is a BITMAPINFOHEADER followed by a 256-entry RGBQUAD palette (not the
//! 128-byte FLC file header). The optional audio stream (`01wb`) is PCM.
//! `movi` wraps its chunks in `LIST rec ` interleave groups with `JUNK`
//! padding; `idx1` is ignored. A video chunk is 2 bytes longer than the FLC
//! frame it holds (trailing garbage), so the frame's own size is used.
//!
//! Malformed data returns an error; nothing here panics or reads out of
//! bounds. Some shipped files are damaged: a recurring ~68-byte block
//! (`... c0 c0 df df 00 40 33 2d 11 83 00 04 f0 f1 ...` then spaces)
//! overwrites frame data (2ACOPSEX, CARNIBOY, FASE2/2FCOPMAU/2ACOPMAU,
//! FASE2/2FCOPMU/2ACOPMU, PAN/AVI/2APREBO2, PAN/AVI/2APREMA2), so
//! `decodeNext` must be resumable after `error.BadFrame`.

const std = @import("std");
const Allocator = std.mem.Allocator;
/// Same layout as `platform.zig`'s `Rgb` (not imported: that file reaches
/// outside `src/platform/`, which breaks a standalone `zig test` of this
/// file); reinterpret a palette with
/// `@as(*const [256]platform.Rgb, @ptrCast(&d.palette))` (`@bitCast` rejects it).
pub const Rgb = extern struct { r: u8 = 0, g: u8 = 0, b: u8 = 0 };

pub const Error = error{
    /// Not a RIFF `AVI ` file, or a chunk runs past its parent.
    BadAvi,
    /// The file has no video stream.
    NoVideo,
    /// The video stream is not `AFLC` (e.g. SAMPLE.AVI is Cinepak).
    UnsupportedVideo,
    /// The audio stream is not PCM.
    UnsupportedAudio,
    /// An FLC frame or subchunk is truncated or inconsistent.
    BadFrame,
} || Allocator.Error;

pub const Audio = struct { rate: u32, bits: u16, channels: u16 };

pub const Avi = struct {
    width: u16,
    height: u16,
    /// avih dwTotalFrames.
    frame_count: u32,
    /// avih dwMicroSecPerFrame.
    usec_per_frame: u32,
    audio: ?Audio,
    /// The palette stored in the video `strf` (RGBQUAD order converted).
    palette: ?[256]Rgb,
    /// Borrowed file contents; the chunk slices below point into it.
    bytes: []const u8,
    /// Video chunk payloads in stream order (one FLC frame each).
    video_chunks: []const []const u8,
    /// Audio chunk payloads in stream order (raw PCM).
    audio_chunks: []const []const u8,

    /// Index `bytes` (which must outlive the returned `Avi`).
    pub fn parse(gpa: Allocator, bytes: []const u8) Error!Avi {
        if (bytes.len < 12 or !std.mem.eql(u8, bytes[0..4], "RIFF") or !std.mem.eql(u8, bytes[8..12], "AVI "))
            return error.BadAvi;
        const riff_size = rd32(bytes, 4);
        if (riff_size < 4 or riff_size > bytes.len - 8) return error.BadAvi;
        const body = bytes[12 .. 8 + riff_size];

        var p: Parser = .{};
        var it: ChunkIter = .{ .data = body };
        var movi: ?[]const u8 = null;
        while (try it.next()) |c| {
            if (c.isList("hdrl")) {
                try p.headerList(c.data[4..]);
            } else if (c.isList("movi")) {
                movi = c.data[4..];
            }
        }
        if (!p.have_avih) return error.BadAvi;
        const video_stream = p.video_stream orelse return error.NoVideo;

        var video: std.ArrayList([]const u8) = .empty;
        defer video.deinit(gpa);
        var audio: std.ArrayList([]const u8) = .empty;
        defer audio.deinit(gpa);
        if (movi) |m| try collectMovi(gpa, m, video_stream, p.audio_stream, &video, &audio, 0);

        const video_chunks = try video.toOwnedSlice(gpa);
        errdefer gpa.free(video_chunks);
        const audio_chunks = try audio.toOwnedSlice(gpa);
        return .{
            .width = p.width,
            .height = p.height,
            .frame_count = p.frame_count,
            .usec_per_frame = p.usec_per_frame,
            .audio = p.audio,
            .palette = p.palette,
            .bytes = bytes,
            .video_chunks = video_chunks,
            .audio_chunks = audio_chunks,
        };
    }

    pub fn deinit(a: *Avi, gpa: Allocator) void {
        gpa.free(a.video_chunks);
        gpa.free(a.audio_chunks);
        a.* = undefined;
    }

    /// Playing time: `usec_per_frame * frame_count / 1000`.
    pub fn durationMs(a: *const Avi) u32 {
        const us = @as(u64, a.usec_per_frame) * a.frame_count;
        return @truncate(us / 1000);
    }

    /// All audio chunks concatenated; caller frees. Empty without audio.
    pub fn audioPcm(a: *const Avi, gpa: Allocator) Allocator.Error![]u8 {
        var total: usize = 0;
        for (a.audio_chunks) |c| total += c.len;
        const out = try gpa.alloc(u8, total);
        var i: usize = 0;
        for (a.audio_chunks) |c| {
            @memcpy(out[i..][0..c.len], c);
            i += c.len;
        }
        return out;
    }
};

pub const Decoder = struct {
    avi: *const Avi,
    /// `width * height` palette indices, row-major, top-down.
    pixels: []u8,
    palette: [256]Rgb,
    /// Index of the next video chunk to decode.
    next_frame: u32,

    /// Starts black with the `strf` palette (if any). `avi` must outlive it.
    pub fn init(gpa: Allocator, avi: *const Avi) Error!Decoder {
        if (avi.width == 0 or avi.height == 0) return error.BadAvi;
        const pixels = try gpa.alloc(u8, @as(usize, avi.width) * avi.height);
        @memset(pixels, 0);
        return .{
            .avi = avi,
            .pixels = pixels,
            .palette = avi.palette orelse @splat(.{}),
            .next_frame = 0,
        };
    }

    pub fn deinit(d: *Decoder, gpa: Allocator) void {
        gpa.free(d.pixels);
        d.* = undefined;
    }

    /// Decode the next frame into pixels/palette (deltas apply on top of the
    /// previous frame). false after the last frame. `error.BadFrame` leaves
    /// the frame partly applied and still advances `next_frame`, so the
    /// caller can keep playing (the damaged shipped files need that).
    pub fn decodeNext(d: *Decoder) Error!bool {
        const chunks = d.avi.video_chunks;
        if (d.next_frame >= chunks.len) return false;
        const chunk = chunks[d.next_frame];
        d.next_frame += 1;
        if (chunk.len == 0) return true; // dropped frame: repeat the previous one
        if (chunk.len < 16) return error.BadFrame;
        const size = rd32(chunk, 0);
        if (size < 16 or size > chunk.len or rd16(chunk, 4) != 0xF1FA) return error.BadFrame;
        const count = rd16(chunk, 6);
        var r: Reader = .{ .b = chunk[16..size] };
        for (0..count) |_| {
            const sub_size = try r.int(u32);
            const kind = try r.int(u16);
            if (sub_size < 6) return error.BadFrame;
            const data = try r.take(sub_size - 6);
            try d.subchunk(kind, data);
        }
        return true;
    }

    fn subchunk(d: *Decoder, kind: u16, data: []const u8) Error!void {
        switch (kind) {
            4 => try d.color(data, false), // COLOR_256
            11 => try d.color(data, true), // COLOR_64
            7 => try d.deltaFlc(data), // DELTA_FLC (SS2)
            12 => try d.deltaFli(data), // DELTA_FLI (LC)
            13 => @memset(d.pixels, 0), // BLACK
            15 => try d.byteRun(data), // BYTE_RUN
            16 => { // FLI_COPY
                if (data.len < d.pixels.len) return error.BadFrame;
                @memcpy(d.pixels, data[0..d.pixels.len]);
            },
            else => {}, // PSTAMP (18) and anything unknown: skip
        }
    }

    /// COLOR_64 components (0–63) are scaled to 0–255 as `v << 2 | v >> 4`.
    fn color(d: *Decoder, data: []const u8, six_bit: bool) Error!void {
        var r: Reader = .{ .b = data };
        const packets = try r.int(u16);
        var index: usize = 0;
        for (0..packets) |_| {
            index += try r.byte();
            const raw = try r.byte();
            const n: usize = if (raw == 0) 256 else raw;
            if (index + n > 256) return error.BadFrame;
            const rgb = try r.take(n * 3);
            for (0..n) |j| {
                var c = rgb[j * 3 ..][0..3].*;
                if (six_bit) {
                    for (&c) |*v| v.* = (v.* << 2) | (v.* >> 4);
                }
                d.palette[index + j] = .{ .r = c[0], .g = c[1], .b = c[2] };
            }
            index += n;
        }
    }

    fn byteRun(d: *Decoder, data: []const u8) Error!void {
        const w: usize = d.avi.width;
        var r: Reader = .{ .b = data };
        for (0..d.avi.height) |y| {
            const row = d.pixels[y * w ..][0..w];
            _ = try r.byte(); // packet count (obsolete; decode by width)
            var x: usize = 0;
            while (x < w) {
                const c: i8 = @bitCast(try r.byte());
                if (c >= 0) {
                    const n: usize = @intCast(c);
                    if (x + n > w) return error.BadFrame;
                    @memset(row[x..][0..n], try r.byte());
                    x += n;
                } else {
                    const n: usize = @abs(c);
                    if (x + n > w) return error.BadFrame;
                    @memcpy(row[x..][0..n], try r.take(n));
                    x += n;
                }
            }
        }
    }

    fn deltaFlc(d: *Decoder, data: []const u8) Error!void {
        const w: usize = d.avi.width;
        const h: usize = d.avi.height;
        var r: Reader = .{ .b = data };
        var lines = try r.int(u16);
        var y: usize = 0;
        while (lines > 0) {
            const op = try r.int(u16);
            switch (op & 0xC000) {
                0xC000 => { // skip -op lines
                    y += @abs(@as(i16, @bitCast(op)));
                    continue;
                },
                0x8000 => { // last pixel of the line; packet count follows
                    if (y >= h) return error.BadFrame;
                    d.pixels[y * w + w - 1] = @truncate(op);
                    continue;
                },
                0x4000 => return error.BadFrame,
                else => {},
            }
            if (y >= h) return error.BadFrame;
            const row = d.pixels[y * w ..][0..w];
            var x: usize = 0;
            for (0..op) |_| {
                x += try r.byte();
                const c: i8 = @bitCast(try r.byte());
                const n: usize = 2 * @as(usize, @abs(c));
                if (x + n > w) return error.BadFrame;
                if (c >= 0) {
                    @memcpy(row[x..][0..n], try r.take(n));
                } else {
                    const pair = try r.take(2);
                    var i: usize = 0;
                    while (i < n) : (i += 2) @memcpy(row[x + i ..][0..2], pair);
                }
                x += n;
            }
            y += 1;
            lines -= 1;
        }
    }

    fn deltaFli(d: *Decoder, data: []const u8) Error!void {
        const w: usize = d.avi.width;
        var r: Reader = .{ .b = data };
        const first: usize = try r.int(u16);
        const lines: usize = try r.int(u16);
        if (first + lines > d.avi.height) return error.BadFrame;
        for (first..first + lines) |y| {
            const row = d.pixels[y * w ..][0..w];
            const packets = try r.byte();
            var x: usize = 0;
            for (0..packets) |_| {
                x += try r.byte();
                const c: i8 = @bitCast(try r.byte());
                const n: usize = @abs(c);
                if (x + n > w) return error.BadFrame;
                if (c >= 0) {
                    @memcpy(row[x..][0..n], try r.take(n));
                } else {
                    @memset(row[x..][0..n], try r.byte());
                }
                x += n;
            }
        }
    }
};

/// Bounds-checked little-endian cursor over a FLC subchunk.
const Reader = struct {
    b: []const u8,
    i: usize = 0,

    fn take(r: *Reader, n: usize) Error![]const u8 {
        if (n > r.b.len - r.i) return error.BadFrame;
        defer r.i += n;
        return r.b[r.i..][0..n];
    }

    fn byte(r: *Reader) Error!u8 {
        return (try r.take(1))[0];
    }

    fn int(r: *Reader, comptime T: type) Error!T {
        const n = @divExact(@typeInfo(T).int.bits, 8);
        return std.mem.readInt(T, (try r.take(n))[0..n], .little);
    }
};

fn rd16(b: []const u8, off: usize) u16 {
    return std.mem.readInt(u16, b[off..][0..2], .little);
}

fn rd32(b: []const u8, off: usize) u32 {
    return std.mem.readInt(u32, b[off..][0..4], .little);
}

const Chunk = struct {
    id: *const [4]u8,
    data: []const u8,

    fn isList(c: Chunk, list_type: *const [4]u8) bool {
        return std.mem.eql(u8, c.id, "LIST") and c.data.len >= 4 and std.mem.eql(u8, c.data[0..4], list_type);
    }
};

/// RIFF chunks inside one parent; payloads are word-padded.
const ChunkIter = struct {
    data: []const u8,
    i: usize = 0,

    fn next(it: *ChunkIter) Error!?Chunk {
        if (it.data.len - it.i < 8) return null; // end (or a stray tail shorter than a header)
        const id = it.data[it.i..][0..4];
        const size = rd32(it.data, it.i + 4);
        const start = it.i + 8;
        if (size > it.data.len - start) return error.BadAvi;
        // The pad byte of the last chunk may be missing.
        it.i = @min(start + size + (size & 1), it.data.len);
        return .{ .id = id, .data = it.data[start..][0..size] };
    }
};

const Parser = struct {
    have_avih: bool = false,
    width: u16 = 0,
    height: u16 = 0,
    frame_count: u32 = 0,
    usec_per_frame: u32 = 0,
    audio: ?Audio = null,
    palette: ?[256]Rgb = null,
    video_stream: ?u8 = null,
    audio_stream: ?u8 = null,

    fn headerList(p: *Parser, data: []const u8) Error!void {
        var it: ChunkIter = .{ .data = data };
        var stream: usize = 0;
        while (try it.next()) |c| {
            if (std.mem.eql(u8, c.id, "avih")) {
                if (c.data.len < 40) return error.BadAvi;
                p.usec_per_frame = rd32(c.data, 0);
                p.frame_count = rd32(c.data, 16);
                const w = rd32(c.data, 32);
                const h = rd32(c.data, 36);
                if (w == 0 or h == 0 or w > 0xffff or h > 0xffff) return error.BadAvi;
                p.width = @intCast(w);
                p.height = @intCast(h);
                p.have_avih = true;
            } else if (c.isList("strl")) {
                if (stream < 100) try p.streamList(c.data[4..], @intCast(stream));
                stream += 1;
            }
        }
    }

    fn streamList(p: *Parser, data: []const u8, stream: u8) Error!void {
        var it: ChunkIter = .{ .data = data };
        var kind: ?*const [4]u8 = null;
        while (try it.next()) |c| {
            if (std.mem.eql(u8, c.id, "strh")) {
                if (c.data.len < 4) return error.BadAvi;
                kind = c.data[0..4];
            } else if (std.mem.eql(u8, c.id, "strf")) {
                const k = kind orelse return error.BadAvi;
                if (std.mem.eql(u8, k, "vids") and p.video_stream == null) {
                    try p.videoFormat(c.data);
                    p.video_stream = stream;
                } else if (std.mem.eql(u8, k, "auds") and p.audio_stream == null) {
                    if (c.data.len < 16) return error.BadAvi;
                    if (rd16(c.data, 0) != 1) return error.UnsupportedAudio; // WAVE_FORMAT_PCM
                    p.audio = .{ .channels = rd16(c.data, 2), .rate = rd32(c.data, 4), .bits = rd16(c.data, 14) };
                    p.audio_stream = stream;
                }
            }
        }
    }

    /// BITMAPINFOHEADER + RGBQUAD colour table.
    fn videoFormat(p: *Parser, data: []const u8) Error!void {
        if (data.len < 40) return error.BadAvi;
        if (!std.mem.eql(u8, data[16..20], "AFLC")) return error.UnsupportedVideo;
        const header_size = rd32(data, 0);
        const used = rd32(data, 32);
        const colors: usize = if (used == 0 or used > 256) 256 else used;
        if (header_size < 40 or header_size > data.len or data.len - header_size < colors * 4) return;
        var pal: [256]Rgb = @splat(.{});
        const quads = data[header_size..];
        for (pal[0..colors], 0..) |*c, i| c.* = .{ .r = quads[i * 4 + 2], .g = quads[i * 4 + 1], .b = quads[i * 4] };
        p.palette = pal;
    }
};

/// Collect `NNdc`/`NNdb` (video) and `NNwb` (audio) chunks, descending into
/// `LIST rec ` groups.
fn collectMovi(
    gpa: Allocator,
    data: []const u8,
    video_stream: u8,
    audio_stream: ?u8,
    video: *std.ArrayList([]const u8),
    audio: *std.ArrayList([]const u8),
    depth: u8,
) Error!void {
    if (depth > 4) return error.BadAvi;
    var it: ChunkIter = .{ .data = data };
    while (try it.next()) |c| {
        if (std.mem.eql(u8, c.id, "LIST")) {
            if (c.data.len < 4) return error.BadAvi;
            try collectMovi(gpa, c.data[4..], video_stream, audio_stream, video, audio, depth + 1);
            continue;
        }
        const stream = streamNumber(c.id) orelse continue;
        const tag = c.id[2..4];
        if (stream == video_stream and (std.mem.eql(u8, tag, "dc") or std.mem.eql(u8, tag, "db"))) {
            try video.append(gpa, c.data);
        } else if (audio_stream != null and stream == audio_stream.? and std.mem.eql(u8, tag, "wb")) {
            try audio.append(gpa, c.data);
        }
    }
}

fn streamNumber(id: *const [4]u8) ?u8 {
    if (!std.ascii.isDigit(id[0]) or !std.ascii.isDigit(id[1])) return null;
    return (id[0] - '0') * 10 + (id[1] - '0');
}

// Tests. Expected values come from the files themselves (avih/strf fields,
// COLOR_256 bytes at file offset 0x7039 of 1AMAO.AVI) or from an independent
// Python reference decoder (CRC-32 of the last frame's pixels and its 768
// palette bytes).

const testing = std.testing;

fn readAsset(path: []const u8) ![]u8 {
    return std.Io.Dir.cwd().readFileAlloc(testing.io, path, testing.allocator, .limited(64 << 20));
}

const Expected = struct { frames: u32, pixels_crc: u32, palette_crc: u32 };

fn decodeAll(path: []const u8, want: Expected) !void {
    const gpa = testing.allocator;
    const bytes = try readAsset(path);
    defer gpa.free(bytes);
    var avi = try Avi.parse(gpa, bytes);
    defer avi.deinit(gpa);
    try testing.expectEqual(want.frames, avi.frame_count);
    var d = try Decoder.init(gpa, &avi);
    defer d.deinit(gpa);
    var n: u32 = 0;
    while (try d.decodeNext()) n += 1;
    try testing.expectEqual(want.frames, n);
    try testing.expectEqual(want.pixels_crc, std.hash.Crc32.hash(d.pixels));
    try testing.expectEqual(want.palette_crc, std.hash.Crc32.hash(std.mem.sliceAsBytes(&d.palette)));
}

test "parse 1AMAO.AVI headers" {
    const gpa = testing.allocator;
    const bytes = try readAsset("assets/1AMAO.AVI");
    defer gpa.free(bytes);
    var avi = try Avi.parse(gpa, bytes);
    defer avi.deinit(gpa);
    try testing.expectEqual(29, avi.frame_count);
    try testing.expectEqual(357000, avi.usec_per_frame);
    try testing.expectEqual(10353, avi.durationMs());
    try testing.expectEqual(640, avi.width);
    try testing.expectEqual(480, avi.height);
    try testing.expectEqual(29, avi.video_chunks.len);
    const audio = avi.audio.?;
    try testing.expectEqual(22050, audio.rate);
    try testing.expectEqual(8, audio.bits);
    try testing.expectEqual(1, audio.channels);
    const pcm = try avi.audioPcm(gpa);
    defer gpa.free(pcm);
    try testing.expectEqual(222720, pcm.len);
    try testing.expectEqual(0xcacf1267, std.hash.Crc32.hash(pcm));
}

test "first frame palette matches COLOR_256 bytes" {
    const gpa = testing.allocator;
    const bytes = try readAsset("assets/1AMAO.AVI");
    defer gpa.free(bytes);
    var avi = try Avi.parse(gpa, bytes);
    defer avi.deinit(gpa);
    var d = try Decoder.init(gpa, &avi);
    defer d.deinit(gpa);
    d.palette = @splat(.{}); // don't let the strf palette mask the chunk
    try testing.expect(try d.decodeNext());
    try testing.expectEqual(Rgb{ .r = 0x80, .g = 0x00, .b = 0x00 }, d.palette[1]);
    try testing.expectEqual(Rgb{ .r = 0x05, .g = 0x64, .b = 0x64 }, d.palette[10]);
    try testing.expectEqual(Rgb{ .r = 0x18, .g = 0x22, .b = 0x38 }, d.palette[100]);
    try testing.expectEqual(Rgb{ .r = 0xff, .g = 0xff, .b = 0xff }, d.palette[255]);
    try testing.expectEqualSlices(Rgb, &avi.palette.?, &d.palette);
}

test "decode every frame of 1AMAO.AVI" {
    try decodeAll("assets/1AMAO.AVI", .{ .frames = 29, .pixels_crc = 0x5180ce60, .palette_crc = 0xeaaa19c1 });
}

test "decode every frame of HD/BARACUT1.AVI" {
    try decodeAll("assets/HD/BARACUT1.AVI", .{ .frames = 396, .pixels_crc = 0xb3aa3fa4, .palette_crc = 0xb31da201 });
}

test "Cinepak SAMPLE.AVI is rejected" {
    const gpa = testing.allocator;
    const bytes = try readAsset("assets/SAMPLE.AVI");
    defer gpa.free(bytes);
    try testing.expectError(error.UnsupportedVideo, Avi.parse(gpa, bytes));
}

test "decoding resumes after the damaged frames of 2ACOPSEX.AVI" {
    // Frames 6, 7, 10 and 14 contain the damage block (located by its byte
    // signature in the file).
    const gpa = testing.allocator;
    const bytes = try readAsset("assets/2ACOPSEX.AVI");
    defer gpa.free(bytes);
    var avi = try Avi.parse(gpa, bytes);
    defer avi.deinit(gpa);
    var d = try Decoder.init(gpa, &avi);
    defer d.deinit(gpa);
    var bad: [4]u32 = undefined;
    var n_bad: usize = 0;
    var n: u32 = 0;
    while (true) : (n += 1) {
        const more = d.decodeNext() catch |e| {
            try testing.expectEqual(error.BadFrame, e);
            if (n_bad == bad.len) return error.TestUnexpectedResult;
            bad[n_bad] = n;
            n_bad += 1;
            continue;
        };
        if (!more) break;
    }
    try testing.expectEqual(18, n);
    try testing.expectEqualSlices(u32, &.{ 6, 7, 10, 14 }, bad[0..n_bad]);
}

test "truncated and corrupted data errors instead of panicking" {
    const gpa = testing.allocator;
    const bytes = try readAsset("assets/1AMAO.AVI");
    defer gpa.free(bytes);
    for ([_]usize{ 0, 11, 100, 0x4e0, 0x6810, 0x20000, bytes.len - 1 }) |len| {
        if (Avi.parse(gpa, bytes[0..len])) |avi_const| {
            var avi = avi_const;
            avi.deinit(gpa);
        } else |_| {}
    }
    const copy = try gpa.dupe(u8, bytes);
    defer gpa.free(copy);
    var prng: std.Random.DefaultPrng = .init(1995);
    const rand = prng.random();
    for (0..200) |_| {
        @memcpy(copy, bytes);
        // Corrupt a few bytes inside the frame data (after the headers).
        for (0..8) |_| copy[rand.intRangeLessThan(usize, 0x6800, 0x40000)] = rand.int(u8);
        var avi = Avi.parse(gpa, copy) catch continue;
        defer avi.deinit(gpa);
        var d = try Decoder.init(gpa, &avi);
        defer d.deinit(gpa);
        while (d.decodeNext() catch false) {}
    }
}
