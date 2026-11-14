//! Port unit `movement` (behaviour) of SAUNA.EXE. SceneObject slots 35-3A 3C (moveTo incl. Pacman's click walk (P5), edges incl. Pacman's, stopMoving(Dc) incl. Pacman's/Ghost's, moveTick incl. Pacman's/Ghost's, isMoving) and MoverVtbl/PacmanVtbl/GhostVtbl placeAt.
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

/// SceneObject slot 35 moveTo (hwnd dropped): pacman_move_to (pacman), mover_move_to (ghost) / default.
pub fn moveTo(g: *Game, obj: *Object, x: i16, y: i16, bd: *Backdrop) void {
    _ = g;
    _ = obj;
    _ = x;
    _ = y;
    _ = bd;
    stub.unported("sauna.movement.moveTo");
}

/// SceneObject slot 36 moveToEdgeH: pacman_move_to_edge_h (pacman), mover_move_to_edge_h (ghost) / default.
pub fn moveToEdgeH(g: *Game, obj: *Object, bd: *Backdrop, dir: i16) void {
    _ = g;
    _ = obj;
    _ = bd;
    _ = dir;
    stub.unported("sauna.movement.moveToEdgeH");
}

/// SceneObject slot 37 moveToEdgeV: pacman_move_to_edge_v (pacman), mover_move_to_edge_v (ghost) / default.
pub fn moveToEdgeV(g: *Game, obj: *Object, bd: *Backdrop, dir: i16) void {
    _ = g;
    _ = obj;
    _ = bd;
    _ = dir;
    stub.unported("sauna.movement.moveToEdgeV");
}

/// SceneObject slot 38 stopMovingDc: pacman_stop_moving_dc (pacman), ghost_stop_moving_dc (ghost) / default.
pub fn stopMovingDc(g: *Game, obj: *Object, bd: *Backdrop) void {
    _ = g;
    _ = obj;
    _ = bd;
    stub.unported("sauna.movement.stopMovingDc");
}

/// SceneObject slot 39 stopMoving: pacman_stop_moving (pacman), ghost_stop_moving (ghost) / default.
pub fn stopMoving(g: *Game, obj: *Object, bd: *Backdrop) void {
    _ = g;
    _ = obj;
    _ = bd;
    stub.unported("sauna.movement.stopMoving");
}

/// SceneObject slot 3A moveTick: pacman_move_tick (pacman), ghost_move_tick (ghost) / default.
pub fn moveTick(g: *Game, obj: *Object, bd: *Backdrop) void {
    _ = g;
    _ = obj;
    _ = bd;
    stub.unported("sauna.movement.moveTick");
}

/// SceneObject slot 3C isMoving: actor2d_is_moving (pacman, ghost) / default.
pub fn isMoving(g: *Game, obj: *Object) bool {
    _ = g;
    _ = obj;
    stub.unported("sauna.movement.isMoving");
}

/// MoverVtbl / PacmanVtbl / GhostVtbl slot 00 placeAt (mover_place_at).
pub fn placeAt(g: *Game, obj: *Object, x: i16, y: i16, bd: *Backdrop) void {
    _ = g;
    _ = obj;
    _ = x;
    _ = y;
    _ = bd;
    stub.unported("sauna.movement.placeAt");
}
