//! Port unit `movement` (behaviour) of XILINDRO.EXE. SceneObject slots 2F-34 36 (moveTo, edges, stopMoving(Dc) and moveTick incl. the Fighter's and the Opponent's, isMoving) and Mover/Fighter/OpponentVtbl placeAt.
//!
//! Virtual-slot dispatchers owned by this unit are declared below with
//! their final signatures; their bodies panic until the unit is ported
//! (docs/xilindro/DESIGN.md "Virtual slots"). Replace each body, keep the
//! signature (other units already call it). Each implementation function
//! carries `// @orig <seg:xxxx> <name>` with the XILINDRO address.

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

/// SceneObject slot 2F moveTo (hwnd dropped): mover_move_to (fighter, opponent, banner, energy_bar) / default.
pub fn moveTo(g: *Game, obj: *Object, x: i16, y: i16, bd: *Backdrop) void {
    _ = g;
    _ = obj;
    _ = x;
    _ = y;
    _ = bd;
    stub.unported("xilindro.movement.moveTo");
}

/// SceneObject slot 30 moveToEdgeH: mover_move_to_edge_h (fighter, opponent, banner, energy_bar) / default.
pub fn moveToEdgeH(g: *Game, obj: *Object, bd: *Backdrop, dir: i16) void {
    _ = g;
    _ = obj;
    _ = bd;
    _ = dir;
    stub.unported("xilindro.movement.moveToEdgeH");
}

/// SceneObject slot 31 moveToEdgeV: mover_move_to_edge_v (fighter, opponent, banner, energy_bar) / default.
pub fn moveToEdgeV(g: *Game, obj: *Object, bd: *Backdrop, dir: i16) void {
    _ = g;
    _ = obj;
    _ = bd;
    _ = dir;
    stub.unported("xilindro.movement.moveToEdgeV");
}

/// SceneObject slot 32 stopMovingDc: fighter_stop_moving_dc (fighter), opponent_stop_moving_dc (opponent), actor2d_stop_moving_dc (banner, energy_bar) / default.
pub fn stopMovingDc(g: *Game, obj: *Object, bd: *Backdrop) void {
    _ = g;
    _ = obj;
    _ = bd;
    stub.unported("xilindro.movement.stopMovingDc");
}

/// SceneObject slot 33 stopMoving: fighter_stop_moving (fighter), opponent_stop_moving (opponent), actor2d_stop_moving (banner, energy_bar) / default.
pub fn stopMoving(g: *Game, obj: *Object, bd: *Backdrop) void {
    _ = g;
    _ = obj;
    _ = bd;
    stub.unported("xilindro.movement.stopMoving");
}

/// SceneObject slot 34 moveTick: fighter_move_tick (fighter), opponent_move_tick (opponent), actor2d_move_tick (banner, energy_bar) / default.
pub fn moveTick(g: *Game, obj: *Object, bd: *Backdrop) void {
    _ = g;
    _ = obj;
    _ = bd;
    stub.unported("xilindro.movement.moveTick");
}

/// SceneObject slot 36 isMoving: actor2d_is_moving (fighter, opponent, banner, energy_bar) / default.
pub fn isMoving(g: *Game, obj: *Object) bool {
    _ = g;
    _ = obj;
    stub.unported("xilindro.movement.isMoving");
}

/// MoverVtbl / FighterVtbl / OpponentVtbl slot 00 placeAt (mover_place_at).
pub fn placeAt(g: *Game, obj: *Object, x: i16, y: i16, bd: *Backdrop) void {
    _ = g;
    _ = obj;
    _ = x;
    _ = y;
    _ = bd;
    stub.unported("xilindro.movement.placeAt");
}
