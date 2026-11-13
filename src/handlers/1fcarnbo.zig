//! Port unit `handler_1fcarnbo` (handler). scene handler 1018:f038.
//!
//! The losing cutscene after the boy's bedroom. When the scene starts it
//! takes a life, or, with none left, goes to the game-over scene `6fsaida`.

const Game = @import("../core/game.zig").Game;
const Msg = @import("../core/msg.zig").Msg;
const msg = @import("../core/msg.zig");
const game_scenes = @import("../game_scenes.zig");
const update_list = @import("../update_list.zig");

// @orig 1018:f038 handler_1fcarnbo
pub fn handle(g: *Game, m: Msg) i16 {
    if (m.id != msg.noite.scene_started) return 0;
    if (g.lives < 1) {
        update_list.discard(&g.updateList);
        // 1018:f17a "6fsaida"; x=0 y=0, no player/panel/status bar, 1Animation
        _ = game_scenes.switchScene(g, "6fsaida", 0, 0, 0, 0, 0, 1, 0);
        return 1;
    }
    g.lives -%= 1;
    return 0;
}
