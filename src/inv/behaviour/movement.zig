//! Port unit `movement` (behaviour) of INV.EXE. SceneObject slots 2F-34 36 (moveTo, edges, stopMoving(Dc) incl. the Saucer's, the Missile's and the InvaderColumn's (right-edge descent, landing), moveTick incl. the Missile's and the InvaderColumn's, isMoving).
//!
//! The cannon, the saucer, the bombs, the shot, the invader columns and the
//! explosion are the Movers; the control panel and the status bar take the
//! slots' defaults (absorbed, empty). GetDC/ReleaseDC pairs are gone (the DC
//! is the platform screen); hwnd and hdc parameters are dropped.
//! mover_place_at is `occupancy.placeAt` (its canStep overrides call it).

const msg = @import("../../core/msg.zig");
const Game = @import("../core/game.zig").Game;
const object = @import("../core/object.zig");
const Object = object.Object;
const world = @import("../core/world.zig");
const Backdrop = world.Backdrop;
const backdrop = @import("../backdrop.zig");
const object_create = @import("../object_create.zig");
const score = @import("../score.zig");
const animation = @import("animation.zig");
const occupancy = @import("occupancy.zig");
const position = @import("position.zig");
const render = @import("render.zig");
const visibility = @import("visibility.zig");

fn abs16(v: i16) i16 {
    return if (v < 0) 0 -% v else v;
}

/// SceneObject slot 2F moveTo (hwnd dropped): mover_move_to (cannon, saucer, bomb, shot, column, explosion) / default.
pub fn moveTo(g: *Game, obj: *Object, x: i16, y: i16, bd: *Backdrop) void {
    switch (obj.kind) {
        .cannon, .saucer, .bomb, .shot, .invader_column, .invader_explosion => moverMoveTo(g, obj, x, y, bd),
        // scene_object_move_to_default (absorbed)
        .control_panel, .status_bar => {},
    }
}

/// SceneObject slot 30 moveToEdgeH: mover_move_to_edge_h (cannon, saucer, bomb, shot, column, explosion) / default.
pub fn moveToEdgeH(g: *Game, obj: *Object, bd: *Backdrop, dir: i16) void {
    switch (obj.kind) {
        .cannon, .saucer, .bomb, .shot, .invader_column, .invader_explosion => moverMoveToEdgeH(g, obj, bd, dir),
        // scene_object_move_to_edge_h_default (absorbed)
        .control_panel, .status_bar => {},
    }
}

/// SceneObject slot 31 moveToEdgeV: mover_move_to_edge_v (cannon, saucer, bomb, shot, column, explosion) / default.
pub fn moveToEdgeV(g: *Game, obj: *Object, bd: *Backdrop, dir: i16) void {
    switch (obj.kind) {
        .cannon, .saucer, .bomb, .shot, .invader_column, .invader_explosion => moverMoveToEdgeV(g, obj, bd, dir),
        // scene_object_move_to_edge_v_default (absorbed)
        .control_panel, .status_bar => {},
    }
}

/// SceneObject slot 32 stopMovingDc: actor2d_stop_moving_dc (cannon), saucer_stop_moving_dc (saucer), missile_stop_moving_dc (bomb, shot), invader_column_stop_moving_dc (column, explosion) / default.
pub fn stopMovingDc(g: *Game, obj: *Object, bd: *Backdrop) void {
    switch (obj.kind) {
        .cannon => actor2dStopMovingDc(g, obj, bd),
        .saucer => saucerStopMovingDc(g, obj, bd),
        .bomb, .shot => missileStopMovingDc(g, obj, bd),
        .invader_column, .invader_explosion => invaderColumnStopMovingDc(g, obj, bd),
        // scene_object_stop_moving_dc_default (absorbed)
        .control_panel, .status_bar => {},
    }
}

/// SceneObject slot 33 stopMoving: actor2d_stop_moving (cannon), saucer_stop_moving (saucer), missile_stop_moving (bomb, shot), invader_column_stop_moving (column, explosion) / default.
pub fn stopMoving(g: *Game, obj: *Object, bd: *Backdrop) void {
    switch (obj.kind) {
        .cannon => actor2dStopMoving(g, obj, bd),
        .saucer => saucerStopMoving(g, obj, bd),
        .bomb, .shot => missileStopMoving(g, obj, bd),
        .invader_column, .invader_explosion => invaderColumnStopMoving(g, obj, bd),
        // scene_object_stop_moving_default (absorbed)
        .control_panel, .status_bar => {},
    }
}

