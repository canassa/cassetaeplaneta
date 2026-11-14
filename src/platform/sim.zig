//! The backend-independent half of the platform: DOS-style files over
//! `assets/` (plus a save directory), the system font, WaveMix, MCI
//! (sequencer, waveaudio, avivideo) and the minigame stub. Every
//! notification is timed from the media's own length (WAVE data size, MIDI
//! tempo map, AVI frame count), never from the audio device, so the
//! headless and SDL backends post the same messages at the same ticks. The
//! SDL backend only renders `mixer` and presents the video frames.

const std = @import("std");
const p = @import("platform.zig");
const msg = @import("../core/msg.zig");
const wm = msg.wm;
const noite = @import("../core/msg.zig").noite;
const Font = @import("font.zig").Font;
const flic = @import("flic.zig");
const midi = @import("midi.zig");
const mixer = @import("mixer.zig");

pub const max_files = 20; // a Win16 task's default handle table

pub const MinigameResult = struct {
    won: bool = true,
    score: i32 = 0,
    /// How long the stub minigame's window takes to appear after WinExec
    /// (FindWindow fails until then), like a real program starting up.
    startup_ms: u32 = 1500,
    /// How long it takes to answer 0x40b with 0x40c.
    reply_ms: u32 = 100,
    /// How long the stub minigame "runs" before reporting.
    duration_ms: u32 = 3000,
};

/// Which WaveMix call fails (to exercise the game's error boxes).
pub const WaveMixFailure = enum { none, get_info, configure_init, open_channel };

pub const Options = struct {
    /// The extracted disc (root of the game's DOS paths).
    assets_dir: []const u8 = "assets",
    /// Where saves (JOGO*.INI) are written; read before `assets_dir`.
    save_dir: []const u8 = "save",
    minigame: MinigameResult = .{},
    wavemix_failure: WaveMixFailure = .none,
    /// Decode AVI frames onto the screen (the SDL backend); headless only
    /// times them.
    decode_video: bool = false,
    /// Keep PCM for the mixer (the SDL backend).
    keep_audio: bool = false,
    /// A file store that replaces `assets_dir` and `save_dir` (the web
    /// backend, which has no file system).
    host_files: ?HostFiles = null,
    /// Quality of life, not in the original (`Sim.filterInput`): a click,
    /// a right click or Esc/Enter/Space while an AVI clip plays ends it.
    skip_videos: bool = false,
};

/// Files from somewhere other than the host file system. Paths are
/// `hostKey`s: lower case, `/`-separated, relative to the disc root.
pub const HostFiles = struct {
    ctx: *anyopaque,
    /// The whole file (saves first, then the disc), owned by the caller
    /// (`gpa`); null if there is none.
    read: *const fn (ctx: *anyopaque, gpa: std.mem.Allocator, key: []const u8) ?[]u8,
    /// Stores a written file (a save) under `key`.
    save: *const fn (ctx: *anyopaque, key: []const u8, data: []const u8) void,
};

/// A DOS path as a `HostFiles` key: drive dropped, `\` → `/`, empty and
/// `.` components dropped, lower case (DOS names are case-insensitive).
/// Null if it does not fit `buf`.
pub fn hostKey(buf: []u8, dos: []const u8) ?[]const u8 {
    var path = dos;
    if (path.len >= 2 and path[1] == ':') path = path[2..];
    var n: usize = 0;
    var it = std.mem.tokenizeAny(u8, path, "\\/");
    while (it.next()) |part| {
        const name = std.mem.trim(u8, part, " ");
        if (name.len == 0 or std.mem.eql(u8, name, ".")) continue;
        if (n != 0) {
            if (n == buf.len) return null;
            buf[n] = '/';
            n += 1;
        }
        if (n + name.len > buf.len) return null;
        _ = std.ascii.lowerString(buf[n..][0..name.len], name);
        n += name.len;
    }
    return buf[0..n];
}

const OpenFile = struct {
    data: std.ArrayList(u8) = .empty,
    pos: usize = 0,
    /// Save-dir relative path when the file is written back on close.
    save_path: ?[]u8 = null,
};

const Pending = struct { due: u32, ev: p.Event };

const Window = struct {
    title: []const u8,
    hwnd: p.Hwnd,
    alive: bool,
    /// Its result is scheduled: the window closes when it is delivered.
    reporting: bool = false,
    /// When the window exists (FindWindow finds it from then on).
    appears_at: u32 = 0,
};

/// An open WaveMix wave: its length and (with `keep_audio`) its samples.
const WaveData = struct {
    ms: u32,
    bytes: ?[]u8 = null,
    pcm: ?mixer.Pcm = null,
};

const DeviceKind = enum { sequencer, waveaudio };

/// An MCI device opened with mciSendString.
const MciDevice = struct {
    id: p.Device,
    kind: DeviceKind,
    alias: [32]u8 = @splat(0),
    alias_len: usize = 0,
    length_ms: u32,
    /// Position (ms) when not playing; when playing, position at `since`.
    pos_ms: u32 = 0,
    playing: bool = false,
    since: u32 = 0,
    /// A `notify` play is pending (its MM_MCINOTIFY is scheduled).
    notify: bool = false,
    bytes: []u8,
    pcm: ?mixer.Pcm = null,

    fn aliasName(d: *const MciDevice) []const u8 {
        return d.alias[0..d.alias_len];
    }
};

/// The AVI being shown (MCI avivideo).
const Video = struct {
    id: p.Device,
    bytes: []u8,
    avi: *flic.Avi,
    decoder: ?flic.Decoder = null,
    pcm_bytes: ?[]u8 = null,
    playing: bool = false,
    since: u32 = 0,
    /// The screen palette before the video took it.
    saved_palette: ?[256]p.Rgb = null,
};

/// The presses `Sim.filterInput` swallowed whose release it still owes
/// nothing to the game.
const Swallowed = struct {
    lbutton: bool = false,
    rbutton: bool = false,
    /// By `skip_keys` index.
    keys: [skip_keys.len]bool = @splat(false),
};

/// How long a clip plays before input can skip it.
pub const skip_grace_ms = 750;

/// The keys that skip a video: VK_RETURN, VK_ESCAPE, VK_SPACE.
pub const skip_keys = [_]u16{ 0x0d, 0x1b, 0x20 };

