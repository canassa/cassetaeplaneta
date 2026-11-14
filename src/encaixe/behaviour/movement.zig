//! Port unit `movement` (behaviour) of ENCAIXE.EXE. SceneObject slots 31-36 38 (moveTo, edges, stopMoving(Dc), moveTick, isMoving) and MoverVtbl/PieceVtbl placeAt.
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

/// SceneObject slot 31 moveTo (hwnd dropped): Mover's (piece).
pub fn moveTo(g: *Game, obj: *Object, x: i16, y: i16, bd: *Backdrop) void {
    _ = g;
    _ = obj;
    _ = x;
    _ = y;
    _ = bd;
    stub.unported("encaixe.movement.moveTo");
}

/// SceneObject slot 32 moveToEdgeH.
pub fn moveToEdgeH(g: *Game, obj: *Object, bd: *Backdrop, dir: i16) void {
    _ = g;
    _ = obj;
    _ = bd;
    _ = dir;
    stub.unported("encaixe.movement.moveToEdgeH");
}

/// SceneObject slot 33 moveToEdgeV.
pub fn moveToEdgeV(g: *Game, obj: *Object, bd: *Backdrop, dir: i16) void {
    _ = g;
    _ = obj;
    _ = bd;
    _ = dir;
    stub.unported("encaixe.movement.moveToEdgeV");
}

/// SceneObject slot 34 stopMovingDc: te_piece_stop_moving_dc (piece).
pub fn stopMovingDc(g: *Game, obj: *Object, bd: *Backdrop) void {
    _ = g;
    _ = obj;
    _ = bd;
    stub.unported("encaixe.movement.stopMovingDc");
}

/// SceneObject slot 35 stopMoving: te_piece_stop_moving (piece).
pub fn stopMoving(g: *Game, obj: *Object, bd: *Backdrop) void {
    _ = g;
    _ = obj;
    _ = bd;
    stub.unported("encaixe.movement.stopMoving");
}

/// SceneObject slot 36 moveTick: Player2D's (piece).
pub fn moveTick(g: *Game, obj: *Object, bd: *Backdrop) void {
    _ = g;
    _ = obj;
    _ = bd;
    stub.unported("encaixe.movement.moveTick");
}

/// SceneObject slot 38 isMoving: Actor2D's (piece).
pub fn isMoving(g: *Game, obj: *Object) bool {
    _ = g;
    _ = obj;
    stub.unported("encaixe.movement.isMoving");
}

/// MoverVtbl / PieceVtbl slot 00 placeAt (mover_place_at).
pub fn placeAt(g: *Game, obj: *Object, x: i16, y: i16, bd: *Backdrop) void {
    _ = g;
    _ = obj;
    _ = x;
    _ = y;
    _ = bd;
    stub.unported("encaixe.movement.placeAt");
}
