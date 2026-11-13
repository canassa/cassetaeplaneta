//! Port unit `render` (behaviour). SceneObject slots 17-1E: dirty rects, overlap, restore background, draw, draw clip, erase.
//!
//! Virtual-slot dispatchers owned by this unit are declared below with
//! their final signatures; their bodies panic until the unit is ported
//! (docs/DESIGN.md "Virtual slots → dispatchers"). Replace each body, keep
//! the signature (other units already call it).

const stub = @import("../core/stub.zig");
const Game = @import("../core/game.zig").Game;
const object = @import("../core/object.zig");
const Object = object.Object;
const BitmapInfoHeader = object.BitmapInfoHeader;
const world = @import("../core/world.zig");
const Backdrop = world.Backdrop;

/// SceneObject slot 17 (skeleton stub: unported until this unit is).
pub fn addDirtyRect(g: *Game, obj: *Object, x: i16, y: i16, w: i16, h: i16) void {
    _ = .{ g, obj, x, y, w, h };
    stub.unported("render.addDirtyRect");
}

/// SceneObject slot 18 (skeleton stub: unported until this unit is).
pub fn computeOverlap(g: *Game, obj: *Object, other: *Object) bool {
    _ = .{ g, obj, other };
    stub.unported("render.computeOverlap");
}

/// SceneObject slot 19 (skeleton stub: unported until this unit is).
pub fn restoreBackground(g: *Game, obj: *Object, bd: *Backdrop, flag: i16) void {
    _ = .{ g, obj, bd, flag };
    stub.unported("render.restoreBackground");
}

/// SceneObject slot 1A (skeleton stub: unported until this unit is).
pub fn drawDirtyTo(g: *Game, obj: *Object, dst_hdr: *const BitmapInfoHeader, dst_bits: []u8) void {
    _ = .{ g, obj, dst_hdr, dst_bits };
    stub.unported("render.drawDirtyTo");
}

/// SceneObject slot 1B (skeleton stub: unported until this unit is).
pub fn draw(g: *Game, obj: *Object, bd: *Backdrop) void {
    _ = .{ g, obj, bd };
    stub.unported("render.draw");
}

/// SceneObject slot 1C (skeleton stub: unported until this unit is).
pub fn drawClipTo(g: *Game, obj: *Object, dst_hdr: *const BitmapInfoHeader, dst_bits: []u8) void {
    _ = .{ g, obj, dst_hdr, dst_bits };
    stub.unported("render.drawClipTo");
}

/// SceneObject slot 1D (skeleton stub: unported until this unit is).
pub fn drawClip(g: *Game, obj: *Object, bd: *Backdrop) void {
    _ = .{ g, obj, bd };
    stub.unported("render.drawClip");
}

/// SceneObject slot 1E (skeleton stub: unported until this unit is).
pub fn erase(g: *Game, obj: *Object, bd: *Backdrop) void {
    _ = .{ g, obj, bd };
    stub.unported("render.erase");
}
