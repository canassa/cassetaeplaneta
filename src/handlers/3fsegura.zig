//! Port unit `handler_3fsegura` (handler). scene handler 1020:79d4.
//!
//! The security guard: a remark WAVE plays when the scene starts, then (on
//! its end) the guard animation plays with his own WAVE; when that wave ends,
//! or on a right click, the game moves to the building entrance (`3fentseg`).

const Game = @import("../core/game.zig").Game;
const Msg = @import("../core/msg.zig").Msg;
const msg = @import("../core/msg.zig");
const Object = @import("../core/object.zig").Object;
const world = @import("../core/world.zig");
const Backdrop = world.Backdrop;
const Scene = world.Scene;
const update_list = @import("../update_list.zig");
const ini = @import("../ini.zig");
const tick = @import("../behaviour/tick.zig");
const game_scenes = @import("../game_scenes.zig");
const sound = @import("../sound.zig");

const GUARD_ID: u16 = 0xd2;
const remark_wav = "fase3\\3fentseg\\garots06.wav";

pub const State = struct {
    // @orig g_s3fseguraIntro (initial DGROUP value 1)
    intro: i16 = 1,
    // @orig g_s3fseguraGuard
    guard: ?*Object = null,
};

fn must(comptime T: type, p: ?*T) *T {
    return p orelse @panic("3fsegura: null pointer");
}

// @orig 1020:79d4 handler_3fsegura
pub fn handle(g: *Game, m: Msg) i16 {
    const s = g.sceneState(State);
    switch (m.id) {
        msg.wm.rbuttondown => s.intro = 1,
        msg.wm.mm_wom_done => {
            if (s.intro != 0) {
                const guard = must(Object, s.guard);
                const a = must(Object, guard.as(.animation));
                const bd = must(Backdrop, must(Scene, g.scene).backdrop);
                tick.play(g, a, bd);
                _ = sound.play(g, msg.main_window, guard.wave);
                s.intro = 0;
                return 1;
            }
        },
        msg.noite.scene_started => {
            const path = ini.concatStrings(&g.concatBuf, &g.driveCD, remark_wav);
            const w = sound.open(g, path) catch |e| @panic(@errorName(e));
            _ = sound.play(g, msg.main_window, w);
            return 1;
        },
        msg.noite.object_created => {
            if (m.wparam == GUARD_ID) s.guard = g.newObject;
            return 1;
        },
        else => return 0,
    }
    update_list.discard(&g.updateList);
    _ = game_scenes.switchScene(g, "3fentseg", 0xf0, 0xaa, 1, 1, 0, 0, 0);
    return 1;
}
