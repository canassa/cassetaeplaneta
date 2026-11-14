//! Port unit `saucer` (module) of INV.EXE. the saucer: creation, SaucerVtbl armTimer (the 10 s launch) and checkEdge, saucer_explode.
//!
//! Each function carries `// @orig <seg:xxxx> <name>` with the INV address.
//! The hwnd and hdc parameters are dropped (the platform's screen).

const std = @import("std");
const Game = @import("core/game.zig").Game;
const object = @import("core/object.zig");
const Object = object.Object;
const world = @import("core/world.zig");
const Backdrop = world.Backdrop;
const object_create = @import("object_create.zig");
const animation = @import("behaviour/animation.zig");
const movement = @import("behaviour/movement.zig");
const occupancy = @import("behaviour/occupancy.zig");
const position = @import("behaviour/position.zig");
const visibility = @import("behaviour/visibility.zig");

pub const Error = object_create.Error;

// @orig 1068:0343 inv_create_saucer
/// `g_saucer` = a Saucer (kind `saucer`, hidden, steps 20 x 20, timer 0xc /
/// 60 ms, hit box = the strip-0 size, the two `g_saucerStrip*` strips, at
/// (50, 10)), attached; the 10 s launch timer 0xe through armTimer; `hitFrame`
/// = -1. A failed allocation is a null `g_saucer` in the original, which then
/// crashes.
pub fn createSaucer(g: *Game, bd: *Backdrop) Error!void {
    const s = g.local().create(Object) catch return error.OutOfMemory;
    s.* = .{ .kind = .saucer };
    try object_create.saucerCtor(
        g,
        s,
        0x32,
        10,
        2,
        &g.saucerStripFiles,
        &g.saucerStripFrames,
        &g.saucerStripWidths,
        &g.saucerStripHeights,
        0,
        0,
        g.saucerStripWidths[0],
        g.saucerStripHeights[0],
        0xc,
        0x3c,
        0x14,
        0x14,
        0,
        0,
        true,
    );
    g.saucer = s;
    _ = occupancy.attach(g, s, bd);
    _ = armTimer(g, s, 0xe, 10000, 3);
    s.saucer.hitFrame = -1;
}

// @orig 1068:0a84 saucer_arm_timer
/// SaucerVtbl slot 01 armTimer (saucer_arm_timer; hwnd dropped): stores
/// `timer_id` by `kind` (0 +0x46, 1 +0x48, 2 +0x4a, 3 timer2Id, 0xf +0x44,
/// 0x14 +0x42; others none) and arms the system timer; returns the saucer.
pub fn armTimer(g: *Game, obj: *Object, timer_id: u16, period: u16, kind: i16) *Object {
    switch (kind) {
        0 => obj.saucer.unk42[2] = timer_id,
        1 => obj.saucer.unk42[3] = timer_id,
        2 => obj.saucer.unk42[4] = timer_id,
        3 => obj.saucer.timer2Id = @bitCast(timer_id),
        0xf => obj.saucer.unk42[1] = timer_id,
        0x14 => obj.saucer.unk42[0] = timer_id,
        else => {},
    }
    g.setSystemTimer(timer_id, period);
    return obj;
}

// @orig 1068:0c16 saucer_explode
/// The saucer `obj` is hit: it stops (mover_stop_moving_dc), then `g_saucer`
/// takes strip 1 (the explosion), `framesLeft` 7, is placed 20 px up and left
/// of `obj`, shown, and `obj`'s animation timer started.
pub fn explode(g: *Game, obj: *Object, bd: *Backdrop) void {
    movement.moverStopMovingDc(g, obj);
    const s = g.saucer.?;
    s.curStrip = 1;
    s.anim.framesLeft = 7;
    s.x = obj.x -% 0x14;
    s.y = obj.y -% 0x14;
    visibility.show(g, s, bd);
    animation.play(g, obj, bd);
}

// @orig 1068:0d3e saucer_check_edge
/// SaucerVtbl slot 03 checkEdge (saucer_check_edge; hwnd dropped): the 0xc
/// tick. Right of width / 2: at x >= bgWidth - 2 * width, `unk40` = 0, stop
/// and park (stopMovingDc), hide. Otherwise, with `unk40` 0 (dead: the parked
/// x is 50): stopMoving, strip 0, `unk40` = 1. Then one mover_move_tick (not
/// the Actor2D tick: no frame step); a no-op once stopped.
pub fn checkEdge(g: *Game, obj: *Object, bd: *Backdrop) void {
    if (@divTrunc(position.width(obj), 2) < obj.x) {
        const limit = position.width(obj) *% 2 -% bd.bgWidth;
        if (0 -% limit <= obj.x) {
            obj.saucer.unk40 = 0;
            movement.stopMovingDc(g, obj, bd);
            visibility.hideAndInvalidate(g, obj, 0, bd);
        }
    } else if (obj.saucer.unk40 == 0) {
        movement.stopMoving(g, obj, bd);
        obj.curStrip = 0;
        obj.saucer.unk40 = 1;
    }
    movement.moverMoveTick(g, obj, bd);
}
