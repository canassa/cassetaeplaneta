//! Port unit `hero` (module) of INFERNO.EXE. the Hero class (the player, a
//! Player2D): its SceneObject overrides (play, tick, moveToEdgeV,
//! stopMoving(Dc), moveTick: walk, jump, the world scroll), the jump,
//! hero_collide (BUGS.md H5, H7), size toggle, pose reset.
//!
//! The Hero is an Actor2D whose SceneObject sits at Hero + 0x62 in the
//! original (`this` of the SceneObject overrides, `this - 0x62` for the class
//! methods); here both are `obj`. GetDC/ReleaseDC and hwnd/hdc are gone (the
//! DC is the platform screen).

const Game = @import("core/game.zig").Game;
const object = @import("core/object.zig");
const Object = object.Object;
const world = @import("core/world.zig");
const Backdrop = world.Backdrop;
const backdrop = @import("backdrop.zig");
const ledge = @import("ledge.zig");
const prop = @import("prop.zig");
const score = @import("score.zig");
const animation = @import("behaviour/animation.zig");
const movement = @import("behaviour/movement.zig");
const occupancy = @import("behaviour/occupancy.zig");
const position = @import("behaviour/position.zig");
const render = @import("behaviour/render.zig");
const visibility = @import("behaviour/visibility.zig");

fn abs16(v: i16) i16 {
    return if (v < 0) 0 -% v else v;
}

/// The original indexes the global arrays unchecked.
fn idx(i: i16) usize {
    return @as(u16, @bitCast(i));
}

// @orig 1068:589e inferno_nop (absorbed)
// An empty far cdecl function; its only call (hero_move_tick's walk) is dropped.

/// The hero's strip from its state: curFrame 0 (1 while `busy`, the jump
/// pose), curStrip the standing one (small 0/2, big 4/6 by facing).
// @orig 1068:0b01 hero_reset_pose
pub fn resetPose(g: *Game, obj: *Object, bd: *Backdrop) void {
    _ = g;
    _ = bd;
    const h = &obj.hero;
    obj.curFrame = 0;
    if (h.facing == 1) {
        obj.curStrip = if (h.altStrips == 0) 2 else 6;
    } else {
        obj.curStrip = if (h.altStrips == 0) 0 else 4;
    }
    if (h.busy != 0) obj.curFrame = 1;
}

/// Small <-> big: the walk stops, the strip changes (`powerTimer` 180 when it
/// becomes big), the pose goes back onto the floor line whatever the height.
// @orig 1068:09be hero_toggle_size
pub fn toggleSize(g: *Game, obj: *Object, bd: *Backdrop) void {
    const h = &obj.hero;
    if (h.walking != 0) {
        h.walking = 0;
        obj.mover.moving = 0;
    }
    if (h.altStrips == 0) {
        h.powerTimer = 0xb4;
        h.altStrips = 1;
        obj.curStrip = if (h.facing == 1) 6 else 4;
    } else {
        h.altStrips = 0;
        h.powerTimer = 0;
        obj.curStrip = if (h.facing == 1) 2 else 0;
    }
    obj.curFrame = if (h.busy == 0) 0 else 1;
    movement.placeAt(g, obj, obj.x, g.floorY, bd);
    visibility.invalidate(g, obj);
}

/// The animation timer stopped on strips 8-11 (death, kill): the hero stands
/// on the floor line facing right (a small hero always on strip 0).
// @orig 1068:1936 hero_anim_done
pub fn animDone(g: *Game, obj: *Object, bd: *Backdrop) void {
    const h = &obj.hero;
    if (h.altStrips == 0) {
        obj.curStrip = 0;
    } else if (h.facing == 2) {
        obj.curStrip = 4;
    } else {
        obj.curStrip = 6;
    }
    obj.curFrame = 0;
    h.walking = 0;
    h.busy = 0;
    h.facing = 2;
    h.jumpTicks = 0;
    h.jumpPhase = 4;
    movement.placeAt(g, obj, obj.x, g.floorY, bd);
    visibility.invalidate(g, obj);
}

