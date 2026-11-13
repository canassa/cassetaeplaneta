//! Port unit `handler_1fsala` (handler). scene handler 1018:ebf0.
//!
//! Living room. Right-clicking the cat (object 0x6f) plays its animation
//! once with its sound; right-clicking the curtain (0x6e) rewinds its
//! animation before the engine default plays it.

const Game = @import("../core/game.zig").Game;
const Object = @import("../core/object.zig").Object;
const msg = @import("../core/msg.zig");
const Msg = msg.Msg;
const backdrop = @import("../backdrop.zig");
const frames = @import("../frames.zig");
const animation = @import("../behaviour/animation.zig");
const sound = @import("../sound.zig");

pub const State = struct {
    // @orig g_s1fsalaHitObject
    hitObject: ?*Object = null,
};

// @orig 1018:ebf0 handler_1fsala
pub fn handle(g: *Game, m: Msg) i16 {
    if (m.id != msg.wm.rbuttondown) return 0;
    const s = g.sceneState(State);
    const bd = g.scene.?.backdrop.?;
    // The pick point is the click in scene coordinates (client + scroll),
    // a 16x16 rectangle.
    const q = backdrop.queryRect(g, bd, @as(i16, @bitCast(m.lo())) +% bd.originX, @as(i16, @bitCast(m.hi())) +% bd.originY, 16, 16);
    s.hitObject = q.obj;
    if (q.result <= 0) return 0;
    const obj = s.hitObject orelse return 0;
    if (!obj.is(.animation)) return 0;
    if (obj.id == 0x6f) {
        _ = frames.setCurFrame(obj, 0);
        animation.playOnce(g, obj, g.scene.?.backdrop.?);
        // obj.wave indexes the wave table (the original holds the handle).
        const wave = if (obj.wave) |w| g.sound.waves[w] else null;
        _ = sound.play(g, msg.main_window, wave);
        return 1;
    }
    if (obj.id == 0x6e) _ = frames.setCurFrame(obj, 0);
    return 0;
}
