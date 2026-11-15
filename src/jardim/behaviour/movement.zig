//! Port unit `movement` (behaviour) of JARDIM.EXE. SceneObject slots 34-39 3B (moveTo, edges, stopMoving(Dc), moveTick, isMoving), MoverVtbl placeAt.
//!
//! The Portable and the Player are the Movers (the bare Mover, Actor and
//! Moveable classes are never instantiated: their functions are the kinds'
//! overrides). GetDC/ReleaseDC pairs are gone (the DC is the platform
//! screen); hwnd and hdc parameters are dropped. The walk is TIRO's
//! Bresenham line; the tick and place-at are NOITE's Moveable ones
//! (placeAt moves with moveToAndDrop).

const msg = @import("../../core/msg.zig");
const Game = @import("../core/game.zig").Game;
const object = @import("../core/object.zig");
const Object = object.Object;
const world = @import("../core/world.zig");
const Backdrop = world.Backdrop;
const backdrop = @import("../backdrop.zig");
const animation = @import("animation.zig");
const occupancy = @import("occupancy.zig");
const position = @import("position.zig");
const render = @import("render.zig");
const space3d = @import("space3d.zig");
const visibility = @import("visibility.zig");

fn abs16(v: i16) i16 {
    return if (v < 0) 0 -% v else v;
}

/// SceneObject slot 34 moveTo (hwnd dropped): moveable_move_to (portable, player) / default.
pub fn moveTo(g: *Game, obj: *Object, x: i16, y: i16, bd: *Backdrop) void {
    switch (obj.kind) {
        // @orig 10c0:2438 moveable_move_to
        .portable, .player => moverMoveTo(g, obj, x, y, bd),
        // scene_object_move_to_default (absorbed)
        .scene_object, .wall_strip, .exit, .control_panel => {},
    }
}

/// SceneObject slot 35 moveToEdgeH: moveable_move_to_edge_h (portable, player) / default.
pub fn moveToEdgeH(g: *Game, obj: *Object, bd: *Backdrop, dir: i16) void {
    switch (obj.kind) {
        // @orig 10c0:2468 moveable_move_to_edge_h
        .portable, .player => moverMoveToEdgeH(g, obj, bd, dir),
        // scene_object_move_to_edge_h_default (absorbed)
        .scene_object, .wall_strip, .exit, .control_panel => {},
    }
}

/// SceneObject slot 36 moveToEdgeV: moveable_move_to_edge_v (portable, player) / default.
pub fn moveToEdgeV(g: *Game, obj: *Object, bd: *Backdrop, dir: i16) void {
    switch (obj.kind) {
        // @orig 10c0:2496 moveable_move_to_edge_v
        .portable, .player => moverMoveToEdgeV(g, obj, bd, dir),
        // scene_object_move_to_edge_v_default (absorbed)
        .scene_object, .wall_strip, .exit, .control_panel => {},
    }
}

/// SceneObject slot 37 stopMovingDc: moveable_stop_moving_dc (portable), actor_stop_moving_dc (player) / default.
pub fn stopMovingDc(g: *Game, obj: *Object, bd: *Backdrop) void {
    switch (obj.kind) {
        .portable => moveableStopMovingDc(g, obj),
        .player => actorStopMovingDc(g, obj, bd),
        // scene_object_stop_moving_dc_default (absorbed)
        .scene_object, .wall_strip, .exit, .control_panel => {},
    }
}

/// SceneObject slot 38 stopMoving: moveable_stop_moving (portable), actor_stop_moving (player) / default.
pub fn stopMoving(g: *Game, obj: *Object, bd: *Backdrop) void {
    switch (obj.kind) {
        .portable => moveableStopMoving(g, obj, bd),
        .player => actorStopMoving(g, obj, bd),
        // scene_object_stop_moving_default (absorbed)
        .scene_object, .wall_strip, .exit, .control_panel => {},
    }
}

/// SceneObject slot 39 moveTick: moveable_move_tick (portable), player_move_tick (player) / default.
pub fn moveTick(g: *Game, obj: *Object, bd: *Backdrop) void {
    switch (obj.kind) {
        .portable => moveableMoveTick(g, obj, bd),
        .player => playerMoveTick(g, obj, bd),
        // scene_object_move_tick_default (absorbed)
        .scene_object, .wall_strip, .exit, .control_panel => {},
    }
}

