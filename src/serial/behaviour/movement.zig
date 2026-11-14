//! Port unit `movement` (behaviour) of SERIAL.EXE. SceneObject slots 2F-34 36 (moveTo, edges, stopMoving(Dc) incl. Target's/Projectile's, moveTick, isMoving) and MoverVtbl/TargetVtbl/ProjectileVtbl placeAt.
//!
//! The gun, the targets and the bullet are the Movers; the control
//! panel and the status bar take the slots' defaults (absorbed, empty).
//! GetDC/ReleaseDC pairs are gone (the DC is the platform screen); hwnd and
//! hdc parameters are dropped. SERIAL's tick invalidates where TIRO's blits; the Target's stop is a reduced inline (no timer kill, no 0x404, no place) and its tick has the shot. Unlike ENCAIXE's: mover_stop_moving_dc is
//! here (the piece overrides it there), the Actor2D stop pair calls
//! animation_set_strip, the tick resets the rects through render, and
//! Target/Projectile have their own stop overrides and Target its tick.

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
const visibility = @import("visibility.zig");
const sound = @import("../sound.zig");

fn abs16(v: i16) i16 {
    return if (v < 0) 0 -% v else v;
}

/// SceneObject slot 2F moveTo (hwnd dropped): mover_move_to (gun, target, bullet) / default.
pub fn moveTo(g: *Game, obj: *Object, x: i16, y: i16, bd: *Backdrop) void {
    switch (obj.kind) {
        .gun, .target, .bullet => moverMoveTo(g, obj, x, y, bd),
        // scene_object_move_to_default (absorbed)
        .control_panel, .status_bar => {},
    }
}

/// SceneObject slot 30 moveToEdgeH: mover_move_to_edge_h (gun, target, bullet) / default.
pub fn moveToEdgeH(g: *Game, obj: *Object, bd: *Backdrop, dir: i16) void {
    switch (obj.kind) {
        .gun, .target, .bullet => moverMoveToEdgeH(g, obj, bd, dir),
        // scene_object_move_to_edge_h_default (absorbed)
        .control_panel, .status_bar => {},
    }
}

/// SceneObject slot 31 moveToEdgeV: mover_move_to_edge_v (gun, target, bullet) / default.
pub fn moveToEdgeV(g: *Game, obj: *Object, bd: *Backdrop, dir: i16) void {
    switch (obj.kind) {
        .gun, .target, .bullet => moverMoveToEdgeV(g, obj, bd, dir),
        // scene_object_move_to_edge_v_default (absorbed)
        .control_panel, .status_bar => {},
    }
}

/// SceneObject slot 32 stopMovingDc: actor2d_stop_moving_dc (gun), target_stop_moving_dc (target), projectile_stop_moving_dc (bullet) / default.
pub fn stopMovingDc(g: *Game, obj: *Object, bd: *Backdrop) void {
    switch (obj.kind) {
        .gun => actor2dStopMovingDc(g, obj, bd),
        .target => targetStopMovingDc(g, obj, bd),
        .bullet => projectileStopMovingDc(g, obj, bd),
        // scene_object_stop_moving_dc_default (absorbed)
        .control_panel, .status_bar => {},
    }
}

/// SceneObject slot 33 stopMoving: actor2d_stop_moving (gun), target_stop_moving (target), projectile_stop_moving (bullet) / default.
pub fn stopMoving(g: *Game, obj: *Object, bd: *Backdrop) void {
    switch (obj.kind) {
        .gun => actor2dStopMoving(g, obj, bd),
        .target => targetStopMoving(g, obj, bd),
        .bullet => projectileStopMoving(g, obj, bd),
        // scene_object_stop_moving_default (absorbed)
        .control_panel, .status_bar => {},
    }
}

/// SceneObject slot 34 moveTick: player2d_move_tick (gun), target_move_tick (target), actor2d_move_tick (bullet) / default.
pub fn moveTick(g: *Game, obj: *Object, bd: *Backdrop) void {
    switch (obj.kind) {
        .gun => player2dMoveTick(g, obj, bd),
        .target => targetMoveTick(g, obj, bd),
        .bullet => actor2dMoveTick(g, obj, bd),
        // scene_object_move_tick_default (absorbed)
        .control_panel, .status_bar => {},
    }
}

/// SceneObject slot 36 isMoving: actor2d_is_moving (gun, target, bullet) / default.
pub fn isMoving(g: *Game, obj: *Object) bool {
    _ = g;
    return switch (obj.kind) {
        // @orig 1088:2bb4 actor2d_is_moving
        .gun, .target, .bullet => moverIsMoving(obj),
        // scene_object_is_moving_default (absorbed)
        .control_panel, .status_bar => false,
    };
}

