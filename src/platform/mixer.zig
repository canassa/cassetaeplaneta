//! The sound mixer behind WaveMix, the MCI waveaudio device, the AVI
//! soundtracks and the MIDI sequencer: voices over PCM the `Sim` owns,
//! mixed to 44.1 kHz stereo s16 for the SDL audio stream. Pure state; the
//! headless backend never renders it (timing comes from durations, not
//! from the mix, so both backends post the same notifications).

const std = @import("std");
const midi = @import("midi.zig");

pub const out_rate = 44_100;

/// PCM as stored in a WAVE `data` chunk.
pub const Pcm = struct {
    data: []const u8,
    rate: u32,
    /// 8 (unsigned) or 16 (signed little-endian).
    bits: u16,
    channels: u16,

    pub fn frames(p: Pcm) usize {
        const bpf = @as(usize, p.bits / 8) * p.channels;
        return if (bpf == 0) 0 else p.data.len / bpf;
    }

    fn sample(p: Pcm, frame: usize, ch: u16) i32 {
        const c = @min(ch, p.channels - 1);
        if (p.bits == 8) {
            return (@as(i32, p.data[frame * p.channels + c]) - 128) << 8;
        }
        const i = (frame * p.channels + c) * 2;
        return std.mem.readInt(i16, p.data[i..][0..2], .little);
    }
};

pub const Voice = struct {
    pcm: ?Pcm = null,
    /// Position in source frames, 32.32 fixed point.
    pos: u64 = 0,
    /// Extra plays after this one; 0xFFFF = forever.
    loops: u16 = 0,
    paused: bool = false,

    pub fn start(v: *Voice, pcm: Pcm, loops: u16) void {
        v.* = .{ .pcm = pcm, .loops = loops };
    }

    pub fn stop(v: *Voice) void {
        v.* = .{};
    }

    fn mixInto(v: *Voice, out: []i32) void {
        const pcm = v.pcm orelse return;
        if (v.paused) return;
        const n = pcm.frames();
        if (n == 0 or pcm.channels == 0) return v.stop();
        const step: u64 = (@as(u64, pcm.rate) << 32) / out_rate;
        var i: usize = 0;
        while (i + 1 < out.len) : (i += 2) {
            var f: usize = @intCast(v.pos >> 32);
            if (f >= n) {
                if (v.loops == 0) return v.stop();
                if (v.loops != 0xffff) v.loops -= 1;
                v.pos -= @as(u64, n) << 32;
                f = @intCast(v.pos >> 32);
            }
            out[i] += pcm.sample(f, 0);
            out[i + 1] += pcm.sample(f, 1);
            v.pos += step;
        }
    }
};

/// WaveMix sessions mixed at once: one per program (`platform.max_tasks`).
pub const sessions = 4;

pub const Mixer = struct {
    /// The eight WaveMix channels of each program's session.
    channels: [sessions][8]Voice = @splat(@splat(.{})),
    /// MCI waveaudio devices (one alias at a time is enough for the game).
    mci_wave: Voice = .{},
    /// The playing AVI's soundtrack.
    video: Voice = .{},
    /// The MIDI synthesizer (owned by the backend; null = no music).
    synth: ?*midi.Synth = null,
    /// WaveMixActivate(false) silences the session's WaveMix channels.
    active: [sessions]bool = @splat(true),

    /// Mixes `out.len / 2` stereo frames. No allocation.
    pub fn render(m: *Mixer, out: []i16) void {
        var acc: [1024]i32 = undefined;
        var music: [1024]i16 = undefined;
        var done: usize = 0;
        while (done < out.len) {
            const n = @min(acc.len, out.len - done) & ~@as(usize, 1);
            if (n == 0) break;
            const a = acc[0..n];
            @memset(a, 0);
            for (&m.channels, m.active) |*bank, on| {
                if (on) for (bank) |*v| v.mixInto(a);
            }
            m.mci_wave.mixInto(a);
            m.video.mixInto(a);
            if (m.synth) |s| {
                s.render(music[0..n]);
                for (a, music[0..n]) |*x, y| x.* += y;
            }
            for (out[done..][0..n], a) |*o, x| o.* = @intCast(std.math.clamp(x, -32768, 32767));
            done += n;
        }
        @memset(out[done..], 0);
    }
};

test "a mono 8-bit voice resamples to stereo and ends" {
    var data: [22]u8 = undefined; // 22 frames at 22050 Hz
    for (&data, 0..) |*d, i| d.* = if (i % 2 == 0) 128 + 64 else 128 - 64;
    var m: Mixer = .{};
    m.channels[0][0].start(.{ .data = &data, .rate = 22050, .bits = 8, .channels = 1 }, 0);
    var out: [200]i16 = undefined;
    m.render(&out);
    try std.testing.expectEqual(@as(i16, 64 << 8), out[0]);
    try std.testing.expectEqual(out[0], out[1]); // mono → both sides
    try std.testing.expectEqual(@as(i16, 64 << 8), out[2]); // 2:1 upsampling
    try std.testing.expectEqual(@as(i16, -64 << 8), out[4]);
    try std.testing.expect(m.channels[0][0].pcm == null); // 44 out frames < 100
    try std.testing.expectEqual(@as(i16, 0), out[199]);
}
