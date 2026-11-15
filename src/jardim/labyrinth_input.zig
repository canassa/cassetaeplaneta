//! Port unit `labyrinth_input` (module) of JARDIM.EXE. LabyrinthBackdrop slot 17 handleMessage (the keys, the 55-ms tick, the shot, doors, the result 0x40a; BUGS.md J1, J6) and labyrinth_move_and_render (a step and its collisions).
//!
//! hwnd and hdc are dropped (GetDC/ReleaseDC have no counterpart). `GetKeyState(VK_SHIFT)` and
//! `GetKeyState(VK_CAPITAL)` are the task queue's synchronous key state (`Queue.keyState`: the
//! key messages it has handed out, as in Windows).
//! The map and table reads the original makes unchecked panic here when outside their arrays.

const std = @import("std");
const msg = @import("../core/msg.zig");
const Msg = msg.Msg;
const Game = @import("core/game.zig").Game;
const object = @import("core/object.zig");
const Object = object.Object;
const world = @import("core/world.zig");
const Backdrop = world.Backdrop;
const animation = @import("behaviour/animation.zig");
const position = @import("behaviour/position.zig");
const render = @import("behaviour/render.zig");
const hud = @import("hud.zig");
const labyrinth = @import("labyrinth.zig");
const raycast = @import("raycast.zig");
const sprites = @import("sprites.zig");

const vk_shift: u16 = 0x10;
const vk_control: u16 = 0x11;
const vk_capital: u16 = 0x14;
const vk_escape: u16 = 0x1b;
const vk_space: u16 = 0x20;

/// `_aFldiv`: signed 32-bit division; a zero divisor is the original's #DE.
fn aFldiv(a: i32, b: i32) i32 {
    if (b == 0) @panic("labyrinth_input: divide fault in _aFldiv (the original's #DE: a table entry of 0)");
    if (b == -1) return 0 -% a;
    return @divTrunc(a, b);
}

/// An entry of tables[`which`] (the original's pointer into it).
fn tableAt(g: *Game, which: usize, i: i32) i32 {
    const t = g.tables.trig[which];
    if (i < 0 or i >= t.len) @panic("labyrinth_input: table index out of range");
    return t[@intCast(i)];
}

fn wallAt(bd: *const Backdrop, row: i32, col: i32) i8 {
    if (row < 0 or row >= world.map_rows or col < 0 or col > world.map_cols)
        @panic("labyrinth_input: wall read outside the map");
    return bd.wallRows[@intCast(row)][@intCast(col)];
}

/// The cell a step lands on. A running step (64 units, Shift) from beside the border lands
/// outside the map, and the original reads past `wallRows` with no fault: row −1 is the far
/// pointer before it, `cscAt`, so the byte at the column's offset in tables[6] from the view
/// angle; row 80 is `objectRows[0]`, column −1 or 57 the bytes around a row. Whatever it reads,
/// the midpoint test then finds the border wall and undoes the step (BUGS.md JARDIM, harmless).
/// Row −1 is read as the original does; the others, whose bytes are far pointers or heap, as 0.
fn stepCell(g: *Game, bd: *const Backdrop, row: i32, col: i32) i8 {
    if (row >= 0 and row < world.map_rows and col >= 0 and col <= world.map_cols)
        return bd.wallRows[@intCast(row)][@intCast(col)];
    if (row != -1 or col < 0) return 0;
    const t = g.tables.trig[6];
    const i = @as(usize, bd.cscAt) + @as(usize, @intCast(col)) / 4;
    if (i >= t.len) return 0;
    const word: u32 = @bitCast(t[i]);
    return @bitCast(@as(u8, @truncate(word >> @intCast(8 * (@as(u32, @intCast(col)) % 4)))));
}

fn objectAt(bd: *Backdrop, row: i32, col: i32) *?*Object {
    if (row < 0 or row >= world.map_rows or col < 0 or col >= world.map_cols)
        @panic("labyrinth_input: object cell outside the map");
    return &bd.objectRows[@intCast(row)][@intCast(col)];
}

/// GetKeyState(vk) < 0: Shift (run) and Caps Lock held down (strafe).
fn keyHeld(g: *Game, vk: u16) bool {
    return g.queue.keyState(vk) < 0;
}

