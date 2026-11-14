//! Port unit `visibility` (behaviour) of INV.EXE. SceneObject slots 1B-21 (redraw, hideAndInvalidate, blitToDc incl. the Cannon's, invalidate, slot24, hide, show) and 4D redrawOverlapping.
//!
//! Virtual-slot dispatchers owned by this unit are declared below with
//! their final signatures; their bodies panic until the unit is ported
//! (docs/inv/DESIGN.md "Virtual slots"). Replace each body, keep the
//! signature (other units already call it). Each implementation function
//! carries `// @orig <seg:xxxx> <name>` with the INV address.

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

/// SceneObject slot 1B redraw: actor2d_redraw (cannon, saucer, bomb, shot, column, explosion), animated3d_redraw (panel) / SceneObject's.
pub fn redraw(g: *Game, obj: *Object, bd: *Backdrop) void {
    _ = g;
    _ = obj;
    _ = bd;
    stub.unported("inv.visibility.redraw");
}

/// SceneObject slot 1C hideAndInvalidate. INV's (1088:17a4) hides, then calls
/// `scene_object_blit_to_dc` on its hdc (TIRO's calls the virtual
/// `invalidate`): `unused` is that hdc, which the port drops.
pub fn hideAndInvalidate(g: *Game, obj: *Object, unused: u16, bd: *Backdrop) void {
    _ = g;
    _ = obj;
    _ = unused;
    _ = bd;
    stub.unported("inv.visibility.hideAndInvalidate");
}

/// SceneObject slot 1D blitToDc (hdc dropped): cannon_blit_to_dc (cannon), actor2d_blit_to_dc (saucer, bomb, shot, column, explosion) / SceneObject's.
pub fn blitToDc(g: *Game, obj: *Object, bd: *Backdrop) void {
    _ = g;
    _ = obj;
    _ = bd;
    stub.unported("inv.visibility.blitToDc");
}

/// SceneObject slot 1E invalidate: mover_invalidate (cannon, saucer, bomb, shot, column, explosion) / SceneObject's.
pub fn invalidate(g: *Game, obj: *Object) void {
    _ = g;
    _ = obj;
    stub.unported("inv.visibility.invalidate");
}

/// SceneObject slot 1F slot24 (hdc dropped): mover_slot24 (cannon, saucer, bomb, shot, column, explosion) / SceneObject's.
pub fn slot24(g: *Game, obj: *Object, bd: *Backdrop) void {
    _ = g;
    _ = obj;
    _ = bd;
    stub.unported("inv.visibility.slot24");
}

/// SceneObject slot 20 hide: mover_hide (cannon, saucer, bomb, shot, column, explosion) / SceneObject's.
pub fn hide(g: *Game, obj: *Object, bd: *Backdrop) void {
    _ = g;
    _ = obj;
    _ = bd;
    stub.unported("inv.visibility.hide");
}

/// SceneObject slot 21 show: actor2d_show (cannon, saucer, bomb, shot, column, explosion), animated3d_show (panel) / SceneObject's.
pub fn show(g: *Game, obj: *Object, bd: *Backdrop) void {
    _ = g;
    _ = obj;
    _ = bd;
    stub.unported("inv.visibility.show");
}

/// SceneObject slot 4D redrawOverlapping (hdc dropped): object3d_redraw_overlapping (panel) / SceneObject's.
pub fn redrawOverlapping(g: *Game, obj: *Object, bd: *Backdrop, flag: i16) void {
    _ = g;
    _ = obj;
    _ = bd;
    _ = flag;
    stub.unported("inv.visibility.redrawOverlapping");
}
