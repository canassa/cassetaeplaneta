//! Port unit `handler_6fsaida` (handler). scene handler 1028:1018.
//!
//! The game-over cutscene. When its AVI finishes (MCI notify, successful)
//! it closes the clip, re-inits WaveMix, resets lives to 3 and the score to
//! 0, and goes back to the title menu `fundinic`.

const Game = @import("../core/game.zig").Game;
const msg = @import("../core/msg.zig");
const Msg = msg.Msg;
const avi = @import("../avi.zig");
const game_scenes = @import("../game_scenes.zig");
const sound = @import("../sound.zig");
const update_list = @import("../update_list.zig");

pub const State = struct {
    // Written only (reset to 0 here, never read): unknown purpose.
    // @orig g_s6fsaidaUnk0C96
    unk0c96: i16 = 0,
    // @orig g_s6fsaidaUnk0C98
    unk0c98: i16 = 0,
    // @orig g_s6fsaidaUnk0C9A
    unk0c9a: i16 = 0,
};

// @orig 1028:1018 handler_6fsaida
pub fn handle(g: *Game, m: Msg) i16 {
    if (m.id != msg.wm.mm_mcinotify) return 0;
    const s = g.sceneState(State);
    if (g.aviPlaying) |playing| {
        if (playing.anim.aviDevice == m.lo() and m.wparam == 1) {
            avi.closeAvi(g, playing, playing.anim.aviDevice);
            g.aviPlaying = null;
            _ = sound.mixInit(g);
            g.lives = 3;
            g.score = 0;
            s.unk0c98 = 0;
            s.unk0c96 = 0;
            s.unk0c9a = 0;
            update_list.discard(&g.updateList);
            // 1028:1388 "fundinic"; x=0 y=0, no player/panel/status bar.
            _ = game_scenes.switchScene(g, "fundinic", 0, 0, 0, 0, 0, 0, 0);
        }
    }
    return 1;
}
