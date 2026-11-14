//! Port unit `position` (behaviour) of TIRO.EXE. SceneObject slots 08-0C getX/getY/getStep, 39 setPosition, 4C unk4E, 4E/4F overlap tests, 50/51 54/55 defaults; the /Od out-of-line accessors (hit box, frame, size); next_object_id.
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

/// SceneObject slot 08 getX: mover_get_x (crossbow, target, arrow) / SceneObject's.
pub fn getX(g: *Game, obj: *Object) i16 {
    _ = g;
    _ = obj;
    stub.unported("tiro.position.getX");
}

/// SceneObject slot 09 getY: mover_get_y (crossbow, target, arrow) / SceneObject's.
pub fn getY(g: *Game, obj: *Object) i16 {
    _ = g;
    _ = obj;
    stub.unported("tiro.position.getY");
}

/// SceneObject slot 0A getStepX: mover_get_step_x (crossbow, target, arrow) / default.
pub fn getStepX(g: *Game, obj: *Object) i16 {
    _ = g;
    _ = obj;
    stub.unported("tiro.position.getStepX");
}

/// SceneObject slot 0B getStepY: mover_get_step_y (crossbow, target, arrow) / default.
pub fn getStepY(g: *Game, obj: *Object) i16 {
    _ = g;
    _ = obj;
    stub.unported("tiro.position.getStepY");
}

/// SceneObject slot 0C slot11 (default only).
pub fn slot11(g: *Game, obj: *Object, arg: u16) i16 {
    _ = g;
    _ = obj;
    _ = arg;
    stub.unported("tiro.position.slot11");
}

/// SceneObject slot 39 setPosition: actor2d_set_position (crossbow, target, arrow) / SceneObject's.
pub fn setPosition(g: *Game, obj: *Object, x: i16, y: i16) void {
    _ = g;
    _ = obj;
    _ = x;
    _ = y;
    stub.unported("tiro.position.setPosition");
}

/// SceneObject slot 4C unk4E (returns "").
pub fn unk4E(g: *Game, obj: *Object) []const u8 {
    _ = g;
    _ = obj;
    stub.unported("tiro.position.unk4E");
}

/// SceneObject slot 4E hitboxOverlaps.
pub fn hitboxOverlaps(g: *Game, obj: *Object, other: *Object) bool {
    _ = g;
    _ = obj;
    _ = other;
    stub.unported("tiro.position.hitboxOverlaps");
}

/// SceneObject slot 4F boundsOverlap.
pub fn boundsOverlap(g: *Game, obj: *Object, other: *Object) bool {
    _ = g;
    _ = obj;
    _ = other;
    stub.unported("tiro.position.boundsOverlap");
}

/// SceneObject slot 50 slot5B (default only).
pub fn slot5B(g: *Game, obj: *Object, arg: i16) i16 {
    _ = g;
    _ = obj;
    _ = arg;
    stub.unported("tiro.position.slot5B");
}

/// SceneObject slot 51 slot5C (default only).
pub fn slot5C(g: *Game, obj: *Object, arg: i16) i16 {
    _ = g;
    _ = obj;
    _ = arg;
    stub.unported("tiro.position.slot5C");
}

/// SceneObject slot 54 isEnabled (default only).
pub fn isEnabled(g: *Game, obj: *Object) bool {
    _ = g;
    _ = obj;
    stub.unported("tiro.position.isEnabled");
}

/// SceneObject slot 55 getExitIndex (default only).
pub fn getExitIndex(g: *Game, obj: *Object) i16 {
    _ = g;
    _ = obj;
    stub.unported("tiro.position.getExitIndex");
}
