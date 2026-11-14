//! Port unit `visibility` (behaviour) of SAUNA.EXE. SceneObject slots 21-27 (redraw, hideAndInvalidate, blitToDc, invalidate, slot24, hide, show) and 54 redrawOverlapping.
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

/// SceneObject slot 21 redraw: animated3d_redraw (panel), actor2d_redraw (pacman, ghost) / SceneObject's.
pub fn redraw(g: *Game, obj: *Object, bd: *Backdrop) void {
    _ = g;
    _ = obj;
    _ = bd;
    stub.unported("sauna.visibility.redraw");
}

/// SceneObject slot 22 hideAndInvalidate.
pub fn hideAndInvalidate(g: *Game, obj: *Object, unused: u16, bd: *Backdrop) void {
    _ = g;
    _ = obj;
    _ = unused;
    _ = bd;
    stub.unported("sauna.visibility.hideAndInvalidate");
}

/// SceneObject slot 23 blitToDc (hdc dropped): actor2d_blit_to_dc (pacman, ghost) / SceneObject's.
pub fn blitToDc(g: *Game, obj: *Object, bd: *Backdrop) void {
    _ = g;
    _ = obj;
    _ = bd;
    stub.unported("sauna.visibility.blitToDc");
}

/// SceneObject slot 24 invalidate: mover_invalidate (pacman, ghost) / SceneObject's.
pub fn invalidate(g: *Game, obj: *Object) void {
    _ = g;
    _ = obj;
    stub.unported("sauna.visibility.invalidate");
}

/// SceneObject slot 25 slot24 (hdc dropped): mover_slot24 (pacman, ghost) / SceneObject's.
pub fn slot24(g: *Game, obj: *Object, bd: *Backdrop) void {
    _ = g;
    _ = obj;
    _ = bd;
    stub.unported("sauna.visibility.slot24");
}

/// SceneObject slot 26 hide: mover_hide (pacman, ghost) / SceneObject's.
pub fn hide(g: *Game, obj: *Object, bd: *Backdrop) void {
    _ = g;
    _ = obj;
    _ = bd;
    stub.unported("sauna.visibility.hide");
}

/// SceneObject slot 27 show: animated3d_show (panel), actor2d_show (pacman, ghost) / SceneObject's.
pub fn show(g: *Game, obj: *Object, bd: *Backdrop) void {
    _ = g;
    _ = obj;
    _ = bd;
    stub.unported("sauna.visibility.show");
}

/// SceneObject slot 54 redrawOverlapping (hdc dropped): object3d_redraw_overlapping (panel) / SceneObject's.
pub fn redrawOverlapping(g: *Game, obj: *Object, bd: *Backdrop, flag: i16) void {
    _ = g;
    _ = obj;
    _ = bd;
    _ = flag;
    stub.unported("sauna.visibility.redrawOverlapping");
}