pub const Sim = struct {
    gpa: std.mem.Allocator,
    io: std.Io,
    opts: Options,
    files: [max_files]?OpenFile = @splat(null),
    pending: std.ArrayList(Pending) = .empty,
    minigames: [4]?Window = @splat(null),
    font: ?Font = null,
    font_tried: bool = false,
    // WaveMix
    session: p.MixSession = 0,
    channels_open: bool = false,
    waves: std.ArrayList(?WaveData) = .empty, // id = index + 1
    lru: [8]u32 = @splat(0),
    /// The wave each channel was last given (0 = none, flushed or freed).
    playing: [8]p.Wave = @splat(0),
    // MCI
    devices: std.ArrayList(MciDevice) = .empty,
    next_device: p.Device = 1,
    videos: std.ArrayList(Video) = .empty,
    mix: mixer.Mixer = .{},
    /// Input that skipped a video: its release (and the button's bit in
    /// the moves until then) is kept from the game too.
    swallowed: Swallowed = .{},

    pub fn init(gpa: std.mem.Allocator, io: std.Io, opts: Options) Sim {
        return .{ .gpa = gpa, .io = io, .opts = opts };
    }

    pub fn deinit(s: *Sim) void {
        for (&s.files) |*f| if (f.*) |*of| {
            of.data.deinit(s.gpa);
            if (of.save_path) |sp| s.gpa.free(sp);
            f.* = null;
        };
        for (s.waves.items) |w| if (w) |wd| if (wd.bytes) |b| s.gpa.free(b);
        s.waves.deinit(s.gpa);
        for (s.devices.items) |d| s.gpa.free(d.bytes);
        s.devices.deinit(s.gpa);
        while (s.videos.items.len > 0) s.freeVideo(0);
        s.videos.deinit(s.gpa);
        s.pending.deinit(s.gpa);
        if (s.font) |*f| f.deinit(s.gpa);
    }

    /// The next due notification at `now`, if any (FIFO among equals).
    pub fn poll(s: *Sim, now: u32) ?p.Event {
        var best: ?usize = null;
        for (s.pending.items, 0..) |pe, i| {
            if (@as(i32, @bitCast(now -% pe.due)) < 0) continue;
            if (best == null or @as(i32, @bitCast(pe.due -% s.pending.items[best.?].due)) < 0) best = i;
        }
        const i = best orelse return null;
        const ev = s.pending.orderedRemove(i).ev;
        if (ev == .message and ev.message.id == wm.mm_mcinotify) s.mciNotified(ev.message, now);
        // The minigame reports and exits: its window is gone from now on
        // (the scenes poll FindWindow on their timers until then).
        if (ev == .message and ev.message.id == noite.minigame_result) {
            for (&s.minigames) |*w| if (w.*) |win| {
                if (win.reporting) w.* = null;
            };
        }
        return ev;
    }

    pub fn nextDue(s: *const Sim) ?u32 {
        var best: ?u32 = null;
        for (s.pending.items) |pe| {
            if (best == null or @as(i32, @bitCast(pe.due -% best.?)) < 0) best = pe.due;
        }
        return best;
    }

    fn schedule(s: *Sim, due: u32, ev: p.Event) void {
        s.pending.append(s.gpa, .{ .due = due, .ev = ev }) catch {};
    }

    /// Drops the scheduled messages `pred` matches.
    fn unschedule(s: *Sim, ctx: anytype, comptime pred: fn (@TypeOf(ctx), p.Msg) bool) void {
        var i: usize = 0;
        while (i < s.pending.items.len) {
            const ev = s.pending.items[i].ev;
            if (ev == .message and pred(ctx, ev.message)) {
                _ = s.pending.orderedRemove(i);
            } else i += 1;
        }
    }

    // ---- files ----------------------------------------------------------

    /// DOS path → path relative to the disc root, normalised with `/`.
    fn normalise(buf: []u8, dos: []const u8) []const u8 {
        var path = dos;
        if (path.len >= 2 and path[1] == ':') path = path[2..];
        var n: usize = 0;
        for (path) |c| {
            if (n == buf.len) break;
            buf[n] = if (c == '\\') '/' else c;
            n += 1;
        }
        return std.mem.trim(u8, buf[0..n], "/ ");
    }

    /// Finds `rel` under `root` ignoring case; returns the real relative path.
    fn resolveIn(s: *Sim, root: []const u8, rel: []const u8, out: []u8) ?[]const u8 {
        var dir = std.Io.Dir.cwd().openDir(s.io, root, .{ .iterate = true }) catch return null;
        var n: usize = 0;
        var it = std.mem.tokenizeScalar(u8, rel, '/');
        while (it.next()) |want| {
            var found: ?[]const u8 = null;
            var walk = dir.iterate();
            var name_buf: [256]u8 = undefined;
            while (walk.next(s.io) catch null) |e| {
                if (std.ascii.eqlIgnoreCase(e.name, want) and e.name.len <= name_buf.len) {
                    @memcpy(name_buf[0..e.name.len], e.name);
                    found = name_buf[0..e.name.len];
                    break;
                }
            }
            const name = found orelse {
                dir.close(s.io);
                return null;
            };
            if (n != 0) {
                out[n] = '/';
                n += 1;
            }
            if (n + name.len >= out.len) {
                dir.close(s.io);
                return null;
            }
            @memcpy(out[n..][0..name.len], name);
            n += name.len;
            if (it.peek() != null) {
                const sub = dir.openDir(s.io, name, .{ .iterate = true }) catch {
                    dir.close(s.io);
                    return null;
                };
                dir.close(s.io);
                dir = sub;
            }
        }
        dir.close(s.io);
        return out[0..n];
    }

    fn readHost(s: *Sim, dos: []const u8) ?[]u8 {
        if (s.opts.host_files) |h| {
            var kb: [512]u8 = undefined;
            return h.read(h.ctx, s.gpa, hostKey(&kb, dos) orelse return null);
        }
        var nb: [512]u8 = undefined;
        const rel = normalise(&nb, dos);
        var rb: [512]u8 = undefined;
        var pb: [1024]u8 = undefined;
        for ([_][]const u8{ s.opts.save_dir, s.opts.assets_dir }) |root| {
            const real = s.resolveIn(root, rel, &rb) orelse continue;
            const full = std.fmt.bufPrint(&pb, "{s}/{s}", .{ root, real }) catch continue;
            return std.Io.Dir.cwd().readFileAlloc(s.io, full, s.gpa, .limited(64 << 20)) catch continue;
        }
        return null;
    }

    pub fn open(s: *Sim, path: []const u8, mode: p.OpenMode) ?p.File {
        const slot = for (&s.files, 0..) |*f, i| {
            if (f.* == null) break i;
        } else return null;
        var of: OpenFile = .{};
        if (mode != .create) {
            if (s.readHost(path)) |bytes| {
                of.data = .fromOwnedSlice(bytes);
            } else if (mode == .read or mode == .read_write) return null;
        }
        if (mode != .read) {
            var nb: [512]u8 = undefined;
            const rel = normalise(&nb, path);
            const lower = s.gpa.alloc(u8, rel.len) catch return null;
            _ = std.ascii.lowerString(lower, rel);
            of.save_path = lower;
        }
        s.files[slot] = of;
        return @intCast(slot + 5); // DOS: 0–4 are the standard handles
    }

    fn file(s: *Sim, f: p.File) ?*OpenFile {
        if (f < 5 or f - 5 >= max_files) return null;
        if (s.files[f - 5]) |*of| return of;
        return null;
    }

    pub fn read(s: *Sim, f: p.File, buf: []u8) usize {
        const of = s.file(f) orelse return 0;
        const n = @min(buf.len, of.data.items.len -| of.pos);
        @memcpy(buf[0..n], of.data.items[of.pos..][0..n]);
        of.pos += n;
        return n;
    }

    pub fn write(s: *Sim, f: p.File, bytes: []const u8) usize {
        const of = s.file(f) orelse return 0;
        const end = of.pos + bytes.len;
        if (end > of.data.items.len) of.data.resize(s.gpa, end) catch return 0;
        @memcpy(of.data.items[of.pos..end], bytes);
        of.pos = end;
        return bytes.len;
    }

    pub fn seek(s: *Sim, f: p.File, offset: i32, whence: p.Whence) i32 {
        const of = s.file(f) orelse return -1;
        const base: i64 = switch (whence) {
            .set => 0,
            .cur => @intCast(of.pos),
            .end => @intCast(of.data.items.len),
        };
        const to = base + offset;
        if (to < 0) return -1;
        of.pos = @intCast(to);
        return @intCast(to);
    }

    pub fn close(s: *Sim, f: p.File) void {
        const of = s.file(f) orelse return;
        if (of.save_path) |sp| save: {
            if (s.opts.host_files) |h| {
                var kb: [512]u8 = undefined;
                if (hostKey(&kb, sp)) |key| h.save(h.ctx, key, of.data.items);
                s.gpa.free(sp);
                break :save;
            }
            const dir = std.fs.path.dirname(sp);
            var root = std.Io.Dir.cwd().openDir(s.io, ".", .{}) catch null;
            if (root) |*r| {
                defer r.close(s.io);
                var pb: [1024]u8 = undefined;
                if (dir) |d| {
                    const full_dir = std.fmt.bufPrint(&pb, "{s}/{s}", .{ s.opts.save_dir, d }) catch "";
                    r.createDirPath(s.io, full_dir) catch {};
                } else r.createDirPath(s.io, s.opts.save_dir) catch {};
                const full = std.fmt.bufPrint(&pb, "{s}/{s}", .{ s.opts.save_dir, sp }) catch "";
                r.writeFile(s.io, .{ .sub_path = full, .data = of.data.items }) catch {};
            }
            s.gpa.free(sp);
        }
        of.data.deinit(s.gpa);
        s.files[f - 5] = null;
    }

    // ---- GDI text ------------------------------------------------------------

    /// The system font, loaded from the disc's `MSSVGA\VGASYS.FON` on first use.
    fn systemFont(s: *Sim) ?*const Font {
        if (!s.font_tried) {
            s.font_tried = true;
            if (s.readHost("\\MSSVGA\\VGASYS.FON")) |bytes| {
                defer s.gpa.free(bytes);
                s.font = Font.parse(s.gpa, bytes) catch null;
            }
        }
        return if (s.font) |*f| f else null;
    }

    /// GDI's colour match for a DIB: PALETTEINDEX(i) is i, an RGB value
    /// the nearest table entry (lowest index on ties).
    pub fn nearestIndex(colors: *const [256]p.RgbQuad, color: u32) u8 {
        if (color >> 24 == 1) return @truncate(color);
        const r: i32 = @intCast(color & 0xff);
        const g: i32 = @intCast(color >> 8 & 0xff);
        const b: i32 = @intCast(color >> 16 & 0xff);
        var best: u8 = 0;
        var best_d: i32 = std.math.maxInt(i32);
        for (colors, 0..) |q, i| {
            const dr = r - q.red;
            const dg = g - q.green;
            const db = b - q.blue;
            const d = dr * dr + dg * dg + db * db;
            if (d < best_d) {
                best_d = d;
                best = @intCast(i);
            }
        }
        return best;
    }

    pub fn textOut(s: *Sim, surf: p.Surface, style: p.TextStyle, x: i16, y: i16, text: []const u8) bool {
        const f = s.systemFont() orelse return false;
        const fg = nearestIndex(surf.colors, style.color);
        const bg: ?u8 = if (style.bk_mode == .@"opaque") nearestIndex(surf.colors, style.bk_color) else null;
        f.draw(surf.pixels, surf.stride(), surf.width, surf.height, surf.bottom_up, x, y, fg, bg, text);
        return true;
    }

    pub fn textExtent(s: *Sim, text: []const u8) u32 {
        const f = s.systemFont() orelse return @as(u32, @intCast(text.len * 8)) | 16 << 16;
        const e = f.extent(text);
        return @as(u32, e.w) | @as(u32, e.h) << 16;
    }

    // ---- WaveMix ----------------------------------------------------------

    const mmsyserr_invalhandle: u16 = 5;
    const mmsyserr_invalparam: u16 = 11;
    const mmsyserr_error: u16 = 1;

    pub const WaveInfo = struct { ms: u32, pcm: mixer.Pcm };

    /// Length and samples of a RIFF WAVE file, or null if it is not one.
    pub fn parseWave(bytes: []const u8) ?WaveInfo {
        if (bytes.len < 12 or !std.mem.eql(u8, bytes[0..4], "RIFF") or !std.mem.eql(u8, bytes[8..12], "WAVE")) return null;
        var pos: usize = 12;
        var rate: u32 = 0;
        var byte_rate: u32 = 0;
        var channels: u16 = 0;
        var bits: u16 = 0;
        while (pos + 8 <= bytes.len) {
            const ck = bytes[pos..][0..4];
            const size = std.mem.readInt(u32, bytes[pos + 4 ..][0..4], .little);
            const body = bytes[pos + 8 ..];
            if (std.mem.eql(u8, ck, "fmt ") and body.len >= 16) {
                channels = std.mem.readInt(u16, body[2..4], .little);
                rate = std.mem.readInt(u32, body[4..8], .little);
                byte_rate = std.mem.readInt(u32, body[8..12], .little);
                bits = std.mem.readInt(u16, body[14..16], .little);
            }
            if (std.mem.eql(u8, ck, "data")) {
                if (byte_rate == 0) return null;
                const data = body[0..@min(size, body.len)];
                return .{
                    .ms = @intCast(@as(u64, size) * 1000 / byte_rate),
                    .pcm = .{ .data = data, .rate = rate, .bits = bits, .channels = @max(channels, 1) },
                };
            }
            pos += 8 + @as(usize, size) + (size & 1);
        }
        return null;
    }

    /// Duration of a RIFF WAVE file in ms, or null if it is not one.
    pub fn waveDuration(bytes: []const u8) ?u32 {
        return if (parseWave(bytes)) |w| w.ms else null;
    }

    pub fn mixGetInfo(s: *Sim) u16 {
        return if (s.opts.wavemix_failure == .get_info) mmsyserr_error else 0;
    }

    pub fn mixConfigureInit(s: *Sim, channels: u16, rate_khz: u16) p.MixSession {
        _ = .{ channels, rate_khz }; // the mixer resamples whatever it gets
        if (s.opts.wavemix_failure == .configure_init or s.session != 0) return 0;
        s.session = 1;
        return s.session;
    }

    pub fn mixOpenChannel(s: *Sim, session: p.MixSession, channel: i16, flags: u32) u16 {
        _ = .{ channel, flags };
        if (session == 0 or session != s.session) return mmsyserr_invalhandle;
        if (s.opts.wavemix_failure == .open_channel) return mmsyserr_error;
        s.channels_open = true;
        return 0;
    }

    pub fn mixCloseChannel(s: *Sim, session: p.MixSession, channel: i16, flags: u32) u16 {
        if (session == 0 or session != s.session) return mmsyserr_invalhandle;
        _ = s.waveFlush(session, channel, flags);
        if (flags & p.wmix.openall != 0) s.channels_open = false;
        return 0;
    }

    pub fn mixCloseSession(s: *Sim, session: p.MixSession) u16 {
        if (session == 0 or session != s.session) return mmsyserr_invalhandle;
        _ = s.waveFlush(session, 0, p.wmix.all);
        s.session = 0;
        s.channels_open = false;
        return 0;
    }

    pub fn mixActivate(s: *Sim, session: p.MixSession, active: bool) u16 {
        if (session == 0 or session != s.session) return mmsyserr_invalhandle;
        s.mix.active = active;
        return 0;
    }

    pub fn waveOpen(s: *Sim, session: p.MixSession, path: []const u8) ?p.Wave {
        if (session == 0 or session != s.session) return null;
        const bytes = s.readHost(path) orelse return null;
        const info = parseWave(bytes) orelse {
            s.gpa.free(bytes);
            return null;
        };
        var wd: WaveData = .{ .ms = info.ms };
        if (s.opts.keep_audio) {
            wd.bytes = bytes;
            wd.pcm = info.pcm;
        } else s.gpa.free(bytes);
        s.waves.append(s.gpa, wd) catch {
            if (wd.bytes) |b| s.gpa.free(b);
            return null;
        };
        return @intCast(s.waves.items.len);
    }

    fn wave(s: *Sim, w: p.Wave) ?*WaveData {
        if (w == 0 or w > s.waves.items.len) return null;
        if (s.waves.items[w - 1]) |*wd| return wd;
        return null;
    }

    pub fn waveFree(s: *Sim, session: p.MixSession, w: p.Wave) u16 {
        if (session == 0 or session != s.session) return mmsyserr_invalhandle;
        const wd = s.wave(w) orelse return mmsyserr_invalhandle;
        // WAVEMIX.DLL's WaveMixFreeWave (seg 1:20d8) unlinks the wave from
        // every channel's play queue, the playing entry included, and posts
        // nothing: the wave stops and its MM_WOM_DONE never comes.
        for (&s.playing, 0..) |*pw, c| if (pw.* == w) {
            s.unschedule(ChannelMatch{ .channel = @intCast(c) }, ChannelMatch.matches);
            s.mix.channels[c].stop();
            pw.* = 0;
        };
        if (wd.bytes) |b| s.gpa.free(b);
        s.waves.items[w - 1] = null;
        return 0;
    }

    const ChannelMatch = struct {
        channel: u16,
        fn matches(c: @This(), m: p.Msg) bool {
            return m.id == wm.mm_wom_done and m.wparam == c.channel;
        }
    };

    pub fn wavePlay(s: *Sim, now: u32, params: p.PlayParams) u16 {
        if (params.session == 0 or params.session != s.session or !s.channels_open) return mmsyserr_invalhandle;
        const wd = s.wave(params.wave) orelse return mmsyserr_invalhandle;
        var ch: usize = undefined;
        if (params.use_lru_channel) {
            ch = std.mem.indexOfMin(u32, &s.lru);
        } else {
            if (params.channel < 0 or params.channel >= 8) return mmsyserr_invalparam;
            ch = @intCast(params.channel);
        }
        // The game always clears the queue; queued play (no flag) is not
        // modelled: the new wave replaces the old one either way.
        s.unschedule(ChannelMatch{ .channel = @intCast(ch) }, ChannelMatch.matches);
        s.lru[ch] = now +% 1;
        s.playing[ch] = params.wave;
        if (wd.pcm) |pcm| s.mix.channels[ch].start(pcm, params.loops) else s.mix.channels[ch].stop();
        if (params.notify and params.loops != 0xffff) {
            const ms = wd.ms *% (@as(u32, params.loops) + 1);
            s.schedule(now +% ms, .{ .message = .{ .id = wm.mm_wom_done, .wparam = @intCast(ch) } });
        }
        return 0;
    }

    pub fn waveFlush(s: *Sim, session: p.MixSession, channel: i16, flags: u32) u16 {
        if (session == 0 or session != s.session) return mmsyserr_invalhandle;
        for (0..8) |c| {
            if (flags & p.wmix.all == 0 and c != channel) continue;
            s.unschedule(ChannelMatch{ .channel = @intCast(c) }, ChannelMatch.matches);
            s.mix.channels[c].stop();
            s.playing[c] = 0;
        }
        return 0;
    }

    // ---- MCI strings ----------------------------------------------------------

    const mcierr_unrecognized_command = p.mcierr.unrecognized_command;
    const mcierr_invalid_device_name = p.mcierr.invalid_device_name;
    const mcierr_file_not_found = p.mcierr.file_not_found;
    const mcierr_duplicate_alias = p.mcierr.duplicate_alias;
    const mcierr_unsupported_function = p.mcierr.unsupported_function;
    const mci_notify_successful: u16 = 1;
    const mci_notify_superseded: u16 = 2;
    const mci_notify_aborted: u16 = 4;

    fn device(s: *Sim, alias: []const u8) ?*MciDevice {
        for (s.devices.items) |*d| if (std.ascii.eqlIgnoreCase(d.aliasName(), alias)) return d;
        return null;
    }

    fn position(d: *const MciDevice, now: u32) u32 {
        if (!d.playing) return d.pos_ms;
        return @min(d.length_ms, d.pos_ms +% (now -% d.since));
    }

    const DeviceMatch = struct {
        dev: p.Device,
        fn matches(c: @This(), m: p.Msg) bool {
            return m.id == wm.mm_mcinotify and m.lparam == c.dev;
        }
    };

    /// A pending `notify` is cut short: MM_MCINOTIFY with ABORTED, or
    /// SUPERSEDED when the new command asks for notification too.
    fn interrupt(s: *Sim, d: *MciDevice, now: u32, superseded: bool) void {
        if (!d.notify) return;
        s.unschedule(DeviceMatch{ .dev = d.id }, DeviceMatch.matches);
        d.notify = false;
        const why = if (superseded) mci_notify_superseded else mci_notify_aborted;
        s.schedule(now, .{ .message = .{ .id = wm.mm_mcinotify, .wparam = why, .lparam = d.id } });
    }

    /// A device's end-of-play notification was delivered: it is stopped at
    /// its end.
    fn mciNotified(s: *Sim, m: p.Msg, now: u32) void {
        if (m.wparam != mci_notify_successful) return;
        for (s.devices.items) |*d| if (d.id == m.lparam) {
            d.pos_ms = position(d, now);
            d.playing = false;
            d.notify = false;
        };
    }

    fn startAudio(s: *Sim, d: *MciDevice) void {
        switch (d.kind) {
            .sequencer => if (s.mix.synth) |syn| {
                syn.load(d.bytes) catch return;
                // The synth plays from the start only; a resume after
                // "pause" restarts the song in sound, not in timing.
                syn.play();
            },
            .waveaudio => if (d.pcm) |pcm| s.mix.mci_wave.start(pcm, 0),
        }
    }

    fn stopAudio(s: *Sim, d: *MciDevice) void {
        switch (d.kind) {
            .sequencer => if (s.mix.synth) |syn| syn.stop(),
            .waveaudio => s.mix.mci_wave.stop(),
        }
    }

    /// The MCI string commands the game sends (see `Platform.mciString`).
    pub fn mciString(s: *Sim, now: u32, command: []const u8) u32 {
        var words: [8][]const u8 = undefined;
        var n: usize = 0;
        var it = std.mem.tokenizeScalar(u8, command, ' ');
        while (it.next()) |w| : (n += 1) {
            if (n == words.len) return mcierr_unrecognized_command;
            words[n] = w;
        }
        if (n < 2) return mcierr_unrecognized_command;
        const verb = words[0];
        const rest = words[2..n];
        var notify = false;
        var from_zero = false;
        var kind: ?DeviceKind = null;
        var alias: ?[]const u8 = null;
        var i: usize = 0;
        while (i < rest.len) : (i += 1) {
            const w = rest[i];
            if (std.ascii.eqlIgnoreCase(w, "notify")) {
                notify = true;
            } else if (std.ascii.eqlIgnoreCase(w, "from") and i + 1 < rest.len) {
                from_zero = std.mem.eql(u8, rest[i + 1], "0");
                i += 1;
            } else if (std.ascii.eqlIgnoreCase(w, "type") and i + 1 < rest.len) {
                i += 1;
                if (std.ascii.eqlIgnoreCase(rest[i], "sequencer")) kind = .sequencer else if (std.ascii.eqlIgnoreCase(rest[i], "waveaudio")) kind = .waveaudio else return mcierr_invalid_device_name;
            } else if (std.ascii.eqlIgnoreCase(w, "alias") and i + 1 < rest.len) {
                i += 1;
                alias = rest[i];
            }
        }
        if (std.ascii.eqlIgnoreCase(verb, "open")) {
            const a = alias orelse words[1];
            if (s.device(a) != null) return mcierr_duplicate_alias;
            const k = kind orelse return mcierr_invalid_device_name;
            const bytes = s.readHost(words[1]) orelse return mcierr_file_not_found;
            var d: MciDevice = .{ .id = s.next_device, .kind = k, .length_ms = 0, .bytes = bytes };
            switch (k) {
                .sequencer => d.length_ms = midi.songLengthMs(s.gpa, bytes) catch {
                    s.gpa.free(bytes);
                    return mcierr_file_not_found;
                },
                .waveaudio => {
                    const w = parseWave(bytes) orelse {
                        s.gpa.free(bytes);
                        return mcierr_file_not_found;
                    };
                    d.length_ms = w.ms;
                    if (s.opts.keep_audio) d.pcm = w.pcm;
                },
            }
            d.alias_len = @min(a.len, d.alias.len);
            @memcpy(d.alias[0..d.alias_len], a[0..d.alias_len]);
            s.devices.append(s.gpa, d) catch {
                s.gpa.free(bytes);
                return mcierr_file_not_found;
            };
            s.next_device += 1;
            return 0;
        }
        const d = s.device(words[1]) orelse return mcierr_invalid_device_name;
        if (std.ascii.eqlIgnoreCase(verb, "play")) {
            s.interrupt(d, now, notify);
            if (from_zero) d.pos_ms = 0 else d.pos_ms = position(d, now);
            if (d.pos_ms >= d.length_ms) d.pos_ms = if (from_zero) 0 else d.length_ms;
            const resume_audio = d.playing or d.pos_ms != 0;
            d.playing = true;
            d.since = now;
            if (!resume_audio or from_zero) s.startAudio(d) else if (d.kind == .sequencer) {
                if (s.mix.synth) |syn| syn.play();
            } else s.mix.mci_wave.paused = false;
            if (notify) {
                d.notify = true;
                s.schedule(now +% (d.length_ms - d.pos_ms), .{ .message = .{ .id = wm.mm_mcinotify, .wparam = mci_notify_successful, .lparam = d.id } });
            }
            return 0;
        }
        if (std.ascii.eqlIgnoreCase(verb, "pause") or std.ascii.eqlIgnoreCase(verb, "stop")) {
            s.interrupt(d, now, notify);
            d.pos_ms = position(d, now);
            d.playing = false;
            if (std.ascii.eqlIgnoreCase(verb, "stop") and d.kind == .waveaudio) d.pos_ms = 0;
            switch (d.kind) {
                .sequencer => if (s.mix.synth) |syn| syn.pause(),
                .waveaudio => s.mix.mci_wave.paused = true,
            }
            return 0;
        }
        if (std.ascii.eqlIgnoreCase(verb, "resume")) {
            if (!d.playing) {
                d.playing = true;
                d.since = now;
                switch (d.kind) {
                    .sequencer => if (s.mix.synth) |syn| syn.play(),
                    .waveaudio => s.mix.mci_wave.paused = false,
                }
            }
            return 0;
        }
        if (std.ascii.eqlIgnoreCase(verb, "close")) {
            s.interrupt(d, now, false);
            s.stopAudio(d);
            s.gpa.free(d.bytes);
            const idx = (@intFromPtr(d) - @intFromPtr(s.devices.items.ptr)) / @sizeOf(MciDevice);
            _ = s.devices.orderedRemove(idx);
            return 0;
        }
        return mcierr_unsupported_function;
    }

    // ---- MCI avivideo ---------------------------------------------------------

    /// AVI: microseconds per frame × frames, from the `avih` header.
    pub fn aviDuration(bytes: []const u8) ?u32 {
        const i = std.mem.indexOf(u8, bytes[0..@min(bytes.len, 4096)], "avih") orelse return null;
        if (i + 8 + 20 > bytes.len) return null;
        const usec = std.mem.readInt(u32, bytes[i + 8 ..][0..4], .little);
        const frames = std.mem.readInt(u32, bytes[i + 8 + 16 ..][0..4], .little);
        return @intCast(@as(u64, usec) * frames / 1000);
    }

    fn video(s: *Sim, dev: p.Device) ?usize {
        for (s.videos.items, 0..) |v, i| if (v.id == dev) return i;
        return null;
    }

    fn freeVideo(s: *Sim, i: usize) void {
        var v = s.videos.orderedRemove(i);
        if (v.decoder) |*d| d.deinit(s.gpa);
        if (v.pcm_bytes) |b| s.gpa.free(b);
        v.avi.deinit(s.gpa);
        s.gpa.destroy(v.avi);
        s.gpa.free(v.bytes);
    }

    /// MCI_OPEN of an AVI: 0 and `out` set, or the MCI error (file not
    /// found; not a FLIC AVI this decoder reads; out of memory).
    pub fn aviOpen(s: *Sim, path: []const u8, out: *p.Device) u32 {
        const bytes = s.readHost(path) orelse return p.mcierr.file_not_found;
        const avi = s.gpa.create(flic.Avi) catch {
            s.gpa.free(bytes);
            return p.mcierr.out_of_memory;
        };
        avi.* = flic.Avi.parse(s.gpa, bytes) catch {
            s.gpa.destroy(avi);
            s.gpa.free(bytes);
            return p.mcierr.invalid_file;
        };
        const dev: p.Device = 0x100 + s.next_device;
        s.next_device += 1;
        s.videos.append(s.gpa, .{ .id = dev, .bytes = bytes, .avi = avi }) catch {
            avi.deinit(s.gpa);
            s.gpa.destroy(avi);
            s.gpa.free(bytes);
            return p.mcierr.out_of_memory;
        };
        out.* = dev;
        return 0;
    }

    /// MCI_PLAY with notify: 0, or MCIERR_INVALID_DEVICE_ID.
    pub fn aviPlay(s: *Sim, now: u32, dev: p.Device, screen: *p.Screen) u32 {
        const i = s.video(dev) orelse return p.mcierr.invalid_device_id;
        const v = &s.videos.items[i];
        if (s.opts.decode_video and v.decoder == null) {
            v.decoder = flic.Decoder.init(s.gpa, v.avi) catch null;
            v.saved_palette = screen.palette;
        }
        if (s.opts.keep_audio and v.pcm_bytes == null) if (v.avi.audio) |a| {
            v.pcm_bytes = v.avi.audioPcm(s.gpa) catch null;
            if (v.pcm_bytes) |b| s.mix.video.start(.{ .data = b, .rate = a.rate, .bits = a.bits, .channels = a.channels }, 0);
        };
        v.playing = true;
        v.since = now;
        s.schedule(now +% v.avi.durationMs(), .{ .message = .{ .id = wm.mm_mcinotify, .wparam = mci_notify_successful, .lparam = dev } });
        return 0;
    }

    /// Draws the frames of the playing videos that fell due by `now` onto
    /// `screen` (640×480, top-left). True if the screen changed.
    pub fn videoUpdate(s: *Sim, now: u32, screen: *p.Screen) bool {
        var changed = false;
        for (s.videos.items) |*v| {
            if (!v.playing) continue;
            const d = &(v.decoder orelse continue);
            const us: u64 = @as(u64, now -% v.since) * 1000;
            const due: u64 = if (v.avi.usec_per_frame == 0) 0 else us / v.avi.usec_per_frame;
            while (d.next_frame <= due) {
                const more = d.decodeNext() catch true; // damaged frames on the disc: keep going
                if (!more) break;
                changed = true;
            }
            if (changed) {
                const w: usize = @min(v.avi.width, p.screen_width);
                const h: usize = @min(v.avi.height, p.screen_height);
                for (0..h) |y| @memcpy(screen.pixels[y * p.screen_width ..][0..w], d.pixels[y * v.avi.width ..][0..w]);
                for (&screen.palette, d.palette) |*o, c| o.* = .{ .r = c.r, .g = c.g, .b = c.b };
            }
        }
        return changed;
    }

    pub fn aviStop(s: *Sim, dev: p.Device, screen: *p.Screen) void {
        s.unschedule(DeviceMatch{ .dev = dev }, DeviceMatch.matches);
        const i = s.video(dev) orelse return;
        const v = &s.videos.items[i];
        v.playing = false;
        if (v.pcm_bytes != null) s.mix.video.stop();
        if (v.saved_palette) |pal| screen.palette = pal;
        v.saved_palette = null;
    }

    pub fn aviClose(s: *Sim, dev: p.Device, screen: *p.Screen) void {
        s.aviStop(dev, screen);
        const i = s.video(dev) orelse return;
        s.freeVideo(i);
    }

    /// Ends every playing AVI clip as if it had played to the end: its
    /// pending MM_MCINOTIFY (successful) falls due `now`; frames and sound
    /// stop where they are. The notification is moved, not added, so the
    /// game gets exactly one. `.none` when no clip has one pending (none
    /// plays, or its end was already delivered); `.early` (nothing
    /// skipped) while a clip is in its first `skip_grace_ms`, so the second
    /// click of a double click that started it doesn't skip it unseen.
    pub fn skipVideos(s: *Sim, now: u32) enum { none, early, skipped } {
        for (s.pending.items) |pe| {
            if (pe.ev != .message) continue;
            const m = pe.ev.message;
            if (m.id != wm.mm_mcinotify or m.wparam != mci_notify_successful) continue;
            const i = s.video(m.lo()) orelse continue;
            if (now -% s.videos.items[i].since < skip_grace_ms) return .early;
        }
        var any = false;
        for (s.pending.items) |*pe| {
            if (pe.ev != .message) continue;
            const m = pe.ev.message;
            if (m.id != wm.mm_mcinotify or m.wparam != mci_notify_successful) continue;
            const i = s.video(m.lo()) orelse continue;
            const v = &s.videos.items[i];
            pe.due = now;
            if (v.playing and v.pcm_bytes != null) s.mix.video.stop();
            v.playing = false;
            any = true;
        }
        return if (any) .skipped else .none;
    }

    /// Input on its way to the game. With `Options.skip_videos` (quality
    /// of life, not in the original, whose MCIAVI window ignored input) a
    /// left or right button press, or Esc/Enter/Space, while a clip plays
    /// ends the clip (`skipVideos`; in its first `skip_grace_ms` it only
    /// is ignored) and is swallowed, and so is its release
    /// (and the button's MK_* bit in the mouse messages before it). Null =
    /// swallowed; without the option every message passes unchanged.
    ///
    /// A stub minigame that has answered the game's hello has its window
    /// up: in Windows that window is in front and active, so the mouse and
    /// the keys go to it, not to the game, until it reports and closes.
    /// The stub has no window, so its input is dropped here; otherwise a
    /// click in the moment between the hello and the 0x40c that hides the
    /// game could still leave the scene that launched the minigame, and
    /// the next scene's handler would take its 0x40c/0x40a for its own
    /// (3fhall's TIRO into 3ffarao: back to the hall with the pharaoh
    /// video still playing over it, then a crash when the video ends).
    pub fn filterInput(s: *Sim, now: u32, m: p.Msg) ?p.Msg {
        if (s.minigameHasInput(now)) {
            switch (m.id) {
                wm.lbuttonup => s.swallowed.lbutton = false,
                wm.rbuttonup => s.swallowed.rbutton = false,
                wm.keyup => for (skip_keys, &s.swallowed.keys) |k, *held| {
                    if (k == m.wparam) held.* = false;
                },
                else => {},
            }
            return null;
        }
        switch (m.id) {
            wm.lbuttonup => if (s.swallowed.lbutton) {
                s.swallowed.lbutton = false;
                return null;
            },
            wm.rbuttonup => if (s.swallowed.rbutton) {
                s.swallowed.rbutton = false;
                return null;
            },
            wm.keyup => for (skip_keys, &s.swallowed.keys) |k, *held| {
                if (k == m.wparam and held.*) {
                    held.* = false;
                    return null;
                }
            },
            else => {},
        }
        var out = m;
        if (m.id >= wm.mousemove and m.id <= wm.mousemove + 9) {
            if (s.swallowed.lbutton) out.wparam &= ~msg.mk.lbutton;
            if (s.swallowed.rbutton) out.wparam &= ~msg.mk.rbutton;
        }
        if (!s.opts.skip_videos) return out;
        const key = std.mem.indexOfScalar(u16, &skip_keys, m.wparam);
        switch (m.id) {
            wm.lbuttondown, wm.rbuttondown => {},
            wm.keydown => if (key == null) return out,
            else => return out,
        }
        if (s.skipVideos(now) == .none) return out;
        switch (m.id) {
            wm.lbuttondown => s.swallowed.lbutton = true,
            wm.rbuttondown => s.swallowed.rbutton = true,
            else => s.swallowed.keys[key.?] = true,
        }
        return null;
    }

    // ---- minigames ------------------------------------------------------------

    /// Minigame EXE base name → window title (ledger, Unit 13).
    const titles = [_]struct { exe: []const u8, title: []const u8 }{
        .{ .exe = "tiro", .title = "Tiro ao Alvaro" },
        .{ .exe = "sauna", .title = "Sauna Mista" },
        .{ .exe = "encaixe", .title = "Encaixe Perfeito" },
        .{ .exe = "serial", .title = "Serial Killer" },
        .{ .exe = "xilindro", .title = "Xilindro" },
        .{ .exe = "inferno", .title = "Inferno" },
        .{ .exe = "inv", .title = "Invasores" },
        // The game compares the window title in code page 1252 (0xe1 = á).
        .{ .exe = "salgin", .title = "Sala de Gin\xe1stica" },
        .{ .exe = "jardim", .title = "Noite Animal Jardim" },
    };

    pub fn winExec(s: *Sim, now: u32, command: []const u8) u16 {
        const cmd = std.mem.trim(u8, command, " ");
        const exe_path = cmd[0 .. std.mem.indexOfScalar(u8, cmd, ' ') orelse cmd.len];
        var base = exe_path[(std.mem.lastIndexOfAny(u8, exe_path, "\\/:") orelse 0)..];
        base = std.mem.trimStart(u8, base, "\\/:");
        if (std.mem.lastIndexOfScalar(u8, base, '.')) |dot| base = base[0..dot];
        for (titles) |t| {
            if (!std.ascii.eqlIgnoreCase(t.exe, base)) continue;
            for (&s.minigames, 0..) |*w, i| if (w.* == null) {
                w.* = .{ .title = t.title, .hwnd = @intCast(100 + i), .alive = true, .appears_at = now +% s.opts.minigame.startup_ms };
                return 33;
            };
            return 0; // out of memory
        }
        return 2; // file not found
    }

    /// A minigame window is up and answered the hello (it reports, then
    /// closes): it has the input.
    fn minigameHasInput(s: *const Sim, now: u32) bool {
        for (s.minigames) |w| if (w) |win| {
            if (win.alive and win.reporting and @as(i32, @bitCast(now -% win.appears_at)) >= 0) return true;
        };
        return false;
    }

    pub fn findWindow(s: *Sim, now: u32, title: []const u8) ?p.Hwnd {
        for (s.minigames) |w| if (w) |win| {
            if (@as(i32, @bitCast(now -% win.appears_at)) < 0) continue;
            if (win.alive and std.mem.eql(u8, win.title, title)) return win.hwnd;
        };
        return null;
    }

    /// The stub minigame answers 0x40b with 0x40c, then reports the result
    /// configured in `Options.minigame` and closes.
    pub fn postTo(s: *Sim, now: u32, hwnd: p.Hwnd, m: p.Msg) bool {
        for (&s.minigames) |*w| if (w.*) |*win| {
            if (win.hwnd != hwnd or !win.alive) continue;
            // A repeated hello (JARDIM's timer keeps posting it) is ignored.
            if (m.id == noite.minigame_hello and !win.reporting) {
                const r = s.opts.minigame;
                s.schedule(now +% r.reply_ms, .{ .message = .{ .id = noite.minigame_ready } });
                s.schedule(now +% r.reply_ms +% r.duration_ms, .{ .message = .{ .id = noite.minigame_result, .wparam = @intFromBool(r.won), .lparam = r.score } });
                win.reporting = true; // gone once its result is delivered
            }
            return true;
        };
        return false;
    }
};