/// SceneObject slot 29 play override (hero_play: hero_collide;
/// animation.play's hero arm).
// @orig 1068:0bc8 hero_play
pub fn play(g: *Game, obj: *Object, bd: *Backdrop) void {
    collide(g, obj, bd);
}

/// SceneObject slot 2D tick override (hero_tick; animation.tick's hero arm):
/// the next frame, re-placed where it is so it is drawn, invalidated.
// @orig 1068:15c3 hero_tick
pub fn tick(g: *Game, obj: *Object, bd: *Backdrop) void {
    _ = animation.nextFrame(g, obj);
    movement.placeAt(g, obj, obj.x, obj.y, bd);
    visibility.invalidate(g, obj);
}

/// SceneObject slot 31 moveToEdgeV override (hero_move_to_edge_v: the jump's
/// target; movement.moveToEdgeV's hero arm). The engine's, but it stores
/// `dir` in `jumpPhase` (even for a dir it then refuses) and does not start
/// the movement timer.
// @orig 1068:1720 hero_move_to_edge_v
pub fn moveToEdgeV(g: *Game, obj: *Object, bd: *Backdrop, dir: i16) void {
    _ = g;
    const m = &obj.mover;
    m.stepX = abs16(m.stepX);
    m.stepY = abs16(m.stepY);
    m.moving = 1;
    obj.hero.jumpPhase = @bitCast(dir);
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
}

/// SceneObject slot 32 stopMovingDc override (hero_stop_moving_dc, hdc
/// dropped; movement.stopMovingDc's hero arm). The mover's, without the
/// timer kill, and it also clears `walking`.
// @orig 1068:1649 hero_stop_moving_dc
pub fn stopMovingDc(g: *Game, obj: *Object, bd: *Backdrop) void {
    _ = g;
    _ = bd;
    const m = &obj.mover;
    m.moving = 0;
    obj.hero.walking = 0;
    m.stepX = abs16(m.stepX);
    m.stepY = abs16(m.stepY);
    m.prevX = obj.x;
    m.targetX = obj.x;
    m.prevY = obj.y;
    m.targetY = obj.y;
}

/// SceneObject slot 33 stopMoving override (hero_stop_moving;
/// movement.stopMoving's hero arm).
// @orig 1068:16dd hero_stop_moving
pub fn stopMoving(g: *Game, obj: *Object, bd: *Backdrop) void {
    stopMovingDc(g, obj, bd);
}

/// The landing reset: stop, no jump, no walk, standing frame, back on the
/// floor line.
fn land(g: *Game, obj: *Object, bd: *Backdrop) void {
    stopMovingDc(g, obj, bd);
    obj.hero.busy = 0;
    obj.hero.walking = 0;
    obj.curFrame = 0;
    movement.placeAt(g, obj, obj.x, g.floorY, bd);
    visibility.invalidate(g, obj);
}

/// Parks a killed hazard: erased, blitted and put at x = -width.
fn park(g: *Game, other: *Object, bd: *Backdrop) void {
    render.erase(g, other, bd);
    visibility.blitToDc(g, other, bd);
    movement.placeAt(g, other, 0 -% position.width(other), other.y, bd);
}

/// The bounce shared by a platform and another prop: the hero stops, falls
/// (`jumpKind` 2) and is put 5 px lower.
fn bounce(g: *Game, obj: *Object, bd: *Backdrop) void {
    const h = &obj.hero;
    h.busy = 1;
    h.jumpKind = 2;
    h.jumpTicks = 0;
    h.walking = 0;
    h.jumpPhase = 8;
    moveToEdgeV(g, obj, bd, 8);
    movement.placeAt(g, obj, obj.x, obj.y +% 5, bd);
    visibility.blitToDc(g, obj, bd);
}

