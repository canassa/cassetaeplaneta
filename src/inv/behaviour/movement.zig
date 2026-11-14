//! Port unit `movement` (behaviour) of INV.EXE. SceneObject slots 2F-34 36 (moveTo, edges, stopMoving(Dc) incl. the Saucer's, the Missile's and the InvaderColumn's (right-edge descent, landing), moveTick incl. the Missile's and the InvaderColumn's, isMoving).
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

/// SceneObject slot 2F moveTo (hwnd dropped): mover_move_to (cannon, saucer, bomb, shot, column, explosion) / default.
pub fn moveTo(g: *Game, obj: *Object, x: i16, y: i16, bd: *Backdrop) void {
    _ = g;
    _ = obj;
    _ = x;
    _ = y;
    _ = bd;
    stub.unported("inv.movement.moveTo");
}

/// SceneObject slot 30 moveToEdgeH: mover_move_to_edge_h (cannon, saucer, bomb, shot, column, explosion) / default.
pub fn moveToEdgeH(g: *Game, obj: *Object, bd: *Backdrop, dir: i16) void {
    _ = g;
    _ = obj;
    _ = bd;
    _ = dir;
    stub.unported("inv.movement.moveToEdgeH");
}

/// SceneObject slot 31 moveToEdgeV: mover_move_to_edge_v (cannon, saucer, bomb, shot, column, explosion) / default.
pub fn moveToEdgeV(g: *Game, obj: *Object, bd: *Backdrop, dir: i16) void {
    _ = g;
    _ = obj;
    _ = bd;
    _ = dir;
    stub.unported("inv.movement.moveToEdgeV");
}

/// SceneObject slot 32 stopMovingDc: actor2d_stop_moving_dc (cannon), saucer_stop_moving_dc (saucer), missile_stop_moving_dc (bomb, shot), invader_column_stop_moving_dc (column, explosion) / default.
pub fn stopMovingDc(g: *Game, obj: *Object, bd: *Backdrop) void {
    _ = g;
    _ = obj;
    _ = bd;
    stub.unported("inv.movement.stopMovingDc");
}

/// SceneObject slot 33 stopMoving: actor2d_stop_moving (cannon), saucer_stop_moving (saucer), missile_stop_moving (bomb, shot), invader_column_stop_moving (column, explosion) / default.
pub fn stopMoving(g: *Game, obj: *Object, bd: *Backdrop) void {
    _ = g;
    _ = obj;
    _ = bd;
    stub.unported("inv.movement.stopMoving");
}

/// SceneObject slot 34 moveTick: player2d_move_tick (cannon), actor2d_move_tick (saucer), missile_move_step (bomb, shot), invader_column_move_tick (column, explosion) / default.
pub fn moveTick(g: *Game, obj: *Object, bd: *Backdrop) void {
    _ = g;
    _ = obj;
    _ = bd;
    stub.unported("inv.movement.moveTick");
}

/// SceneObject slot 36 isMoving: actor2d_is_moving (cannon, saucer, bomb, shot, column, explosion) / default.
pub fn isMoving(g: *Game, obj: *Object) bool {
    _ = g;
    _ = obj;
    stub.unported("inv.movement.isMoving");
}
