//! Port unit `gallery` (module) of TIRO.EXE. TiroScene: its handler (keys, the target and arrow timers, the second hit stage, the end test, WM_DESTROY and 0x40a; BUGS.md T1-T5), create (MCI, WaveMix, the score), createScreen.
//!
//! Virtual-slot dispatchers owned by this unit are declared below with
//! their final signatures; their bodies panic until the unit is ported
//! (docs/tiro/DESIGN.md "Virtual slots"). Replace each body, keep the
//! signature (other units already call it). Each implementation function
//! carries `// @orig <seg:xxxx> <name>` with the TIRO address.

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

/// SceneVtbl slot 00 handleMessage (tiro_scene_handle_message): non-zero = handled.
pub fn handleMessage(g: *Game, scene: *Scene, m: Msg) i16 {
    _ = g;
    _ = scene;
    _ = m;
    stub.unported("tiro.gallery.handleMessage");
}

/// SceneVtbl slot 05 createScreen (tiro_scene_create_screen).
pub fn createScreen(g: *Game, scene: *Scene) ?*Backdrop {
    _ = g;
    _ = scene;
    stub.unported("tiro.gallery.createScreen");
}

/// SceneVtbl slot 07 create (tiro_scene_create; hwnd dropped).
pub fn create(g: *Game, scene: *Scene) ?*Scene {
    _ = g;
    _ = scene;
    stub.unported("tiro.gallery.create");
}
