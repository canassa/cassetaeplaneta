//! Port unit `scene` (module) of JARDIM.EXE. Scene methods (SceneVtbl 01-04 06 08-0F), ctor, scene_create, the destructor, exits and their links.
//!
//! Virtual-slot dispatchers owned by this unit are declared below with
//! their final signatures; their bodies panic until the unit is ported
//! (docs/jardim/DESIGN.md "Virtual slots"). Replace each body, keep the
//! signature (other units already call it). Each implementation function
//! carries `// @orig <seg:xxxx> <name>` with the JARDIM address.

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

/// SceneVtbl slot 01 getHasPlayer.
pub fn getHasPlayer(g: *Game, scene: *Scene) bool {
    _ = g;
    _ = scene;
    stub.unported("jardim.scene.getHasPlayer");
}

/// SceneVtbl slot 02 getHasControlPanel.
pub fn getHasControlPanel(g: *Game, scene: *Scene) bool {
    _ = g;
    _ = scene;
    stub.unported("jardim.scene.getHasControlPanel");
}

/// SceneVtbl slot 03 getHasStatusBar.
pub fn getHasStatusBar(g: *Game, scene: *Scene) bool {
    _ = g;
    _ = scene;
    stub.unported("jardim.scene.getHasStatusBar");
}

/// SceneVtbl slot 04 addObject.
pub fn addObject(g: *Game, scene: *Scene, obj: *Object) void {
    _ = g;
    _ = scene;
    _ = obj;
    stub.unported("jardim.scene.addObject");
}

/// SceneVtbl slot 06 createNewScene's default (scene_create_new_scene_default, absorbed: "Faltou redefinir…"), which the phases call first.
pub fn createNewSceneDefault(g: *Game, scene: *Scene, exit_index: i16) ?*Scene {
    _ = g;
    _ = scene;
    _ = exit_index;
    stub.unported("jardim.scene.createNewSceneDefault");
}

/// SceneVtbl slot 07 create (scene_create: the base, which labyrinth_scene_create calls).
pub fn create(g: *Game, scene: *Scene) *Scene {
    _ = g;
    _ = scene;
    stub.unported("jardim.scene.create");
}

/// SceneVtbl slot 08 blitToDc (hdc dropped).
pub fn blitToDc(g: *Game, scene: *Scene) *Scene {
    _ = g;
    _ = scene;
    stub.unported("jardim.scene.blitToDc");
}

/// SceneVtbl slot 09 clearView.
pub fn clearView(g: *Game, scene: *Scene) *Scene {
    _ = g;
    _ = scene;
    stub.unported("jardim.scene.clearView");
}

/// SceneVtbl slot 0A drawBackground.
pub fn drawBackground(g: *Game, scene: *Scene) *Scene {
    _ = g;
    _ = scene;
    stub.unported("jardim.scene.drawBackground");
}

/// SceneVtbl slot 0B addExit (scene_add_exit).
pub fn addExit(g: *Game, scene: *Scene, ex: *Object) i16 {
    _ = g;
    _ = scene;
    _ = ex;
    stub.unported("jardim.scene.addExit");
}

/// SceneVtbl slot 0C addExitToScene (scene_add_exit_to_scene).
pub fn addExitToScene(g: *Game, scene: *Scene, ex: *Object, scene_name: []const u8, player_x: i16, player_y: i16, condition: ?*Condition) i16 {
    _ = g;
    _ = scene;
    _ = ex;
    _ = scene_name;
    _ = player_x;
    _ = player_y;
    _ = condition;
    stub.unported("jardim.scene.addExitToScene");
}

/// SceneVtbl slot 0D addExitAt (scene_add_exit_at: the phases' Exit).
pub fn addExitAt(g: *Game, scene: *Scene, ex: *Object, player_x: i16, player_y: i16, condition: ?*Condition) i16 {
    _ = g;
    _ = scene;
    _ = ex;
    _ = player_x;
    _ = player_y;
    _ = condition;
    stub.unported("jardim.scene.addExitAt");
}

/// SceneVtbl slot 0E addExitAlt (scene_add_exit_alt).
pub fn addExitAlt(g: *Game, scene: *Scene, ex: *Object, alt_scene_name: []const u8, alt_x: i16, alt_y: i16) i16 {
    _ = g;
    _ = scene;
    _ = ex;
    _ = alt_scene_name;
    _ = alt_x;
    _ = alt_y;
    stub.unported("jardim.scene.addExitAlt");
}

/// SceneVtbl slot 0F getExit.
pub fn getExit(g: *Game, scene: *Scene, index: i16) ?*Object {
    _ = g;
    _ = scene;
    _ = index;
    stub.unported("jardim.scene.getExit");
}
