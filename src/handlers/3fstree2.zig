//! Port unit `handler_3fstree2` (handler). scene handler 1020:897c.

//! The jail-minigame winning cutscene. When its video ends (MM_MCINOTIFY) and
//! the serial-killer minigame (`minigameWon[3]`) was won too, it goes to the
//! hall if the jail minigame (`minigameWon[2]`) was also won, else back to
//! the prison. If `minigameWon[3]` is 0 nothing happens after the video is
//! closed (original behaviour). No scene globals.

const Game = @import("../core/game.zig").Game;
const Msg = @import("../core/msg.zig").Msg;
const msg = @import("../core/msg.zig");
const avi = @import("../avi.zig");
const game_scenes = @import("../game_scenes.zig");
const sound = @import("../sound.zig");
const update_list = @import("../update_list.zig");

// @orig 1020:897c handler_3fstree2
pub fn handle(g: *Game, m: Msg) i16 {
    if (m.id != msg.wm.mm_mcinotify) return 0;
    const playing = g.aviPlaying orelse return 1;
    if (playing.anim.aviDevice == m.lo() and m.wparam == 1) {
        avi.closeAvi(g, playing, playing.anim.aviDevice);
        g.aviPlaying = null;
        _ = sound.mixInit(g);
        if (g.minigameWon[3] != 0) {
            update_list.discard(&g.updateList);
            if (g.minigameWon[2] != 0) {
                // 1020:9c30
                _ = game_scenes.switchScene(g, "3fhall", 0xf0, 0xaa, 1, 1, 0, 0, 0);
            } else {
                // 1020:9c26
                _ = game_scenes.switchScene(g, "3fprisao", 0xf0, 0xaa, 1, 1, 0, 0, 0);
            }
        }
    }
    return 1;
}
