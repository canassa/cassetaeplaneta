//! Port unit `movement` (behaviour) of SERIAL.EXE. SceneObject slots 2F-34 36 (moveTo, edges, stopMoving(Dc) incl. Target's/Projectile's, moveTick incl. Target's walk step and the killers' shot (a life, WM_DESTROY at 0), isMoving) and MoverVtbl/TargetVtbl/ProjectileVtbl placeAt.
//!
//! Virtual-slot dispatchers owned by this unit are declared below with
//! their final signatures; their bodies panic until the unit is ported
//! (docs/serial/DESIGN.md "Virtual slots"). Replace each body, keep the
//! signature (other units already call it). Each implementation function
//! carries `// @orig <seg:xxxx> <name>` with the SERIAL address.

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

/// SceneObject slot 2F moveTo (hwnd dropped): mover_move_to (gun, target, bullet) / default.
pub fn moveTo(g: *Game, obj: *Object, x: i16, y: i16, bd: *Backdrop) void {
    _ = g;
    _ = obj;
    _ = x;
    _ = y;
    _ = bd;
    stub.unported("serial.movement.moveTo");
}

/// SceneObject slot 30 moveToEdgeH: mover_move_to_edge_h (gun, target, bullet) / default.
pub fn moveToEdgeH(g: *Game, obj: *Object, bd: *Backdrop, dir: i16) void {
    _ = g;
    _ = obj;
    _ = bd;
    _ = dir;
    stub.unported("serial.movement.moveToEdgeH");
}

/// SceneObject slot 31 moveToEdgeV: mover_move_to_edge_v (gun, target, bullet) / default.
pub fn moveToEdgeV(g: *Game, obj: *Object, bd: *Backdrop, dir: i16) void {
    _ = g;
    _ = obj;
    _ = bd;
    _ = dir;
    stub.unported("serial.movement.moveToEdgeV");
}

/// SceneObject slot 32 stopMovingDc: actor2d_stop_moving_dc (gun), target_stop_moving_dc (target), projectile_stop_moving_dc (bullet) / default.
pub fn stopMovingDc(g: *Game, obj: *Object, bd: *Backdrop) void {
    _ = g;
    _ = obj;
    _ = bd;
    stub.unported("serial.movement.stopMovingDc");
}

/// SceneObject slot 33 stopMoving: actor2d_stop_moving (gun), target_stop_moving (target), projectile_stop_moving (bullet) / default.
pub fn stopMoving(g: *Game, obj: *Object, bd: *Backdrop) void {
    _ = g;
    _ = obj;
    _ = bd;
    stub.unported("serial.movement.stopMoving");
}

/// SceneObject slot 34 moveTick: player2d_move_tick (gun), target_move_tick (target), actor2d_move_tick (bullet) / default.
pub fn moveTick(g: *Game, obj: *Object, bd: *Backdrop) void {
    _ = g;
    _ = obj;
    _ = bd;
    stub.unported("serial.movement.moveTick");
}

/// SceneObject slot 36 isMoving: actor2d_is_moving (gun, target, bullet) / default.
pub fn isMoving(g: *Game, obj: *Object) bool {
    _ = g;
    _ = obj;
    stub.unported("serial.movement.isMoving");
}

/// MoverVtbl / TargetVtbl / ProjectileVtbl slot 00 placeAt (mover_place_at).
pub fn placeAt(g: *Game, obj: *Object, x: i16, y: i16, bd: *Backdrop) void {
    _ = g;
    _ = obj;
    _ = x;
    _ = y;
    _ = bd;
    stub.unported("serial.movement.placeAt");
}
