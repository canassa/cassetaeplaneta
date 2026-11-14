//! Port unit `movement` (behaviour) of INFERNO.EXE. SceneObject slots 2F-34
//! 36 (moveTo, edges, stopMoving(Dc), moveTick, isMoving), MoverVtbl placeAt
//! (every table's slot 00), mover_step/at_target.
//!
//! Virtual-slot dispatchers owned by this unit are declared below with
//! their final signatures; their bodies panic until the unit is ported
//! (docs/inferno/DESIGN.md "Virtual slots"). Replace each body, keep the
//! signature (other units already call it). Each implementation function
//! carries `// @orig <seg:xxxx> <name>` with the INFERNO address.

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

/// SceneObject slot 2F moveTo (hwnd dropped): mover_move_to (every kind).
pub fn moveTo(g: *Game, obj: *Object, x: i16, y: i16, bd: *Backdrop) void {
    _ = g;
    _ = obj;
    _ = x;
    _ = y;
    _ = bd;
    stub.unported("inferno.movement.moveTo");
}

/// SceneObject slot 30 moveToEdgeH: mover_move_to_edge_h (hero),
/// ledge.moveToEdgeH (platform), prop.moveToEdgeH (prop, hazard).
pub fn moveToEdgeH(g: *Game, obj: *Object, bd: *Backdrop, dir: i16) void {
    _ = g;
    _ = obj;
    _ = bd;
    _ = dir;
    stub.unported("inferno.movement.moveToEdgeH");
}

/// SceneObject slot 31 moveToEdgeV: hero.moveToEdgeV (hero),
/// mover_move_to_edge_v (platform, prop, hazard).
pub fn moveToEdgeV(g: *Game, obj: *Object, bd: *Backdrop, dir: i16) void {
    _ = g;
    _ = obj;
    _ = bd;
    _ = dir;
    stub.unported("inferno.movement.moveToEdgeV");
}

/// SceneObject slot 32 stopMovingDc: hero.stopMovingDc (hero),
/// actor2d_stop_moving_dc (platform, prop, hazard).
pub fn stopMovingDc(g: *Game, obj: *Object, bd: *Backdrop) void {
    _ = g;
    _ = obj;
    _ = bd;
    stub.unported("inferno.movement.stopMovingDc");
}

/// SceneObject slot 33 stopMoving: hero.stopMoving (hero),
/// actor2d_stop_moving (platform, prop), hazard.stopMoving (hazard).
pub fn stopMoving(g: *Game, obj: *Object, bd: *Backdrop) void {
    _ = g;
    _ = obj;
    _ = bd;
    stub.unported("inferno.movement.stopMoving");
}

/// SceneObject slot 34 moveTick: hero.moveTick, ledge.moveTick,
/// prop.moveTick, hazard.moveTick (each kind its own).
pub fn moveTick(g: *Game, obj: *Object, bd: *Backdrop) void {
    _ = g;
    _ = obj;
    _ = bd;
    stub.unported("inferno.movement.moveTick");
}

/// SceneObject slot 36 isMoving: actor2d_is_moving (every kind).
pub fn isMoving(g: *Game, obj: *Object) bool {
    _ = g;
    _ = obj;
    stub.unported("inferno.movement.isMoving");
}

/// MoverVtbl / PlatformVtbl / PropVtbl slot 00 placeAt (mover_place_at, every
/// table).
pub fn placeAt(g: *Game, obj: *Object, x: i16, y: i16, bd: *Backdrop) void {
    _ = g;
    _ = obj;
    _ = x;
    _ = y;
    _ = bd;
    stub.unported("inferno.movement.placeAt");
}
