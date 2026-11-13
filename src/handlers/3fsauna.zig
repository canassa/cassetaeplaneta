//! Port unit `handler_3fsauna` (handler). scene handler 1020:7f58.
//!
//! The sauna. A right click (once) plays the attendant's animation once and its
//! wave; when the wave ends the SAUNA minigame (`sauna\sauna.exe`, window
//! "Sauna Mista") is launched and timer 0x14 polls for its window to hand it
//! the main window (0x40b). Its 0x40c hides the main window; its 0x40a result
//! is recorded in `minigameWon[4]`. A win, or a loss with lives left, goes
//! back to the hall; a loss that brings lives to exactly 0 goes to the
//! game-over scene (the `DEC; JNZ` test, BUGS.md B1).

const Game = @import("../core/game.zig").Game;
const Msg = @import("../core/msg.zig").Msg;
const msg = @import("../core/msg.zig");
const cstr = @import("../core/cstr.zig");
const Object = @import("../core/object.zig").Object;
const game_scenes = @import("../game_scenes.zig");
const sound = @import("../sound.zig");
const update_list = @import("../update_list.zig");
const animation = @import("../behaviour/animation.zig");

const wm = msg.wm;
const noite = msg.noite;

pub const State = struct {
    // @orig g_s3fsaunaSboal (the attendant, INI Number 0xd1)
    sboal: ?*Object = null,
    // @orig g_s3fsaunaMinigameRunning
    minigameRunning: i16 = 0,
    // @orig g_s3fsaunaStarted
    started: i16 = 0,
    // @orig g_s3fsaunaMinigameWnd (0 = none)
    minigameWnd: msg.Hwnd = 0,
};

// 1020:9c38
const minigame_title = "Sauna Mista";
// 1020:9c44
const minigame_exe = "sauna\\sauna.exe";

// @orig 1020:7f58 handler_3fsauna
pub fn handle(g: *Game, m: Msg) i16 {
    const s = g.sceneState(State);
    switch (m.id) {
        wm.mm_wom_done => {
            var cmd: [256]u8 = undefined;
            // 1018:b784 "%s%s"
            const line = cstr.print(&cmd, "{s}{s}", .{ cstr.slice(&g.driveCD), minigame_exe });
            _ = g.plat.winExec(line); // SW_SHOW (5); result not checked
            g.setTimer(0x14, 100);
            return 0;
        },
        wm.timer => {
            if (m.wparam != 0x14) return 0;
            const w = g.plat.findWindow(minigame_title);
            s.minigameWnd = w orelse 0;
            const win = w orelse return 0;
            g.killTimer(0x14);
            // lParam = the main window handle.
            _ = g.plat.postTo(win, Msg.make(noite.minigame_hello, 0, msg.main_window, 0));
            return 0;
        },
        wm.systimer => {
            if (s.minigameRunning == 0) return 0;
            if (g.plat.findWindow(minigame_title) == null) {
                _ = g.post(Msg.make(noite.minigame_result, 0, 0, 0));
            }
            return 1;
        },
        wm.rbuttondown => {
            if (s.started == 0) {
                s.started = 1;
                if (s.sboal) |obj| {
                    // Cast to Animation (slot 0x124), then Animation slot
                    // 0x1c: play once.
                    animation.playOnce(g, obj.as(.animation).?, g.scene.?.backdrop.?);
                    _ = sound.play(g, msg.main_window, obj.wave);
                } else {
                    _ = sound.play(g, msg.main_window, null);
                }
            }
            return 1;
        },
        noite.scene_started => return 0,
        noite.object_created => {
            if (m.wparam == 0xd1) {
                s.sboal = g.newObject;
                s.sboal.?.playOnceRewinds = 0;
            }
            return 0;
        },
        noite.minigame_ready => {
            s.minigameRunning = 1;
            g.plat.showMain(false);
            return 0;
        },
        noite.minigame_result => return result(g, s, m),
        else => return 0,
    }
}

/// 0x40a: wParam = won, lParam = score.
fn result(g: *Game, s: *State, m: Msg) i16 {
    _ = g.plat.realizePalette(&g.scene.?.backdrop.?.bmiColors);
    s.minigameRunning = 0;
    g.plat.showMain(true);
    g.minigameWon[4] = @intFromBool(m.wparam != 0);
    g.score +%= m.lparam;
    s.minigameWnd = 0;
    if (g.minigameWon[4] == 0) {
        g.lives -%= 1;
        if (g.lives == 0) {
            s.minigameRunning = 0;
            s.started = 0;
            update_list.discard(&g.updateList);
            // 1018:f17a; x, y, player, panel, status bar 0, is1animation 1.
            _ = game_scenes.switchScene(g, "6fsaida", 0, 0, 0, 0, 0, 1, 0);
            return 0;
        }
    }
    s.minigameRunning = 0;
    s.started = 0;
    update_list.discard(&g.updateList);
    // 1020:9c30
    _ = game_scenes.switchScene(g, "3fhall", 0xf0, 200, 1, 1, 0, 0, 0);
    return 0;
}
