//! MIDI music: the platform's replacement for the MCI `sequencer` device the
//! original opens on `VELHA.MID` and friends. Standard MIDI Files are
//! rendered with TinySoundFont/TinyMidiLoader (vendor/tinysoundfont, MIT)
//! against a General MIDI SoundFont (the dev shell exports GeneralUser GS as
//! `NOITE_SOUNDFONT`).
//!
//! `songLengthMs` is pure Zig (no SoundFont): what MCI reports as the
//! sequencer's length in milliseconds. `Synth` is the player. TSF/TML
//! allocate through libc `malloc` (in `init` and `load` only); `render`
//! never allocates.

const std = @import("std");

const Tsf = opaque {};
const TmlMessage = opaque {};

// vendor/tinysoundfont/tsf_impl.c (helpers) and tsf.h / tml.h.
extern "c" fn noite_tsf_open(buffer: *const anyopaque, size: c_int, sample_rate: c_int) ?*Tsf;
extern "c" fn noite_tsf_rewind(f: *Tsf) void;
extern "c" fn noite_tsf_silence(f: *Tsf) void;
extern "c" fn noite_midi_dispatch(f: *Tsf, cur: ?*TmlMessage, ms: c_uint) ?*TmlMessage;
extern "c" fn tsf_close(f: *Tsf) void;
extern "c" fn tsf_active_voice_count(f: *Tsf) c_int;
extern "c" fn tsf_render_short(f: *Tsf, buffer: [*]i16, samples: c_int, flag_mixing: c_int) void;
extern "c" fn tml_load_memory(buffer: *const anyopaque, size: c_int) ?*TmlMessage;
extern "c" fn tml_free(f: *TmlMessage) void;

pub const Error = error{InvalidMidi};

/// Frames rendered between two event dispatches (1.45 ms at 44.1 kHz).
const block_frames = 64;

/// The SMF inside `bytes`: the file itself, or the `MThd` chunk onwards of
/// a RIFF RMID wrapper.
fn smfBytes(bytes: []const u8) Error![]const u8 {
    if (bytes.len >= 4 and std.mem.eql(u8, bytes[0..4], "RIFF")) {
        const at = std.mem.indexOf(u8, bytes, "MThd") orelse return error.InvalidMidi;
        return bytes[at..];
    }
    return bytes;
}

const Tempo = struct { tick: u64, us_per_quarter: u32 };

const Cursor = struct {
    bytes: []const u8,
    pos: usize = 0,

    fn byte(c: *Cursor) Error!u8 {
        if (c.pos >= c.bytes.len) return error.InvalidMidi;
        defer c.pos += 1;
        return c.bytes[c.pos];
    }

    /// A variable-length quantity (at most 4 bytes, 28 bits).
    fn vlq(c: *Cursor) Error!u32 {
        var v: u32 = 0;
        for (0..4) |_| {
            const b = try c.byte();
            v = (v << 7) | (b & 0x7f);
            if (b & 0x80 == 0) return v;
        }
        return error.InvalidMidi;
    }

    fn skip(c: *Cursor, n: usize) Error!void {
        if (n > c.bytes.len - c.pos) return error.InvalidMidi;
        c.pos += n;
    }
};

