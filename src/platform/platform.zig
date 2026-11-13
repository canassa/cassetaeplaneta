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

/// What the player sees: the original's client area. app_init (1018:3014)
/// creates the window 640x480 with CreateWindow style 0x80C00000
/// (WS_POPUP|WS_CAPTION), so on Windows 3.1 (VGA metrics: SM_CYCAPTION 20
/// including the caption's bottom border line, SM_CXBORDER = SM_CYBORDER = 1)
/// AdjustWindowRect leaves a client of 640-2 x 480-(20-1)-1 = 638x459. The
/// game draws into the framebuffer from the client's top-left, so the
/// framebuffer stays 640x480 and only its top-left client_width x
/// client_height part is presented (the rest was never visible).
pub const client_width = 638;
pub const client_height = 459;

/// An open file (the original's DOS handle).
pub const File = u16;
/// A wave opened through WaveMix.
pub const Wave = u16;
/// An MCI device id (AVI or waveaudio).
pub const Device = u16;

pub const Rgb = extern struct { r: u8 = 0, g: u8 = 0, b: u8 = 0 };
const BitmapInfoHeader = @import("../core/object.zig").BitmapInfoHeader;
/// A DIB colour-table entry (Win16 RGBQUAD).
pub const RgbQuad = extern struct { blue: u8 = 0, green: u8 = 0, red: u8 = 0, reserved: u8 = 0 };
/// A WaveMix session handle (WaveMixConfigureInit); 0 = failure.
pub const MixSession = u16;

/// MessageBox styles (MB_*) and results (ID*).
pub const mb = struct {
    pub const ok: u16 = 0x00;
    pub const okcancel: u16 = 0x01;
    pub const abortretryignore: u16 = 0x02;
    pub const yesnocancel: u16 = 0x03;
    pub const yesno: u16 = 0x04;
    pub const retrycancel: u16 = 0x05;
    pub const iconhand: u16 = 0x10;
    pub const iconquestion: u16 = 0x20;
    pub const iconexclamation: u16 = 0x30;
    pub const iconasterisk: u16 = 0x40;
};
pub const id = struct {
    pub const ok: i16 = 1;
    pub const cancel: i16 = 2;
    pub const abort: i16 = 3;
    pub const retry: i16 = 4;
    pub const ignore: i16 = 5;
    pub const yes: i16 = 6;
    pub const no: i16 = 7;
};

/// The answer a backend without a user gives: the box's first button.
pub fn defaultButton(style: u16) i16 {
    return switch (style & 0x0f) {
        mb.abortretryignore => id.abort,
        mb.yesnocancel, mb.yesno => id.yes,
        mb.retrycancel => id.retry,
        else => id.ok,
    };
}

/// An 8-bit DIB as WinG/GDI see it: the backdrop's WinG bitmap that text
/// is drawn into and that `wingBitBlt` copies to the screen
/// (`Backdrop.surface()` builds it). Rows are `stride()` bytes apart (the
/// DIB rule: padded to 4 bytes). `colors` is its colour table: GDI maps a
/// COLORREF to the nearest entry.
pub const Surface = struct {
    pixels: []u8,
    width: u16,
    height: u16,
    /// Row 0 of `pixels` is the bottom row (positive biHeight).
    bottom_up: bool,
    colors: *const [256]RgbQuad,

    pub fn stride(s: Surface) usize {
        return (@as(usize, s.width) + 3) & ~@as(usize, 3);
    }
};

/// Win16 PALETTEENTRY.
pub const PaletteEntry = extern struct { red: u8 = 0, green: u8 = 0, blue: u8 = 0, flags: u8 = 0 };

/// The 20 static colours of the Windows 3.1 system palette: entries 0–9
/// then 246–255 (what GetSystemPaletteEntries returns for them on a
/// 256-colour display driver).
pub const static_colors = [20]Rgb{
    .{ .r = 0, .g = 0, .b = 0 },       .{ .r = 128, .g = 0, .b = 0 },     .{ .r = 0, .g = 128, .b = 0 },
    .{ .r = 128, .g = 128, .b = 0 },   .{ .r = 0, .g = 0, .b = 128 },     .{ .r = 128, .g = 0, .b = 128 },
    .{ .r = 0, .g = 128, .b = 128 },   .{ .r = 192, .g = 192, .b = 192 }, .{ .r = 192, .g = 220, .b = 192 },
    .{ .r = 166, .g = 202, .b = 240 }, .{ .r = 255, .g = 251, .b = 240 }, .{ .r = 160, .g = 160, .b = 164 },
    .{ .r = 128, .g = 128, .b = 128 }, .{ .r = 255, .g = 0, .b = 0 },     .{ .r = 0, .g = 255, .b = 0 },
    .{ .r = 255, .g = 255, .b = 0 },   .{ .r = 0, .g = 0, .b = 255 },     .{ .r = 255, .g = 0, .b = 255 },
    .{ .r = 0, .g = 255, .b = 255 },   .{ .r = 255, .g = 255, .b = 255 },
};

