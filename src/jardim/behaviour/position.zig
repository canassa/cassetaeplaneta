//! Port unit `position` (behaviour) of JARDIM.EXE. SceneObject slots 00-04 (slot00/01, RLE, scene name), 0D-11 getX/getY/getStep, 3E setPosition, 3F/40 scroll target, 54-57 overlaps, 5A/5B exit slots, 5C-60 defaults; the out-of-line accessors; next_object_id, message_box_printf.
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

/// SceneObject slot 00 slot00 (default only).
pub fn slot00(g: *Game, obj: *Object) void {
    _ = g;
    _ = obj;
    stub.unported("jardim.position.slot00");
}

/// SceneObject slot 01 slot01 (default only).
pub fn slot01(g: *Game, obj: *Object) i16 {
    _ = g;
    _ = obj;
    stub.unported("jardim.position.slot01");
}

/// SceneObject slot 02 enableRle (SceneObject's: scene_object_enable_rle).
pub fn enableRle(g: *Game, obj: *Object) void {
    _ = g;
    _ = obj;
    stub.unported("jardim.position.enableRle");
}

/// SceneObject slot 03 isRle (SceneObject's: scene_object_is_rle).
pub fn isRle(g: *Game, obj: *Object) bool {
    _ = g;
    _ = obj;
    stub.unported("jardim.position.isRle");
}

/// SceneObject slot 04 getSceneName (SceneObject's: scene_object_get_scene_name).
pub fn getSceneName(g: *Game, obj: *Object) []const u8 {
    _ = g;
    _ = obj;
    stub.unported("jardim.position.getSceneName");
}

/// SceneObject slot 0D getX: mover_get_x (portable, player) / SceneObject's.
pub fn getX(g: *Game, obj: *Object) i16 {
    _ = g;
    _ = obj;
    stub.unported("jardim.position.getX");
}

/// SceneObject slot 0E getY: mover_get_y (portable, player) / SceneObject's.
pub fn getY(g: *Game, obj: *Object) i16 {
    _ = g;
    _ = obj;
    stub.unported("jardim.position.getY");
}

/// SceneObject slot 0F getStepX: mover_get_step_x (portable, player) / default.
pub fn getStepX(g: *Game, obj: *Object) i16 {
    _ = g;
    _ = obj;
    stub.unported("jardim.position.getStepX");
}

/// SceneObject slot 10 getStepY: mover_get_step_y (portable, player) / default.
pub fn getStepY(g: *Game, obj: *Object) i16 {
    _ = g;
    _ = obj;
    stub.unported("jardim.position.getStepY");
}

/// SceneObject slot 11 slot11 (default only).
pub fn slot11(g: *Game, obj: *Object, arg1: i16, arg2: i16) i16 {
    _ = g;
    _ = obj;
    _ = arg1;
    _ = arg2;
    stub.unported("jardim.position.slot11");
}

/// SceneObject slot 3E setPosition: moveable_set_position (portable, player) / SceneObject's.
pub fn setPosition(g: *Game, obj: *Object, x: i16, y: i16) void {
    _ = g;
    _ = obj;
    _ = x;
    _ = y;
    stub.unported("jardim.position.setPosition");
}

/// SceneObject slot 3F isScrollTarget: player_is_scroll_target (player) / SceneObject's.
pub fn isScrollTarget(g: *Game, obj: *Object) bool {
    _ = g;
    _ = obj;
    stub.unported("jardim.position.isScrollTarget");
}

/// SceneObject slot 40 slot43 (default only).
pub fn slot43(g: *Game, obj: *Object) ?*anyopaque {
    _ = g;
    _ = obj;
    stub.unported("jardim.position.slot43");
}

/// SceneObject slot 54 hitboxOverlaps (SceneObject's).
pub fn hitboxOverlaps(g: *Game, obj: *Object, other: *Object) bool {
    _ = g;
    _ = obj;
    _ = other;
    stub.unported("jardim.position.hitboxOverlaps");
}

/// SceneObject slot 55 boundsOverlap (SceneObject's).
pub fn boundsOverlap(g: *Game, obj: *Object, other: *Object) bool {
    _ = g;
    _ = obj;
    _ = other;
    stub.unported("jardim.position.boundsOverlap");
}

/// SceneObject slot 56 slot5B (default only).
pub fn slot5B(g: *Game, obj: *Object, arg: ?*anyopaque) i16 {
    _ = g;
    _ = obj;
    _ = arg;
    stub.unported("jardim.position.slot5B");
}

/// SceneObject slot 57 slot5C (default only).
pub fn slot5C(g: *Game, obj: *Object, arg: ?*anyopaque) i16 {
    _ = g;
    _ = obj;
    _ = arg;
    stub.unported("jardim.position.slot5C");
}

/// SceneObject slot 5A isEnabled: exit_is_enabled (exit) / default.
pub fn isEnabled(g: *Game, obj: *Object) bool {
    _ = g;
    _ = obj;
    stub.unported("jardim.position.isEnabled");
}

/// SceneObject slot 5B getExitIndex: exit_get_exit_index (exit) / default.
pub fn getExitIndex(g: *Game, obj: *Object) i16 {
    _ = g;
    _ = obj;
    stub.unported("jardim.position.getExitIndex");
}

/// SceneObject slot 5C slot61 (default only).
pub fn slot61(g: *Game, obj: *Object) i16 {
    _ = g;
    _ = obj;
    stub.unported("jardim.position.slot61");
}

/// SceneObject slot 5D slot62 (default only).
pub fn slot62(g: *Game, obj: *Object) i16 {
    _ = g;
    _ = obj;
    stub.unported("jardim.position.slot62");
}

/// SceneObject slot 5E slot63 (default only).
pub fn slot63(g: *Game, obj: *Object) i16 {
    _ = g;
    _ = obj;
    stub.unported("jardim.position.slot63");
}

/// SceneObject slot 5F slot64 (default only).
pub fn slot64(g: *Game, obj: *Object) i16 {
    _ = g;
    _ = obj;
    stub.unported("jardim.position.slot64");
}

/// SceneObject slot 60 slot65 (default only).
pub fn slot65(g: *Game, obj: *Object) i16 {
    _ = g;
    _ = obj;
    stub.unported("jardim.position.slot65");
}
