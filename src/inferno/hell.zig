//! Port unit `hell` (module) of INFERNO.EXE. InfernoScene: its handler (the
//! 3-minute clock, keys, the 5 timer tests, WM_DESTROY, WM_CLOSE and the
//! 0x40a reports: BUGS.md H2, H4), create (MCI, WaveMix, the score box),
//! createScreen.
//!
//! Virtual-slot dispatchers owned by this unit are declared below with
//! their final signatures; their bodies panic until the unit is ported
//! (docs/inferno/DESIGN.md "Virtual slots"). Replace each body, keep the
//! signature (other units already call it). Each implementation function
//! carries `// @orig <seg:xxxx> <name>` with the INFERNO address.

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

/// SceneVtbl slot 00 handleMessage (inferno_scene_handle_message): non-zero =
/// handled.
pub fn handleMessage(g: *Game, scene: *Scene, m: Msg) i16 {
    _ = g;
    _ = scene;
    _ = m;
    stub.unported("inferno.hell.handleMessage");
}

/// SceneVtbl slot 05 createScreen (inferno_scene_create_screen).
pub fn createScreen(g: *Game, scene: *Scene) ?*Backdrop {
    _ = g;
    _ = scene;
    stub.unported("inferno.hell.createScreen");
}

/// SceneVtbl slot 07 create (inferno_scene_create; hwnd dropped).
pub fn create(g: *Game, scene: *Scene) ?*Scene {
    _ = g;
    _ = scene;
    stub.unported("inferno.hell.create");
}
