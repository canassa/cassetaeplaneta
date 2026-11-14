//! Port unit `invasion` (module) of INV.EXE. InvScene: its handler (keys, every WM_SYSTIMER, the hit tests, the speed-up, the end, WM_DESTROY and 0x40a; BUGS.md I1, I2), create (MCI, WaveMix, the 8 waves, the score), createScreen, cannon_lose_life.
//!
//! Virtual-slot dispatchers owned by this unit are declared below with
//! their final signatures; their bodies panic until the unit is ported
//! (docs/inv/DESIGN.md "Virtual slots"). Replace each body, keep the
//! signature (other units already call it). Each implementation function
//! carries `// @orig <seg:xxxx> <name>` with the INV address.

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

/// SceneVtbl slot 00 handleMessage (inv_scene_handle_message): non-zero = handled.
pub fn handleMessage(g: *Game, scene: *Scene, m: Msg) i16 {
    _ = g;
    _ = scene;
    _ = m;
    stub.unported("inv.invasion.handleMessage");
}

/// SceneVtbl slot 05 createScreen (inv_scene_create_screen: `Espaco.bmp`).
pub fn createScreen(g: *Game, scene: *Scene) ?*Backdrop {
    _ = g;
    _ = scene;
    stub.unported("inv.invasion.createScreen");
}

/// SceneVtbl slot 07 create (inv_scene_create; hwnd dropped): MCI `doom1.mid`,
/// WaveMix, the eight waves, the score box.
pub fn create(g: *Game, scene: *Scene) ?*Scene {
    _ = g;
    _ = scene;
    stub.unported("inv.invasion.create");
}