test "wave and avi durations come from the file headers" {
    const gpa = std.testing.allocator;
    const io = std.testing.io;
    const wav = try std.Io.Dir.cwd().readFileAlloc(io, "assets/PAN/WAV/BOIOLS01.WAV", gpa, .limited(16 << 20));
    defer gpa.free(wav);
    try std.testing.expect(Sim.waveDuration(wav).? > 0);
    var s = Sim.init(gpa, io, .{});
    defer s.deinit();
    var screen: p.Screen = .{};
    // 1AMAO.AVI: 29 frames at 357000 µs (avih bytes 0x20 and 0x30)
    var dev: p.Device = 0;
    try std.testing.expectEqual(@as(u32, 0), s.aviOpen("\\1amao.avi", &dev));
    try std.testing.expectEqual(@as(u32, 0), s.aviPlay(0, dev, &screen));
    try std.testing.expectEqual(p.mcierr.file_not_found, s.aviOpen("\\nothere.avi", &dev));
    try std.testing.expectEqual(@as(?u32, 29 * 357), s.nextDue());
    s.aviClose(dev, &screen);
    try std.testing.expectEqual(@as(?u32, null), s.nextDue());
}

test "DOS paths resolve case-insensitively under the disc root" {
    var s = Sim.init(std.testing.allocator, std.testing.io, .{});
    defer s.deinit();
    const f = s.open("\\casseta.ini", .read).?;
    var buf: [2]u8 = undefined;
    try std.testing.expectEqual(@as(usize, 2), s.read(f, &buf));
    try std.testing.expectEqual(@as(i32, 0), s.seek(f, 0, .set));
    s.close(f);
    try std.testing.expectEqual(@as(?p.File, null), s.open("\\nope.ini", .read));
}

