//! Port unit `ghost` (module) of SAUNA.EXE. the ghost AI: GhostVtbl chooseDirection (rand) and isNextStepFree, SaunaSceneVtbl sendGhostsHome.
//!
//! Virtual-slot dispatchers owned by this unit are declared below with
//! their final signatures; their bodies panic until the unit is ported
//! (docs/sauna/DESIGN.md "Virtual slots"). Replace each body, keep the
//! signature (other units already call it). Each implementation function
//! carries `// @orig <seg:xxxx> <name>` with the SAUNA address.

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

/// GhostVtbl slot 01 chooseDirection (ghost_choose_direction; hwnd dropped): toward Pacman (away while powered) when aligned within 16 px and the next step is free, else `rand() % 4`.
pub fn chooseDirection(g: *Game, obj: *Object, bd: *Backdrop) void {
    _ = g;
    _ = obj;
    _ = bd;
    stub.unported("sauna.ghost.chooseDirection");
}

/// GhostVtbl slot 02 isNextStepFree (ghost_is_next_step_free): no wall in the cells of the next step.
pub fn isNextStepFree(g: *Game, obj: *Object, bd: *Backdrop) bool {
    _ = g;
    _ = obj;
    _ = bd;
    stub.unported("sauna.ghost.isNextStepFree");
}

/// SaunaSceneVtbl slot 10 sendGhostsHome (sauna_scene_send_ghosts_home): the four ghosts back to (300, 230), still walking their lines.
pub fn sendGhostsHome(g: *Game, scene: *Scene) void {
    _ = g;
    _ = scene;
    stub.unported("sauna.ghost.sendGhostsHome");
}
