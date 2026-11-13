//! Port unit `handler_2ftaxi` (handler). scene handler 1020:9a3a.
//!
//! The taxi stand: a right click on the taxi stand (object 0x109) sends the
//! taxi (the object created as 0x108) driving to x = 0 with its sound; when
//! it arrives the player goes back to the street (2fpontoc). A right click
//! on object 0x165 leaves for the building entrance (3fentseg).

const Game = @import("../core/game.zig").Game;
const Object = @import("../core/object.zig").Object;
const msg = @import("../core/msg.zig");
const Msg = msg.Msg;
const backdrop = @import("../backdrop.zig");
const game_scenes = @import("../game_scenes.zig");
const sound = @import("../sound.zig");
const update_list = @import("../update_list.zig");
const movement = @import("../behaviour/movement.zig");

const TAXI_ID: u16 = 0x108;

pub const State = struct {
    // @orig g_s2ftaxiHitObject
    hitObject: ?*Object = null,
    // @orig g_s2ftaxiTaxi
    taxi: ?*Object = null,
};

// @orig 1020:9a3a handler_2ftaxi
pub fn handle(g: *Game, m: Msg) i16 {
    const s = g.sceneState(State);
    switch (m.id) {
        msg.wm.rbuttondown => {
            const bd = g.scene.?.backdrop.?;
            const q = backdrop.queryRect(g, bd, @as(i16, @bitCast(m.lo())) +% bd.originX, @as(i16, @bitCast(m.hi())) +% bd.originY, 0x10, 0x10);
            s.hitObject = q.obj;
            if (q.result <= 0) return 0;
            const hit = s.hitObject orelse return 0;
            if (hit.id == 0x109) {
                const taxi = s.taxi.?;
                taxi.mover.allowOffscreen = 1;
                movement.moveTo(g, taxi, 0, taxi.y, g.scene.?.backdrop.?);
                _ = sound.play(g, msg.main_window, taxi.wave);
                return 1;
            }
            if (hit.id == 0x165) {
                update_list.discard(&g.updateList);
                _ = game_scenes.switchScene(g, "3fentseg", 0xaa, 0xf0, 1, 1, 0, 0, 0);
                return 0;
            }
            return 1;
        },
        msg.noite.movement_finished => {
            if (m.wparam != TAXI_ID) return 0;
            update_list.discard(&g.updateList);
            _ = game_scenes.switchScene(g, "2fpontoc", 0xfa, 0xf0, 1, 1, 0, 0, 0);
            return 1;
        },
        msg.noite.object_created => {
            if (m.wparam == TAXI_ID) s.taxi = g.newObject;
            return 0;
        },
        else => return 0,
    }
}
