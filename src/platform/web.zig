//! Web backend (wasm32-wasi in a browser page, `web/noite.js`): the page
//! owns the clock, the canvas, input, WebAudio and the files; this side
//! keeps the screen, an input queue the page fills, and the shared `Sim`
//! for files, media timing and video frames. Nothing here blocks: `wait`
//! returns at once and the page calls the main loop once per animation
//! frame (`src/web_main.zig`).
//!
//! Files come from the page's store (the disc's files it downloaded before
//! starting, by `hostKey`; saves in localStorage) through `HostFiles`.
//! Audio: the page pulls the mix (`mixer.render`, 44.1 kHz stereo s16) as
//! it schedules WebAudio buffers; music uses TinySoundFont over the
//! SoundFont the page downloaded (store key `soundfont.sf2`).

const std = @import("std");
const p = @import("platform.zig");
const sim_mod = @import("sim.zig");
const Sim = sim_mod.Sim;
const msg = @import("../core/msg.zig");
const midi = @import("midi.zig");
const mixer = @import("mixer.zig");
const wm = msg.wm;

/// What the page provides (the `env` imports of `web/noite.js`).
pub const js = struct {
    /// performance.now(), in milliseconds since the page started.
    pub extern "env" fn js_now() f64;
    /// Date.now(), in milliseconds since 1970.
    pub extern "env" fn js_date_now() f64;
    /// Size of the stored file `key`, or -1 if there is none.
    pub extern "env" fn js_file_size(key: [*]const u8, len: usize) i32;
    /// Copies the stored file `key` (js_file_size bytes) to `dst`.
    pub extern "env" fn js_file_read(key: [*]const u8, len: usize, dst: [*]u8) void;
    /// Stores a save file.
    pub extern "env" fn js_file_save(key: [*]const u8, len: usize, data: [*]const u8, data_len: usize) void;
    /// Shows the client part (platform.client_*, top-left) of `pixels` (640×480 RGBA) on the canvas.
    pub extern "env" fn js_present(pixels: [*]const u8) void;
    /// ShowWindow: hides the canvas while a (stubbed) minigame runs.
    pub extern "env" fn js_show_main(show: bool) void;
    /// console.log (level 0 err, 1 warn, 2 info, 3 debug).
    pub extern "env" fn js_log(level: u32, text: [*]const u8, len: usize) void;
};

/// The input the page posted (mouse, arrow keys, focus), oldest first.
const InputRing = struct {
    buf: [256]p.Event = undefined,
    head: usize = 0,
    len: usize = 0,

    fn push(r: *InputRing, ev: p.Event) void {
        if (r.len == r.buf.len) return; // a stalled page: drop new input
        r.buf[(r.head + r.len) % r.buf.len] = ev;
        r.len += 1;
    }

    fn pop(r: *InputRing) ?p.Event {
        if (r.len == 0) return null;
        const ev = r.buf[r.head];
        r.head = (r.head + 1) % r.buf.len;
        r.len -= 1;
        return ev;
    }
};

/// The page's key codes for `key` (KeyboardEvent.keyCode, which are the
/// Win16 virtual keys): the arrows, and the keys that skip a video
/// (`Sim.filterInput`; the page sends them only when that is on).
pub const Key = enum(u16) { enter = 0x0d, escape = 0x1b, space = 0x20, left = 0x25, up = 0x26, right = 0x27, down = 0x28 };

