//! Port unit `handler_3ffarao` (handler). scene handler 1020:81f0.
//!
//! The pharaoh cutscene: when its video ends the ENCAIXE ("Encaixe
//! Perfeito") minigame is launched. A win goes back to the hall; a loss
//! costs a life and goes to the losing cutscene `3fcasame` (`6fsaida`, game
//! over, when lives reaches exactly 0). The result goes to
//! `Game.minigameWon[0]`.

const Game = @import("../core/game.zig").Game;
const Msg = @import("../core/msg.zig").Msg;
const msg = @import("../core/msg.zig");
const cstr = @import("../core/cstr.zig");
const avi = @import("../avi.zig");
const sound = @import("../sound.zig");
const game_scenes = @import("../game_scenes.zig");
const update_list = @import("../update_list.zig");

const wm = msg.wm;
const noite = msg.noite;

pub const State = struct {
    // @orig g_s3ffaraoMinigameRunning
    minigameRunning: i16 = 0,
    // @orig g_s3ffaraoMinigameWnd
    minigameWnd: msg.Hwnd = 0,
};

// 1020:9c54
const minigame_title = "Encaixe Perfeito";
// 1020:9c66
const minigame_exe = "encaixe\\encaixe.exe";

// @orig 1020:81f0 handler_3ffarao
pub fn handle(g: *Game, m: Msg) i16 {
    const s = g.sceneState(State);
    switch (m.id) {
        wm.timer => {
            if (m.wparam == 0x14) {
                const w = g.plat.findWindow(minigame_title);
                s.minigameWnd = w orelse 0;
                if (w) |win| {
                    g.killTimer(0x14);
                    // lParam = the main window handle.
                    _ = g.plat.postTo(win, Msg.make(noite.minigame_hello, 0, msg.main_window, 0));
                }
            }
        },
        wm.systimer => {
            if (s.minigameRunning != 0) {
                if (g.plat.findWindow(minigame_title) == null) {
                    _ = g.post(Msg.make(noite.minigame_result, 0, 0, 0));
                }
                return 1;
            }
        },
        wm.mm_mcinotify => {
            if (g.aviPlaying) |playing| {
                if (playing.anim.aviDevice == m.lo() and m.wparam == 1) {
                    avi.closeAvi(g, playing, playing.anim.aviDevice);
                    g.aviPlaying = null;
                    _ = sound.mixInit(g);
                    var cmd: [256]u8 = undefined;
                    const line = cstr.print(&cmd, "{s}{s}", .{ cstr.slice(&g.baseDir), minigame_exe });
                    _ = g.plat.winExec(line); // SW_SHOW (5); result not checked
                    g.setTimer(0x14, 100);
                }
            }
            return 1;
        },
        noite.minigame_result => {
            g.plat.realizePalette(&g.scene.?.backdrop.?.bmiColors);
            s.minigameRunning = 0;
            g.plat.showMain(true);
            g.minigameWon[0] = @intFromBool(m.wparam != 0);
            g.score +%= m.lparam;
            s.minigameWnd = 0;
            if (g.minigameWon[0] == 0) {
                g.lives -%= 1;
                s.minigameRunning = 0;
                update_list.discard(&g.updateList);
                // The original tests for exactly 0 (BUGS.md B1).
                // 1018:f17a "6fsaida" / 1020:9c7a "3fcasame"; 1animation.
                const name = if (g.lives == 0) "6fsaida" else "3fcasame";
                _ = game_scenes.switchScene(g, name, 0, 0, 0, 0, 0, 1, 0);
            } else {
                s.minigameRunning = 0;
                update_list.discard(&g.updateList);
                // 1020:9c30 "3fhall"; player and control panel at (0xf0, 200).
                _ = game_scenes.switchScene(g, "3fhall", 0xf0, 200, 1, 1, 0, 0, 0);
            }
        },
        noite.minigame_ready => {
            s.minigameRunning = 1;
            g.plat.showMain(false);
        },
        else => {},
    }
    return 0;
}
