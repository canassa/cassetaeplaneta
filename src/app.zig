//! Port unit `app` (module). the WinG shell: WinMain, app_init, AppWndProc (create, destroy, activate, palette, music), message loop.
//!
//! The message loop itself is `src/main.zig`'s `run` (docs/DESIGN.md
//! "Events and timing"); this unit holds what the original runs around it:
//! start-up (`start` = WinMain + app_init + CreateWindow/ShowWindow), the
//! window procedure (`wndProc`) and the shutdown (`exit`).
//!
//! No counterpart: the second-instance check, GetModuleHandle/GetProcAddress
//! of USER's SetSystemTimer/KillSystemTimer (`g.setSystemTimer`), the window
//! class, the icon/cursor, the window position and the DC handles.

const std = @import("std");
const Game = @import("core/game.zig").Game;
const msg = @import("core/msg.zig");
const Msg = msg.Msg;
const wm = msg.wm;
const cstr = @import("core/cstr.zig");
const platform = @import("platform/platform.zig");
const world = @import("core/world.zig");
const game_unit = @import("game.zig");
const game_input = @import("game_input.zig");
const backdrop = @import("backdrop.zig");
const sound = @import("sound.zig");

/// Caption of the WaveMix failure boxes (1018:36d8).
const wave_mix_caption = "Erro Wave Mix";

// @orig 1010:038c clear_system_palette
/// Realizes an all-black PC_NOCOLLAPSE palette to reset the system palette.
/// The platform's screen starts black with the static colours: nothing to do.
fn clearSystemPalette(g: *Game) void {
    _ = g;
}

// @orig 1018:31aa WinMain
// @orig 1018:3014 app_init
/// Program start: the globals the data segment and app_init set up, the
/// handler table, the game object's constructor (the `Game` is allocated by
/// `main`), then CreateWindow (sends WM_CREATE) and ShowWindow (activates
/// the window: WM_ACTIVATEAPP, WM_ACTIVATE, WM_QUERYNEWPALETTE, and a
/// WM_PAINT for the invalid client area).
pub fn start(g: *Game) !void {
    clearSystemPalette(g);
    g.windowWidth = platform.screen_width;
    g.windowHeight = platform.screen_height;
    game_unit.registerSceneHandlers(g);
    _ = game_unit.ctor(g);

    _ = g.send(.{ .id = wm.create });
    _ = g.send(.{ .id = wm.activateapp, .wparam = 1 });
    _ = g.send(.{ .id = wm.activate, .wparam = 1 });
    _ = g.send(.{ .id = wm.querynewpalette });
    g.queue.paint_pending = true;
}

// @orig 1018:312e app_exit
/// Destroys the game's objects (the original also frees the Game; here
/// `main` does, so the flags of the scalar destructor are 0).
pub fn exit(g: *Game) void {
    _ = game_unit.scalarDtor(g, 0);
}

// @orig 1018:315c app_message_loop (absorbed)
// @orig 1018:3274 app_idle (absorbed)
// The PeekMessage/WaitMessage loop is `main.run`; the idle hook returns 1
// ("wait for a message"), which is `Platform.wait`.

// @orig 1018:3638 app_command
/// WM_COMMAND: nothing (the window has no menu); the result is 0.
fn command(g: *Game, m: Msg) i32 {
    _ = g;
    _ = m;
    return 0;
}

/// The current scene's backdrop (the original reads `scene->backdrop`).
fn backdropOf(g: *Game) ?*world.Backdrop {
    const s = g.scene orelse return null;
    return s.backdrop;
}

/// SelectPalette + RealizePalette on the window DC; the number of palette
/// entries that changed (RealizePalette's result).
fn realize(g: *Game, bd: *const world.Backdrop) u16 {
    return g.plat.realizePalette(&bd.bmiColors);
}

/// InvalidateRect(hwnd, NULL, FALSE): WM_PAINT comes when the queue is idle.
fn invalidate(g: *Game) void {
    g.queue.paint_pending = true;
}