fn speed32(bd: *const Backdrop) i32 {
    const hi: u32 = @as(u16, @bitCast(bd.moveSpeed));
    const lo: u32 = @as(u16, @bitCast(bd.moveRamp));
    return @bitCast(hi << 16 | lo);
}

/// velX/velY = dividend / tables[5|6] at the angle plus `offset` entries; `negate` is the
/// tick's reverse (the quotient negated).
fn setVelocity(g: *Game, bd: *Backdrop, dividend: i32, offset: i32, negate: bool) void {
    var qx = aFldiv(dividend, tableAt(g, 5, @as(i32, bd.secAt) + offset));
    if (negate) qx = 0 -% qx;
    bd.velX = qx;
    var qy = aFldiv(dividend, tableAt(g, 6, @as(i32, bd.cscAt) + offset));
    if (negate) qy = 0 -% qy;
    bd.velY = qy;
}

fn shiftTables(bd: *Backdrop, delta: i32) void {
    const d: u16 = @bitCast(@as(i16, @truncate(delta)));
    bd.secAt +%= d;
    bd.cscAt +%= d;
}

/// A turn left: `step` 0x30 (0x60 with Shift) units, the scrolls with it.
fn turnLeft(bd: *Backdrop, step: i32) void {
    bd.viewAngle +%= step;
    if (bd.viewAngle < 0xb40) {
        shiftTables(bd, step);
    } else {
        bd.viewAngle -%= 0xb40;
        shiftTables(bd, step - 0xb40);
    }
    bd.skyScrollX +%= @intCast(-@divTrunc(step, 6));
    if (bd.skyScrollX < 0) bd.skyScrollX +%= bd.viewW;
    bd.floorScrollX +%= @intCast(-@divTrunc(step, 3));
    if (bd.floorScrollX < 0) bd.floorScrollX +%= bd.viewW;
}

fn turnRight(bd: *Backdrop, step: i32, shift: bool) void {
    bd.viewAngle -%= step;
    if (bd.viewAngle < 0) {
        bd.viewAngle +%= 0xb40;
        shiftTables(bd, 0xb40 - step);
    } else {
        shiftTables(bd, -step);
    }
    bd.skyScrollX +%= @intCast(@divTrunc(step, 6));
    if (bd.viewW <= bd.skyScrollX) bd.skyScrollX = 0;
    bd.floorScrollX +%= @intCast(@divTrunc(step, 3));
    if (bd.viewW <= bd.floorScrollX) bd.floorScrollX = if (shift) bd.floorScrollX -% bd.viewW else 0;
}

/// Strafe velocity: 90 degrees off the view angle (left: +0x2d0 entries, or -0x870 past the
/// end; right: -0x2d0, or +0x870 below 0x2d0), the speed in moveSpeed:moveRamp.
fn strafeVelocity(g: *Game, bd: *Backdrop, left: bool) void {
    const offset: i32 = if (left)
        (if (bd.viewAngle +% 0x2d0 <= 0xb40) 0x2d0 else -0x870)
    else
        (if (bd.viewAngle < 0x2d0) 0x870 else -0x2d0);
    setVelocity(g, bd, speed32(bd), offset, false);
}

fn strafeLeft(g: *Game, bd: *Backdrop) void {
    strafeVelocity(g, bd, true);
    bd.floorScrollX -%= 0x10;
    if (bd.floorScrollX < 0) bd.floorScrollX +%= bd.viewW;
    moveAndRender(g, bd, g.shotCellObject);
}

fn strafeRight(g: *Game, bd: *Backdrop) void {
    strafeVelocity(g, bd, false);
    bd.floorScrollX +%= 0x10;
    if (bd.viewW <= bd.floorScrollX) bd.floorScrollX = 0;
    moveAndRender(g, bd, g.shotCellObject);
}

/// The shot stopped: the scene's hit, the hands back to fists when the ammunition is gone.
fn shotHit(g: *Game, bd: *Backdrop, row: i32, col: i32, from_tick: bool) void {
    bd.shotInFlight = 0;
    bd.scene.?.hit(g, g.shotCellObject, @truncate(col), @truncate(row));
    if (bd.ammo == 0) {
        bd.hands.?.curStrip = 0;
        bd.hands.?.curFrame = 0;
    } else if (from_tick) {
        _ = animation.nextFrame(g, bd.hands.?);
    }
    g.shotCellObject = null;
}

