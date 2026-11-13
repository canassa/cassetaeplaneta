//! Port unit `handler_4fsalgin` (handler). scene handler 1028:0678.
//!
//! The gym. The scene's two animations are the sporting man (INI Number
//! 0xf4, `4smaoe`, with the "esporgar" wave) and the other one (0xf5,
//! `4smalm`). When the scene starts 0xf5 plays and 0xf4's wave is played;
//! when 0xf4's animation finishes the gym minigame (`salgin\salgin.exe`) is
//! launched and timer 0x14 polls for its window to hand it the main window
//! (0x40b). The minigame's 0x40c hides the main window; its 0x40a result:
//! a win goes to the "espquete" cutscene; a loss takes a life and returns
//! to the main bar, or goes to the game-over scene when none are left.
//! The result is kept in the scene global `won` (always cleared again
//! before the scene switch), not in `Game.minigameWon`.

const Game = @import("../core/game.zig").Game;
const Object = @import("../core/object.zig").Object;
const Backdrop = @import("../core/world.zig").Backdrop;
const msg = @import("../core/msg.zig");
const Msg = msg.Msg;
const backdrop = @import("../backdrop.zig");
const cstr = @import("../core/cstr.zig");
const frames = @import("../frames.zig");
const game_scenes = @import("../game_scenes.zig");
const platform = @import("../platform/platform.zig");
const sound = @import("../sound.zig");
const update_list = @import("../update_list.zig");
const animation = @import("../behaviour/animation.zig");
const render = @import("../behaviour/render.zig");
const tick = @import("../behaviour/tick.zig");
const visibility = @import("../behaviour/visibility.zig");

/// 1028:1306 (cp1252/850 byte 0xe1 = a acute).
const minigame_window = "Sala de Gin\xe1stica";

pub const State = struct {
    // @orig g_s4fsalginMinigameRunning (initial data 0)
    minigameRunning: i16 = 0,
    // @orig g_s4fsalginMinigameWnd (initial data 0 = none)
    minigameWnd: ?platform.Hwnd = null,
    // @orig g_s4fsalginWon (initial data 0)
    won: i16 = 0,
    // @orig g_s4fsalginSmalm (INI Number 0xf5)
    smalm: ?*Object = null,
    // @orig g_s4fsalginSmaoe (INI Number 0xf4)
    smaoe: ?*Object = null,
    // @orig g_s4fsalginHitObject
    hitObject: ?*Object = null,
};

fn bdOf(g: *Game) *Backdrop {
    return g.scene.?.backdrop.?;
}

// @orig 1028:0678 handler_4fsalgin
pub fn handle(g: *Game, m: Msg) i16 {
    const s = g.sceneState(State);
    switch (m.id) {
        msg.noite.scene_started => {
            tick.play(g, s.smalm.?, bdOf(g));
            _ = sound.play(g, msg.main_window, s.smaoe.?.wave);
            return 1;
        },
        msg.wm.timer => {
            if (m.wparam != 0x14) return 0;
            s.minigameWnd = g.plat.findWindow(minigame_window);
            const w = s.minigameWnd orelse return 0;
            g.killTimer(0x14);
            _ = g.plat.postTo(w, Msg.make(msg.noite.minigame_hello, 0, msg.main_window, 0));
            return 0;
        },
        msg.wm.systimer => {
            if (s.minigameRunning == 0) return 0;
            if (g.plat.findWindow(minigame_window) == null) {
                _ = g.post(Msg.make(msg.noite.minigame_result, 0, 0, 0));
            }
            return 1;
        },
        msg.wm.rbuttondown => {
            const bd = bdOf(g);
            const q = backdrop.queryRect(g, bd, @as(i16, @bitCast(m.lo())) +% bd.originX, @as(i16, @bitCast(m.hi())) +% bd.originY, 0x10, 0x10);
            const r: i8 = @truncate(q.result);
            s.hitObject = q.obj;
            if (r < 1) return 0;
            const hit = s.hitObject orelse return 0;
            if (hit.id == 0xf4 or hit.id == 0xf5) return 1;
            return 0;
        },
        msg.wm.mm_wom_done => {
            // animation slot 07 playOnce
            animation.playOnce(g, s.smaoe.?, bdOf(g));
            return 0;
        },
        msg.noite.animation_finished => {
            if (m.wparam != 0xf4) return 0;
            const a = s.smalm.?;
            animation.stopAndRedraw(g, a, bdOf(g));
            g.setSystemTimer(@bitCast(a.anim.timerId), @bitCast(a.anim.timerPeriod));
            _ = frames.setCurFrame(a, 0);
            frames.resetRects(a);
            render.draw(g, a, bdOf(g));
            _ = visibility.invalidate(g, a);
            var cmd: [260]u8 = undefined;
            // 1018:b784 "%s%s", 1028:1318
            _ = cstr.print(&cmd, "{s}{s}", .{ cstr.slice(&g.driveCD), "salgin\\salgin.exe" });
            _ = g.plat.mciString("stop musica");
            _ = g.plat.winExec(cstr.slice(&cmd));
            g.setTimer(0x14, 100);
            return 1;
        },
        msg.noite.object_created => {
            if (m.wparam == 0xf4) {
                s.smaoe = g.newObject;
                s.smaoe.?.playOnceRewinds = 0;
            }
            if (m.wparam == 0xf5) s.smalm = g.newObject;
            return 1;
        },
        msg.noite.minigame_result => return result(g, s, m),
        msg.noite.minigame_ready => {
            s.minigameRunning = 1;
            g.plat.showMain(false);
            return 0;
        },
        else => return 0,
    }
}

/// 0x40a: wParam = won, lParam = score.
fn result(g: *Game, s: *State, m: Msg) i16 {
    s.minigameRunning = 0;
    g.plat.showMain(true);
    s.won = @intFromBool(m.wparam != 0);
    g.score +%= m.lparam;
    s.minigameWnd = null;
    if (s.won != 0) {
        leave(g, s);
        // 1028:132a; x, y, player, panel, status bar 0, is1animation 1.
        _ = game_scenes.switchScene(g, "espquete", 0, 0, 0, 0, 0, 1, 0);
        return 0;
    }
    s.won = 0;
    g.lives -%= 1;
    if (g.lives != 0) {
        leave(g, s);
        // 1020:d590
        _ = game_scenes.switchScene(g, "4fbar", 0, 0, 0, 1, 0, 0, 0);
        return 0;
    }
    leave(g, s);
    // The original discards the update list a second time here.
    update_list.discard(&g.updateList);
    // 1018:f17a
    _ = game_scenes.switchScene(g, "6fsaida", 0, 0, 0, 0, 0, 1, 0);
    return 0;
}

fn leave(g: *Game, s: *State) void {
    s.minigameWnd = null;
    s.minigameRunning = 0;
    s.won = 0;
    update_list.discard(&g.updateList);
}
