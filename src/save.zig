//! Port unit `save` (module). save games (JOGO*.INI): save, load, load objects, file_create.
//!
//! Virtual-slot dispatchers owned by this unit are declared below with
//! their final signatures; their bodies panic until the unit is ported
//! (docs/DESIGN.md "Virtual slots → dispatchers"). Replace each body, keep
//! the signature (other units already call it).

const stub = @import("core/stub.zig");
const Game = @import("core/game.zig").Game;
const File = @import("platform/platform.zig").File;

/// Game slot 09 (skeleton stub: unported until this unit is).
pub fn loadGame(g: *Game, name: []const u8) *Game {
    _ = .{ g, name };
    stub.unported("save.loadGame");
}

/// Game slot 0A (skeleton stub: unported until this unit is).
pub fn saveGame(g: *Game, name: []const u8) void {
    _ = .{ g, name };
    stub.unported("save.saveGame");
}

/// Game slot 0B (skeleton stub: unported until this unit is).
pub fn loadObjects(g: *Game, fd: File) void {
    _ = .{ g, fd };
    stub.unported("save.loadObjects");
}
