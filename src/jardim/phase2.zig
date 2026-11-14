//! Port unit `phase2` (module) of JARDIM.EXE. Phase2Scene (raymap2): as phase1; createNewScene builds Phase3Scene; BUGS.md J3, J6.
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
const scene = @import("scene.zig");
const labyrinth_scene = @import("labyrinth_scene.zig");

/// Phase2Scene's LabyrinthSceneVtbl (91aa): set by `labyrinth_scene.ctor(.two)`.
pub const vtbl: world.SceneVtbl = .{
    .handleMessage = handleMessage,
    .createScreen = labyrinth_scene.createScreen2,
    .createNewScene = createNewScene,
    .create = create,
    .hit = hit,
    .touch = touch,
    .placeObjects = placeObjects,
    .playEnemyAttackSound = playEnemyAttackSound,
    .playEnemyStepSound = playEnemyStepSound,
    .playFireSound = playFireSound,
    .playDoorSound = playDoorSound,
    .onLifeLost = onLifeLost,
};

/// LabyrinthSceneVtbl slot 00 handleMessage (phase2_scene_handle_message; hwnd dropped): WM_DESTROY, activation, the exit doors on SPACE, MM_WOM_DONE (the respawn), then `labyrinth_scene.handleMessage`.
pub fn handleMessage(g: *Game, s: *Scene, m: Msg) u16 {
    _ = g;
    _ = s;
    _ = m;
    stub.unported("jardim.phase2.handleMessage");
}

/// LabyrinthSceneVtbl slot 06 createNewScene (phase2_scene_create_new_scene): the Phase3Scene.
pub fn createNewScene(g: *Game, s: *Scene, exit_index: i16) ?*Scene {
    _ = g;
    _ = s;
    _ = exit_index;
    stub.unported("jardim.phase2.createNewScene");
}

/// LabyrinthSceneVtbl slot 07 create (phase2_scene_create; hwnd dropped).
pub fn create(g: *Game, s: *Scene) *Scene {
    _ = g;
    _ = s;
    stub.unported("jardim.phase2.create");
}

/// LabyrinthSceneVtbl slot 10 hit (phase2_scene_hit).
pub fn hit(g: *Game, s: *Scene, obj: ?*Object, col: i16, row: i16) void {
    _ = g;
    _ = s;
    _ = obj;
    _ = col;
    _ = row;
    stub.unported("jardim.phase2.hit");
}

/// LabyrinthSceneVtbl slot 11 touch (phase2_scene_touch).
pub fn touch(g: *Game, s: *Scene, obj: *Object) i16 {
    _ = g;
    _ = s;
    _ = obj;
    stub.unported("jardim.phase2.touch");
}

/// LabyrinthSceneVtbl slot 12 placeObjects (phase2_scene_place_objects).
pub fn placeObjects(g: *Game, s: *Scene) *Scene {
    _ = g;
    _ = s;
    stub.unported("jardim.phase2.placeObjects");
}

/// LabyrinthSceneVtbl slot 13 playEnemyAttackSound (phase2_scene_play_enemy_attack_sound).
pub fn playEnemyAttackSound(g: *Game, s: *Scene, obj: *Object) void {
    _ = g;
    _ = s;
    _ = obj;
    stub.unported("jardim.phase2.playEnemyAttackSound");
}

/// LabyrinthSceneVtbl slot 14 playEnemyStepSound (phase2_scene_play_enemy_step_sound).
pub fn playEnemyStepSound(g: *Game, s: *Scene, obj: *Object) void {
    _ = g;
    _ = s;
    _ = obj;
    stub.unported("jardim.phase2.playEnemyStepSound");
}

/// LabyrinthSceneVtbl slot 15 playFireSound (phase2_scene_play_fire_sound).
pub fn playFireSound(g: *Game, s: *Scene) void {
    _ = g;
    _ = s;
    stub.unported("jardim.phase2.playFireSound");
}

/// LabyrinthSceneVtbl slot 16 playDoorSound (phase2_scene_play_door_sound).
pub fn playDoorSound(g: *Game, s: *Scene) void {
    _ = g;
    _ = s;
    stub.unported("jardim.phase2.playDoorSound");
}

/// LabyrinthSceneVtbl slot 17 onLifeLost (phase2_scene_on_life_lost; hwnd dropped): `berro` with a notify window.
pub fn onLifeLost(g: *Game, s: *Scene) void {
    _ = g;
    _ = s;
    stub.unported("jardim.phase2.onLifeLost");
}
