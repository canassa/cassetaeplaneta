//! Port unit `handler_2bfedriv` (handler). scene handler 1018:f7d4.
//!
//! The driving cutscene: when the scene starts the boy's driving animation
//! (object 0xfa) plays with the car music; when the music ends (a right
//! click ends it at once) everything stops and one of three police
//! cutscenes is picked at random.

const Game = @import("../core/game.zig").Game;
const Msg = @import("../core/msg.zig").Msg;
const msg = @import("../core/msg.zig");
const Object = @import("../core/object.zig").Object;
const animation = @import("../behaviour/animation.zig");
const tick = @import("../behaviour/tick.zig");
const game_scenes = @import("../game_scenes.zig");
const sound = @import("../sound.zig");
const ini = @import("../ini.zig");

const boy_id: u16 = 0xfa;

pub const State = struct {
    // @orig g_s2bfedrivBoyDriving
    boyDriving: ?*Object = null,
    // @orig g_s2bfedrivUnk0B50 (only ever written, with 0)
    unk0B50: i16 = 0,
    // @orig g_s2bfedrivRandom
    random: i16 = 0,
};

// @orig 1018:f7d4 handler_2bfedriv
pub fn handle(g: *Game, m: Msg) i16 {
    const s = g.sceneState(State);
    switch (m.id) {
        msg.wm.rbuttondown => {
            // Fakes the end of the music.
            _ = g.post(Msg.make(msg.wm.mm_wom_done, 0, 0, 0));
        },
        msg.wm.mm_wom_done => {
            const bd = g.scene.?.backdrop.?;
            animation.stopAndRedraw(g, s.boyDriving.?, bd);
            sound.stopAll(&g.sound, g.plat);
            s.unk0B50 = 0;
            s.random = ini.randomBelow(&g.rand, g.plat, 3);
            // The original's switch has a never-taken fall-through returning 1.
            const name: []const u8 = switch (s.random) {
                0 => "2fcopbom",
                1 => "2acopmau",
                2 => "2acopmu",
                else => return 1,
            };
            _ = game_scenes.switchScene(g, name, 0, 0, 0, 0, 0, 1, 0);
        },
        msg.noite.scene_started => {
            const bd = g.scene.?.backdrop.?;
            tick.play(g, s.boyDriving.?.as(.animation).?, bd);
            s.unk0B50 = 0;
            const path = ini.concatStrings(&g.concatBuf, &g.driveCD, "fase2\\2BFEDRIV\\musicar.wav");
            const wave = sound.open(g, path) catch null;
            _ = sound.play(g, msg.main_window, wave);
        },
        msg.noite.object_created => {
            if (m.wparam == boy_id) s.boyDriving = g.newObject;
        },
        else => return 0,
    }
    return 1;
}
