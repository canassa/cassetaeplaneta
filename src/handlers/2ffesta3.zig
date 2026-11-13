//! Port unit `handler_2ffesta3` (handler). scene handler 1020:7452.
//!
//! The party street reached by car: the car (object 0xfd) drives in with the
//! player, the player walks off, and a remark wave chosen by the scene the
//! player came from is played. Then (or on a right click) it moves on to the
//! security-guard scene `3fsegura`.

const Game = @import("../core/game.zig").Game;
const Object = @import("../core/object.zig").Object;
const msg = @import("../core/msg.zig");
const Msg = msg.Msg;
const game_scenes = @import("../game_scenes.zig");
const ini = @import("../ini.zig");
const sound = @import("../sound.zig");
const update_list = @import("../update_list.zig");
const movement = @import("../behaviour/movement.zig");
const space3d = @import("../behaviour/space3d.zig");
const visibility = @import("../behaviour/visibility.zig");

const CAR_ID: u16 = 0xfd;

pub const State = struct {
    // @orig g_s2ffesta3Arrived
    arrived: i16 = 0,
    // @orig g_s2ffesta3Car
    car: ?*Object = null,
};

fn leave(g: *Game, s: *State) i16 {
    s.arrived = 0;
    update_list.discard(&g.updateList);
    _ = game_scenes.switchScene(g, "3fsegura", 0, 0, 0, 0, 0, 0, 0);
    return 1;
}

/// Remark wave by the scene the player came from. The original leaves its
/// stack buffer uninitialised for any other scene (-> just the drive prefix).
fn remarkPath(prev: i16) []const u8 {
    return switch (prev) {
        7 => "fase2\\2ffesta\\ASSASS02.WAV",
        0xb => "fase2\\2ffesta\\stones03.WAV",
        0xd => "fase2\\2ffesta\\boiols02.WAV",
        0x14, 0x17 => "fase2\\2ffesta\\PORTGS03.WAV",
        else => "",
    };
}

// @orig 1020:7452 handler_2ffesta3
pub fn handle(g: *Game, m: Msg) i16 {
    const s = g.sceneState(State);
    switch (m.id) {
        msg.wm.rbuttondown => return leave(g, s),
        msg.wm.mm_wom_done => {
            if (g.prevSceneNumber != 0x14 and g.prevSceneNumber != 0x17) return 1;
            return leave(g, s);
        },
        msg.noite.scene_started => {
            const player = g.player.?;
            const car = s.car.?;
            const bd = g.scene.?.backdrop.?;
            player.mover.allowOffscreen = 1;
            space3d.moveToAndDrop(g, player, 0x2bc, 0xfa, bd);
            car.mover.allowOffscreen = 1;
            movement.moveTo(g, car, 0x2bc, car.y, bd);
            _ = sound.play(g, msg.main_window, car.wave);
            const path = ini.concatStrings(&g.concatBuf, &g.driveCD, remarkPath(g.prevSceneNumber));
            const wave = sound.open(g, path) catch null;
            _ = sound.play(g, msg.main_window, wave);
            return 1;
        },
        msg.noite.movement_finished => {
            if (m.wparam == CAR_ID) {
                const bd = g.scene.?.backdrop.?;
                _ = visibility.invalidate(g, g.player.?);
                movement.moveTo(g, g.player.?, 0xf0, 0x32, bd);
                s.arrived = 1;
                return 1;
            }
            if (s.arrived == 0) return 0;
            if (g.prevSceneNumber == 0x14 or g.prevSceneNumber == 0x17) return 0;
            return leave(g, s);
        },
        msg.noite.object_created => {
            if (m.wparam == CAR_ID) s.car = g.newObject;
            return 1;
        },
        else => return 0,
    }
}
