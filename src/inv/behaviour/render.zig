//! Port unit `render` (behaviour) of INV.EXE. SceneObject slots 12-1A (dirty rects, overlap, restore background incl. the InvaderColumn's and InvaderExplosion's, drawDirtyTo, draw incl. theirs, drawClip(To), erase, slot1F) and the DC hooks.
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

/// SceneObject slot 12 addDirtyRect.
pub fn addDirtyRect(g: *Game, obj: *Object, x: i16, y: i16, w: i16, h: i16) void {
    _ = g;
    _ = obj;
    _ = x;
    _ = y;
    _ = w;
    _ = h;
    stub.unported("inv.render.addDirtyRect");
}

/// SceneObject slot 13 computeOverlap.
pub fn computeOverlap(g: *Game, obj: *Object, other: *Object) bool {
    _ = g;
    _ = obj;
    _ = other;
    stub.unported("inv.render.computeOverlap");
}

/// SceneObject slot 14 restoreBackground: mover_restore_background (cannon, saucer, bomb, shot), invader_column_restore_background (column), invader_explosion_restore_background (explosion) / SceneObject's.
pub fn restoreBackground(g: *Game, obj: *Object, bd: *Backdrop, flag: i16) void {
    _ = g;
    _ = obj;
    _ = bd;
    _ = flag;
    stub.unported("inv.render.restoreBackground");
}

/// SceneObject slot 15 drawDirtyTo: mover_draw_dirty_to (cannon, saucer, bomb, shot, column, explosion) / SceneObject's.
pub fn drawDirtyTo(g: *Game, obj: *Object, dst_hdr: *const BitmapInfoHeader, dst_bits: []u8) void {
    _ = g;
    _ = obj;
    _ = dst_hdr;
    _ = dst_bits;
    stub.unported("inv.render.drawDirtyTo");
}

/// SceneObject slot 16 draw: player2d_draw (cannon), animation_draw (saucer, bomb, shot), invader_column_draw (column), invader_explosion_draw (explosion), control_panel_draw (panel) / SceneObject's.
pub fn draw(g: *Game, obj: *Object, bd: *Backdrop) void {
    _ = g;
    _ = obj;
    _ = bd;
    stub.unported("inv.render.draw");
}

/// SceneObject slot 17 drawClipTo.
pub fn drawClipTo(g: *Game, obj: *Object, dst_hdr: *const BitmapInfoHeader, dst_bits: []u8) void {
    _ = g;
    _ = obj;
    _ = dst_hdr;
    _ = dst_bits;
    stub.unported("inv.render.drawClipTo");
}

/// SceneObject slot 18 drawClip.
pub fn drawClip(g: *Game, obj: *Object, bd: *Backdrop) void {
    _ = g;
    _ = obj;
    _ = bd;
    stub.unported("inv.render.drawClip");
}

/// SceneObject slot 19 erase: animation_erase (cannon, saucer, bomb, shot, column, explosion, panel) / SceneObject's.
pub fn erase(g: *Game, obj: *Object, bd: *Backdrop) void {
    _ = g;
    _ = obj;
    _ = bd;
    stub.unported("inv.render.erase");
}

/// SceneObject slot 1A slot1F: animation_slot1f (cannon, saucer, bomb, shot, column, explosion, panel) / default.
pub fn slot1F(g: *Game, obj: *Object, bd: *Backdrop) void {
    _ = g;
    _ = obj;
    _ = bd;
    stub.unported("inv.render.slot1F");
}
