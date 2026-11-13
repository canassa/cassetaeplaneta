//! Port unit `handler_4fmarte` (handler). scene handler 1028:0308.
//!
//! The invaders losing scene. When the scene starts the Martian (INI Number
//! 0xf0) plays its animation and its wave. When the wave ends the animation
//! is stopped (its system timer is re-armed, as the original does) and a
//! life is lost: the player returns to the main bar (`4fbar`), or the game
//! is over (`6fsaida`) when no lives are left. Right-button clicks on the
//! Martian are swallowed.

const Game = @import("../core/game.zig").Game;
const Msg = @import("../core/msg.zig").Msg;
const msg = @import("../core/msg.zig");
const Object = @import("../core/object.zig").Object;
const animation = @import("../behaviour/animation.zig");
const tick = @import("../behaviour/tick.zig");
const backdrop = @import("../backdrop.zig");
const game_scenes = @import("../game_scenes.zig");
const sound = @import("../sound.zig");
const update_list = @import("../update_list.zig");

/// The Martian's INI Number.
const MARTIAN_ID: u16 = 0xf0;

/// The globals are zero in the EXE's initial data (NE DGROUP 0xc7c..0xc82
/// stored as zeros, 0xaac4/0xaac8 in BSS).
pub const State = struct {
    // @orig g_s4fmarteMartian
    martian: ?*Object = null,
    // @orig g_s4fmarteHitObject (object under the cursor, from the grid query)
    hitObject: ?*Object = null,
    // @orig g_s4fmarteUnk0C7C, g_s4fmarteUnk0C7E, g_s4fmarteUnk0C80, g_s4fmarteUnk0C82
    // (only ever cleared, never read)
    unk0c7c: i16 = 0,
    unk0c7e: i16 = 0,
    unk0c80: i16 = 0,
    unk0c82: i16 = 0,
};

// @orig 1028:0308 handler_4fmarte
pub fn handle(g: *Game, m: Msg) i16 {
    const s = g.sceneState(State);
    switch (m.id) {
        msg.wm.rbuttondown => {
            const bd = g.scene.?.backdrop.?;
            const q = backdrop.queryRect(g, bd, @as(i16, @bitCast(m.lo())) +% bd.originX, @as(i16, @bitCast(m.hi())) +% bd.originY, 0x10, 0x10);
            s.hitObject = q.obj;
            if (q.result > 0) {
                if (s.hitObject) |h| {
                    if (h.id == MARTIAN_ID) return 1;
                }
            }
            return 0;
        },
        msg.wm.mm_wom_done => {
            const martian = s.martian.?;
            animation.stopAndRedraw(g, martian, g.scene.?.backdrop.?);
            // The timer id and period are read through two `asAnimation` calls.
            const a = martian.as(.animation).?;
            g.setSystemTimer(@bitCast(a.anim.timerId), @bitCast(a.anim.timerPeriod));
            g.lives -%= 1;
            const over = g.lives == 0;
            s.unk0c80 = 0;
            s.unk0c7c = 0;
            s.unk0c7e = 0;
            s.unk0c82 = 0;
            update_list.discard(&g.updateList);
            if (over) {
                // 1018:f17a; x, y, player, panel, status bar 0, is1animation 1.
                _ = game_scenes.switchScene(g, "6fsaida", 0, 0, 0, 0, 0, 1, 0);
            } else {
                // 1020:d590
                _ = game_scenes.switchScene(g, "4fbar", 0, 0, 0, 1, 0, 0, 0);
            }
            return 0;
        },
        msg.noite.scene_started => {
            const martian = s.martian.?;
            tick.play(g, martian.as(.animation).?, g.scene.?.backdrop.?);
            _ = sound.play(g, msg.main_window, martian.wave);
            return 1;
        },
        msg.noite.object_created => {
            if (m.wparam == MARTIAN_ID) s.martian = g.newObject;
            return 1;
        },
        else => return 0,
    }
}
