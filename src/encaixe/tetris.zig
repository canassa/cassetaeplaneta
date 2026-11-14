//! Port unit `tetris` (module) of ENCAIXE.EXE. TetrisScene: its handler (keys, gravity, landing, music, WM_DESTROY and 0x40a), create (MCI, WaveMix, the score), createScreen.
//!
//! Virtual-slot dispatchers owned by this unit are declared below with
//! their final signatures; their bodies panic until the unit is ported
//! (docs/encaixe/DESIGN.md "Virtual slots"). Replace each body, keep the
//! signature (other units already call it). Each implementation function
//! carries `// @orig <1008:xxxx> <name>` with the ENCAIXE address.

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

/// SceneVtbl slot 00 handleMessage (te_scene_handle_message): non-zero = handled.
pub fn handleMessage(g: *Game, scene: *Scene, m: Msg) i16 {
    _ = g;
    _ = scene;
    _ = m;
    stub.unported("encaixe.tetris.handleMessage");
}

/// SceneVtbl slot 05 createScreen (te_scene_create_screen).
pub fn createScreen(g: *Game, scene: *Scene) ?*Backdrop {
    _ = g;
    _ = scene;
    stub.unported("encaixe.tetris.createScreen");
}

/// SceneVtbl slot 07 create (te_scene_create; hwnd dropped).
pub fn create(g: *Game, scene: *Scene) ?*Scene {
    _ = g;
    _ = scene;
    stub.unported("encaixe.tetris.create");
}