fn shotCell(shot: *const Object) struct { row: i32, col: i32 } {
    return .{ .row = shot.worldY >> 5, .col = shot.worldX >> 5 };
}

/// The shot is tall enough to hit what it displaced.
fn shotHitsObject(shot: *Object, obj: *Object) bool {
    return position.hitH(shot) -% 0x14 <= position.hitH(obj);
}

fn fire(g: *Game, bd: *Backdrop) void {
    if (bd.hands.?.curStrip == 0) {
        bd.scene.?.playFireSound(g);
        bd.hands.?.curFrame = 1;
        labyrinth.renderFrame(g, bd, g.shotCellObject);
        return;
    }
    if (bd.shotInFlight != 0) return;
    bd.shotInFlight = 1;
    g.shotSec = tableAt(g, 5, bd.secAt);
    g.shotCsc = tableAt(g, 6, bd.cscAt);
    const shot = bd.shot.?;
    shot.worldX = @truncate(bd.playerX);
    shot.worldY = @truncate(bd.playerY);
    const c = shotCell(shot);
    g.shotCellObject = objectAt(bd, c.row, c.col).*;
    bd.scene.?.playFireSound(g);
    if (wallAt(bd, c.row, c.col) < 1) {
        if (g.shotCellObject) |obj| {
            if (shotHitsObject(shot, obj)) {
                shotHit(g, bd, c.row, c.col, false);
                return;
            }
        }
        objectAt(bd, c.row, c.col).* = shot;
        _ = animation.nextFrame(g, bd.hands.?);
        bd.ammo -%= 1;
        labyrinth.renderFrame(g, bd, g.shotCellObject);
    } else {
        shotHit(g, bd, c.row, c.col, false);
    }
}

/// WM_SYSTIMER part 1: the shot flies one cell.
fn shotStep(g: *Game, bd: *Backdrop) void {
    const shot = bd.shot.?;
    const old = shotCell(shot);
    objectAt(bd, old.row, old.col).* = g.shotCellObject;
    shot.worldX +%= @truncate(aFldiv(0x200000, g.shotSec));
    shot.worldY +%= @truncate(aFldiv(0x200000, g.shotCsc));
    const c = shotCell(shot);
    g.shotCellObject = objectAt(bd, c.row, c.col).*;
    if (wallAt(bd, c.row, c.col) < 1) {
        if (g.shotCellObject) |obj| {
            if (shotHitsObject(shot, obj)) {
                shotHit(g, bd, c.row, c.col, true);
                return;
            }
        }
        objectAt(bd, c.row, c.col).* = shot;
        if (g.shotCellObject) |obj| {
            obj.worldX = shot.worldX;
            obj.worldY = shot.worldY;
        }
    } else {
        shotHit(g, bd, c.row, c.col, true);
    }
}

/// WM_SYSTIMER: no arrow held, a walk coasts down (speed -4 a tick to 16), else an idle frame.
fn coast(g: *Game, bd: *Backdrop) void {
    const key = g.lastMoveKey;
    if (key != 0x26 and key != 0x28) {
        labyrinth.renderFrame(g, bd, g.shotCellObject);
        return;
    }
    if (bd.moveSpeed < 0x10 or (bd.moveSpeed < 0x11 and bd.moveRamp == 0) or g.enemyBlockedWalk) {
        g.lastMoveKey = 0x10;
        return;
    }
    bd.moveSpeed -%= 4;
    if (key == 0x26) {
        bd.floorScrollY +%= 10;
        if (bd.viewHalfH <= bd.floorScrollY) bd.floorScrollY = 0;
    } else {
        bd.floorScrollY -%= 10;
        if (bd.floorScrollY < 0) bd.floorScrollY +%= bd.viewHalfH;
    }
    setVelocity(g, bd, speed32(bd), 0, key == 0x28);
    moveAndRender(g, bd, g.shotCellObject);
}

