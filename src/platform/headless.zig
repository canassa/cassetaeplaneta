//! Headless backend: a virtual clock that jumps to the next deadline, a
//! script of timed input, and the shared `Sim` for files and media. Same
//! script + same assets → same message trace (tests, trace diffing).

const std = @import("std");
const p = @import("platform.zig");
const Sim = @import("sim.zig").Sim;
pub const Options = @import("sim.zig").Options;

pub const Scripted = struct { at: u32, ev: p.Event };

pub const Headless = struct {
    sim: Sim,
    now: u32 = 0,
    /// time() at tick 0 (fixed so random_below is reproducible).
    epoch: i32 = 800_000_000,
    script: []const Scripted = &.{},
    next_script: usize = 0,
    screen_buf: p.Screen = .{},
    presents: u32 = 0,
    shown: bool = true,

    pub fn init(gpa: std.mem.Allocator, io: std.Io, opts: Options) Headless {
        return .{ .sim = .init(gpa, io, opts) };
    }

    pub fn deinit(h: *Headless) void {
        h.sim.deinit();
    }

    /// True when nothing will ever happen again without new input.
    pub fn idleForever(h: *const Headless) bool {
        return h.next_script == h.script.len and h.sim.nextDue() == null;
    }

    pub fn platform(h: *Headless) p.Platform {
        return .{ .ptr = h, .vtable = &vtable };
    }

    fn self(ptr: *anyopaque) *Headless {
        return @ptrCast(@alignCast(ptr));
    }

    fn ticks(ptr: *anyopaque) u32 {
        return self(ptr).now;
    }
    fn unixTime(ptr: *anyopaque) i32 {
        const h = self(ptr);
        return h.epoch +% @as(i32, @intCast(h.now / 1000));
    }
    fn poll(ptr: *anyopaque) ?p.Event {
        const h = self(ptr);
        if (h.next_script < h.script.len and h.script[h.next_script].at <= h.now) {
            h.next_script += 1;
            return h.script[h.next_script - 1].ev;
        }
        return h.sim.poll(h.now);
    }
    fn wait(ptr: *anyopaque, deadline: ?u32) void {
        const h = self(ptr);
        var to = deadline;
        if (h.sim.nextDue()) |d| to = if (to) |t| @min(t, d) else d;
        if (h.next_script < h.script.len) {
            const at = h.script[h.next_script].at;
            to = if (to) |t| @min(t, at) else at;
        }
        if (to) |t| h.now = @max(h.now, t);
    }
    fn screen(ptr: *anyopaque) *p.Screen {
        return &self(ptr).screen_buf;
    }
    fn present(ptr: *anyopaque) void {
        self(ptr).presents += 1;
    }
    fn textOut(_: *anyopaque, _: i16, _: i16, _: u32, _: []const u8) void {}
    fn textExtent(_: *anyopaque, text: []const u8) u32 {
        // System font cell 8×16 (approximation until a font is chosen).
        return @as(u32, @intCast(text.len * 8)) | 16 << 16;
    }
    fn open(ptr: *anyopaque, path: []const u8, mode: p.OpenMode) ?p.File {
        return self(ptr).sim.open(path, mode);
    }
    fn read(ptr: *anyopaque, f: p.File, buf: []u8) usize {
        return self(ptr).sim.read(f, buf);
    }
    fn write(ptr: *anyopaque, f: p.File, bytes: []const u8) usize {
        return self(ptr).sim.write(f, bytes);
    }
    fn seek(ptr: *anyopaque, f: p.File, offset: i32, whence: p.Whence) i32 {
        return self(ptr).sim.seek(f, offset, whence);
    }
    fn close(ptr: *anyopaque, f: p.File) void {
        self(ptr).sim.close(f);
    }
    fn waveOpen(ptr: *anyopaque, path: []const u8) ?p.Wave {
        return self(ptr).sim.waveOpen(path);
    }
    fn waveFree(_: *anyopaque, _: p.Wave) void {}
    fn wavePlay(ptr: *anyopaque, channel: u8, w: p.Wave, loops: i16) bool {
        const h = self(ptr);
        return h.sim.wavePlay(h.now, channel, w, loops);
    }
    fn waveFlush(ptr: *anyopaque, channel: u8) void {
        self(ptr).sim.waveFlush(channel);
    }
    fn mixActivate(_: *anyopaque, _: bool) bool {
        return true;
    }
    fn mciString(ptr: *anyopaque, command: []const u8) u32 {
        const h = self(ptr);
        return h.sim.mciString(h.now, command);
    }
    fn aviOpen(ptr: *anyopaque, path: []const u8) ?p.Device {
        return self(ptr).sim.aviOpen(path);
    }
    fn aviPlay(ptr: *anyopaque, dev: p.Device) bool {
        const h = self(ptr);
        return h.sim.aviPlay(h.now, dev);
    }
    fn aviStop(ptr: *anyopaque, dev: p.Device) void {
        self(ptr).sim.aviStop(dev);
    }
    fn aviClose(ptr: *anyopaque, dev: p.Device) void {
        self(ptr).sim.aviStop(dev);
    }
    fn winExec(ptr: *anyopaque, command: []const u8) u16 {
        return self(ptr).sim.winExec(command);
    }
    fn findWindow(ptr: *anyopaque, title: []const u8) ?p.Hwnd {
        return self(ptr).sim.findWindow(title);
    }
    fn postTo(ptr: *anyopaque, hwnd: p.Hwnd, m: p.Msg) bool {
        const h = self(ptr);
        return h.sim.postTo(h.now, hwnd, m);
    }
    fn showMain(ptr: *anyopaque, show: bool) void {
        self(ptr).shown = show;
    }
    fn messageBox(_: *anyopaque, caption: []const u8, text: []const u8) void {
        std.log.info("MessageBox [{s}] {s}", .{ caption, text });
    }

    const vtable: p.Platform.VTable = .{
        .ticks = ticks,
        .unixTime = unixTime,
        .poll = poll,
        .wait = wait,
        .screen = screen,
        .present = present,
        .textOut = textOut,
        .textExtent = textExtent,
        .open = open,
        .read = read,
        .write = write,
        .seek = seek,
        .close = close,
        .waveOpen = waveOpen,
        .waveFree = waveFree,
        .wavePlay = wavePlay,
        .waveFlush = waveFlush,
        .mixActivate = mixActivate,
        .mciString = mciString,
        .aviOpen = aviOpen,
        .aviPlay = aviPlay,
        .aviStop = aviStop,
        .aviClose = aviClose,
        .winExec = winExec,
        .findWindow = findWindow,
        .postTo = postTo,
        .showMain = showMain,
        .messageBox = messageBox,
    };
};

test "the minigame stub answers the protocol in order" {
    var h = Headless.init(std.testing.allocator, std.testing.io, .{ .minigame = .{ .won = false, .score = 7 } });
    defer h.deinit();
    const plat = h.platform();
    try std.testing.expect(plat.winExec("\\sauna\\sauna.exe") >= 32);
    const w = plat.findWindow("Sauna Mista").?;
    try std.testing.expect(plat.postTo(w, .{ .id = 0x40b }));
    plat.wait(null);
    try std.testing.expectEqual(@as(u16, 0x40c), plat.poll().?.message.id);
    plat.wait(null);
    const r = plat.poll().?.message;
    try std.testing.expectEqual(@as(u16, 0x40a), r.id);
    try std.testing.expectEqual(@as(i32, 7), r.lparam);
    try std.testing.expect(h.idleForever());
}