test "text extents come from VGASYS.FON" {
    var s = Sim.init(std.testing.allocator, std.testing.io, .{});
    defer s.deinit();
    // Digits are 8 px, the cell 16 px high (oracle: the font file).
    try std.testing.expectEqual(@as(u32, 24 | 16 << 16), s.textExtent("123"));
    var pixels: [32 * 16]u8 = @splat(7);
    var colors: [256]p.RgbQuad = @splat(.{});
    colors[3] = .{ .red = 255, .green = 255 }; // yellow
    colors[5] = .{ .red = 250, .green = 250, .blue = 250 };
    const surf: p.Surface = .{ .pixels = &pixels, .width = 32, .height = 16, .bottom_up = false, .colors = &colors };
    try std.testing.expect(s.textOut(surf, .{ .color = 0x00ffff, .bk_mode = .transparent }, 0, 0, "1"));
    try std.testing.expect(std.mem.indexOfScalar(u8, &pixels, 3) != null);
    try std.testing.expect(std.mem.indexOfScalar(u8, &pixels, 5) == null);
    _ = s.textOut(surf, .{}, 16, 0, "1"); // opaque white background
    try std.testing.expect(std.mem.indexOfScalar(u8, &pixels, 5) != null);
    try std.testing.expectEqual(@as(u8, 9), Sim.nearestIndex(&colors, 0x01000009));
}

