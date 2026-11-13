//! Port unit `game` (module). game lifetime, creation slots (player, panels, exit scene), global objects, handler table.
//!
//! Virtual-slot dispatchers owned by this unit are declared below with
//! their final signatures; their bodies panic until the unit is ported
//! (docs/DESIGN.md "Virtual slots → dispatchers"). Replace each body, keep
//! the signature (other units already call it).

const stub = @import("core/stub.zig");
const ini = @import("ini.zig");
const Game = @import("core/game.zig").Game;
const object = @import("core/object.zig");
const Object = object.Object;
const world = @import("core/world.zig");
const Scene = world.Scene;

/// Game slot 02 (skeleton stub: unported until this unit is).
pub fn createPlayer(g: *Game) ?*Object {
    _ = .{g};
    stub.unported("game.createPlayer");
}

/// Game slot 03: no class of the game overrides the base stub, which only
/// warns and returns the current scene.
// @orig 1010:46f4 game_create_init_scene_default (absorbed)
pub fn createInitScene(g: *Game, name: []const u8) ?*Scene {
    _ = name;
    ini.messageBoxPrintf(g.plat, &g.messageBuf, "CUIDADO !", "Faltou redefinir o m\xe9todo CreateInitScene", 0);
    return g.scene;
}

/// Game slot 04 (skeleton stub: unported until this unit is).
pub fn createControlPanel(g: *Game) ?*Object {
    _ = .{g};
    stub.unported("game.createControlPanel");
}

/// Game slot 05 (skeleton stub: unported until this unit is).
pub fn createStatusBar(g: *Game) ?*Object {
    _ = .{g};
    stub.unported("game.createStatusBar");
}

/// Game slot 06 (skeleton stub: unported until this unit is).
pub fn createExitScene(g: *Game, exit_index: i16) ?*Scene {
    _ = .{ g, exit_index };
    stub.unported("game.createExitScene");
}

/// Game slot 08 (skeleton stub: unported until this unit is).
pub fn onCreate(g: *Game) *Game {
    _ = .{g};
    stub.unported("game.onCreate");
}
