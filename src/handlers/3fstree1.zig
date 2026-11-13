//! Port unit `handler_3fstree1` (handler). scene handler 1020:8a64.
//!
//! The jail-minigame losing cutscene. It only reacts to the end of its video
//! (MM_MCINOTIFY): the video is closed, a life is lost, and the player goes
//! back to the prison (`3fprisao`, string at 1020:9c26), or to
//! the game-over scene (`6fsaida`) when no lives are left. No scene globals.

const Game = @import("../core/game.zig").Game;
const Msg = @import("../core/msg.zig").Msg;
const msg = @import("../core/msg.zig");
const avi = @import("../avi.zig");
const game_scenes = @import("../game_scenes.zig");
const sound = @import("../sound.zig");
const update_list = @import("../update_list.zig");

// @orig 1020:8a64 handler_3fstree1
pub fn handle(g: *Game, m: Msg) i16 {
    if (m.id != msg.wm.mm_mcinotify) return 0;
    const playing = g.aviPlaying orelse return 1;
    if (playing.anim.aviDevice == m.lo() and m.wparam == 1) {
        // animation slot 05 closeAvi(device)
        avi.closeAvi(g, playing, playing.anim.aviDevice);
        g.aviPlaying = null;
        _ = sound.mixInit(g);
        // Original bug B1 shape: decrement, then test for exactly 0.
        g.lives -%= 1;
        update_list.discard(&g.updateList);
        if (g.lives == 0) {
            // 1018:f17a; x, y, player, panel, status bar 0, is1animation 1.
            _ = game_scenes.switchScene(g, "6fsaida", 0, 0, 0, 0, 0, 1, 0);
        } else {
            // 1020:9c26
            _ = game_scenes.switchScene(g, "3fprisao", 0xf0, 0xaa, 1, 1, 0, 0, 0);
        }
    }
    return 1;
}
