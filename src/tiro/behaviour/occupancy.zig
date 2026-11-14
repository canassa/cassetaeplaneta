//! Port unit `occupancy` (behaviour) of TIRO.EXE. SceneObject slots 22-26 (occupy, vacate, attach, canStep incl. Target's, isStepBlocked) and reattach.
//!
//! Virtual-slot dispatchers owned by this unit are declared below with
//! their final signatures; their bodies panic until the unit is ported
//! (docs/tiro/DESIGN.md "Virtual slots"). Replace each body, keep the
//! signature (other units already call it). Each implementation function
//! carries `// @orig <seg:xxxx> <name>` with the TIRO address.

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
const RectQuery = world.RectQuery;

/// SceneObject slot 22 occupy: control_panel_occupy (panel), status_bar_occupy (status) / SceneObject's.
pub fn occupy(g: *Game, obj: *Object, bd: *Backdrop) i16 {
    _ = g;
    _ = obj;
    _ = bd;
    stub.unported("tiro.occupancy.occupy");
}

/// SceneObject slot 23 vacate: control_panel_vacate (panel), status_bar_vacate (status) / SceneObject's.
pub fn vacate(g: *Game, obj: *Object, bd: *Backdrop) i16 {
    _ = g;
    _ = obj;
    _ = bd;
    stub.unported("tiro.occupancy.vacate");
}

/// SceneObject slot 24 attach: actor2d_attach (crossbow, target, arrow), control_panel_attach (panel), status_bar_attach (status) / SceneObject's.
pub fn attach(g: *Game, obj: *Object, bd: *Backdrop) ?*Object {
    _ = g;
    _ = obj;
    _ = bd;
    stub.unported("tiro.occupancy.attach");
}

/// SceneObject slot 25 canStep: actor2d_can_step (crossbow, arrow), target_can_step (target) / default.
pub fn canStep(g: *Game, obj: *Object, bd: *Backdrop) bool {
    _ = g;
    _ = obj;
    _ = bd;
    stub.unported("tiro.occupancy.canStep");
}

/// SceneObject slot 26 isStepBlocked.
pub fn isStepBlocked(g: *Game, obj: *Object, bd: *Backdrop) bool {
    _ = g;
    _ = obj;
    _ = bd;
    stub.unported("tiro.occupancy.isStepBlocked");
}
