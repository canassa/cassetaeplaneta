//! SDL3 backend: a 640×480 window showing the palettized screen, mouse and
//! arrow keys as Win16 input messages, the real clock. Files and media
//! timing come from `Sim` (silent for now). SDL is declared by hand below
//! (Zig 0.17 has no @cImport; only the calls used are declared).

const std = @import("std");
const p = @import("platform.zig");
const Sim = @import("sim.zig").Sim;
const Options = @import("sim.zig").Options;
const msg = @import("../core/msg.zig");
const wm = msg.wm;

const c = struct {
    const Window = opaque {};
    const Renderer = opaque {};
    const Texture = opaque {};
    const init_video: u32 = 0x20;
    const pixelformat_xrgb8888: u32 = 0x16161804;
    const textureaccess_streaming: c_int = 1;
    const event_quit: u32 = 0x100;
    const event_focus_gained: u32 = 0x20e;
    const event_focus_lost: u32 = 0x20f;
    const event_key_down: u32 = 0x300;
    const event_key_up: u32 = 0x301;
    const event_mouse_motion: u32 = 0x400;
    const event_mouse_button_down: u32 = 0x401;
    const event_mouse_button_up: u32 = 0x402;
    const key_right: u32 = 0x4000004f;
    const key_left: u32 = 0x40000050;
    const key_down: u32 = 0x40000051;
    const key_up: u32 = 0x40000052;
    /// SDL_Event is a 128-byte union; fields are read at their offsets.
    const Event = extern struct { bytes: [128]u8 align(8) };

    extern "c" fn SDL_Init(flags: u32) bool;
    extern "c" fn SDL_Quit() void;
    extern "c" fn SDL_GetError() [*:0]const u8;
    extern "c" fn SDL_CreateWindow(title: [*:0]const u8, w: c_int, h: c_int, flags: u64) ?*Window;
    extern "c" fn SDL_DestroyWindow(w: *Window) void;
    extern "c" fn SDL_CreateRenderer(w: *Window, name: ?[*:0]const u8) ?*Renderer;
    extern "c" fn SDL_DestroyRenderer(r: *Renderer) void;
    extern "c" fn SDL_CreateTexture(r: *Renderer, format: u32, access: c_int, w: c_int, h: c_int) ?*Texture;
    extern "c" fn SDL_DestroyTexture(t: *Texture) void;
    extern "c" fn SDL_UpdateTexture(t: *Texture, rect: ?*const anyopaque, pixels: *const anyopaque, pitch: c_int) bool;
    extern "c" fn SDL_RenderClear(r: *Renderer) bool;
    extern "c" fn SDL_RenderTexture(r: *Renderer, t: *Texture, src: ?*const anyopaque, dst: ?*const anyopaque) bool;
    extern "c" fn SDL_RenderPresent(r: *Renderer) bool;
    extern "c" fn SDL_ShowWindow(w: *Window) bool;
    extern "c" fn SDL_HideWindow(w: *Window) bool;
    extern "c" fn SDL_GetTicks() u64;
    extern "c" fn SDL_PollEvent(e: *Event) bool;
    extern "c" fn SDL_WaitEventTimeout(e: *Event, timeout_ms: i32) bool;
};

