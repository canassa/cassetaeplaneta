//! Port unit `movement` (behaviour) of ENCAIXE.EXE. SceneObject slots 31-36 38 (moveTo, edges, stopMoving(Dc), moveTick, isMoving) and MoverVtbl/PieceVtbl placeAt.
//!
//! Only the piece is a Mover: the other kinds take the slot's default
//! (absorbed, empty). The GetDC/ReleaseDC pairs of the originals are gone
//! (the DC is the platform screen).

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

fn abs16(v: i16) i16 {
    return if (v < 0) 0 -% v else v;
}

fn curFrameDef(obj: *Object) *const object.Frame {
    return &obj.frames[@intCast(obj.curStrip)];
}

/// SceneObject slot 31 moveTo (hwnd dropped): Mover's (piece).
pub fn moveTo(g: *Game, obj: *Object, x: i16, y: i16, bd: *Backdrop) void {
    switch (obj.kind) {
        .piece => moverMoveTo(g, obj, x, y, bd),
        // scene_object_move_to_default (absorbed)
        .control_panel, .status_bar => {},
    }
}

/// SceneObject slot 32 moveToEdgeH.
pub fn moveToEdgeH(g: *Game, obj: *Object, bd: *Backdrop, dir: i16) void {
    switch (obj.kind) {
        .piece => moverMoveToEdgeH(g, obj, bd, dir),
        // scene_object_move_to_edge_h_default (absorbed)
        .control_panel, .status_bar => {},
    }
}

/// SceneObject slot 33 moveToEdgeV.
pub fn moveToEdgeV(g: *Game, obj: *Object, bd: *Backdrop, dir: i16) void {
    switch (obj.kind) {
        .piece => moverMoveToEdgeV(g, obj, bd, dir),
        // scene_object_move_to_edge_v_default (absorbed)
        .control_panel, .status_bar => {},
    }
}

/// SceneObject slot 34 stopMovingDc: te_piece_stop_moving_dc (piece).
pub fn stopMovingDc(g: *Game, obj: *Object, bd: *Backdrop) void {
    switch (obj.kind) {
        .piece => tePieceStopMovingDc(g, obj, bd),
        // scene_object_stop_moving_dc_default (absorbed)
        .control_panel, .status_bar => {},
    }
}

/// SceneObject slot 35 stopMoving: te_piece_stop_moving (piece).
pub fn stopMoving(g: *Game, obj: *Object, bd: *Backdrop) void {
    switch (obj.kind) {
        .piece => tePieceStopMoving(g, obj, bd),
        // scene_object_stop_moving_default (absorbed)
        .control_panel, .status_bar => {},
    }
}

/// SceneObject slot 36 moveTick: Player2D's (piece).
pub fn moveTick(g: *Game, obj: *Object, bd: *Backdrop) void {
    switch (obj.kind) {
        .piece => player2dMoveTick(g, obj, bd),
        // scene_object_move_tick_default (absorbed)
        .control_panel, .status_bar => {},
    }
}

/// SceneObject slot 38 isMoving: Actor2D's (piece).
pub fn isMoving(g: *Game, obj: *Object) bool {
    _ = g;
    return switch (obj.kind) {
        // @orig 1008:5cd4 actor2d_is_moving
        .piece => obj.mover.moving != 0,
        // scene_object_is_moving_default (absorbed)
        .control_panel, .status_bar => false,
    };
}

/// MoverVtbl / PieceVtbl slot 00 placeAt (mover_place_at).
pub fn placeAt(g: *Game, obj: *Object, x: i16, y: i16, bd: *Backdrop) void {
    switch (obj.kind) {
        .piece => moverPlaceAt(g, obj, x, y, bd),
        // The Mover vtables only exist on the piece.
        else => unreachable,
    }
}

// @orig 1008:719c mover_place_at
fn moverPlaceAt(g: *Game, obj: *Object, x: i16, y: i16, bd: *Backdrop) void {
    _ = occupancy.vacate(g, obj, bd);
    position.setPosition(g, obj, x, y);
    render.restoreBackground(g, obj, bd, 1);
    _ = occupancy.occupy(g, obj, bd);
    // scene_object_dc_hook (1008:6ea8): an empty hook (render's).
    render.draw(g, obj, bd);
}

// @orig 1008:76f0 mover_step
/// Advances the next position one Bresenham step towards the target (also
/// called directly by `piece.moveTick`).
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

// @orig 1008:777a mover_at_target
/// True when the next position is within one step of the target along the
/// major axis (y when errIncX is 0, else x).
fn moverAtTarget(obj: *Object) bool {
    const m = &obj.mover;
    if (m.errIncX == 0) {
        return !(abs16(m.stepY) < abs16(obj.nextY -% m.targetY));
    }
    return !(abs16(m.stepX) < abs16(obj.nextX -% m.targetX));
}

// @orig 1008:77d8 mover_move_tick
fn moverMoveTick(g: *Game, obj: *Object, bd: *Backdrop) void {
    if (obj.mover.moving == 0) return;
    moverStep(obj);
    if (occupancy.canStep(g, obj, bd)) {
        const f = curFrameDef(obj);
        obj.dirty.left = 0;
        obj.clip.left = 0;
        obj.dirty.top = 0;
        obj.clip.top = 0;
        obj.dirty.right = f.width;
        obj.clip.right = f.width;
        obj.dirty.bottom = f.height;
        obj.clip.bottom = f.height;
        placeAt(g, obj, obj.nextX, obj.nextY, bd);
        visibility.redrawOverlapping(g, obj, bd, 1);
        visibility.blitToDc(g, obj, bd);
        _ = backdrop.autoscroll(g, bd, obj, obj.nextX, obj.nextY);
        if (!moverAtTarget(obj)) return;
    }
    stopMovingDc(g, obj, bd);
}

