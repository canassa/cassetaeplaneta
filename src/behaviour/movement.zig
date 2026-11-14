//! Port unit `movement` (behaviour). SceneObject slots 37-3C, 3E and Mover placeAt: walking, edge walks, stop, movement tick.
//!
//! The GetDC/ReleaseDC pairs of the originals are gone (the DC is the
//! platform screen). The line stepping is a Bresenham walk driven by the
//! movement system timer (`Mover.timerId`); finishing posts 0x404, and the
//! player posts 0x405 on every tick.

const Game = @import("../core/game.zig").Game;
const msg = @import("../core/msg.zig");
const object = @import("../core/object.zig");
const Object = object.Object;
const world = @import("../core/world.zig");
const Backdrop = world.Backdrop;
const animation = @import("animation.zig");
const occupancy = @import("occupancy.zig");
const position = @import("position.zig");
const render = @import("render.zig");
const space3d = @import("space3d.zig");
const visibility = @import("visibility.zig");
const backdrop = @import("../backdrop.zig");
const frames = @import("../frames.zig");

fn abs16(v: i16) i16 {
    return if (v < 0) 0 -% v else v;
}

/// SceneObject slot 37: start moving towards screen point (x, y).
pub fn moveTo(g: *Game, obj: *Object, x: i16, y: i16, bd: *Backdrop) void {
    switch (obj.kind) {
        // @orig 1010:1b1a scene_object_move_to_default (absorbed)
        .local, .animated, .exit, .control_panel, .status_bar => {},
        .moveable, .actor, .portable => moveableMoveTo(g, obj, x, y, bd),
        .player => directionalPlayerMoveTo(g, obj, x, y, bd),
    }
}

/// SceneObject slot 38: start a horizontal walk to an edge (dir 1 left, 2 right).
pub fn moveToEdgeH(g: *Game, obj: *Object, bd: *Backdrop, dir: i16) void {
    switch (obj.kind) {
        // @orig 1010:1b24 scene_object_move_to_edge_h_default (absorbed)
        .local, .animated, .exit, .control_panel, .status_bar => {},
        .moveable, .actor, .portable => moveableMoveToEdgeH(g, obj, bd, dir),
        .player => directionalPlayerMoveToEdgeH(g, obj, bd, dir),
    }
}

/// SceneObject slot 39: start a vertical walk to an edge (dir 4 up, 8 down).
pub fn moveToEdgeV(g: *Game, obj: *Object, bd: *Backdrop, dir: i16) void {
    switch (obj.kind) {
        // @orig 1010:1b2e scene_object_move_to_edge_v_default (absorbed)
        .local, .animated, .exit, .control_panel, .status_bar => {},
        .moveable, .actor, .portable => moveableMoveToEdgeV(g, obj, bd, dir),
        .player => directionalPlayerMoveToEdgeV(g, obj, bd, dir),
    }
}

/// SceneObject slot 3A: stop moving (kill the timer, post 0x404).
pub fn stopMovingDc(g: *Game, obj: *Object, bd: *Backdrop) void {
    switch (obj.kind) {
        // @orig 1010:1b42 scene_object_stop_moving_dc_default (absorbed)
        .local, .animated, .exit, .control_panel, .status_bar => {},
        .moveable, .portable => moveableStopMovingDc(g, obj, bd),
        .actor => actorStopMovingDc(g, obj, bd),
        .player => directionalPlayerStopMovingDc(g, obj, bd),
    }
}

/// SceneObject slot 3B: stop moving (gets the DC, calls slot 3A).
pub fn stopMoving(g: *Game, obj: *Object, bd: *Backdrop) void {
    switch (obj.kind) {
        // @orig 1010:1b38 scene_object_stop_moving_default (absorbed)
        .local, .animated, .exit, .control_panel, .status_bar => {},
        .moveable, .portable => moveableStopMoving(g, obj, bd),
        .actor, .player => actorStopMoving(g, obj, bd),
    }
}

/// SceneObject slot 3C: one movement timer tick.
pub fn moveTick(g: *Game, obj: *Object, bd: *Backdrop) void {
    switch (obj.kind) {
        // @orig 1010:1b4c scene_object_move_tick_default (absorbed)
        .local, .animated, .exit, .control_panel, .status_bar => {},
        .moveable, .portable => moveableMoveTick(g, obj, bd),
        .actor => actorMoveTick(g, obj, bd),
        .player => playerMoveTick(g, obj, bd),
    }
}

