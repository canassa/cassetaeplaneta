//! SDL3 backend: a window of the original's client size (platform.client_*) showing the palettized screen, mouse and
//! arrow keys as Win16 input messages, the real clock, and an audio stream
//! fed from `Sim`'s mixer (waves, AVI soundtracks, MIDI through
//! TinySoundFont with the SoundFont in `$NOITE_SOUNDFONT`). Files, media
//! timing and video frames come from `Sim`. SDL is declared by hand below
//! (Zig 0.17 has no @cImport; only the calls used are declared).

const std = @import("std");
const p = @import("platform.zig");
const Sim = @import("sim.zig").Sim;
const Options = @import("sim.zig").Options;
const msg = @import("../core/msg.zig");
const midi = @import("midi.zig");
const mixer = @import("mixer.zig");
const wm = msg.wm;

const c = struct {
    const Window = opaque {};
    const Renderer = opaque {};
    const Texture = opaque {};
    const FRect = extern struct { x: f32, y: f32, w: f32, h: f32 };
    const init_video: u32 = 0x20;
    const init_audio: u32 = 0x10;
    const AudioStream = opaque {};
    const AudioSpec = extern struct { format: u32, channels: c_int, freq: c_int };
    const audio_s16le: u32 = 0x8010;
    const audio_device_default_playback: u32 = 0xFFFFFFFF;
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
    extern "c" fn SDL_Delay(ms: u32) void;
    extern "c" fn SDL_PollEvent(e: *Event) bool;
    extern "c" fn SDL_WaitEventTimeout(e: *Event, timeout_ms: i32) bool;
    extern "c" fn SDL_OpenAudioDeviceStream(dev: u32, spec: *const AudioSpec, callback: ?*const anyopaque, userdata: ?*anyopaque) ?*AudioStream;
    extern "c" fn SDL_ResumeAudioStreamDevice(stream: *AudioStream) bool;
    extern "c" fn SDL_PutAudioStreamData(stream: *AudioStream, buf: *const anyopaque, len: c_int) bool;
    extern "c" fn SDL_GetAudioStreamQueued(stream: *AudioStream) c_int;
    extern "c" fn SDL_DestroyAudioStream(stream: *AudioStream) void;
    extern "c" fn getenv(name: [*:0]const u8) ?[*:0]const u8;
    /// SDL_Surface's public head (SDL 3).
    const Surface = extern struct { flags: u32, format: u32, w: c_int, h: c_int, pitch: c_int, pixels: ?*anyopaque };
    extern "c" fn SDL_RenderReadPixels(r: *Renderer, rect: ?*const anyopaque) ?*Surface;
    extern "c" fn SDL_ConvertSurface(s: *Surface, format: u32) ?*Surface;
    extern "c" fn SDL_DestroySurface(s: *Surface) void;
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
    audio: ?*c.AudioStream = null,
    synth: ?midi.Synth = null,
    mix_buf: [2048]i16 = undefined,

    /// Audio kept queued ahead of the device (~90 ms of 44.1 kHz stereo s16).
    const audio_ahead_bytes = 4096 * 4;

    pub fn init(s: *Sdl, gpa: std.mem.Allocator, io: std.Io, opts: Options) !void {
        if (!c.SDL_Init(c.init_video | c.init_audio)) return fail("SDL_Init");
        const win = c.SDL_CreateWindow("Casseta & Planeta - Noite Animal", p.client_width, p.client_height, 0) orelse return fail("SDL_CreateWindow");
        const ren = c.SDL_CreateRenderer(win, null) orelse return fail("SDL_CreateRenderer");
        const tex = c.SDL_CreateTexture(ren, c.pixelformat_xrgb8888, c.textureaccess_streaming, p.screen_width, p.screen_height) orelse return fail("SDL_CreateTexture");
        var o = opts;
        o.decode_video = true;
        const spec: c.AudioSpec = .{ .format = c.audio_s16le, .channels = 2, .freq = mixer.out_rate };
        const stream = c.SDL_OpenAudioDeviceStream(c.audio_device_default_playback, &spec, null, null);
        if (stream == null) std.log.warn("no audio: {s}", .{std.mem.span(c.SDL_GetError())});
        o.keep_audio = stream != null;
        s.* = .{ .sim = .init(gpa, io, o), .window = win, .renderer = ren, .texture = tex, .audio = stream };
        if (stream) |st| {
            _ = c.SDL_ResumeAudioStreamDevice(st);
            s.synth = loadSynth(gpa, io);
        }
        // `s` does not move from here on: the mixer points at the synth.
        if (s.synth) |*syn| s.sim.mix.synth = syn;
    }

    /// The MIDI synthesizer over `$NOITE_SOUNDFONT` (set by the dev shell);
    /// without it music is silent (its timing and notifications still work).
    fn loadSynth(gpa: std.mem.Allocator, io: std.Io) ?midi.Synth {
        const path = std.mem.span(c.getenv("NOITE_SOUNDFONT") orelse {
            std.log.warn("NOITE_SOUNDFONT is not set: no music", .{});
            return null;
        });
        const sf2 = std.Io.Dir.cwd().readFileAlloc(io, path, gpa, .limited(256 << 20)) catch |e| {
            std.log.warn("cannot read SoundFont {s}: {t}", .{ path, e });
            return null;
        };
        defer gpa.free(sf2);
        return midi.Synth.init(gpa, sf2, mixer.out_rate) catch |e| {
            std.log.warn("bad SoundFont {s}: {t}", .{ path, e });
            return null;
        };
    }

    /// Keeps the audio stream fed from the mixer.
    fn pumpAudio(s: *Sdl) void {
        const st = s.audio orelse return;
        while (c.SDL_GetAudioStreamQueued(st) < audio_ahead_bytes) {
            s.sim.mix.render(&s.mix_buf);
            if (!c.SDL_PutAudioStreamData(st, &s.mix_buf, @intCast(s.mix_buf.len * 2))) return;
        }
    }

    fn fail(what: []const u8) error{SdlFailed} {
        std.log.err("{s}: {s}", .{ what, std.mem.span(c.SDL_GetError()) });
        return error.SdlFailed;
    }

    pub fn deinit(s: *Sdl) void {
        if (s.audio) |st| c.SDL_DestroyAudioStream(st);
        s.sim.mix.synth = null;
        if (s.synth) |*syn| syn.deinit();
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
                    // SDLK_RETURN/ESCAPE/SPACE are the virtual keys; only
                    // passed on to skip videos.
                    0x0d, 0x1b, 0x20 => if (s.sim.opts.skip_videos) @intCast(key) else return null,
                    else => return null,
                };
                return .{ .input = .{ .id = if (ty == c.event_key_down) wm.keydown else wm.keyup, .wparam = v } };
            },
            else => return null,
        }
    }

    fn poll(ptr: *anyopaque) ?p.Event {
        const s = self(ptr);
        s.pumpAudio();
        if (s.sim.videoUpdate(ticks(ptr), &s.screen_buf)) present(ptr);
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
        var ms: i32 = if (to) |t| @max(0, @as(i32, @bitCast(t -% now))) else 100;
        // Wake up often enough to feed the audio stream and the video.
        if (s.audio != null or s.sim.videos.items.len > 0) ms = @min(ms, 10);
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
        s.screen_buf.drawOverlay(u32, &s.rgb, p.screen_width, &lut);
        _ = c.SDL_UpdateTexture(s.texture, null, &s.rgb, p.screen_width * 4);
        _ = c.SDL_RenderClear(s.renderer);
        const client: c.FRect = .{ .x = 0, .y = 0, .w = p.client_width, .h = p.client_height };
        _ = c.SDL_RenderTexture(s.renderer, s.texture, &client, null);
        _ = c.SDL_RenderPresent(s.renderer);
    }

    /// Test hook: what the renderer shows, read back from SDL (not the
    /// game's 8-bit screen), as XRGB8888 into `out`. False on failure.
    pub fn readBack(s: *Sdl, out: *[p.client_width * p.client_height]u32) bool {
        const raw = c.SDL_RenderReadPixels(s.renderer, null) orelse return false;
        defer c.SDL_DestroySurface(raw);
        const conv = c.SDL_ConvertSurface(raw, c.pixelformat_xrgb8888) orelse return false;
        defer c.SDL_DestroySurface(conv);
        if (conv.w < p.client_width or conv.h < p.client_height) return false;
        const base: [*]const u8 = @ptrCast(conv.pixels orelse return false);
        for (0..p.client_height) |y| {
            const src: [*]align(1) const u32 = @ptrCast(base + y * @as(usize, @intCast(conv.pitch)));
            @memcpy(out[y * p.client_width ..][0..p.client_width], src[0..p.client_width]);
        }
        return true;
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
        return self(ptr).sim.wavePlay(ticks(ptr), params);
    }
    fn waveFlush(ptr: *anyopaque, ses: p.MixSession, channel: i16, flags: u32) u16 {
        return self(ptr).sim.waveFlush(ses, channel, flags);
    }
    fn mciString(ptr: *anyopaque, command: []const u8) u32 {
        return self(ptr).sim.mciString(ticks(ptr), command);
    }
    fn aviOpen(ptr: *anyopaque, path: []const u8, dev: *p.Device) u32 {
        return self(ptr).sim.aviOpen(path, dev);
    }
    fn aviPlay(ptr: *anyopaque, dev: p.Device) u32 {
        const s = self(ptr);
        return s.sim.aviPlay(ticks(ptr), dev, &s.screen_buf);
    }
    fn aviStop(ptr: *anyopaque, dev: p.Device) void {
        const s = self(ptr);
        s.sim.aviStop(dev, &s.screen_buf);
    }
    fn aviClose(ptr: *anyopaque, dev: p.Device) void {
        const s = self(ptr);
        s.sim.aviClose(dev, &s.screen_buf);
    }
    fn winExec(ptr: *anyopaque, command: []const u8) u16 {
        return self(ptr).sim.winExec(ticks(ptr), command);
    }
    fn findWindow(ptr: *anyopaque, title: []const u8) ?p.Hwnd {
        return self(ptr).sim.findWindow(ticks(ptr), title);
    }
    fn postTo(ptr: *anyopaque, hwnd: p.Hwnd, m: p.Msg) bool {
        return self(ptr).sim.postTo(ticks(ptr), hwnd, m);
    }
    fn showMain(ptr: *anyopaque, show: bool) void {
        const s = self(ptr);
        _ = if (show) c.SDL_ShowWindow(s.window) else c.SDL_HideWindow(s.window);
    }
    fn messageBox(_: *anyopaque, caption: []const u8, text: []const u8, style: u16) i16 {
        std.log.warn("MessageBox [{s}] {s} (style {x})", .{ caption, text, style });
        return p.defaultButton(style);
    }

    fn filterInput(ptr: *anyopaque, m: p.Msg) ?p.Msg {
        return self(ptr).sim.filterInput(ticks(ptr), m);
    }

    /// A real stall: the clock (SDL_GetTicks) runs on.
    fn freeze(_: *anyopaque, ms: u32) void {
        c.SDL_Delay(ms);
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
