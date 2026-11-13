//! Port unit `handler_espquete` (handler). scene handler 1028:0a88.
//!
//! The garden cutscene. When its video ends the garden minigame
//! (`jardim\jardim.exe`) is launched and timer 0x14 polls for its window to
//! hand it the main window (0x40b, wParam = variant 1). Its 0x40c hides the
//! main window (or, if the poll has not run yet, answers with 0x40a); the
//! 0x40a result goes to `6fsai1` (first ending) on a win, to the game-over
//! scene `6fsaida` on a loss.
//!
//! The original also `_chdrive`/`_chdir`s the CD drive into `<CD>jardim`
//! before launching and restores only the drive afterwards (BUGS.md B11);
//! the platform has no current-directory state, so that has no effect here.

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
    // @orig g_espqueteMinigameRunning (DGROUP 0x0c8a, initial 0)
    minigameRunning: i16 = 0,
    // @orig g_espqueteMinigameWnd (DGROUP 0x0c8c, initial 0; 0 = none)
    minigameWnd: ?platform.Hwnd = null,
    // @orig g_espqueteWon (DGROUP 0x0c8e, initial 0)
    won: i16 = 0,
};

// @orig 1028:0a88 handler_espquete
pub fn handle(g: *Game, m: Msg) i16 {
    const s = g.sceneState(State);
    switch (m.id) {
        msg.wm.timer => {
            if (m.wparam != 0x14) return 0;
            // 1028:1334 "Noite Animal Jardim"
            s.minigameWnd = g.plat.findWindow("Noite Animal Jardim");
            const w = s.minigameWnd orelse return 0;
            s.minigameRunning = 1;
            g.plat.showMain(false);
            // wParam = variant 1, lParam = the main window. The timer is
            // not killed here (0x40c does it).
            _ = g.plat.postTo(w, Msg.make(msg.noite.minigame_hello, 1, msg.main_window, 0));
            return 0;
        },
        msg.wm.systimer => {
            if (s.minigameRunning == 0) return 0;
            if (g.plat.findWindow("Noite Animal Jardim") == null) {
                _ = g.post(Msg.make(msg.noite.minigame_result, 0, 0, 0));
            }
            return 1;
        },
        msg.wm.mm_mcinotify => {
            const playing = g.aviPlaying orelse return 1;
            if (playing.anim.aviDevice != m.lo() or m.wparam != 1) return 1;
            avi.closeAvi(g, playing, playing.anim.aviDevice);
            g.aviPlaying = null;
            // _getdrive / _chdrive / _chdir("<CD>jardim") (1028:1348): no effect here.
            var cmd: [256]u8 = undefined;
            // 1018:b784 "%s%s", 1028:1366
            _ = cstr.print(&cmd, "{s}{s}", .{ cstr.slice(&g.driveCD), "jardim\\jardim.exe" });
            _ = g.plat.winExec(cstr.slice(&cmd));
            g.setTimer(0x14, 100);
            return 1;
        },
        msg.noite.minigame_result => {
            result(g, s, m);
            return 0;
        },
        msg.noite.minigame_ready => {
            if (s.minigameRunning == 0) {
                s.minigameRunning = 1;
                if (s.minigameWnd) |w| _ = g.plat.postTo(w, Msg.make(msg.noite.minigame_result, 0, 0, 0));
                g.killTimer(0x14);
                g.plat.showMain(false);
            } else {
                if (s.minigameWnd) |w| _ = g.plat.postTo(w, Msg.make(msg.noite.minigame_result, 0, 0, 0));
            }
            return 0;
        },
        else => return 0,
    }
}

/// 0x40a: wParam = won, lParam = score.
fn result(g: *Game, s: *State, m: Msg) void {
    s.minigameRunning = 0;
    g.plat.showMain(true);
    s.won = @intFromBool(m.wparam != 0);
    g.score +%= m.lparam;
    s.minigameWnd = null;
    _ = sound.mixInit(g);
    // _chdrive(saved drive) and the unused "<CD> minus last char" path: no effect.
    const won = s.won;
    s.minigameWnd = null;
    s.minigameRunning = 0;
    s.won = 0;
    update_list.discard(&g.updateList);
    // won: 1028:1378 "6fsai1"; lost: 1018:f17a "6fsaida"
    // no life is taken; player at (0, 0), only 1animation set.
    const name: []const u8 = if (won == 0) "6fsaida" else "6fsai1";
    _ = game_scenes.switchScene(g, name, 0, 0, 0, 0, 0, 1, 0);
}