/// The hero's collision response, `other` = SceneObject.linked (set by
/// canStep or by prop.hitPlayer; no NULL test in the original). Hazard: a
/// small hero's stomp (more than 30 px above it) gives +150 once per latch,
/// a side hit plays the death strip and costs nothing (H5); a big hero
/// kills it for +150 and plays the kill strip; the hazard is parked. Platform:
/// bounce and its `play`. The cross: +300, parked at x 640, size toggled.
/// Another prop: bounce. Anything else: the jump ends.
// @orig 1068:0260 hero_collide
pub fn collide(g: *Game, obj: *Object, bd: *Backdrop) void {
    const h = &obj.hero;
    const other = obj.linked.?.as(.actor2d).?;
    if (other.is(.hazard)) {
        if (h.altStrips == 0) {
            render.resetRects(obj);
            if (obj.y < other.y -% 0x1e) {
                if (g.stompScored == 0) {
                    g.stompScored = 1;
                    score.add150(g, bd);
                }
                park(g, other, bd);
            } else {
                movement.stopMoving(g, obj, bd);
                h.walking = 0;
                h.busy = 0;
                park(g, other, bd);
                obj.curStrip = if (h.facing == 2) 8 else 9;
                animation.playOnce(g, obj, bd);
                if (g.fixes.inferno_side_hit_costs_life) score.loseLife(g, bd);
            }
        } else {
            score.add150(g, bd);
            obj.curStrip = if (h.facing == 2) 10 else 11;
            obj.curFrame = 0;
            movement.placeAt(g, obj, obj.x, g.floorY, bd);
            visibility.invalidate(g, obj);
            park(g, other, bd);
            animation.playOnce(g, obj, bd);
        }
    } else if (other.is(.platform)) {
        stopMovingDc(g, obj, bd);
        bounce(g, obj, bd);
        animation.play(g, other, bd);
    } else if (prop.isPowerUp(g, other)) {
        score.add300(g, bd);
        movement.stopMoving(g, other, bd);
        visibility.hideAndInvalidate(g, other, 0, bd);
        movement.placeAt(g, other, 0x280, other.y, bd);
        toggleSize(g, obj, bd);
    } else if (other.is(.prop)) {
        movement.stopMovingDc(g, obj, bd);
        bounce(g, obj, bd);
    } else {
        h.busy = 0;
        h.walking = 0;
        obj.mover.moving = 0;
        resetPose(g, obj, bd);
    }
}

/// One 55 ms step of a jump: a vertical step (clamped to the floor line, a
/// walking jump drifting 2 px sideways outside the scroll zone), then the
/// occupancy decides: free, it is placed and the world redrawn around it and
/// the rise turns into the fall (or the fall ends); blocked by an object,
/// `collide`; blocked by the floor wall, it lands.
// @orig 1068:0edc hero_jump_step
pub fn jumpStep(g: *Game, obj: *Object, bd: *Backdrop) void {
    const h = &obj.hero;
    movement.moverStep(obj);
    if (g.floorY < obj.nextY) obj.nextY = g.floorY;
    if ((h.jumpKind == 1 or h.jumpKind == 3) and (obj.x < 0x154 or (obj.x > 0x153 and h.facing == 1))) {
        const half = @divTrunc(obj.mover.stepX, 2);
        if (h.facing == 1) {
            obj.nextX -%= half;
        } else {
            obj.nextX +%= half;
        }
    }
    if (!occupancy.canStep(g, obj, bd)) {
        if (obj.linked == null) {
            land(g, obj, bd);
        } else {
            collide(g, obj, bd);
        }
    } else {
        movement.placeAt(g, obj, obj.nextX, obj.nextY, bd);
        visibility.redrawOverlapping(g, obj, bd, 1);
        for (g.platforms) |p| {
            const item = p.?.platform.item.?;
            if (item.curFrame == 0) visibility.show(g, item, bd);
        }
        for (g.platforms) |p| visibility.show(g, p.?, bd);
        render.draw(g, obj, bd);
        visibility.invalidate(g, obj);
        _ = backdrop.autoscroll(g, bd, obj, obj.nextX, obj.nextY);
        if (movement.moverAtTarget(obj) or (h.jumpPhase == 4 and @as(i16, @bitCast(h.jumpTicks)) < 1)) {
            if (h.jumpPhase == 4) {
                moveToEdgeV(g, obj, bd, 8);
                h.jumpPhase = 8;
            } else {
                land(g, obj, bd);
            }
        }
    }
    if (h.busy != 0 and obj.y == g.floorY) land(g, obj, bd);
    if (h.jumpPhase == 4) h.jumpTicks -%= 1;
}

