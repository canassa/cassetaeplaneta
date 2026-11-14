//! Port unit `movement` (behaviour) of TIRO.EXE. SceneObject slots 2F-34 36 (moveTo, edges, stopMoving(Dc) incl. Target's/Projectile's, moveTick, isMoving) and MoverVtbl/TargetVtbl/ProjectileVtbl placeAt.
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

/// SceneObject slot 2F moveTo (hwnd dropped): mover_move_to (crossbow, target, arrow) / default.
pub fn moveTo(g: *Game, obj: *Object, x: i16, y: i16, bd: *Backdrop) void {
    _ = g;
    _ = obj;
    _ = x;
    _ = y;
    _ = bd;
    stub.unported("tiro.movement.moveTo");
}

/// SceneObject slot 30 moveToEdgeH: mover_move_to_edge_h (crossbow, target, arrow) / default.
pub fn moveToEdgeH(g: *Game, obj: *Object, bd: *Backdrop, dir: i16) void {
    _ = g;
    _ = obj;
    _ = bd;
    _ = dir;
    stub.unported("tiro.movement.moveToEdgeH");
}

/// SceneObject slot 31 moveToEdgeV: mover_move_to_edge_v (crossbow, target, arrow) / default.
pub fn moveToEdgeV(g: *Game, obj: *Object, bd: *Backdrop, dir: i16) void {
    _ = g;
    _ = obj;
    _ = bd;
    _ = dir;
    stub.unported("tiro.movement.moveToEdgeV");
}

/// SceneObject slot 32 stopMovingDc: actor2d_stop_moving_dc (crossbow), target_stop_moving_dc (target), projectile_stop_moving_dc (arrow) / default.
pub fn stopMovingDc(g: *Game, obj: *Object, bd: *Backdrop) void {
    _ = g;
    _ = obj;
    _ = bd;
    stub.unported("tiro.movement.stopMovingDc");
}

/// SceneObject slot 33 stopMoving: actor2d_stop_moving (crossbow), target_stop_moving (target), projectile_stop_moving (arrow) / default.
pub fn stopMoving(g: *Game, obj: *Object, bd: *Backdrop) void {
    _ = g;
    _ = obj;
    _ = bd;
    stub.unported("tiro.movement.stopMoving");
}

/// SceneObject slot 34 moveTick: player2d_move_tick (crossbow), target_move_tick (target), actor2d_move_tick (arrow) / default.
pub fn moveTick(g: *Game, obj: *Object, bd: *Backdrop) void {
    _ = g;
    _ = obj;
    _ = bd;
    stub.unported("tiro.movement.moveTick");
}

/// SceneObject slot 36 isMoving: actor2d_is_moving (crossbow, target, arrow) / default.
pub fn isMoving(g: *Game, obj: *Object) bool {
    _ = g;
    _ = obj;
    stub.unported("tiro.movement.isMoving");
}

/// MoverVtbl / TargetVtbl / ProjectileVtbl slot 00 placeAt (mover_place_at).
pub fn placeAt(g: *Game, obj: *Object, x: i16, y: i16, bd: *Backdrop) void {
    _ = g;
    _ = obj;
    _ = x;
    _ = y;
    _ = bd;
    stub.unported("tiro.movement.placeAt");
}
