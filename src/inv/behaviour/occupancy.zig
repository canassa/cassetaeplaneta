//! Port unit `occupancy` (behaviour) of INV.EXE. SceneObject slots 22-26 (occupy, vacate, attach, canStep incl. the Cannon's, the Missile's and the InvaderColumn's, isStepBlocked), reattach, and Mover placeAt (slot 00 of MoverVtbl, SaucerVtbl, MissileVtbl, InvaderVtbl).
//!
//! Virtual-slot dispatchers owned by this unit are declared below with
//! their final signatures; their bodies panic until the unit is ported
//! (docs/inv/DESIGN.md "Virtual slots"). Replace each body, keep the
//! signature (other units already call it). Each implementation function
//! carries `// @orig <seg:xxxx> <name>` with the INV address.

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
    stub.unported("inv.occupancy.occupy");
}

/// SceneObject slot 23 vacate: control_panel_vacate (panel), status_bar_vacate (status) / SceneObject's.
pub fn vacate(g: *Game, obj: *Object, bd: *Backdrop) i16 {
    _ = g;
    _ = obj;
    _ = bd;
    stub.unported("inv.occupancy.vacate");
}

/// SceneObject slot 24 attach: actor2d_attach (cannon, saucer, bomb, shot, column, explosion), control_panel_attach (panel), status_bar_attach (status) / SceneObject's.
pub fn attach(g: *Game, obj: *Object, bd: *Backdrop) ?*Object {
    _ = g;
    _ = obj;
    _ = bd;
    stub.unported("inv.occupancy.attach");
}

/// SceneObject slot 25 canStep: cannon_can_step (cannon), actor2d_can_step (saucer), missile_can_step (bomb, shot), invader_column_can_step (column, explosion) / default.
pub fn canStep(g: *Game, obj: *Object, bd: *Backdrop) bool {
    _ = g;
    _ = obj;
    _ = bd;
    stub.unported("inv.occupancy.canStep");
}

/// SceneObject slot 26 isStepBlocked.
pub fn isStepBlocked(g: *Game, obj: *Object, bd: *Backdrop) bool {
    _ = g;
    _ = obj;
    _ = bd;
    stub.unported("inv.occupancy.isStepBlocked");
}

/// MoverVtbl / SaucerVtbl / MissileVtbl / InvaderVtbl slot 00 placeAt
/// (mover_place_at): vacate, setPosition, restoreBackground, occupy, the DC
/// hook, draw. In `occupancy`, not `movement` as in TIRO: the canStep
/// overrides call it (docs/inv/DESIGN.md "Units").
pub fn placeAt(g: *Game, obj: *Object, x: i16, y: i16, bd: *Backdrop) void {
    _ = g;
    _ = obj;
    _ = x;
    _ = y;
    _ = bd;
    stub.unported("inv.occupancy.placeAt");
}
