//! Port unit `render` (behaviour) of ENCAIXE.EXE. SceneObject slots 13-1C (dirty rects, overlap, restore background, drawDirtyTo, draw, unk18, drawClip(To), erase, slot1F) and the DC hooks.
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

/// SceneObject slot 13 addDirtyRect.
pub fn addDirtyRect(g: *Game, obj: *Object, x: i16, y: i16, w: i16, h: i16) void {
    _ = g;
    _ = obj;
    _ = x;
    _ = y;
    _ = w;
    _ = h;
    stub.unported("encaixe.render.addDirtyRect");
}

/// SceneObject slot 14 computeOverlap.
pub fn computeOverlap(g: *Game, obj: *Object, other: *Object) bool {
    _ = g;
    _ = obj;
    _ = other;
    stub.unported("encaixe.render.computeOverlap");
}

/// SceneObject slot 15 restoreBackground: the piece's own (te_piece_restore_background) / SceneObject's.
pub fn restoreBackground(g: *Game, obj: *Object, bd: *Backdrop, flag: i16) void {
    _ = g;
    _ = obj;
    _ = bd;
    _ = flag;
    stub.unported("encaixe.render.restoreBackground");
}

/// SceneObject slot 16 drawDirtyTo: Mover's (piece) / SceneObject's (far bits and header).
pub fn drawDirtyTo(g: *Game, obj: *Object, dst_hdr: *const BitmapInfoHeader, dst_bits: []u8) void {
    _ = g;
    _ = obj;
    _ = dst_hdr;
    _ = dst_bits;
    stub.unported("encaixe.render.drawDirtyTo");
}

/// SceneObject slot 17 draw: te_piece_draw (piece), control_panel_draw (panels.draw), SceneObject's.
pub fn draw(g: *Game, obj: *Object, bd: *Backdrop) void {
    _ = g;
    _ = obj;
    _ = bd;
    stub.unported("encaixe.render.draw");
}

/// SceneObject slot 18 unk18 (ENCAIXE-only draw variant).
pub fn unk18(g: *Game, obj: *Object, bd: *Backdrop) void {
    _ = g;
    _ = obj;
    _ = bd;
    stub.unported("encaixe.render.unk18");
}

/// SceneObject slot 19 drawClipTo.
pub fn drawClipTo(g: *Game, obj: *Object, dst_hdr: *const BitmapInfoHeader, dst_bits: []u8) void {
    _ = g;
    _ = obj;
    _ = dst_hdr;
    _ = dst_bits;
    stub.unported("encaixe.render.drawClipTo");
}

/// SceneObject slot 1A drawClip.
pub fn drawClip(g: *Game, obj: *Object, bd: *Backdrop) void {
    _ = g;
    _ = obj;
    _ = bd;
    stub.unported("encaixe.render.drawClip");
}

/// SceneObject slot 1B erase: Animation's (piece, control_panel) / SceneObject's.
pub fn erase(g: *Game, obj: *Object, bd: *Backdrop) void {
    _ = g;
    _ = obj;
    _ = bd;
    stub.unported("encaixe.render.erase");
}

/// SceneObject slot 1C slot1F: Animation's (piece, control_panel) / default.
pub fn slot1F(g: *Game, obj: *Object, bd: *Backdrop) void {
    _ = g;
    _ = obj;
    _ = bd;
    stub.unported("encaixe.render.slot1F");
}
