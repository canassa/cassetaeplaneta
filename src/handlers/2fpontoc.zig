//! Port unit `handler_2fpontoc` (handler). scene handler 1018:f182.
//!
//! The street in front of the house. Right-clicking the bus stop (object
//! 0xfb) or the car stop (0x78) calls that vehicle: it drives in, the player
//! boards, it drives off and a random destination scene follows (bus: three
//! cutscenes, car: four). Right-clicking the door (0x15f) goes back to the
//! living room.

const Game = @import("../core/game.zig").Game;
const Object = @import("../core/object.zig").Object;
const msg = @import("../core/msg.zig");
const Msg = msg.Msg;
const backdrop = @import("../backdrop.zig");
const frames = @import("../frames.zig");
const game_scenes = @import("../game_scenes.zig");
const ini = @import("../ini.zig");
const panels = @import("../panels.zig");
const sound = @import("../sound.zig");
const update_list = @import("../update_list.zig");
const animation = @import("../behaviour/animation.zig");
const misc = @import("../behaviour/misc.zig");
const movement = @import("../behaviour/movement.zig");
const render = @import("../behaviour/render.zig");
const visibility = @import("../behaviour/visibility.zig");

const CAR_ID: u16 = 0x78;
const BUS_ID: u16 = 0xfb;
const DOOR_ID: u16 = 0x15f;

pub const State = struct {
    // @orig g_s2fpontocBoarding
    boarding: i16 = 0,
    // @orig g_s2fpontocHitObject
    hitObject: ?*Object = null,
    // @orig g_s2fpontocBus
    bus: ?*Object = null,
    // @orig g_s2fpontocCar
    car: ?*Object = null,
    // @orig g_s2fpontocDoor
    door: ?*Object = null,
    // @orig g_s2fpontocRandom
    random: i16 = 0,
    // @orig g_s2fpontocDestination
    destination: i16 = 0,
};

/// Right click on the vehicle: let it move off-screen (to `x`) and play its
/// sound.
fn callVehicle(g: *Game, vehicle: *Object, x: i16) i16 {
    vehicle.mover.allowOffscreen = 1;
    animation.stop(g, g.player.?);
    movement.moveTo(g, vehicle, x, vehicle.y, g.scene.?.backdrop.?);
    _ = sound.play(g, msg.main_window, vehicle.wave);
    return 1;
}

// @orig 1018:f182 handler_2fpontoc
pub fn handle(g: *Game, m: Msg) i16 {
    const s = g.sceneState(State);
    switch (m.id) {
        msg.wm.rbuttondown => {
            if (m.hi() >= 0x168 and panels.isOpen(g, g.controlPanel.?)) return 0;
            const bd = g.scene.?.backdrop.?;
            const q = backdrop.queryRect(g, bd, @as(i16, @bitCast(m.lo())) +% bd.originX, @as(i16, @bitCast(m.hi())) +% bd.originY, 0x10, 0x10);
            s.hitObject = q.obj;
            if (q.result < 1) return 0;
            const hit = s.hitObject orelse return 0;
            if (hit.id == 1) {
                if (misc.slot01(g, hit) == 0) return callVehicle(g, s.bus.?, -0x17d);
            } else if (hit.id == 2 and misc.slot01(g, hit) == 0) {
                return callVehicle(g, s.car.?, 0x19e);
            }
            if (hit.id != 0x15f) return 0;
            if (misc.slot01(g, hit) != 0) return 0;
            s.boarding = 0;
            _ = sound.play(g, msg.main_window, s.door.?.wave);
            update_list.discard(&g.updateList);
            g.itemSelected = 0;
            _ = game_scenes.switchScene(g, "1fsala", 0x32, 0xc8, 1, 1, 0, 0, 0);
            return 1;
        },
        msg.noite.exit_finished => {
            if (g.exitPending == 0) return 0;
            g.exitPending = 0;
            g.itemSelected = 0;
            s.boarding = 0;
            // (name, has_player, has_control_panel, is_1animation)
            const name: []const u8, const has_cp: i16, const is1: i16 = switch (m.wparam) {
                2 => .{ "2floucos", 0, 1 },
                3 => .{ "2fonimot", 0, 1 },
                4 => .{ "2apolit", 0, 1 },
                7 => .{ "2fasspap", 0, 0 },
                0xb => .{ "2fshardi", 1, 0 },
                0xc => .{ "2fportdi", 1, 0 },
                0xd => .{ "2fgaydir", 1, 0 },
                else => return 1,
            };
            update_list.discard(&g.updateList);
            _ = game_scenes.switchScene(g, name, 0, 0, 0, has_cp, 0, is1, 0);
            return 1;
        },
        msg.noite.movement_finished => {
            if (m.wparam == CAR_ID or m.wparam == BUS_ID) {
                const car = m.wparam == CAR_ID;
                const v = (if (car) s.car else s.bus).?;
                const bd = g.scene.?.backdrop.?;
                if (misc.slot01(g, v) == 0) {
                    // The vehicle arrived: walk the player to its edge, mark it.
                    movement.moveToEdgeH(g, g.player.?, bd, if (car) 2 else 1);
                    misc.slot00(g, v);
                    s.hitObject = v;
                    s.boarding = 1;
                    return 1;
                }
                // The vehicle left: pick the destination scene.
                visibility.hideAndInvalidate(g, v, 0, bd);
                if (car) {
                    s.random = ini.randomBelow(&g.rand, g.plat, 4);
                    switch (s.random) {
                        0 => s.destination = 0xd,
                        1 => s.destination = 0xc,
                        2 => s.destination = 0xb,
                        3 => s.destination = 7,
                        else => {},
                    }
                } else {
                    s.random = ini.randomBelow(&g.rand, g.plat, 3);
                    switch (s.random) {
                        0 => s.destination = 2,
                        1 => s.destination = 4,
                        2 => s.destination = 3,
                        else => {},
                    }
                }
                g.exitPending = 1;
                _ = g.post(.{ .id = msg.noite.exit_finished, .wparam = @bitCast(s.destination) });
            }
            if (s.boarding == 0) return 0;
            const hit = s.hitObject orelse return 0;
            s.boarding = 0;
            const bd = g.scene.?.backdrop.?;
            visibility.hideAndInvalidate(g, g.player.?, 0, bd);
            frames.resetRects(hit);
            render.draw(g, hit, g.scene.?.backdrop.?);
            _ = visibility.invalidate(g, hit);
            g.scene.?.hasPlayer = 0;
            movement.moveTo(g, hit, 0x280, hit.y, g.scene.?.backdrop.?);
            return 1;
        },
        msg.noite.object_created => {
            switch (m.wparam) {
                CAR_ID => s.car = g.newObject,
                BUS_ID => s.bus = g.newObject,
                DOOR_ID => s.door = g.newObject,
                else => {},
            }
            return 0;
        },
        else => return 0,
    }
}