/// SceneObject slot 3E: is a movement in progress?
pub fn isMoving(g: *Game, obj: *Object) bool {
    return switch (obj.kind) {
        // @orig 1010:1b64 scene_object_is_moving_default (absorbed)
        .local, .animated, .exit, .control_panel, .status_bar => false,
        .moveable, .actor, .player, .portable => moveableIsMoving(g, obj),
    };
}

/// Mover slot 00 (DirectionalPlayer slot 00): put the object at (x, y).
pub fn placeAt(g: *Game, obj: *Object, x: i16, y: i16, bd: *Backdrop) void {
    switch (obj.kind) {
        .moveable, .actor, .player, .portable => moveablePlaceAt(g, obj, x, y, bd),
        // The Mover vtable only exists on mover kinds (the bare Mover
        // class is never instantiated).
        else => unreachable,
    }
}

// @orig 1010:2c10 mover_is_moving
fn moverIsMoving(g: *Game, obj: *Object) bool {
    _ = g;
    return obj.mover.moving != 0;
}

// @orig 1010:3bc2 moveable_is_moving
fn moveableIsMoving(g: *Game, obj: *Object) bool {
    return moverIsMoving(g, obj);
}

// @orig 1010:3b44 moveable_move_to
fn moveableMoveTo(g: *Game, obj: *Object, x: i16, y: i16, bd: *Backdrop) void {
    moverMoveTo(g, obj, x, y, bd);
}

// @orig 1010:3b66 moveable_move_to_edge_h
fn moveableMoveToEdgeH(g: *Game, obj: *Object, bd: *Backdrop, dir: i16) void {
    moverMoveToEdgeH(g, obj, bd, dir);
}

// @orig 1010:3b86 moveable_move_to_edge_v
fn moveableMoveToEdgeV(g: *Game, obj: *Object, bd: *Backdrop, dir: i16) void {
    moverMoveToEdgeV(g, obj, bd, dir);
}

// @orig 1010:c3ba mover_move_to
/// Starts moving towards screen point (x, y): converted to world
/// coordinates with the sprite's bottom centre on it and clamped to the
/// background unless `allowOffscreen`; sets up the Bresenham line and starts
/// the movement system timer. A zero-length move leaves `moving` 0.
fn moverMoveTo(g: *Game, obj: *Object, x: i16, y: i16, bd: *Backdrop) void {
    const m = &obj.mover;
    m.stepX = abs16(m.stepX);
    m.stepY = abs16(m.stepY);
    m.moving = 1;
    var ty = y;
    if (m.allowOffscreen == 0) {
        const w = frames.width(obj);
        if (0 -% (@divTrunc(w, 2) -% bd.bgWidth) < bd.originX +% x) {
            m.targetX = 0 -% (frames.width(obj) -% bd.bgWidth);
        } else {
            m.targetX = x -% (@divTrunc(frames.width(obj), 2) -% bd.originX);
        }
        if (bd.bgHeight < bd.originY +% y) {
            ty = 0 -% (frames.height(obj) -% bd.bgHeight);
        } else {
            ty = y -% (frames.height(obj) -% bd.originY);
        }
    } else {
        m.targetX = x;
    }
    m.targetY = ty;
    obj.nextX = obj.x;
    obj.nextY = obj.y;
    m.lineDx = m.targetX -% obj.nextX;
    m.lineDy = m.targetY -% obj.nextY;
    if (m.lineDx < 0) {
        m.stepX = 0 -% m.stepX;
        m.lineDx = 0 -% m.lineDx;
    }
    if (m.lineDy < 0) {
        m.stepY = 0 -% m.stepY;
        m.lineDy = 0 -% m.lineDy;
    } else if (m.lineDy == 0) {
        m.lineDy = 1;
    }
    if (m.lineDx == 0 and m.lineDy == 1) {
        m.moving = 0;
    } else {
        if (m.lineDy < m.lineDx) {
            m.errIncX = m.lineDy *% 2;
            m.lineErr = m.lineDy *% 2 -% m.lineDx;
            m.errIncDiag = m.lineErr -% m.lineDx;
            m.errIncY = 0;
        } else {
            m.errIncY = m.lineDx *% -2;
            m.lineErr = m.lineDx *% -2 +% m.lineDy;
            m.errIncDiag = m.lineErr +% m.lineDy;
            m.errIncX = 0;
        }
        g.setSystemTimer(@bitCast(m.timerId), @bitCast(m.timerPeriod));
    }
}

