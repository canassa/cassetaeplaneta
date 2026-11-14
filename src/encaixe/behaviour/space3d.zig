//! Port unit `space3d` (behaviour) of ENCAIXE.EXE. SceneObject slots 00-07 0D-12 3A (Object3D getters/setters, unk11, drawBounds), the Object3DVtbl slots, the perspective math.
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

/// Object3DVtbl findSupport's results: the return value and `*out_support`.
pub const Support = struct { result: i16 = 0, support: ?*Object = null };

/// SceneObject slot 00 getWorldX: Object3D's (control_panel) / default 0.
pub fn getWorldX(g: *Game, obj: *Object) i16 {
    _ = g;
    _ = obj;
    stub.unported("encaixe.space3d.getWorldX");
}

/// SceneObject slot 01 getWorldDepth.
pub fn getWorldDepth(g: *Game, obj: *Object) i16 {
    _ = g;
    _ = obj;
    stub.unported("encaixe.space3d.getWorldDepth");
}

/// SceneObject slot 02 getWorldElev.
pub fn getWorldElev(g: *Game, obj: *Object) i16 {
    _ = g;
    _ = obj;
    stub.unported("encaixe.space3d.getWorldElev");
}

/// SceneObject slot 03 getSizeW.
pub fn getSizeW(g: *Game, obj: *Object) i16 {
    _ = g;
    _ = obj;
    stub.unported("encaixe.space3d.getSizeW");
}

/// SceneObject slot 04 getSizeH.
pub fn getSizeH(g: *Game, obj: *Object) i16 {
    _ = g;
    _ = obj;
    stub.unported("encaixe.space3d.getSizeH");
}

/// SceneObject slot 05 getSizeD.
pub fn getSizeD(g: *Game, obj: *Object) i16 {
    _ = g;
    _ = obj;
    stub.unported("encaixe.space3d.getSizeD");
}

/// SceneObject slot 06 getAnchorX.
pub fn getAnchorX(g: *Game, obj: *Object) i16 {
    _ = g;
    _ = obj;
    stub.unported("encaixe.space3d.getAnchorX");
}

/// SceneObject slot 07 getAnchorY.
pub fn getAnchorY(g: *Game, obj: *Object) i16 {
    _ = g;
    _ = obj;
    stub.unported("encaixe.space3d.getAnchorY");
}

/// SceneObject slot 0D setElevation (Ghidra: this, elev, backdrop).
pub fn setElevation(g: *Game, obj: *Object, bd: *Backdrop, elev: i16) ?*Object {
    _ = g;
    _ = obj;
    _ = bd;
    _ = elev;
    stub.unported("encaixe.space3d.setElevation");
}

/// SceneObject slot 0E setAnchor.
pub fn setAnchor(g: *Game, obj: *Object, x: i16, y: i16) ?*Object {
    _ = g;
    _ = obj;
    _ = x;
    _ = y;
    stub.unported("encaixe.space3d.setAnchor");
}

/// SceneObject slot 0F setSize.
pub fn setSize(g: *Game, obj: *Object, w: i16, h: i16, d: i16) ?*Object {
    _ = g;
    _ = obj;
    _ = w;
    _ = h;
    _ = d;
    stub.unported("encaixe.space3d.setSize");
}

/// SceneObject slot 10 setWorldElev (default only).
pub fn setWorldElev(g: *Game, obj: *Object, elev: i16) ?*Object {
    _ = g;
    _ = obj;
    _ = elev;
    stub.unported("encaixe.space3d.setWorldElev");
}

/// SceneObject slot 11 unk11 (ENCAIXE-only; Object3D: GetDC + ReleaseDC, returns this; hwnd dropped).
pub fn unk11(g: *Game, obj: *Object, arg: i16) ?*Object {
    _ = g;
    _ = obj;
    _ = arg;
    stub.unported("encaixe.space3d.unk11");
}

/// SceneObject slot 12 drawBounds (hdc dropped).
pub fn drawBounds(g: *Game, obj: *Object, bd: *Backdrop) ?*Object {
    _ = g;
    _ = obj;
    _ = bd;
    stub.unported("encaixe.space3d.drawBounds");
}

/// SceneObject slot 3A moveToAndDrop.
pub fn moveToAndDrop(g: *Game, obj: *Object, x: i16, y: i16, bd: *Backdrop) void {
    _ = g;
    _ = obj;
    _ = x;
    _ = y;
    _ = bd;
    stub.unported("encaixe.space3d.moveToAndDrop");
}

/// Object3DVtbl slot 00 (object3d_slot00).
pub fn slot00(g: *Game, obj: *Object) i16 {
    _ = g;
    _ = obj;
    stub.unported("encaixe.space3d.slot00");
}

/// Object3DVtbl slot 01 findSupport: the support found (out parameter) and the result.
pub fn findSupport(g: *Game, obj: *Object, bd: *Backdrop) Support {
    _ = g;
    _ = obj;
    _ = bd;
    stub.unported("encaixe.space3d.findSupport");
}

/// Object3DVtbl slot 02 isBelow.
pub fn isBelow(g: *Game, obj: *Object, other: *Object, bd: *Backdrop) bool {
    _ = g;
    _ = obj;
    _ = other;
    _ = bd;
    stub.unported("encaixe.space3d.isBelow");
}

/// Object3DVtbl slot 03 isAboveOnScreen.
pub fn isAboveOnScreen(g: *Game, obj: *Object, other: *Object, bd: *Backdrop) bool {
    _ = g;
    _ = obj;
    _ = other;
    _ = bd;
    stub.unported("encaixe.space3d.isAboveOnScreen");
}

/// Object3DVtbl slot 04 isInFrontOf (the draw list's order).
pub fn isInFrontOf(g: *Game, obj: *Object, other: *Object, bd: *Backdrop) bool {
    _ = g;
    _ = obj;
    _ = other;
    _ = bd;
    stub.unported("encaixe.space3d.isInFrontOf");
}

/// Object3DVtbl slot 05 overlaps3d.
pub fn overlaps3d(g: *Game, obj: *Object, other: *Object, bd: *Backdrop) bool {
    _ = g;
    _ = obj;
    _ = other;
    _ = bd;
    stub.unported("encaixe.space3d.overlaps3d");
}

/// Object3DVtbl slot 06 moveToAtElev.
pub fn moveToAtElev(g: *Game, obj: *Object, x: i16, y: i16, bd: *Backdrop, elev: i16) void {
    _ = g;
    _ = obj;
    _ = x;
    _ = y;
    _ = bd;
    _ = elev;
    stub.unported("encaixe.space3d.moveToAtElev");
}

/// Object3DVtbl slot 07 dropToSupport.
pub fn dropToSupport(g: *Game, obj: *Object, bd: *Backdrop) void {
    _ = g;
    _ = obj;
    _ = bd;
    stub.unported("encaixe.space3d.dropToSupport");
}
