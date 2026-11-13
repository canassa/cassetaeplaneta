//! Port unit `game_hook` (module). noite_game_handle_message_hook: right button (exits, pick-up, options, closet picking).
//!
//! Virtual-slot dispatchers owned by this unit are declared below with
//! their final signatures; their bodies panic until the unit is ported
//! (docs/DESIGN.md "Virtual slots → dispatchers"). Replace each body, keep
//! the signature (other units already call it).

const stub = @import("core/stub.zig");
const Game = @import("core/game.zig").Game;
const Msg = @import("core/msg.zig").Msg;

/// Game slot 01 (skeleton stub: unported until this unit is).
pub fn handleMessageHook(g: *Game, m: Msg) i32 {
    _ = .{ g, m };
    stub.unported("game_hook.handleMessageHook");
}
