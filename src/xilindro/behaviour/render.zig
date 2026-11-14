//! Port unit `render` (behaviour) of XILINDRO.EXE. SceneObject slots 12-1A (dirty rects, overlap, restore background, drawDirtyTo, draw, drawClip(To), erase, slot1F) and the DC hooks.
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

/// SceneObject slot 12 addDirtyRect.
pub fn addDirtyRect(g: *Game, obj: *Object, x: i16, y: i16, w: i16, h: i16) void {
    _ = g;
    _ = obj;
    _ = x;
    _ = y;
    _ = w;
    _ = h;
    stub.unported("xilindro.render.addDirtyRect");
}

/// SceneObject slot 13 computeOverlap.
pub fn computeOverlap(g: *Game, obj: *Object, other: *Object) bool {
    _ = g;
    _ = obj;
    _ = other;
    stub.unported("xilindro.render.computeOverlap");
}

/// SceneObject slot 14 restoreBackground: mover_restore_background (fighter, opponent, banner, energy_bar) / SceneObject's.
pub fn restoreBackground(g: *Game, obj: *Object, bd: *Backdrop, flag: i16) void {
    _ = g;
    _ = obj;
    _ = bd;
    _ = flag;
    stub.unported("xilindro.render.restoreBackground");
}

/// SceneObject slot 15 drawDirtyTo: mover_draw_dirty_to (fighter, opponent, banner, energy_bar) / SceneObject's.
pub fn drawDirtyTo(g: *Game, obj: *Object, dst_hdr: *const BitmapInfoHeader, dst_bits: []u8) void {
    _ = g;
    _ = obj;
    _ = dst_hdr;
    _ = dst_bits;
    stub.unported("xilindro.render.drawDirtyTo");
}

/// SceneObject slot 16 draw: player2d_draw (fighter), animation_draw (opponent, banner, energy_bar), control_panel_draw (panel) / SceneObject's.
pub fn draw(g: *Game, obj: *Object, bd: *Backdrop) void {
    _ = g;
    _ = obj;
    _ = bd;
    stub.unported("xilindro.render.draw");
}

/// SceneObject slot 17 drawClipTo.
pub fn drawClipTo(g: *Game, obj: *Object, dst_hdr: *const BitmapInfoHeader, dst_bits: []u8) void {
    _ = g;
    _ = obj;
    _ = dst_hdr;
    _ = dst_bits;
    stub.unported("xilindro.render.drawClipTo");
}

/// SceneObject slot 18 drawClip.
pub fn drawClip(g: *Game, obj: *Object, bd: *Backdrop) void {
    _ = g;
    _ = obj;
    _ = bd;
    stub.unported("xilindro.render.drawClip");
}

/// SceneObject slot 19 erase: animation_erase (fighter, opponent, banner, energy_bar, panel) / SceneObject's.
pub fn erase(g: *Game, obj: *Object, bd: *Backdrop) void {
    _ = g;
    _ = obj;
    _ = bd;
    stub.unported("xilindro.render.erase");
}

/// SceneObject slot 1A slot1F: animation_slot1f (fighter, opponent, banner, energy_bar, panel) / default.
pub fn slot1F(g: *Game, obj: *Object, bd: *Backdrop) void {
    _ = g;
    _ = obj;
    _ = bd;
    stub.unported("xilindro.render.slot1F");
}