/// SceneObject slot 3B isMoving: moveable_is_moving (portable, player) / default.
pub fn isMoving(g: *Game, obj: *Object) bool {
    _ = g;
    return switch (obj.kind) {
        // @orig 10c0:24ec moveable_is_moving
        .portable, .player => moverIsMoving(obj),
        // scene_object_is_moving_default (absorbed)
        .scene_object, .wall_strip, .exit, .control_panel => false,
    };
}

/// MoverVtbl slot 00 placeAt (moveable_place_at: the Portable's and the Player's).
pub fn placeAt(g: *Game, obj: *Object, x: i16, y: i16, bd: *Backdrop) void {
    switch (obj.kind) {
        .portable, .player => moveablePlaceAt(g, obj, x, y, bd),
        // The Mover vtable only exists on these two.
        else => unreachable,
    }
}

// @orig 10c0:1c68 mover_is_moving
fn moverIsMoving(obj: *Object) bool {
    return obj.mover.moving != 0;
}

// @orig 1048:125e moveable_place_at
/// Moves with `moveToAndDrop` (slot 3D), restores the background,
/// re-occupies and draws (the call to the empty scene_object_dc_hook is
/// omitted).
fn moveablePlaceAt(g: *Game, obj: *Object, x: i16, y: i16, bd: *Backdrop) void {
    _ = occupancy.vacate(g, obj, bd);
    space3d.moveToAndDrop(g, obj, x, y, bd);
    render.restoreBackground(g, obj, bd, 1);
    _ = occupancy.occupy(g, obj, bd);
    render.draw(g, obj, bd);
}

// @orig 1038:1632 mover_step
/// Advances the next position one Bresenham step towards the target.
fn moverStep(obj: *Object) void {
    const m = &obj.mover;
    var e = m.lineErr;
    if (m.errIncX == 0) {
        if (e < 1) {
            e +%= m.errIncDiag;
            obj.nextX +%= m.stepX;
            obj.nextY +%= m.stepY;
        } else {
            e +%= m.errIncY;
            obj.nextY +%= m.stepY;
        }
    } else if (e < 1) {
        e +%= m.errIncX;
        obj.nextX +%= m.stepX;
    } else {
        e +%= m.errIncDiag;
        obj.nextX +%= m.stepX;
        obj.nextY +%= m.stepY;
    }
    m.lineErr = e;
}

// @orig 1038:1749 mover_at_target
/// True when the next position is within one step of the target along the
/// major axis (y when errIncX is 0, else x).
fn moverAtTarget(obj: *Object) bool {
    const m = &obj.mover;
    if (m.errIncX == 0) {
        return !(abs16(m.stepY) < abs16(obj.nextY -% m.targetY));
    }
    return !(abs16(m.stepX) < abs16(obj.nextX -% m.targetX));
}

// @orig 1038:1a6b mover_move_to
/// Starts moving towards screen point (x, y): the target puts the sprite's
/// bottom centre on it, clamped to the background; sets up the Bresenham
/// line and starts the movement system timer. A zero-length move leaves
/// `moving` 0.
fn moverMoveTo(g: *Game, obj: *Object, x: i16, y: i16, bd: *Backdrop) void {
    const m = &obj.mover;
    m.stepX = abs16(m.stepX);
    m.stepY = abs16(m.stepY);
    m.moving = 1;
    const w = position.width(obj);
    const h = position.height(obj);
    const half = @divTrunc(w, 2);
    if (0 -% (half -% bd.bgWidth) < bd.originX +% x) {
        m.targetX = 0 -% (w -% bd.bgWidth);
    } else {
        m.targetX = x -% (half -% bd.originX);
    }
    if (bd.bgHeight < bd.originY +% y) {
        m.targetY = 0 -% (h -% bd.bgHeight);
    } else {
        m.targetY = y -% (h -% bd.originY);
    }
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
        return;
    }
    if (m.lineDy < m.lineDx) {
        m.errIncX = m.lineDy *% 2;
        m.lineErr = m.errIncX -% m.lineDx;
        m.errIncDiag = m.lineErr -% m.lineDx;
        m.errIncY = 0;
    } else {
        m.errIncY = m.lineDx *% -2;
        m.lineErr = m.errIncY +% m.lineDy;
        m.errIncDiag = m.lineErr +% m.lineDy;
        m.errIncX = 0;
    }
    g.setSystemTimer(@bitCast(m.timerId), @bitCast(m.timerPeriod));
}

