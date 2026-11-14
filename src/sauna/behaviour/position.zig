//! Port unit `position` (behaviour) of SAUNA.EXE. SceneObject slots 04 getSceneName, 0D-11 getX/getY/getStep, 3F setPosition, 55/56 overlap tests, 57/58 5B/5C defaults; the /Od out-of-line accessors (hit box, frame, size); next_object_id.
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

/// SceneObject slot 04 getSceneName (char *: the name SceneObject+0x478).
pub fn getSceneName(g: *Game, obj: *Object) []const u8 {
    _ = g;
    _ = obj;
    stub.unported("sauna.position.getSceneName");
}

/// SceneObject slot 0D getX: mover_get_x (pacman, ghost) / SceneObject's.
pub fn getX(g: *Game, obj: *Object) i16 {
    _ = g;
    _ = obj;
    stub.unported("sauna.position.getX");
}

/// SceneObject slot 0E getY: mover_get_y (pacman, ghost) / SceneObject's.
pub fn getY(g: *Game, obj: *Object) i16 {
    _ = g;
    _ = obj;
    stub.unported("sauna.position.getY");
}

/// SceneObject slot 0F getStepX: mover_get_step_x (pacman, ghost) / default.
pub fn getStepX(g: *Game, obj: *Object) i16 {
    _ = g;
    _ = obj;
    stub.unported("sauna.position.getStepX");
}

/// SceneObject slot 10 getStepY: mover_get_step_y (pacman, ghost) / default.
pub fn getStepY(g: *Game, obj: *Object) i16 {
    _ = g;
    _ = obj;
    stub.unported("sauna.position.getStepY");
}

/// SceneObject slot 11 slot11 (default only).
pub fn slot11(g: *Game, obj: *Object, arg: u16) i16 {
    _ = g;
    _ = obj;
    _ = arg;
    stub.unported("sauna.position.slot11");
}

/// SceneObject slot 3F setPosition: actor2d_set_position (pacman, ghost) / SceneObject's.
pub fn setPosition(g: *Game, obj: *Object, x: i16, y: i16) void {
    _ = g;
    _ = obj;
    _ = x;
    _ = y;
    stub.unported("sauna.position.setPosition");
}

/// SceneObject slot 55 hitboxOverlaps.
pub fn hitboxOverlaps(g: *Game, obj: *Object, other: *Object) bool {
    _ = g;
    _ = obj;
    _ = other;
    stub.unported("sauna.position.hitboxOverlaps");
}

/// SceneObject slot 56 boundsOverlap.
pub fn boundsOverlap(g: *Game, obj: *Object, other: *Object) bool {
    _ = g;
    _ = obj;
    _ = other;
    stub.unported("sauna.position.boundsOverlap");
}

/// SceneObject slot 57 slot5B (default only).
pub fn slot5B(g: *Game, obj: *Object, arg: i16) i16 {
    _ = g;
    _ = obj;
    _ = arg;
    stub.unported("sauna.position.slot5B");
}

/// SceneObject slot 58 slot5C (default only).
pub fn slot5C(g: *Game, obj: *Object, arg: i16) i16 {
    _ = g;
    _ = obj;
    _ = arg;
    stub.unported("sauna.position.slot5C");
}

/// SceneObject slot 5B isEnabled (default only).
pub fn isEnabled(g: *Game, obj: *Object) bool {
    _ = g;
    _ = obj;
    stub.unported("sauna.position.isEnabled");
}

/// SceneObject slot 5C getExitIndex (default only).
pub fn getExitIndex(g: *Game, obj: *Object) i16 {
    _ = g;
    _ = obj;
    stub.unported("sauna.position.getExitIndex");
}
