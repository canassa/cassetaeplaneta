//! The platform layer: everything the original got from Windows, WinG, GDI,
//! WaveMix, MCI and DOS. Game code reaches the OS only through `Platform`
//! (docs/DESIGN.md "Platform layer"). Two backends: `headless` (virtual
//! clock, scripted input; tests and trace runs) and `sdl` (SDL3 window).
//!
//! Notifications the OS would post to the game window (MM_WOM_DONE,
//! MM_MCINOTIFY, a minigame's 0x40a/0x40c) come back from `poll` as
//! `.message` events at the virtual time they happen, so both backends
//! produce the same event order for the same input.

const std = @import("std");
const msg = @import("../core/msg.zig");
pub const Msg = msg.Msg;
pub const Hwnd = msg.Hwnd;

pub const screen_width = 640;
pub const screen_height = 480;

/// An open file (the original's DOS handle).
pub const File = u16;
/// A wave opened through WaveMix.
pub const Wave = u16;
/// An MCI device id (AVI or waveaudio).
pub const Device = u16;

pub const Rgb = extern struct { r: u8 = 0, g: u8 = 0, b: u8 = 0 };

/// The window's client area: what the original's GetDC + WinGBitBlt paint
/// on. 8-bit palettized; the palette is the realized logical palette.
pub const Screen = struct {
    pixels: [screen_width * screen_height]u8 = @splat(0),
    palette: [256]Rgb = @splat(.{}),
};

pub const Event = union(enum) {
    /// The user closed the window.
    quit,
    /// Mouse or keyboard input (WM_MOUSEMOVE, WM_LBUTTONDOWN, WM_KEYDOWN…).
    input: Msg,
    /// WM_ACTIVATE: the window gained (true) or lost focus.
    activate: bool,
    /// A message the OS posts to the main window.
    message: Msg,
};

pub const OpenMode = enum { read, write, read_write, create };
pub const Whence = enum(u2) { set = 0, cur = 1, end = 2 };

