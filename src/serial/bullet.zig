//! Port unit `bullet` (module) of SERIAL.EXE. the gun's aim and the bullet: creation, ProjectileVtbl stepMove/tryStep (the first hit stage), the shot wave.
//!
//! Virtual-slot dispatchers owned by this unit keep their signatures
//! (docs/serial/DESIGN.md "Virtual slots"); hwnd/hdc parameters are dropped
//! (the DC is the platform screen).

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

// @orig 1068:03d5 serial_create_bullets
/// Builds the one bullet (`g_bullets[0]`; the loop runs `i < 1`): `Bullet`
/// at x 0, y 0x17c, 1 strip (bala.bmp, 3 frames of 47 x 31), hit box 0,0 and
/// strip 0's width x height, timer 0xc at 55 ms, step 20 x 20, not visible.
/// Then attach, `curStrip` = 0 (the aim picks the frame) and
/// `Projectile.unk46` = -1. A failed allocation stores NULL in the original
/// and dereferences it next; here it is the error.
pub fn createBullets(g: *Game, bd: *Backdrop) object_create.Error!void {
    var i: usize = 0;
    while (i < 1) : (i += 1) {
        const bullet = g.local().create(Object) catch {
            g.bullets[i] = null;
            return error.OutOfMemory;
        };
        bullet.* = .{ .kind = .bullet };
        try object_create.bulletCtor(g, bullet, 0, 0x17c, 1, &g.bulletStripFiles, &g.bulletStripFrames, &g.bulletStripWidths, &g.bulletStripHeights, 0, 0, g.bulletStripWidths[0], g.bulletStripHeights[0], 0xc, 0x37, 20, 20, 0, 0, true);
        g.bullets[i] = bullet;
        _ = occupancy.attach(g, bullet, bd);
        bullet.curStrip = 0;
        bullet.projectile.unk46 = -1;
    }
}

// @orig 1068:04c1 gun_aim
/// Steps the gun's aim (`curFrame`) with wrap-around: 'D' (right)
/// 0 -> 1 -> 2 -> 0, 'E' (left) 0 -> 2, 1 -> 0, 2 -> 1; any other key, or an
/// aim outside 0..2, changes nothing. The `gun` parameter is unused (the
/// original works on `g_gun`, which must exist).
pub fn aim(g: *Game, key: i16) void {
    const gun = g.gun.?;
    const k: u8 = @truncate(@as(u16, @bitCast(key)));
    if (k == 'D') {
        switch (gun.curFrame) {
            0 => gun.curFrame = 1,
            1 => gun.curFrame = 2,
            2 => gun.curFrame = 0,
            else => {},
        }
    } else if (k == 'E') {
        switch (gun.curFrame) {
            0 => gun.curFrame = 2,
            1 => gun.curFrame = 0,
            2 => gun.curFrame = 1,
            else => {},
        }
    }
}

// @orig 1068:478c serial_play_shot_wave
/// `wave_play(0, g_shotWave)`.
pub fn playShotWave(g: *Game) void {
    _ = sound.play(g, 0, g.shotWave);
}

fn abs16(v: i16) i16 {
    return if (v < 0) 0 -% v else v;
}

/// ProjectileVtbl slot 02 stepMove (hwnd and hdc dropped): while moving, one
/// Bresenham step and `tryStep`; blocked -> stop (the bullet vanishes),
/// `moving` = 0 and hideAndInvalidate; else place at the next position,
/// redraw the overlapping objects, queue the repaint (`invalidate`; TIRO
/// blitted to the DC here), and stop at the destination. `dir` is the
/// original's `int *outDir` (3 = a hit, BUGS.md K3).
// @orig 1068:13d7 projectile_step_move
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
        visibility.invalidate(g, obj);
        if (movement.moverAtTarget(obj)) {
            movement.stopMovingDc(g, obj, bd);
            obj.mover.moving = 0;
        }
    }
}

/// ProjectileVtbl slot 03 tryStep: the occupancy query of the next rect
/// (`canStep`, which leaves the blocker in `linked`). Free: 1. Blocked with
/// no blocker (wall cell, or the grid's edge): 0. A blocker that is not a
/// Target (`isTarget`): 0 (`linked` is kept; TIRO clears it). A Target: when
/// `|blocker.y - nextY| <= height / 2` of the blocker, `dir.*` = 3; 1
/// either way.
// @orig 1068:12a5 projectile_try_step
pub fn tryStep(g: *Game, obj: *Object, bd: *Backdrop, dir: *i16) i16 {
    if (occupancy.canStep(g, obj, bd)) return 1;
    const blocker = obj.linked orelse return 0;
    if (!blocker.is(.target)) return 0;
    const half = @divTrunc(position.height(blocker), 2);
    if (abs16(blocker.y -% obj.nextY) <= half) dir.* = 3;
    return 1;
}

test "analyze all" {
    _ = .{ &createBullets, &aim, &playShotWave, &stepMove, &tryStep };
}
