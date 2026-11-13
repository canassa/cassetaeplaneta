//! Port unit `handler_3fstreet` (handler). scene handler 1020:8750.
//!
//! The street-escape cutscene. When its video ends the jail minigame
//! (`xilindro\xilindro.exe`) is launched and timer 0x14 polls for its window
//! to hand it the main window (0x40b). The minigame's 0x40c hides the main
//! window; its 0x40a result is recorded in `minigameWon[3]`: a win goes to
//! 3fstree2, a loss to 3fstree1 (which takes the life).

const Game = @import("../core/game.zig").Game;
const Msg = @import("../core/msg.zig").Msg;
const msg = @import("../core/msg.zig");
const cstr = @import("../core/cstr.zig");
const platform = @import("../platform/platform.zig");
const avi = @import("../avi.zig");
const game_scenes = @import("../game_scenes.zig");
const sound = @import("../sound.zig");
const update_list = @import("../update_list.zig");

pub const State = struct {
    // @orig g_s3fstreetMinigameRunning (DGROUP 0x0be4, initial 0)
    minigameRunning: i16 = 0,
    // @orig g_s3fstreetMinigameWnd (DGROUP 0x0be6, initial 0; 0 = none)
    minigameWnd: ?platform.Hwnd = null,
};

// @orig 1020:8750 handler_3fstreet
pub fn handle(g: *Game, m: Msg) i16 {
    const s = g.sceneState(State);
    switch (m.id) {
        msg.wm.timer => {
            if (m.wparam != 0x14) return 0;
            // 1020:9ca4
            s.minigameWnd = g.plat.findWindow("Xilindro");
            const w = s.minigameWnd orelse return 0;
            g.killTimer(0x14);
            _ = g.plat.postTo(w, Msg.make(msg.noite.minigame_hello, 0, msg.main_window, 0));
            return 0;
        },
        msg.wm.systimer => {
            if (s.minigameRunning == 0) return 0;
            if (g.plat.findWindow("Xilindro") == null) {
                _ = g.post(Msg.make(msg.noite.minigame_result, 0, 0, 0));
            }
            return 1;
        },
        msg.wm.mm_mcinotify => {
            const playing = g.aviPlaying orelse return 1;
            if (playing.anim.aviDevice == m.lo() and m.wparam == 1) {
                avi.closeAvi(g, playing, playing.anim.aviDevice);
                g.aviPlaying = null;
                _ = sound.mixInit(g);
                var cmd: [256]u8 = undefined;
                // 1018:b784 "%s%s", 1020:9cae
                _ = cstr.print(&cmd, "{s}{s}", .{ cstr.slice(&g.driveCD), "xilindro\\xilindro.exe" });
                _ = g.plat.winExec(cstr.slice(&cmd));
                g.setTimer(0x14, 100);
            }
            return 1;
        },
        msg.noite.minigame_result => {
            result(g, s, m);
            return 0;
        },
        msg.noite.minigame_ready => {
            s.minigameRunning = 1;
            g.plat.showMain(false);
            return 0;
        },
        else => return 0,
    }
}

/// 0x40a: wParam = won, lParam = score.
fn result(g: *Game, s: *State, m: Msg) void {
    _ = g.plat.realizePalette(&g.scene.?.backdrop.?.bmiColors);
    s.minigameRunning = 0;
    g.plat.showMain(true);
    g.minigameWon[3] = @intFromBool(m.wparam != 0);
    g.score +%= m.lparam;
    s.minigameWnd = null;
    update_list.discard(&g.updateList);
    // won: 1020:9cc4 "3fstree2"; lost: 1020:9cce "3fstree1"
    const name: []const u8 = if (g.minigameWon[3] == 0) "3fstree1" else "3fstree2";
    _ = game_scenes.switchScene(g, name, 0, 0, 0, 0, 0, 1, 0);
}
