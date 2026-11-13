//! Port unit `handler_1fquarbo` (handler). scene handler 1018:e806.
//!
//! The boy's bedroom. Right-clicking the radio (object 0x5c) starts its
//! animation and music (the music restarts each time the wave ends); a left
//! click or another right click while it plays stops it and re-marks the
//! bed's (object 0x59) floor cells. The radio animation is ticked here.

const Game = @import("../core/game.zig").Game;
const Msg = @import("../core/msg.zig").Msg;
const msg = @import("../core/msg.zig");
const Object = @import("../core/object.zig").Object;
const world = @import("../core/world.zig");
const Backdrop = world.Backdrop;
const animation = @import("../behaviour/animation.zig");
const occupancy = @import("../behaviour/occupancy.zig");
const tick = @import("../behaviour/tick.zig");
const backdrop = @import("../backdrop.zig");
const frames = @import("../frames.zig");
const sound = @import("../sound.zig");

/// The radio object's INI Number, and the bed's.
const RADIO_ID: i16 = 0x5c;
const BED_ID: i16 = 0x59;

pub const State = struct {
    // @orig g_s1fquarboHitObject
    hitObject: ?*Object = null,
    // @orig g_s1fquarboRadioOn
    radioOn: i16 = 0,
    // @orig g_s1fquarboRadio
    radio: ?*Object = null,
    // @orig g_s1fquarboBed
    bed: ?*Object = null,
};

/// `SceneObject.wave` as the sound unit's handle (Object.wave is u8, Wave u16).
fn waveOf(obj: *Object) ?u16 {
    return if (obj.wave) |w| w else null;
}

/// The tail shared by left click and right click while the radio plays.
fn stopRadio(g: *Game, s: *State, bd: *Backdrop) i16 {
    const radio = s.radio.?;
    animation.stopAndRedraw(g, radio, bd);
    sound.stop(&g.sound, g.plat, waveOf(radio));
    occupancy.reoccupy(g, s.bed.?, g.scene.?.backdrop.?);
    s.radioOn = 0;
    return 0;
}

// @orig 1018:e806 handler_1fquarbo
pub fn handle(g: *Game, m: Msg) i16 {
    const s = g.sceneState(State);
    switch (m.id) {
        msg.wm.rbuttondown => {
            if (s.hitObject != null and animation.isRunning(g, s.radio.?)) {
                return stopRadio(g, s, g.scene.?.backdrop.?);
            }
            const bd = g.scene.?.backdrop.?;
            const q = backdrop.queryRect(g, bd, @as(i16, @bitCast(m.lo())) +% bd.originX, @as(i16, @bitCast(m.hi())) +% bd.originY, 0x10, 0x10);
            s.hitObject = q.obj;
            if (q.result < 1) return 0;
            const hit = s.hitObject orelse return 0;
            if (!hit.is(.animation)) return 0;
            if (hit.id != RADIO_ID) return 0;
            if (s.radioOn != 0) return 0;
            const radio = s.radio.?;
            _ = frames.setCurFrame(radio, 0);
            tick.play(g, radio.as(.animation).?, bd);
            _ = sound.play(g, msg.main_window, waveOf(hit));
            s.radioOn = 1;
            return 1;
        },
        msg.wm.systimer => {
            const radio = s.radio orelse return 0;
            if (@as(u16, @bitCast(animation.getTimerId(g, radio))) == m.wparam) {
                tick.tick(g, radio, g.scene.?.backdrop.?);
            }
            return 0;
        },
        msg.wm.lbuttondown => {
            if (s.hitObject == null) return 0;
            if (!animation.isRunning(g, s.radio.?)) return 0;
            return stopRadio(g, s, g.scene.?.backdrop.?);
        },
        msg.wm.mm_wom_done => {
            if (s.radioOn != 0) _ = sound.play(g, msg.main_window, waveOf(s.radio.?));
            return 1;
        },
        msg.noite.scene_started => {
            animation.stopAndRedraw(g, s.radio.?, g.scene.?.backdrop.?);
            return 0;
        },
        msg.noite.object_created => {
            if (m.wparam == @as(u16, @bitCast(RADIO_ID))) {
                s.radio = g.newObject;
            } else if (m.wparam == @as(u16, @bitCast(BED_ID))) {
                s.bed = g.newObject;
            }
            return 1;
        },
        else => return 0,
    }
}
