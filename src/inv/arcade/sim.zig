//! Not in the original (`Fixes.inv_arcade_rules`): the rules of Taito's 1978 Space Invaders on INV's
//! screen and art (docs/inv/ARCADE.md has every number and where it comes from).
//!
//! `Sim` is the whole game and knows nothing of the Game, the window or the art but their sizes: one
//! `frame` is a 60th of a second of the arcade. `driver.zig` runs it by the clock, `glue.zig` ties it
//! to INV's score, sounds and result, `view.zig` draws it, `bot.zig` plays it.
//!
//! What is the arcade's: the rack's march (one invader per frame, so the whole rack speeds up as
//! invaders die; two pictures; a drop at each wall; the last invader very fast), the player's one
//! shot at a time, the three kinds of bomb (the aimed "rolling" one and the "plunger" and
//! "squiggly" ones, which fall from the columns of the arcade's tables) with the reload rule that
//! sets how many are on screen, the saucer's timer and its mystery score, the shot count that
//! decides it, the bunkers, the pause of a kill and of a death, the invasion line. What is ours: the
//! geometry (the art is 88 px wide invaders on a 640 px screen: four columns, not eleven), the
//! speeds (the arcade's, per screen crossed), the scale of the score (x10).

const std = @import("std");
const bunker = @import("bunker.zig");
const Bunker = bunker.Bunker;

pub const fps = 60;

// ---- the screen and the sprites (INV's art) ----

pub const screen_w = 640;
pub const screen_h = 480;
/// Positions that move smoothly are 24.8 fixed point.
pub const fix = 256;

/// The rack: four columns by five rows, as the original's; row 0 is the bottom row.
pub const cols = 4;
pub const rows = 5;
pub const n_inv = cols * rows;
/// An invader's cell in the art (`MOVEIN.BMP` is a column of them) and its drawn size.
pub const inv_w = 88;
pub const inv_h = 34;
/// The invader's visible part inside the cell (for the walls and the hits).
pub const inv_vis_l = 3;
pub const inv_vis_r = 85;
pub const pitch_x = 108;
pub const pitch_y = 38;
/// Where the rack starts: its bottom left invader's top left.
pub const rack_x0 = 114;
pub const rack_top0 = 42;
pub const rack_y0 = rack_top0 + (rows - 1) * pitch_y;
/// The walls the rack turns at (they touch the visible part), the drop at each turn (half a row, as
/// the arcade's 8 of 16), the step of a march (2 arcade pixels), and the lone invader's.
pub const wall_l = 6;
pub const wall_r = screen_w - 6;
pub const drop_px = 16;
pub const march_dx = 6;
pub const march_dx_last = 9;
/// The invasion line: the cannon's top. An invader placed with its bottom on it has landed.
pub const land_y = 380;

pub const cannon_w = 65;
pub const cannon_h = 67;
pub const cannon_y = 380;
pub const cannon_min_x = 24;
pub const cannon_max_x = 551;

pub const shot_w = 12;
pub const shot_h = 22;
pub const bomb_w = 12;
pub const bomb_h = 22;
pub const saucer_w = 61;
pub const saucer_h = 32;
pub const saucer_y = 6;
pub const saucer_min_x = 8;
pub const saucer_max_x = screen_w - 8 - saucer_w;
pub const ground_y = 452;

pub const bunker_xs = [4]i32{ 95, 223, 351, 479 };
pub const bunker_y = 312;

// ---- speeds: the arcade's, per screen crossed (docs/inv/ARCADE.md "Speeds") ----

/// px per frame x 256.
pub const player_speed = 3 * fix;
pub const shot_speed = 7 * fix;
/// 4 arcade px per 3 frames (5 with few invaders left) on a screen 1.76 times as tall.
pub const bomb_speed = 597;
pub const bomb_speed_fast = 746;
/// Invaders left (of 20) at which the bombs speed up: the arcade's 8 of 55.
pub const bomb_fast_below = 4;
pub const saucer_speed = 488;

// ---- times, in frames ----

pub const death_frames = 60;
/// After a death, and at the start, the invaders do not fire for 0x30 frames.
pub const fire_pause = 48;
pub const invader_burst = 16;
pub const shot_burst_frames = 10;
pub const bomb_burst_frames = 9;
pub const saucer_burst = 32;
/// The saucer's score shows (and counts) this many frames into the burst.
pub const saucer_score_at = 8;
pub const saucer_period = 0x300;
pub const win_hold = 30;
/// The saucer does not come with fewer invaders than this (the arcade's 8 of 55).
pub const saucer_min_alive = 3;

/// Arcade points of a hit, by row; INV's score is ten times them.
pub const score_scale = 10;
/// A bomb that hits the cannon costs this much of INV's score (the original's -500).
pub const hit_penalty = 500;
/// The saucer's mystery score by the shot count mod 15 (`SaucerScrTab` 1D54, x10: the arcade's
/// table is 16 long and wraps at 15, which is the famous bug).
pub const saucer_scores = [15]u16{ 100, 50, 50, 100, 150, 100, 100, 50, 300, 100, 100, 100, 50, 150, 100 };

/// The columns the plunger and the squiggly shots fall from, by the arcade's table (`ColFireTable`
/// 1D00, the 11 columns of the arcade) and our column of each.
const col_fire = [21]u8{ 1, 7, 1, 1, 1, 4, 11, 1, 6, 3, 1, 1, 11, 9, 2, 8, 2, 11, 4, 7, 10 };
const plunger_first = 0;
const plunger_end = 16;
const squiggly_first = 6;
const squiggly_end = 21;

