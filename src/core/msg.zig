//! Window messages. The port keeps the original's message numbers, so handler
//! code compares `msg.id` against the same constants the original does.
//! `hwnd` is gone: there is one main window (`main_window`); foreign windows
//! (minigames) are `Hwnd` values handed out by the platform.

/// A Win16 window handle. Only the platform's minigame host makes others.
pub const Hwnd = u16;
pub const main_window: Hwnd = 1;

/// One window message, as the window procedure receives it.
pub const Msg = struct {
    id: u16,
    wparam: u16 = 0,
    /// The original's `lParam` (a C `long`); mouse messages pack x | y << 16.
    lparam: i32 = 0,

    pub fn lo(m: Msg) u16 {
        return @truncate(@as(u32, @bitCast(m.lparam)));
    }
    pub fn hi(m: Msg) u16 {
        return @truncate(@as(u32, @bitCast(m.lparam)) >> 16);
    }
    pub fn make(id: u16, wparam: u16, lo_word: u16, hi_word: u16) Msg {
        return .{ .id = id, .wparam = wparam, .lparam = @bitCast(@as(u32, lo_word) | @as(u32, hi_word) << 16) };
    }
};

/// Windows messages the game handles (values from the Win16 SDK).
pub const wm = struct {
    pub const create: u16 = 0x0001;
    pub const destroy: u16 = 0x0002;
    pub const activate: u16 = 0x0006;
    pub const paint: u16 = 0x000f;
    pub const close: u16 = 0x0010;
    pub const quit: u16 = 0x0012;
    pub const activateapp: u16 = 0x001c;
    pub const keydown: u16 = 0x0100;
    pub const keyup: u16 = 0x0101;
    pub const command: u16 = 0x0111;
    pub const timer: u16 = 0x0113;
    /// Undocumented; SetSystemTimer (USER ordinal 11) timers.
    pub const systimer: u16 = 0x0118;
    pub const mousemove: u16 = 0x0200;
    pub const lbuttondown: u16 = 0x0201;
    pub const lbuttonup: u16 = 0x0202;
    pub const rbuttondown: u16 = 0x0204;
    pub const rbuttonup: u16 = 0x0205;
    pub const querynewpalette: u16 = 0x030f;
    pub const palettechanged: u16 = 0x0311;
    /// MCI completion; wParam `mci_notify_successful`, lParam lo = device id.
    pub const mm_mcinotify: u16 = 0x03b9;
    /// A WaveMix wave finished (also faked by wave_play for unknown waves).
    pub const mm_wom_done: u16 = 0x03bd;
};

pub const mci_notify_successful: u16 = 1;

/// The game's private messages (ledger: "Window messages").
pub const noite = struct {
    /// Sent by every scene creator once the scene is built.
    pub const scene_started: u16 = 0x401;
    /// wParam = exit index.
    pub const exit_finished: u16 = 0x402;
    /// wParam = object id.
    pub const animation_finished: u16 = 0x403;
    /// wParam = object id.
    pub const movement_finished: u16 = 0x404;
    /// wParam = object id; posted every player movement tick.
    pub const player_stepped: u16 = 0x405;
    /// wParam = object id (INI Number); `Game.newObject` is the object.
    pub const object_created: u16 = 0x406;
    /// From a minigame: wParam = won, lParam = score.
    pub const minigame_result: u16 = 0x40a;
    /// To a minigame: lParam = main window (JARDIM: wParam = variant).
    pub const minigame_hello: u16 = 0x40b;
    /// From a minigame: it is up; the main window hides.
    pub const minigame_ready: u16 = 0x40c;
    /// Posted after an AVI ends; clears `Game.inputLocked`.
    pub const unlock_input: u16 = 0x40d;
};

/// Win16 virtual-key codes used by the engine.
pub const vk = struct {
    pub const left: u16 = 0x25;
    pub const up: u16 = 0x26;
    pub const right: u16 = 0x27;
    pub const down: u16 = 0x28;
};

/// `wParam` key-state bits of mouse messages.
pub const mk = struct {
    pub const lbutton: u16 = 0x0001;
    pub const rbutton: u16 = 0x0002;
    pub const shift: u16 = 0x0004;
    pub const control: u16 = 0x0008;
};