/// WM_SYSTIMER Up/Down held: Shift runs (0x40), a repeated key speeds up (0x18), else 0x10.
fn walkHeld(g: *Game, bd: *Backdrop, forward: bool) void {
    const key: i16 = if (forward) 0x26 else 0x28;
    const sign: i16 = if (forward) 1 else -1;
    bd.moveRamp = 0;
    if (keyHeld(g, vk_shift)) {
        bd.moveSpeed = 0x40;
        bd.floorScrollY +%= sign * 0x1e;
    } else if (g.lastMoveKey == key) {
        bd.moveSpeed = 0x18;
        bd.floorScrollY +%= sign * 0xf;
    } else {
        bd.moveSpeed = 0x10;
        bd.floorScrollY +%= sign * 10;
    }
    if (forward) {
        if (bd.viewHalfH <= bd.floorScrollY) bd.floorScrollY = 0;
    } else if (bd.floorScrollY < 0) {
        bd.floorScrollY +%= bd.viewHalfH;
    }
    g.lastMoveKey = key;
    setVelocity(g, bd, speed32(bd), 0, !forward);
    moveAndRender(g, bd, g.shotCellObject);
}

/// WM_SYSTIMER with an arrow held. Returns the pending idle frame (a pure turn).
fn tickHeld(g: *Game, bd: *Backdrop) void {
    const blocked = g.fixes.jardim_enemy_blocks_walk and g.enemyBlockedWalk;
    var render_pending = false;
    if (g.keyRightDown != 0 or g.keyLeftDown != 0) {
        const right = g.keyRightDown != 0;
        bd.moveRamp = 0;
        bd.moveSpeed = 0x10;
        g.lastMoveKey = if (right) 0x27 else 0x25;
        if (keyHeld(g, vk_capital)) {
            if (blocked) {
                render_pending = true;
            } else if (right) strafeRight(g, bd) else strafeLeft(g, bd);
        } else {
            const shift = keyHeld(g, vk_shift);
            const step: i32 = if (shift) 0x60 else 0x30;
            if (right) turnRight(bd, step, shift) else turnLeft(bd, step);
            render_pending = true;
        }
    }
    if (g.keyUpDown != 0 or g.keyDownDown != 0) {
        if (blocked) {
            render_pending = true;
        } else {
            walkHeld(g, bd, g.keyUpDown != 0);
            render_pending = false;
        }
    }
    if (render_pending) labyrinth.renderFrame(g, bd, g.shotCellObject);
}

fn tick(g: *Game, bd: *Backdrop) void {
    if (bd.shotInFlight != 0) shotStep(g, bd);
    if (g.keysDownCount == 0) {
        coast(g, bd);
    } else {
        tickHeld(g, bd);
    }
}

fn keyDown(g: *Game, bd: *Backdrop, m: Msg) void {
    switch (m.wparam) {
        0x25 => {
            if (g.keyLeftDown == 0) {
                g.keyLeftDown = 1;
                g.keysDownCount +%= 1;
                if (keyHeld(g, vk_capital)) {
                    g.enemyBlockedWalk = false;
                    strafeLeft(g, bd);
                } else {
                    turnLeft(bd, 0x30);
                    labyrinth.renderFrame(g, bd, g.shotCellObject);
                }
            } else {
                g.keyAltContext = @intFromBool((@as(u32, @bitCast(m.lparam)) & 0x20000000) != 0);
            }
        },
        0x27 => {
            if (g.keyRightDown == 0) {
                g.keyRightDown = 1;
                g.keysDownCount +%= 1;
                if (keyHeld(g, vk_capital)) {
                    g.enemyBlockedWalk = false;
                    strafeRight(g, bd);
                } else {
                    turnRight(bd, 0x30, false);
                    labyrinth.renderFrame(g, bd, g.shotCellObject);
                }
            } else {
                g.keyAltContext = @intFromBool((@as(u32, @bitCast(m.lparam)) & 0x20000000) != 0);
            }
        },
        0x26 => {
            if (g.keyUpDown == 0) {
                g.enemyBlockedWalk = false;
                setVelocity(g, bd, 0x100000, 0, false);
                bd.floorScrollY +%= 10;
                if (bd.viewHalfH <= bd.floorScrollY) bd.floorScrollY = 0;
                g.keyUpDown = 1;
                g.keysDownCount +%= 1;
                moveAndRender(g, bd, g.shotCellObject);
            }
        },
        0x28 => {
            if (g.keyDownDown == 0) {
                g.enemyBlockedWalk = false;
                setVelocity(g, bd, -0x100000, 0, false);
                bd.floorScrollY -%= 10;
                if (bd.floorScrollY < 0) bd.floorScrollY +%= bd.viewHalfH;
                g.keyDownDown = 1;
                g.keysDownCount +%= 1;
                moveAndRender(g, bd, g.shotCellObject);
            }
        },
        vk_control => fire(g, bd),
        vk_space => {
            const x = (aFldiv(0x200000, tableAt(g, 5, bd.secAt)) +% bd.playerX) >> 5;
            const y = (aFldiv(0x200000, tableAt(g, 6, bd.cscAt)) +% bd.playerY) >> 5;
            const col: i32 = @as(i16, @truncate(x));
            const row: i32 = @as(i16, @truncate(y));
            if (wallAt(bd, row, col) > 8) {
                bd.wallRows[@intCast(row)][@intCast(col)] = 0;
                labyrinth.renderFrame(g, bd, g.shotCellObject);
                hud.refreshMapPanel(g, bd);
                bd.scene.?.playDoorSound(g);
            }
        },
        else => {},
    }
}

