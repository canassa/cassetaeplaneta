//! Port unit `render` (behaviour) of JARDIM.EXE. SceneObject slots 17-1F (dirty rects, overlap, restore background, drawDirtyTo, draw incl. the panel's and its texts, drawClip(To), erase, slot1F), the DC hooks, reset_rects.
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

/// SceneObject slot 17 addDirtyRect (SceneObject's).
pub fn addDirtyRect(g: *Game, obj: *Object, x: i16, y: i16, w: i16, h: i16) void {
    _ = g;
    _ = obj;
    _ = x;
    _ = y;
    _ = w;
    _ = h;
    stub.unported("jardim.render.addDirtyRect");
}

/// SceneObject slot 18 computeOverlap (SceneObject's).
pub fn computeOverlap(g: *Game, obj: *Object, other: *Object) bool {
    _ = g;
    _ = obj;
    _ = other;
    stub.unported("jardim.render.computeOverlap");
}

/// SceneObject slot 19 restoreBackground: mover_restore_background (portable, player) / SceneObject's.
pub fn restoreBackground(g: *Game, obj: *Object, bd: *Backdrop, flag: i16) void {
    _ = g;
    _ = obj;
    _ = bd;
    _ = flag;
    stub.unported("jardim.render.restoreBackground");
}

/// SceneObject slot 1A drawDirtyTo: mover_draw_dirty_to (portable, player) / SceneObject's.
pub fn drawDirtyTo(g: *Game, obj: *Object, dst_hdr: *const BitmapInfoHeader, dst_bits: []u8) void {
    _ = g;
    _ = obj;
    _ = dst_hdr;
    _ = dst_bits;
    stub.unported("jardim.render.drawDirtyTo");
}

/// SceneObject slot 1B draw: exit_draw (exit), player_draw (player), control_panel_draw (control_panel) / SceneObject's.
pub fn draw(g: *Game, obj: *Object, bd: *Backdrop) void {
    _ = g;
    _ = obj;
    _ = bd;
    stub.unported("jardim.render.draw");
}

/// SceneObject slot 1C drawClipTo (SceneObject's).
pub fn drawClipTo(g: *Game, obj: *Object, dst_hdr: *const BitmapInfoHeader, dst_bits: []u8) void {
    _ = g;
    _ = obj;
    _ = dst_hdr;
    _ = dst_bits;
    stub.unported("jardim.render.drawClipTo");
}

/// SceneObject slot 1D drawClip (SceneObject's).
pub fn drawClip(g: *Game, obj: *Object, bd: *Backdrop) void {
    _ = g;
    _ = obj;
    _ = bd;
    stub.unported("jardim.render.drawClip");
}

/// SceneObject slot 1E erase: animation_erase (exit, player, control_panel) / SceneObject's.
pub fn erase(g: *Game, obj: *Object, bd: *Backdrop) void {
    _ = g;
    _ = obj;
    _ = bd;
    stub.unported("jardim.render.erase");
}

/// SceneObject slot 1F slot1F: animation_slot1f (exit, player, control_panel) / default.
pub fn slot1F(g: *Game, obj: *Object, bd: *Backdrop) void {
    _ = g;
    _ = obj;
    _ = bd;
    stub.unported("jardim.render.slot1F");
}