test "WaveMix: session, LRU channel, notify and flush" {
    var s = Sim.init(std.testing.allocator, std.testing.io, .{});
    defer s.deinit();
    try std.testing.expectEqual(@as(u16, 0), s.mixGetInfo());
    const ses = s.mixConfigureInit(1, 22);
    try std.testing.expect(ses != 0);
    try std.testing.expectEqual(@as(u16, 0), s.mixOpenChannel(ses, 0, p.wmix.openall));
    const w = s.waveOpen(ses, "\\PAN\\WAV\\BOIOLS01.WAV").?;
    const ms = s.wave(w).?.ms;
    try std.testing.expectEqual(@as(u16, 0), s.wavePlay(10, .{ .session = ses, .channel = 3, .wave = w, .notify = true, .clear_queue = true }));
    try std.testing.expectEqual(@as(?u32, 10 + ms), s.nextDue());
    try std.testing.expectEqual(@as(u16, 3), s.poll(10 + ms).?.message.wparam);
    // LRU: channel 3 was just used, so an LRU play takes channel 0.
    _ = s.wavePlay(20, .{ .session = ses, .channel = 7, .wave = w, .notify = true, .use_lru_channel = true });
    try std.testing.expectEqual(@as(u16, 0), s.pending.items[0].ev.message.wparam);
    _ = s.waveFlush(ses, 0, p.wmix.all);
    try std.testing.expectEqual(@as(?u32, null), s.nextDue());
    // Freeing a playing wave stops it with no notification; the other
    // channel's wave still notifies.
    const w2 = s.waveOpen(ses, "\\PAN\\WAV\\BOIOLS01.WAV").?;
    _ = s.wavePlay(40, .{ .session = ses, .channel = 1, .wave = w, .notify = true });
    _ = s.wavePlay(40, .{ .session = ses, .channel = 2, .wave = w2, .notify = true });
    try std.testing.expectEqual(@as(u16, 0), s.waveFree(ses, w));
    try std.testing.expectEqual(@as(usize, 1), s.pending.items.len);
    try std.testing.expectEqual(@as(u16, 2), s.pending.items[0].ev.message.wparam);
    _ = s.waveFlush(ses, 0, p.wmix.all);
    try std.testing.expectEqual(@as(u16, 0), s.mixCloseSession(ses));
    try std.testing.expectEqual(@as(u16, 5), s.wavePlay(30, .{ .session = ses, .channel = 0, .wave = w, .notify = false }));

    var f = Sim.init(std.testing.allocator, std.testing.io, .{ .wavemix_failure = .configure_init });
    defer f.deinit();
    try std.testing.expectEqual(@as(p.MixSession, 0), f.mixConfigureInit(1, 22));
}