fn keyUp(g: *Game, bd: *Backdrop, m: Msg) void {
    switch (m.wparam) {
        vk_control => if (bd.hands.?.curStrip == 0) {
            bd.hands.?.curFrame = 0;
            labyrinth.renderFrame(g, bd, g.shotCellObject);
        },
        0x25 => if (g.keyLeftDown != 0) {
            g.keyLeftDown = 0;
            g.keysDownCount -%= 1;
        },
        0x26 => if (g.keyUpDown != 0) {
            g.keyUpDown = 0;
            g.keysDownCount -%= 1;
        },
        0x27 => if (g.keyRightDown != 0) {
            g.keyRightDown = 0;
            g.keysDownCount -%= 1;
        },
        0x28 => if (g.keyDownDown != 0) {
            g.keyDownDown = 0;
            g.keysDownCount -%= 1;
        },
        else => {},
    }
    g.keyAltContext = 0;
}

/// WM_DESTROY: the result to NOITE. J1: the win's bonus is 10^9 / (the tick's low word, sign
/// extended, minus the 32-bit start tick); fixed, the milliseconds played.
fn destroy(g: *Game, bd: *Backdrop, m: Msg) void {
    if (bd.lives == 0 or m.wparam != 0xffff) {
        bd.score -%= 1000;
        _ = g.plat.postTo(g.noiteWnd, .{ .id = msg.noite.minigame_result, .wparam = 0, .lparam = bd.score });
    } else {
        const now = g.plat.ticks();
        var diff: i32 = undefined;
        if (g.fixes.jardim_time_bonus) {
            diff = @max(1, @as(i32, @bitCast(now -% g.startTick)));
        } else {
            const lo: i16 = @bitCast(@as(u16, @truncate(now)));
            diff = @as(i32, lo) -% @as(i32, @bitCast(g.startTick));
        }
        const bonus = aFldiv(1000000000, diff);
        bd.score +%= @truncate(bonus);
        _ = g.plat.postTo(g.noiteWnd, .{ .id = msg.noite.minigame_result, .wparam = 1, .lparam = bd.score });
    }
}

// @orig 1028:2609 labyrinth_backdrop_handle_message
/// LabyrinthBackdropVtbl slot 17 handleMessage (labyrinth_backdrop_handle_message; hwnd dropped).
pub fn handleMessage(g: *Game, bd: *Backdrop, m: Msg) u16 {
    if (bd.active == 0) return 0;
    switch (m.id) {
        msg.wm.destroy => {
            destroy(g, bd, m);
            return 0;
        },
        msg.wm.paint => {
            labyrinth.paint(g, bd);
            return 0;
        },
        msg.wm.keydown => {
            if (m.wparam == vk_escape) {
                g.killSystemTimer(1);
                g.postQuitMessage();
                return 1;
            }
            keyDown(g, bd, m);
            return 1;
        },
        msg.wm.keyup => {
            keyUp(g, bd, m);
            return 1;
        },
        msg.wm.systimer => {
            tick(g, bd);
            return 1;
        },
        else => return 0,
    }
}

