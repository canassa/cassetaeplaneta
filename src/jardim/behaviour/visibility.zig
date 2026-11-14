//! Port unit `visibility` (behaviour) of JARDIM.EXE. SceneObject slots 20-26 (redraw, hideAndInvalidate, blitToDc, invalidate, slot24, hide, show) and 53 redrawOverlapping.
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

/// SceneObject slot 20 redraw: animated3d_redraw (exit, player, control_panel) / SceneObject's.
pub fn redraw(g: *Game, obj: *Object, bd: *Backdrop) void {
    _ = g;
    _ = obj;
    _ = bd;
    stub.unported("jardim.visibility.redraw");
}

/// SceneObject slot 21 hideAndInvalidate (SceneObject's).
pub fn hideAndInvalidate(g: *Game, obj: *Object, unused: u16, bd: *Backdrop) void {
    _ = g;
    _ = obj;
    _ = unused;
    _ = bd;
    stub.unported("jardim.visibility.hideAndInvalidate");
}

/// SceneObject slot 22 blitToDc (hdc dropped): moveable_blit_to_dc (portable, player) / SceneObject's.
pub fn blitToDc(g: *Game, obj: *Object, bd: *Backdrop) void {
    _ = g;
    _ = obj;
    _ = bd;
    stub.unported("jardim.visibility.blitToDc");
}

/// SceneObject slot 23 invalidate: moveable_invalidate (portable, player) / SceneObject's.
pub fn invalidate(g: *Game, obj: *Object) void {
    _ = g;
    _ = obj;
    stub.unported("jardim.visibility.invalidate");
}

/// SceneObject slot 24 slot24 (hdc dropped): mover_slot24 (portable, player) / default.
pub fn slot24(g: *Game, obj: *Object, bd: *Backdrop) void {
    _ = g;
    _ = obj;
    _ = bd;
    stub.unported("jardim.visibility.slot24");
}

/// SceneObject slot 25 hide: mover_hide (portable, player) / SceneObject's.
pub fn hide(g: *Game, obj: *Object, bd: *Backdrop) void {
    _ = g;
    _ = obj;
    _ = bd;
    stub.unported("jardim.visibility.hide");
}

/// SceneObject slot 26 show: mover_show (portable), animated3d_show (exit, control_panel), actor_show (player) / SceneObject's.
pub fn show(g: *Game, obj: *Object, bd: *Backdrop) void {
    _ = g;
    _ = obj;
    _ = bd;
    stub.unported("jardim.visibility.show");
}

/// SceneObject slot 53 redrawOverlapping (hdc dropped): object3d_redraw_overlapping (portable, exit, player, control_panel) / default.
pub fn redrawOverlapping(g: *Game, obj: *Object, bd: *Backdrop, flag: i16) void {
    _ = g;
    _ = obj;
    _ = bd;
    _ = flag;
    stub.unported("jardim.visibility.redrawOverlapping");
}
