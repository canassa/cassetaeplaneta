//! Not in the original (`Fixes.jardim_smooth_movement`, a Corrigida addition): Wolfenstein
//! 3D's movement in JARDIM's labyrinth.
//!
//! The original moves the player only on WM_SYSTIMER (any timer: the 55-ms game tick and the
//! 50-ms FindWindow retry, BUGS.md J8) and on the arrows' presses, by whole steps (16 units a
//! press, 24 a tick held, 64 running; 48 angle units a turn), and draws a frame per step. Here
//! a motion timer (`timer_id`, 14 ms) polls the keys and moves the player in Wolf3D's 70-Hz
//! tics counted against the clock, so the speed depends on neither timer:
//!
//! - **Speeds** (id Software's 1995 source, WL_PLAY.C `PollKeyboardMove` and WL_AGENT.C
//!   `ControlMovement`/`Thrust`): a held key adds BASEMOVE 35 (RUNMOVE 70 with the run
//!   button) per tic; forward is ×MOVESCALE 150, backward ×BACKMOVESCALE 100, a strafe
//!   ×MOVESCALE, in 1/65536 tile; a turn is the same 35 (70) per tic / ANGLESCALE 20 degrees.
//!   So per tic: walk 5250/65536 tile, run 10500, back 3500 (7000 running), turn 1.75°
//!   (3.5°): 5.61 tiles/s walking, 11.2 running, 3.74 back, 122.5°/s turning, 245 running.
//!   Speed is set by the keys each tic: no acceleration, no coasting.
//! - **JARDIM's units:** a cell is 32 units and a turn 2880, so a tic is 168000/65536 units
//!   walking (×32), 336000 running, 112000 back (224000 running), 14 angle units turning (28).
//! - **Collision** (WL_AGENT.C `ClipMove`/`TryMove`): the player is a box of radius
//!   PLAYERSIZE = MINDIST = 0x5800 (0.34 tile: 11 units); a move into a wall or door cell is
//!   tried whole, then along x only, then along y only: the player slides along walls. The
//!   original's parity push and undone steps are not used.
//! - **Objects:** a pickup is touched when the player's centre enters its cell (as a step
//!   ends in it in the original); an enemy's cell blocks the entry and touches it (J6's fix:
//!   once per contact; without it, once per game tick while pressed into). An enemy that comes
//!   into the player's cell does not trap him.
//! - **Drawing:** a motion step that moved or turned draws a frame (`g.viewOnly`): the view,
//!   the sprites, the hands, the minimap and the HUD, but the enemies neither act nor animate
//!   and the hands do not sway; those stay on the game tick's frame (timer 1), with the shot,
//!   the doors and the exits.

const std = @import("std");
const Game = @import("core/game.zig").Game;
const world = @import("core/world.zig");
const Backdrop = world.Backdrop;
const hud = @import("hud.zig");
const labyrinth = @import("labyrinth.zig");
const labyrinth_input = @import("labyrinth_input.zig");
const enemies = @import("enemies.zig");

/// The motion timer (a system timer, as the game's).
pub const timer_id: u16 = 0x57;
pub const timer_ms: u16 = 14;

/// Wolf3D's tic rate (ID_SD.H `TickBase`) and the most tics one step runs (a long stall is
/// not caught up all at once, as `CalcTics` caps them).
pub const tic_hz: u32 = 70;
pub const max_tics: u32 = 10;

/// Per tic, in 1/65536 unit (Wolf3D's 1/65536 tile × 32).
pub const walk_speed: i64 = 35 * 150 * 32;
pub const run_speed: i64 = 70 * 150 * 32;
pub const back_speed: i64 = 35 * 100 * 32;
pub const back_run_speed: i64 = 70 * 100 * 32;
/// Per tic, in angle units (2880 a turn): 35/20 or 70/20 degrees.
pub const turn_speed: i32 = 35 * 8 / 20;
pub const run_turn_speed: i32 = 70 * 8 / 20;
/// PLAYERSIZE (0x5800 / 0x10000 tile), in units.
pub const radius: i32 = 11;

const full_turn: i32 = 2880;