/// Length of a Standard MIDI File in ms (tempo map aware), computed without a SoundFont.
/// The song ends at the last track's End Of Track (or the end of its chunk);
/// tempo changes from every track apply to the whole song. Rounded down.
pub fn songLengthMs(gpa: std.mem.Allocator, midi_bytes: []const u8) !u32 {
    const smf = try smfBytes(midi_bytes);
    if (smf.len < 14 or !std.mem.eql(u8, smf[0..4], "MThd")) return error.InvalidMidi;
    const header_len = std.mem.readInt(u32, smf[4..8], .big);
    if (header_len < 6 or header_len > smf.len - 8) return error.InvalidMidi;
    const track_count = std.mem.readInt(u16, smf[10..12], .big);
    const division = std.mem.readInt(u16, smf[12..14], .big);
    if (division == 0) return error.InvalidMidi;

    var tempos: std.ArrayList(Tempo) = .empty;
    defer tempos.deinit(gpa);
    var end_tick: u64 = 0;

    var pos: usize = 8 + header_len;
    var tracks_seen: u32 = 0;
    while (tracks_seen < track_count and smf.len - pos >= 8) {
        const id = smf[pos..][0..4];
        const len = std.mem.readInt(u32, smf[pos + 4 ..][0..4], .big);
        const body_start = pos + 8;
        // A truncated last chunk is read up to the end of the file.
        const body_end = body_start + @min(len, smf.len - body_start);
        pos = body_end;
        if (!std.mem.eql(u8, id, "MTrk")) continue;
        tracks_seen += 1;

        var c: Cursor = .{ .bytes = smf[body_start..body_end] };
        var tick: u64 = 0;
        var running: u8 = 0;
        while (c.pos < c.bytes.len) {
            tick += try c.vlq();
            var status = try c.byte();
            if (status == 0xff) {
                const kind = try c.byte();
                const n = try c.vlq();
                if (kind == 0x51 and n == 3) {
                    const d = c.bytes[c.pos..];
                    if (d.len < 3) return error.InvalidMidi;
                    try tempos.append(gpa, .{
                        .tick = tick,
                        .us_per_quarter = @as(u32, d[0]) << 16 | @as(u32, d[1]) << 8 | d[2],
                    });
                }
                try c.skip(n);
                if (kind == 0x2f) break;
                continue;
            }
            if (status == 0xf0 or status == 0xf7) {
                try c.skip(try c.vlq());
                continue;
            }
            if (status & 0x80 != 0) {
                if (status >= 0xf0) return error.InvalidMidi;
                running = status;
            } else {
                if (running == 0) return error.InvalidMidi;
                c.pos -= 1; // the byte was data under running status
                status = running;
            }
            const data_len: usize = switch (status >> 4) {
                0xc, 0xd => 1,
                else => 2,
            };
            try c.skip(data_len);
        }
        end_tick = @max(end_tick, tick);
    }
    if (tracks_seen == 0) return error.InvalidMidi;

    // Microseconds, exact: each tempo segment is ticks * us_per_quarter /
    // division, accumulated as a numerator over `division`.
    std.mem.sort(Tempo, tempos.items, {}, struct {
        fn lessThan(_: void, a: Tempo, b: Tempo) bool {
            return a.tick < b.tick;
        }
    }.lessThan);
    var us_times_div: u128 = 0;
    var last_tick: u64 = 0;
    var tempo: u32 = 500_000;
    for (tempos.items) |t| {
        if (t.tick >= end_tick) break;
        us_times_div += @as(u128, t.tick - last_tick) * tempo;
        last_tick = t.tick;
        tempo = t.us_per_quarter;
    }
    us_times_div += @as(u128, end_tick - last_tick) * tempo;

    const ms: u128 = if (division & 0x8000 != 0) blk: {
        // SMPTE: -frames per second (high byte, two's complement) times
        // ticks per frame (low byte); tempo does not apply.
        const fps: u32 = 256 - @as(u32, division >> 8);
        const per_frame: u32 = division & 0xff;
        if (fps == 0 or per_frame == 0) return error.InvalidMidi;
        break :blk @as(u128, end_tick) * 1000 / (fps * per_frame);
    } else us_times_div / division / 1000;
    return std.math.cast(u32, ms) orelse error.InvalidMidi;
}

/// A General MIDI synthesizer playing one song at a time: the MCI
/// sequencer's open / play / pause / stop / seek to start.
pub const Synth = struct {
    font: *Tsf,
    /// The loaded song's first message (owned), null when none is loaded.
    song: ?*TmlMessage = null,
    /// The next message to dispatch; null once all have been.
    cur: ?*TmlMessage = null,
    /// Song position in output frames.
    frame: u64 = 0,
    sample_rate: u32,
    is_playing: bool = false,

    /// Stereo s16 output at `sample_rate`. `sf2_bytes` may be freed after.
    /// `gpa` is unused: TSF allocates through libc malloc.
    pub fn init(gpa: std.mem.Allocator, sf2_bytes: []const u8, sample_rate: u32) !Synth {
        _ = gpa;
        if (sample_rate == 0) return error.InvalidSampleRate;
        const size = std.math.cast(c_int, sf2_bytes.len) orelse return error.InvalidSoundFont;
        const rate = std.math.cast(c_int, sample_rate) orelse return error.InvalidSampleRate;
        if (size < 12) return error.InvalidSoundFont;
        const font = noite_tsf_open(sf2_bytes.ptr, size, rate) orelse return error.InvalidSoundFont;
        return .{ .font = font, .sample_rate = sample_rate };
    }

    pub fn deinit(s: *Synth) void {
        if (s.song) |m| tml_free(m);
        tsf_close(s.font);
        s.* = undefined;
    }

    /// Replaces the current song, position 0, paused. On error the previous
    /// song is unloaded too.
    pub fn load(s: *Synth, midi_bytes: []const u8) !void {
        if (s.song) |m| tml_free(m);
        s.song = null;
        s.stop();
        const smf = try smfBytes(midi_bytes);
        const size = std.math.cast(c_int, smf.len) orelse return error.InvalidMidi;
        if (size < 14) return error.InvalidMidi;
        s.song = tml_load_memory(smf.ptr, size) orelse return error.InvalidMidi;
        s.cur = s.song;
    }

    pub fn play(s: *Synth) void {
        s.is_playing = s.song != null;
    }

    /// Stops the song where it is; sounding notes are cut.
    pub fn pause(s: *Synth) void {
        s.is_playing = false;
        noite_tsf_silence(s.font);
    }

    /// Silence and rewind; paused.
    pub fn stop(s: *Synth) void {
        s.is_playing = false;
        s.seekStart();
    }

    /// Back to position 0 with fresh channel state; keeps playing or paused.
    pub fn seekStart(s: *Synth) void {
        noite_tsf_rewind(s.font);
        s.cur = s.song;
        s.frame = 0;
    }

    /// True while playing and the song (including its last notes' release)
    /// has not finished.
    pub fn playing(s: *const Synth) bool {
        return s.is_playing and !s.finished();
    }

    fn finished(s: *const Synth) bool {
        return s.cur == null and tsf_active_voice_count(s.font) == 0;
    }

    /// Render interleaved stereo s16 frames; silence when paused/finished/no song.
    /// An odd trailing sample is zeroed.
    pub fn render(s: *Synth, out: []i16) void {
        const frames = out.len / 2;
        var done: usize = 0;
        while (done < frames and s.playing()) {
            const ms: u64 = s.frame * 1000 / s.sample_rate;
            s.cur = noite_midi_dispatch(s.font, s.cur, @intCast(@min(ms, std.math.maxInt(c_uint))));
            const n = @min(block_frames, frames - done);
            tsf_render_short(s.font, out[done * 2 ..].ptr, @intCast(n), 0);
            done += n;
            s.frame += n;
        }
        @memset(out[done * 2 ..], 0);
    }
};