pub const Platform = struct {
    ptr: *anyopaque,
    vtable: *const VTable,

    pub const VTable = struct {
        // Clock
        /// Milliseconds since start (GetTickCount / timer base).
        ticks: *const fn (*anyopaque) u32,
        /// Seconds since 1970 (CRT time(); seeds random_below).
        unixTime: *const fn (*anyopaque) i32,
        // Events
        poll: *const fn (*anyopaque) ?Event,
        /// Block until `deadline` (ticks) or the next event; null = no deadline.
        wait: *const fn (*anyopaque, deadline: ?u32) void,
        // Video
        screen: *const fn (*anyopaque) *Screen,
        /// Show `screen` (after the palette or pixels changed).
        present: *const fn (*anyopaque) void,
        /// GDI TextOut with the system font, transparent background.
        textOut: *const fn (*anyopaque, x: i16, y: i16, color: u32, text: []const u8) void,
        /// GetTextExtent: width (lo) and height (hi) of `text` in pixels.
        textExtent: *const fn (*anyopaque, text: []const u8) u32,
        // Files (DOS paths: `\FASE2\X.WAV`, case-insensitive, rooted at the disc)
        open: *const fn (*anyopaque, path: []const u8, mode: OpenMode) ?File,
        read: *const fn (*anyopaque, f: File, buf: []u8) usize,
        write: *const fn (*anyopaque, f: File, bytes: []const u8) usize,
        /// _llseek: new position, or -1.
        seek: *const fn (*anyopaque, f: File, offset: i32, whence: Whence) i32,
        close: *const fn (*anyopaque, f: File) void,
        // WaveMix (22 kHz mono, 8 channels)
        waveOpen: *const fn (*anyopaque, path: []const u8) ?Wave,
        waveFree: *const fn (*anyopaque, w: Wave) void,
        /// Play on `channel`; posts MM_WOM_DONE when done. `loops` -1 = forever.
        wavePlay: *const fn (*anyopaque, channel: u8, w: Wave, loops: i16) bool,
        waveFlush: *const fn (*anyopaque, channel: u8) void,
        mixActivate: *const fn (*anyopaque, active: bool) bool,
        // MCI
        /// mciSendString for the commands the game sends ("open … alias
        /// musica", "play musica notify", "pause musica", "close …"); 0 = OK.
        /// `notify` completions arrive as MM_MCINOTIFY messages.
        mciString: *const fn (*anyopaque, command: []const u8) u32,
        /// MCI_OPEN of an AVI (avivideo) over the main window.
        aviOpen: *const fn (*anyopaque, path: []const u8) ?Device,
        /// MCI_PLAY with notify: MM_MCINOTIFY(successful, device) at the end.
        aviPlay: *const fn (*anyopaque, dev: Device) bool,
        aviStop: *const fn (*anyopaque, dev: Device) void,
        aviClose: *const fn (*anyopaque, dev: Device) void,
        // Other programs (the minigames)
        /// WinExec; ≥ 32 on success, like Win16.
        winExec: *const fn (*anyopaque, command: []const u8) u16,
        findWindow: *const fn (*anyopaque, title: []const u8) ?Hwnd,
        /// PostMessage to another program's window.
        postTo: *const fn (*anyopaque, hwnd: Hwnd, m: Msg) bool,
        /// ShowWindow(main window, SW_SHOW / SW_HIDE).
        showMain: *const fn (*anyopaque, show: bool) void,
        // UI
        messageBox: *const fn (*anyopaque, caption: []const u8, text: []const u8) void,
    };

    pub fn ticks(p: Platform) u32 {
        return p.vtable.ticks(p.ptr);
    }
    pub fn unixTime(p: Platform) i32 {
        return p.vtable.unixTime(p.ptr);
    }
    pub fn poll(p: Platform) ?Event {
        return p.vtable.poll(p.ptr);
    }
    pub fn wait(p: Platform, deadline: ?u32) void {
        p.vtable.wait(p.ptr, deadline);
    }
    pub fn screen(p: Platform) *Screen {
        return p.vtable.screen(p.ptr);
    }
    pub fn present(p: Platform) void {
        p.vtable.present(p.ptr);
    }
    pub fn textOut(p: Platform, x: i16, y: i16, color: u32, text: []const u8) void {
        p.vtable.textOut(p.ptr, x, y, color, text);
    }
    pub fn textExtent(p: Platform, text: []const u8) u32 {
        return p.vtable.textExtent(p.ptr, text);
    }
    pub fn open(p: Platform, path: []const u8, mode: OpenMode) ?File {
        return p.vtable.open(p.ptr, path, mode);
    }
    pub fn read(p: Platform, f: File, buf: []u8) usize {
        return p.vtable.read(p.ptr, f, buf);
    }
    pub fn write(p: Platform, f: File, bytes: []const u8) usize {
        return p.vtable.write(p.ptr, f, bytes);
    }
    pub fn seek(p: Platform, f: File, offset: i32, whence: Whence) i32 {
        return p.vtable.seek(p.ptr, f, offset, whence);
    }
    pub fn close(p: Platform, f: File) void {
        p.vtable.close(p.ptr, f);
    }
    pub fn waveOpen(p: Platform, path: []const u8) ?Wave {
        return p.vtable.waveOpen(p.ptr, path);
    }
    pub fn waveFree(p: Platform, w: Wave) void {
        p.vtable.waveFree(p.ptr, w);
    }
    pub fn wavePlay(p: Platform, channel: u8, w: Wave, loops: i16) bool {
        return p.vtable.wavePlay(p.ptr, channel, w, loops);
    }
    pub fn waveFlush(p: Platform, channel: u8) void {
        p.vtable.waveFlush(p.ptr, channel);
    }
    pub fn mixActivate(p: Platform, active: bool) bool {
        return p.vtable.mixActivate(p.ptr, active);
    }
    pub fn mciString(p: Platform, command: []const u8) u32 {
        return p.vtable.mciString(p.ptr, command);
    }
    pub fn aviOpen(p: Platform, path: []const u8) ?Device {
        return p.vtable.aviOpen(p.ptr, path);
    }
    pub fn aviPlay(p: Platform, dev: Device) bool {
        return p.vtable.aviPlay(p.ptr, dev);
    }
    pub fn aviStop(p: Platform, dev: Device) void {
        p.vtable.aviStop(p.ptr, dev);
    }
    pub fn aviClose(p: Platform, dev: Device) void {
        p.vtable.aviClose(p.ptr, dev);
    }
    pub fn winExec(p: Platform, command: []const u8) u16 {
        return p.vtable.winExec(p.ptr, command);
    }
    pub fn findWindow(p: Platform, title: []const u8) ?Hwnd {
        return p.vtable.findWindow(p.ptr, title);
    }
    pub fn postTo(p: Platform, hwnd: Hwnd, m: Msg) bool {
        return p.vtable.postTo(p.ptr, hwnd, m);
    }
    pub fn showMain(p: Platform, show: bool) void {
        p.vtable.showMain(p.ptr, show);
    }
    pub fn messageBox(p: Platform, caption: []const u8, text: []const u8) void {
        p.vtable.messageBox(p.ptr, caption, text);
    }
};