/// SceneObject slot 34 moveTick: player2d_move_tick (cannon), actor2d_move_tick (saucer), missile_move_step (bomb, shot), invader_column_move_tick (column, explosion) / default.
pub fn moveTick(g: *Game, obj: *Object, bd: *Backdrop) void {
    switch (obj.kind) {
        .cannon => player2dMoveTick(g, obj, bd),
        .saucer => actor2dMoveTick(g, obj, bd),
        .bomb, .shot => missileMoveStep(g, obj, bd),
        .invader_column, .invader_explosion => invaderColumnMoveTick(g, obj, bd),
        // scene_object_move_tick_default (absorbed)
        .control_panel, .status_bar => {},
    }
}

/// SceneObject slot 36 isMoving: actor2d_is_moving (cannon, saucer, bomb, shot, column, explosion) / default.
pub fn isMoving(g: *Game, obj: *Object) bool {
    _ = g;
    return switch (obj.kind) {
        // @orig 1088:24e0 actor2d_is_moving
        .cannon, .saucer, .bomb, .shot, .invader_column, .invader_explosion => moverIsMoving(obj),
        // scene_object_is_moving_default (absorbed)
        .control_panel, .status_bar => false,
    };
}

// @orig 1088:20e8 mover_is_moving
fn moverIsMoving(obj: *Object) bool {
    return obj.mover.moving != 0;
}

// @orig 1028:0e5e mover_step
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

// @orig 1028:0efe mover_at_target
/// True when the next position is within one step of the target along the
/// major axis (y when errIncX is 0, else x).
pub fn moverAtTarget(obj: *Object) bool {
    const m = &obj.mover;
    if (m.errIncX == 0) {
        return !(abs16(m.stepY) < abs16(obj.nextY -% m.targetY));
    }
    return !(abs16(m.stepX) < abs16(obj.nextX -% m.targetX));
}

// @orig 1028:0f89 mover_move_tick
pub fn moverMoveTick(g: *Game, obj: *Object, bd: *Backdrop) void {
    if (obj.mover.moving == 0) return;
    moverStep(obj);
    if (occupancy.canStep(g, obj, bd)) {
        render.resetRects(obj);
        occupancy.placeAt(g, obj, obj.nextX, obj.nextY, bd);
        visibility.redrawOverlapping(g, obj, bd, 1);
        visibility.blitToDc(g, obj, bd);
        _ = backdrop.autoscroll(g, bd, obj, obj.nextX, obj.nextY);
        if (!moverAtTarget(obj)) return;
    }
    stopMovingDc(g, obj, bd);
}

// @orig 1028:111b mover_move_to
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

// @orig 1028:12fe mover_move_to_edge_v
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

// @orig 1028:1427 mover_move_to_edge_h
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

// @orig 1028:154e mover_stop_moving
/// Mover's stopMoving (GetDC, the virtual stopMovingDc, ReleaseDC).
fn moverStopMoving(g: *Game, obj: *Object, bd: *Backdrop) void {
    stopMovingDc(g, obj, bd);
}

// @orig 1028:159f mover_stop_moving_dc
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

// @orig 1088:2272 actor2d_move_tick
fn actor2dMoveTick(g: *Game, obj: *Object, bd: *Backdrop) void {
    if (obj.mover.moving != 0) {
        _ = animation.nextFrame(g, obj);
        moverMoveTick(g, obj, bd);
    }
}

// @orig 1088:22a8 actor2d_stop_moving
fn actor2dStopMoving(g: *Game, obj: *Object, bd: *Backdrop) void {
    _ = animation.setStrip(g, obj, 0, bd);
    moverStopMoving(g, obj, bd);
}

// @orig 1088:22e2 actor2d_stop_moving_dc
fn actor2dStopMovingDc(g: *Game, obj: *Object, bd: *Backdrop) void {
    _ = animation.setStrip(g, obj, 0, bd);
    moverStopMovingDc(g, obj);
}

// @orig 1028:18a7 player2d_move_tick
/// The Actor2D tick, then always posts 0x405 (player stepped) with the
/// object id; lParam is `(y & (x >> 15)) << 16`: y when x is negative, else 0.
fn player2dMoveTick(g: *Game, obj: *Object, bd: *Backdrop) void {
    actor2dMoveTick(g, obj, bd);
    const hi: u16 = @bitCast(obj.y & (obj.x >> 15));
    _ = g.post(msg.Msg.make(msg.noite.player_stepped, @bitCast(obj.id), 0, hi));
}

// @orig 1068:0b20 saucer_stop_moving_dc
/// mover_stop_moving_dc, erases the saucer where it is (hideAndInvalidate,
/// blit), parks it at (50, 10) and erases/blits it there again.
fn saucerStopMovingDc(g: *Game, obj: *Object, bd: *Backdrop) void {
    moverStopMovingDc(g, obj);
    visibility.hideAndInvalidate(g, obj, 0, bd);
    visibility.blitToDc(g, obj, bd);
    occupancy.placeAt(g, obj, 0x32, 10, bd);
    visibility.hideAndInvalidate(g, obj, 0, bd);
    visibility.blitToDc(g, obj, bd);
}

