//! The backend-independent half of the platform: DOS-style files over
//! `assets/` (plus a save directory), and the timing of waves, MCI devices
//! and minigames. Media are silent here: a wave or video only takes its
//! real duration and then posts its notification, so event order does not
//! depend on the backend. (Decoding/mixing for the SDL backend plugs in
//! later behind the same calls; see docs/DESIGN.md "Platform layer".)

const std = @import("std");
const p = @import("platform.zig");
const wm = @import("../core/msg.zig").wm;
const noite = @import("../core/msg.zig").noite;

pub const max_files = 20; // a Win16 task's default handle table

pub const MinigameResult = struct {
    won: bool = true,
    score: i32 = 0,
    /// How long the stub minigame "runs" before reporting.
    duration_ms: u32 = 1000,
};

pub const Options = struct {
    /// The extracted disc (root of the game's DOS paths).
    assets_dir: []const u8 = "assets",
    /// Where saves (JOGO*.INI) are written; read before `assets_dir`.
    save_dir: []const u8 = "save",
    minigame: MinigameResult = .{},
};

const OpenFile = struct {
    data: std.ArrayList(u8) = .empty,
    pos: usize = 0,
    /// Save-dir relative path when the file is written back on close.
    save_path: ?[]u8 = null,
};

const Pending = struct { due: u32, ev: p.Event };

const Window = struct { title: []const u8, hwnd: p.Hwnd, alive: bool };

