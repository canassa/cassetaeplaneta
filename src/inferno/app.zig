//! Port unit `app` (module) of INFERNO.EXE. The WinG shell: WinMain, app_init, AppWndProc (create, destroy, activate, paint, palette, the 0x40b hello and the 0x40c posted before every message: BUGS.md H1), message loop.
//!
//! The message loop is the host's (`platform/host.zig` runs `Game.dispatchPending`
//! for the task); this unit holds start-up (`start` = WinMain + app_init +
//! CreateWindow/ShowWindow), the window procedure (`wndProc`) and the shutdown
//! (`exit`).
//!
//! No counterpart: the second-instance box, GetModuleFileName, GetModuleHandle /
//! GetProcAddress of USER's SetSystemTimer / KillSystemTimer (`g.setSystemTimer`),
//! the window class, the icon / cursor, the window position, clear_system_palette,
//! the paint's PAINTSTRUCT and DC handles. WinMain's returned exit code is an
//! uninitialised stack word (nothing reads it), so `start` returns none.
//!
//! Differences from SERIAL's: the 0x40c post is unconditional while `g_started`
//! (no `g_handshakePending`; `Fixes.inferno_ready_once` restores one "ready"),
//! the system timer is 55 ms and WM_DESTROY does not kill it, WM_PAINT plays
//! no wave.

const std = @import("std");
const msg = @import("../core/msg.zig");
const Msg = msg.Msg;
const wm = msg.wm;
const platform = @import("../platform/platform.zig");
const Game = @import("core/game.zig").Game;
const world = @import("core/world.zig");
const game_unit = @import("game.zig");
const game_input = @import("game_input.zig");
const backdrop = @import("backdrop.zig");

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

// @orig 1038:021a WinMain
// @orig 1038:0055 app_init
/// Program start: the static initialiser runs before WinMain; app_init sets
/// the window size, news the Game (`game.ctor`), CreateWindow sends WM_CREATE
/// and ShowWindow activates the window (WM_ACTIVATEAPP, WM_ACTIVATE,
/// WM_QUERYNEWPALETTE, then WM_PAINT for the invalid client area).
pub fn start(g: *Game) !void {
    game_unit.initStaticConditions(g);
    g.windowWidth = platform.screen_width;
    g.windowHeight = platform.screen_height;
    _ = game_unit.ctor(g);

    _ = g.send(.{ .id = wm.create });
    _ = g.send(.{ .id = wm.activateapp, .wparam = 1 });
    _ = g.send(.{ .id = wm.activate, .wparam = 1 });
    _ = g.send(.{ .id = wm.querynewpalette });
    g.queue.paint_pending = true;
}

// @orig 1038:017a app_exit
/// Deletes the game's objects (`game.dtor`; the host frees the Game).
pub fn exit(g: *Game) void {
    game_unit.dtor(g);
}

// @orig 1038:01b7 app_message_loop (absorbed)
// @orig 1038:02fb app_idle (absorbed)
// The PeekMessage / WaitMessage loop is the host's turn of
// `Game.dispatchPending` / `Platform.wait`; the idle hook returns 1.

// @orig 1038:0580 app_command
/// WM_COMMAND: nothing; the result is 0.
fn command(g: *Game, m: Msg) i32 {
    _ = g;
    _ = m;
    return 0;
}

// @orig 1038:0324 app_paint
/// WM_PAINT body (the palette is selected by the caller): the backdrop's
/// view to the window. Returns 1.
fn paint(g: *Game) i32 {
    if (backdropOf(g)) |bd| backdrop.blitToDc(g, bd);
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

// @orig 1038:0353 ?APPWNDPROC@@ZCJPBUHWND__@@IIJ@Z
/// The window procedure. Once `g_started` is set, every message first posts
/// 0x40c to `g_noiteWnd` (the original's `if (g_noiteWnd)` is empty: the post
/// is unconditional, BUGS.md H1; behind `inferno_ready_once` only one, once
/// NOITE's window is known), then goes to the game (`handleMessage`); a
/// handled message only gets DefWindowProc. Then WM_CREATE (onCreate, 55 ms
/// system timer 1), WM_DESTROY (quit; the timer is not killed), WM_PAINT
/// (palette, blit; no wave), WM_ACTIVATEAPP, WM_COMMAND, palette messages and
/// the 0x40b hello (stores NOITE's window). The 0x40a result is posted by the
/// scene's handler, not here.
pub fn wndProc(g: *Game, m: Msg) i32 {
    if (g.started != 0) {
        const ready: Msg = .{ .id = msg.noite.minigame_ready, .wparam = g.mainWindow };
        if (g.fixes.inferno_ready_once) {
            if (g.noiteWnd != 0 and !g.readyPosted) {
                _ = g.plat.postTo(g.noiteWnd, ready);
                g.readyPosted = true;
            }
        } else {
            _ = g.plat.postTo(g.noiteWnd, ready);
        }
        if (game_input.handleMessage(g, m) != 0) return defWindowProc(g, m);
    }
    switch (m.id) {
        wm.activateapp => g.appActive = @bitCast(m.wparam),
        wm.create => {
            _ = game_unit.onCreate(g);
            g.started = 1;
            g.setSystemTimer(1, 55);
        },
        wm.destroy => g.postQuitMessage(),
        wm.paint => {
            // BeginPaint, SelectPalette/RealizePalette, app_paint, EndPaint.
            if (backdropOf(g)) |bd| _ = realize(g, bd);
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
