//! Port unit `render` (behaviour) of INFERNO.EXE. SceneObject slots 12-1A
//! (dirty rects, overlap, restoreBackground, drawDirtyTo, draw, drawClip(To),
//! erase, slot1F) and the DC hooks.
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

/// SceneObject slot 12 addDirtyRect (scene_object_add_dirty_rect).
pub fn addDirtyRect(g: *Game, obj: *Object, x: i16, y: i16, w: i16, h: i16) void {
    _ = g;
    _ = obj;
    _ = x;
    _ = y;
    _ = w;
    _ = h;
    stub.unported("inferno.render.addDirtyRect");
}

/// SceneObject slot 13 computeOverlap (scene_object_compute_overlap).
pub fn computeOverlap(g: *Game, obj: *Object, other: *Object) bool {
    _ = g;
    _ = obj;
    _ = other;
    stub.unported("inferno.render.computeOverlap");
}

/// SceneObject slot 14 restoreBackground: mover_restore_background (hero,
/// platform), prop.restoreBackground (prop, hazard: prop_restore_background).
pub fn restoreBackground(g: *Game, obj: *Object, bd: *Backdrop, flag: i16) void {
    _ = g;
    _ = obj;
    _ = bd;
    _ = flag;
    stub.unported("inferno.render.restoreBackground");
}

/// SceneObject slot 15 drawDirtyTo: mover_draw_dirty_to (every kind).
pub fn drawDirtyTo(g: *Game, obj: *Object, dst_hdr: *const BitmapInfoHeader, dst_bits: []u8) void {
    _ = g;
    _ = obj;
    _ = dst_hdr;
    _ = dst_bits;
    stub.unported("inferno.render.drawDirtyTo");
}

/// SceneObject slot 16 draw: animation_draw (every kind).
pub fn draw(g: *Game, obj: *Object, bd: *Backdrop) void {
    _ = g;
    _ = obj;
    _ = bd;
    stub.unported("inferno.render.draw");
}

/// SceneObject slot 17 drawClipTo (scene_object_draw_clip_to).
pub fn drawClipTo(g: *Game, obj: *Object, dst_hdr: *const BitmapInfoHeader, dst_bits: []u8) void {
    _ = g;
    _ = obj;
    _ = dst_hdr;
    _ = dst_bits;
    stub.unported("inferno.render.drawClipTo");
}

/// SceneObject slot 18 drawClip (scene_object_draw_clip).
pub fn drawClip(g: *Game, obj: *Object, bd: *Backdrop) void {
    _ = g;
    _ = obj;
    _ = bd;
    stub.unported("inferno.render.drawClip");
}

/// SceneObject slot 19 erase: animation_erase (every kind).
pub fn erase(g: *Game, obj: *Object, bd: *Backdrop) void {
    _ = g;
    _ = obj;
    _ = bd;
    stub.unported("inferno.render.erase");
}

/// SceneObject slot 1A slot1F: animation_slot1f (every kind).
pub fn slot1F(g: *Game, obj: *Object, bd: *Backdrop) void {
    _ = g;
    _ = obj;
    _ = bd;
    stub.unported("inferno.render.slot1F");
}