fn ourColumn(arcade_col: u8) u8 {
    return @intCast(@as(u32, arcade_col - 1) * cols / 11);
}

/// How many arcade steps (3 frames) another bomb must have taken before a new one may fall, by the
/// arcade points (`AShotReloadRate`: 30, 10, 0B, 08, 07 hex by score; the score steps are the
/// arcade's 299, 1099, 2099 and 3099 scaled by 20 / 55, our wave being 20 invaders).
pub fn reloadRate(points: u32) u16 {
    if (points <= 108) return 0x30;
    if (points <= 399) return 0x10;
    if (points <= 763) return 0x0b;
    if (points <= 1127) return 0x08;
    return 0x07;
}

pub const BombKind = enum(u2) { rolling, plunger, squiggly };

pub const Invader = struct {
    alive: bool = true,
    /// Top left of its cell, as last placed by the march.
    x: i32 = 0,
    y: i32 = 0,
    frame: u1 = 0,
};

pub const Bomb = struct {
    state: enum { idle, fall, blow } = .idle,
    /// Top left of its art; `y` is 24.8.
    x: i32 = 0,
    y: i32 = 0,
    /// Steps taken (a step is 3 frames): the arcade's reload rule counts them.
    steps: u16 = 0,
    /// Frames since it fell (its animation).
    age: u32 = 0,
    blow: u8 = 0,
    /// Where it burst (the centre of its bottom edge).
    bx: i32 = 0,
    by: i32 = 0,
};

pub const Shot = struct {
    state: enum { none, fly, blow, wait_alien } = .none,
    x: i32 = 0,
    y: i32 = 0,
    t: u8 = 0,
    /// Where it burst (the centre of its top).
    bx: i32 = 0,
    by: i32 = 0,
};

pub const Saucer = struct {
    state: enum { none, fly, hit } = .none,
    x: i32 = 0,
    dir: i32 = 1,
    t: u8 = 0,
    /// The score of the hit, in INV's points, once it is known (0 before).
    shown: u16 = 0,
};

pub const Mode = enum { play, dying, won_hold, over };

/// What the player does this frame.
pub const Input = struct {
    /// -1 left, 0, 1 right.
    dir: i2 = 0,
    /// The fire button is down (a tap between two frames counts).
    fire: bool = false,
};

/// What happened in a frame (for the sounds, the score and the end).
pub const Events = struct {
    fired: bool = false,
    invader_hit: bool = false,
    saucer_launch: bool = false,
    saucer_hit: bool = false,
    cannon_hit: bool = false,
    bomb_shot: bool = false,
    march: bool = false,
    descend: bool = false,
    landed: bool = false,
    respawn: bool = false,
    /// The score to add (INV's points, signed).
    score: i32 = 0,
    won: bool = false,
    lost: bool = false,
};

/// The cannon's extent of each row of its art (`CANHAO.BMP`: the first and last opaque pixel; hi < lo
/// is a blank row): a bomb passes beside the barrel. Measured from the picture (a test in `glue.zig`
/// checks it against the disc's), so the bot and the game agree without the art.
const cannon_art = [cannon_h][2]i16{
    .{ 0, -1 },  .{ 28, 37 }, .{ 27, 38 }, .{ 26, 39 }, .{ 26, 39 }, .{ 26, 39 }, .{ 25, 39 }, .{ 25, 40 },
    .{ 25, 40 }, .{ 25, 40 }, .{ 24, 40 }, .{ 24, 41 }, .{ 24, 41 }, .{ 24, 41 }, .{ 24, 41 }, .{ 24, 41 },
    .{ 25, 41 }, .{ 26, 40 }, .{ 27, 38 }, .{ 27, 38 }, .{ 27, 38 }, .{ 27, 38 }, .{ 27, 38 }, .{ 27, 38 },
    .{ 27, 38 }, .{ 27, 38 }, .{ 27, 38 }, .{ 27, 38 }, .{ 27, 38 }, .{ 27, 38 }, .{ 27, 38 }, .{ 27, 38 },
    .{ 17, 45 }, .{ 17, 46 }, .{ 17, 46 }, .{ 11, 53 }, .{ 10, 54 }, .{ 10, 54 }, .{ 10, 54 }, .{ 10, 54 },
    .{ 10, 54 }, .{ 10, 54 }, .{ 10, 54 }, .{ 10, 54 }, .{ 10, 54 }, .{ 10, 54 }, .{ 10, 55 }, .{ 9, 56 },
    .{ 8, 57 },  .{ 7, 58 },  .{ 6, 58 },  .{ 6, 59 },  .{ 5, 59 },  .{ 5, 59 },  .{ 5, 60 },  .{ 4, 60 },
    .{ 4, 61 },  .{ 4, 61 },  .{ 3, 61 },  .{ 3, 62 },  .{ 3, 62 },  .{ 2, 62 },  .{ 2, 63 },  .{ 2, 63 },
    .{ 1, 63 },  .{ 1, 41 },  .{ 0, -1 },
};

pub const CannonRow = struct { lo: i16, hi: i16 };

fn cannonRows() [cannon_h]CannonRow {
    var r: [cannon_h]CannonRow = undefined;
    for (&r, cannon_art) |*row, a| row.* = .{ .lo = a[0], .hi = a[1] };
    return r;
}

const Prev = struct {
    cx: i32 = 0,
    shot_y: i32 = 0,
    bomb_y: [3]i32 = @splat(0),
    saucer_x: i32 = 0,
};

