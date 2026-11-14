//! Port unit `movement` (behaviour) of JARDIM.EXE. SceneObject slots 34-39 3B (moveTo, edges, stopMoving(Dc), moveTick, isMoving), MoverVtbl placeAt.
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

/// SceneObject slot 34 moveTo (hwnd dropped): moveable_move_to (portable, player) / default.
pub fn moveTo(g: *Game, obj: *Object, x: i16, y: i16, bd: *Backdrop) void {
    _ = g;
    _ = obj;
    _ = x;
    _ = y;
    _ = bd;
    stub.unported("jardim.movement.moveTo");
}

/// SceneObject slot 35 moveToEdgeH: moveable_move_to_edge_h (portable, player) / default.
pub fn moveToEdgeH(g: *Game, obj: *Object, bd: *Backdrop, dir: i16) void {
    _ = g;
    _ = obj;
    _ = bd;
    _ = dir;
    stub.unported("jardim.movement.moveToEdgeH");
}

/// SceneObject slot 36 moveToEdgeV: moveable_move_to_edge_v (portable, player) / default.
pub fn moveToEdgeV(g: *Game, obj: *Object, bd: *Backdrop, dir: i16) void {
    _ = g;
    _ = obj;
    _ = bd;
    _ = dir;
    stub.unported("jardim.movement.moveToEdgeV");
}

/// SceneObject slot 37 stopMovingDc: moveable_stop_moving_dc (portable), actor_stop_moving_dc (player) / default.
pub fn stopMovingDc(g: *Game, obj: *Object, bd: *Backdrop) void {
    _ = g;
    _ = obj;
    _ = bd;
    stub.unported("jardim.movement.stopMovingDc");
}

/// SceneObject slot 38 stopMoving: moveable_stop_moving (portable), actor_stop_moving (player) / default.
pub fn stopMoving(g: *Game, obj: *Object, bd: *Backdrop) void {
    _ = g;
    _ = obj;
    _ = bd;
    stub.unported("jardim.movement.stopMoving");
}

/// SceneObject slot 39 moveTick: moveable_move_tick (portable), player_move_tick (player) / default.
pub fn moveTick(g: *Game, obj: *Object, bd: *Backdrop) void {
    _ = g;
    _ = obj;
    _ = bd;
    stub.unported("jardim.movement.moveTick");
}

/// SceneObject slot 3B isMoving: moveable_is_moving (portable, player) / default.
pub fn isMoving(g: *Game, obj: *Object) bool {
    _ = g;
    _ = obj;
    stub.unported("jardim.movement.isMoving");
}

/// MoverVtbl slot 00 placeAt (moveable_place_at: the Portable's and the Player's).
pub fn placeAt(g: *Game, obj: *Object, x: i16, y: i16, bd: *Backdrop) void {
    _ = g;
    _ = obj;
    _ = x;
    _ = y;
    _ = bd;
    stub.unported("jardim.movement.placeAt");
}