const vk_shift: u16 = 0x10;
const vk_capital: u16 = 0x14;
const vk_left: u16 = 0x25;
const vk_up: u16 = 0x26;
const vk_right: u16 = 0x27;
const vk_down: u16 = 0x28;
const vk_a: u16 = 0x41;
const vk_d: u16 = 0x44;
const vk_s: u16 = 0x53;
const vk_w: u16 = 0x57;

/// Starts (or restarts, in a new phase) the motion timer and the clock it counts from.
pub fn start(g: *Game) void {
    g.setSystemTimer(timer_id, timer_ms);
    restart(g);
}

/// The tics count from now (after the controls screen, a new phase).
pub fn restart(g: *Game) void {
    g.wolf.lastMs = g.plat.ticks();
    g.wolf.ticAcc = 0;
    g.wolf.fracX = 0;
    g.wolf.fracY = 0;
}

fn held(g: *Game, vk: u16) bool {
    // The key that took the controls screen down moves nothing until released.
    if (g.controls.heldKey == vk) return false;
    return g.queue.keyState(vk) < 0;
}

/// What the keys ask for: -1, 0 or 1 each (forward, left).
pub const Input = struct {
    walk: i2 = 0,
    strafe: i2 = 0,
    turn: i2 = 0,
    run: bool = false,

    fn any(in: Input) bool {
        return in.walk != 0 or in.strafe != 0 or in.turn != 0;
    }
};

fn axis(plus: bool, minus: bool) i2 {
    return @as(i2, @intFromBool(plus)) - @as(i2, @intFromBool(minus));
}

/// W/S or Up/Down walk, A/D strafe (`jardim_wolf_keys`), Left/Right turn (strafe with Caps
/// Lock held down, as the original), Shift runs.
pub fn poll(g: *Game) Input {
    const wk = g.fixes.jardim_wolf_keys;
    const caps = held(g, vk_capital);
    const left = held(g, vk_left);
    const right = held(g, vk_right);
    const fwd = held(g, vk_up) or (wk and held(g, vk_w));
    const back = held(g, vk_down) or (wk and held(g, vk_s));
    const sl = (wk and held(g, vk_a)) or (caps and left);
    const sr = (wk and held(g, vk_d)) or (caps and right);
    return .{
        .walk = axis(fwd, back),
        .strafe = axis(sl, sr),
        .turn = if (caps) 0 else axis(left, right),
        .run = held(g, vk_shift),
    };
}

fn wrap(v: i32, m: i32) i16 {
    return @intCast(@mod(v, m));
}

/// Turns by `delta` angle units (positive: left), the tables' indexes and the scrolls with
/// it (the sky 1 px per 6 units, the floor 1 px per 3, as the original's turns).
pub fn turnBy(g: *Game, bd: *Backdrop, delta: i32) void {
    bd.viewAngle = @mod(bd.viewAngle + delta, full_turn);
    bd.secAt = @intCast(bd.viewAngle);
    bd.cscAt = @intCast(bd.viewAngle);
    g.wolf.skyAcc += delta;
    const sky = @divTrunc(g.wolf.skyAcc, 6);
    g.wolf.skyAcc -= sky * 6;
    bd.skyScrollX = wrap(@as(i32, bd.skyScrollX) - sky, bd.viewW);
    floorX(g, bd, @divTrunc(@as(i64, delta) * 0x10000, 3));
}

/// The floor's horizontal scroll: `units` (1/65536) to the left plus the remainder.
fn floorX(g: *Game, bd: *Backdrop, units: i64) void {
    g.wolf.floorXAcc += @intCast(units);
    const px = @divTrunc(g.wolf.floorXAcc, 0x10000);
    g.wolf.floorXAcc -= px * 0x10000;
    bd.floorScrollX = wrap(@as(i32, bd.floorScrollX) - px, bd.viewW);
}

/// The floor's forward scroll: 10 px per 16 units, as a walk press.
fn floorY(g: *Game, bd: *Backdrop, units: i64) void {
    g.wolf.floorYAcc += @intCast(@divTrunc(units * 5, 8));
    const px = @divTrunc(g.wolf.floorYAcc, 0x10000);
    g.wolf.floorYAcc -= px * 0x10000;
    bd.floorScrollY = wrap(@as(i32, bd.floorScrollY) + px, bd.viewHalfH);
}

