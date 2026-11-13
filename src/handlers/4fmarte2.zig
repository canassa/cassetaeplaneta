//! Port unit `handler_4fmarte2` (handler). scene handler 1028:04e6.
//!
//! The invaders' winning scene: the Martian (object 0xf1) speaks, and when
//! its wave ends the game goes on to the esoteric cutscene `ESOTEBOY`.

const Game = @import("../core/game.zig").Game;
const Object = @import("../core/object.zig").Object;
const msg = @import("../core/msg.zig");
const Msg = msg.Msg;
const backdrop = @import("../backdrop.zig");
const game_scenes = @import("../game_scenes.zig");
const sound = @import("../sound.zig");
const update_list = @import("../update_list.zig");
const animation = @import("../behaviour/animation.zig");
const tick = @import("../behaviour/tick.zig");

/// The Martian's INI Number.
const MARTIAN_ID: i16 = 0xf1;

pub const State = struct {
    // @orig g_s4fmarte2Martian
    martian: ?*Object = null,
    // @orig g_s4fmarte2HitObject
    hitObject: ?*Object = null,
};

// @orig 1028:04e6 handler_4fmarte2
pub fn handle(g: *Game, m: Msg) i16 {
    const s = g.sceneState(State);
    switch (m.id) {
        msg.wm.rbuttondown => {
            const bd = g.scene.?.backdrop.?;
            const q = backdrop.queryRect(g, bd, @as(i16, @bitCast(m.lo())) +% bd.originX, @as(i16, @bitCast(m.hi())) +% bd.originY, 0x10, 0x10);
            s.hitObject = q.obj;
            if (q.result < 1) return 0;
            const hit = s.hitObject orelse return 0;
            if (hit.id != MARTIAN_ID) return 0;
            return 1;
        },
        msg.wm.mm_wom_done => {
            const mar = s.martian.?;
            animation.stopAndRedraw(g, mar, g.scene.?.backdrop.?);
            g.setSystemTimer(@bitCast(mar.anim.timerId), @bitCast(mar.anim.timerPeriod));
            update_list.discard(&g.updateList);
            // 1028:12fc "ESOTEBOY"; no player, panel, status bar; is1animation 1.
            _ = game_scenes.switchScene(g, "ESOTEBOY", 0, 0, 0, 0, 0, 1, 0);
            return 0;
        },
        msg.noite.scene_started => {
            const mar = s.martian.?;
            tick.play(g, mar, g.scene.?.backdrop.?);
            _ = sound.play(g, msg.main_window, mar.wave);
            return 1;
        },
        msg.noite.object_created => {
            if (m.wparam == MARTIAN_ID) s.martian = g.newObject;
            return 1;
        },
        else => return 0,
    }
}
