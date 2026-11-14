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
        const h = self(ptr);
        h.presents += 1;
        // Frame dumps: AVI frames that fell due (only with decode_video).
        _ = h.sim.videoUpdate(h.now, &h.screen_buf);
    }
    fn textOut(ptr: *anyopaque, surf: p.Surface, style: p.TextStyle, x: i16, y: i16, text: []const u8) bool {
        return self(ptr).sim.textOut(surf, style, x, y, text);
    }
    fn textExtent(ptr: *anyopaque, text: []const u8) u32 {
        return self(ptr).sim.textExtent(text);
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
    fn mixGetInfo(ptr: *anyopaque) u16 {
        return self(ptr).sim.mixGetInfo();
    }
    fn mixConfigureInit(ptr: *anyopaque, channels: u16, rate_khz: u16) p.MixSession {
        return self(ptr).sim.mixConfigureInit(channels, rate_khz);
    }
    fn mixOpenChannel(ptr: *anyopaque, ses: p.MixSession, channel: i16, flags: u32) u16 {
        return self(ptr).sim.mixOpenChannel(ses, channel, flags);
    }
    fn mixCloseChannel(ptr: *anyopaque, ses: p.MixSession, channel: i16, flags: u32) u16 {
        return self(ptr).sim.mixCloseChannel(ses, channel, flags);
    }
    fn mixCloseSession(ptr: *anyopaque, ses: p.MixSession) u16 {
        return self(ptr).sim.mixCloseSession(ses);
    }
    fn mixActivate(ptr: *anyopaque, ses: p.MixSession, active: bool) u16 {
        return self(ptr).sim.mixActivate(ses, active);
    }
    fn waveOpen(ptr: *anyopaque, ses: p.MixSession, path: []const u8) ?p.Wave {
        return self(ptr).sim.waveOpen(ses, path);
    }
    fn waveFree(ptr: *anyopaque, ses: p.MixSession, w: p.Wave) u16 {
        return self(ptr).sim.waveFree(ses, w);
    }
    fn wavePlay(ptr: *anyopaque, params: p.PlayParams) u16 {
        const h = self(ptr);
        return h.sim.wavePlay(h.now, params);
    }
    fn waveFlush(ptr: *anyopaque, ses: p.MixSession, channel: i16, flags: u32) u16 {
        return self(ptr).sim.waveFlush(ses, channel, flags);
    }
    fn mciString(ptr: *anyopaque, command: []const u8) u32 {
        const h = self(ptr);
        return h.sim.mciString(h.now, command);
    }
    fn aviOpen(ptr: *anyopaque, path: []const u8, dev: *p.Device) u32 {
        return self(ptr).sim.aviOpen(path, dev);
    }
    fn aviPlay(ptr: *anyopaque, dev: p.Device) u32 {
        const h = self(ptr);
        return h.sim.aviPlay(h.now, dev, &h.screen_buf);
    }
    fn aviStop(ptr: *anyopaque, dev: p.Device) void {
        const h = self(ptr);
        h.sim.aviStop(dev, &h.screen_buf);
    }
    fn aviClose(ptr: *anyopaque, dev: p.Device) void {
        const h = self(ptr);
        h.sim.aviClose(dev, &h.screen_buf);
    }
    fn winExec(ptr: *anyopaque, command: []const u8) u16 {
        const h = self(ptr);
        return h.sim.winExec(h.now, command);
    }
    fn findWindow(ptr: *anyopaque, title: []const u8) ?p.Hwnd {
        const h = self(ptr);
        return h.sim.findWindow(h.now, title);
    }
    fn postTo(ptr: *anyopaque, hwnd: p.Hwnd, m: p.Msg) bool {
        const h = self(ptr);
        return h.sim.postTo(h.now, hwnd, m);
    }
    fn showMain(ptr: *anyopaque, show: bool) void {
        self(ptr).shown = show;
    }
    fn messageBox(_: *anyopaque, caption: []const u8, text: []const u8, style: u16) i16 {
        std.log.info("MessageBox [{s}] {s} (style {x})", .{ caption, text, style });
        return p.defaultButton(style);
    }

    fn filterInput(ptr: *anyopaque, m: p.Msg) ?p.Msg {
        const h = self(ptr);
        return h.sim.filterInput(h.now, m);
    }

    fn freeze(ptr: *anyopaque, ms: u32) void {
        self(ptr).now +%= ms;
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
        .mixGetInfo = mixGetInfo,
        .mixConfigureInit = mixConfigureInit,
        .mixOpenChannel = mixOpenChannel,
        .mixCloseChannel = mixCloseChannel,
        .mixCloseSession = mixCloseSession,
        .mixActivate = mixActivate,
        .waveOpen = waveOpen,
        .waveFree = waveFree,
        .wavePlay = wavePlay,
        .waveFlush = waveFlush,
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
        .filterInput = filterInput,
        .freeze = freeze,
    };
};

test "the minigame stub answers the protocol in order" {
    var h = Headless.init(std.testing.allocator, std.testing.io, .{ .minigame = .{ .won = false, .score = 7 } });
    defer h.deinit();
    const plat = h.platform();
    try std.testing.expect(plat.winExec("\\sauna\\sauna.exe") >= 32);
    // The window shows up after the stub's start-up time.
    try std.testing.expectEqual(@as(?p.Hwnd, null), plat.findWindow("Sauna Mista"));
    plat.wait(1500);
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
