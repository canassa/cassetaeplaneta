//! Port unit `movement` (behaviour) of INFERNO.EXE. SceneObject slots 2F-34
//! 36 (moveTo, edges, stopMoving(Dc), moveTick, isMoving), MoverVtbl placeAt
//! (every table's slot 00), mover_step/at_target.
//!
//! The four kinds (hero, platform, prop, hazard) are all Actor2D; each
//! kind's own override is its class unit's function. GetDC/ReleaseDC and
//! the palette realisation are gone (the DC is the platform screen); hwnd
//! and hdc parameters are dropped.

const Game = @import("../core/game.zig").Game;
const object = @import("../core/object.zig");
const Object = object.Object;
const world = @import("../core/world.zig");
const Backdrop = world.Backdrop;
const backdrop = @import("../backdrop.zig");
const hazard = @import("../hazard.zig");
const hero = @import("../hero.zig");
const ledge = @import("../ledge.zig");
const prop = @import("../prop.zig");
const animation = @import("animation.zig");
const occupancy = @import("occupancy.zig");
const position = @import("position.zig");
const render = @import("render.zig");
const visibility = @import("visibility.zig");

fn abs16(v: i16) i16 {
    return if (v < 0) 0 -% v else v;
}

/// SceneObject slot 2F moveTo (hwnd dropped): mover_move_to (every kind).
pub fn moveTo(g: *Game, obj: *Object, x: i16, y: i16, bd: *Backdrop) void {
    moverMoveTo(g, obj, x, y, bd);
}

/// SceneObject slot 30 moveToEdgeH: mover_move_to_edge_h (hero),
/// ledge.moveToEdgeH (platform), prop.moveToEdgeH (prop, hazard).
pub fn moveToEdgeH(g: *Game, obj: *Object, bd: *Backdrop, dir: i16) void {
    switch (obj.kind) {
        .hero => moverMoveToEdgeH(g, obj, bd, dir),
        .platform => ledge.moveToEdgeH(g, obj, bd, dir),
        .prop, .hazard => prop.moveToEdgeH(g, obj, bd, dir),
    }
}

/// SceneObject slot 31 moveToEdgeV: hero.moveToEdgeV (hero),
/// mover_move_to_edge_v (platform, prop, hazard).
pub fn moveToEdgeV(g: *Game, obj: *Object, bd: *Backdrop, dir: i16) void {
    switch (obj.kind) {
        .hero => hero.moveToEdgeV(g, obj, bd, dir),
        .platform, .prop, .hazard => moverMoveToEdgeV(g, obj, bd, dir),
    }
}

/// SceneObject slot 32 stopMovingDc: hero.stopMovingDc (hero),
/// actor2d_stop_moving_dc (platform, prop, hazard).
pub fn stopMovingDc(g: *Game, obj: *Object, bd: *Backdrop) void {
    switch (obj.kind) {
        .hero => hero.stopMovingDc(g, obj, bd),
        .platform, .prop, .hazard => actor2dStopMovingDc(g, obj, bd),
    }
}

/// SceneObject slot 33 stopMoving: hero.stopMoving (hero),
/// actor2d_stop_moving (platform, prop), hazard.stopMoving (hazard).
pub fn stopMoving(g: *Game, obj: *Object, bd: *Backdrop) void {
    switch (obj.kind) {
        .hero => hero.stopMoving(g, obj, bd),
        .platform, .prop => actor2dStopMoving(g, obj, bd),
        .hazard => hazard.stopMoving(g, obj, bd),
    }
}

/// SceneObject slot 34 moveTick: hero.moveTick, ledge.moveTick,
/// prop.moveTick, hazard.moveTick (each kind its own).
pub fn moveTick(g: *Game, obj: *Object, bd: *Backdrop) void {
    switch (obj.kind) {
        .hero => hero.moveTick(g, obj, bd),
        .platform => ledge.moveTick(g, obj, bd),
        .prop => prop.moveTick(g, obj, bd),
        .hazard => hazard.moveTick(g, obj, bd),
    }
}

/// SceneObject slot 36 isMoving: actor2d_is_moving (every kind).
pub fn isMoving(g: *Game, obj: *Object) bool {
    _ = g;
    // @orig 1080:3204 actor2d_is_moving
    return moverIsMoving(obj);
}