// @orig 1028:3e23 labyrinth_move_and_render
/// A step: the velocity added, a wall in the new cell pushes the player back out along the
/// axis its parity names (and resets the speed), a wall at the midpoint or still in the new
/// cell restores the old position, an object in the cell is `touch`ed (non-zero restores,
/// and health 0 costs a life, 0 lives post WM_DESTROY); then the frame, the minimap and its
/// marker, the HUD, `onLifeLost` if a life went, and the velocity cleared. The original takes
/// the HUD branch from a stack slot that is uninitialised on the wall-reject path; the port
/// always takes the numbers' branch (the slot is zero on every other path).
pub fn moveAndRender(g: *Game, bd: *Backdrop, carried: ?*Object) void {
    const lives_before = bd.lives;
    bd.moveFlag = 1;
    const old_x = bd.playerX;
    const old_y = bd.playerY;
    bd.playerX +%= bd.velX;
    bd.playerY +%= bd.velY;
    labyrinth.drawSkyFloor(g, bd);

    const cell = stepCell(g, bd, bd.playerY >> 5, bd.playerX >> 5);
    if (cell > 0 and cell & 1 == 0) {
        bd.moveRamp = 0;
        bd.moveSpeed = 0x10;
        if (bd.velX > 0) {
            bd.playerX -%= @as(i32, @as(u8, @truncate(@as(u32, @bitCast(bd.playerX)))) & 0x1f) + 8;
        } else {
            bd.playerX +%= 0x28 - @as(i32, @as(u8, @truncate(@as(u32, @bitCast(bd.playerX)))) & 0x1f);
        }
    } else if (cell & 1 != 0) {
        bd.moveRamp = 0;
        bd.moveSpeed = 0x10;
        if (bd.velY > 0) {
            bd.playerY -%= @as(i32, @as(u8, @truncate(@as(u32, @bitCast(bd.playerY)))) & 0x1f) + 8;
        } else {
            bd.playerY +%= 0x28 - @as(i32, @as(u8, @truncate(@as(u32, @bitCast(bd.playerY)))) & 0x1f);
        }
    }

    if (wallAt(bd, (bd.playerY +% old_y) >> 6, (bd.playerX +% old_x) >> 6) > 0 or
        wallAt(bd, bd.playerY >> 5, bd.playerX >> 5) > 0)
    {
        bd.playerX = old_x;
        bd.playerY = old_y;
    } else if (objectAt(bd, bd.playerY >> 5, bd.playerX >> 5).*) |obj| {
        if (bd.scene.?.touch(g, obj) != 0) {
            bd.playerX = old_x;
            bd.playerY = old_y;
            // J6: the held key's walk ends with the blocked step.
            if (g.fixes.jardim_enemy_blocks_walk) g.enemyBlockedWalk = true;
        }
        if (bd.health < 1) {
            bd.health = 100;
            bd.lives -%= 1;
        }
        if (bd.lives == 0) _ = g.post(Msg.make(msg.wm.destroy, 0, 0, 0));
    }

    raycast.renderView(g, bd, bd.playerX, bd.playerY, bd.viewAngle);
    if (carried) |obj| {
        const diff: i32 = @as(i32, obj.worldY) -% bd.playerY;
        const csc: i32 = g.tables.trig[6][bd.cscAt];
        const depth: i32 = diff *% csc;
        _ = sprites.insert(bd.spriteQueue.?, -1, -1, @truncate(bd.viewAngle), @truncate(depth >> 16), obj);
    }
    sprites.flush(g, bd.spriteQueue.?, bd);
    render.draw(g, bd.hands.?, bd);
    _ = g.plat.realizePalette(&bd.bmiColors);
    labyrinth.presentView(g, bd);
    hud.presentMinimap(g, bd);
    hud.minimapPlayer(g, bd, bd.playerX, bd.playerY);
    hud.drawHud(g, bd);
    hud.presentHud(g, bd);
    if (bd.lives != lives_before) bd.scene.?.onLifeLost(g);
    bd.velY = 0;
    bd.velX = 0;
}