// @orig 1010:c64c mover_move_to_edge_v
/// Vertical move to the bottom edge of the background (dir 8) or half off
/// the top edge (dir 4); any other dir (or no distance) stops.
fn moverMoveToEdgeV(g: *Game, obj: *Object, bd: *Backdrop, dir: i16) void {
    const m = &obj.mover;
    m.stepX = abs16(m.stepX);
    m.stepY = abs16(m.stepY);
    m.moving = 1;
    m.targetX = obj.x;
    if (dir != 8 and dir != 4) {
        m.moving = 0;
        return;
    }
    const off: i16 = if (dir == 8) frames.height(obj) -% bd.bgHeight else @divTrunc(frames.height(obj), 2);
    m.targetY = 0 -% off;
    obj.nextX = obj.x;
    obj.nextY = obj.y;
    m.lineDx = 0;
    m.lineDy = m.targetY -% obj.nextY;
    if (m.lineDy < 0) {
        m.stepY = 0 -% m.stepY;
        m.lineDy = 0 -% m.lineDy;
    } else if (m.lineDy == 0) {
        m.moving = 0;
        return;
    }
    m.errIncY = m.lineDx *% -2;
    m.lineErr = m.errIncY +% m.lineDy;
    m.errIncDiag = m.lineErr +% m.lineDy;
    m.errIncX = 0;
    g.setSystemTimer(@bitCast(m.timerId), @bitCast(m.timerPeriod));
}

// @orig 1010:c7ba mover_move_to_edge_h
/// Horizontal move to the right edge of the background (dir 2) or half off
/// the left edge (dir 1); any other dir (or no distance) stops.
fn moverMoveToEdgeH(g: *Game, obj: *Object, bd: *Backdrop, dir: i16) void {
    const m = &obj.mover;
    m.stepX = abs16(m.stepX);
    m.stepY = abs16(m.stepY);
    m.moving = 1;
    if (dir != 2 and dir != 1) {
        m.moving = 0;
        return;
    }
    const off: i16 = if (dir == 2) frames.width(obj) -% bd.bgWidth else @divTrunc(frames.width(obj), 2);
    m.targetX = 0 -% off;
    m.targetY = obj.y;
    obj.nextX = obj.x;
    obj.nextY = obj.y;
    m.lineDx = m.targetX -% obj.nextX;
    m.lineDy = 1;
    if (m.lineDx < 0) {
        m.stepX = 0 -% m.stepX;
        m.lineDx = 0 -% m.lineDx;
    } else if (m.lineDx == 0) {
        m.moving = 0;
        return;
    }
    m.errIncX = m.lineDy *% 2;
    m.lineErr = m.errIncX -% m.lineDx;
    m.errIncDiag = m.lineErr -% m.lineDx;
    m.errIncY = 0;
    g.setSystemTimer(@bitCast(m.timerId), @bitCast(m.timerPeriod));
}

// @orig 1010:c154 mover_step
/// Advances the next position one Bresenham step towards the target.
fn moverStep(obj: *Object) void {
    const s = stepFrom(obj);
    obj.nextX = s.x;
    obj.nextY = s.y;
    obj.mover.lineErr = s.err;
}

const Step = struct { x: i16, y: i16, err: i16 };

/// mover_step's arithmetic: the next position and line error one step on
/// from the current next position, leaving the object as it is.
fn stepFrom(obj: *const Object) Step {
    const m = &obj.mover;
    const e = m.lineErr;
    var s: Step = .{ .x = obj.nextX, .y = obj.nextY, .err = e };
    if (m.errIncX == 0) {
        if (e < 1) {
            s.x +%= m.stepX;
            s.y +%= m.stepY;
            s.err = e +% m.errIncDiag;
        } else {
            s.y +%= m.stepY;
            s.err = e +% m.errIncY;
        }
    } else {
        if (e < 1) {
            s.x +%= m.stepX;
            s.err = e +% m.errIncX;
        } else {
            s.x +%= m.stepX;
            s.y +%= m.stepY;
            s.err = e +% m.errIncDiag;
        }
    }
    return s;
}

