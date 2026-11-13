//! Port unit `tick` (behaviour). SceneObject slots 30 play and 34 tick (animation, 3D, exit, control panel, player).
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

/// SceneObject slot 30 (skeleton stub: unported until this unit is).
pub fn play(g: *Game, obj: *Object, bd: *Backdrop) void {
    _ = .{ g, bd };
    switch (obj.kind) {
        // @orig 1010:1ad4 scene_object_play_default (absorbed)
        .local, .moveable, .portable, .status_bar => {},
        else => stub.unported("tick.play"),
    }
}

/// SceneObject slot 34 (skeleton stub: unported until this unit is).
pub fn tick(g: *Game, obj: *Object, bd: *Backdrop) void {
    _ = .{ g, bd };
    switch (obj.kind) {
        // @orig 1010:1afc scene_object_tick_default (absorbed)
        .local, .moveable, .portable, .status_bar => {},
        else => stub.unported("tick.tick"),
    }
}
