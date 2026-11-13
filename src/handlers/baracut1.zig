//! Port unit `handler_baracut1` (handler). scene handler 1018:f09e.
//!
//! A losing cutscene. When the scene starts it takes a life, or, with none
//! left (lives <= 0, tested before the decrement), goes to the game-over
//! scene `6fsaida`.

const Game = @import("../core/game.zig").Game;
const Msg = @import("../core/msg.zig").Msg;
const msg = @import("../core/msg.zig");
const game_scenes = @import("../game_scenes.zig");
const update_list = @import("../update_list.zig");

// @orig 1018:f09e handler_baracut1
pub fn handle(g: *Game, m: Msg) i16 {
    if (m.id != msg.noite.scene_started) return 0;
    if (g.lives < 1) {
        update_list.discard(&g.updateList);
        // 1018:f17a "6fsaida"; player at (0, 0), no player / control panel,
        // status bar, no 1animation, no click exit.
        _ = game_scenes.switchScene(g, "6fsaida", 0, 0, 0, 0, 1, 0, 0);
        return 1;
    }
    g.lives -%= 1;
    return 0;
}