pub const Sim = struct {
    t: u32 = 0,
    mode: Mode = .play,
    hold: u8 = 0,

    // the cannon
    cx: i32 = cannon_min_x * fix,
    lives: u8 = 3,
    death_t: u32 = 0,
    landed: bool = false,
    fire_bounce: bool = false,
    cannon_rows: [cannon_h]CannonRow = cannonRows(),

    shot: Shot = .{},
    /// Player shots that have ended (the arcade's saucer score and direction read it).
    shot_count: u32 = 0,

    // the rack
    inv: [n_inv]Invader = @splat(.{}),
    alive: u8 = n_inv,
    rack_x: i32 = rack_x0,
    rack_y: i32 = rack_y0,
    rack_dx: i32 = march_dx,
    /// 1 right, -1 left.
    dir: i32 = 1,
    pending_drop: i32 = 0,
    rack_frame: u1 = 0,
    cursor: usize = 0,
    /// The killed invader's burst: where and how many frames are left (the march waits meanwhile).
    burst_x: i32 = 0,
    burst_y: i32 = 0,
    burst_t: u8 = 0,
    /// The deepest the rack has been (a descent below it plays a sound).
    drops: u8 = 0,

    // the bombs
    bombs: [3]Bomb = @splat(.{}),
    roll_skip: bool = true,
    plunger_idx: u8 = plunger_first,
    squiggly_idx: u8 = squiggly_first,
    fire_delay: u8 = fire_pause,

    // the saucer
    saucer: Saucer = .{},
    saucer_timer: u16 = saucer_period,
    saucer_pending: bool = false,
    saucer_idx: u8 = 0,
    /// The next saucer goes left to right.
    saucer_ltr: bool = true,

    /// Arcade points scored (INV's score is `score_scale` times them, less the penalties).
    points: u32 = 0,
    bunkers: [4]Bunker = undefined,
    prev: Prev = .{},

    pub fn init() Sim {
        var s: Sim = .{};
        for (&s.bunkers, bunker_xs) |*b, x| b.* = Bunker.init(x, bunker_y);
        s.placeAll();
        s.prev = .{ .cx = s.cx, .saucer_x = 0 };
        return s;
    }

    pub fn cannonX(s: *const Sim) i32 {
        return s.cx >> 8;
    }

    /// Every invader at its place in the rack (the start).
    fn placeAll(s: *Sim) void {
        for (0..n_inv) |i| {
            const col: i32 = @intCast(i % cols);
            const row: i32 = @intCast(i / cols);
            s.inv[i].x = s.rack_x + col * pitch_x;
            s.inv[i].y = s.rack_y - row * pitch_y;
        }
    }

    pub fn rowOf(i: usize) usize {
        return i / cols;
    }

    fn snapshot(s: *Sim) void {
        s.prev.cx = s.cx;
        s.prev.shot_y = s.shot.y;
        for (s.bombs, 0..) |b, i| s.prev.bomb_y[i] = b.y;
        s.prev.saucer_x = s.saucer.x;
    }

    /// One 60th of a second.
    pub fn frame(s: *Sim, in: Input, ev: *Events) void {
        s.t +%= 1;
        s.snapshot();
        switch (s.mode) {
            .play => s.playFrame(in, ev),
            .dying => s.dyingFrame(ev),
            .won_hold => {
                s.hold -= 1;
                if (s.hold == 0) {
                    s.mode = .over;
                    ev.won = true;
                }
            },
            .over => {},
        }
    }

    fn playFrame(s: *Sim, in: Input, ev: *Events) void {
        if (s.fire_delay > 0) s.fire_delay -= 1;
        s.movePlayer(in.dir);
        s.fireLogic(in.fire, ev);
        s.updateShot(ev);
        s.updateBombs(ev);
        if (s.mode != .play) return;
        s.updateSaucer(ev);
        s.updateRack(ev);
        if (s.mode != .play) return;
        if (s.alive == 0 and s.burst_t == 0) {
            s.mode = .won_hold;
            s.hold = win_hold;
        }
    }

    // ---- the cannon ----

    fn movePlayer(s: *Sim, dir: i2) void {
        s.cx += @as(i32, dir) * player_speed;
        s.cx = std.math.clamp(s.cx, cannon_min_x * fix, cannon_max_x * fix);
    }

    fn fireLogic(s: *Sim, held: bool, ev: *Events) void {
        if (s.shot.state != .none) return;
        // The arcade's fire bounce: a button still down when the last shot ends does not fire again.
        if (s.fire_bounce) {
            if (!held) s.fire_bounce = false;
            return;
        }
        if (!held) return;
        s.fire_bounce = true;
        s.shot = .{ .state = .fly, .x = s.cannonX() + 26, .y = (cannon_y - 18) * fix };
        s.prev.shot_y = s.shot.y;
        ev.fired = true;
    }

    fn startDeath(s: *Sim, ev: *Events, by_bomb: bool) void {
        s.mode = .dying;
        s.death_t = 0;
        if (by_bomb) {
            s.lives -= 1;
            ev.cannon_hit = true;
            ev.score -= hit_penalty;
        } else {
            s.lives = 0;
            s.landed = true;
            ev.landed = true;
        }
    }

    fn dyingFrame(s: *Sim, ev: *Events) void {
        s.death_t += 1;
        if (s.death_t < death_frames) return;
        if (s.lives == 0) {
            s.mode = .over;
            ev.lost = true;
            return;
        }
        // Back at the left edge, the bombs gone, the invaders quiet for a moment.
        s.cx = cannon_min_x * fix;
        s.prev.cx = s.cx;
        for (&s.bombs) |*b| b.* = .{};
        s.roll_skip = true;
        if (s.shot.state != .none) s.endShot();
        s.fire_bounce = true;
        s.fire_delay = fire_pause;
        s.mode = .play;
        ev.respawn = true;
    }

    // ---- the player's shot ----

    fn endShot(s: *Sim) void {
        s.shot.state = .none;
        s.shot_count += 1;
        s.saucer_idx = (s.saucer_idx + 1) % @as(u8, saucer_scores.len);
        // The next saucer's direction follows the count's low bit (the arcade's comment: odd goes
        // left to right), set while none is out.
        if (s.saucer.state == .none) s.saucer_ltr = s.shot_count & 1 == 1;
    }

    fn updateShot(s: *Sim, ev: *Events) void {
        const sh = &s.shot;
        switch (sh.state) {
            .none => {},
            .blow, .wait_alien => {
                sh.t -= 1;
                if (sh.t == 0) s.endShot();
            },
            .fly => {
                sh.y -= shot_speed;
                const tip = (sh.y >> 8) + 1;
                const x0 = sh.x + 5;
                const x1 = sh.x + 7;
                const y1 = tip + 7;
                // The top of the field.
                if (tip <= 2) return s.shotBurst(sh.x + 6, tip);
                // The saucer.
                if (s.saucer.state == .fly) {
                    const sx = s.saucer.x >> 8;
                    if (x1 >= sx + 1 and x0 <= sx + saucer_w - 2 and y1 >= saucer_y + 1 and tip <= saucer_y + saucer_h - 2) {
                        s.saucer.state = .hit;
                        s.saucer.t = saucer_burst;
                        s.saucer.shown = 0;
                        ev.saucer_hit = true;
                        // The shot is spent at once (the arcade removes it, counting it).
                        s.endShot();
                        return;
                    }
                }
                // An invader (the lowest the shot reaches).
                var hit: ?usize = null;
                for (&s.inv, 0..) |*iv, i| {
                    if (!iv.alive) continue;
                    if (x1 < iv.x + inv_vis_l + 1 or x0 > iv.x + inv_vis_r - 1) continue;
                    if (y1 < iv.y + 1 or tip > iv.y + inv_h - 1) continue;
                    if (hit == null or iv.y > s.inv[hit.?].y) hit = i;
                }
                if (hit) |i| {
                    const iv = &s.inv[i];
                    iv.alive = false;
                    s.alive -= 1;
                    const pts: u32 = switch (rowOf(i)) {
                        0, 1 => 10,
                        2, 3 => 20,
                        else => 30,
                    };
                    s.points += pts;
                    ev.score += @intCast(pts * score_scale);
                    ev.invader_hit = true;
                    s.burst_x = iv.x;
                    s.burst_y = iv.y;
                    s.burst_t = invader_burst;
                    sh.state = .wait_alien;
                    sh.t = invader_burst;
                    return;
                }
                // A bomb in the way: both burst (the arcade: the shot finds no invader where it
                // hit, so it bursts; the bomb meets the burst).
                for (&s.bombs) |*b| {
                    if (b.state != .fall) continue;
                    const by = b.y >> 8;
                    if (x1 < b.x + 1 or x0 > b.x + 10 or y1 < by or tip > by + bomb_h - 1) continue;
                    s.bombBurst(b);
                    ev.bomb_shot = true;
                    return s.shotBurst(sh.x + 6, tip);
                }
                // A bunker (the bunker's pixels the tip overlaps).
                for (&s.bunkers) |*bk| {
                    const t = bk.touch(x0, tip, x1, y1);
                    if (t.n == 0) continue;
                    const c = @divFloor(sh.x + 6 - bk.x, bunker.block);
                    // The burst's bottom is 6 pixels below the contact (the arcade's shot is 4
                    // tall and its burst starts 3 under its foot).
                    bk.erase(x0, tip, x1, y1);
                    bk.carve(&bunker.shot_burst, c - 2, t.low_r - 6);
                    return s.shotBurst(sh.x + 6, tip);
                }
            },
        }
    }

    fn shotBurst(s: *Sim, cx: i32, tip: i32) void {
        s.shot.state = .blow;
        s.shot.t = shot_burst_frames;
        s.shot.bx = cx;
        s.shot.by = tip;
    }

    // ---- the bombs ----

    fn updateBombs(s: *Sim, ev: *Events) void {
        const fast = s.alive < bomb_fast_below;
        for (&s.bombs, 0..) |*b, k| {
            const turn = s.t % 3 == k;
            switch (b.state) {
                .idle => if (turn) s.tryFire(@fromBackingInt(@intCast(k)), ev),
                .blow => {
                    b.blow -= 1;
                    if (b.blow == 0) b.* = .{};
                },
                .fall => {
                    b.y += if (fast) bomb_speed_fast else bomb_speed;
                    b.age += 1;
                    if (turn) b.steps += 1;
                    if (s.bombHits(b, ev)) {
                        if (s.mode != .play) return;
                    }
                },
            }
        }
    }

    fn bombBurst(s: *Sim, b: *Bomb) void {
        _ = s;
        b.state = .blow;
        b.blow = bomb_burst_frames;
        b.bx = b.x + bomb_w / 2;
        b.by = (b.y >> 8) + bomb_h;
    }

    /// Does the falling bomb meet the ground, the cannon, a bunker or the shot? It bursts then.
    fn bombHits(s: *Sim, b: *Bomb, ev: *Events) bool {
        const by = b.y >> 8;
        const x0 = b.x + 1;
        const x1 = b.x + 10;
        const y1 = by + bomb_h - 1;
        // The player's shot.
        if (s.shot.state == .fly) {
            const tip = (s.shot.y >> 8) + 1;
            if (s.shot.x + 7 >= x0 and s.shot.x + 5 <= x1 and tip + 7 >= by and tip <= y1) {
                s.bombBurst(b);
                ev.bomb_shot = true;
                s.shotBurst(s.shot.x + 6, tip);
                return true;
            }
        }
        // The cannon.
        if (y1 >= cannon_y) {
            const cx = s.cannonX();
            var y = @max(by, cannon_y);
            while (y <= @min(y1, cannon_y + cannon_h - 1)) : (y += 1) {
                const row = s.cannon_rows[@intCast(y - cannon_y)];
                if (row.hi < row.lo) continue;
                if (cx + row.hi >= x0 and cx + row.lo <= x1) {
                    s.bombBurst(b);
                    s.startDeath(ev, true);
                    return true;
                }
            }
        }
        // A bunker: the bomb's own pixels and the burst's carve it.
        for (&s.bunkers) |*bk| {
            const t = bk.touch(x0, by + bomb_h - 8, x1, y1);
            if (t.n == 0) continue;
            const c = @divFloor(b.x + 6 - bk.x, bunker.block);
            const bottom_row = @divFloor(bk.bottom() - 1 - y1, bunker.block);
            bk.erase(x0, by, x1, y1);
            bk.carve(&bunker.bomb_burst, c - 2, bottom_row - 2);
            s.bombBurst(b);
            return true;
        }
        // The ground.
        if (y1 + 1 >= ground_y) {
            s.bombBurst(b);
            return true;
        }
        return false;
    }

    fn activeSteps(s: *const Sim, k: usize) u16 {
        const b = s.bombs[k];
        return if (b.state == .idle) 0 else b.steps;
    }

    fn tryFire(s: *Sim, kind: BombKind, ev: *Events) void {
        const k: usize = @backingInt(kind);
        if (kind == .rolling and s.roll_skip) {
            s.roll_skip = false;
            return;
        }
        if (kind == .plunger and s.alive == 1) return;
        if (kind == .squiggly and s.saucer_pending and s.activeSteps(2) == 0) {
            // The saucer takes the squiggly's turn (the arcade's one object for both).
            if (s.saucer.state != .none) return;
            if (s.alive >= saucer_min_alive) {
                s.launchSaucer(ev);
                return;
            }
        }
        if (s.fire_delay > 0) return;
        // The reload rule: a bomb falls only when each other one has taken more steps than the rate.
        const rate = reloadRate(s.points);
        for (0..3) |o| {
            if (o == k) continue;
            const n = s.activeSteps(o);
            if (n != 0 and rate >= n) return;
        }
        const col: u8 = switch (kind) {
            .rolling => s.playerColumn(),
            .plunger => blk: {
                const c = ourColumn(col_fire[s.plunger_idx]);
                s.plunger_idx += 1;
                if (s.plunger_idx >= plunger_end) s.plunger_idx = plunger_first;
                break :blk c;
            },
            .squiggly => blk: {
                const c = ourColumn(col_fire[s.squiggly_idx]);
                s.squiggly_idx += 1;
                if (s.squiggly_idx >= squiggly_end) s.squiggly_idx = squiggly_first;
                break :blk c;
            },
        };
        // The lowest invader of the column.
        var r: usize = 0;
        while (r < rows) : (r += 1) {
            const iv = s.inv[r * cols + col];
            if (!iv.alive) continue;
            s.bombs[k] = .{
                .state = .fall,
                .x = iv.x + inv_w / 2 - bomb_w / 2,
                .y = (iv.y + inv_h - 6) * fix,
                .steps = 1,
            };
            s.prev.bomb_y[k] = s.bombs[k].y;
            return;
        }
    }

    /// The column of the rack over the cannon's middle (the aimed bomb's), the end columns when
    /// the cannon is beyond the rack.
    fn playerColumn(s: *const Sim) u8 {
        const mid = s.cannonX() + cannon_w / 2;
        const c = @divFloor(mid - s.rack_x, pitch_x);
        return @intCast(std.math.clamp(c, 0, cols - 1));
    }

    // ---- the saucer ----

    fn launchSaucer(s: *Sim, ev: *Events) void {
        s.saucer = .{ .state = .fly };
        if (s.saucer_ltr) {
            s.saucer.x = saucer_min_x * fix;
            s.saucer.dir = 1;
        } else {
            s.saucer.x = saucer_max_x * fix;
            s.saucer.dir = -1;
        }
        s.prev.saucer_x = s.saucer.x;
        ev.saucer_launch = true;
    }

    fn updateSaucer(s: *Sim, ev: *Events) void {
        // The timer runs once the rack has come down (the arcade's `TimeToSaucer`).
        if (s.rack_y > rack_y0) {
            if (s.saucer_timer == 0) {
                s.saucer_timer = saucer_period;
                s.saucer_pending = true;
            }
            s.saucer_timer -= 1;
        }
        const sc = &s.saucer;
        switch (sc.state) {
            .none => {},
            .fly => {
                sc.x += sc.dir * saucer_speed;
                const px = sc.x >> 8;
                if (px < saucer_min_x or px > saucer_max_x) {
                    sc.* = .{};
                    s.saucer_pending = false;
                }
            },
            .hit => {
                sc.t -= 1;
                if (sc.t == saucer_burst - saucer_score_at) {
                    const pts: u32 = saucer_scores[s.saucer_idx];
                    s.points += pts;
                    sc.shown = @intCast(pts * score_scale);
                    ev.score += @intCast(pts * score_scale);
                }
                if (sc.t == 0) {
                    sc.* = .{};
                    s.saucer_pending = false;
                }
            },
        }
    }

    // ---- the rack ----

    fn updateRack(s: *Sim, ev: *Events) void {
        if (s.alive == 0) {
            if (s.burst_t > 0) s.burst_t -= 1;
            return;
        }
        // The march waits while a killed invader bursts.
        if (s.burst_t > 0) {
            s.burst_t -= 1;
            return;
        }
        var guard: usize = 0;
        while (guard < 2 * n_inv) : (guard += 1) {
            s.cursor += 1;
            if (s.cursor >= n_inv) {
                s.cursor = 0;
                s.moveRef(ev);
            }
            if (s.inv[s.cursor].alive) break;
        } else return;
        s.place(s.cursor, ev);
    }

    /// The reference invader (the bottom left) steps; the others follow as the march reaches them.
    fn moveRef(s: *Sim, ev: *Events) void {
        if (s.pending_drop != 0) {
            s.rack_y += s.pending_drop;
            s.pending_drop = 0;
            s.drops += 1;
            ev.descend = true;
        }
        s.rack_x += s.rack_dx;
        s.rack_frame ^= 1;
        ev.march = true;
    }

    fn place(s: *Sim, i: usize, ev: *Events) void {
        const iv = &s.inv[i];
        const col: i32 = @intCast(i % cols);
        const row: i32 = @intCast(i / cols);
        iv.x = s.rack_x + col * pitch_x;
        iv.y = s.rack_y - row * pitch_y;
        iv.frame = s.rack_frame;
        // An invader eats the bunker under it.
        for (&s.bunkers) |*bk| bk.erase(iv.x + inv_vis_l, iv.y, iv.x + inv_vis_r, iv.y + inv_h - 1);
        if (iv.y + inv_h >= land_y) {
            s.startDeath(ev, false);
            return;
        }
        s.checkWalls();
    }

    /// The arcade's `RackBump`: a visible pixel at a wall turns the rack (and drops it at the next
    /// step).
    fn checkWalls(s: *Sim) void {
        for (s.inv) |iv| {
            if (!iv.alive) continue;
            if (s.dir > 0 and iv.x + inv_vis_r >= wall_r) {
                s.dir = -1;
                s.rack_dx = -march_dx;
                s.pending_drop = drop_px;
                return;
            }
            if (s.dir < 0 and iv.x + inv_vis_l <= wall_l) {
                s.dir = 1;
                s.rack_dx = if (s.alive == 1) march_dx_last else march_dx;
                s.pending_drop = drop_px;
                return;
            }
        }
    }

    // ---- for the picture ----

    /// The screen position of the cannon's top left, between the frames: `f` of the way from the
    /// previous frame's (0..256).
    pub fn lerp(a: i32, b: i32, f: i32) i32 {
        return (a + @divTrunc((b - a) * f, 256)) >> 8;
    }
};