// @orig 1018:3280 app_paint
/// WM_PAINT body: the backdrop's view to the window, or BLACKNESS over
/// 640x480 without a scene. Returns 1.
fn paint(g: *Game) i32 {
    if (backdropOf(g)) |bd| {
        backdrop.blitToDc(g, bd);
        return 1;
    }
    @memset(&g.plat.screen().pixels, 0);
    return 1;
}

/// DefWindowProc for what the game uses: WM_CLOSE destroys the window; the
/// rest has no visible effect here.
fn defWindowProc(g: *Game, m: Msg) i32 {
    if (m.id == wm.close) return g.send(.{ .id = wm.destroy });
    return 0;
}

/// Reports a MessageBox with the WaveMix caption (MB_ICONEXCLAMATION).
fn waveMixBox(g: *Game, text: []const u8) void {
    _ = g.plat.messageBox(wave_mix_caption, text, platform.mb.iconexclamation);
}

// @orig 1018:32d6 ?APPWNDPROC@@ZCJIIIJ@Z
/// The window procedure. Once the game exists (or for 0x406, sent while the
/// game is being created) every message goes to the game first (scene
/// handler, hook, engine default); a handled message still gets
/// DefWindowProc. Then create/destroy, activation, palette, paint, the
/// music's MCI loop. A null scene is treated as a null backdrop (the
/// original would read through the null pointer).
pub fn wndProc(g: *Game, m: Msg) i32 {
    if (g.appInitialized != 0 or m.id == msg.noite.object_created) {
        if (game_input.handleMessage(g, m) != 0) return defWindowProc(g, m);
    }
    switch (m.id) {
        wm.create => {
            if (sound.mixInit(g) != 0) waveMixBox(g, "N\xe3o consegue inicializar");
            g.setSystemTimer(1, 50);
            _ = game_unit.onCreate(g);
            g.appInitialized = 1;
        },
        wm.destroy => {
            sound.freeAll(&g.sound, g.plat);
            sound.mixClose(&g.sound, g.plat);
            _ = g.plat.mciString("close musica");
            g.killSystemTimer(1);
            g.postQuitMessage();
        },
        wm.activate => {
            const active = m.wparam != 0 and m.hi() == 0;
            if (active) {
                var changed: u16 = 0;
                if (backdropOf(g)) |bd| changed = realize(g, bd);
                if (changed != 0) invalidate(g);
                if (g.ini.rec.isAvi != 0) return defWindowProc(g, m);
                g.musicMciResult = g.plat.mciString("play musica notify");
                if (sound.mixActivate(&g.sound, g.plat) == 0) waveMixBox(g, "N\xe3o consegue ativar");
            } else {
                if (g.ini.rec.isAvi != 0) return defWindowProc(g, m);
                g.musicMciResult = g.plat.mciString("pause musica");
                if (sound.mixDeactivate(&g.sound, g.plat) == 0) waveMixBox(g, "N\xe3o consegue desativar");
            }
        },
        wm.paint => {
            if (backdropOf(g)) |bd| _ = realize(g, bd);
            _ = paint(g);
            return 0;
        },
        wm.activateapp => g.appActive = m.wparam,
        wm.command => return command(g, m),
        wm.querynewpalette, wm.palettechanged => {
            // WM_PALETTECHANGED from our own window is ignored.
            if (m.id == wm.palettechanged and m.wparam == msg.main_window) return defWindowProc(g, m);
            var changed: u16 = 0;
            if (backdropOf(g)) |bd| changed = realize(g, bd);
            if (changed != 0) invalidate(g);
            return changed;
        },
        wm.mm_mcinotify => if (m.wparam == msg.mci_notify_successful) {
            // The song ended: play it again.
            g.musicMciResult = g.plat.mciString("play musica from 0 notify");
            if (g.musicMciResult != 0) {
                // Caption string at 1010:d796.
                _ = g.plat.messageBox("MCI Erro", platform.mciGetErrorString(g.musicMciResult), platform.mb.iconexclamation);
                g.musicMciResult = 0;
            }
        },
        else => {},
    }
    return defWindowProc(g, m);
}