// @orig 1010:c1ea mover_at_target
/// True when the next position is within one step of the target along the
/// major axis.
fn moverAtTarget(obj: *Object) bool {
    const m = &obj.mover;
    if (m.errIncX == 0) {
        return !(abs16(m.stepY) < abs16(obj.nextY -% m.targetY));
    }
    return !(abs16(m.stepX) < abs16(obj.nextX -% m.targetX));
}

/// The body shared by mover_move_tick and moveable_move_tick (the Mover one
/// also invalidates the redrawn rectangle).
fn moveTickBody(g: *Game, obj: *Object, bd: *Backdrop, invalidate: bool) void {
    if (obj.mover.moving == 0) return;
    moverStep(obj);
    if (occupancy.canStep(g, obj, bd)) {
        frames.resetRects(obj);
        placeAt(g, obj, obj.nextX, obj.nextY, bd);
        visibility.redrawOverlapping(g, obj, bd, 1);
        if (invalidate) _ = visibility.invalidate(g, obj);
        _ = backdrop.autoscroll(g, bd, obj, obj.nextX, obj.nextY);
        if (!moverAtTarget(obj)) return;
    }
    stopMovingDc(g, obj, bd);
}

// @orig 1010:c260 mover_move_tick
fn moverMoveTick(g: *Game, obj: *Object, bd: *Backdrop) void {
    moveTickBody(g, obj, bd, true);
}

// @orig 1010:6146 moveable_move_tick
fn moveableMoveTick(g: *Game, obj: *Object, bd: *Backdrop) void {
    moveTickBody(g, obj, bd, false);
}

/// Not in the original (B30's and B36's fixes): starts `obj` walking
/// straight down (or up) its own column to world row `top` (its top-left
/// corner's row). The item's horizontal step is 0, so a target in another
/// column makes a line that never arrives when it is wider than high;
/// `allowOffscreen` takes the target as it is (no bottom-centre
/// conversion, no clamp to the background's right edge) for this call.
pub fn fallTo(g: *Game, obj: *Object, top: i16, bd: *Backdrop) void {
    const m = &obj.mover;
    const keep = m.allowOffscreen;
    m.allowOffscreen = 1;
    moveTo(g, obj, obj.x, top, bd);
    m.allowOffscreen = keep;
}

/// Not in the original (`Fixes.smooth_item_fall`): the system timer that
/// draws a dropped item between the steps of its fall. The INI objects'
/// timers are 1-10, and the scene's WM_SYSTIMER loop only ticks 5-10.
pub const smooth_fall_timer: u16 = 0xfa11;

/// `Fixes.smooth_item_fall`: after a drop started the item's fall, runs
/// `smooth_fall_timer` at a fifth of the item's timer period (its steps are
/// 10 rows, so the in-between frames move 2).
pub fn smoothFallStart(g: *Game, obj: *Object) void {
    if (!g.fixes.smooth_item_fall or obj.kind != .portable or !isMoving(g, obj)) return;
    g.setSystemTimer(smooth_fall_timer, @bitCast(@divTrunc(obj.mover.timerPeriod, 5)));
}

/// One `smooth_fall_timer` tick: puts the falling item `obj` (the selected
/// one) between its last step and the next, in proportion to the time since
/// its own timer last fired. The steps still come from that timer
/// (`moveTick`, as in the original) from the next position this does not
/// touch, so the fall's path, end and timing do not change, and the item's
/// timer (shared with other objects) keeps its period. The timer stops
/// with the fall, or when the item's timer is gone.
pub fn smoothFallTick(g: *Game, obj: ?*Object, bd: *Backdrop) void {
    const o = obj orelse return g.killSystemTimer(smooth_fall_timer);
    if (o.kind != .portable or !isMoving(g, o)) return g.killSystemTimer(smooth_fall_timer);
    const t = g.queue.findTimer(.system, @bitCast(o.mover.timerId)) orelse
        return g.killSystemTimer(smooth_fall_timer);
    if (o.visible == 0) return;
    const period: i32 = @intCast(t.period);
    const left: i32 = @bitCast(t.due -% g.plat.ticks());
    if (left <= 0 or left >= period) return;
    const s = stepFrom(o);
    const x = between(o.nextX, s.x, period - left, period);
    const y = between(o.nextY, s.y, period - left, period);
    if (x == o.x and y == o.y) return;
    frames.resetRects(o);
    placeAt(g, o, x, y, bd);
    visibility.redrawOverlapping(g, o, bd, 1);
}

