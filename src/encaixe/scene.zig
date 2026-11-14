//! Port unit `scene` (module) of ENCAIXE.EXE. Scene methods (SceneVtbl 01-04 06 08-0C), scene_create and the destructor.
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

/// SceneVtbl slot 01 getHasPlayer.
pub fn getHasPlayer(g: *Game, scene: *Scene) bool {
    _ = g;
    _ = scene;
    stub.unported("encaixe.scene.getHasPlayer");
}

/// SceneVtbl slot 02 getHasControlPanel.
pub fn getHasControlPanel(g: *Game, scene: *Scene) bool {
    _ = g;
    _ = scene;
    stub.unported("encaixe.scene.getHasControlPanel");
}

/// SceneVtbl slot 03 getHasStatusBar.
pub fn getHasStatusBar(g: *Game, scene: *Scene) bool {
    _ = g;
    _ = scene;
    stub.unported("encaixe.scene.getHasStatusBar");
}

/// SceneVtbl slot 04 addObject.
pub fn addObject(g: *Game, scene: *Scene, obj: *Object) void {
    _ = g;
    _ = scene;
    _ = obj;
    stub.unported("encaixe.scene.addObject");
}

/// SceneVtbl slot 06 createNewScene (default only: "Faltou redefinir…").
pub fn createNewScene(g: *Game, scene: *Scene, exit_index: i16) ?*Scene {
    _ = g;
    _ = scene;
    _ = exit_index;
    stub.unported("encaixe.scene.createNewScene");
}

/// SceneVtbl slot 08 blitToDc (hdc dropped).
pub fn blitToDc(g: *Game, scene: *Scene) *Scene {
    _ = g;
    _ = scene;
    stub.unported("encaixe.scene.blitToDc");
}

/// SceneVtbl slot 09 clearView.
pub fn clearView(g: *Game, scene: *Scene) *Scene {
    _ = g;
    _ = scene;
    stub.unported("encaixe.scene.clearView");
}

/// SceneVtbl slot 0A drawBackground.
pub fn drawBackground(g: *Game, scene: *Scene) *Scene {
    _ = g;
    _ = scene;
    stub.unported("encaixe.scene.drawBackground");
}

/// SceneVtbl slot 0B addExit (scene_add_exit_at).
pub fn addExit(g: *Game, scene: *Scene, ex: *Object, player_x: i16, player_y: i16, condition: ?*Condition) i16 {
    _ = g;
    _ = scene;
    _ = ex;
    _ = player_x;
    _ = player_y;
    _ = condition;
    stub.unported("encaixe.scene.addExit");
}

/// SceneVtbl slot 0C getExit.
pub fn getExit(g: *Game, scene: *Scene, index: i16) ?*Object {
    _ = g;
    _ = scene;
    _ = index;
    stub.unported("encaixe.scene.getExit");
}