fn readAsset(gpa: std.mem.Allocator, path: []const u8) ![]u8 {
    return std.Io.Dir.cwd().readFileAlloc(std.testing.io, path, gpa, .limited(1 << 20));
}

test "songLengthMs matches the tempo-map oracle" {
    const gpa = std.testing.allocator;
    // Oracle: an independent SMF walk with exact rational arithmetic
    // (end of the longest track through the tempo map, floored).
    const cases = [_]struct { path: []const u8, ms: u32 }{
        .{ .path = "assets/VELHA.MID", .ms = 42659 },
        .{ .path = "assets/MARIO.MID", .ms = 32172 },
    };
    for (cases) |case| {
        const bytes = try readAsset(gpa, case.path);
        defer gpa.free(bytes);
        const got = try songLengthMs(gpa, bytes);
        try std.testing.expect(@abs(@as(i64, got) - case.ms) <= 1);
    }
}

test "songLengthMs rejects bad data" {
    const gpa = std.testing.allocator;
    try std.testing.expectError(error.InvalidMidi, songLengthMs(gpa, ""));
    try std.testing.expectError(error.InvalidMidi, songLengthMs(gpa, "MThd\x00\x00\x00\x06\x00\x01\x00\x01\x00\x78"));
    // A track whose event runs past the end of its chunk.
    try std.testing.expectError(error.InvalidMidi, songLengthMs(gpa, "MThd\x00\x00\x00\x06\x00\x00\x00\x01\x00\x78" ++
        "MTrk\x00\x00\x00\x02\x00\x90"));
}

test "Synth renders VELHA.MID" {
    const gpa = std.testing.allocator;
    const sf2_path = std.testing.environ.getPosix("NOITE_SOUNDFONT") orelse return error.SkipZigTest;
    const sf2 = try std.Io.Dir.cwd().readFileAlloc(std.testing.io, sf2_path, gpa, .limited(256 << 20));
    defer gpa.free(sf2);
    var synth: Synth = try .init(gpa, sf2, 44100);
    defer synth.deinit();

    var buf: [44100 * 2]i16 = undefined;
    synth.render(&buf); // no song: silence
    try std.testing.expect(std.mem.allEqual(i16, &buf, 0));
    try std.testing.expectError(error.InvalidMidi, synth.load("not a midi file"));

    const mid = try readAsset(gpa, "assets/VELHA.MID");
    defer gpa.free(mid);
    try synth.load(mid);
    synth.render(&buf); // loaded but paused: silence
    try std.testing.expect(std.mem.allEqual(i16, &buf, 0));

    synth.play();
    try std.testing.expect(synth.playing());
    synth.render(&buf);
    try std.testing.expect(!std.mem.allEqual(i16, &buf, 0));

    synth.pause();
    try std.testing.expect(!synth.playing());
    synth.render(&buf);
    try std.testing.expect(std.mem.allEqual(i16, &buf, 0));

    synth.stop();
    try std.testing.expectEqual(@as(u64, 0), synth.frame);
    synth.play();
    synth.render(&buf);
    try std.testing.expect(!std.mem.allEqual(i16, &buf, 0));
}