/// `from` moved the fraction `num / den` (< 1) of the way to `to`.
fn between(from: i16, to: i16, num: i32, den: i32) i16 {
    return @intCast(from + @divTrunc((@as(i32, to) - from) * num, den));
}

/// B26 fix (not in the original): forgets a walk in progress without the
/// stop's side effects (the timer, shared with the animation, keeps
/// running; no 0x404), so the next tick does not resume it from the stale
/// next position.
pub fn cancelWalk(obj: *Object) void {
    const m = &obj.mover;
    m.moving = 0;
    m.stepX = abs16(m.stepX);
    m.stepY = abs16(m.stepY);
    m.targetX = obj.x;
    m.targetY = obj.y;
}

/// The body shared by mover_stop_moving_dc and moveable_stop_moving_dc.
fn stopMovingDcBody(g: *Game, obj: *Object) void {
    const m = &obj.mover;
    m.moving = 0;
    g.killSystemTimer(@bitCast(m.timerId));
    m.stepX = abs16(m.stepX);
    m.stepY = abs16(m.stepY);
    m.prevX = obj.x;
    m.targetX = obj.x;
    m.prevY = obj.y;
    m.targetY = obj.y;
    _ = g.post(.{ .id = msg.noite.movement_finished, .wparam = @bitCast(obj.id) });
}

// @orig 1010:c968 mover_stop_moving_dc
fn moverStopMovingDc(g: *Game, obj: *Object, bd: *Backdrop) void {
    _ = bd;
    stopMovingDcBody(g, obj);
}

// @orig 1010:6290 moveable_stop_moving_dc
fn moveableStopMovingDc(g: *Game, obj: *Object, bd: *Backdrop) void {
    stopMovingDcBody(g, obj);
    // B30: each step of a dropped item's fall put its 3D place on the
    // floor (portable_move_to_and_drop); at the end it goes back to its
    // support's height and is redrawn over what it now lies in front of.
    if (obj.kind != .portable) return;
    const elev = obj.portable.restElev orelse return;
    obj.portable.restElev = null;
    if (obj.visible == 0) return;
    space3d.setElevationAtBottom(g, obj, bd, elev);
    render.draw(g, obj, bd);
    visibility.redrawOverlapping(g, obj, bd, 1);
}

// @orig 1010:c91a mover_stop_moving
fn moverStopMoving(g: *Game, obj: *Object, bd: *Backdrop) void {
    stopMovingDc(g, obj, bd);
}

// @orig 1010:6242 moveable_stop_moving
fn moveableStopMoving(g: *Game, obj: *Object, bd: *Backdrop) void {
    stopMovingDc(g, obj, bd);
}

// @orig 1010:b9ba mover_place_at
/// Frees the grid cells, sets the position, restores the background,
/// re-occupies the grid and draws the object (the original's call to the
/// empty FUN_1010_b348 is omitted).
fn moverPlaceAt(g: *Game, obj: *Object, x: i16, y: i16, bd: *Backdrop) void {
    _ = occupancy.vacate(g, obj, bd);
    position.setPosition(g, obj, x, y);
    render.restoreBackground(g, obj, bd, 1);
    _ = occupancy.occupy(g, obj, bd);
    render.draw(g, obj, bd);
}

// @orig 1010:5684 moveable_place_at
/// As the Mover one, but moves with `moveToAndDrop` (drops onto the floor).
fn moveablePlaceAt(g: *Game, obj: *Object, x: i16, y: i16, bd: *Backdrop) void {
    _ = occupancy.vacate(g, obj, bd);
    space3d.moveToAndDrop(g, obj, x, y, bd);
    render.restoreBackground(g, obj, bd, 1);
    _ = occupancy.occupy(g, obj, bd);
    render.draw(g, obj, bd);
}