// @orig 1008:7912 mover_move_to
/// Starts moving towards screen point (x, y): the target puts the sprite's
/// bottom centre on it, clamped to the background; sets up the Bresenham
/// line and starts the movement system timer. A zero-length move leaves
/// `moving` 0.
fn moverMoveTo(g: *Game, obj: *Object, x: i16, y: i16, bd: *Backdrop) void {
    const m = &obj.mover;
    m.stepX = abs16(m.stepX);
    m.stepY = abs16(m.stepY);
    m.moving = 1;
    const w = curFrameDef(obj).width;
    const h = curFrameDef(obj).height;
    const half = @divTrunc(w, 2);
    if (0 -% (half -% bd.bgWidth) < bd.originX +% x) {
        m.targetX = bd.bgWidth -% w;
    } else {
        m.targetX = (bd.originX -% half) +% x;
    }
    if (bd.bgHeight < bd.originY +% y) {
        m.targetY = bd.bgHeight -% h;
    } else {
        m.targetY = (bd.originY -% h) +% y;
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

// @orig 1008:7a8a mover_move_to_edge_v
/// Vertical move to the bottom edge of the background (dir 8) or half off
/// the top (dir 4); any other dir, or no distance, stops. The piece's fall.
fn moverMoveToEdgeV(g: *Game, obj: *Object, bd: *Backdrop, dir: i16) void {
    const m = &obj.mover;
    m.stepX = abs16(m.stepX);
    m.stepY = abs16(m.stepY);
    m.moving = 1;
    m.targetX = obj.x;
    const h = curFrameDef(obj).height;
    const off: i16 = if (dir == 8)
        h -% bd.bgHeight
    else if (dir == 4)
        @divTrunc(h, 2)
    else {
        m.moving = 0;
        return;
    };
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
    m.lineErr = m.lineDy;
    m.errIncDiag = m.lineDy *% 2;
    m.errIncX = 0;
    m.errIncY = 0;
    g.setSystemTimer(@bitCast(m.timerId), @bitCast(m.timerPeriod));
}

// @orig 1008:7b66 mover_move_to_edge_h
/// Horizontal move to the right edge of the background (dir 2) or half off
/// the left (dir 1); any other dir, or no distance, stops.
fn moverMoveToEdgeH(g: *Game, obj: *Object, bd: *Backdrop, dir: i16) void {
    const m = &obj.mover;
    m.stepX = abs16(m.stepX);
    m.stepY = abs16(m.stepY);
    m.moving = 1;
    const w = curFrameDef(obj).width;
    const off: i16 = if (dir == 2)
        w -% bd.bgWidth
    else if (dir == 1)
        @divTrunc(w, 2)
    else {
        m.moving = 0;
        return;
    };
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
    m.errIncX = 2;
    m.lineErr = 2 -% m.lineDx;
    m.errIncDiag = m.lineErr -% m.lineDx;
    m.errIncY = 0;
    g.setSystemTimer(@bitCast(m.timerId), @bitCast(m.timerPeriod));
}

// @orig 1008:7c50 mover_stop_moving
/// Mover's stopMoving (GetDC, stopMovingDc, ReleaseDC). The piece overrides
/// slot 35, but te_scene_handle_message calls this one directly (the
/// left/right keys).
pub fn moverStopMoving(g: *Game, obj: *Object, bd: *Backdrop) void {
    stopMovingDc(g, obj, bd);
}

// @orig 1008:7eee player2d_move_tick
/// While moving: next frame of the strip, then the mover's tick; always
/// posts 0x405 (player stepped) with the object id. The original's lParam
/// is `(y & (x >> 15)) << 16`: the y position when x is negative, else 0.
fn player2dMoveTick(g: *Game, obj: *Object, bd: *Backdrop) void {
    if (obj.mover.moving != 0) {
        _ = animation.nextFrame(g, obj);
        moverMoveTick(g, obj, bd);
    }
    const hi: u16 = @bitCast(obj.y & (obj.x >> 15));
    _ = g.post(msg.Msg.make(msg.noite.player_stepped, @bitCast(obj.id), 0, hi));
}

// @orig 1008:bbd8 te_piece_stop_moving_dc
/// Makes the piece rest where it is: the steps lose their sign, the target
/// and the previous position become the current one. The first half goes
/// through `g_piece`, the second through `this` (the same object).
fn tePieceStopMovingDc(g: *Game, obj: *Object, bd: *Backdrop) void {
    _ = bd;
    const p = g.piece.?;
    p.mover.stepX = abs16(p.mover.stepX);
    p.mover.stepY = abs16(p.mover.stepY);
    p.mover.targetX = p.x;
    p.mover.targetY = p.y;
    obj.mover.prevX = obj.x;
    obj.mover.targetX = obj.x;
    obj.mover.prevY = obj.y;
    obj.mover.targetY = obj.y;
}

// @orig 1008:bc38 te_piece_stop_moving
fn tePieceStopMoving(g: *Game, obj: *Object, bd: *Backdrop) void {
    tePieceStopMovingDc(g, obj, bd);
    obj.mover.direction = 8;
    obj.mover.moving = 0;
}
