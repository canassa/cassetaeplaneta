//! Port unit `handler_4fjarvamp` (handler). scene handler 1028:0d80.
//!
//! The vampire's garden: the scene start (0x401) launches the garden
//! minigame (`jardim\jardim.exe`) and polls (timer 0x14) for its window,
//! which gets 0x40b (wParam = variant, 0 here; lParam = main window). The
//! minigame's 0x40c is answered by posting 0x40a back to it and hiding the
//! main window. Its result (0x40a, wParam = won, lParam = score) adds the
//! score and goes to the second ending (`6fsai2`) on a win or straight to
//! game over (`6fsaida`, no life taken) on a loss.
//!
//! The original also switches the CD drive's current directory to `jardim`
//! (`_chdrive`/`_chdir`, a "n\xe3o trocou diret\xf3rio" box if that fails) and
//! restores only the drive afterwards (BUGS.md B11). The platform's DOS file
//! layer has no current directory (paths are absolute), so that part is
//! not reproduced; the saved drive is kept for fidelity but unused.

const Game = @import("../core/game.zig").Game;
const Msg = @import("../core/msg.zig").Msg;
const msg = @import("../core/msg.zig");
const cstr = @import("../core/cstr.zig");
const platform = @import("../platform/platform.zig");
const game_scenes = @import("../game_scenes.zig");
const update_list = @import("../update_list.zig");

pub const State = struct {
    // @orig g_s4fjarvampMinigameRunning (DGROUP 0x0c90, initial 0)
    minigameRunning: i16 = 0,
    // @orig g_s4fjarvampMinigameWnd (DGROUP 0x0c92, initial 0; 0 = none)
    minigameWnd: ?platform.Hwnd = null,
    // @orig g_s4fjarvampWon (DGROUP 0x0c94, initial 0)
    won: i16 = 0,
    // @orig g_s4fjarvampSavedDrive (DGROUP 0xaae4, BSS = 0); `_getdrive()`
    savedDrive: i16 = 0,
};

// @orig 1028:0d80 handler_4fjarvamp
pub fn handle(g: *Game, m: Msg) i16 {
    const s = g.sceneState(State);
    switch (m.id) {
        msg.wm.timer => {
            if (m.wparam != 0x14) return 0;
            // 1028:1334
            s.minigameWnd = g.plat.findWindow("Noite Animal Jardim");
            const w = s.minigameWnd orelse return 0;
            s.minigameRunning = 1;
            g.plat.showMain(false);
            // 0x40b: wParam = variant 0, lParam = main window
            _ = g.plat.postTo(w, Msg.make(msg.noite.minigame_hello, 0, msg.main_window, 0));
            return 0;
        },
        msg.wm.systimer => {
            if (s.minigameRunning == 0) return 0;
            if (g.plat.findWindow("Noite Animal Jardim") == null) {
                _ = g.post(Msg.make(msg.noite.minigame_result, 0, 0, 0));
            }
            return 1;
        },
        msg.noite.scene_started => {
            var cmd: [256]u8 = undefined;
            // 1018:b784 "%s%s", 1028:1366
            _ = cstr.print(&cmd, "{s}{s}", .{ cstr.slice(&g.driveCD), "jardim\\jardim.exe" });
            _ = g.plat.winExec(cstr.slice(&cmd));
            g.setTimer(0x14, 100);
            return 1;
        },
        msg.noite.minigame_result => {
            s.minigameRunning = 0;
            g.plat.showMain(true);
            s.won = @intFromBool(m.wparam != 0);
            g.score +%= m.lparam;
            const won = s.won != 0;
            s.minigameWnd = null;
            s.minigameRunning = 0;
            s.won = 0;
            update_list.discard(&g.updateList);
            // won: 1028:1380 "6fsai2"; lost: 1018:f17a "6fsaida"
            const name: []const u8 = if (won) "6fsai2" else "6fsaida";
            _ = game_scenes.switchScene(g, name, 0, 0, 0, 0, 0, 1, 0);
            return 0;
        },
        msg.noite.minigame_ready => {
            const w = s.minigameWnd orelse return 0;
            if (s.minigameRunning == 0) {
                s.minigameRunning = 1;
                _ = g.plat.postTo(w, Msg.make(msg.noite.minigame_result, 0, 0, 0));
                g.killTimer(0x14);
                g.plat.showMain(false);
                return 0;
            }
            _ = g.plat.postTo(w, Msg.make(msg.noite.minigame_result, 0, 0, 0));
            return 0;
        },
        else => return 0,
    }
}
