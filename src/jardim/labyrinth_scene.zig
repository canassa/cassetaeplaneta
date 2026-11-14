//! Port unit `labyrinth_scene` (module) of JARDIM.EXE. LabyrinthScene: ctor, create, its handler (the 0x402 carry to the next phase), the respawn (slot 17); the three phase ctors (each sets its phase's vtable) and createScreen (the LabyrinthBackdrop on opcaoN.bmp).
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

/// The phase scenes' ctors (phase1/2/3_scene_ctor → labyrinth_scene_ctor → scene_ctor): a new scene of that phase, its vtable set (`phase1.vtbl` …).
pub fn ctor(g: *Game, phase: world.Phase, name: []const u8) !*Scene {
    _ = g;
    _ = phase;
    _ = name;
    stub.unported("jardim.labyrinth_scene.ctor");
}

/// LabyrinthScene slot 00 handleMessage (labyrinth_scene_handle_message; hwnd dropped): forwards to the backdrop; 0x402 carries the state to the next phase.
pub fn handleMessage(g: *Game, s: *Scene, m: Msg) u16 {
    _ = g;
    _ = s;
    _ = m;
    stub.unported("jardim.labyrinth_scene.handleMessage");
}

/// LabyrinthScene slot 07 create (labyrinth_scene_create; hwnd dropped): scene_create and the screen.
pub fn create(g: *Game, s: *Scene) *Scene {
    _ = g;
    _ = s;
    stub.unported("jardim.labyrinth_scene.create");
}

/// LabyrinthScene slot 17 (labyrinth_scene_respawn; hwnd dropped): every object back, the fists, the start, score -500.
pub fn respawn(g: *Game, s: *Scene) void {
    _ = g;
    _ = s;
    stub.unported("jardim.labyrinth_scene.respawn");
}

/// LabyrinthSceneVtbl slot 05 createScreen of Phase1Scene (phase1_scene_create_screen: the LabyrinthBackdrop on opcao1.bmp).
pub fn createScreen1(g: *Game, s: *Scene) ?*Backdrop {
    _ = g;
    _ = s;
    stub.unported("jardim.labyrinth_scene.createScreen1");
}

/// LabyrinthSceneVtbl slot 05 createScreen of Phase2Scene (phase2_scene_create_screen: the LabyrinthBackdrop on opcao2.bmp).
pub fn createScreen2(g: *Game, s: *Scene) ?*Backdrop {
    _ = g;
    _ = s;
    stub.unported("jardim.labyrinth_scene.createScreen2");
}

/// LabyrinthSceneVtbl slot 05 createScreen of Phase3Scene (phase3_scene_create_screen: the LabyrinthBackdrop on opcao3.bmp).
pub fn createScreen3(g: *Game, s: *Scene) ?*Backdrop {
    _ = g;
    _ = s;
    stub.unported("jardim.labyrinth_scene.createScreen3");
}
