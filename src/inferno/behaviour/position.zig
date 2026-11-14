//! Port unit `position` (behaviour) of INFERNO.EXE. SceneObject slots 00-11
//! 38 (Object3D getters/setters: defaults only, INFERNO builds no Object3D),
//! 08-0C getX/getY/getStep, 39 setPosition, 4C getSceneName, 4E/4F overlap
//! tests, 50/51 54/55 defaults; the /Od out-of-line accessors (strip, size,
//! frame, dib); next_object_id, message_box_printf.
//!
//! Virtual-slot dispatchers owned by this unit are declared below with
//! their final signatures; their bodies panic until the unit is ported
//! (docs/inferno/DESIGN.md "Virtual slots"). Replace each body, keep the
//! signature (other units already call it). Each implementation function
//! carries `// @orig <seg:xxxx> <name>` with the INFERNO address.

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

/// SceneObject slot 00 getWorldX: default only
/// (scene_object_get_world_x_default; INFERNO builds no Object3D).
pub fn getWorldX(g: *Game, obj: *Object) i16 {
    _ = g;
    _ = obj;
    stub.unported("inferno.position.getWorldX");
}

/// SceneObject slot 01 getWorldDepth: default only.
pub fn getWorldDepth(g: *Game, obj: *Object) i16 {
    _ = g;
    _ = obj;
    stub.unported("inferno.position.getWorldDepth");
}

/// SceneObject slot 02 getWorldElev: default only.
pub fn getWorldElev(g: *Game, obj: *Object) i16 {
    _ = g;
    _ = obj;
    stub.unported("inferno.position.getWorldElev");
}

/// SceneObject slot 03 getSizeW: default only.
pub fn getSizeW(g: *Game, obj: *Object) i16 {
    _ = g;
    _ = obj;
    stub.unported("inferno.position.getSizeW");
}

/// SceneObject slot 04 getSizeH: default only.
pub fn getSizeH(g: *Game, obj: *Object) i16 {
    _ = g;
    _ = obj;
    stub.unported("inferno.position.getSizeH");
}

/// SceneObject slot 05 getSizeD: default only.
pub fn getSizeD(g: *Game, obj: *Object) i16 {
    _ = g;
    _ = obj;
    stub.unported("inferno.position.getSizeD");
}

/// SceneObject slot 06 getAnchorX: default only.
pub fn getAnchorX(g: *Game, obj: *Object) i16 {
    _ = g;
    _ = obj;
    stub.unported("inferno.position.getAnchorX");
}

/// SceneObject slot 07 getAnchorY: default only.
pub fn getAnchorY(g: *Game, obj: *Object) i16 {
    _ = g;
    _ = obj;
    stub.unported("inferno.position.getAnchorY");
}

/// SceneObject slot 08 getX: mover_get_x (hero, platform, prop, hazard).
pub fn getX(g: *Game, obj: *Object) i16 {
    _ = g;
    _ = obj;
    stub.unported("inferno.position.getX");
}

/// SceneObject slot 09 getY: mover_get_y (every kind).
pub fn getY(g: *Game, obj: *Object) i16 {
    _ = g;
    _ = obj;
    stub.unported("inferno.position.getY");
}

/// SceneObject slot 0A getStepX: mover_get_step_x (every kind).
pub fn getStepX(g: *Game, obj: *Object) i16 {
    _ = g;
    _ = obj;
    stub.unported("inferno.position.getStepX");
}

/// SceneObject slot 0B getStepY: mover_get_step_y (every kind).
pub fn getStepY(g: *Game, obj: *Object) i16 {
    _ = g;
    _ = obj;
    stub.unported("inferno.position.getStepY");
}

/// SceneObject slot 0C slot11: default only.
pub fn slot11(g: *Game, obj: *Object, arg: u16) i16 {
    _ = g;
    _ = obj;
    _ = arg;
    stub.unported("inferno.position.slot11");
}

