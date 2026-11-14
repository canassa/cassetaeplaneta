//! Port unit `arrow` (module) of TIRO.EXE. the crossbow's aim and the arrow: creation, ProjectileVtbl stepMove/tryStep (the first hit stage), the shot wave.
//!
//! TIRO's own gameplay (no ENCAIXE twin). Virtual-slot dispatchers owned by
//! this unit keep their signatures (docs/tiro/DESIGN.md "Virtual slots");
//! hwnd/hdc parameters are dropped (the DC is the platform screen).

const Game = @import("core/game.zig").Game;
const object = @import("core/object.zig");
const Object = object.Object;
const world = @import("core/world.zig");
const Backdrop = world.Backdrop;
const object_create = @import("object_create.zig");
const sound = @import("sound.zig");
const movement = @import("behaviour/movement.zig");
const occupancy = @import("behaviour/occupancy.zig");
const position = @import("behaviour/position.zig");
const visibility = @import("behaviour/visibility.zig");

// @orig 1068:038a tiro_create_arrows
/// Builds the one arrow (`g_arrows[0]`; the original's loop runs `i < 1`):
/// `Arrow` at x 0, y 0x17c, 3 strips (Tiresq, Tirofr, Tirdir), hit box 0,0
/// and strip 0's width x height (55 x 27), timer 0x10 at 55 ms, step 10 x 10,
/// visible. Then attach, `curStrip` = 1 (the straight picture) and
/// `Projectile.unk46` = -1. A failed allocation stores NULL in the original
/// and dereferences it next; here it is the error.
pub fn createArrows(g: *Game, bd: *Backdrop) object_create.Error!void {
    var i: usize = 0;
    while (i < 1) : (i += 1) {
        const arrow = g.local().create(Object) catch {
            g.arrows[i] = null;
            return error.OutOfMemory;
        };
        arrow.* = .{ .kind = .arrow };
        try object_create.arrowCtor(g, arrow, 0, 0x17c, 3, &g.arrowStripFiles, &g.arrowStripFrames, &g.arrowStripWidths, &g.arrowStripHeights, 0, 0, g.arrowStripWidths[0], g.arrowStripHeights[0], 0x10, 0x37, 10, 10, 1, 0, true);
        g.arrows[i] = arrow;
        _ = occupancy.attach(g, arrow, bd);
        arrow.curStrip = 1;
        arrow.projectile.unk46 = -1;
    }
}

// @orig 1068:0476 crossbow_aim
/// Steps the crossbow's aim (`curFrame`) with wrap-around: 'D' (right)
/// 0 -> 1 -> 2 -> 0, 'E' (left) 0 -> 2, 1 -> 0, 2 -> 1; any other key, or an
/// aim outside 0..2, changes nothing. The `crossbow` parameter is unused (the
/// original works on `g_crossbow`, which must exist).
pub fn aim(g: *Game, key: i16) void {
    const cb = g.crossbow.?;
    const k: u8 = @truncate(@as(u16, @bitCast(key)));
    if (k == 'D') {
        switch (cb.curFrame) {
            0 => cb.curFrame = 1,
            1 => cb.curFrame = 2,
            2 => cb.curFrame = 0,
            else => {},
        }
    } else if (k == 'E') {
        switch (cb.curFrame) {
            0 => cb.curFrame = 2,
            1 => cb.curFrame = 0,
            2 => cb.curFrame = 1,
            else => {},
        }
    }
}

// @orig 1068:2d89 tiro_play_shot_wave
/// `wave_play(0, g_shotWave)`.
pub fn playShotWave(g: *Game) void {
    _ = sound.play(g, 0, g.shotWave);
}

fn abs16(v: i16) i16 {
    return if (v < 0) 0 -% v else v;
}

/// ProjectileVtbl slot 02 stepMove (hwnd and hdc dropped): while moving, one
/// Bresenham step and `tryStep`; blocked -> stop (the arrow vanishes),
/// `moving` = 0 and hideAndInvalidate; else place at the next position,
/// redraw the overlapping objects (targets, then the arrow), blit, and stop
/// at the destination. `dir` is the original's `int *outDir` (3 = a hit,
/// BUGS.md T5).
// @orig 1068:1641 projectile_step_move
pub fn stepMove(g: *Game, obj: *Object, bd: *Backdrop, dir: *i16) void {
    if (obj.mover.moving == 0) return;
    movement.moverStep(obj);
    if (tryStep(g, obj, bd, dir) == 0) {
        movement.stopMovingDc(g, obj, bd);
        obj.mover.moving = 0;
        visibility.hideAndInvalidate(g, obj, 0, bd);
    } else {
        movement.placeAt(g, obj, obj.nextX, obj.nextY, bd);
        visibility.redrawOverlapping(g, obj, bd, 1);
        visibility.blitToDc(g, obj, bd);
        if (movement.moverAtTarget(obj)) {
            movement.stopMovingDc(g, obj, bd);
            obj.mover.moving = 0;
        }
    }
}

/// ProjectileVtbl slot 03 tryStep: the occupancy query of the next rect
/// (`canStep`, which leaves the blocker in `linked`). Free: 1. Blocked with
/// no blocker (wall cell, or the grid's edge): 0. A blocker that is not a
/// Target (`isTarget`): `linked` cleared, 0. A Target: when
/// `|blocker.y - nextY| <= height / 2` of the blocker (47), `dir.*` = 3; 1
/// either way.
// @orig 1068:1448 projectile_try_step
pub fn tryStep(g: *Game, obj: *Object, bd: *Backdrop, dir: *i16) i16 {
    if (occupancy.canStep(g, obj, bd)) return 1;
    const blocker = obj.linked orelse return 0;
    if (!blocker.is(.target)) {
        obj.linked = null;
        return 0;
    }
    const half = @divTrunc(position.height(blocker), 2);
    if (abs16(blocker.y -% obj.nextY) <= half) dir.* = 3;
    return 1;
}

test "analyze all" {
    _ = .{ &createArrows, &aim, &playShotWave, &stepMove, &tryStep };
}