pub const Sdl = struct {
    sim: Sim,
    window: *c.Window,
    renderer: *c.Renderer,
    texture: *c.Texture,
    screen_buf: p.Screen = .{},
    rgb: [p.screen_width * p.screen_height]u32 = undefined,
    buttons: u16 = 0,
    /// An event taken by `wait` that `poll` has not returned yet.
    held: ?c.Event = null,

    pub fn init(s: *Sdl, gpa: std.mem.Allocator, io: std.Io, opts: Options) !void {
        if (!c.SDL_Init(c.init_video)) return fail("SDL_Init");
        const win = c.SDL_CreateWindow("Casseta & Planeta - Noite Animal", p.screen_width, p.screen_height, 0) orelse return fail("SDL_CreateWindow");
        const ren = c.SDL_CreateRenderer(win, null) orelse return fail("SDL_CreateRenderer");
        const tex = c.SDL_CreateTexture(ren, c.pixelformat_xrgb8888, c.textureaccess_streaming, p.screen_width, p.screen_height) orelse return fail("SDL_CreateTexture");
        s.* = .{ .sim = .init(gpa, io, opts), .window = win, .renderer = ren, .texture = tex };
    }

    fn fail(what: []const u8) error{SdlFailed} {
        std.log.err("{s}: {s}", .{ what, std.mem.span(c.SDL_GetError()) });
        return error.SdlFailed;
    }

    pub fn deinit(s: *Sdl) void {
        s.sim.deinit();
        c.SDL_DestroyTexture(s.texture);
        c.SDL_DestroyRenderer(s.renderer);
        c.SDL_DestroyWindow(s.window);
        c.SDL_Quit();
    }

    pub fn platform(s: *Sdl) p.Platform {
        return .{ .ptr = s, .vtable = &vtable };
    }

    fn self(ptr: *anyopaque) *Sdl {
        return @ptrCast(@alignCast(ptr));
    }

    fn ticks(_: *anyopaque) u32 {
        return @truncate(c.SDL_GetTicks());
    }
    fn unixTime(ptr: *anyopaque) i32 {
        const s = self(ptr);
        const now = std.Io.Clock.real.now(s.sim.io);
        return @intCast(@divTrunc(now.nanoseconds, std.time.ns_per_s));
    }

    fn rd(comptime T: type, e: *const c.Event, off: usize) T {
        return std.mem.bytesToValue(T, e.bytes[off..][0..@sizeOf(T)]);
    }

    fn translate(s: *Sdl, e: *const c.Event) ?p.Event {
        const ty = rd(u32, e, 0);
        switch (ty) {
            c.event_quit => return .quit,
            c.event_focus_gained => return .{ .activate = true },
            c.event_focus_lost => return .{ .activate = false },
            c.event_mouse_motion => {
                const x: u16 = @intFromFloat(@max(0, rd(f32, e, 28)));
                const y: u16 = @intFromFloat(@max(0, rd(f32, e, 32)));
                return .{ .input = msg.Msg.make(wm.mousemove, s.buttons, x, y) };
            },
            c.event_mouse_button_down, c.event_mouse_button_up => {
                const down = ty == c.event_mouse_button_down;
                const button = e.bytes[24];
                const x: u16 = @intFromFloat(@max(0, rd(f32, e, 28)));
                const y: u16 = @intFromFloat(@max(0, rd(f32, e, 32)));
                const bit: u16 = switch (button) {
                    1 => msg.mk.lbutton,
                    3 => msg.mk.rbutton,
                    else => return null,
                };
                if (down) s.buttons |= bit else s.buttons &= ~bit;
                const id: u16 = if (bit == msg.mk.lbutton)
                    (if (down) wm.lbuttondown else wm.lbuttonup)
                else
                    (if (down) wm.rbuttondown else wm.rbuttonup);
                return .{ .input = msg.Msg.make(id, s.buttons, x, y) };
            },
            c.event_key_down, c.event_key_up => {
                const key = rd(u32, e, 28);
                const v: u16 = switch (key) {
                    c.key_left => msg.vk.left,
                    c.key_right => msg.vk.right,
                    c.key_up => msg.vk.up,
                    c.key_down => msg.vk.down,
                    else => return null,
                };
                return .{ .input = .{ .id = if (ty == c.event_key_down) wm.keydown else wm.keyup, .wparam = v } };
            },
            else => return null,
        }
    }

    fn poll(ptr: *anyopaque) ?p.Event {
        const s = self(ptr);
        if (s.sim.poll(ticks(ptr))) |ev| return ev;
        if (s.held) |held| {
            s.held = null;
            if (s.translate(&held)) |ev| return ev;
        }
        var e: c.Event = undefined;
        while (c.SDL_PollEvent(&e)) {
            if (s.translate(&e)) |ev| return ev;
        }
        return null;
    }

    fn wait(ptr: *anyopaque, deadline: ?u32) void {
        const s = self(ptr);
        var to = deadline;
        if (s.sim.nextDue()) |d| to = if (to) |t| @min(t, d) else d;
        const now = ticks(ptr);
        const ms: i32 = if (to) |t| @max(0, @as(i32, @bitCast(t -% now))) else 100;
        var e: c.Event = undefined;
        if (c.SDL_WaitEventTimeout(&e, ms)) s.held = e;
    }

    fn screen(ptr: *anyopaque) *p.Screen {
        return &self(ptr).screen_buf;
    }

    fn present(ptr: *anyopaque) void {
        const s = self(ptr);
        var lut: [256]u32 = undefined;
        for (&lut, s.screen_buf.palette) |*l, col| l.* = @as(u32, col.r) << 16 | @as(u32, col.g) << 8 | col.b;
        for (&s.rgb, s.screen_buf.pixels) |*o, i| o.* = lut[i];
        _ = c.SDL_UpdateTexture(s.texture, null, &s.rgb, p.screen_width * 4);
        _ = c.SDL_RenderClear(s.renderer);
        _ = c.SDL_RenderTexture(s.renderer, s.texture, null, null);
        _ = c.SDL_RenderPresent(s.renderer);
    }

    fn textOut(_: *anyopaque, _: i16, _: i16, _: u32, _: []const u8) void {}
    fn textExtent(_: *anyopaque, text: []const u8) u32 {
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
        return self(ptr).sim.wavePlay(ticks(ptr), channel, w, loops);
    }
    fn waveFlush(ptr: *anyopaque, channel: u8) void {
        self(ptr).sim.waveFlush(channel);
    }
    fn mixActivate(_: *anyopaque, _: bool) bool {
        return true;
    }
    fn mciString(ptr: *anyopaque, command: []const u8) u32 {
        return self(ptr).sim.mciString(ticks(ptr), command);
    }
    fn aviOpen(ptr: *anyopaque, path: []const u8) ?p.Device {
        return self(ptr).sim.aviOpen(path);
    }
    fn aviPlay(ptr: *anyopaque, dev: p.Device) bool {
        return self(ptr).sim.aviPlay(ticks(ptr), dev);
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
        return self(ptr).sim.postTo(ticks(ptr), hwnd, m);
    }
    fn showMain(ptr: *anyopaque, show: bool) void {
        const s = self(ptr);
        _ = if (show) c.SDL_ShowWindow(s.window) else c.SDL_HideWindow(s.window);
    }
    fn messageBox(_: *anyopaque, caption: []const u8, text: []const u8) void {
        std.log.warn("MessageBox [{s}] {s}", .{ caption, text });
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
