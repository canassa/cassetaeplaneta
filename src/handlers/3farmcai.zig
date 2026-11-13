//! Port unit `handler_3farmcai` (handler). scene handler 1020:8458.
//!
//! The prison-escape cutscene. When the scene starts the music is paused and
//! the waves released, and the scene's video plays. When the video ends the
//! serial-killer minigame (`serial\serial.exe`) is launched and timer 0x14
//! polls for its window to hand it the main window (0x40b). The minigame's
//! 0x40c hides the main window; its 0x40a result is recorded in
//! `minigameWon[2]`: a win goes to the hall if the jail minigame
//! (`minigameWon[3]`) is also won, else back to the prison; a loss takes a
//! life, or goes to the game-over scene when none are left.

const Game = @import("../core/game.zig").Game;
const Msg = @import("../core/msg.zig").Msg;
const msg = @import("../core/msg.zig");
const cstr = @import("../core/cstr.zig");
const platform = @import("../platform/platform.zig");
const avi = @import("../avi.zig");
const game_scenes = @import("../game_scenes.zig");
const sound = @import("../sound.zig");
const update_list = @import("../update_list.zig");
const tick = @import("../behaviour/tick.zig");
const Object = @import("../core/object.zig").Object;

pub const State = struct {
    // @orig g_s3farmcaiAvi (the video object, INI Number 0x7f)
    avi: ?*Object = null,
    // @orig g_s3farmcaiMinigameRunning
    minigameRunning: i16 = 0,
    // @orig g_s3farmcaiMinigameWnd (0 = none)
    minigameWnd: ?platform.Hwnd = null,
};

// @orig 1020:8458 handler_3farmcai
pub fn handle(g: *Game, m: Msg) i16 {
    const s = g.sceneState(State);
    switch (m.id) {
        msg.noite.scene_started => {
            // 1018:370e, 1018:3736
            _ = g.plat.mciString("play musica notify");
            _ = g.plat.mciString("pause musica");
            sound.stopAll(&g.sound, g.plat);
            sound.freeAll(&g.sound, g.plat);
            sound.mixClose(&g.sound, g.plat);
            tick.play(g, s.avi.?, g.scene.?.backdrop.?);
            return 1;
        },
        msg.wm.timer => {
            if (m.wparam != 0x14) return 0;
            // 1020:9c84
            s.minigameWnd = g.plat.findWindow("Serial Killer");
            const w = s.minigameWnd orelse return 0;
            g.killTimer(0x14);
            _ = g.plat.postTo(w, Msg.make(msg.noite.minigame_hello, 0, msg.main_window, 0));
            return 0;
        },
        msg.wm.systimer => {
            if (s.minigameRunning == 0) return 0;
            if (g.plat.findWindow("Serial Killer") == null) {
                _ = g.post(Msg.make(msg.noite.minigame_result, 0, 0, 0));
            }
            return 1;
        },
        msg.wm.mm_mcinotify => {
            const playing = g.aviPlaying orelse return 1;
            if (playing.anim.aviDevice == m.lo() and m.wparam == 1) {
                // animation slot 05 closeAvi(device)
                avi.closeAvi(g, playing, playing.anim.aviDevice);
                g.aviPlaying = null;
                _ = sound.mixInit(g);
                var cmd: [256]u8 = undefined;
                // 1018:b784 "%s%s", 1020:9c92
                _ = cstr.print(&cmd, "{s}{s}", .{ cstr.slice(&g.driveCD), "serial\\serial.exe" });
                _ = g.plat.winExec(cstr.slice(&cmd));
                g.setTimer(0x14, 100);
            }
            return 1;
        },
        msg.noite.object_created => {
            if (m.wparam == 0x7f) s.avi = g.newObject;
            return 0;
        },
        msg.noite.minigame_ready => {
            s.minigameRunning = 1;
            g.plat.showMain(false);
            return 0;
        },
        msg.noite.minigame_result => return result(g, s, m),
        else => return 0,
    }
}

/// 0x40a: wParam = won, lParam = score.
fn result(g: *Game, s: *State, m: Msg) i16 {
    g.plat.realizePalette(&g.scene.?.backdrop.?.bmiColors);
    s.minigameRunning = 0;
    g.plat.showMain(true);
    g.minigameWon[2] = @intFromBool(m.wparam != 0);
    g.score +%= m.lparam;
    s.minigameWnd = null;
    if (g.minigameWon[2] == 0) {
        g.lives -%= 1;
        if (g.lives == 0) {
            s.minigameRunning = 0;
            update_list.discard(&g.updateList);
            // 1018:f17a; x, y, player, panel, status bar 0, is1animation 1.
            _ = game_scenes.switchScene(g, "6fsaida", 0, 0, 0, 0, 0, 1, 0);
            return 0;
        }
        return toPrison(g, s);
    }
    if (g.minigameWon[3] == 0) return toPrison(g, s);
    s.minigameRunning = 0;
    update_list.discard(&g.updateList);
    // 1020:9c30
    _ = game_scenes.switchScene(g, "3fhall", 0xf0, 200, 1, 1, 0, 0, 0);
    return 0;
}

fn toPrison(g: *Game, s: *State) i16 {
    s.minigameRunning = 0;
    update_list.discard(&g.updateList);
    // 1020:9c26
    _ = game_scenes.switchScene(g, "3fprisao", 0xf0, 200, 1, 1, 0, 0, 0);
    return 0;
}