pub const Web = struct {
    sim: Sim,
    screen_buf: p.Screen = .{},
    rgba: [p.screen_width * p.screen_height * 4]u8 = undefined,
    /// The screen changed since the page last showed it.
    dirty: bool = true,
    buttons: u16 = 0,
    input: InputRing = .{},
    synth: ?midi.Synth = null,
    /// ticks() of the page clock at start (ticks count from 0, like
    /// GetTickCount after boot).
    epoch_ms: f64,

    pub fn init(w: *Web, gpa: std.mem.Allocator, skip_videos: bool) void {
        w.* = .{
            .sim = .init(gpa, std.Io.failing, .{
                .decode_video = true,
                .keep_audio = true,
                .host_files = .{ .ctx = w, .read = hostRead, .save = hostSave },
                .skip_videos = skip_videos,
            }),
            .epoch_ms = js.js_now(),
        };
        if (hostRead(w, gpa, "soundfont.sf2")) |sf2| {
            defer gpa.free(sf2);
            w.synth = midi.Synth.init(gpa, sf2, mixer.out_rate) catch |e| blk: {
                std.log.warn("bad SoundFont: {t}", .{e});
                break :blk null;
            };
        } else std.log.warn("no SoundFont: no music", .{});
        // `w` does not move from here on: the mixer points at the synth.
        if (w.synth) |*syn| w.sim.mix.synth = syn;
    }

    pub fn deinit(w: *Web) void {
        w.sim.mix.synth = null;
        if (w.synth) |*syn| syn.deinit();
        w.sim.deinit();
    }

    pub fn platform(w: *Web) p.Platform {
        return .{ .ptr = w, .vtable = &vtable };
    }

    fn hostRead(ctx: *anyopaque, gpa: std.mem.Allocator, name: []const u8) ?[]u8 {
        _ = ctx;
        const n = js.js_file_size(name.ptr, name.len);
        if (n < 0) return null;
        const bytes = gpa.alloc(u8, @intCast(n)) catch return null;
        js.js_file_read(name.ptr, name.len, bytes.ptr);
        return bytes;
    }

    fn hostSave(ctx: *anyopaque, name: []const u8, data: []const u8) void {
        _ = ctx;
        js.js_file_save(name.ptr, name.len, data.ptr, data.len);
    }

    // ---- the page's side --------------------------------------------------

    /// A mouse event from the page: `kind` 0 move, 1 down, 2 up; `button`
    /// 0 left, 2 right (MouseEvent.button); (x, y) in client pixels.
    pub fn mouse(w: *Web, kind: u8, button: u8, x: u16, y: u16) void {
        const cx = @min(x, p.client_width - 1);
        const cy = @min(y, p.client_height - 1);
        if (kind == 0) return w.input.push(.{ .input = msg.Msg.make(wm.mousemove, w.buttons, cx, cy) });
        const bit: u16 = switch (button) {
            0 => msg.mk.lbutton,
            2 => msg.mk.rbutton,
            else => return,
        };
        const down = kind == 1;
        if (down) w.buttons |= bit else w.buttons &= ~bit;
        const id: u16 = if (bit == msg.mk.lbutton)
            (if (down) wm.lbuttondown else wm.lbuttonup)
        else
            (if (down) wm.rbuttondown else wm.rbuttonup);
        w.input.push(.{ .input = msg.Msg.make(id, w.buttons, cx, cy) });
    }

    /// A key from the page (only `Key`s are passed on).
    pub fn key(w: *Web, down: bool, k: Key) void {
        w.input.push(.{ .input = .{ .id = if (down) wm.keydown else wm.keyup, .wparam = @backingInt(k) } });
    }

    /// Window focus (WM_ACTIVATE).
    pub fn focus(w: *Web, on: bool) void {
        w.input.push(.{ .activate = on });
    }

    /// The tab was closed (WM_CLOSE).
    pub fn close(w: *Web) void {
        w.input.push(.quit);
    }

    /// Converts the screen to RGBA and hands it to the page, if it changed.
    pub fn show(w: *Web) void {
        if (!w.dirty) return;
        w.dirty = false;
        var lut: [256][4]u8 = undefined;
        for (&lut, w.screen_buf.palette) |*l, c| l.* = .{ c.r, c.g, c.b, 255 };
        for (w.screen_buf.pixels, 0..) |i, k| w.rgba[k * 4 ..][0..4].* = lut[i];
        const px: *[p.screen_width * p.screen_height][4]u8 = @ptrCast(&w.rgba);
        w.screen_buf.drawOverlay([4]u8, px, p.screen_width, &lut);
        js.js_present(&w.rgba);
    }

    // ---- the platform ------------------------------------------------------

    fn self(ptr: *anyopaque) *Web {
        return @ptrCast(@alignCast(ptr));
    }

    fn ticks(ptr: *anyopaque) u32 {
        const ms = js.js_now() - self(ptr).epoch_ms;
        return @truncate(@as(u64, @intFromFloat(@max(0, ms))));
    }
    fn unixTime(_: *anyopaque) i32 {
        return @intFromFloat(@divFloor(js.js_date_now(), 1000));
    }
    fn poll(ptr: *anyopaque) ?p.Event {
        const w = self(ptr);
        if (w.sim.videoUpdate(ticks(ptr), &w.screen_buf)) w.dirty = true;
        if (w.sim.poll(ticks(ptr))) |ev| return ev;
        return w.input.pop();
    }
    /// The page's frame loop does the waiting.
    fn wait(_: *anyopaque, _: ?u32) void {}
    fn screen(ptr: *anyopaque) *p.Screen {
        return &self(ptr).screen_buf;
    }
    /// Marks the screen for the end of the frame (`show`): the game
    /// presents after every message burst, the page shows once a frame.
    fn present(ptr: *anyopaque) void {
        self(ptr).dirty = true;
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
    fn closeFile(ptr: *anyopaque, f: p.File) void {
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
    fn waveFree(ptr: *anyopaque, ses: p.MixSession, wv: p.Wave) u16 {
        return self(ptr).sim.waveFree(ses, wv);
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
        const w = self(ptr);
        return w.sim.aviPlay(ticks(ptr), dev, &w.screen_buf);
    }
    fn aviStop(ptr: *anyopaque, dev: p.Device) void {
        const w = self(ptr);
        w.sim.aviStop(dev, &w.screen_buf);
        w.dirty = true;
    }
    fn aviClose(ptr: *anyopaque, dev: p.Device) void {
        const w = self(ptr);
        w.sim.aviClose(dev, &w.screen_buf);
        w.dirty = true;
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
    fn showMain(_: *anyopaque, on: bool) void {
        js.js_show_main(on);
    }
    /// Like the SDL backend: logged, answered with the first button.
    fn messageBox(_: *anyopaque, caption: []const u8, text: []const u8, style: u16) i16 {
        std.log.warn("MessageBox [{s}] {s} (style {x})", .{ caption, text, style });
        return p.defaultButton(style);
    }

    fn filterInput(ptr: *anyopaque, m: p.Msg) ?p.Msg {
        return self(ptr).sim.filterInput(ticks(ptr), m);
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
        .close = closeFile,
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
    };
};