// ---- tests ----

const testing = std.testing;

fn run(s: *Sim, frames: u32, in: Input) Events {
    var t: Events = .{};
    for (0..frames) |_| {
        var ev: Events = .{};
        s.frame(in, &ev);
        t.score += ev.score;
        t.fired = t.fired or ev.fired;
        t.invader_hit = t.invader_hit or ev.invader_hit;
        t.saucer_launch = t.saucer_launch or ev.saucer_launch;
        t.saucer_hit = t.saucer_hit or ev.saucer_hit;
        t.cannon_hit = t.cannon_hit or ev.cannon_hit;
        t.bomb_shot = t.bomb_shot or ev.bomb_shot;
        t.march = t.march or ev.march;
        t.descend = t.descend or ev.descend;
        t.landed = t.landed or ev.landed;
        t.respawn = t.respawn or ev.respawn;
        t.won = t.won or ev.won;
        t.lost = t.lost or ev.lost;
    }
    return t;
}

/// The cannon under invader `i`, at a place its shot passes between the bunkers.
fn aimUnder(s: *Sim, i: usize) void {
    const off = [cols]i32{ 70, 78, 10, 22 };
    s.cx = (s.inv[i].x + off[i % cols] - 32) * fix;
}

test "the rack marches one invader a frame: a full step takes as many frames as there are invaders" {
    var s = Sim.init();
    s.fire_delay = 255;
    var steps: u32 = 0;
    var frames: u32 = 0;
    while (steps < 3) {
        var ev: Events = .{};
        s.frame(.{}, &ev);
        frames += 1;
        if (ev.march) steps += 1;
    }
    // The first march comes when the cursor wraps (20 frames in), then every 20.
    try testing.expectEqual(@as(u32, 60), frames);
    // Kill one: the cycle is 19 frames.
    s.inv[5].alive = false;
    s.alive = 19;
    var ev: Events = .{};
    var n: u32 = 0;
    while (!ev.march) {
        ev = .{};
        s.frame(.{}, &ev);
        n += 1;
    }
    var m: u32 = 0;
    ev = .{};
    while (!ev.march) {
        ev = .{};
        s.frame(.{}, &ev);
        m += 1;
    }
    try testing.expectEqual(@as(u32, 19), m);
}