test "MCI sequencer: notify at the song's length, pause aborts it" {
    var s = Sim.init(std.testing.allocator, std.testing.io, .{});
    defer s.deinit();
    try std.testing.expectEqual(@as(u32, 0), s.mciString(0, "open \\VELHA.MID type sequencer alias musica"));
    try std.testing.expectEqual(@as(u32, 289), s.mciString(0, "open \\VELHA.MID type sequencer alias musica"));
    try std.testing.expectEqual(@as(u32, 0), s.mciString(100, "play musica notify"));
    // VELHA.MID is 42659 ms long (midi.zig's tempo-map oracle).
    try std.testing.expectEqual(@as(?u32, 100 + 42659), s.nextDue());
    _ = s.mciString(1100, "pause musica");
    const ab = s.poll(1100).?.message;
    try std.testing.expectEqual(@as(u16, 4), ab.wparam); // MCI_NOTIFY_ABORTED
    _ = s.mciString(2000, "play musica notify");
    try std.testing.expectEqual(@as(?u32, 2000 + 42659 - 1000), s.nextDue());
    const done = s.poll(2000 + 41659).?.message;
    try std.testing.expectEqual(@as(u16, 1), done.wparam);
    try std.testing.expectEqual(@as(u32, 0), s.mciString(50_000, "play musica from 0 notify"));
    try std.testing.expectEqual(@as(?u32, 50_000 + 42659), s.nextDue());
    try std.testing.expectEqual(@as(u32, 0), s.mciString(50_001, "close musica"));
    try std.testing.expectEqual(@as(u32, 263), s.mciString(50_002, "play musica"));
    try std.testing.expectEqual(@as(u32, 275), s.mciString(0, "open \\fase4\\4fboydj\\maeemae.wav type waveaudio alias dancacasseta"));
    // The B2 fix's path (the copy at the disc root) opens and plays.
    try std.testing.expectEqual(@as(u32, 0), s.mciString(0, "open \\maeemae.wav type waveaudio alias dancacasseta"));
    try std.testing.expectEqual(@as(u32, 0), s.mciString(0, "play dancacasseta notify"));
}

