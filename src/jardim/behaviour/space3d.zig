//! Port unit `space3d` (behaviour) of JARDIM.EXE. SceneObject slots 05-0C 12-16 3D (Object3D getters and setters, drawBounds, moveToAndDrop) and the Object3DVtbl slots, the perspective math.
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

/// Object3DVtbl.findSupport's result (the out parameter joins the return).
pub const Support = struct {
    result: i16 = 0,
    support: ?*Object = null,
};

/// SceneObject slot 05 getWorldX: object3d_world_x (portable, exit, player, control_panel) / default.
pub fn getWorldX(g: *Game, obj: *Object) i16 {
    _ = g;
    _ = obj;
    stub.unported("jardim.space3d.getWorldX");
}

/// SceneObject slot 06 getWorldDepth: object3d_world_depth (portable, exit, player, control_panel) / default.
pub fn getWorldDepth(g: *Game, obj: *Object) i16 {
    _ = g;
    _ = obj;
    stub.unported("jardim.space3d.getWorldDepth");
}

/// SceneObject slot 07 getWorldElev: object3d_world_elev (portable, exit, player, control_panel) / default.
pub fn getWorldElev(g: *Game, obj: *Object) i16 {
    _ = g;
    _ = obj;
    stub.unported("jardim.space3d.getWorldElev");
}

/// SceneObject slot 08 getSizeW: object3d_size_w (portable, exit, player, control_panel) / default.
pub fn getSizeW(g: *Game, obj: *Object) i16 {
    _ = g;
    _ = obj;
    stub.unported("jardim.space3d.getSizeW");
}

/// SceneObject slot 09 getSizeH: object3d_size_h (portable, exit, player, control_panel) / default.
pub fn getSizeH(g: *Game, obj: *Object) i16 {
    _ = g;
    _ = obj;
    stub.unported("jardim.space3d.getSizeH");
}

/// SceneObject slot 0A getSizeD: object3d_size_d (portable, exit, player, control_panel) / default.
pub fn getSizeD(g: *Game, obj: *Object) i16 {
    _ = g;
    _ = obj;
    stub.unported("jardim.space3d.getSizeD");
}

/// SceneObject slot 0B getAnchorX: object3d_anchor_x (portable, exit, player, control_panel) / default.
pub fn getAnchorX(g: *Game, obj: *Object) i16 {
    _ = g;
    _ = obj;
    stub.unported("jardim.space3d.getAnchorX");
}

/// SceneObject slot 0C getAnchorY: object3d_anchor_y (portable, exit, player, control_panel) / default.
pub fn getAnchorY(g: *Game, obj: *Object) i16 {
    _ = g;
    _ = obj;
    stub.unported("jardim.space3d.getAnchorY");
}

/// SceneObject slot 12 setElevation: portable_set_elevation (portable), object3d_set_elevation (exit, control_panel), moveable_set_elevation (player) / default.
pub fn setElevation(g: *Game, obj: *Object, bd: *Backdrop, elev: i16) ?*Object {
    _ = g;
    _ = obj;
    _ = bd;
    _ = elev;
    stub.unported("jardim.space3d.setElevation");
}

/// SceneObject slot 13 setAnchor: object3d_set_anchor (portable, exit, player, control_panel) / default.
pub fn setAnchor(g: *Game, obj: *Object, x: i16, y: i16) ?*Object {
    _ = g;
    _ = obj;
    _ = x;
    _ = y;
    stub.unported("jardim.space3d.setAnchor");
}

/// SceneObject slot 14 setSize: object3d_set_size (portable, exit, player, control_panel) / default.
pub fn setSize(g: *Game, obj: *Object, w: i16, h: i16, d: i16) ?*Object {
    _ = g;
    _ = obj;
    _ = w;
    _ = h;
    _ = d;
    stub.unported("jardim.space3d.setSize");
}

/// SceneObject slot 15 setWorldElev: portable_set_world_elev (portable) / default.
pub fn setWorldElev(g: *Game, obj: *Object, elev: i16) ?*Object {
    _ = g;
    _ = obj;
    _ = elev;
    stub.unported("jardim.space3d.setWorldElev");
}

/// SceneObject slot 16 drawBounds (hdc dropped): object3d_draw_bounds (portable, exit, player, control_panel) / default.
pub fn drawBounds(g: *Game, obj: *Object, bd: *Backdrop) ?*Object {
    _ = g;
    _ = obj;
    _ = bd;
    stub.unported("jardim.space3d.drawBounds");
}

/// SceneObject slot 3D moveToAndDrop: portable_move_to_and_drop (portable), object3d_move_to_and_drop (exit, control_panel), moveable_move_to_and_drop (player) / default.
pub fn moveToAndDrop(g: *Game, obj: *Object, x: i16, y: i16, bd: *Backdrop) void {
    _ = g;
    _ = obj;
    _ = x;
    _ = y;
    _ = bd;
    stub.unported("jardim.space3d.moveToAndDrop");
}

/// Object3DVtbl slot 00 (object3d_slot00).
pub fn slot00(g: *Game, obj: *Object) i16 {
    _ = g;
    _ = obj;
    stub.unported("jardim.space3d.slot00");
}

/// Object3DVtbl slot 01 findSupport: the support found (out parameter) and the result.
pub fn findSupport(g: *Game, obj: *Object, bd: *Backdrop) Support {
    _ = g;
    _ = obj;
    _ = bd;
    stub.unported("jardim.space3d.findSupport");
}

/// Object3DVtbl slot 02 isBelow (portable_is_below for the Portables).
pub fn isBelow(g: *Game, obj: *Object, other: *Object, bd: *Backdrop) bool {
    _ = g;
    _ = obj;
    _ = other;
    _ = bd;
    stub.unported("jardim.space3d.isBelow");
}

/// Object3DVtbl slot 03 isAboveOnScreen.
pub fn isAboveOnScreen(g: *Game, obj: *Object, other: *Object, bd: *Backdrop) bool {
    _ = g;
    _ = obj;
    _ = other;
    _ = bd;
    stub.unported("jardim.space3d.isAboveOnScreen");
}

/// Object3DVtbl slot 04 isInFrontOf (the draw list's order).
pub fn isInFrontOf(g: *Game, obj: *Object, other: *Object, bd: *Backdrop) bool {
    _ = g;
    _ = obj;
    _ = other;
    _ = bd;
    stub.unported("jardim.space3d.isInFrontOf");
}

/// Object3DVtbl slot 05 overlaps3d.
pub fn overlaps3d(g: *Game, obj: *Object, other: *Object, bd: *Backdrop) bool {
    _ = g;
    _ = obj;
    _ = other;
    _ = bd;
    stub.unported("jardim.space3d.overlaps3d");
}

/// Object3DVtbl slot 06 moveToAtElev (object3d_/moveable_/portable_move_to_at_elev).
pub fn moveToAtElev(g: *Game, obj: *Object, x: i16, y: i16, bd: *Backdrop, elev: i16) void {
    _ = g;
    _ = obj;
    _ = x;
    _ = y;
    _ = bd;
    _ = elev;
    stub.unported("jardim.space3d.moveToAtElev");
}

/// Object3DVtbl slot 07 dropToSupport (object3d_/moveable_/portable_drop_to_support).
pub fn dropToSupport(g: *Game, obj: *Object, bd: *Backdrop) void {
    _ = g;
    _ = obj;
    _ = bd;
    stub.unported("jardim.space3d.dropToSupport");
}
