//! Port unit `occupancy` (behaviour) of JARDIM.EXE. SceneObject slots 27-2B (occupy, vacate, attach incl. the wall strip's, canStep, isStepBlocked) and reattach.
//!
//! Virtual-slot dispatchers owned by this unit are declared below with
//! their final signatures; their bodies panic until the unit is ported
//! (docs/jardim/DESIGN.md "Virtual slots"). Replace each body, keep the
//! signature (other units already call it). Each implementation function
//! carries `// @orig <seg:xxxx> <name>` with the JARDIM address.

const std = @import("std");
const stub = @import("../../core/stub.zig");
const msg = @import("../../core/msg.zig");
const Msg = msg.Msg;
const Game = @import("../core/game.zig").Game;
const object = @import("../core/object.zig");
const Object = object.Object;
const ObjectList = object.ObjectList;
const Frame = object.Frame;
const FrameCell = object.FrameCell;
const BitmapInfoHeader = object.BitmapInfoHeader;
const world = @import("../core/world.zig");
const Backdrop = world.Backdrop;
const Scene = world.Scene;
const Condition = world.Condition;

/// SceneObject slot 27 occupy: player_occupy (player), control_panel_occupy (control_panel) / SceneObject's.
pub fn occupy(g: *Game, obj: *Object, bd: *Backdrop) i16 {
    _ = g;
    _ = obj;
    _ = bd;
    stub.unported("jardim.occupancy.occupy");
}

/// SceneObject slot 28 vacate: player_vacate (player), control_panel_vacate (control_panel) / SceneObject's.
pub fn vacate(g: *Game, obj: *Object, bd: *Backdrop) i16 {
    _ = g;
    _ = obj;
    _ = bd;
    stub.unported("jardim.occupancy.vacate");
}

/// SceneObject slot 29 attach: wall_strip_attach (wall_strip), moveable_attach (portable, player), object3d_attach (exit), control_panel_attach (control_panel) / SceneObject's.
pub fn attach(g: *Game, obj: *Object, bd: *Backdrop) ?*Object {
    _ = g;
    _ = obj;
    _ = bd;
    stub.unported("jardim.occupancy.attach");
}

/// SceneObject slot 2A canStep: portable_can_step (portable), moveable_can_step (player) / default.
pub fn canStep(g: *Game, obj: *Object, bd: *Backdrop) bool {
    _ = g;
    _ = obj;
    _ = bd;
    stub.unported("jardim.occupancy.canStep");
}

/// SceneObject slot 2B isStepBlocked (SceneObject's).
pub fn isStepBlocked(g: *Game, obj: *Object, bd: *Backdrop) bool {
    _ = g;
    _ = obj;
    _ = bd;
    stub.unported("jardim.occupancy.isStepBlocked");
}