test "AVI frames are drawn onto the screen as they fall due" {
    var s = Sim.init(std.testing.allocator, std.testing.io, .{ .decode_video = true });
    defer s.deinit();
    var screen: p.Screen = .{};
    var dev: p.Device = 0;
    try std.testing.expectEqual(@as(u32, 0), s.aviOpen("\\1AMAO.AVI", &dev));
    try std.testing.expectEqual(@as(u32, 0), s.aviPlay(0, dev, &screen));
    try std.testing.expect(s.videoUpdate(0, &screen)); // frame 0
    try std.testing.expect(!s.videoUpdate(100, &screen)); // frame 1 is due at 357 ms
    try std.testing.expect(s.videoUpdate(357, &screen));
    try std.testing.expect(std.mem.indexOfNone(u8, &screen.pixels, &.{0}) != null);
    s.aviClose(dev, &screen);
    try std.testing.expectEqual(@as(u8, 0), screen.palette[1].r); // restored
}

test "a click skips the playing AVI: one notification, now, and no click" {
    var s = Sim.init(std.testing.allocator, std.testing.io, .{ .skip_videos = true });
    defer s.deinit();
    var screen: p.Screen = .{};
    var dev: p.Device = 0;
    const down = msg.Msg.make(wm.lbuttondown, msg.mk.lbutton, 10, 10);
    const up = msg.Msg.make(wm.lbuttonup, 0, 10, 10);
    // No clip: input passes.
    try std.testing.expectEqual(@as(?p.Msg, down), s.filterInput(0, down));
    try std.testing.expectEqual(@as(?p.Msg, up), s.filterInput(0, up));
    try std.testing.expectEqual(@as(u32, 0), s.aviOpen("\\1AMAO.AVI", &dev));
    try std.testing.expectEqual(@as(u32, 0), s.aviPlay(100, dev, &screen));
    // An unrelated key passes; the click is swallowed, with its move and release.
    const left: msg.Msg = .{ .id = wm.keydown, .wparam = msg.vk.left };
    try std.testing.expectEqual(@as(?p.Msg, left), s.filterInput(200, left));
    // In the first skip_grace_ms a click is swallowed but skips nothing.
    try std.testing.expectEqual(@as(?p.Msg, null), s.filterInput(200, down));
    try std.testing.expectEqual(@as(?p.Msg, null), s.filterInput(250, up));
    try std.testing.expectEqual(@as(?u32, 100 + 29 * 357), s.nextDue());
    try std.testing.expectEqual(@as(?p.Msg, null), s.filterInput(900, down));
    try std.testing.expectEqual(@as(?u32, 900), s.nextDue());
    try std.testing.expectEqual(@as(u16, 0), s.filterInput(910, msg.Msg.make(wm.mousemove, msg.mk.lbutton, 1, 1)).?.wparam);
    // A second press before the end is delivered is swallowed too.
    const esc: msg.Msg = .{ .id = wm.keydown, .wparam = 0x1b };
    try std.testing.expectEqual(@as(?p.Msg, null), s.filterInput(920, esc));
    try std.testing.expectEqual(@as(?p.Msg, null), s.filterInput(930, up));
    try std.testing.expectEqual(@as(?p.Msg, null), s.filterInput(930, .{ .id = wm.keyup, .wparam = 0x1b }));
    const ev = s.poll(930).?.message;
    try std.testing.expectEqual(wm.mm_mcinotify, ev.id);
    try std.testing.expectEqual(@as(u16, 1), ev.wparam);
    try std.testing.expectEqual(dev, ev.lo());
    try std.testing.expectEqual(@as(?p.Event, null), s.poll(100_000));
    // The end is out: input reaches the game again.
    try std.testing.expectEqual(@as(?p.Msg, down), s.filterInput(940, down));
    s.aviClose(dev, &screen);
}

