//! Port unit `visibility` (behaviour) of INFERNO.EXE. SceneObject slots 1B-21
//! (redraw, hideAndInvalidate, blitToDc, invalidate, slot24, hide, show) and
//! 4D redrawOverlapping.
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

/// SceneObject slot 1B redraw: actor2d_redraw (every kind).
pub fn redraw(g: *Game, obj: *Object, bd: *Backdrop) void {
    _ = g;
    _ = obj;
    _ = bd;
    stub.unported("inferno.visibility.redraw");
}

/// SceneObject slot 1C hideAndInvalidate (scene_object_hide_and_invalidate).
pub fn hideAndInvalidate(g: *Game, obj: *Object, unused: u16, bd: *Backdrop) void {
    _ = g;
    _ = obj;
    _ = unused;
    _ = bd;
    stub.unported("inferno.visibility.hideAndInvalidate");
}

/// SceneObject slot 1D blitToDc: actor2d_blit_to_dc (every kind).
pub fn blitToDc(g: *Game, obj: *Object, bd: *Backdrop) void {
    _ = g;
    _ = obj;
    _ = bd;
    stub.unported("inferno.visibility.blitToDc");
}

/// SceneObject slot 1E invalidate: mover_invalidate (every kind).
pub fn invalidate(g: *Game, obj: *Object) void {
    _ = g;
    _ = obj;
    stub.unported("inferno.visibility.invalidate");
}

/// SceneObject slot 1F slot24: mover_slot24 (every kind).
pub fn slot24(g: *Game, obj: *Object, bd: *Backdrop) void {
    _ = g;
    _ = obj;
    _ = bd;
    stub.unported("inferno.visibility.slot24");
}

/// SceneObject slot 20 hide: mover_hide (every kind).
pub fn hide(g: *Game, obj: *Object, bd: *Backdrop) void {
    _ = g;
    _ = obj;
    _ = bd;
    stub.unported("inferno.visibility.hide");
}

/// SceneObject slot 21 show: actor2d_show (every kind).
pub fn show(g: *Game, obj: *Object, bd: *Backdrop) void {
    _ = g;
    _ = obj;
    _ = bd;
    stub.unported("inferno.visibility.show");
}

/// SceneObject slot 4D redrawOverlapping (scene_object_redraw_overlapping; no
/// override in INFERNO).
pub fn redrawOverlapping(g: *Game, obj: *Object, bd: *Backdrop, flag: i16) void {
    _ = g;
    _ = obj;
    _ = bd;
    _ = flag;
    stub.unported("inferno.visibility.redrawOverlapping");
}
