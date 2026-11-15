//! Port unit `app` (module) of JARDIM.EXE. The WinG shell: WinMain, app_init, AppWndProc (the 0x40c re-posting until NOITE's 0x40a, the 0x40b hello and variant, timer 10; BUGS.md J7), message loop, paint.
//!
//! The message loop is the host's (`platform/host.zig` runs `Game.dispatchPending`
//! for the task); this unit holds what the original runs around it: start-up
//! (`start` = WinMain + app_init + CreateWindow/ShowWindow), the window procedure
//! (`wndProc`) and the shutdown (`exit`).
//!
//! No counterpart: the second-instance box, GetModuleFileName, GetModuleHandle /
//! GetProcAddress of USER's SetSystemTimer / KillSystemTimer (`g.setSystemTimer`),
//! the window class, the icon / cursor, the window position, clear_system_palette
//! (the screen starts black), the paint's PAINTSTRUCT and DC handles, the About
//! box. WinMain returns an uninitialised stack word after a normal run: nothing
//! reads it, so `start` returns no code.
//!
//! Differences from SAUNA's / INFERNO's: before anything else, while `g_noiteWnd`
//! is 0 every message FindWindow's NOITE and posts 0x40c to it, and until NOITE's
//! 0x40a ack (`g_noiteAcked`) every message posts it again; the 0x40b hello would
//! store the variant and post 0x40c, but once WM_CREATE has run the game's handler
//! takes 0x40b and 0x40a first and answers 1, so neither case runs (BUGS.md J7: the
//! variant stays 0, the ack is never seen); the system timer is id 10 at 50 ms
//! (killed in WM_DESTROY) and its WM_SYSTIMER retries the FindWindow. WM_PAINT
//! plays no wave.

const std = @import("std");
const msg = @import("../core/msg.zig");
const Msg = msg.Msg;
const wm = msg.wm;
const Game = @import("core/game.zig").Game;
const world = @import("core/world.zig");
const game_unit = @import("game.zig");
const game_input = @import("game_input.zig");
const backdrop = @import("backdrop.zig");

/// The window title FindWindow looks for (task 0's, DGROUP 10d0:0062/006f/007c/0089).
const noite_title = "Noite Animal";

/// The timer WM_CREATE starts (SetSystemTimer id, period).
const timer_id: u16 = 10;
const timer_ms: u16 = 50;

/// The current scene's backdrop (the original reads `g_game->scene->backdrop`
/// unchecked; a null scene is treated as a null backdrop).
fn backdropOf(g: *Game) ?*world.Backdrop {
    const s = g.scene orelse return null;
    return s.backdrop;
}

/// SelectPalette + RealizePalette on the window DC; the number of palette
/// entries that changed.
fn realize(g: *Game, bd: *const world.Backdrop) u16 {
    return g.plat.realizePalette(&bd.bmiColors);
}

/// PostMessage(g_noiteWnd, 0x40c, hwnd, 0): the "ready".
fn postReady(g: *Game) void {
    _ = g.plat.postTo(g.noiteWnd, .{ .id = msg.noite.minigame_ready, .wparam = g.mainWindow });
}

/// FindWindow("Noite Animal"): stores the window in `g_noiteWnd` and, when found,
/// posts the 0x40c to it. J7 (`jardim_variant_hello`): the FindWindow result is
/// not used at all, so NOITE hears nothing from JARDIM before its own 0x40b hello
/// (espquete takes the first 0x40c for the reply and never sends the hello), and
/// `wndProc` lets the hello and the ack reach their cases.
fn findNoite(g: *Game) void {
    if (g.fixes.jardim_variant_hello) return;
    g.noiteWnd = g.plat.findWindow(noite_title) orelse 0;
    if (g.noiteWnd != 0) postReady(g);
}

// @orig 1020:021a WinMain
// @orig 1020:0055 app_init
/// Program start: the static initialiser runs before WinMain; app_init news the
/// Game (`game.ctor`), CreateWindow sends WM_CREATE and ShowWindow activates the
/// window (WM_ACTIVATEAPP, WM_ACTIVATE, WM_QUERYNEWPALETTE, then WM_PAINT for the
/// invalid client area), as NOITE's `app.start`.
pub fn start(g: *Game) !void {
    game_unit.initStaticConditions(g);
    _ = game_unit.ctor(g);

    _ = g.send(.{ .id = wm.create });
    _ = g.send(.{ .id = wm.activateapp, .wparam = 1 });
    _ = g.send(.{ .id = wm.activate, .wparam = 1 });
    _ = g.send(.{ .id = wm.querynewpalette });
    g.queue.paint_pending = true;
}