/// A wall or door (or the outside) under the player's box at (x, y) (`TryMove`).
pub fn blocked(bd: *const Backdrop, x: i32, y: i32) bool {
    return within(bd, x, y, radius);
}

/// A wall or door (or the outside) less than `r` + 1 units from (x, y) along an axis.
pub fn within(bd: *const Backdrop, x: i32, y: i32, r: i32) bool {
    var row = (y - r) >> 5;
    while (row <= (y + r) >> 5) : (row += 1) {
        var col = (x - r) >> 5;
        while (col <= (x + r) >> 5) : (col += 1) {
            if (row < 0 or row >= world.map_rows or col < 0 or col >= world.map_cols) return true;
            if (bd.wallRows[@intCast(row)][@intCast(col)] > 0) return true;
        }
    }
    return false;
}

fn posX(g: *Game, bd: *const Backdrop) i64 {
    return @as(i64, bd.playerX) * 0x10000 + g.wolf.fracX;
}

fn posY(g: *Game, bd: *const Backdrop) i64 {
    return @as(i64, bd.playerY) * 0x10000 + g.wolf.fracY;
}

fn setPos(g: *Game, bd: *Backdrop, x: i64, y: i64) void {
    bd.playerX = @intCast(x >> 16);
    bd.playerY = @intCast(y >> 16);
    g.wolf.fracX = @intCast(x & 0xffff);
    g.wolf.fracY = @intCast(y & 0xffff);
}

/// `ClipMove`: the whole move, else x only, else y only, else none. True if the player moved.
pub fn clipMove(g: *Game, bd: *Backdrop, dx: i64, dy: i64) bool {
    const x = posX(g, bd);
    const y = posY(g, bd);
    const tries = [_][2]i64{ .{ dx, dy }, .{ dx, 0 }, .{ 0, dy } };
    for (tries) |t| {
        if (t[0] == 0 and t[1] == 0) continue;
        const nx = x + t[0];
        const ny = y + t[1];
        if (!blocked(bd, @intCast(nx >> 16), @intCast(ny >> 16))) {
            setPos(g, bd, nx, ny);
            return true;
        }
    }
    return false;
}

/// `Thrust`: `speed` (1/65536 unit) along `angle` (0..2879), from the tables' 1/cos and
/// 1/sin (16.16), as the original's velocity.
pub fn thrust(g: *Game, bd: *Backdrop, angle: i32, speed: i64) bool {
    const a: usize = @intCast(@mod(angle, full_turn));
    const dx = @divTrunc(speed * 0x10000, g.tables.trig[5][a]);
    const dy = @divTrunc(speed * 0x10000, g.tables.trig[6][a]);
    return clipMove(g, bd, dx, dy);
}

fn cellOf(v: i32) i32 {
    return v >> 5;
}

/// The objects at the end of a tic's move from (`old_x`, `old_y`): a pickup touched on
/// entering its cell, an enemy's cell entered undoes the move and touches it.
fn touchObjects(g: *Game, bd: *Backdrop, old_x: i64, old_y: i64) void {
    const row = cellOf(bd.playerY);
    const col = cellOf(bd.playerX);
    if (row < 0 or row >= world.map_rows or col < 0 or col >= world.map_cols) return;
    const obj = bd.objectRows[@intCast(row)][@intCast(col)] orelse return;
    const entering = row != cellOf(@intCast(old_y >> 16)) or col != cellOf(@intCast(old_x >> 16));
    if (obj.isEnemy != 0) {
        var touch = true;
        if (!g.fixes.jardim_enemy_once_per_contact) {
            // Without J6's fix, pressing into it hurts once a game tick, as a held key.
            touch = g.wolf.touchedTick != g.wolf.gameTick;
            if (touch) g.wolf.touchedTick = g.wolf.gameTick;
        }
        if (touch) _ = labyrinth_input.touchObject(g, bd, obj);
        if (entering) setPos(g, bd, old_x, old_y);
        labyrinth_input.lifeCheck(g, bd);
    } else if (entering) {
        _ = labyrinth_input.touchObject(g, bd, obj);
        labyrinth_input.lifeCheck(g, bd);
    }
}

