//! Port unit `visibility` (behaviour). SceneObject slots 16, 20-23, 25, 26, 58: redraw, blit to screen, invalidate, hide, show, redraw overlapping, debug bounds.
//!
//! Virtual-slot dispatchers owned by this unit are declared below with
//! their final signatures; their bodies panic until the unit is ported
//! (docs/DESIGN.md "Virtual slots → dispatchers"). Replace each body, keep
//! the signature (other units already call it).

const stub = @import("../core/stub.zig");
const Game = @import("../core/game.zig").Game;
const object = @import("../core/object.zig");
const Object = object.Object;
const world = @import("../core/world.zig");
const Backdrop = world.Backdrop;

/// SceneObject slot 16 (skeleton stub: unported until this unit is).
pub fn drawBounds(g: *Game, obj: *Object, bd: *Backdrop) ?*Object {
    _ = .{ g, bd };
    return switch (obj.kind) {
        // @orig 1010:1442 scene_object_draw_bounds_default (absorbed)
        .status_bar => obj,
        else => stub.unported("visibility.drawBounds"),
    };
}

/// SceneObject slot 20 (skeleton stub: unported until this unit is).
pub fn redraw(g: *Game, obj: *Object, bd: *Backdrop) void {
    _ = .{ g, obj, bd };
    stub.unported("visibility.redraw");
}

/// SceneObject slot 21 (skeleton stub: unported until this unit is).
pub fn hideAndInvalidate(g: *Game, obj: *Object, unused: i16, bd: *Backdrop) void {
    _ = .{ g, obj, unused, bd };
    stub.unported("visibility.hideAndInvalidate");
}

/// SceneObject slot 22 (skeleton stub: unported until this unit is).
pub fn blitToDc(g: *Game, obj: *Object, bd: *Backdrop) void {
    _ = .{ g, obj, bd };
    stub.unported("visibility.blitToDc");
}

/// SceneObject slot 23 (skeleton stub: unported until this unit is).
pub fn invalidate(g: *Game, obj: *Object) i16 {
    _ = .{ g, obj };
    stub.unported("visibility.invalidate");
}

/// SceneObject slot 25 (skeleton stub: unported until this unit is).
pub fn hide(g: *Game, obj: *Object, bd: *Backdrop) void {
    _ = .{ g, obj, bd };
    stub.unported("visibility.hide");
}

/// SceneObject slot 26 (skeleton stub: unported until this unit is).
pub fn show(g: *Game, obj: *Object, bd: *Backdrop) void {
    _ = .{ g, obj, bd };
    stub.unported("visibility.show");
}

/// SceneObject slot 58 (skeleton stub: unported until this unit is).
pub fn redrawOverlapping(g: *Game, obj: *Object, bd: *Backdrop, flag: i16) void {
    _ = .{ g, bd, flag };
    switch (obj.kind) {
        // @orig 1010:c36e scene_object_redraw_overlapping_default (absorbed)
        .status_bar => {},
        else => stub.unported("visibility.redrawOverlapping"),
    }
}