// @orig 1038:1dfb mover_move_to_edge_v
/// Vertical move to the bottom edge of the background (dir 8) or half off
/// the top (dir 4); any other dir, or no distance, stops.
fn moverMoveToEdgeV(g: *Game, obj: *Object, bd: *Backdrop, dir: i16) void {
    const m = &obj.mover;
    m.stepX = abs16(m.stepX);
    m.stepY = abs16(m.stepY);
    m.moving = 1;
    m.targetX = obj.x;
    if (dir == 8) {
        m.targetY = 0 -% (position.height(obj) -% bd.bgHeight);
    } else if (dir == 4) {
        m.targetY = 0 -% @divTrunc(position.height(obj), 2);
    } else {
        m.moving = 0;
        return;
    }
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

// @orig 1038:2020 mover_move_to_edge_h
/// Horizontal move to the right edge of the background (dir 2) or half off
/// the left (dir 1); any other dir, or no distance, stops.
fn moverMoveToEdgeH(g: *Game, obj: *Object, bd: *Backdrop, dir: i16) void {
    const m = &obj.mover;
    m.stepX = abs16(m.stepX);
    m.stepY = abs16(m.stepY);
    m.moving = 1;
    if (dir == 2) {
        m.targetX = 0 -% (position.width(obj) -% bd.bgWidth);
    } else if (dir == 1) {
        m.targetX = 0 -% @divTrunc(position.width(obj), 2);
    } else {
        m.moving = 0;
        return;
    }
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

// @orig 1048:1dec moveable_move_tick
fn moveableMoveTick(g: *Game, obj: *Object, bd: *Backdrop) void {
    if (obj.mover.moving == 0) return;
    moverStep(obj);
    if (occupancy.canStep(g, obj, bd)) {
        render.resetRects(obj);
        placeAt(g, obj, obj.nextX, obj.nextY, bd);
        visibility.redrawOverlapping(g, obj, bd, 1);
        _ = backdrop.autoscroll(g, bd, obj, obj.nextX, obj.nextY);
        if (!moverAtTarget(obj)) return;
    }
    stopMovingDc(g, obj, bd);
}

// @orig 1048:1fcd moveable_stop_moving
fn moveableStopMoving(g: *Game, obj: *Object, bd: *Backdrop) void {
    stopMovingDc(g, obj, bd);
}

// @orig 1048:2032 moveable_stop_moving_dc
/// moving = 0, kills the movement timer, steps lose their sign, target and
/// previous position become the current one, posts 0x404 with the id.
fn moveableStopMovingDc(g: *Game, obj: *Object) void {
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

// @orig 10c0:254e actor_move_tick
/// While moving: one animation frame, then the Moveable tick.
fn actorMoveTick(g: *Game, obj: *Object, bd: *Backdrop) void {
    if (obj.mover.moving != 0) {
        _ = animation.nextFrame(g, obj);
        moveableMoveTick(g, obj, bd);
    }
}

// @orig 10c0:259a actor_stop_moving
fn actorStopMoving(g: *Game, obj: *Object, bd: *Backdrop) void {
    _ = animation.setStrip(g, obj, 0, bd);
    moveableStopMoving(g, obj, bd);
}

// @orig 10c0:25e4 actor_stop_moving_dc
fn actorStopMovingDc(g: *Game, obj: *Object, bd: *Backdrop) void {
    _ = animation.setStrip(g, obj, 0, bd);
    moveableStopMovingDc(g, obj);
}

// @orig 1048:249a player_move_tick
/// The Actor tick, then always posts 0x405 (player stepped) with the object
/// id; lParam is `(y & (x >> 15)) << 16`: y when x is negative, else 0.
fn playerMoveTick(g: *Game, obj: *Object, bd: *Backdrop) void {
    actorMoveTick(g, obj, bd);
    const hi: u16 = @bitCast(obj.y & (obj.x >> 15));
    _ = g.post(msg.Msg.make(msg.noite.player_stepped, @bitCast(obj.id), 0, hi));
}

// @orig 10c0:65ae player_move_to_edge_h
/// Not a slot: game_handle_message's arrow-key branch calls it directly
/// (dead in JARDIM). Stops the animation, faces the walk (strip 1 right, 2
/// left), moves; if no movement started, plays the idle pose.
pub fn playerMoveToEdgeH(g: *Game, obj: *Object, bd: *Backdrop, dir: i16) void {
    animation.stop(g, obj);
    _ = animation.setStrip(g, obj, if (dir == 2) 1 else 2, bd);
    moverMoveToEdgeH(g, obj, bd, dir);
    if (obj.mover.moving == 0) animation.playIdle(g, obj, bd);
}
