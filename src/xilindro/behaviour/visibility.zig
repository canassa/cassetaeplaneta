//! Port unit `visibility` (behaviour) of XILINDRO.EXE. SceneObject slots 1B-21 (redraw, hideAndInvalidate, blitToDc, invalidate incl. the Fighter's and the Opponent's, slot24, hide, show) and 4D redrawOverlapping (the Fighter's and the Opponent's draw each other).
//!
//! Virtual-slot dispatchers owned by this unit are declared below with
//! their final signatures; their bodies panic until the unit is ported
//! (docs/xilindro/DESIGN.md "Virtual slots"). Replace each body, keep the
//! signature (other units already call it). Each implementation function
//! carries `// @orig <seg:xxxx> <name>` with the XILINDRO address.

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

/// SceneObject slot 1B redraw: actor2d_redraw (fighter, opponent, banner, energy_bar), animated3d_redraw (panel) / SceneObject's.
pub fn redraw(g: *Game, obj: *Object, bd: *Backdrop) void {
    _ = g;
    _ = obj;
    _ = bd;
    stub.unported("xilindro.visibility.redraw");
}

/// SceneObject slot 1C hideAndInvalidate.
pub fn hideAndInvalidate(g: *Game, obj: *Object, unused: u16, bd: *Backdrop) void {
    _ = g;
    _ = obj;
    _ = unused;
    _ = bd;
    stub.unported("xilindro.visibility.hideAndInvalidate");
}

/// SceneObject slot 1D blitToDc (hdc dropped): actor2d_blit_to_dc (fighter, opponent, banner, energy_bar) / SceneObject's.
pub fn blitToDc(g: *Game, obj: *Object, bd: *Backdrop) void {
    _ = g;
    _ = obj;
    _ = bd;
    stub.unported("xilindro.visibility.blitToDc");
}

/// SceneObject slot 1E invalidate: fighter_invalidate (fighter), opponent_invalidate (opponent), mover_invalidate (banner, energy_bar) / SceneObject's.
pub fn invalidate(g: *Game, obj: *Object) void {
    _ = g;
    _ = obj;
    stub.unported("xilindro.visibility.invalidate");
}

/// SceneObject slot 1F slot24 (hdc dropped): mover_slot24 (fighter, opponent, banner, energy_bar) / SceneObject's.
pub fn slot24(g: *Game, obj: *Object, bd: *Backdrop) void {
    _ = g;
    _ = obj;
    _ = bd;
    stub.unported("xilindro.visibility.slot24");
}

/// SceneObject slot 20 hide: mover_hide (fighter, opponent, banner, energy_bar) / SceneObject's.
pub fn hide(g: *Game, obj: *Object, bd: *Backdrop) void {
    _ = g;
    _ = obj;
    _ = bd;
    stub.unported("xilindro.visibility.hide");
}

/// SceneObject slot 21 show: actor2d_show (fighter, opponent, banner, energy_bar), animated3d_show (panel) / SceneObject's.
pub fn show(g: *Game, obj: *Object, bd: *Backdrop) void {
    _ = g;
    _ = obj;
    _ = bd;
    stub.unported("xilindro.visibility.show");
}

/// SceneObject slot 4D redrawOverlapping (hdc dropped): fighter_redraw_overlapping (fighter), opponent_redraw_overlapping (opponent), object3d_redraw_overlapping (panel) / SceneObject's.
pub fn redrawOverlapping(g: *Game, obj: *Object, bd: *Backdrop, flag: i16) void {
    _ = g;
    _ = obj;
    _ = bd;
    _ = flag;
    stub.unported("xilindro.visibility.redrawOverlapping");
}