// @orig 1068:0bc5 saucer_stop_moving
fn saucerStopMoving(g: *Game, obj: *Object, bd: *Backdrop) void {
    stopMovingDc(g, obj, bd);
}

// @orig 1068:0e77 missile_stop_moving_dc
/// mover_stop_moving_dc, then hideAndInvalidate and blit: the missile disappears.
fn missileStopMovingDc(g: *Game, obj: *Object, bd: *Backdrop) void {
    moverStopMovingDc(g, obj);
    visibility.hideAndInvalidate(g, obj, 0, bd);
    visibility.blitToDc(g, obj, bd);
}

// @orig 1068:0ede missile_stop_moving
fn missileStopMoving(g: *Game, obj: *Object, bd: *Backdrop) void {
    stopMovingDc(g, obj, bd);
}

// @orig 1068:10f0 missile_move_step
/// One missile step: canStep false stops it (stop + hide again); else place,
/// redrawOverlapping, blit, autoscroll and the stop at the target.
fn missileMoveStep(g: *Game, obj: *Object, bd: *Backdrop) void {
    if (obj.mover.moving == 0) return;
    moverStep(obj);
    if (!occupancy.canStep(g, obj, bd)) {
        missileStopMovingDc(g, obj, bd);
        visibility.hideAndInvalidate(g, obj, 0, bd);
        return;
    }
    occupancy.placeAt(g, obj, obj.nextX, obj.nextY, bd);
    visibility.redrawOverlapping(g, obj, bd, 1);
    visibility.blitToDc(g, obj, bd);
    _ = backdrop.autoscroll(g, bd, obj, obj.nextX, obj.nextY);
    if (moverAtTarget(obj)) {
        missileStopMovingDc(g, obj, bd);
        visibility.hideAndInvalidate(g, obj, 0, bd);
    }
}

// @orig 1068:13a8 invader_column_stop_moving_dc
/// Empty column: a moving one just stops and hides. Otherwise a landed
/// formation sends WM_DESTROY again; a right-edge turn (direction 2) descends
/// by width / 4 unless the lowest live invader would reach y 390 (landed,
/// WM_DESTROY); then always mover_stop_moving_dc.
fn invaderColumnStopMovingDc(g: *Game, obj: *Object, bd: *Backdrop) void {
    const inv = &obj.invader;
    if (inv.lowestAlive == -1) {
        if (obj.mover.moving != 0) {
            moverStopMovingDc(g, obj);
            visibility.hideAndInvalidate(g, obj, 0, bd);
        }
        return;
    }
    if (g.invadersLanded != 0) {
        _ = g.send(.{ .id = msg.wm.destroy });
    } else if (inv.direction == 2) {
        if ((inv.lowestAlive +% 1) *% 0x2c +% obj.y < 0x186) {
            const x = obj.x;
            const w = position.width(obj);
            occupancy.placeAt(g, obj, x, @divTrunc(w, 4) +% obj.y, bd);
            if (g.formationMaxY < obj.y) {
                g.formationMaxY = obj.y;
                score.playDescendWave(g);
            }
            visibility.blitToDc(g, obj, bd);
        } else {
            inv.landed = 1;
            g.invadersLanded = 1;
            inv.atEdge = 1;
            _ = g.send(.{ .id = msg.wm.destroy });
        }
    }
    moverStopMovingDc(g, obj);
}

// @orig 1068:14e3 invader_column_stop_moving
fn invaderColumnStopMoving(g: *Game, obj: *Object, bd: *Backdrop) void {
    invaderColumnStopMovingDc(g, obj, bd);
}

// @orig 1068:160a invader_column_move_tick
/// One march step: canStep false stops (virtual stopMovingDc); else the next
/// frame, the five cells follow the column (set_cell + draw, the draw inside
/// the loop), place, redrawOverlapping, blit, stop at the target.
fn invaderColumnMoveTick(g: *Game, obj: *Object, bd: *Backdrop) void {
    if (obj.mover.moving == 0) return;
    moverStep(obj);
    if (!occupancy.canStep(g, obj, bd)) {
        stopMovingDc(g, obj, bd);
        return;
    }
    _ = animation.nextFrame(g, obj);
    var i: i16 = 0;
    while (i < 5) : (i += 1) {
        const alive: i16 = if (obj.invader.cells[@intCast(i)].alive != 0) 1 else 0;
        object_create.invaderColumnSetCell(obj, obj.nextX, obj.nextY, i, alive);
        render.draw(g, obj, bd);
    }
    occupancy.placeAt(g, obj, obj.nextX, obj.nextY, bd);
    visibility.redrawOverlapping(g, obj, bd, 1);
    visibility.blitToDc(g, obj, bd);
    if (moverAtTarget(obj)) stopMovingDc(g, obj, bd);
}
