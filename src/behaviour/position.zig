//! Port unit `position` (behaviour). SceneObject slots 0D-10 getX/getY/getStep, 41 setPosition, 42 isScrollTarget, 59/5A overlap tests.
//!
//! Virtual-slot dispatchers owned by this unit are declared below with
//! their final signatures; their bodies panic until the unit is ported
//! (docs/DESIGN.md "Virtual slots → dispatchers"). Replace each body, keep
//! the signature (other units already call it).

const stub = @import("../core/stub.zig");
const Game = @import("../core/game.zig").Game;
const object = @import("../core/object.zig");
const Object = object.Object;

/// SceneObject slot 0D (skeleton stub: unported until this unit is).
pub fn getX(g: *Game, obj: *Object) i16 {
    _ = .{ g, obj };
    stub.unported("position.getX");
}

/// SceneObject slot 0E (skeleton stub: unported until this unit is).
pub fn getY(g: *Game, obj: *Object) i16 {
    _ = .{ g, obj };
    stub.unported("position.getY");
}

/// SceneObject slot 0F (skeleton stub: unported until this unit is).
pub fn getStepX(g: *Game, obj: *Object) i16 {
    _ = .{g};
    return switch (obj.kind) {
        // @orig 1010:13ce scene_object_get_step_x_default (absorbed)
        .local, .animated, .exit, .control_panel, .status_bar => 0,
        else => stub.unported("position.getStepX"),
    };
}

/// SceneObject slot 10 (skeleton stub: unported until this unit is).
pub fn getStepY(g: *Game, obj: *Object) i16 {
    _ = .{g};
    return switch (obj.kind) {
        // @orig 1010:13da scene_object_get_step_y_default (absorbed)
        .local, .animated, .exit, .control_panel, .status_bar => 0,
        else => stub.unported("position.getStepY"),
    };
}

/// SceneObject slot 41 (skeleton stub: unported until this unit is).
pub fn setPosition(g: *Game, obj: *Object, x: i16, y: i16) void {
    _ = .{ g, obj, x, y };
    stub.unported("position.setPosition");
}

/// SceneObject slot 42 (skeleton stub: unported until this unit is).
pub fn isScrollTarget(g: *Game, obj: *Object) bool {
    _ = .{ g, obj };
    stub.unported("position.isScrollTarget");
}

/// SceneObject slot 59 (skeleton stub: unported until this unit is).
pub fn hitboxOverlaps(g: *Game, obj: *Object, other: *Object) bool {
    _ = .{ g, obj, other };
    stub.unported("position.hitboxOverlaps");
}

/// SceneObject slot 5A (skeleton stub: unported until this unit is).
pub fn boundsOverlap(g: *Game, obj: *Object, other: *Object) bool {
    _ = .{ g, obj, other };
    stub.unported("position.boundsOverlap");
}
