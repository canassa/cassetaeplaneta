//! Port unit `space3d` (behaviour) of TIRO.EXE. SceneObject slots 00-07 0D-11 38 (Object3D getters/setters, drawBounds), the Object3DVtbl slots, the perspective math.
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

/// Object3DVtbl findSupport's results: the return value and `*out_support`.
pub const Support = struct { result: i16 = 0, support: ?*Object = null };

/// SceneObject slot 00 getWorldX: object3d_get_world_x (panel) / default.
pub fn getWorldX(g: *Game, obj: *Object) i16 {
    _ = g;
    _ = obj;
    stub.unported("tiro.space3d.getWorldX");
}

/// SceneObject slot 01 getWorldDepth: object3d_get_world_depth (panel) / default.
pub fn getWorldDepth(g: *Game, obj: *Object) i16 {
    _ = g;
    _ = obj;
    stub.unported("tiro.space3d.getWorldDepth");
}

/// SceneObject slot 02 getWorldElev: object3d_get_world_elev (panel) / default.
pub fn getWorldElev(g: *Game, obj: *Object) i16 {
    _ = g;
    _ = obj;
    stub.unported("tiro.space3d.getWorldElev");
}

/// SceneObject slot 03 getSizeW: object3d_get_size_w (panel) / default.
pub fn getSizeW(g: *Game, obj: *Object) i16 {
    _ = g;
    _ = obj;
    stub.unported("tiro.space3d.getSizeW");
}

/// SceneObject slot 04 getSizeH: object3d_get_size_h (panel) / default.
pub fn getSizeH(g: *Game, obj: *Object) i16 {
    _ = g;
    _ = obj;
    stub.unported("tiro.space3d.getSizeH");
}

/// SceneObject slot 05 getSizeD: object3d_get_size_d (panel) / default.
pub fn getSizeD(g: *Game, obj: *Object) i16 {
    _ = g;
    _ = obj;
    stub.unported("tiro.space3d.getSizeD");
}

/// SceneObject slot 06 getAnchorX: object3d_get_anchor_x (panel) / default.
pub fn getAnchorX(g: *Game, obj: *Object) i16 {
    _ = g;
    _ = obj;
    stub.unported("tiro.space3d.getAnchorX");
}

/// SceneObject slot 07 getAnchorY: object3d_get_anchor_y (panel) / default.
pub fn getAnchorY(g: *Game, obj: *Object) i16 {
    _ = g;
    _ = obj;
    stub.unported("tiro.space3d.getAnchorY");
}

/// SceneObject slot 0D setElevation (Ghidra: this, elev, backdrop): object3d_set_elevation (panel) / default.
pub fn setElevation(g: *Game, obj: *Object, bd: *Backdrop, elev: i16) ?*Object {
    _ = g;
    _ = obj;
    _ = bd;
    _ = elev;
    stub.unported("tiro.space3d.setElevation");
}

/// SceneObject slot 0E setAnchor: object3d_set_anchor (panel) / default.
pub fn setAnchor(g: *Game, obj: *Object, x: i16, y: i16) ?*Object {
    _ = g;
    _ = obj;
    _ = x;
    _ = y;
    stub.unported("tiro.space3d.setAnchor");
}

/// SceneObject slot 0F setSize: object3d_set_size (panel) / default.
pub fn setSize(g: *Game, obj: *Object, w: i16, h: i16, d: i16) ?*Object {
    _ = g;
    _ = obj;
    _ = w;
    _ = h;
    _ = d;
    stub.unported("tiro.space3d.setSize");
}

/// SceneObject slot 10 setWorldElev (default only).
pub fn setWorldElev(g: *Game, obj: *Object, elev: i16) ?*Object {
    _ = g;
    _ = obj;
    _ = elev;
    stub.unported("tiro.space3d.setWorldElev");
}

/// SceneObject slot 11 drawBounds (hdc dropped): object3d_draw_bounds (panel) / default.
pub fn drawBounds(g: *Game, obj: *Object, bd: *Backdrop) ?*Object {
    _ = g;
    _ = obj;
    _ = bd;
    stub.unported("tiro.space3d.drawBounds");
}

/// SceneObject slot 38 moveToAndDrop: object3d_move_to_and_drop (panel) / default.
pub fn moveToAndDrop(g: *Game, obj: *Object, x: i16, y: i16, bd: *Backdrop) void {
    _ = g;
    _ = obj;
    _ = x;
    _ = y;
    _ = bd;
    stub.unported("tiro.space3d.moveToAndDrop");
}

/// Object3DVtbl slot 00 (object3d_slot00).
pub fn slot00(g: *Game, obj: *Object) i16 {
    _ = g;
    _ = obj;
    stub.unported("tiro.space3d.slot00");
}

/// Object3DVtbl slot 01 findSupport: the support found (out parameter) and the result.
pub fn findSupport(g: *Game, obj: *Object, bd: *Backdrop) Support {
    _ = g;
    _ = obj;
    _ = bd;
    stub.unported("tiro.space3d.findSupport");
}

/// Object3DVtbl slot 02 isBelow.
pub fn isBelow(g: *Game, obj: *Object, other: *Object, bd: *Backdrop) bool {
    _ = g;
    _ = obj;
    _ = other;
    _ = bd;
    stub.unported("tiro.space3d.isBelow");
}

/// Object3DVtbl slot 03 isAboveOnScreen.
pub fn isAboveOnScreen(g: *Game, obj: *Object, other: *Object, bd: *Backdrop) bool {
    _ = g;
    _ = obj;
    _ = other;
    _ = bd;
    stub.unported("tiro.space3d.isAboveOnScreen");
}

/// Object3DVtbl slot 04 isInFrontOf (the draw list's order).
pub fn isInFrontOf(g: *Game, obj: *Object, other: *Object, bd: *Backdrop) bool {
    _ = g;
    _ = obj;
    _ = other;
    _ = bd;
    stub.unported("tiro.space3d.isInFrontOf");
}

/// Object3DVtbl slot 05 overlaps3d.
pub fn overlaps3d(g: *Game, obj: *Object, other: *Object, bd: *Backdrop) bool {
    _ = g;
    _ = obj;
    _ = other;
    _ = bd;
    stub.unported("tiro.space3d.overlaps3d");
}

/// Object3DVtbl slot 06 moveToAtElev.
pub fn moveToAtElev(g: *Game, obj: *Object, x: i16, y: i16, bd: *Backdrop, elev: i16) void {
    _ = g;
    _ = obj;
    _ = x;
    _ = y;
    _ = bd;
    _ = elev;
    stub.unported("tiro.space3d.moveToAtElev");
}

/// Object3DVtbl slot 07 dropToSupport.
pub fn dropToSupport(g: *Game, obj: *Object, bd: *Backdrop) void {
    _ = g;
    _ = obj;
    _ = bd;
    stub.unported("tiro.space3d.dropToSupport");
}