test "the rack turns at a wall, drops once and goes back" {
    var s = Sim.init();
    s.fire_delay = 255;
    var seen_drop = false;
    var turned_at_right = false;
    var frames: u32 = 0;
    while (frames < 6000 and !seen_drop) : (frames += 1) {
        var ev: Events = .{};
        s.frame(.{}, &ev);
        if (s.dir < 0) turned_at_right = true;
        if (ev.descend) seen_drop = true;
    }
    try testing.expect(turned_at_right and seen_drop);
    try testing.expectEqual(@as(i32, rack_y0 + drop_px), s.rack_y);
    try testing.expect(s.rack_dx < 0);
}

test "the last invader is fast" {
    var s = Sim.init();
    s.fire_delay = 255;
    for (&s.inv, 0..) |*iv, i| iv.alive = i == 0;
    s.alive = 1;
    const x0 = s.rack_x;
    _ = run(&s, 10, .{});
    // One invader: a march every frame, 6 px each, until a wall.
    try testing.expect(@abs(s.rack_x - x0) >= 54);
}

test "the player's shot: one at a time, a press must follow a release" {
    var s = Sim.init();
    var ev: Events = .{};
    s.frame(.{ .fire = true }, &ev);
    try testing.expect(ev.fired and s.shot.state == .fly);
    // Held down: no second shot even after this one is gone.
    s.shot.state = .none;
    ev = .{};
    s.frame(.{ .fire = true }, &ev);
    try testing.expect(!ev.fired);
    s.frame(.{ .fire = false }, &ev);
    s.frame(.{ .fire = true }, &ev);
    try testing.expect(ev.fired);
}

