//! Port unit `occupancy` (behaviour). SceneObject slots 27-2C: occupy, vacate, reoccupy, attach, canStep; reattach on scene change.
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

/// SceneObject slot 27 (skeleton stub: unported until this unit is).
pub fn occupy(g: *Game, obj: *Object, bd: *Backdrop) i16 {
    _ = .{ g, obj, bd };
    stub.unported("occupancy.occupy");
}

/// SceneObject slot 28 (skeleton stub: unported until this unit is).
pub fn vacate(g: *Game, obj: *Object, bd: *Backdrop) i16 {
    _ = .{ g, obj, bd };
    stub.unported("occupancy.vacate");
}

/// SceneObject slot 29 (skeleton stub: unported until this unit is).
pub fn reoccupy(g: *Game, obj: *Object, bd: *Backdrop) void {
    _ = .{ g, obj, bd };
    stub.unported("occupancy.reoccupy");
}

/// SceneObject slot 2A (skeleton stub: unported until this unit is).
pub fn attach(g: *Game, obj: *Object, bd: *Backdrop) ?*Object {
    _ = .{ g, obj, bd };
    stub.unported("occupancy.attach");
}

/// SceneObject slot 2B (skeleton stub: unported until this unit is).
pub fn canStep(g: *Game, obj: *Object, bd: *Backdrop) bool {
    _ = .{ g, bd };
    return switch (obj.kind) {
        // @orig 1010:1a76 scene_object_can_step_default (absorbed)
        .local, .animated, .exit, .control_panel, .status_bar => false,
        else => stub.unported("occupancy.canStep"),
    };
}

/// SceneObject slot 2C (skeleton stub: unported until this unit is).
pub fn isStepBlocked(g: *Game, obj: *Object, bd: *Backdrop) bool {
    _ = .{ g, obj, bd };
    stub.unported("occupancy.isStepBlocked");
}