// @orig 1010:3fa4 actor_move_tick
/// While moving: one animation frame, then the Moveable tick.
fn actorMoveTick(g: *Game, obj: *Object, bd: *Backdrop) void {
    if (obj.mover.moving != 0) {
        _ = animation.nextFrame(g, obj);
        moveableMoveTick(g, obj, bd);
    }
}

// @orig 1010:3fe2 actor_stop_moving
fn actorStopMoving(g: *Game, obj: *Object, bd: *Backdrop) void {
    _ = animation.setStrip(g, obj, 0, bd);
    moveableStopMoving(g, obj, bd);
}

// @orig 1010:402c actor_stop_moving_dc
fn actorStopMovingDc(g: *Game, obj: *Object, bd: *Backdrop) void {
    _ = animation.setStrip(g, obj, 0, bd);
    moveableStopMovingDc(g, obj, bd);
}

// @orig 1010:6612 player_move_tick
/// The Actor tick, then posts 0x405 with wParam = id; lParam is 0 in the low
/// word and `y` (only when x is negative) in the high word, as compiled.
fn playerMoveTick(g: *Game, obj: *Object, bd: *Backdrop) void {
    actorMoveTick(g, obj, bd);
    const sign: u16 = if (obj.x < 0) 0xffff else 0;
    const hi: u16 = @as(u16, @bitCast(obj.y)) & sign;
    _ = g.post(msg.Msg.make(msg.noite.player_stepped, @bitCast(obj.id), 0, hi));
}

// @orig 1010:e5e8 directional_player_move_to
/// Faces the walk direction (strip 2 left, 1 right), moves; if no movement
/// started, plays the idle pose.
fn directionalPlayerMoveTo(g: *Game, obj: *Object, x: i16, y: i16, bd: *Backdrop) void {
    animation.stop(g, obj);
    const strip: i16 = if (x -% (@divTrunc(frames.width(obj), 2) -% bd.originX) < obj.x) 2 else 1;
    _ = animation.setStrip(g, obj, strip, bd);
    moveableMoveTo(g, obj, x, y, bd);
    if (obj.mover.moving == 0) animation.playIdle(g, obj, bd);
}

// @orig 1010:e6c4 directional_player_move_to_edge_h
fn directionalPlayerMoveToEdgeH(g: *Game, obj: *Object, bd: *Backdrop, dir: i16) void {
    animation.stop(g, obj);
    _ = animation.setStrip(g, obj, if (dir == 2) 1 else 2, bd);
    moveableMoveToEdgeH(g, obj, bd, dir);
    if (obj.mover.moving == 0) animation.playIdle(g, obj, bd);
}

// @orig 1010:e76e directional_player_move_to_edge_v
fn directionalPlayerMoveToEdgeV(g: *Game, obj: *Object, bd: *Backdrop, dir: i16) void {
    animation.stop(g, obj);
    _ = animation.setStrip(g, obj, if (dir == 8) 3 else 4, bd);
    moveableMoveToEdgeV(g, obj, bd, dir);
    if (obj.mover.moving == 0) animation.playIdle(g, obj, bd);
}

// @orig 1010:e818 directional_player_stop_moving_dc
fn directionalPlayerStopMovingDc(g: *Game, obj: *Object, bd: *Backdrop) void {
    actorStopMovingDc(g, obj, bd);
    animation.playIdle(g, obj, bd);
}

test "the in-between frames of a fall" {
    const std = @import("std");
    try std.testing.expectEqual(@as(i16, 102), between(100, 110, 40, 200));
    try std.testing.expectEqual(@as(i16, 108), between(100, 110, 160, 200));
    try std.testing.expectEqual(@as(i16, -8), between(0, -10, 80, 100));
}

test "the Mover-class variants compile" {
    // No kind uses these (the bare Mover class is never instantiated); the
    // Moveable copies are the live ones.
    _ = &moverMoveTick;
    _ = &moverStopMoving;
    _ = &moverPlaceAt;
    _ = &moverStopMovingDc;
}