// @orig 1020:017a app_exit
/// Deletes the game's objects (`game_scalar_dtor`, flags 1; the host frees the Game).
pub fn exit(g: *Game) void {
    _ = game_unit.scalarDtor(g, 1);
}

// @orig 1020:01b7 app_message_loop (absorbed)
// @orig 1020:02fb app_idle (absorbed)
// The PeekMessage / WaitMessage loop is the host's turn of
// `Game.dispatchPending` / `Platform.wait`; the idle hook returns 1.

// @orig 1020:0625 app_command
/// WM_COMMAND: nothing (the window has no menu); the result is 0.
fn command(g: *Game, m: Msg) i32 {
    _ = g;
    _ = m;
    return 0;
}

// @orig 1020:0324 app_paint
/// WM_PAINT body (the palette is selected by the caller): the backdrop's view to
/// the window. Returns 1.
fn paint(g: *Game) i32 {
    if (backdropOf(g)) |bd| backdrop.blitToDc(g, bd);
    return 1;
}

/// InvalidateRect(hwnd, NULL, FALSE): WM_PAINT comes when the queue is idle.
fn invalidate(g: *Game) void {
    g.queue.paint_pending = true;
}

/// DefWindowProc for what the game uses: WM_CLOSE destroys the window; the rest
/// has no visible effect here.
fn defWindowProc(g: *Game, m: Msg) i32 {
    if (m.id == wm.close) return g.send(.{ .id = wm.destroy });
    return 0;
}

// @orig 1020:0000 APPABOUT (absorbed)
// The About-box procedure (WM_INITDIALOG -> 1, OK -> EndDialog) is never
// referenced: there is no About menu.

// @orig 1020:0353 APPWNDPROC
/// The window procedure. First, while `g_noiteWnd` is 0: FindWindow("Noite
/// Animal") and, if found, 0x40c to it; else, until NOITE's 0x40a, 0x40c to
/// `g_noiteWnd` on every message (J7: the FindWindow is not used, see
/// `findNoite`). Once `g_started` the message goes to the game (`handleMessage`);
/// a handled message only gets DefWindowProc. Then WM_CREATE (onCreate, timer 10
/// at 50 ms), WM_DESTROY (kill the timer, quit), WM_PAINT (palette, blit),
/// WM_ACTIVATEAPP, WM_COMMAND, the palette messages, WM_SYSTIMER (FindWindow
/// retry), 0x40a (ack) and 0x40b (hello: NOITE's window and the variant, then
/// 0x40c). The 0x40a result is posted by the scene's handler, not here.
pub fn wndProc(g: *Game, m: Msg) i32 {
    if (g.noiteWnd == 0) {
        findNoite(g);
    } else if (g.noiteAcked == 0) {
        postReady(g);
    }
    // Once started every message goes to game_handle_message first, whose scene answers 1
    // for 0x40b and 0x40a: their cases below never run in the original (BUGS.md J7). The
    // fix lets NOITE's hello and ack through.
    const handshake = m.id == msg.noite.minigame_hello or m.id == msg.noite.minigame_result;
    if (g.started != 0 and !(g.fixes.jardim_variant_hello and handshake)) {
        if (game_input.handleMessage(g, m) != 0) return defWindowProc(g, m);
    }
    switch (m.id) {
        wm.command => return command(g, m),
        wm.create => {
            _ = game_unit.onCreate(g);
            g.started = 1;
            g.setSystemTimer(timer_id, timer_ms);
        },
        wm.destroy => {
            g.killSystemTimer(timer_id);
            g.postQuitMessage();
        },
        wm.paint => {
            // BeginPaint, SelectPalette/RealizePalette (the backdrop's palette),
            // app_paint, EndPaint.
            if (backdropOf(g)) |bd| _ = realize(g, bd);
            _ = paint(g);
            return 0;
        },
        wm.activateapp => g.appActive = @bitCast(m.wparam),
        wm.querynewpalette, wm.palettechanged => {
            // WM_PALETTECHANGED from our own window is ignored.
            if (m.id == wm.palettechanged and m.wparam == g.mainWindow) return defWindowProc(g, m);
            var changed: u16 = 0;
            if (backdropOf(g)) |bd| changed = realize(g, bd);
            if (changed != 0) invalidate(g);
            return changed;
        },
        wm.systimer => {
            if (g.noiteWnd == 0) findNoite(g);
        },
        msg.noite.minigame_result => g.noiteAcked = 1,
        msg.noite.minigame_hello => {
            g.noiteWnd = m.lo();
            g.variant = @bitCast(m.wparam);
            postReady(g);
        },
        else => {},
    }
    return defWindowProc(g, m);
}