// @orig 1088:27bc mover_is_moving
fn moverIsMoving(obj: *Object) bool {
    return obj.mover.moving != 0;
}

/// MoverVtbl / TargetVtbl / ProjectileVtbl slot 00 placeAt (mover_place_at).
pub fn placeAt(g: *Game, obj: *Object, x: i16, y: i16, bd: *Backdrop) void {
    switch (obj.kind) {
        .gun, .target, .bullet => moverPlaceAt(g, obj, x, y, bd),
        // The Mover vtables only exist on these three.
        else => unreachable,
    }
}

// @orig 1028:073c mover_place_at
fn moverPlaceAt(g: *Game, obj: *Object, x: i16, y: i16, bd: *Backdrop) void {
    _ = occupancy.vacate(g, obj, bd);
    position.setPosition(g, obj, x, y);
    render.restoreBackground(g, obj, bd, 1);
    _ = occupancy.occupy(g, obj, bd);
    // scene_object_dc_hook (1028:02ec): an empty hook (render's).
    render.draw(g, obj, bd);
}

// @orig 1028:0e8e mover_step
/// Advances the next position one Bresenham step towards the target.
pub fn moverStep(obj: *Object) void {
    const m = &obj.mover;
    var e = m.lineErr;
    if (m.errIncX == 0) {
        if (e < 1) {
            obj.nextX +%= m.stepX;
            obj.nextY +%= m.stepY;
            e +%= m.errIncDiag;
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

// @orig 1028:0f2e mover_at_target
/// True when the next position is within one step of the target along the
/// major axis (y when errIncX is 0, else x).
pub fn moverAtTarget(obj: *Object) bool {
    const m = &obj.mover;
    if (m.errIncX == 0) {
        return !(abs16(m.stepY) < abs16(obj.nextY -% m.targetY));
    }
    return !(abs16(m.stepX) < abs16(obj.nextX -% m.targetX));
}

// @orig 1028:0fb9 mover_move_tick
fn moverMoveTick(g: *Game, obj: *Object, bd: *Backdrop) void {
    if (obj.mover.moving == 0) return;
    moverStep(obj);
    if (occupancy.canStep(g, obj, bd)) {
        render.resetRects(obj);
        placeAt(g, obj, obj.nextX, obj.nextY, bd);
        visibility.redrawOverlapping(g, obj, bd, 1);
        // SERIAL: slot 0x78 invalidate (queues the repaint) where TIRO blits.
        visibility.invalidate(g, obj);
        _ = backdrop.autoscroll(g, bd, obj, obj.nextX, obj.nextY);
        if (!moverAtTarget(obj)) return;
    }
    stopMovingDc(g, obj, bd);
}

// @orig 1028:113f mover_move_to
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
        m.errIncX = m.lineDy << 1;
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

// @orig 1028:1322 mover_move_to_edge_v
/// Vertical move to the bottom edge of the background (dir 8) or half off
/// the top (dir 4); any other dir, or no distance, stops.
fn moverMoveToEdgeV(g: *Game, obj: *Object, bd: *Backdrop, dir: i16) void {
    const m = &obj.mover;
    m.stepX = abs16(m.stepX);
    m.stepY = abs16(m.stepY);
    m.moving = 1;
    m.targetX = obj.x;
    const h = position.height(obj);
    if (dir == 8) {
        m.targetY = 0 -% (h -% bd.bgHeight);
    } else if (dir == 4) {
        m.targetY = 0 -% @divTrunc(h, 2);
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

// @orig 1028:144b mover_move_to_edge_h
/// Horizontal move to the right edge of the background (dir 2) or half off
/// the left (dir 1); any other dir, or no distance, stops.
fn moverMoveToEdgeH(g: *Game, obj: *Object, bd: *Backdrop, dir: i16) void {
    const m = &obj.mover;
    m.stepX = abs16(m.stepX);
    m.stepY = abs16(m.stepY);
    m.moving = 1;
    const w = position.width(obj);
    if (dir == 2) {
        m.targetX = 0 -% (w -% bd.bgWidth);
    } else if (dir == 1) {
        m.targetX = 0 -% @divTrunc(w, 2);
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
    m.errIncX = m.lineDy << 1;
    m.lineErr = m.errIncX -% m.lineDx;
    m.errIncDiag = m.lineErr -% m.lineDx;
    m.errIncY = 0;
    g.setSystemTimer(@bitCast(m.timerId), @bitCast(m.timerPeriod));
}

// @orig 1028:1572 mover_stop_moving
/// Mover's stopMoving (GetDC, the virtual stopMovingDc, ReleaseDC).
fn moverStopMoving(g: *Game, obj: *Object, bd: *Backdrop) void {
    stopMovingDc(g, obj, bd);
}

// @orig 1028:15c3 mover_stop_moving_dc
/// moving = 0, kills the movement timer, steps lose their sign, target and
/// previous position become the current one, posts 0x404 with the id.
pub fn moverStopMovingDc(g: *Game, obj: *Object) void {
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

// @orig 1088:2946 actor2d_move_tick
fn actor2dMoveTick(g: *Game, obj: *Object, bd: *Backdrop) void {
    if (obj.mover.moving != 0) {
        _ = animation.nextFrame(g, obj);
        moverMoveTick(g, obj, bd);
    }
}

// @orig 1088:297c actor2d_stop_moving
fn actor2dStopMoving(g: *Game, obj: *Object, bd: *Backdrop) void {
    _ = animation.setStrip(g, obj, 0, bd);
    moverStopMoving(g, obj, bd);
}

// @orig 1088:29b6 actor2d_stop_moving_dc
fn actor2dStopMovingDc(g: *Game, obj: *Object, bd: *Backdrop) void {
    _ = animation.setStrip(g, obj, 0, bd);
    moverStopMovingDc(g, obj);
}

// @orig 1028:18a9 player2d_move_tick
/// The Actor2D tick, then always posts 0x405 (player stepped) with the
/// object id; lParam is `(y & (x >> 15)) << 16`: y when x is negative, else 0.
fn player2dMoveTick(g: *Game, obj: *Object, bd: *Backdrop) void {
    actor2dMoveTick(g, obj, bd);
    const hi: u16 = @bitCast(obj.y & (obj.x >> 15));
    _ = g.post(msg.Msg.make(msg.noite.player_stepped, @bitCast(obj.id), 0, hi));
}

// @orig 1068:0663 target_stop_moving_dc
/// SERIAL's inlined, reduced mover_stop_moving_dc: moving = 0, steps lose
/// their sign, target and previous position become the current one, then
/// hideAndInvalidate. It neither kills the timer (the walk timers are
/// shared by many figures) nor posts 0x404, and does not place or blit.
fn targetStopMovingDc(g: *Game, obj: *Object, bd: *Backdrop) void {
    const m = &obj.mover;
    m.moving = 0;
    m.stepX = abs16(m.stepX);
    m.stepY = abs16(m.stepY);
    m.prevX = obj.x;
    m.targetX = obj.x;
    m.prevY = obj.y;
    m.targetY = obj.y;
    visibility.hideAndInvalidate(g, obj, 0, bd);
}

// @orig 1068:06d9 target_stop_moving
fn targetStopMoving(g: *Game, obj: *Object, bd: *Backdrop) void {
    stopMovingDc(g, obj, bd);
}

// @orig 1068:120b projectile_stop_moving_dc
/// mover_stop_moving_dc, then hideAndInvalidate (no blit).
fn projectileStopMovingDc(g: *Game, obj: *Object, bd: *Backdrop) void {
    moverStopMovingDc(g, obj);
    visibility.hideAndInvalidate(g, obj, 0, bd);
}

// @orig 1068:1254 projectile_stop_moving
fn projectileStopMoving(g: *Game, obj: *Object, bd: *Backdrop) void {
    stopMovingDc(g, obj, bd);
}

// @orig 1068:0dfc target_move_tick
/// One walk step of a target: step, canStep, the next walk frame, place at
/// the next position, THE SHOT (a kind-2 figure whose frame count minus
/// curFrame is 2 plays tiros1.WAV and costs a life; the last one sends
/// WM_DESTROY), redrawOverlapping, the invalidate, the autoscroll. No
/// at-target test: target_wrap_at_edge does the edge test.
fn targetMoveTick(g: *Game, obj: *Object, bd: *Backdrop) void {
    if (obj.mover.moving == 0) return;
    moverStep(obj);
    if (!occupancy.canStep(g, obj, bd)) {
        targetStopMovingDc(g, obj, bd);
        obj.mover.moving = 0;
        visibility.hideAndInvalidate(g, obj, 0, bd);
        return;
    }
    _ = animation.nextFrame(g, obj);
    moverPlaceAt(g, obj, obj.nextX, obj.nextY, bd);
    if (obj.target.kind == 2 and position.frameCount(obj) -% obj.curFrame == 2) {
        _ = sound.play(g, 0, g.shotWave);
        g.lives -%= 1;
        if (g.lives == 0) _ = g.send(.{ .id = msg.wm.destroy });
    }
    visibility.redrawOverlapping(g, obj, bd, 1);
    visibility.invalidate(g, obj); // the original calls scene_object_invalidate (1028:001b) directly; mover_invalidate does the same
    _ = backdrop.autoscroll(g, bd, obj, obj.nextX, obj.nextY);
}
