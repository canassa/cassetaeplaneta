//! Port unit `handler_1fquarpa` (handler). scene handler 1018:ea72.
//!
//! The parents' bedroom: the father's three voice lines (opened when the
//! scene starts, one picked at random when he is right-clicked) and the
//! moose head, whose animation is rewound on a right-click.

const std = @import("std");
const Game = @import("../core/game.zig").Game;
const Msg = @import("../core/msg.zig").Msg;
const msg = @import("../core/msg.zig");
const Object = @import("../core/object.zig").Object;
const cstr = @import("../core/cstr.zig");
const platform = @import("../platform/platform.zig");
const backdrop = @import("../backdrop.zig");
const frames = @import("../frames.zig");
const sound = @import("../sound.zig");
const ini = @import("../ini.zig");

const father_id = 0xf8;
const moose_id = 99;

pub const State = struct {
    // @orig g_s1fquarpaHitObject
    hitObject: ?*Object = null,
    // @orig g_s1fquarpaFatherWave0
    fatherWave0: ?platform.Wave = null,
    // @orig g_s1fquarpaFatherWave1
    fatherWave1: ?platform.Wave = null,
    // @orig g_s1fquarpaFatherWave2
    fatherWave2: ?platform.Wave = null,
};

fn openVoice(g: *Game, file: []const u8) ?platform.Wave {
    var buf: [256]u8 = undefined;
    const path = cstr.print(&buf, "{s}{s}", .{ cstr.slice(&g.driveCD), file });
    // The original's open cannot fail by limit on this path length.
    return sound.open(g, path) catch null;
}

// @orig 1018:ea72 handler_1fquarpa
pub fn handle(g: *Game, m: Msg) i16 {
    const s = g.sceneState(State);
    if (m.id != msg.wm.rbuttondown) {
        if (m.id == msg.noite.scene_started) {
            s.fatherWave0 = openVoice(g, "pair0.wav");
            s.fatherWave1 = openVoice(g, "pair1.wav");
            s.fatherWave2 = openVoice(g, "pair2.wav");
        }
        return 0;
    }
    const bd = g.scene.?.backdrop.?;
    // x/y = click position plus the backdrop scroll origin; 16x16 probe.
    const q = backdrop.queryRect(g, bd, @as(i16, @bitCast(m.lo())) +% bd.originX, @as(i16, @bitCast(m.hi())) +% bd.originY, 0x10, 0x10);
    s.hitObject = q.obj;
    if (q.result < 1) return 0;
    const hit = s.hitObject orelse return 0;
    if (!hit.is(.animation)) return 0;
    if (hit.id != father_id) {
        if (hit.id == moose_id) _ = frames.setCurFrame(hit, 0);
        return 0;
    }
    const wave = switch (ini.randomBelow(&g.rand, g.plat, 3)) {
        0 => s.fatherWave0,
        1 => s.fatherWave1,
        2 => s.fatherWave2,
        else => return 1,
    };
    _ = sound.play(g, msg.main_window, wave);
    return 1;
}
