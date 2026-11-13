//! Port unit `handler_2ffesta2` (handler). scene handler 1020:71fa.
//!
//! Arrival at the party by bus: when the scene starts the bus (object 0xfc)
//! drives across with its sound; when it stops the player is sent walking,
//! and when that movement ends (or on a right click) the game moves on to
//! the third phase's first scene, `3fsegura`.

const Game = @import("../core/game.zig").Game;
const Object = @import("../core/object.zig").Object;
const msg = @import("../core/msg.zig");
const Msg = msg.Msg;
const game_scenes = @import("../game_scenes.zig");
const sound = @import("../sound.zig");
const update_list = @import("../update_list.zig");
const movement = @import("../behaviour/movement.zig");

const BUS_ID: u16 = 0xfc;

pub const State = struct {
    // @orig g_s2ffesta2Arrived
    arrived: i16 = 0,
    // @orig g_s2ffesta2Bus
    bus: ?*Object = null,
};

// @orig 1020:71fa handler_2ffesta2
pub fn handle(g: *Game, m: Msg) i16 {
    const s = g.sceneState(State);
    switch (m.id) {
        msg.noite.scene_started => {
            const bus = s.bus.?;
            bus.mover.allowOffscreen = 1;
            movement.moveTo(g, bus, 0x2bc, bus.y, g.scene.?.backdrop.?);
            _ = sound.play(g, msg.main_window, bus.wave);
            return 0;
        },
        msg.noite.object_created => {
            if (m.wparam == BUS_ID) s.bus = g.newObject;
            return 1;
        },
        msg.noite.movement_finished => {
            if (m.wparam == BUS_ID) {
                const p = g.player.?;
                movement.moveTo(g, p, 0xf0, p.y, g.scene.?.backdrop.?);
                s.arrived = 1;
                return 1;
            }
            if (s.arrived == 0) return 0;
            return leave(g, s);
        },
        msg.wm.rbuttondown => return leave(g, s),
        else => return 0,
    }
}

fn leave(g: *Game, s: *State) i16 {
    s.arrived = 0;
    update_list.discard(&g.updateList);
    _ = game_scenes.switchScene(g, "3fsegura", 0, 0, 0, 0, 0, 0, 0);
    return 1;
}