test "a shot kills an invader, scores by row and holds the march a moment" {
    var s = Sim.init();
    s.fire_delay = 255;
    aimUnder(&s, 0);
    var ev: Events = .{};
    s.frame(.{ .fire = true }, &ev);
    var score: i32 = 0;
    var hit = false;
    var f: u32 = 0;
    while (f < 120 and !hit) : (f += 1) {
        ev = .{};
        s.frame(.{}, &ev);
        score += ev.score;
        hit = ev.invader_hit;
    }
    try testing.expect(hit);
    try testing.expectEqual(@as(i32, 100), score);
    try testing.expectEqual(@as(u8, 19), s.alive);
    try testing.expect(s.burst_t > 0);
    // The shot is spent only when the burst is over; the count then is 1.
    _ = run(&s, invader_burst, .{});
    try testing.expectEqual(@as(u32, 1), s.shot_count);
    try testing.expect(s.shot.state == .none);
}

test "the rows score 10, 10, 20, 20, 30 (times ten)" {
    try testing.expectEqual(@as(usize, 0), Sim.rowOf(3));
    var s = Sim.init();
    s.fire_delay = 255;
    inline for (.{ .{ 0, 100 }, .{ 1, 100 }, .{ 2, 200 }, .{ 3, 200 }, .{ 4, 300 } }) |c| {
        s = Sim.init();
        s.fire_delay = 255;
        // Clear the rows below so the shot reaches row c[0].
        for (0..c[0] * cols) |i| {
            s.inv[i].alive = false;
            s.alive -= 1;
        }
        aimUnder(&s, c[0] * cols);
        var total: i32 = 0;
        var ev: Events = .{};
        s.frame(.{ .fire = true }, &ev);
        for (0..80) |_| {
            ev = .{};
            s.frame(.{}, &ev);
            total += ev.score;
        }
        try testing.expectEqual(@as(i32, c[1]), total);
    }
}

