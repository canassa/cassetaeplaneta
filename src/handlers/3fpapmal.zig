//! Port unit `handler_3fpapmal` (handler). scene handler 1020:8b40.
//!
//! The pope's punishment cutscene: when its video ends the hell minigame
//! (INFERNO.EXE) is launched. Either result returns to the hall (3fhall); a
//! loss costs a life, and at zero lives the game-over scene (6fsaida).
//!
//! Timer 0x14 (100 ms) polls for the minigame's window to send it the
//! 0x40b hello; the system timer (0x118) detects a minigame that vanished
//! without reporting and then posts a lost result (0x40a, 0, 0).

const Game = @import("../core/game.zig").Game;
const Object = @import("../core/object.zig").Object;
const msg = @import("../core/msg.zig");
const Msg = msg.Msg;
const cstr = @import("../core/cstr.zig");
const avi = @import("../avi.zig");
const game_scenes = @import("../game_scenes.zig");
const sound = @import("../sound.zig");
const update_list = @import("../update_list.zig");

pub const State = struct {
    // @orig g_s3fpapmalMinigameRunning
    minigameRunning: i16 = 0,
    // @orig g_s3fpapmalMinigameWnd
    minigameWnd: u16 = 0,
    // @orig g_s3fpapmalWon
    won: i16 = 0,
    // @orig g_s3fpapmalAvi
    avi: ?*Object = null,
};

// @orig 1020:8b40 handler_3fpapmal
pub fn handle(g: *Game, m: Msg) i16 {
    const s = g.sceneState(State);
    switch (m.id) {
        msg.wm.mm_mcinotify => {
            // Unlike the engine default, only a successful completion counts.
            const playing = g.aviPlaying orelse return 1;
            if (playing.anim.aviDevice != m.lo() or m.wparam != 1) return 1;
            avi.stopAvi(g, playing, playing.anim.aviDevice);
            avi.closeAvi(g, playing, playing.anim.aviDevice);
            g.aviPlaying = null;
            _ = sound.mixInit(g);
            var buf: [256]u8 = undefined;
            // 1020:9ce0
            const cmd = cstr.print(&buf, "{s}{s}", .{ cstr.slice(&g.driveCD), "inferno\\inferno.exe" });
            _ = g.plat.winExec(cmd);
            g.setTimer(0x14, 100);
            return 1;
        },
        msg.wm.timer => {
            if (m.wparam != 0x14) return 0;
            const w = g.plat.findWindow("Inferno") orelse {
                s.minigameWnd = 0;
                return 0;
            };
            s.minigameWnd = w;
            g.killTimer(0x14);
            _ = g.plat.postTo(w, Msg.make(msg.noite.minigame_hello, 0, msg.main_window, 0));
            return 0;
        },
        msg.wm.systimer => {
            if (s.minigameRunning == 0) return 0;
            if (g.plat.findWindow("Inferno") == null) {
                _ = g.post(Msg.make(msg.noite.minigame_result, 0, 0, 0));
            }
            return 1;
        },
        msg.noite.object_created => {
            if (m.wparam == 0xa8) s.avi = g.newObject;
            return 0;
        },
        msg.noite.minigame_ready => {
            s.minigameRunning = 1;
            g.plat.showMain(false);
            return 0;
        },
        msg.noite.minigame_result => {
            const bd = g.scene.?.backdrop.?;
            _ = g.plat.realizePalette(&bd.bmiColors);
            s.minigameRunning = 0;
            g.plat.showMain(true);
            g.score +%= @as(i32, @bitCast(m.lparam));
            s.minigameWnd = 0;
            s.won = @intFromBool(m.wparam != 0);
            if (m.wparam == 0) {
                g.lives -%= 1;
                if (g.lives == 0) {
                    s.minigameRunning = 0;
                    s.won = 0;
                    update_list.discard(&g.updateList);
                    // 1018:f17a
                    _ = game_scenes.switchScene(g, "6fsaida", 0, 0, 0, 0, 0, 1, 0);
                    return 0;
                }
            }
            s.minigameRunning = 0;
            s.won = 0;
            update_list.discard(&g.updateList);
            // 1020:9c30
            _ = game_scenes.switchScene(g, "3fhall", 0xf0, 0xaa, 1, 1, 0, 0, 0);
            return 0;
        },
        else => return 0,
    }
}