// @orig 1080:2cd4 mover_is_moving
fn moverIsMoving(obj: *Object) bool {
    return obj.mover.moving != 0;
}

/// MoverVtbl / PlatformVtbl / PropVtbl slot 00 placeAt (mover_place_at, every
/// table).
pub fn placeAt(g: *Game, obj: *Object, x: i16, y: i16, bd: *Backdrop) void {
    moverPlaceAt(g, obj, x, y, bd);
}

// @orig 1028:0a0a mover_place_at
fn moverPlaceAt(g: *Game, obj: *Object, x: i16, y: i16, bd: *Backdrop) void {
    _ = occupancy.vacate(g, obj, bd);
    position.setPosition(g, obj, x, y);
    render.restoreBackground(g, obj, bd, 1);
    _ = occupancy.occupy(g, obj, bd);
    // scene_object_dc_hook (1028:03d7): an empty hook (render's).
    render.draw(g, obj, bd);
}

// @orig 1028:141e mover_step
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

// @orig 1028:1535 mover_at_target
/// True when the next position is within one step of the target along the
/// major axis (y when errIncX is 0, else x).
pub fn moverAtTarget(obj: *Object) bool {
    const m = &obj.mover;
    if (m.errIncX == 0) {
        return !(abs16(m.stepY) < abs16(obj.nextY -% m.targetY));
    }
    return !(abs16(m.stepX) < abs16(obj.nextX -% m.targetX));
}

// @orig 1028:15e3 mover_move_tick
/// Palette realisation and the DC are gone; unlike TIRO's there is no
/// render.resetRects before the placeAt.
pub fn moverMoveTick(g: *Game, obj: *Object, bd: *Backdrop) void {
    if (obj.mover.moving == 0) return;
    moverStep(obj);
    if (occupancy.canStep(g, obj, bd)) {
        placeAt(g, obj, obj.nextX, obj.nextY, bd);
        visibility.redrawOverlapping(g, obj, bd, 1);
        visibility.blitToDc(g, obj, bd);
        _ = backdrop.autoscroll(g, bd, obj, obj.nextX, obj.nextY);
        if (!moverAtTarget(obj)) return;
    }
    stopMovingDc(g, obj, bd);
}

// @orig 1028:1853 mover_move_to
/// Starts moving towards screen point (x, y): the target puts the sprite's
/// bottom centre on it, clamped to the background; sets up the Bresenham
/// line and starts the movement system timer. A zero-length move leaves
/// `moving` 0.
pub fn moverMoveTo(g: *Game, obj: *Object, x: i16, y: i16, bd: *Backdrop) void {
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

// @orig 1028:1be3 mover_move_to_edge_v
/// Vertical move to the bottom edge of the background (dir 8) or half off
/// the top (dir 4); any other dir, or no distance, stops.
pub fn moverMoveToEdgeV(g: *Game, obj: *Object, bd: *Backdrop, dir: i16) void {
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

// @orig 1028:1e08 mover_move_to_edge_h
/// Horizontal move to the right edge of the background (dir 2) or half off
/// the left (dir 1); any other dir, or no distance, stops.
pub fn moverMoveToEdgeH(g: *Game, obj: *Object, bd: *Backdrop, dir: i16) void {
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

// @orig 1028:202b mover_stop_moving
/// Mover's stopMoving (GetDC, the virtual stopMovingDc, ReleaseDC).
pub fn moverStopMoving(g: *Game, obj: *Object, bd: *Backdrop) void {
    stopMovingDc(g, obj, bd);
}

// @orig 1028:2090 mover_stop_moving_dc
/// moving = 0, kills the movement timer, steps lose their sign, target and
/// previous position become the current one. Unlike TIRO's it posts nothing.
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
}

// @orig 1080:2f5e actor2d_stop_moving
pub fn actor2dStopMoving(g: *Game, obj: *Object, bd: *Backdrop) void {
    _ = animation.setStrip(g, obj, 0, bd);
    moverStopMoving(g, obj, bd);
}

// @orig 1080:2fa8 actor2d_stop_moving_dc
pub fn actor2dStopMovingDc(g: *Game, obj: *Object, bd: *Backdrop) void {
    _ = animation.setStrip(g, obj, 0, bd);
    moverStopMovingDc(g, obj);
}
