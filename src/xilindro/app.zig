//! Port unit `app` (module) of XILINDRO.EXE. The WinG shell: WinMain, app_init, AppWndProc (create: on_create and the 50 ms timer 1; destroy, activate, 0x40b hello / 0x40c ready), message loop.
//!
//! Virtual-slot dispatchers owned by this unit are declared below with
//! their final signatures; their bodies panic until the unit is ported
//! (docs/xilindro/DESIGN.md "Virtual slots"). Replace each body, keep the
//! signature (other units already call it). Each implementation function
//! carries `// @orig <seg:xxxx> <name>` with the XILINDRO address.

const std = @import("std");
const stub = @import("../core/stub.zig");
const msg = @import("../core/msg.zig");
const Msg = msg.Msg;
const Game = @import("core/game.zig").Game;
const object = @import("core/object.zig");
const Object = object.Object;
const ObjectList = object.ObjectList;
const Frame = object.Frame;
const FrameCell = object.FrameCell;
const BitmapInfoHeader = object.BitmapInfoHeader;
const world = @import("core/world.zig");
const Backdrop = world.Backdrop;
const Scene = world.Scene;
const Condition = world.Condition;
const RectQuery = world.RectQuery;

/// WinMain + app_init up to the message loop (CreateWindow sends WM_CREATE; then the activation messages, as NOITE's `app.start`).
pub fn start(g: *Game) !void {
    _ = g;
    stub.unported("xilindro.app.start");
}

/// app_exit: deletes the game's objects (the host frees the Game).
pub fn exit(g: *Game) void {
    _ = g;
    stub.unported("xilindro.app.exit");
}

/// The window procedure (?APPWNDPROC).
pub fn wndProc(g: *Game, m: Msg) i32 {
    _ = g;
    _ = m;
    stub.unported("xilindro.app.wndProc");
}