pub const Sim = struct {
    gpa: std.mem.Allocator,
    io: std.Io,
    opts: Options,
    files: [max_files]?OpenFile = @splat(null),
    waves: std.ArrayList(u32) = .empty, // duration in ms per wave id (index + 1)
    pending: std.ArrayList(Pending) = .empty,
    minigames: [4]?Window = @splat(null),
    music_open: bool = false,

    pub fn init(gpa: std.mem.Allocator, io: std.Io, opts: Options) Sim {
        return .{ .gpa = gpa, .io = io, .opts = opts };
    }

    pub fn deinit(s: *Sim) void {
        for (&s.files) |*f| if (f.*) |*of| {
            of.data.deinit(s.gpa);
            if (of.save_path) |sp| s.gpa.free(sp);
            f.* = null;
        };
        s.waves.deinit(s.gpa);
        s.pending.deinit(s.gpa);
    }

    /// The next due notification at `now`, if any (FIFO among equals).
    pub fn poll(s: *Sim, now: u32) ?p.Event {
        var best: ?usize = null;
        for (s.pending.items, 0..) |pe, i| {
            if (@as(i32, @bitCast(now -% pe.due)) < 0) continue;
            if (best == null or @as(i32, @bitCast(pe.due -% s.pending.items[best.?].due)) < 0) best = i;
        }
        const i = best orelse return null;
        return s.pending.orderedRemove(i).ev;
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
        if (of.save_path) |sp| {
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

    // ---- WaveMix ----------------------------------------------------------

    /// Duration of a RIFF WAVE file in ms, or null if it is not one.
    pub fn waveDuration(bytes: []const u8) ?u32 {
        if (bytes.len < 12 or !std.mem.eql(u8, bytes[0..4], "RIFF") or !std.mem.eql(u8, bytes[8..12], "WAVE")) return null;
        var pos: usize = 12;
        var byte_rate: u32 = 0;
        while (pos + 8 <= bytes.len) {
            const id = bytes[pos..][0..4];
            const size = std.mem.readInt(u32, bytes[pos + 4 ..][0..4], .little);
            const body = bytes[pos + 8 ..];
            if (std.mem.eql(u8, id, "fmt ") and body.len >= 12) byte_rate = std.mem.readInt(u32, body[8..12], .little);
            if (std.mem.eql(u8, id, "data")) {
                if (byte_rate == 0) return null;
                return @intCast(@as(u64, size) * 1000 / byte_rate);
            }
            pos += 8 + size + (size & 1);
        }
        return null;
    }

    pub fn waveOpen(s: *Sim, path: []const u8) ?p.Wave {
        const bytes = s.readHost(path) orelse return null;
        defer s.gpa.free(bytes);
        const ms = waveDuration(bytes) orelse return null;
        s.waves.append(s.gpa, ms) catch return null;
        return @intCast(s.waves.items.len);
    }

    pub fn wavePlay(s: *Sim, now: u32, channel: u8, w: p.Wave, loops: i16) bool {
        if (w == 0 or w > s.waves.items.len) return false;
        if (loops < 0) return true; // looping waves never finish
        const ms = s.waves.items[w - 1] * @as(u32, @intCast(loops + 1));
        s.schedule(now +% ms, .{ .message = .{ .id = wm.mm_wom_done, .wparam = channel } });
        return true;
    }

    pub fn waveFlush(s: *Sim, channel: u8) void {
        var i: usize = 0;
        while (i < s.pending.items.len) {
            const ev = s.pending.items[i].ev;
            if (ev == .message and ev.message.id == wm.mm_wom_done and ev.message.wparam == channel) {
                _ = s.pending.orderedRemove(i);
            } else i += 1;
        }
    }

    // ---- MCI ----------------------------------------------------------------

    /// The few MCI string commands the game sends. Music (sequencer) never
    /// notifies here: MIDI playback is not implemented yet.
    pub fn mciString(s: *Sim, now: u32, command: []const u8) u32 {
        _ = now;
        var it = std.mem.tokenizeScalar(u8, command, ' ');
        const verb = it.next() orelse return 1;
        if (std.ascii.eqlIgnoreCase(verb, "open")) {
            const path = it.next() orelse return 1;
            const bytes = s.readHost(path) orelse return 275; // MCIERR_FILE_NOT_FOUND
            s.gpa.free(bytes);
            s.music_open = true;
            return 0;
        }
        return 0;
    }

    /// AVI: microseconds per frame × frames, from the `avih` header.
    pub fn aviDuration(bytes: []const u8) ?u32 {
        const i = std.mem.indexOf(u8, bytes[0..@min(bytes.len, 4096)], "avih") orelse return null;
        if (i + 8 + 20 > bytes.len) return null;
        const usec = std.mem.readInt(u32, bytes[i + 8 ..][0..4], .little);
        const frames = std.mem.readInt(u32, bytes[i + 8 + 16 ..][0..4], .little);
        return @intCast(@as(u64, usec) * frames / 1000);
    }

    pub fn aviOpen(s: *Sim, path: []const u8) ?p.Device {
        const bytes = s.readHost(path) orelse return null;
        defer s.gpa.free(bytes);
        const ms = aviDuration(bytes) orelse return null;
        s.waves.append(s.gpa, ms) catch return null; // devices share the duration table
        return @intCast(0x100 + s.waves.items.len);
    }

    pub fn aviPlay(s: *Sim, now: u32, dev: p.Device) bool {
        if (dev <= 0x100 or dev - 0x100 > s.waves.items.len) return false;
        const ms = s.waves.items[dev - 0x101];
        s.schedule(now +% ms, .{ .message = .{ .id = wm.mm_mcinotify, .wparam = 1, .lparam = dev } });
        return true;
    }

    pub fn aviStop(s: *Sim, dev: p.Device) void {
        var i: usize = 0;
        while (i < s.pending.items.len) {
            const ev = s.pending.items[i].ev;
            if (ev == .message and ev.message.id == wm.mm_mcinotify and ev.message.lparam == dev) {
                _ = s.pending.orderedRemove(i);
            } else i += 1;
        }
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
        .{ .exe = "salgin", .title = "Sala de Ginástica" },
        .{ .exe = "jardim", .title = "Noite Animal Jardim" },
    };

    pub fn winExec(s: *Sim, command: []const u8) u16 {
        const cmd = std.mem.trim(u8, command, " ");
        const exe_path = cmd[0 .. std.mem.indexOfScalar(u8, cmd, ' ') orelse cmd.len];
        var base = exe_path[(std.mem.lastIndexOfAny(u8, exe_path, "\\/:") orelse 0)..];
        base = std.mem.trimStart(u8, base, "\\/:");
        if (std.mem.lastIndexOfScalar(u8, base, '.')) |dot| base = base[0..dot];
        for (titles) |t| {
            if (!std.ascii.eqlIgnoreCase(t.exe, base)) continue;
            for (&s.minigames, 0..) |*w, i| if (w.* == null) {
                w.* = .{ .title = t.title, .hwnd = @intCast(100 + i), .alive = true };
                return 33;
            };
            return 0; // out of memory
        }
        return 2; // file not found
    }

    pub fn findWindow(s: *Sim, title: []const u8) ?p.Hwnd {
        for (s.minigames) |w| if (w) |win| {
            if (win.alive and std.mem.eql(u8, win.title, title)) return win.hwnd;
        };
        return null;
    }

    /// The stub minigame answers 0x40b with 0x40c, then reports the result
    /// configured in `Options.minigame` and closes.
    pub fn postTo(s: *Sim, now: u32, hwnd: p.Hwnd, m: p.Msg) bool {
        for (&s.minigames) |*w| if (w.*) |*win| {
            if (win.hwnd != hwnd or !win.alive) continue;
            if (m.id == noite.minigame_hello) {
                const r = s.opts.minigame;
                s.schedule(now +% 100, .{ .message = .{ .id = noite.minigame_ready } });
                s.schedule(now +% 100 +% r.duration_ms, .{ .message = .{ .id = noite.minigame_result, .wparam = @intFromBool(r.won), .lparam = r.score } });
                win.alive = false; // gone once it reports
                w.* = null;
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
    // 1AMAO.AVI: 29 frames at 357000 µs (avih bytes 0x20 and 0x30)
    const dev = s.aviOpen("\\1amao.avi").?;
    try std.testing.expect(s.aviPlay(0, dev));
    try std.testing.expectEqual(@as(?u32, 29 * 357), s.nextDue());
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
