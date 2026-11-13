//! Port unit `handler_2ffesta` (handler). scene handler 1020:771a.
//!
//! The party street reached on foot. When the scene starts the player is
//! allowed off-screen and walks towards x = 0xf0; on arrival (0x404) or on any
//! right click the game moves to the security-guard scene "3fsegura".

const Game = @import("../core/game.zig").Game;
const msg = @import("../core/msg.zig");
const Msg = msg.Msg;
const game_scenes = @import("../game_scenes.zig");
const update_list = @import("../update_list.zig");
const movement = @import("../behaviour/movement.zig");

pub const State = struct {
    // @orig g_s2ffestaWalking
    walking: i16 = 0,
};

// @orig 1020:771a handler_2ffesta
pub fn handle(g: *Game, m: Msg) i16 {
    const s = g.sceneState(State);
    switch (m.id) {
        msg.wm.rbuttondown => {},
        msg.noite.scene_started => {
            const player = g.player.?;
            player.mover.allowOffscreen = 1;
            movement.moveTo(g, player, 0xf0, player.y, g.scene.?.backdrop.?);
            s.walking = 1;
            return 1;
        },
        msg.noite.movement_finished => if (s.walking == 0) return 0,
        else => return 0,
    }
    s.walking = 0;
    update_list.discard(&g.updateList);
    _ = game_scenes.switchScene(g, "3fsegura", 0, 0, 0, 0, 0, 0, 0);
    return 1;
}
