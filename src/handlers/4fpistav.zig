//! Port unit `handler_4fpistav` (handler). scene handler 1020:c3a4.
//!
//! The dance floor. When the scene starts the dancers (object 0xf2) play and
//! an MCI waveaudio device `dancacasseta` is opened on a file that is not on
//! the disc (BUGS.md B2: `FASE4\4FBOYDJ\MAEEMAE.WAV` exists only at the root
//! and in `PAN\WAV\`), so the open fails and the scene is silent; the
//! activate pause/resume and the notify loop act on a device that does not
//! exist. A right click on the top-right area (or on the dancers) is
//! handled; a right click on the exit area closes the device, resumes the
//! `musica` sequencer and goes to the bar (`4fbar`).

const Game = @import("../core/game.zig").Game;
const Msg = @import("../core/msg.zig").Msg;
const msg = @import("../core/msg.zig");
const Object = @import("../core/object.zig").Object;
const world = @import("../core/world.zig");
const Backdrop = world.Backdrop;
const Scene = world.Scene;
const cstr = @import("../core/cstr.zig");
const tick = @import("../behaviour/tick.zig");
const backdrop = @import("../backdrop.zig");
const game_scenes = @import("../game_scenes.zig");
const platform = @import("../platform/platform.zig");
const sound = @import("../sound.zig");
const update_list = @import("../update_list.zig");

/// INI Numbers of the scene's objects.
const DANCERS_ID: i16 = 0xf2;
const EXIT_ID: u16 = 0x130;

pub const State = struct {
    // @orig g_s4fpistavHitObject
    hitObject: ?*Object = null,
    // @orig g_s4fpistavDancers
    dancers: ?*Object = null,
    // @orig g_s4fpistavExit (written, never read)
    exit: ?*Object = null,
};

/// The original's unchecked pointers: a missing one is a crash there.
fn must(comptime T: type, p: ?*T) *T {
    return p orelse @panic("4fpistav: null pointer");
}

// @orig 1020:c3a4 handler_4fpistav
pub fn handle(g: *Game, m: Msg) i16 {
    const s = g.sceneState(State);
    switch (m.id) {
        msg.wm.rbuttondown => {
            const bd = must(Backdrop, must(Scene, g.scene).backdrop);
            const q = backdrop.queryRect(g, bd, @as(i16, @bitCast(m.lo())) +% bd.originX, @as(i16, @bitCast(m.hi())) +% bd.originY, 16, 16);
            s.hitObject = q.obj;
            if (q.result <= 0) return 0;
            const hit = s.hitObject orelse return 0;
            if (m.lo() < 0x186 or m.hi() > 200) {
                if (hit.id != DANCERS_ID) return 0;
                return 1;
            }
            // 1020:d57c, 1020:78ba
            _ = g.plat.mciString("close dancacasseta");
            _ = g.plat.mciString("play musica");
            _ = sound.mixInit(g);
            update_list.discard(&g.updateList);
            // x, y, player 0, control panel 1, status bar 0, is1animation 0, click exit 0.
            _ = game_scenes.switchScene(g, "4fbar", 0, 0, 0, 1, 0, 0, 0);
            return 1;
        },
        msg.wm.activate => {
            // Activated and not minimized.
            if (m.wparam != 0 and m.hi() == 0) {
                _ = g.plat.mciString("play dancacasseta notify");
                if (sound.mixActivate(&g.sound, g.plat) != 0) return 1;
                _ = g.plat.messageBox("Erro Wave Mix", "N\xe3o consegue ativar", platform.mb.iconexclamation);
            } else {
                _ = g.plat.mciString("pause dancacasseta");
                if (sound.mixDeactivate(&g.sound, g.plat) != 0) return 1;
                _ = g.plat.messageBox("Erro Wave Mix", "N\xe3o consegue desativar", platform.mb.iconexclamation);
            }
            return 1;
        },
        msg.wm.mousemove => {
            if (m.hi() < 0x169) return 0;
            return 1;
        },
        msg.wm.mm_mcinotify => {
            if (m.wparam != 1) return 1;
            _ = g.plat.mciString("play dancacasseta from 0 notify");
            return 1;
        },
        msg.noite.scene_started => {
            sound.stopAll(&g.sound, g.plat);
            sound.freeAll(&g.sound, g.plat);
            sound.mixClose(&g.sound, g.plat);
            _ = g.plat.mciString("pause musica");
            const bd = must(Backdrop, must(Scene, g.scene).backdrop);
            tick.play(g, must(Object, must(Object, s.dancers).as(.animation)), bd);
            // "open " ++ g_driveCD ++ path ++ " type waveaudio alias dancacasseta";
            // 1018:c598 "%s%s%s%s", 1020:d534, 1020:d510. The open fails (B2).
            var cmd: [260]u8 = undefined;
            const c = cstr.print(&cmd, "{s}{s}{s}{s}", .{ "open ", cstr.slice(&g.driveCD), "fase4\\4fboydj\\maeemae.wav", " type waveaudio alias dancacasseta" });
            _ = g.plat.mciString(c);
            _ = g.plat.mciString("play dancacasseta notify");
            return 1;
        },
        msg.noite.object_created => {
            if (m.wparam == 0xf2) {
                s.dancers = g.newObject;
            } else if (m.wparam == EXIT_ID) {
                s.exit = g.newObject;
            }
            return 0;
        },
        else => return 0,
    }
}
