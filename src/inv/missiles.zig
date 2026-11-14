//! Port unit `missiles` (module) of INV.EXE. the shot and the 2 bombs: creation (the null-pointer writes, BUGS.md INV Harmless), MissileVtbl armTimer and moveTick, shot_vanish, bomb_shot_down.
//!
//! Virtual-slot dispatchers owned by this unit keep their signatures
//! (docs/inv/DESIGN.md "Virtual slots"); hwnd/hdc parameters are dropped.

const Game = @import("core/game.zig").Game;
const object = @import("core/object.zig");
const Object = object.Object;
const world = @import("core/world.zig");
const Backdrop = world.Backdrop;
const object_create = @import("object_create.zig");
const animation = @import("behaviour/animation.zig");
const movement = @import("behaviour/movement.zig");
const occupancy = @import("behaviour/occupancy.zig");
const visibility = @import("behaviour/visibility.zig");

// @orig 1068:03df inv_create_shot
/// Builds the one shot (`g_shots[0]`; the loop runs `i < 1`): `Shot` at x 0,
/// y 0x17c, 1 strip (Tiro.bmp, 2 frames of 12 x 22), hit box 0,0 and strip
/// 0's size, timer 0xd at 55 ms, step 20 x 20, hidden. Then attach and
/// `hitFrame` = -1. The original first stores 0 through the still-NULL
/// `g_shots[i]` (DGROUP 0x42, BUGS.md INV Harmless): not ported, the port
/// has no such bytes. A failed allocation stores NULL and dereferences it
/// next; here it is the error.
pub fn createShot(g: *Game, bd: *Backdrop) object_create.Error!void {
    var i: usize = 0;
    while (i < 1) : (i += 1) {
        const shot = g.local().create(Object) catch {
            g.shots[i] = null;
            return error.OutOfMemory;
        };
        shot.* = .{ .kind = .shot };
        try object_create.shotCtor(g, shot, 0, 0x17c, 1, &g.shotStripFiles, &g.shotStripFrames, &g.shotStripWidths, &g.shotStripHeights, 0, 0, g.shotStripWidths[0], g.shotStripHeights[0], 0xd, 0x37, 20, 20, 0, 0, true);
        g.shots[i] = shot;
        _ = occupancy.attach(g, shot, bd);
        shot.missile.hitFrame = -1;
    }
}

// @orig 1068:04bc shot_vanish
/// The cannon's shot hit something: frame 1 of Tiro.bmp (blank), placed at
/// its own position (erases the flying picture), blit, then the Mover's own
/// stop (`moving` = 0, timer 0xd killed) so SPACE can fire again.
pub fn shotVanish(g: *Game, obj: *Object, bd: *Backdrop) void {
    obj.curFrame = 1;
    occupancy.placeAt(g, obj, obj.x, obj.y, bd);
    visibility.blitToDc(g, obj, bd);
    movement.moverStopMovingDc(g, obj);
}

// @orig 1068:0541 inv_create_bombs
/// Builds the two bombs (`g_bombs[i]`): `Bomb` parked at x 0x26c, y 0, 2
/// strips (Bomba.bmp, Bomtir.bmp), hit box 0,0 and strip 0's size, timer
/// `bombTimerIds[i]` at 55 ms, step 20 x 20, hidden. Then the Mover attach,
/// the drop timer through `armTimer` (bomb 0 kind 2, bomb 1 kind 5; periods
/// and ids from `g.bombDropPeriods` / `g.bombDropTimerIds`) and the
/// SceneObject attach. The original's store through the still-NULL
/// `g_bombs[i]` (DGROUP 0x42 = 1) is not ported (BUGS.md INV Harmless).
pub fn createBombs(g: *Game, bd: *Backdrop) object_create.Error!void {
    var i: usize = 0;
    while (i < 2) : (i += 1) {
        const bomb = g.local().create(Object) catch {
            g.bombs[i] = null;
            return error.OutOfMemory;
        };
        bomb.* = .{ .kind = .bomb };
        try object_create.bombCtor(g, bomb, 0x26c, 0, 2, &g.bombStripFiles, &g.bombStripFrames, &g.bombStripWidths, &g.bombStripHeights, 0, 0, g.bombStripWidths[0], g.bombStripHeights[0], g.bombTimerIds[i], 0x37, 20, 20, 0, 0, true);
        g.bombs[i] = bomb;
        // mover_attach (1088:1fb0) on the Mover part, then the slot's attach
        // (the second is a no-op: `attached` is set).
        _ = occupancy.attach(g, bomb, bd);
        _ = armTimer(g, bomb, @bitCast(g.bombDropTimerIds[i]), @bitCast(g.bombDropPeriods[i]), if (i == 0) 2 else 5);
        _ = occupancy.attach(g, bomb, bd);
    }
}

// @orig 1068:06d1 bomb_shot_down
/// The cannon's shot met a bomb: stop it if moving (the Mover's own stop),
/// hide it when below y 400, and for hitState '1' switch to strip 1
/// (Bomtir.bmp, the impact), `framesLeft` 3, `hitFrame` 3, show, play.
pub fn bombShotDown(g: *Game, obj: *Object, bd: *Backdrop) void {
    if (movement.isMoving(g, obj)) movement.moverStopMovingDc(g, obj);
    if (obj.y > 400) visibility.hideAndInvalidate(g, obj, 0, bd);
    if (obj.missile.hitState == '1') {
        obj.curStrip = 1;
        obj.anim.framesLeft = 3;
        obj.missile.hitFrame = 3;
        visibility.show(g, obj, bd);
        animation.play(g, obj, bd);
    }
}

/// MissileVtbl slot 01 armTimer (missile_arm_timer; hwnd dropped): a bomb's
/// drop timer (`kind` 2 sets `timer2Id` and `timer2IdB`, 5 only `timer2IdB`);
/// returns the missile, as the original returns `this`.
// @orig 1068:0e26 missile_arm_timer
pub fn armTimer(g: *Game, obj: *Object, timer_id: u16, period: u16, kind: i16) *Object {
    if (kind == 2) {
        obj.missile.timer2Id = @bitCast(timer_id);
        obj.missile.timer2IdB = @bitCast(timer_id);
    } else if (kind == 5) {
        obj.missile.timer2IdB = @bitCast(timer_id);
    }
    g.setSystemTimer(timer_id, period);
    return obj;
}

/// MissileVtbl slot 02 moveTick (missile_move_tick; hwnd dropped): stop
/// off-screen (the shot at y < 5, a bomb below y 470), else one step.
// @orig 1068:0f2f missile_move_tick
pub fn moveTick(g: *Game, obj: *Object, bd: *Backdrop) void {
    if (obj.y < 5 or obj.y > 0x1d6) {
        movement.stopMovingDc(g, obj, bd);
        visibility.hideAndInvalidate(g, obj, 0, bd);
    } else {
        movement.moveTick(g, obj, bd);
    }
}

test "analyze all" {
    _ = .{ &createShot, &shotVanish, &createBombs, &bombShotDown, &armTimer, &moveTick };
}
