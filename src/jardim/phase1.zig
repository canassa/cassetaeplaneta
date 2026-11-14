//! Port unit `phase1` (module) of JARDIM.EXE. Phase1Scene (raymap1): create (objects, MCI music, WaveMix), placeObjects, touch, hit, the sounds, onLifeLost, its handler (exit doors, the scream's end), createNewScene (Phase2Scene); BUGS.md J3, J6.
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

/// Phase1Scene's LabyrinthSceneVtbl (834c): set by `labyrinth_scene.ctor(.one)`.
pub const vtbl: world.SceneVtbl = .{
    .handleMessage = handleMessage,
    .createScreen = labyrinth_scene.createScreen1,
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

/// LabyrinthSceneVtbl slot 00 handleMessage (phase1_scene_handle_message; hwnd dropped): WM_DESTROY, activation, the exit doors on SPACE, MM_WOM_DONE (the respawn), then `labyrinth_scene.handleMessage`.
pub fn handleMessage(g: *Game, s: *Scene, m: Msg) u16 {
    _ = g;
    _ = s;
    _ = m;
    stub.unported("jardim.phase1.handleMessage");
}

/// LabyrinthSceneVtbl slot 06 createNewScene (phase1_scene_create_new_scene): the Phase2Scene.
pub fn createNewScene(g: *Game, s: *Scene, exit_index: i16) ?*Scene {
    _ = g;
    _ = s;
    _ = exit_index;
    stub.unported("jardim.phase1.createNewScene");
}

/// LabyrinthSceneVtbl slot 07 create (phase1_scene_create; hwnd dropped).
pub fn create(g: *Game, s: *Scene) *Scene {
    _ = g;
    _ = s;
    stub.unported("jardim.phase1.create");
}

/// LabyrinthSceneVtbl slot 10 hit (phase1_scene_hit).
pub fn hit(g: *Game, s: *Scene, obj: ?*Object, col: i16, row: i16) void {
    _ = g;
    _ = s;
    _ = obj;
    _ = col;
    _ = row;
    stub.unported("jardim.phase1.hit");
}

/// LabyrinthSceneVtbl slot 11 touch (phase1_scene_touch).
pub fn touch(g: *Game, s: *Scene, obj: *Object) i16 {
    _ = g;
    _ = s;
    _ = obj;
    stub.unported("jardim.phase1.touch");
}

/// LabyrinthSceneVtbl slot 12 placeObjects (phase1_scene_place_objects).
pub fn placeObjects(g: *Game, s: *Scene) *Scene {
    _ = g;
    _ = s;
    stub.unported("jardim.phase1.placeObjects");
}

/// LabyrinthSceneVtbl slot 13 playEnemyAttackSound (phase1_scene_play_enemy_attack_sound).
pub fn playEnemyAttackSound(g: *Game, s: *Scene, obj: *Object) void {
    _ = g;
    _ = s;
    _ = obj;
    stub.unported("jardim.phase1.playEnemyAttackSound");
}

/// LabyrinthSceneVtbl slot 14 playEnemyStepSound (phase1_scene_play_enemy_step_sound).
pub fn playEnemyStepSound(g: *Game, s: *Scene, obj: *Object) void {
    _ = g;
    _ = s;
    _ = obj;
    stub.unported("jardim.phase1.playEnemyStepSound");
}

/// LabyrinthSceneVtbl slot 15 playFireSound (phase1_scene_play_fire_sound).
pub fn playFireSound(g: *Game, s: *Scene) void {
    _ = g;
    _ = s;
    stub.unported("jardim.phase1.playFireSound");
}

/// LabyrinthSceneVtbl slot 16 playDoorSound (phase1_scene_play_door_sound).
pub fn playDoorSound(g: *Game, s: *Scene) void {
    _ = g;
    _ = s;
    stub.unported("jardim.phase1.playDoorSound");
}

/// LabyrinthSceneVtbl slot 17 onLifeLost (phase1_scene_on_life_lost; hwnd dropped): `berro` with a notify window.
pub fn onLifeLost(g: *Game, s: *Scene) void {
    _ = g;
    _ = s;
    stub.unported("jardim.phase1.onLifeLost");
}
