//! Port unit `handler_1furso` (handler). scene handler 1018:eee0.
//!
//! The polar-bear cutscene. When the scene starts the bear animation and its
//! sound play; when the sound ends the animation is stopped (its system
//! timer is then re-armed, as the original does) and the game returns to the
//! kitchen (`1fcozin0`) with player and control panel. Right-button clicks
//! are swallowed.

const Game = @import("../core/game.zig").Game;
const Msg = @import("../core/msg.zig").Msg;
const msg = @import("../core/msg.zig");
const Object = @import("../core/object.zig").Object;
const animation = @import("../behaviour/animation.zig");
const tick = @import("../behaviour/tick.zig");
const game_scenes = @import("../game_scenes.zig");
const sound = @import("../sound.zig");
const update_list = @import("../update_list.zig");

pub const State = struct {
    // @orig g_s1fursoBear
    bear: ?*Object = null,
};

/// The bear animation's INI Number.
const BEAR_ID: u16 = 0x77;

// @orig 1018:eee0 handler_1furso
pub fn handle(g: *Game, m: Msg) i16 {
    const s = g.sceneState(State);
    switch (m.id) {
        msg.wm.rbuttondown, msg.wm.rbuttonup => return 1,
        msg.wm.mm_wom_done => {
            const bear = s.bear orelse return 1;
            animation.stopAndRedraw(g, bear, g.scene.?.backdrop.?);
            g.setSystemTimer(@bitCast(bear.anim.timerId), @bitCast(bear.anim.timerPeriod));
            update_list.discard(&g.updateList);
            _ = game_scenes.switchScene(g, "1fcozin0", 0x3a, 0x73, 1, 1, 0, 0, 0);
            return 1;
        },
        msg.noite.scene_started => {
            const bear = s.bear orelse return 1;
            tick.play(g, bear, g.scene.?.backdrop.?);
            _ = sound.play(g, msg.main_window, bear.wave);
            return 1;
        },
        msg.noite.object_created => {
            if (m.wparam == BEAR_ID) s.bear = g.newObject;
            return 1;
        },
        else => return 0,
    }
}