/// GetSystemPaletteEntries(hdc, start, out.len, out): the static colours
/// for entries 0–9 and 246–255, black (flags 0) for the others. Returns
/// the number of entries written. Same on every backend (deterministic).
pub fn getSystemPaletteEntries(start: u16, out: []PaletteEntry) u16 {
    for (out, 0..) |*e, k| {
        const i = @as(usize, start) + k;
        const c: Rgb = if (i < 10) static_colors[i] else if (i >= 246 and i < 256) static_colors[i - 236] else .{};
        e.* = .{ .red = c.r, .green = c.g, .blue = c.b };
    }
    return @intCast(out.len);
}

/// WinGRecommendDIBFormat: fills `hdr` with WinG's preferred 8-bit format
/// — a top-down (biHeight -1), 1-pixel-wide, uncompressed DIB — and returns
/// TRUE. Every backend recommends the same format, so the backdrop is
/// always top-down (`Backdrop.dibOrientation` -1) and the objects'
/// `dibFormatOk` is 1.
pub fn wingRecommendDibFormat(hdr: *BitmapInfoHeader) bool {
    hdr.* = .{ .biWidth = 1, .biHeight = -1 };
    return true;
}

/// The DC state TextOut uses: SetTextColor, SetBkColor, SetBkMode. GDI's
/// defaults: black text on an opaque white background.
pub const TextStyle = struct {
    color: u32 = 0x000000,
    bk_color: u32 = 0xffffff,
    bk_mode: BkMode = .@"opaque",
};
pub const BkMode = enum(u16) { transparent = 1, @"opaque" = 2 };

/// MCI error codes (MCIERR_*) the platform returns.
pub const mcierr = struct {
    pub const invalid_device_id: u32 = 257;
    pub const unrecognized_command: u32 = 261;
    pub const invalid_device_name: u32 = 263;
    pub const out_of_memory: u32 = 264;
    pub const unsupported_function: u32 = 274;
    pub const file_not_found: u32 = 275;
    pub const duplicate_alias: u32 = 289;
    pub const invalid_file: u32 = 296;
};

/// mciGetErrorString: the text MMSYSTEM gives for an MCI error code
/// (English Windows wording; the Portuguese Windows 3.1 text the original
/// players saw is not known). Unknown codes get a generic text. Same on
/// every backend.
pub fn mciGetErrorString(code: u32) []const u8 {
    return switch (code) {
        mcierr.invalid_device_id => "Invalid MCI device ID. Use the ID returned when opening the MCI device.",
        mcierr.unrecognized_command => "The driver cannot recognize the specified command.",
        mcierr.invalid_device_name => "The specified device is not open or is not recognized by MCI.",
        mcierr.out_of_memory => "Your system does not have enough memory for this task. Quit one or more applications to increase available memory, and then try again.",
        mcierr.unsupported_function => "The MCI device the system is using does not support the specified command.",
        mcierr.file_not_found => "The specified file cannot be found. Make sure the path and filename are correct.",
        mcierr.duplicate_alias => "The specified alias is already being used in this application. Use a unique alias.",
        mcierr.invalid_file => "The specified file cannot be played on the specified MCI device. The file may be corrupt, or not in the correct format.",
        else => "Unknown MCI error.",
    };
}

/// WaveMix flags (WMIX_*).
pub const wmix = struct {
    // WaveMixOpenChannel / WaveMixCloseChannel
    pub const opensingle: u32 = 0;
    pub const openall: u32 = 1;
    pub const opencount: u32 = 2;
    // WaveMixFlushChannel
    pub const all: u32 = 1;
    pub const noremix: u32 = 2;
};

