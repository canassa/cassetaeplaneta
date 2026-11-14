//! Port unit `app` (module) of ENCAIXE.EXE. The WinG shell: WinMain, app_init, AppWndProc (create, destroy, activate, palette, the 0x40b hello / 0x40c ready handshake), message loop, APPABOUT.
//!
//! The message loop is the host's (`platform/host.zig` runs `Game.dispatchPending`
//! for the task; docs/encaixe/DESIGN.md "Running two programs"); this unit holds
//! what the original runs around it: start-up (`start` = WinMain + app_init +
//! CreateWindow/ShowWindow), the window procedure (`wndProc`) and the shutdown
//! (`exit`).
//!
//! No counterpart: the second-instance box, GetModuleFileName, GetModuleHandle /
//! GetProcAddress of USER's SetSystemTimer / KillSystemTimer (`g.setSystemTimer`),
//! the window class, the icon / cursor, the window position, clear_system_palette
//! (the screen starts black), the paint's PAINTSTRUCT and DC handles.

const std = @import("std");
const msg = @import("../core/msg.zig");
const Msg = msg.Msg;
const wm = msg.wm;
const platform = @import("../platform/platform.zig");
const Game = @import("core/game.zig").Game;
const world = @import("core/world.zig");
const game_unit = @import("game.zig");
const game_input = @import("game_input.zig");

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

// @orig 1008:89cc WinMain
// @orig 1008:8886 app_init
/// Program start: app_init sets the window size, news the Game (the host
/// allocates it, `game.ctor` is its constructor), CreateWindow sends
/// WM_CREATE and ShowWindow activates the window (WM_ACTIVATEAPP,
/// WM_ACTIVATE, WM_QUERYNEWPALETTE, then WM_PAINT for the invalid client
/// area), as NOITE's `app.start`.
pub fn start(g: *Game) !void {
    g.windowWidth = platform.screen_width;
    g.windowHeight = platform.screen_height;
    _ = game_unit.ctor(g);

    _ = g.send(.{ .id = wm.create });
    _ = g.send(.{ .id = wm.activateapp, .wparam = 1 });
    _ = g.send(.{ .id = wm.activate, .wparam = 1 });
    _ = g.send(.{ .id = wm.querynewpalette });
    g.queue.paint_pending = true;
}

// @orig 1008:8970 app_exit
/// Deletes the game's objects (`game_dtor`; the host frees the Game, so the
/// original's operator_delete has no counterpart).
pub fn exit(g: *Game) void {
    game_unit.dtor(g);
}

// @orig 1008:8988 app_message_loop (absorbed)
// @orig 1008:8a96 app_idle (absorbed)
// The PeekMessage / WaitMessage loop is the host's turn of
// `Game.dispatchPending` / `Platform.wait`; the idle hook returns 1 ("wait
// for a message").

// @orig 1010:0000 ?APPABOUT@@ZCHPBUHWND__@@IIJ@Z (absorbed)
// The About-box dialog procedure of the WinG skeleton: no menu reaches it.

// @orig 1008:8c84 app_command
/// WM_COMMAND: nothing (the window has no menu); the result is 0.
fn command(g: *Game, m: Msg) i32 {
    _ = g;
    _ = m;
    return 0;
}

// @orig 1008:8a9a app_paint
/// WM_PAINT body: the backdrop's palette, then its view to the window
/// (WinGBitBlt 0,0,viewWidth,viewHeight from origin). Returns 1.
fn paint(g: *Game) i32 {
    if (backdropOf(g)) |bd| {
        _ = realize(g, bd);
        g.plat.wingBitBlt(0, 0, bd.viewWidth, bd.viewHeight, bd.surface(), bd.originX, bd.originY);
    }
    return 1;
}

/// InvalidateRect(hwnd, NULL, FALSE): WM_PAINT comes when the queue is idle.
fn invalidate(g: *Game) void {
    g.queue.paint_pending = true;
}

/// DefWindowProc for what the game uses: WM_CLOSE destroys the window; the
/// rest has no visible effect here.
fn defWindowProc(g: *Game, m: Msg) i32 {
    if (m.id == wm.close) return g.send(.{ .id = wm.destroy });
    return 0;
}

// @orig 1008:8ae4 ?APPWNDPROC@@ZCJPBUHWND__@@IIJ@Z
/// The window procedure. Once `g_started` is set, the first message posts the
/// 0x40c ready to NOITE (if its 0x40b hello came and the handshake is still
/// pending), then every message goes to the game first (`handleMessage`:
/// scene handler, engine default); a handled message only gets DefWindowProc.
/// Then WM_CREATE (onCreate, 50 ms system timer 1), WM_DESTROY (kill the
/// timer, quit), WM_PAINT, WM_ACTIVATEAPP, WM_COMMAND, palette messages and
/// the 0x40b hello (stores NOITE's window).
pub fn wndProc(g: *Game, m: Msg) i32 {
    if (g.started != 0) {
        if (g.noiteWnd != 0 and g.handshakePending != 0) {
            _ = g.plat.postTo(g.noiteWnd, .{ .id = msg.noite.minigame_ready, .wparam = g.mainWindow });
            g.handshakePending = 0;
        }
        if (game_input.handleMessage(g, m) != 0) return defWindowProc(g, m);
    }
    switch (m.id) {
        wm.activateapp => g.appActive = m.wparam,
        wm.create => {
            _ = game_unit.onCreate(g);
            g.started = 1;
            g.setSystemTimer(1, 50);
        },
        wm.destroy => {
            g.killSystemTimer(1);
            g.postQuitMessage();
        },
        wm.paint => {
            // BeginPaint, SelectPalette/RealizePalette, app_paint, EndPaint.
            _ = paint(g);
            return 0;
        },
        wm.command => return command(g, m),
        wm.querynewpalette, wm.palettechanged => {
            // WM_PALETTECHANGED from our own window is ignored.
            if (m.id == wm.palettechanged and m.wparam == g.mainWindow) return defWindowProc(g, m);
            var changed: u16 = 0;
            if (backdropOf(g)) |bd| changed = realize(g, bd);
            if (changed != 0) invalidate(g);
            return changed;
        },
        msg.noite.minigame_hello => {
            g.noiteWnd = m.lo();
            return defWindowProc(g, m);
        },
        else => {},
    }
    return defWindowProc(g, m);
}
