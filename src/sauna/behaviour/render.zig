//! Port unit `render` (behaviour) of SAUNA.EXE. SceneObject slots 03 isRle, 17-20 (dirty rects, overlap, restoreBackground incl. Pacman's (eating, the win: BUGS.md P3) and the Ghosts', drawDirtyTo, draw, unk18, drawClip(To), erase, slot1F) and the DC hooks.
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

/// SceneObject slot 03 isRle (rleMode: always 0, the RLE path is dead).
pub fn isRle(g: *Game, obj: *Object) bool {
    _ = g;
    _ = obj;
    stub.unported("sauna.render.isRle");
}

/// SceneObject slot 17 addDirtyRect.
pub fn addDirtyRect(g: *Game, obj: *Object, x: i16, y: i16, w: i16, h: i16) void {
    _ = g;
    _ = obj;
    _ = x;
    _ = y;
    _ = w;
    _ = h;
    stub.unported("sauna.render.addDirtyRect");
}

/// SceneObject slot 18 computeOverlap.
pub fn computeOverlap(g: *Game, obj: *Object, other: *Object) bool {
    _ = g;
    _ = obj;
    _ = other;
    stub.unported("sauna.render.computeOverlap");
}

/// SceneObject slot 19 restoreBackground: pacman_restore_background (pacman), ghost_restore_background (ghost) / SceneObject's.
pub fn restoreBackground(g: *Game, obj: *Object, bd: *Backdrop, flag: i16) void {
    _ = g;
    _ = obj;
    _ = bd;
    _ = flag;
    stub.unported("sauna.render.restoreBackground");
}

/// SceneObject slot 1A drawDirtyTo: mover_draw_dirty_to (pacman, ghost) / SceneObject's.
pub fn drawDirtyTo(g: *Game, obj: *Object, dst_hdr: *const BitmapInfoHeader, dst_bits: []u8) void {
    _ = g;
    _ = obj;
    _ = dst_hdr;
    _ = dst_bits;
    stub.unported("sauna.render.drawDirtyTo");
}

/// SceneObject slot 1B draw: control_panel_draw (panel), player2d_draw (pacman), animation_draw (ghost) / SceneObject's.
pub fn draw(g: *Game, obj: *Object, bd: *Backdrop) void {
    _ = g;
    _ = obj;
    _ = bd;
    stub.unported("sauna.render.draw");
}

/// SceneObject slot 1C unk18 (ENCAIXE's: drawDirtyTo into the backdrop's second bitmap).
pub fn unk18(g: *Game, obj: *Object, bd: *Backdrop) void {
    _ = g;
    _ = obj;
    _ = bd;
    stub.unported("sauna.render.unk18");
}

/// SceneObject slot 1D drawClipTo.
pub fn drawClipTo(g: *Game, obj: *Object, dst_hdr: *const BitmapInfoHeader, dst_bits: []u8) void {
    _ = g;
    _ = obj;
    _ = dst_hdr;
    _ = dst_bits;
    stub.unported("sauna.render.drawClipTo");
}

/// SceneObject slot 1E drawClip.
pub fn drawClip(g: *Game, obj: *Object, bd: *Backdrop) void {
    _ = g;
    _ = obj;
    _ = bd;
    stub.unported("sauna.render.drawClip");
}

/// SceneObject slot 1F erase: animation_erase (panel, pacman, ghost) / SceneObject's.
pub fn erase(g: *Game, obj: *Object, bd: *Backdrop) void {
    _ = g;
    _ = obj;
    _ = bd;
    stub.unported("sauna.render.erase");
}

/// SceneObject slot 20 slot1F: animation_slot1f (panel, pacman, ghost) / default.
pub fn slot1F(g: *Game, obj: *Object, bd: *Backdrop) void {
    _ = g;
    _ = obj;
    _ = bd;
    stub.unported("sauna.render.slot1F");
}
