//! Port unit `invaders` (module) of INV.EXE. the formation: the 4 invader columns and the explosion (creation, start right), InvaderVtbl step, the turn, lowestAlive, the explosion's start.
//!
//! Each function carries `// @orig <seg:xxxx> <name>` with the INV address.
//! The hwnd parameters are dropped.

const std = @import("std");
const msg = @import("../core/msg.zig");
const Game = @import("core/game.zig").Game;
const object = @import("core/object.zig");
const Object = object.Object;
const world = @import("core/world.zig");
const Backdrop = world.Backdrop;
const object_create = @import("object_create.zig");
const animation = @import("behaviour/animation.zig");
const movement = @import("behaviour/movement.zig");
const occupancy = @import("behaviour/occupancy.zig");
const position = @import("behaviour/position.zig");

pub const Error = object_create.Error;

// @orig 1068:0146 invader_column_start_right
/// Starts the column heading right (`moveToEdgeH` 2), which arms timer 0xf.
pub fn startRight(g: *Game, bd: *Backdrop, column: *Object) void {
    movement.moveToEdgeH(g, column, bd, 2);
}

// @orig 1068:016e inv_create_invader_columns
/// Four InvaderColumns (kind `invader_column`) from the column strip tables:
/// timer 0xf (the same id for all four, 500 ms), steps 20 x 20, hit box 88 x
/// 217, y 60, x 40 + 108 i. Then for each: attach, cells live (the ctor's
/// init, repeated), `hitState` 0, `lowestAlive`, head right. A failed
/// allocation is a null column in the original, which then crashes.
pub fn createInvaderColumns(g: *Game, bd: *Backdrop) Error!void {
    var i: i16 = 0;
    while (i < 4) : (i += 1) {
        const c = g.local().create(Object) catch return error.OutOfMemory;
        c.* = .{ .kind = .invader_column };
        try object_create.invaderColumnCtor(
            g,
            c,
            i *% 0x6c +% 0x28,
            0x3c,
            1,
            &g.columnStripFiles,
            &g.columnStripFrames,
            &g.columnStripWidths,
            &g.columnStripHeights,
            0,
            0,
            g.columnStripWidths[0],
            g.columnStripHeights[0],
            0xf,
            500,
            0x14,
            0x14,
            1,
            0,
            true,
        );
        g.invaderColumns[@intCast(i)] = c;
    }
    i = 0;
    while (i < 4) : (i += 1) {
        const c = g.invaderColumns[@intCast(i)].?;
        _ = occupancy.attach(g, c, bd);
        object_create.invaderColumnInitCells(c);
        c.invader.hitState = 0;
        _ = updateLowestAlive(c);
        startRight(g, bd, c);
    }
}

// @orig 1068:028b inv_create_invader_explosion
/// The InvaderExplosion (kind `invader_explosion`): hidden, timer 0x10 at
/// 55 ms, steps 20 x 20, hit box 88 x 44 (one strip of 8 frames), parked at
/// (640, 480); attached.
pub fn createInvaderExplosion(g: *Game, bd: *Backdrop) Error!void {
    const e = g.local().create(Object) catch return error.OutOfMemory;
    e.* = .{ .kind = .invader_explosion };
    try object_create.invaderExplosionCtor(
        g,
        e,
        0x280,
        0x1e0,
        1,
        &g.explosionStripFiles,
        &g.explosionStripFrames,
        &g.explosionStripWidths,
        &g.explosionStripHeights,
        0,
        0,
        g.explosionStripWidths[0],
        0x2c,
        0x10,
        0x37,
        0x14,
        0x14,
        0,
        0,
        true,
    );
    g.invaderExplosion = e;
    _ = occupancy.attach(g, e, bd);
}

// @orig 1068:1521 invader_column_update_lowest_alive
/// `lowestAlive` = the highest live cell index, -1 when none; returns it.
pub fn updateLowestAlive(column: *Object) i16 {
    const inv = &column.invader;
    inv.lowestAlive = -1;
    var i: i16 = 0;
    while (i < 5) : (i += 1) {
        if (inv.cells[@intCast(i)].alive != 0 and inv.lowestAlive < i) inv.lowestAlive = i;
    }
    return inv.lowestAlive;
}

// @orig 1068:157b invader_column_turn
/// Turns a column with the formation (the handler calls it on the other live
/// columns when the leader reached an edge): stop (the right-edge descent
/// happens there), reverse the direction and, unless an invader landed, head
/// the new way; one formation `step`; `atEdge` and `firstPass` 0.
pub fn turn(g: *Game, column: *Object, bd: *Backdrop) void {
    const inv = &column.invader;
    if (inv.lowestAlive == -1) return;
    movement.stopMoving(g, column, bd);
    if (inv.direction == 2) {
        inv.direction = 1;
        if (g.invadersLanded == 0) movement.moveToEdgeH(g, column, bd, 1);
    } else {
        inv.direction = 2;
        if (g.invadersLanded == 0) movement.moveToEdgeH(g, column, bd, 2);
    }
    step(g, column, bd);
    inv.atEdge = 0;
    inv.firstPass = 0;
}

// @orig 1068:181f invader_column_step
/// InvaderVtbl slot 01 step (hwnd dropped; the InvaderExplosion shares it):
/// the edge tests, then one formation step.
pub fn step(g: *Game, obj: *Object, bd: *Backdrop) void {
    const inv = &obj.invader;
    const w = position.width(obj);
    if (@divTrunc(w, 2) < obj.x and inv.atEdge == 0) {
        const right_limit = w *% 2 -% bd.bgWidth;
        if (0 -% obj.x == right_limit or 0 -% right_limit < obj.x or inv.atEdge != 0) {
            inv.firstPass = 0;
            inv.atEdge = 1;
            movement.stopMoving(g, obj, bd);
            inv.direction = 1;
            if ((inv.lowestAlive +% 1) *% 0x2c +% obj.y < 0x186) {
                movement.moveToEdgeH(g, obj, bd, 1);
            } else {
                inv.landed = 1;
                g.invadersLanded = 1;
                obj.mover.moving = 0;
                _ = g.send(.{ .id = msg.wm.destroy });
            }
        }
    } else if (inv.firstPass == 0) {
        for (&inv.cells) |*c| c.x = obj.x;
        movement.stopMoving(g, obj, bd);
        obj.curStrip = 0;
        inv.atEdge = 1;
        inv.direction = 2;
        if (inv.lowestAlive != -1) movement.moveToEdgeH(g, obj, bd, 2);
    }
    movement.moveTick(g, obj, bd);
}

// @orig 1068:1c30 invader_explosion_start
/// The handler has put the explosion on the killed cell: strip 0, frame 0
/// (the original reaches them through the SceneObject offset),
/// `frameCounter` 1, loops the animation (timer 0x10) and ticks once. Uses
/// `g_invaderExplosion` and ignores its `this` parameter, so it takes none.
pub fn explosionStart(g: *Game, bd: *Backdrop) void {
    const e = g.invaderExplosion.?;
    e.curStrip = 0;
    e.curFrame = 0;
    e.invader.frameCounter = 1;
    animation.play(g, e, bd);
    animation.tick(g, e, bd);
}
