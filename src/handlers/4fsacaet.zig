//! Port unit `handler_4fsacaet` (handler). scene handler 1028:0000.
//!
//! The flying-saucer scene. The saucer (`disco`, INI Number 0xf3) plays its
//! animation and wave when the scene starts; when that wave ends the
//! invaders minigame (`inv\inv.exe`) is launched (with a warning box when
//! WinExec reports "out of memory", 8) and timer 0x14 polls for its window
//! to hand it the main window (0x40b). The minigame's 0x40c hides the main
//! window; its 0x40a result adds the score and leaves for `4fmarte2` on a
//! win or `4fmarte` on a loss (no life is taken: the original never
//! touches the lives). A right click on the saucer is swallowed.

const Game = @import("../core/game.zig").Game;
const Msg = @import("../core/msg.zig").Msg;
const msg = @import("../core/msg.zig");
const cstr = @import("../core/cstr.zig");
const platform = @import("../platform/platform.zig");
const backdrop = @import("../backdrop.zig");
const game_scenes = @import("../game_scenes.zig");
const sound = @import("../sound.zig");
const update_list = @import("../update_list.zig");
const animation = @import("../behaviour/animation.zig");
const tick = @import("../behaviour/tick.zig");
const Object = @import("../core/object.zig").Object;

/// INI Number of the saucer.
const DISCO_ID: u16 = 0xf3;

pub const State = struct {
    // @orig g_s4fsacaetMinigameRunning
    minigameRunning: i16 = 0,
    // @orig g_s4fsacaetUnk0C76 (only ever cleared)
    unk0C76: i16 = 0,
    // @orig g_s4fsacaetMinigameWnd (0 = none)
    minigameWnd: ?platform.Hwnd = null,
    // @orig g_s4fsacaetWon
    won: i16 = 0,
    // @orig g_s4fsacaetDisco
    disco: ?*Object = null,
    // @orig g_s4fsacaetHitObject (never written but by the rect query)
    hitObject: ?*Object = null,
};

// @orig 1028:0000 handler_4fsacaet
pub fn handle(g: *Game, m: Msg) i16 {
    const s = g.sceneState(State);
    switch (m.id) {
        msg.wm.mm_wom_done => {
            const bd = g.scene.?.backdrop.?;
            const disco = s.disco.?;
            animation.stopAndRedraw(g, disco, bd);
            const a = disco.as(.animation).?;
            g.setSystemTimer(@bitCast(a.anim.timerId), @bitCast(a.anim.timerPeriod));
            var cmd: [260]u8 = undefined;
            // 1018:b784 "%s%s", 1028:1270
            const line = cstr.print(&cmd, "{s}{s}", .{ cstr.slice(&g.driveCD), "Inv\\Inv.exe" });
            if (g.plat.winExec(line) == 8) {
                // 1028:127c, 1028:1296
                _ = g.plat.messageBox(
                    "Erro na abertura do jogo",
                    "Meu filho 't\xf4' sem mem\xf3ria para jogar. Estou salvando o jogo com o nome ",
                    platform.mb.iconexclamation,
                );
            }
            g.setTimer(0x14, 100);
            return 1;
        },
        msg.wm.timer => {
            if (m.wparam != 0x14) return 0;
            // 1028:12e0
            s.minigameWnd = g.plat.findWindow("Invasores");
            const w = s.minigameWnd orelse return 0;
            g.killTimer(0x14);
            _ = g.plat.postTo(w, Msg.make(msg.noite.minigame_hello, 0, msg.main_window, 0));
            return 0;
        },
        msg.wm.systimer => {
            if (s.minigameRunning == 0) return 0;
            if (g.plat.findWindow("Invasores") == null) {
                _ = g.post(Msg.make(msg.noite.minigame_result, 0, 0, 0));
            }
            return 1;
        },
        msg.wm.rbuttondown => {
            const bd = g.scene.?.backdrop.?;
            const q = backdrop.queryRect(g, bd, @as(i16, @bitCast(m.lo())) +% bd.originX, @as(i16, @bitCast(m.hi())) +% bd.originY, 0x10, 0x10);
            s.hitObject = q.obj;
            const hit: i8 = @truncate(q.result);
            if (hit < 1) return 0;
            const o = s.hitObject orelse return 0;
            if (o.id != DISCO_ID) return 0;
            return 1;
        },
        msg.noite.scene_started => {
            const disco = s.disco.?;
            tick.play(g, disco.as(.animation).?, g.scene.?.backdrop.?);
            _ = sound.play(g, msg.main_window, disco.wave);
            return 1;
        },
        msg.noite.object_created => {
            if (m.wparam == DISCO_ID) s.disco = g.newObject;
            return 1;
        },
        msg.noite.minigame_result => {
            s.minigameRunning = 0;
            g.plat.showMain(true);
            g.score +%= m.lparam;
            s.minigameWnd = null;
            s.minigameRunning = 0;
            s.unk0C76 = 0;
            s.won = @intFromBool(m.wparam != 0);
            update_list.discard(&g.updateList);
            // 1028:12ea "4fmarte2", 1028:12f4 "4fmarte"
            const name = if (s.won != 0) "4fmarte2" else "4fmarte";
            _ = game_scenes.switchScene(g, name, 0, 0, 0, 0, 0, 0, 0);
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