/// A jump starts (`jumpKind` is set by the key handler): the jump pose, 18
/// (UP) or 12 (DOWN) rise ticks, the rise; the first jump before any move
/// starts the move timer through the engine's moveToEdgeV. One move tick runs
/// at once.
// @orig 1068:016c hero_start_jump
pub fn startJump(g: *Game, obj: *Object, bd: *Backdrop) void {
    const h = &obj.hero;
    h.busy = 1;
    resetPose(g, obj, bd);
    obj.curFrame = 1;
    h.jumpTicks = if (h.jumpKind == 0 or h.jumpKind == 1) 0x12 else 0xc;
    if (g.heroTimerPending == 0) {
        moveToEdgeV(g, obj, bd, 4);
    } else {
        h.jumpPhase = 4;
        movement.moverMoveToEdgeV(g, obj, bd, 4);
        g.heroTimerPending = 0;
    }
    moveTick(g, obj, bd);
}

/// The landing reset of a move tick after a jump step that ended the jump
/// (the callers decide about the stomp latch, H7); unlike `land` it does not
/// stop the mover first.
fn moveTickLanding(g: *Game, obj: *Object, bd: *Backdrop) void {
    obj.hero.busy = 0;
    obj.hero.walking = 0;
    obj.curFrame = 0;
    movement.placeAt(g, obj, obj.x, g.floorY, bd);
    visibility.invalidate(g, obj);
}

/// SceneObject slot 34 moveTick override (hero_move_tick: the walk, the jump,
/// the world's scroll; movement.moveTick's hero arm). From x 340 facing right
/// the hero stays and the rocks, platforms and drinks move instead (walking
/// or in a walking jump). H7: that branch's landing keeps `stompScored`.
// @orig 1068:0bf7 hero_move_tick
pub fn moveTick(g: *Game, obj: *Object, bd: *Backdrop) void {
    const h = &obj.hero;
    g.scrolling = 0;
    if (h.busy == 0 and h.walking == 0) return;
    if (obj.x < 0x154 or (obj.x > 0x153 and h.facing == 1)) {
        if (h.busy == 0) {
            // inferno_nop (absorbed)
            _ = animation.nextFrame(g, obj);
            movement.moverMoveTick(g, obj, bd);
        } else {
            jumpStep(g, obj, bd);
            if (obj.mover.moving == 0 and h.jumpPhase == 8) {
                moveTickLanding(g, obj, bd);
                g.stompScored = 0;
            }
        }
    } else {
        g.scrolling = 1;
        if (h.jumpKind == 1 or h.jumpKind == 3 or h.walking != 0) {
            for (0..6) |i| {
                const rock = g.rocks[idx(g.rockOrder[i])].?;
                if (rock.prop.active != 0) prop.rockTick(g, rock, bd);
                if (i < 4) {
                    const p = g.platforms[i].?;
                    prop.drinkStep(g, p.platform.item.?, bd);
                    ledge.tick(g, p, bd);
                }
            }
        }
        if (h.busy == 0) {
            animation.tick(g, obj, bd);
        } else {
            jumpStep(g, obj, bd);
            if (obj.mover.moving == 0 and h.jumpPhase == 8) {
                moveTickLanding(g, obj, bd);
                if (g.fixes.inferno_scroll_landing_clears_stomp) g.stompScored = 0;
            }
        }
    }
}

test "every function compiles" {
    @import("std").testing.refAllDecls(@This());
    _ = abs16;
}
