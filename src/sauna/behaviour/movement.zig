//! Port unit `movement` (behaviour) of SAUNA.EXE. SceneObject slots 35-3A 3C (moveTo incl. Pacman's click walk (P5), edges incl. Pacman's, stopMoving(Dc) incl. Pacman's/Ghost's, moveTick incl. Pacman's/Ghost's, isMoving) and MoverVtbl/PacmanVtbl/GhostVtbl placeAt.
//!
//! GetDC/ReleaseDC pairs are gone; hwnd and hdc parameters are dropped.
//! Unlike TIRO's: SAUNA has no Mover stop/tick (Pacman's and the Ghosts'
//! own ones replace them: no timer kill, no 0x404, no autoscroll), the
//! Pacman wrappers stop the animation and pick a strip first, and the
//! Ghost tick re-chooses its heading when Pacman is within 16 px.

const Game = @import("../core/game.zig").Game;
const object = @import("../core/object.zig");
const Object = object.Object;
const world = @import("../core/world.zig");
const Backdrop = world.Backdrop;
const ghost = @import("../ghost.zig");
const animation = @import("animation.zig");
const occupancy = @import("occupancy.zig");
const position = @import("position.zig");
const render = @import("render.zig");
const visibility = @import("visibility.zig");

fn abs16(v: i16) i16 {
    return if (v < 0) 0 -% v else v;
}

/// SceneObject slot 35 moveTo (hwnd dropped): pacman_move_to (pacman), mover_move_to (ghost) / default.
pub fn moveTo(g: *Game, obj: *Object, x: i16, y: i16, bd: *Backdrop) void {
    switch (obj.kind) {
        .pacman => pacmanMoveTo(g, obj, x, y, bd),
        .ghost => moverMoveTo(g, obj, x, y, bd),
        // scene_object_move_to_default (absorbed)
        .dot, .control_panel => {},
    }
}

/// SceneObject slot 36 moveToEdgeH: pacman_move_to_edge_h (pacman), mover_move_to_edge_h (ghost) / default.
pub fn moveToEdgeH(g: *Game, obj: *Object, bd: *Backdrop, dir: i16) void {
    switch (obj.kind) {
        .pacman => pacmanMoveToEdgeH(g, obj, bd, dir),
        .ghost => moverMoveToEdgeH(g, obj, bd, dir),
        // scene_object_move_to_edge_h_default (absorbed)
        .dot, .control_panel => {},
    }
}

/// SceneObject slot 37 moveToEdgeV: pacman_move_to_edge_v (pacman), mover_move_to_edge_v (ghost) / default.
pub fn moveToEdgeV(g: *Game, obj: *Object, bd: *Backdrop, dir: i16) void {
    switch (obj.kind) {
        .pacman => pacmanMoveToEdgeV(g, obj, bd, dir),
        .ghost => moverMoveToEdgeV(g, obj, bd, dir),
        // scene_object_move_to_edge_v_default (absorbed)
        .dot, .control_panel => {},
    }
}

/// SceneObject slot 38 stopMovingDc: pacman_stop_moving_dc (pacman), ghost_stop_moving_dc (ghost) / default.
pub fn stopMovingDc(g: *Game, obj: *Object, bd: *Backdrop) void {
    switch (obj.kind) {
        .pacman => pacmanStopMovingDc(g, obj, bd),
        .ghost => ghostStopMovingDc(g, obj, bd),
        // scene_object_stop_moving_dc_default (absorbed)
        .dot, .control_panel => {},
    }
}

/// SceneObject slot 39 stopMoving: pacman_stop_moving (pacman), ghost_stop_moving (ghost) / default.
pub fn stopMoving(g: *Game, obj: *Object, bd: *Backdrop) void {
    switch (obj.kind) {
        .pacman => pacmanStopMoving(g, obj, bd),
        .ghost => ghostStopMoving(g, obj, bd),
        // scene_object_stop_moving_default (absorbed)
        .dot, .control_panel => {},
    }
}

/// SceneObject slot 3A moveTick: pacman_move_tick (pacman), ghost_move_tick (ghost) / default.
pub fn moveTick(g: *Game, obj: *Object, bd: *Backdrop) void {
    switch (obj.kind) {
        .pacman => pacmanMoveTick(g, obj, bd),
        .ghost => ghostMoveTick(g, obj, bd),
        // scene_object_move_tick_default (absorbed)
        .dot, .control_panel => {},
    }
}

/// SceneObject slot 3C isMoving: actor2d_is_moving (pacman, ghost) / default.
pub fn isMoving(g: *Game, obj: *Object) bool {
    _ = g;
    return switch (obj.kind) {
        // @orig 10a0:2b2c actor2d_is_moving
        .pacman, .ghost => moverIsMoving(obj),
        // scene_object_is_moving_default (absorbed)
        .dot, .control_panel => false,
    };
}

// @orig 10a0:25fc mover_is_moving
fn moverIsMoving(obj: *Object) bool {
    return obj.mover.moving != 0;
}

/// MoverVtbl / PacmanVtbl / GhostVtbl slot 00 placeAt (mover_place_at).
pub fn placeAt(g: *Game, obj: *Object, x: i16, y: i16, bd: *Backdrop) void {
    switch (obj.kind) {
        .pacman, .ghost => moverPlaceAt(g, obj, x, y, bd),
        // The Mover vtables only exist on these two.
        else => unreachable,
    }
}

// @orig 1020:0be1 mover_place_at
fn moverPlaceAt(g: *Game, obj: *Object, x: i16, y: i16, bd: *Backdrop) void {
    _ = occupancy.vacate(g, obj, bd);
    position.setPosition(g, obj, x, y);
    render.restoreBackground(g, obj, bd, 1);
    _ = occupancy.occupy(g, obj, bd);
    // scene_object_dc_hook (an empty hook, render's).
    render.draw(g, obj, bd);
}

