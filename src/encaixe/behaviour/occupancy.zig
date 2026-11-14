//! Port unit `occupancy` (behaviour) of ENCAIXE.EXE. SceneObject slots 24-28 (occupy, vacate, attach, canStep, isStepBlocked) and reattach.
//!
//! Virtual-slot dispatchers owned by this unit are declared below with
//! their final signatures; their bodies panic until the unit is ported
//! (docs/encaixe/DESIGN.md "Virtual slots"). Replace each body, keep the
//! signature (other units already call it). Each implementation function
//! carries `// @orig <1008:xxxx> <name>` with the ENCAIXE address.

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

/// SceneObject slot 24 occupy: ControlPanel's / StatusBar's (empty) / SceneObject's.
pub fn occupy(g: *Game, obj: *Object, bd: *Backdrop) i16 {
    _ = g;
    _ = obj;
    _ = bd;
    stub.unported("encaixe.occupancy.occupy");
}

/// SceneObject slot 25 vacate.
pub fn vacate(g: *Game, obj: *Object, bd: *Backdrop) i16 {
    _ = g;
    _ = obj;
    _ = bd;
    stub.unported("encaixe.occupancy.vacate");
}

/// SceneObject slot 26 attach: Actor2D's (piece), ControlPanel's, StatusBar's.
pub fn attach(g: *Game, obj: *Object, bd: *Backdrop) ?*Object {
    _ = g;
    _ = obj;
    _ = bd;
    stub.unported("encaixe.occupancy.attach");
}

/// SceneObject slot 27 canStep: Actor2D's (piece) / default.
pub fn canStep(g: *Game, obj: *Object, bd: *Backdrop) bool {
    _ = g;
    _ = obj;
    _ = bd;
    stub.unported("encaixe.occupancy.canStep");
}

/// SceneObject slot 28 isStepBlocked.
pub fn isStepBlocked(g: *Game, obj: *Object, bd: *Backdrop) bool {
    _ = g;
    _ = obj;
    _ = bd;
    stub.unported("encaixe.occupancy.isStepBlocked");
}