/// One tic (`ControlMovement`): the turn, the strafe, the walk. True if anything moved.
pub fn tic(g: *Game, bd: *Backdrop, in: Input) bool {
    var moved = false;
    if (in.turn != 0) {
        turnBy(g, bd, @as(i32, in.turn) * (if (in.run) run_turn_speed else turn_speed));
        moved = true;
    }
    const old_x = posX(g, bd);
    const old_y = posY(g, bd);
    if (in.strafe != 0) {
        const speed: i64 = if (in.run) run_speed else walk_speed;
        if (thrust(g, bd, bd.viewAngle + @as(i32, in.strafe) * 720, speed)) {
            floorX(g, bd, @as(i64, in.strafe) * speed);
        }
    }
    if (in.walk != 0) {
        const speed: i64 = if (in.walk > 0)
            (if (in.run) run_speed else walk_speed)
        else
            (if (in.run) back_run_speed else back_speed);
        const angle = if (in.walk > 0) bd.viewAngle else bd.viewAngle + 1440;
        if (thrust(g, bd, angle, speed)) floorY(g, bd, @as(i64, in.walk) * speed);
    }
    if (posX(g, bd) != old_x or posY(g, bd) != old_y) {
        touchObjects(g, bd, old_x, old_y);
        moved = true;
    }
    labyrinth_input.leaveContact(g, bd);
    return moved;
}

/// The motion timer's WM_SYSTIMER: the tics since the last one, then a frame if the player
/// moved or turned.
pub fn motion(g: *Game, bd: *Backdrop) void {
    const now = g.plat.ticks();
    const dt = @min(now -% g.wolf.lastMs, 1000);
    g.wolf.lastMs = now;
    g.wolf.ticAcc += dt * tic_hz;
    var tics = g.wolf.ticAcc / 1000;
    g.wolf.ticAcc %= 1000;
    if (tics > max_tics) tics = max_tics;
    const in = poll(g);
    if (!in.any()) return;
    const lives_before = bd.lives;
    const health_before = bd.health;
    var moved = false;
    var i: u32 = 0;
    while (i < tics) : (i += 1) {
        if (tic(g, bd, in)) moved = true;
    }
    // A blocked touch moves nothing but may cost health or a life: the HUD and the scream.
    if (moved or bd.lives != lives_before or bd.health != health_before) frame(g, bd, lives_before);
}

/// A motion frame: the original's frame (`labyrinth.renderFrame`) with `g.viewOnly`, the
/// minimap and its marker as after a step, and the scream if a touch cost a life.
fn frame(g: *Game, bd: *Backdrop, lives_before: i16) void {
    g.viewOnly = true;
    // The planner's probe build skips the motion frames' drawing (`enemies.probe`).
    if (!enemies.probe) labyrinth.renderFrame(g, bd, g.shotCellObject);
    g.viewOnly = false;
    hud.presentMinimap(g, bd);
    hud.minimapPlayer(g, bd, bd.playerX, bd.playerY);
    if (bd.lives != lives_before) bd.scene.?.onLifeLost(g);
}

// ---- tests ----

const testing = std.testing;

test "Wolf3D's speeds in JARDIM's units" {
    // 5.61 tiles a second walking, 11.2 running, 122.5 degrees a second turning.
    const walk_cells_s = @as(f64, @floatFromInt(walk_speed)) / 65536.0 / 32.0 * 70.0;
    try testing.expectApproxEqAbs(@as(f64, 5.607), walk_cells_s, 0.001);
    try testing.expectEqual(@as(i64, 2) * walk_speed, run_speed);
    try testing.expectEqual(@as(i32, 14), turn_speed);
    try testing.expectEqual(@as(i32, 28), run_turn_speed);
    try testing.expectEqual(@as(f64, 122.5), @as(f64, @floatFromInt(turn_speed)) / 8.0 * 70.0);
}

test "the box slides along a wall" {
    var bd: Backdrop = .{};
    // A wall along row 2; the player in row 1, 3 units below its face.
    for (0..world.map_cols) |c| bd.wallRows[2][c] = 1;
    try testing.expect(!blocked(&bd, 100, 64 - radius - 1));
    try testing.expect(blocked(&bd, 100, 64 - radius));
    try testing.expect(blocked(&bd, 0, 48));
}