/// SceneObject slot 0D setElevation (Ghidra: this, elev, backdrop): default
/// only.
pub fn setElevation(g: *Game, obj: *Object, bd: *Backdrop, elev: i16) ?*Object {
    _ = g;
    _ = obj;
    _ = bd;
    _ = elev;
    stub.unported("inferno.position.setElevation");
}

/// SceneObject slot 0E setAnchor: default only.
pub fn setAnchor(g: *Game, obj: *Object, x: i16, y: i16) ?*Object {
    _ = g;
    _ = obj;
    _ = x;
    _ = y;
    stub.unported("inferno.position.setAnchor");
}

/// SceneObject slot 0F setSize: default only.
pub fn setSize(g: *Game, obj: *Object, w: i16, h: i16, d: i16) ?*Object {
    _ = g;
    _ = obj;
    _ = w;
    _ = h;
    _ = d;
    stub.unported("inferno.position.setSize");
}

/// SceneObject slot 10 setWorldElev: default only.
pub fn setWorldElev(g: *Game, obj: *Object, elev: i16) ?*Object {
    _ = g;
    _ = obj;
    _ = elev;
    stub.unported("inferno.position.setWorldElev");
}

/// SceneObject slot 11 drawBounds (hdc dropped): default only.
pub fn drawBounds(g: *Game, obj: *Object, bd: *Backdrop) ?*Object {
    _ = g;
    _ = obj;
    _ = bd;
    stub.unported("inferno.position.drawBounds");
}

/// SceneObject slot 38 moveToAndDrop: default only.
pub fn moveToAndDrop(g: *Game, obj: *Object, x: i16, y: i16, bd: *Backdrop) void {
    _ = g;
    _ = obj;
    _ = x;
    _ = y;
    _ = bd;
    stub.unported("inferno.position.moveToAndDrop");
}

/// SceneObject slot 39 setPosition: actor2d_set_position (every kind) /
/// scene_object_set_position.
pub fn setPosition(g: *Game, obj: *Object, x: i16, y: i16) void {
    _ = g;
    _ = obj;
    _ = x;
    _ = y;
    stub.unported("inferno.position.setPosition");
}

/// SceneObject slot 4C getSceneName: default only ("").
pub fn getSceneName(g: *Game, obj: *Object) []const u8 {
    _ = g;
    _ = obj;
    stub.unported("inferno.position.getSceneName");
}

/// SceneObject slot 4E hitboxOverlaps (scene_object_hitbox_overlaps).
pub fn hitboxOverlaps(g: *Game, obj: *Object, other: *Object) bool {
    _ = g;
    _ = obj;
    _ = other;
    stub.unported("inferno.position.hitboxOverlaps");
}

/// SceneObject slot 4F boundsOverlap (scene_object_bounds_overlap).
pub fn boundsOverlap(g: *Game, obj: *Object, other: *Object) bool {
    _ = g;
    _ = obj;
    _ = other;
    stub.unported("inferno.position.boundsOverlap");
}

/// SceneObject slot 50 slot5B: default only.
pub fn slot5B(g: *Game, obj: *Object, arg: i16) i16 {
    _ = g;
    _ = obj;
    _ = arg;
    stub.unported("inferno.position.slot5B");
}

/// SceneObject slot 51 slot5C: default only.
pub fn slot5C(g: *Game, obj: *Object, arg: i16) i16 {
    _ = g;
    _ = obj;
    _ = arg;
    stub.unported("inferno.position.slot5C");
}

/// SceneObject slot 54 isEnabled: default only.
pub fn isEnabled(g: *Game, obj: *Object) bool {
    _ = g;
    _ = obj;
    stub.unported("inferno.position.isEnabled");
}

/// SceneObject slot 55 getExitIndex: default only.
pub fn getExitIndex(g: *Game, obj: *Object) i16 {
    _ = g;
    _ = obj;
    stub.unported("inferno.position.getExitIndex");
}
