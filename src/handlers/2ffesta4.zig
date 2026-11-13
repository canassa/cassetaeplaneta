//! Port unit `handler_2ffesta4` (handler). scene handler 1020:7328.
//!
//! Arrival at the party by sports car: when the scene starts the car (object
//! 0x2d) drives across with its sound; when it stops the player is sent
//! walking, and when that movement ends (or on a right click) the game moves
//! on to `3fsegura`.

const Game = @import("../core/game.zig").Game;
const Object = @import("../core/object.zig").Object;
const msg = @import("../core/msg.zig");
const Msg = msg.Msg;
const game_scenes = @import("../game_scenes.zig");
const sound = @import("../sound.zig");
const update_list = @import("../update_list.zig");
const movement = @import("../behaviour/movement.zig");

const CAR_ID: u16 = 0x2d;

pub const State = struct {
    // @orig g_s2ffesta4Arrived
    arrived: i16 = 0,
    // @orig g_s2ffesta4Car
    car: ?*Object = null,
};

fn leave(g: *Game, s: *State) i16 {
    s.arrived = 0;
    update_list.discard(&g.updateList);
    _ = game_scenes.switchScene(g, "3fsegura", 0, 0, 0, 0, 0, 0, 0);
    return 1;
}

// @orig 1020:7328 handler_2ffesta4
pub fn handle(g: *Game, m: Msg) i16 {
    const s = g.sceneState(State);
    switch (m.id) {
        msg.wm.rbuttondown => return leave(g, s),
        msg.noite.scene_started => {
            const car = s.car.?;
            const bd = g.scene.?.backdrop.?;
            car.mover.allowOffscreen = 1;
            movement.moveTo(g, car, -0x17d, car.y, bd);
            _ = sound.play(g, msg.main_window, car.wave);
            return 0;
        },
        msg.noite.movement_finished => {
            if (m.wparam == CAR_ID) {
                const player = g.player.?;
                const bd = g.scene.?.backdrop.?;
                movement.moveTo(g, player, 0xf0, player.y, bd);
                s.arrived = 1;
                return 1;
            }
            if (s.arrived == 0) return 0;
            return leave(g, s);
        },
        msg.noite.object_created => {
            if (m.wparam == CAR_ID) s.car = g.newObject;
            return 1;
        },
        else => return 0,
    }
}