// @orig 1020:1696 mover_step
/// Advances the next position one Bresenham step towards the target.
fn moverStep(obj: *Object) void {
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

// @orig 1020:17ad mover_at_target
/// True when the next position is within one step of the target along the
/// major axis (y when errIncX is 0, else x).
fn moverAtTarget(obj: *Object) bool {
    const m = &obj.mover;
    if (m.errIncX == 0) {
        return !(abs16(m.stepY) < abs16(obj.nextY -% m.targetY));
    }
    return !(abs16(m.stepX) < abs16(obj.nextX -% m.targetX));
}

// @orig 1020:1acf mover_move_to
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

// @orig 1020:1e5f mover_move_to_edge_v
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

// @orig 1020:2084 mover_move_to_edge_h
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

// @orig 1080:074a pacman_move_to
/// Stops the animation, shows a strip (BUGS.md P5: NOITE's numbering, left
/// is +2 and every other click +1), walks, and idles if the walk is empty.
fn pacmanMoveTo(g: *Game, obj: *Object, x: i16, y: i16, bd: *Backdrop) void {
    animation.stop(g, obj);
    const tx = x -% (@divTrunc(position.width(obj), 2) -% bd.originX);
    if (g.fixes.sauna_click_faces_walk) {
        // SAUNA's strips: left 0, right 1, up 2, down 3, by the larger leg.
        const dx = tx -% obj.x;
        const dy = (y -% (position.height(obj) -% bd.originY)) -% obj.y;
        const strip: i16 = if (abs16(dx) >= abs16(dy))
            (if (dx < 0) 0 else 1)
        else
            (if (dy < 0) 2 else 3);
        _ = animation.setStrip(g, obj, g.powerStrip +% strip, bd);
    } else if (tx < obj.x) {
        _ = animation.setStrip(g, obj, g.powerStrip +% 2, bd);
    } else {
        _ = animation.setStrip(g, obj, g.powerStrip +% 1, bd);
    }
    moverMoveTo(g, obj, x, y, bd);
    if (obj.mover.moving == 0) animation.playIdle(g, obj, bd);
}

// @orig 1080:037e pacman_move_to_edge_h
fn pacmanMoveToEdgeH(g: *Game, obj: *Object, bd: *Backdrop, dir: i16) void {
    animation.stop(g, obj);
    _ = animation.setStrip(g, obj, g.powerStrip +% (if (dir == 2) @as(i16, 1) else 0), bd);
    moverMoveToEdgeH(g, obj, bd, dir);
    if (obj.mover.moving == 0) animation.playIdle(g, obj, bd);
}

// @orig 1080:0468 pacman_move_to_edge_v
fn pacmanMoveToEdgeV(g: *Game, obj: *Object, bd: *Backdrop, dir: i16) void {
    animation.stop(g, obj);
    _ = animation.setStrip(g, obj, g.powerStrip +% (if (dir == 8) @as(i16, 3) else 2), bd);
    moverMoveToEdgeV(g, obj, bd, dir);
    if (obj.mover.moving == 0) animation.playIdle(g, obj, bd);
}

// @orig 1080:0557 pacman_stop_moving_dc
fn pacmanStopMovingDc(g: *Game, obj: *Object, bd: *Backdrop) void {
    obj.mover.moving = 0;
    animation.playIdle(g, obj, bd);
}

// @orig 1080:05ac pacman_stop_moving
fn pacmanStopMoving(g: *Game, obj: *Object, bd: *Backdrop) void {
    pacmanStopMovingDc(g, obj, bd);
}

// @orig 1080:1e9b ghost_stop_moving_dc
fn ghostStopMovingDc(g: *Game, obj: *Object, bd: *Backdrop) void {
    ghost.chooseDirection(g, obj, bd);
}

// @orig 1080:1ed0 ghost_stop_moving
fn ghostStopMoving(g: *Game, obj: *Object, bd: *Backdrop) void {
    ghost.chooseDirection(g, obj, bd);
}

// @orig 1080:0a8c pacman_move_tick
fn pacmanMoveTick(g: *Game, obj: *Object, bd: *Backdrop) void {
    if (obj.mover.moving == 0) return;
    _ = animation.nextFrame(g, obj);
    moverStep(obj);
    if (!occupancy.canStep(g, obj, bd)) {
        pacmanStopMovingDc(g, obj, bd);
    } else {
        render.resetRects(obj);
        moverPlaceAt(g, obj, obj.nextX, obj.nextY, bd);
        visibility.invalidate(g, obj);
        if (moverAtTarget(obj)) pacmanStopMovingDc(g, obj, bd);
    }
}

// @orig 1080:1f05 ghost_move_tick
fn ghostMoveTick(g: *Game, obj: *Object, bd: *Backdrop) void {
    if (obj.mover.moving == 0) return;
    _ = animation.nextFrame(g, obj);
    const p = g.pacman.?;
    if (abs16(p.x -% obj.x) < 0x11 or abs16(p.y -% obj.y) < 0x11) {
        ghost.chooseDirection(g, obj, bd);
    }
    moverStep(obj);
    if (!occupancy.canStep(g, obj, bd)) {
        ghostStopMovingDc(g, obj, bd);
    } else {
        moverPlaceAt(g, obj, obj.nextX, obj.nextY, bd);
        visibility.redrawOverlapping(g, obj, bd, 1);
        visibility.invalidate(g, obj);
        if (moverAtTarget(obj)) ghostStopMovingDc(g, obj, bd);
    }
}