test "without skip_videos a click during a clip passes" {
    var s = Sim.init(std.testing.allocator, std.testing.io, .{});
    defer s.deinit();
    var screen: p.Screen = .{};
    var dev: p.Device = 0;
    try std.testing.expectEqual(@as(u32, 0), s.aviOpen("\\1AMAO.AVI", &dev));
    try std.testing.expectEqual(@as(u32, 0), s.aviPlay(0, dev, &screen));
    const down = msg.Msg.make(wm.lbuttondown, msg.mk.lbutton, 10, 10);
    try std.testing.expectEqual(@as(?p.Msg, down), s.filterInput(5, down));
    try std.testing.expectEqual(@as(?u32, 29 * 357), s.nextDue());
    s.aviClose(dev, &screen);
}

test "a minigame that answered the hello has the input until it reports" {
    var s = Sim.init(std.testing.allocator, std.testing.io, .{});
    defer s.deinit();
    const down = msg.Msg.make(wm.rbuttondown, msg.mk.rbutton, 10, 10);
    try std.testing.expectEqual(@as(u16, 33), s.winExec(0, "c:\\noite\\tiro\\tiro.exe"));
    // Launched, not up yet, then up but not spoken to: the game has the input.
    try std.testing.expectEqual(@as(?p.Msg, down), s.filterInput(100, down));
    const w = s.findWindow(1500, "Tiro ao Alvaro").?;
    try std.testing.expectEqual(@as(?p.Msg, down), s.filterInput(1500, down));
    try std.testing.expect(s.postTo(1500, w, msg.Msg.make(noite.minigame_hello, 0, msg.main_window, 0)));
    try std.testing.expectEqual(@as(?p.Msg, null), s.filterInput(1550, down));
    try std.testing.expectEqual(noite.minigame_ready, s.poll(1600).?.message.id);
    try std.testing.expectEqual(@as(?p.Msg, null), s.filterInput(1650, down));
    try std.testing.expectEqual(noite.minigame_result, s.poll(100_000).?.message.id);
    try std.testing.expectEqual(@as(?p.Msg, down), s.filterInput(100_000, down));
}

test "hostKey turns DOS paths into lower-case store keys" {
    var buf: [64]u8 = undefined;
    try std.testing.expectEqualStrings("fase2/2fcopmau/pmaus03.wav", hostKey(&buf, "D:\\FASE2\\\\2fcopmau\\PMAUS03.WAV").?);
    try std.testing.expectEqualStrings("hd/jogo1.ini", hostKey(&buf, "\\hd\\.\\JOGO1.INI").?);
    try std.testing.expectEqualStrings("velha.mid", hostKey(&buf, "\\velha.mid").?);
    var small: [4]u8 = undefined;
    try std.testing.expectEqual(@as(?[]const u8, null), hostKey(&small, "\\velha.mid"));
}
