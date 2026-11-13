//! Port unit `handler_4finifes` (handler). scene handler 1020:9dc6.
//!
//! The disco entrance. When the scene starts the music pauses, the dance
//! loop plays and the dancers animate. A right click on the hint (objects
//! 0x112/0x113) plays its animation and WAVE; a right click in the top-right
//! area (x >= 0x186, y <= 200) goes to the bar (`4fbarboy`). The hint's WAVE
//! ending stops its animation and re-arms its system timer.

const Game = @import("../core/game.zig").Game;
const Msg = @import("../core/msg.zig").Msg;
const msg = @import("../core/msg.zig");
const Object = @import("../core/object.zig").Object;
const world = @import("../core/world.zig");
const Backdrop = world.Backdrop;
const Scene = world.Scene;
const animation = @import("../behaviour/animation.zig");
const tick = @import("../behaviour/tick.zig");
const backdrop = @import("../backdrop.zig");
const game_scenes = @import("../game_scenes.zig");
const ini = @import("../ini.zig");
const sound = @import("../sound.zig");
const update_list = @import("../update_list.zig");

/// INI Numbers: the dancers, the hint, the hint's sign.
const DANCERS_ID: u16 = 0xee;
const HINT_ID: u16 = 0x112;
const HINT_SIGN_ID: u16 = 0x113;

const dance_wav = "fase4\\4finifes\\dance2.wav";

pub const State = struct {
    // @orig g_s4finifesHitObject
    hitObject: ?*Object = null,
    // @orig g_s4finifesHint
    hint: ?*Object = null,
    // @orig g_s4finifesHintSign
    hintSign: ?*Object = null,
    // @orig g_s4finifesDancers
    dancers: ?*Object = null,
};

/// The original's unchecked pointers: a missing one is a crash there.
fn must(comptime T: type, p: ?*T) *T {
    return p orelse @panic("4finifes: null pointer");
}

fn bdOf(g: *Game) *Backdrop {
    return must(Backdrop, must(Scene, g.scene).backdrop);
}

fn die(e: anyerror) noreturn {
    @panic(@errorName(e));
}

// @orig 1020:9dc6 handler_4finifes
pub fn handle(g: *Game, m: Msg) i16 {
    const s = g.sceneState(State);
    switch (m.id) {
        msg.wm.rbuttondown => {
            const bd = bdOf(g);
            const q = backdrop.queryRect(g, bd, @as(i16, @bitCast(m.lo())) +% bd.originX, @as(i16, @bitCast(m.hi())) +% bd.originY, 16, 16);
            s.hitObject = q.obj;
            if (q.result <= 0) return 0;
            const h = s.hitObject orelse return 0;
            if (m.lo() >= 0x186 and m.hi() <= 200) {
                // 1020:78ba "play musica", 1020:d3b6 "4fbarboy"
                _ = g.plat.mciString("play musica");
                _ = sound.mixInit(g);
                update_list.discard(&g.updateList);
                _ = game_scenes.switchScene(g, "4fbarboy", 0, 0, 0, 1, 0, 0, 0);
                return 1;
            }
            if (@as(u16, @bitCast(h.id)) == DANCERS_ID) return 1;
            if (@as(u16, @bitCast(h.id)) != HINT_ID and @as(u16, @bitCast(h.id)) != HINT_SIGN_ID) return 0;
            const hint = must(Object, s.hint);
            tick.play(g, must(Object, hint.as(.animation)), bdOf(g));
            _ = sound.play(g, msg.main_window, hint.wave);
            return 1;
        },
        msg.wm.mm_wom_done => {
            const hint = must(Object, s.hint);
            animation.stopAndRedraw(g, hint, bdOf(g));
            const a = must(Object, hint.as(.animation));
            g.setSystemTimer(@bitCast(a.anim.timerId), @bitCast(a.anim.timerPeriod));
            return 0;
        },
        msg.noite.scene_started => {
            // 1018:3736 "pause musica"
            _ = g.plat.mciString("pause musica");
            const path = ini.concatStrings(&g.concatBuf, &g.driveCD, dance_wav);
            const w = sound.open(g, path) catch |e| die(e);
            _ = sound.playLoop(g, msg.main_window, w);
            const dancers = must(Object, s.dancers);
            tick.play(g, must(Object, dancers.as(.animation)), bdOf(g));
            return 1;
        },
        msg.noite.object_created => {
            switch (m.wparam) {
                DANCERS_ID => s.dancers = g.newObject,
                HINT_ID => s.hint = g.newObject,
                HINT_SIGN_ID => s.hintSign = g.newObject,
                else => {},
            }
            return 0;
        },
        else => return 0,
    }
}
