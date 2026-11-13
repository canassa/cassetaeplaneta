//! Port unit `handler_1fcozin0` (handler). scene handler 1018:ecde.
//!
//! The kitchen. Right clicks on the cockroach (object 0x7c) and the ketchup
//! (0x3e) are swallowed while their object mark (slot 01) is set;
//! right-clicking the cockroach exit (0x101) while the cockroach is marked
//! records it as dealt with, and from then on every scene start removes the
//! cockroach and its exit from the scene's object list and the draw list.

const Game = @import("../core/game.zig").Game;
const Msg = @import("../core/msg.zig").Msg;
const msg = @import("../core/msg.zig");
const Object = @import("../core/object.zig").Object;
const backdrop = @import("../backdrop.zig");
const draw_list = @import("../draw_list.zig");
const object_list = @import("../object_list.zig");
const misc = @import("../behaviour/misc.zig");
const visibility = @import("../behaviour/visibility.zig");

const COCKROACH_ID: i16 = 0x7c;
const KETCHUP_ID: i16 = 0x3e;
const COCKROACH_EXIT_ID: i16 = 0x101;

pub const State = struct {
    // @orig g_s1fcozin0CockroachGone
    cockroachGone: i16 = 0,
    // @orig g_s1fcozin0HitObject
    hitObject: ?*Object = null,
    // @orig g_s1fcozin0Cockroach
    cockroach: ?*Object = null,
    // @orig g_s1fcozin0CockroachExit
    cockroachExit: ?*Object = null,
    // @orig g_s1fcozin0Ketchup
    ketchup: ?*Object = null,
};

/// Takes `obj` out of the scene's object list and the draw list.
fn removeFromScene(g: *Game, obj: *Object) void {
    _ = object_list.remove(&g.scene.?.objects, obj);
    draw_list.remove(&g.drawList, obj.as(.object3d));
}

// @orig 1018:ecde handler_1fcozin0
pub fn handle(g: *Game, m: Msg) i16 {
    const s = g.sceneState(State);
    switch (m.id) {
        msg.wm.rbuttondown => {
            const bd = g.scene.?.backdrop.?;
            const q = backdrop.queryRect(g, bd, @as(i16, @bitCast(m.lo())) +% bd.originX, @as(i16, @bitCast(m.hi())) +% bd.originY, 0x10, 0x10);
            s.hitObject = q.obj;
            if (q.result <= 0) return 0;
            const hit = s.hitObject orelse return 0;
            if (!hit.is(.animation)) return 0;
            switch (hit.id) {
                COCKROACH_ID => return @intFromBool(misc.slot01(g, s.cockroach.?) != 0),
                KETCHUP_ID => return @intFromBool(misc.slot01(g, s.ketchup.?) != 0),
                COCKROACH_EXIT_ID => {
                    if (s.cockroachGone != 0) return 0;
                    if (misc.slot01(g, s.cockroach.?) != 0) s.cockroachGone = 1;
                    return 0;
                },
                else => return 0,
            }
        },
        msg.noite.scene_started => {
            if (s.cockroachGone != 0) {
                const bd = g.scene.?.backdrop.?;
                visibility.hide(g, s.cockroach.?, bd);
                visibility.hide(g, s.cockroachExit.?, g.scene.?.backdrop.?);
                removeFromScene(g, s.cockroach.?);
                removeFromScene(g, s.cockroachExit.?);
            }
            return 0;
        },
        msg.noite.object_created => {
            // g_newObject is read (and dereferenced) only for these ids.
            const obj = g.newObject;
            switch (@as(i16, @bitCast(m.wparam))) {
                KETCHUP_ID => {
                    s.ketchup = obj;
                    obj.?.playOnceRewinds = 0;
                },
                COCKROACH_ID => {
                    s.cockroach = obj;
                    obj.?.playOnceRewinds = 0;
                },
                COCKROACH_EXIT_ID => s.cockroachExit = obj,
                else => {},
            }
            return 0;
        },
        else => return 0,
    }
}