test "bombs: the aimed one falls from the column over the cannon, one at a time at first" {
    var s = Sim.init();
    s.fire_delay = 0;
    // The cannon under the third column.
    s.cx = (s.inv[2].x + inv_w / 2 - cannon_w / 2) * fix;
    var fell = false;
    var most: usize = 0;
    var frames: u32 = 0;
    while (frames < 600) : (frames += 1) {
        var ev: Events = .{};
        s.frame(.{}, &ev);
        if (s.mode != .play) break;
        var n: usize = 0;
        for (s.bombs) |b| {
            if (b.state == .fall) {
                n += 1;
                fell = true;
            }
        }
        most = @max(most, n);
    }
    try testing.expect(fell);
    // Below 109 arcade points the reload rate is 48 steps: one bomb at a time.
    try testing.expectEqual(@as(usize, 1), most);
}

test "reload rate by score, the arcade's table" {
    try testing.expectEqual(@as(u16, 0x30), reloadRate(0));
    try testing.expectEqual(@as(u16, 0x10), reloadRate(109));
    try testing.expectEqual(@as(u16, 0x0b), reloadRate(500));
    try testing.expectEqual(@as(u16, 0x08), reloadRate(1000));
    try testing.expectEqual(@as(u16, 0x07), reloadRate(5000));
}

test "up to three bombs fall together once the score is high enough" {
    var s = Sim.init();
    s.fire_delay = 0;
    s.points = 1200;
    s.cx = (s.inv[1].x + inv_w / 2 - cannon_w / 2) * fix;
    var most: usize = 0;
    for (0..1200) |_| {
        var ev: Events = .{};
        s.frame(.{}, &ev);
        if (s.mode != .play) {
            // Revive: this test counts bombs, not hits.
            s.mode = .play;
            s.lives = 3;
        }
        var n: usize = 0;
        for (s.bombs) |b| {
            if (b.state == .fall) n += 1;
        }
        most = @max(most, n);
    }
    try testing.expect(most == 3);
}

