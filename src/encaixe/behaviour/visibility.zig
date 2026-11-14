//! Port unit `visibility` (behaviour) of ENCAIXE.EXE. SceneObject slots 1D-23 (redraw, hideAndInvalidate, blitToDc, invalidate, slot24, hide, show) and 4F redrawOverlapping.
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

/// SceneObject slot 1D redraw: Actor2D's (piece), Animated3D's (control_panel), SceneObject's.
pub fn redraw(g: *Game, obj: *Object, bd: *Backdrop) void {
    _ = g;
    _ = obj;
    _ = bd;
    stub.unported("encaixe.visibility.redraw");
}

/// SceneObject slot 1E hideAndInvalidate.
pub fn hideAndInvalidate(g: *Game, obj: *Object, unused: u16, bd: *Backdrop) void {
    _ = g;
    _ = obj;
    _ = unused;
    _ = bd;
    stub.unported("encaixe.visibility.hideAndInvalidate");
}

/// SceneObject slot 1F blitToDc (hdc dropped): Actor2D's (piece) / SceneObject's.
pub fn blitToDc(g: *Game, obj: *Object, bd: *Backdrop) void {
    _ = g;
    _ = obj;
    _ = bd;
    stub.unported("encaixe.visibility.blitToDc");
}

/// SceneObject slot 20 invalidate: Mover's (piece) / SceneObject's.
pub fn invalidate(g: *Game, obj: *Object) void {
    _ = g;
    _ = obj;
    stub.unported("encaixe.visibility.invalidate");
}

/// SceneObject slot 21 slot24 (hdc dropped): Mover's (piece) / SceneObject's.
pub fn slot24(g: *Game, obj: *Object, bd: *Backdrop) void {
    _ = g;
    _ = obj;
    _ = bd;
    stub.unported("encaixe.visibility.slot24");
}

/// SceneObject slot 22 hide: Mover's (piece) / SceneObject's.
pub fn hide(g: *Game, obj: *Object, bd: *Backdrop) void {
    _ = g;
    _ = obj;
    _ = bd;
    stub.unported("encaixe.visibility.hide");
}

/// SceneObject slot 23 show: Actor2D's (piece), Animated3D's (control_panel), SceneObject's.
pub fn show(g: *Game, obj: *Object, bd: *Backdrop) void {
    _ = g;
    _ = obj;
    _ = bd;
    stub.unported("encaixe.visibility.show");
}

/// SceneObject slot 4F redrawOverlapping (hdc dropped): Object3D's (control_panel) / SceneObject's.
pub fn redrawOverlapping(g: *Game, obj: *Object, bd: *Backdrop, flag: i16) void {
    _ = g;
    _ = obj;
    _ = bd;
    _ = flag;
    stub.unported("encaixe.visibility.redrawOverlapping");
}
