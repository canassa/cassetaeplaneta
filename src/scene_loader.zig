//! Port unit `scene_loader` (module). ini_scene_create: builds a scene and its objects from its INI section.
//!
//! Virtual-slot dispatchers owned by this unit are declared below with
//! their final signatures; their bodies panic until the unit is ported
//! (docs/DESIGN.md "Virtual slots → dispatchers"). Replace each body, keep
//! the signature (other units already call it).

const stub = @import("core/stub.zig");
const Game = @import("core/game.zig").Game;
const world = @import("core/world.zig");
const Scene = world.Scene;

/// Scene slot 07 (skeleton stub: unported until this unit is).
pub fn create(g: *Game, scene: *Scene) ?*Scene {
    _ = .{ g, scene };
    stub.unported("scene_loader.create");
}