test "a bomb that reaches the cannon takes a life, the arcade's pause, then the cannon is back at the left" {
    var s = Sim.init();
    s.fire_delay = 0;
    // A bomb right over the barrel.
    const cx = s.cannonX();
    s.bombs[1] = .{ .state = .fall, .x = cx + 26, .y = 300 * fix, .steps = 1 };
    var ev: Events = .{};
    var hit = false;
    for (0..200) |_| {
        ev = .{};
        s.frame(.{}, &ev);
        if (ev.cannon_hit) {
            hit = true;
            break;
        }
    }
    try testing.expect(hit and s.lives == 2 and s.mode == .dying);
    try testing.expectEqual(@as(i32, -500), ev.score);
    // Everything stands for 60 frames, then the cannon is back, the bombs gone.
    const rack = s.rack_x;
    s.cx = 300 * fix;
    for (0..death_frames - 1) |_| {
        var e: Events = .{};
        s.frame(.{}, &e);
        try testing.expect(s.mode == .dying);
    }
    var e: Events = .{};
    s.frame(.{}, &e);
    try testing.expect(e.respawn and s.mode == .play);
    try testing.expectEqual(@as(i32, cannon_min_x), s.cannonX());
    try testing.expectEqual(rack, s.rack_x);
    for (s.bombs) |b| try testing.expect(b.state == .idle);
}

test "the third life lost is the loss" {
    var s = Sim.init();
    s.lives = 1;
    s.bombs[0] = .{ .state = .fall, .x = s.cannonX() + 26, .y = 340 * fix, .steps = 1 };
    const ev = run(&s, 200, .{});
    try testing.expect(ev.cannon_hit and ev.lost and s.mode == .over and s.lives == 0);
}

test "an invader that reaches the invasion line ends the game" {
    var s = Sim.init();
    s.fire_delay = 255;
    s.rack_y = 330;
    s.pending_drop = drop_px;
    const ev = run(&s, 200, .{});
    try testing.expect(ev.landed and ev.lost and s.lives == 0);
}

test "the saucer comes after the rack has come down, scores by the shot count (the 23rd is 300)" {
    var s = Sim.init();
    s.fire_delay = 255;
    s.rack_y = rack_y0 + drop_px;
    // Wait for the timer.
    var launched = false;
    for (0..saucer_period + 400) |_| {
        var ev: Events = .{};
        s.fire_delay = 255;
        s.frame(.{}, &ev);
        if (ev.saucer_launch) launched = true;
        if (launched) break;
    }
    try testing.expect(launched and s.saucer.state == .fly);
    // The score table at shot counts 0..14: the 300 sits at 8; the arcade's pointer wraps at 15.
    try testing.expectEqual(@as(u16, 300), saucer_scores[8]);
    try testing.expectEqual(@as(usize, 15), saucer_scores.len);
    var idx: u8 = 0;
    var shots: u32 = 0;
    while (true) {
        shots += 1;
        idx = (idx + 1) % 15;
        if (saucer_scores[idx] == 300) break;
    }
    try testing.expectEqual(@as(u32, 8), shots);
}

test "a shot into a bunker bites it from below; a bomb bites from above, deeper" {
    var s = Sim.init();
    s.fire_delay = 255;
    // Under the first bunker's middle.
    const bk0 = s.bunkers[0].count();
    s.cx = (s.bunkers[0].x + bunker.width / 2 - 32) * fix;
    var ev: Events = .{};
    s.frame(.{ .fire = true }, &ev);
    _ = run(&s, 20, .{});
    const after_shot = s.bunkers[0].count();
    try testing.expect(after_shot < bk0);
    try testing.expect(bk0 - after_shot <= 40);
    // A bomb into the same bunker, further left.
    var s2 = Sim.init();
    s2.fire_delay = 255;
    const n0 = s2.bunkers[1].count();
    s2.bombs[2] = .{ .state = .fall, .x = s2.bunkers[1].x + 30, .y = 250 * fix, .steps = 1 };
    s2.cx = 500 * fix;
    _ = run(&s2, 60, .{});
    const bite = n0 - s2.bunkers[1].count();
    try testing.expect(bite > 8);
}

test "a shot meets a bomb: both burst" {
    var s = Sim.init();
    s.fire_delay = 255;
    s.cx = 300 * fix;
    var ev: Events = .{};
    s.frame(.{ .fire = true }, &ev);
    const sx = s.shot.x;
    s.bombs[0] = .{ .state = .fall, .x = sx, .y = 250 * fix, .steps = 1 };
    var met = false;
    for (0..60) |_| {
        ev = .{};
        s.frame(.{}, &ev);
        if (ev.bomb_shot) met = true;
    }
    try testing.expect(met);
    try testing.expect(s.bombs[0].state != .fall);
}

test "clearing the rack wins after the last burst and a pause" {
    var s = Sim.init();
    s.fire_delay = 255;
    for (1..n_inv) |i| s.inv[i].alive = false;
    s.alive = 1;
    // Standing still (the last invader would march away from the aim).
    s.rack_dx = 0;
    aimUnder(&s, 0);
    var ev: Events = .{};
    s.frame(.{ .fire = true }, &ev);
    var won = false;
    for (0..200) |_| {
        ev = .{};
        s.frame(.{}, &ev);
        if (ev.won) won = true;
    }
    try testing.expect(won and s.mode == .over);
}