/// WaveMixPlay's MIXPLAYPARAMS (minus wSize).
pub const PlayParams = struct {
    session: MixSession,
    channel: i16,
    wave: Wave,
    /// hWndNotify is the main window: MM_WOM_DONE (wParam = channel) is
    /// posted when the wave ends.
    notify: bool,
    /// Play count minus one; 0xFFFF loops forever.
    loops: u16 = 0,
    /// WMIX_CLEARQUEUE: stop what the channel plays (no notification).
    clear_queue: bool = false,
    /// WMIX_USELRUCHANNEL: ignore `channel`, take the least recently used.
    use_lru_channel: bool = false,
    /// WMIX_HIPRIORITY (no effect here: the mix starts at once anyway).
    high_priority: bool = false,
};

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
        /// GDI TextOut with the system font (VGASYS.FON) into `s`; (x, y)
        /// is the top-left of the text. False when no font is available.
        textOut: *const fn (*anyopaque, s: Surface, style: TextStyle, x: i16, y: i16, text: []const u8) bool,
        /// GetTextExtent: width (lo) and height (hi) of `text` in pixels.
        textExtent: *const fn (*anyopaque, text: []const u8) u32,
        // Files (DOS paths: `\FASE2\X.WAV`, case-insensitive, rooted at the disc)
        open: *const fn (*anyopaque, path: []const u8, mode: OpenMode) ?File,
        read: *const fn (*anyopaque, f: File, buf: []u8) usize,
        write: *const fn (*anyopaque, f: File, bytes: []const u8) usize,
        /// _llseek: new position, or -1.
        seek: *const fn (*anyopaque, f: File, offset: i32, whence: Whence) i32,
        close: *const fn (*anyopaque, f: File) void,
        // WaveMix (WAVEMIX.DLL). Results are the DLL's: 0 = success, else
        // an MMSYSERR code; handles 0/null = failure.
        /// WaveMixGetInfo.
        mixGetInfo: *const fn (*anyopaque) u16,
        /// WaveMixConfigureInit (channels 1 = mono, rate in kHz).
        mixConfigureInit: *const fn (*anyopaque, channels: u16, rate_khz: u16) MixSession,
        mixOpenChannel: *const fn (*anyopaque, s: MixSession, channel: i16, flags: u32) u16,
        mixCloseChannel: *const fn (*anyopaque, s: MixSession, channel: i16, flags: u32) u16,
        mixCloseSession: *const fn (*anyopaque, s: MixSession) u16,
        mixActivate: *const fn (*anyopaque, s: MixSession, active: bool) u16,
        /// WaveMixOpenWave from a file.
        waveOpen: *const fn (*anyopaque, s: MixSession, path: []const u8) ?Wave,
        waveFree: *const fn (*anyopaque, s: MixSession, w: Wave) u16,
        wavePlay: *const fn (*anyopaque, params: PlayParams) u16,
        /// WaveMixFlushChannel (`flags` wmix.all: every channel).
        waveFlush: *const fn (*anyopaque, s: MixSession, channel: i16, flags: u32) u16,
        // MCI
        /// mciSendString for the commands the game sends ("open <f> type
        /// sequencer|waveaudio alias <a>", "play <a> [from 0] [notify]",
        /// "pause", "stop", "close"); 0 = OK, else an MCIERR code. A
        /// `notify` play posts MM_MCINOTIFY (wParam MCI_NOTIFY_SUCCESSFUL,
        /// lParam device id) when the song ends, timed from its length.
        mciString: *const fn (*anyopaque, command: []const u8) u32,
        /// MCI_OPEN of an AVI (avivideo, Autodesk FLIC) over the main window:
        /// 0 and `dev` set, or the MCI error (`mcierr`). MCI_WINDOW (show
        /// the video window) has no counterpart: it always succeeds.
        aviOpen: *const fn (*anyopaque, path: []const u8, dev: *Device) u32,
        /// MCI_PLAY with notify: frames are drawn on the screen as they fall
        /// due, then MM_MCINOTIFY(successful, device). 0 or the MCI error.
        aviPlay: *const fn (*anyopaque, dev: Device) u32,
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
        /// MessageBox(main window, text, caption, style): the button pressed.
        messageBox: *const fn (*anyopaque, caption: []const u8, text: []const u8, style: u16) i16,
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
    /// SelectPalette(hdc, hpalette) + RealizePalette(hdc) on the window DC:
    /// the screen palette becomes `colors` (the backdrop's colour table,
    /// which holds the same colours as its logical palette). Returns
    /// RealizePalette's result: the number of entries that changed.
    pub fn realizePalette(p: Platform, colors: *const [256]RgbQuad) u16 {
        const scr = p.screen();
        var n: u16 = 0;
        for (&scr.palette, colors) |*d, c| {
            const new: @TypeOf(d.*) = .{ .r = c.red, .g = c.green, .b = c.blue };
            if (d.r != new.r or d.g != new.g or d.b != new.b) n += 1;
            d.* = new;
        }
        return n;
    }
    /// WinGBitBlt(window DC, dx, dy, w, h, src's WinG DC, sx, sy): SRCCOPY
    /// of the `w`×`h` block at (sx, sy) of `src` (top-down coordinates,
    /// whatever the DIB orientation) to (dx, dy) of the screen, clipped to
    /// both. Negative sizes copy nothing.
    pub fn wingBitBlt(p: Platform, dx: i16, dy: i16, w: i16, h: i16, src: Surface, sx: i16, sy: i16) void {
        const scr = p.screen();
        const stride = src.stride();
        var row: i32 = 0;
        while (row < h) : (row += 1) {
            const y = @as(i32, dy) + row;
            const syr = @as(i32, sy) + row;
            if (y < 0 or y >= screen_height or syr < 0 or syr >= src.height) continue;
            const srow: usize = @intCast(if (src.bottom_up) @as(i32, src.height) - 1 - syr else syr);
            var col: i32 = 0;
            while (col < w) : (col += 1) {
                const x = @as(i32, dx) + col;
                const sxc = @as(i32, sx) + col;
                if (x < 0 or x >= screen_width or sxc < 0 or sxc >= src.width) continue;
                const si = srow * stride + @as(usize, @intCast(sxc));
                if (si >= src.pixels.len) continue;
                scr.pixels[@as(usize, @intCast(y)) * screen_width + @as(usize, @intCast(x))] = src.pixels[si];
            }
        }
    }
    pub fn textOut(p: Platform, s: Surface, style: TextStyle, x: i16, y: i16, text: []const u8) bool {
        return p.vtable.textOut(p.ptr, s, style, x, y, text);
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
    pub fn mixGetInfo(p: Platform) u16 {
        return p.vtable.mixGetInfo(p.ptr);
    }
    pub fn mixConfigureInit(p: Platform, channels: u16, rate_khz: u16) MixSession {
        return p.vtable.mixConfigureInit(p.ptr, channels, rate_khz);
    }
    pub fn mixOpenChannel(p: Platform, s: MixSession, channel: i16, flags: u32) u16 {
        return p.vtable.mixOpenChannel(p.ptr, s, channel, flags);
    }
    pub fn mixCloseChannel(p: Platform, s: MixSession, channel: i16, flags: u32) u16 {
        return p.vtable.mixCloseChannel(p.ptr, s, channel, flags);
    }
    pub fn mixCloseSession(p: Platform, s: MixSession) u16 {
        return p.vtable.mixCloseSession(p.ptr, s);
    }
    pub fn mixActivate(p: Platform, s: MixSession, active: bool) u16 {
        return p.vtable.mixActivate(p.ptr, s, active);
    }
    pub fn waveOpen(p: Platform, s: MixSession, path: []const u8) ?Wave {
        return p.vtable.waveOpen(p.ptr, s, path);
    }
    pub fn waveFree(p: Platform, s: MixSession, w: Wave) u16 {
        return p.vtable.waveFree(p.ptr, s, w);
    }
    pub fn wavePlay(p: Platform, params: PlayParams) u16 {
        return p.vtable.wavePlay(p.ptr, params);
    }
    pub fn waveFlush(p: Platform, s: MixSession, channel: i16, flags: u32) u16 {
        return p.vtable.waveFlush(p.ptr, s, channel, flags);
    }
    pub fn mciString(p: Platform, command: []const u8) u32 {
        return p.vtable.mciString(p.ptr, command);
    }
    pub fn aviOpen(p: Platform, path: []const u8, dev: *Device) u32 {
        return p.vtable.aviOpen(p.ptr, path, dev);
    }
    pub fn aviPlay(p: Platform, dev: Device) u32 {
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
    pub fn messageBox(p: Platform, caption: []const u8, text: []const u8, style: u16) i16 {
        return p.vtable.messageBox(p.ptr, caption, text, style);
    }
};
