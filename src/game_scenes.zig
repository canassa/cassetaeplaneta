//! Port unit `game_scenes` (module). scene switching: take exit, switch scene, first/start scene, IniGame init.
//!
//! Virtual-slot dispatchers owned by this unit are declared below with
//! their final signatures; their bodies panic until the unit is ported
//! (docs/DESIGN.md "Virtual slots → dispatchers"). Replace each body, keep
//! the signature (other units already call it).

const stub = @import("core/stub.zig");
const Game = @import("core/game.zig").Game;
const world = @import("core/world.zig");
const Scene = world.Scene;
const File = @import("platform/platform.zig").File;

/// Game slot 07 (skeleton stub: unported until this unit is).
pub fn init(g: *Game, name: []const u8) *Game {
    _ = .{ g, name };
    stub.unported("game_scenes.init");
}

/// Game slot 0C (skeleton stub: unported until this unit is).
pub fn createFirstScene(g: *Game) ?*Scene {
    _ = .{g};
    stub.unported("game_scenes.createFirstScene");
}

/// Game slot 0D (skeleton stub: unported until this unit is).
pub fn createStartScene(g: *Game, fd: File) ?*Scene {
    _ = .{ g, fd };
    stub.unported("game_scenes.createStartScene");
}
