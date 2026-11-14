//! Port unit `position` (behaviour) of ENCAIXE.EXE. SceneObject slots 08-0C getX/getY/getStep, 3B setPosition, 4E unk4E, 50/51 overlap tests, 52-5C defaults; next_object_id.
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

/// SceneObject slot 08 getX: Mover's (piece) / SceneObject's.
pub fn getX(g: *Game, obj: *Object) i16 {
    _ = g;
    _ = obj;
    stub.unported("encaixe.position.getX");
}

/// SceneObject slot 09 getY.
pub fn getY(g: *Game, obj: *Object) i16 {
    _ = g;
    _ = obj;
    stub.unported("encaixe.position.getY");
}

/// SceneObject slot 0A getStepX: Mover's (piece) / default.
pub fn getStepX(g: *Game, obj: *Object) i16 {
    _ = g;
    _ = obj;
    stub.unported("encaixe.position.getStepX");
}

/// SceneObject slot 0B getStepY.
pub fn getStepY(g: *Game, obj: *Object) i16 {
    _ = g;
    _ = obj;
    stub.unported("encaixe.position.getStepY");
}

/// SceneObject slot 0C slot11 (default only).
pub fn slot11(g: *Game, obj: *Object, arg: u16) i16 {
    _ = g;
    _ = obj;
    _ = arg;
    stub.unported("encaixe.position.slot11");
}

/// SceneObject slot 3B setPosition: Actor2D's (piece) / SceneObject's.
pub fn setPosition(g: *Game, obj: *Object, x: i16, y: i16) void {
    _ = g;
    _ = obj;
    _ = x;
    _ = y;
    stub.unported("encaixe.position.setPosition");
}

/// SceneObject slot 4E unk4E (returns "").
pub fn unk4E(g: *Game, obj: *Object) []const u8 {
    _ = g;
    _ = obj;
    stub.unported("encaixe.position.unk4E");
}

/// SceneObject slot 50 hitboxOverlaps.
pub fn hitboxOverlaps(g: *Game, obj: *Object, other: *Object) bool {
    _ = g;
    _ = obj;
    _ = other;
    stub.unported("encaixe.position.hitboxOverlaps");
}

/// SceneObject slot 51 boundsOverlap.
pub fn boundsOverlap(g: *Game, obj: *Object, other: *Object) bool {
    _ = g;
    _ = obj;
    _ = other;
    stub.unported("encaixe.position.boundsOverlap");
}

/// SceneObject slot 52 slot5B (default only).
pub fn slot5B(g: *Game, obj: *Object, arg: i16) i16 {
    _ = g;
    _ = obj;
    _ = arg;
    stub.unported("encaixe.position.slot5B");
}

/// SceneObject slot 53 slot5C (default only).
pub fn slot5C(g: *Game, obj: *Object, arg: i16) i16 {
    _ = g;
    _ = obj;
    _ = arg;
    stub.unported("encaixe.position.slot5C");
}

/// SceneObject slot 56 isEnabled (default only).
pub fn isEnabled(g: *Game, obj: *Object) bool {
    _ = g;
    _ = obj;
    stub.unported("encaixe.position.isEnabled");
}

/// SceneObject slot 57 getExitIndex (default only).
pub fn getExitIndex(g: *Game, obj: *Object) i16 {
    _ = g;
    _ = obj;
    stub.unported("encaixe.position.getExitIndex");
}
