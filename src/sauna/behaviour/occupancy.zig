//! Port unit `occupancy` (behaviour) of SAUNA.EXE. SceneObject slots 28-2C (occupy, vacate, attach, canStep, isStepBlocked) incl. Pacman's and the Ghosts' own occupy/vacate/canStep: the meetings (BUGS.md P1, P2).
//!
//! Virtual-slot dispatchers owned by this unit are declared below with
//! their final signatures; their bodies panic until the unit is ported
//! (docs/sauna/DESIGN.md "Virtual slots"). Replace each body, keep the
//! signature (other units already call it). Each implementation function
//! carries `// @orig <seg:xxxx> <name>` with the SAUNA address.

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

/// SceneObject slot 28 occupy: control_panel_occupy (panel), pacman_occupy (pacman), ghost_occupy (ghost) / SceneObject's.
pub fn occupy(g: *Game, obj: *Object, bd: *Backdrop) i16 {
    _ = g;
    _ = obj;
    _ = bd;
    stub.unported("sauna.occupancy.occupy");
}

/// SceneObject slot 29 vacate: control_panel_vacate (panel), pacman_vacate (pacman), ghost_vacate (ghost) / SceneObject's.
pub fn vacate(g: *Game, obj: *Object, bd: *Backdrop) i16 {
    _ = g;
    _ = obj;
    _ = bd;
    stub.unported("sauna.occupancy.vacate");
}

/// SceneObject slot 2A attach: control_panel_attach (panel), actor2d_attach (pacman, ghost) / SceneObject's.
pub fn attach(g: *Game, obj: *Object, bd: *Backdrop) ?*Object {
    _ = g;
    _ = obj;
    _ = bd;
    stub.unported("sauna.occupancy.attach");
}

/// SceneObject slot 2B canStep: pacman_can_step (pacman), ghost_can_step (ghost) / default.
pub fn canStep(g: *Game, obj: *Object, bd: *Backdrop) bool {
    _ = g;
    _ = obj;
    _ = bd;
    stub.unported("sauna.occupancy.canStep");
}

/// SceneObject slot 2C isStepBlocked.
pub fn isStepBlocked(g: *Game, obj: *Object, bd: *Backdrop) bool {
    _ = g;
    _ = obj;
    _ = bd;
    stub.unported("sauna.occupancy.isStepBlocked");
}
