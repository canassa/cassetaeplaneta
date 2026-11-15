//! Decodes an AVI of the disc (`AFLC` video) with the port's decoder
//! (src/platform/flic.zig) into raw RGB24 frames for ffmpeg:
//!
//!     avidump IN.AVI OUT.rgb
//!
//! OUT gets every video chunk as one width*height*3 frame, top-down, in
//! stream order; a damaged frame (`error.BadFrame`, BUGS.md B42's files) is
//! written as far as it decoded, as the game shows it. stdout gets
//! `width height usec_per_frame frames`. Built by tools/explorer/build.py.
const std = @import("std");
const flic = @import("flic");

pub fn main(init: std.process.Init) !void {
    const gpa = init.gpa;
    const io = init.io;
    var it = init.minimal.args.iterate();
    _ = it.next();
    const in_path = it.next() orelse return error.MissingArgument;
    const out_path = it.next() orelse return error.MissingArgument;

    const bytes = try std.Io.Dir.cwd().readFileAlloc(io, in_path, gpa, .limited(64 << 20));
    defer gpa.free(bytes);
    var avi = try flic.Avi.parse(gpa, bytes);
    defer avi.deinit(gpa);
    var d = try flic.Decoder.init(gpa, &avi);
    defer d.deinit(gpa);

    const frame_len = @as(usize, avi.width) * avi.height * 3;
    const out = try gpa.alloc(u8, frame_len * avi.video_chunks.len);
    defer gpa.free(out);
    var n: usize = 0;
    while (true) {
        const more = d.decodeNext() catch true; // damaged frames: keep going, as the game does
        if (!more) break;
        const frame = out[n * frame_len ..][0..frame_len];
        for (d.pixels, 0..) |p, i| {
            const c = d.palette[p];
            frame[i * 3 ..][0..3].* = .{ c.r, c.g, c.b };
        }
        n += 1;
    }
    try std.Io.Dir.cwd().writeFile(io, .{ .sub_path = out_path, .data = out[0 .. n * frame_len] });
    var buf: [64]u8 = undefined;
    const line = try std.fmt.bufPrint(&buf, "{d} {d} {d} {d}\n", .{ avi.width, avi.height, avi.usec_per_frame, n });
    try std.Io.File.stdout().writeStreamingAll(io, line);
}
