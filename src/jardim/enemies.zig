//! Not in the original (`Fixes.jardim_fair_enemies`, a Corrigida addition, with
//! `jardim_smooth_movement`): fair enemies. docs/jardim/ENEMIES.md is the investigation behind
//! it, docs/jardim/DESIGN.md "Decisions" the summary, docs/jardim/GAME.md "Fair enemies
//! (Corrigida)" the rules.
//!
//! In the original every type of enemy is ONE Portable stored in many cells, and its logic runs
//! inside the sprite draw: every drawn copy hits (1 health per animation cycle of the shared
//! frame, at any distance), and steps a cell along the view axis on frame 0, into the player's
//! cell and past him, merging with copies of its type. Here each placed enemy is an instance
//! (`Enemy`, in `Game.fair`) with its own cell, step, frame, timers and life; the map keeps the
//! type's object in the instance's cell (`objectRows`), so the shots, the touch and the scenes'
//! `hit` work as before. The logic runs once per instance on the game tick (`think`, timer 1),
//! timed in milliseconds of the task's clock (`plat.ticks()`), whatever the copies drawn or the
//! frame rate; the sprite draw only draws (`placeForDraw`: the instance's place between its
//! cells, its frame, the kill's white flash).
//!
//! An instance: idle until it sees the player (a clear line from its cell's centre to him, at
//! most `sight_cells`), then a reaction delay from the game's rand(), then the chase: a step
//! every `step_ms` along the larger axis towards him (else the smaller), only into an empty
//! floor cell no other enemy holds or leaves, never the player's cell, never nearer than
//! `min_gap` units to him, stopping at `stop` cells (Chebyshev); in sight and within `reach`
//! cells, a wind-up (`windup_ms`: the attack frame, its attack wave) and the blow if he is still
//! in sight and reach, then `cooldown_ms`. Out of sight it chases on for `memory_ms`. The goal
//! (phase 3, not an enemy) stands and animates.

const std = @import("std");
const builtin = @import("builtin");
const build_options = @import("build_options");
const msg = @import("../core/msg.zig");
const platform = @import("../platform/platform.zig");
const game = @import("core/game.zig");
const Game = game.Game;
const object = @import("core/object.zig");
const Object = object.Object;
const world = @import("core/world.zig");
const Backdrop = world.Backdrop;
const SpriteQueue = world.SpriteQueue;
const position = @import("behaviour/position.zig");
const hud = @import("hud.zig");
const labyrinth_input = @import("labyrinth_input.zig");
const sprites = @import("sprites.zig");

pub const Kind = enum(u8) { bussuf, seios, alemao, siri, chato, bicho, goal };

/// One kind's numbers.
pub const KindTuning = struct {
    /// A cell per `step_ms` while chasing (0: it never moves).
    step_ms: u32 = 600,
    /// It attacks within `reach` cells (Chebyshev: the 8 cells around the player are 1).
    reach: i16 = 1,
    /// It stops walking at `stop` cells.
    stop: i16 = 1,
    /// Health a blow takes (Alemão: `ranged`, below).
    damage: i16 = 5,
    /// Alemão's gun: Wolf3D's `T_Shoot`, a hit with chance (256 − 16·cells)/256, for 8 at 1 cell,
    /// 4 up to 3 cells, 2 beyond.
    ranged: bool = false,
    /// The goal (not an enemy) neither attacks nor moves.
    attacks: bool = true,
};

/// Every number of the fair enemies (the owner's tuning: one place).
pub const EnemyTuning = struct {
    /// The walking frames' rate (8 a second); the last frame of a strip is the attack pose,
    /// shown only in the wind-up.
    anim_ms: u32 = 125,
    /// From seeing the player to chasing him: `react_min_ms` + rand() % (max − min + 1)
    /// (Wolf3D's guard reacts in 14–914 ms).
    react_min_ms: u32 = 300,
    react_max_ms: u32 = 800,
    /// The tell: the attack frame and wave this long before the blow.
    windup_ms: u32 = 250,
    /// After a blow (or a blow that missed: out of sight or reach at its end).
    cooldown_ms: u32 = 1200,
    /// After any hit the player cannot be hit for this long.
    invuln_ms: u32 = 500,
    /// It keeps chasing this long after it last saw the player.
    memory_ms: u32 = 1500,
    /// It sees the player up to this far (in cells), along a line clear of walls and doors.
    sight_cells: i32 = 16,
    /// It never steps into a cell whose centre is nearer the player than this (units: a cell is
    /// 32): an enemy next to him is drawn at least this far away, not over the whole view.
    min_gap: i32 = 24,
    /// No step wave this long after an attack wave (WaveMix plays one wave: the tell wins).
    step_quiet_ms: u32 = 600,
    /// Hit feedback: the view's border red this long, this wide; the face a step worse this long.
    border_ms: u32 = 150,
    border_px: i16 = 4,
    face_ms: u32 = 300,
    /// A killed enemy is drawn white this many frames, then gone.
    flash_frames: u8 = 2,
    /// Walking into an enemy only blocks (false), or also hurts as the original's touch does
    /// once per contact (J6's rule: Seios, Siri and Bicho a life, the others 5 health).
    contact_hurts: bool = false,
    kinds: [7]KindTuning = .{
        .{ .step_ms = 600, .damage = 5 }, // Bussuf
        .{ .step_ms = 800, .damage = 10 }, // Seios
        .{ .step_ms = 450, .reach = 4, .stop = 2, .ranged = true }, // Alemão
        .{ .step_ms = 600, .damage = 10 }, // Siri
        .{ .step_ms = 600, .damage = 5 }, // Chato
        .{ .step_ms = 800, .damage = 10 }, // Bicho
        .{ .step_ms = 0, .damage = 0, .attacks = false }, // the goal
    },

    pub fn of(t: *const EnemyTuning, k: Kind) *const KindTuning {
        return &t.kinds[@backingInt(k)];
    }
};

pub const tuning: EnemyTuning = .{};

pub const State = enum(u8) {
    /// Has not seen the player.
    idle,
    /// Saw him: chases at `until`.
    react,
    /// Chasing (and attacking in reach).
    chase,
    /// The tell: the blow at `until`.
    windup,
    /// Shot: drawn white `flash` more frames.
    dying,
    dead,
};

pub const Enemy = struct {
    obj: *Object,
    kind: Kind,
    homeRow: i16,
    homeCol: i16,
    /// The cell it holds in the map, and the one it is walking from (the same when standing).
    row: i16,
    col: i16,
    fromRow: i16,
    fromCol: i16,
    /// When the current step began.
    stepAt: u32 = 0,
    state: State = .idle,
    /// The reaction's or the wind-up's end.
    until: u32 = 0,
    nextStepAt: u32 = 0,
    cooldownUntil: u32 = 0,
    seenAt: u32 = 0,
    /// The walking animation's start (each its own phase).
    animAt: u32 = 0,
    flash: u8 = 0,

    fn alive(e: *const Enemy) bool {
        return e.state != .dying and e.state != .dead;
    }

    fn walking(e: *const Enemy, now: u32, t: *const KindTuning) bool {
        return (e.row != e.fromRow or e.col != e.fromCol) and now -% e.stepAt < t.step_ms;
    }
};

pub const max_enemies = 64;

/// A white copy of a sprite strip (the kill's flash).
const WhiteDib = struct { src: *const object.Dib, bits: []u8 };

/// `Game.fair`.
pub const FairState = struct {
    /// The backdrop the instances belong to (a new phase builds them again).
    bd: ?*Backdrop = null,
    enemies: [max_enemies]Enemy = undefined,
    count: usize = 0,
    /// The player cannot be hit before this (`invuln_ms`; until the respawn after a life lost).
    invulnUntil: u32 = 0,
    respawning: bool = false,
    /// The last hit (the border and the face).
    hurtAt: ?u32 = null,
    lastAttackWaveAt: ?u32 = null,
    /// The lives seen by the last think (a life lost elsewhere waits for the respawn too).
    lives: i16 = 0,
    whites: [8]?WhiteDib = @splat(null),
    /// The debug overlay and log (F9, Debug builds).
    overlay: bool = false,
    /// Counts for the overlay and the log.
    hits: u16 = 0,
    damage: u16 = 0,
    /// The probe's last map line.
    mapHash: u64 = 0,
};

/// The fair enemies are on (they need the Corrigida's movement: with the 1995 one the 1995
/// enemies stay, so the 1995-control scripts keep their runs).
pub fn active(g: *const Game) bool {
    return g.fixes.jardim_fair_enemies and g.fixes.jardim_smooth_movement;
}

fn sceneKind(bd: *Backdrop, obj: *Object) ?Kind {
    const s = bd.scene orelse return null;
    const phase: u8 = if (s.mapFile.len > 6) s.mapFile[6] else '1';
    if (obj == s.goal) return .goal;
    if (obj == s.enemyA) return switch (phase) {
        '2' => .alemao,
        '3' => .chato,
        else => .bussuf,
    };
    if (obj == s.enemyB) return switch (phase) {
        '2' => .siri,
        '3' => .bicho,
        else => .seios,
    };
    return null;
}

/// The instances of `bd`'s map, once per backdrop.
fn ensure(g: *Game, bd: *Backdrop) void {
    const f = &g.fair;
    if (f.bd == bd) return;
    f.* = .{ .bd = bd, .lives = bd.lives, .overlay = f.overlay };
    const now = g.plat.ticks();
    for (0..world.map_rows) |r| {
        for (0..world.map_cols) |c| {
            const obj = bd.objectRows[r][c] orelse continue;
            if (obj.isEnemy == 0) continue;
            const kind = sceneKind(bd, obj) orelse continue;
            if (f.count == max_enemies) @panic("jardim enemies: more than max_enemies placed");
            const row: i16 = @intCast(r);
            const col: i16 = @intCast(c);
            f.enemies[f.count] = .{
                .obj = obj,
                .kind = kind,
                .homeRow = row,
                .homeCol = col,
                .row = row,
                .col = col,
                .fromRow = row,
                .fromCol = col,
                .animAt = now -% @as(u32, @intCast(f.count * 47 % 500)),
            };
            f.count += 1;
        }
    }
}

fn cheb(ar: i32, ac: i32, br: i32, bc: i32) i32 {
    return @intCast(@max(@abs(ar - br), @abs(ac - bc)));
}

fn wallAt(bd: *const Backdrop, row: i32, col: i32) i8 {
    if (row < 0 or row >= world.map_rows or col < 0 or col >= world.map_cols) return 1;
    return bd.wallRows[@intCast(row)][@intCast(col)];
}

/// A line clear of walls and doors from (x0, y0) to (x1, y1) (units), sampled every 4 units.
pub fn clearLine(bd: *const Backdrop, x0: i32, y0: i32, x1: i32, y1: i32) bool {
    const dx = x1 - x0;
    const dy = y1 - y0;
    const n: i32 = @intCast(@max(@abs(dx), @abs(dy)) / 4 + 1);
    var pr = y0 >> 5;
    var pc = x0 >> 5;
    var i: i32 = 0;
    while (i <= n) : (i += 1) {
        const r = (y0 + @divTrunc(dy * i, n)) >> 5;
        const c = (x0 + @divTrunc(dx * i, n)) >> 5;
        if (wallAt(bd, r, c) > 0) return false;
        // Through a corner: one of the two cells beside it must be open.
        if (r != pr and c != pc and wallAt(bd, pr, c) > 0 and wallAt(bd, r, pc) > 0) return false;
        pr = r;
        pc = c;
    }
    return true;
}

fn sees(bd: *const Backdrop, e: *const Enemy) bool {
    const ex = @as(i32, e.col) * 32 + 16;
    const ey = @as(i32, e.row) * 32 + 16;
    const dx = bd.playerX - ex;
    const dy = bd.playerY - ey;
    const r = tuning.sight_cells * 32;
    if (dx * dx + dy * dy > r * r) return false;
    return clearLine(bd, ex, ey, bd.playerX, bd.playerY);
}

fn randBelow(g: *Game, n: u32) u32 {
    return @as(u32, @intCast(g.rand.rand())) % n;
}

/// The cell (r, c) can take a step: an empty floor cell, not the player's, not too near him,
/// not a cell another enemy is walking out of or flashing in.
fn free(g: *Game, bd: *Backdrop, self: *const Enemy, r: i32, c: i32, now: u32) bool {
    if (wallAt(bd, r, c) != 0) return false;
    if (bd.objectRows[@intCast(r)][@intCast(c)] != null) return false;
    if (r == bd.playerY >> 5 and c == bd.playerX >> 5) return false;
    const gx = c * 32 + 16 - bd.playerX;
    const gy = r * 32 + 16 - bd.playerY;
    if (gx * gx + gy * gy < tuning.min_gap * tuning.min_gap) return false;
    for (g.fair.enemies[0..g.fair.count]) |*o| {
        if (o == self) continue;
        if (o.state == .dying and o.row == r and o.col == c) return false;
        if (o.fromRow == r and o.fromCol == c and o.walking(now, tuning.of(o.kind))) return false;
    }
    return true;
}

/// One step towards the player: the larger axis first (Wolf3D's `SelectChaseDir` without
/// diagonals), then the smaller. The map's cell changes at the step's start.
fn step(g: *Game, bd: *Backdrop, e: *Enemy, now: u32) bool {
    const dr = (bd.playerY >> 5) - e.row;
    const dc = (bd.playerX >> 5) - e.col;
    const sr: i32 = std.math.sign(dr);
    const sc: i32 = std.math.sign(dc);
    const tries: [2][2]i32 = if (@abs(dc) >= @abs(dr)) .{ .{ 0, sc }, .{ sr, 0 } } else .{ .{ sr, 0 }, .{ 0, sc } };
    for (tries) |t| {
        if (t[0] == 0 and t[1] == 0) continue;
        const r = e.row + t[0];
        const c = e.col + t[1];
        if (!free(g, bd, e, r, c, now)) continue;
        bd.objectRows[@intCast(e.row)][@intCast(e.col)] = null;
        bd.objectRows[@intCast(r)][@intCast(c)] = e.obj;
        e.fromRow = e.row;
        e.fromCol = e.col;
        e.row = @intCast(r);
        e.col = @intCast(c);
        e.stepAt = now;
        return true;
    }
    return false;
}

fn attackWave(g: *Game, bd: *Backdrop, e: *Enemy, now: u32) void {
    const scene = bd.scene orelse return;
    // Chato's attack slot plays a wave phase 3 never opens (BUGS.md, harmless): its step
    // wave is the tell.
    if (e.kind == .chato) scene.playEnemyStepSound(g, e.obj) else scene.playEnemyAttackSound(g, e.obj);
    g.fair.lastAttackWaveAt = now;
}

/// The blow at the wind-up's end.
fn strike(g: *Game, bd: *Backdrop, e: *Enemy, now: u32) void {
    const t = tuning.of(e.kind);
    const f = &g.fair;
    if (f.respawning or now -% f.invulnUntil >= 0x8000_0000) return;
    const d = cheb(e.row, e.col, bd.playerY >> 5, bd.playerX >> 5);
    var dmg = t.damage;
    if (t.ranged) {
        const chance: u32 = @intCast(@max(0, 256 - 16 * d));
        if (randBelow(g, 256) >= chance) return;
        dmg = if (d <= 1) 8 else if (d <= 3) 4 else 2;
    }
    bd.health -%= dmg;
    f.invulnUntil = now +% tuning.invuln_ms;
    f.hurtAt = now;
    f.hits +%= 1;
    f.damage +%= @intCast(dmg);
    labyrinth_input.lifeCheck(g, bd);
}

/// The game tick: every instance's logic, once (before the tick's frame).
pub fn think(g: *Game, bd: *Backdrop) void {
    ensure(g, bd);
    const f = &g.fair;
    const now = g.plat.ticks();
    const lives_before = bd.lives;
    if (bd.lives < f.lives) f.respawning = true;
    const pr = bd.playerY >> 5;
    const pc = bd.playerX >> 5;
    for (f.enemies[0..f.count]) |*e| {
        // A kill is white for `flash_frames` game frames (the ticks'; the motion frames between
        // show it too), then gone.
        if (e.state == .dying) {
            e.flash -|= 1;
            if (e.flash == 0) e.state = .dead;
        }
        if (!e.alive()) continue;
        // Shot: the scene's `hit` cleared its cell.
        if (bd.objectRows[@intCast(e.row)][@intCast(e.col)] != e.obj) {
            e.state = .dying;
            e.flash = tuning.flash_frames;
            e.fromRow = e.row;
            e.fromCol = e.col;
            continue;
        }
        const t = tuning.of(e.kind);
        if (!t.attacks) continue;
        const los = sees(bd, e);
        if (los) e.seenAt = now;
        const d = cheb(e.row, e.col, pr, pc);
        switch (e.state) {
            .idle => if (los) {
                e.state = .react;
                e.until = now +% tuning.react_min_ms +% randBelow(g, tuning.react_max_ms - tuning.react_min_ms + 1);
            },
            .react => if (now -% e.until < 0x8000_0000) {
                e.state = .chase;
                e.nextStepAt = now;
            },
            .chase => {
                if (los and d <= t.reach and !f.respawning and now -% e.cooldownUntil < 0x8000_0000 and !e.walking(now, t)) {
                    e.state = .windup;
                    e.until = now +% tuning.windup_ms;
                    attackWave(g, bd, e, now);
                } else if (d > t.stop and t.step_ms > 0 and now -% e.seenAt <= tuning.memory_ms and now -% e.nextStepAt < 0x8000_0000) {
                    if (step(g, bd, e, now)) {
                        e.nextStepAt = now +% t.step_ms;
                        const quiet = if (f.lastAttackWaveAt) |a| now -% a < tuning.step_quiet_ms else false;
                        if (los and !quiet) if (bd.scene) |s| s.playEnemyStepSound(g, e.obj);
                    }
                }
            },
            .windup => if (now -% e.until < 0x8000_0000) {
                if (los and d <= t.reach) strike(g, bd, e, now);
                e.state = .chase;
                e.cooldownUntil = now +% tuning.cooldown_ms;
            },
            .dying, .dead => {},
        }
    }
    if (bd.lives != lives_before) {
        f.respawning = true;
        if (bd.scene) |s| s.onLifeLost(g);
    }
    f.lives = bd.lives;
    if (f.overlay or probe) log(g, bd);
}

/// The kills' flash: queues each dying enemy (its cell is empty) for this frame. Called by
/// `sprites.flush`.
pub fn queueDying(g: *Game, q: *SpriteQueue, bd: *Backdrop) void {
    if (g.fair.bd != bd) return;
    for (g.fair.enemies[0..g.fair.count]) |*e| {
        if (e.state != .dying) continue;
        const dx = @as(i32, e.col) * 32 + 16 - bd.playerX;
        const dy = @as(i32, e.row) * 32 + 16 - bd.playerY;
        const d: i32 = @intFromFloat(@sqrt(@as(f64, @floatFromInt(dx * dx + dy * dy))));
        if (sees(bd, e)) _ = sprites.insert(q, e.row, e.col, @truncate(bd.viewAngle), @intCast(@min(d, 0x7fff)), e.obj);
    }
}

pub const Look = struct { white: bool };

/// The sprite draw of the enemy queued in (row, col): its place (between its cells while it
/// walks), its frame; null if no instance is there (the draw keeps the cell's centre).
pub fn placeForDraw(g: *Game, bd: *Backdrop, row: i16, col: i16, obj: *Object) ?Look {
    if (g.fair.bd != bd) return null;
    const now = g.plat.ticks();
    for (g.fair.enemies[0..g.fair.count]) |*e| {
        if (e.obj != obj or e.row != row or e.col != col or e.state == .dead) continue;
        const t = tuning.of(e.kind);
        var x: i32 = @as(i32, e.col) * 32 + 16;
        var y: i32 = @as(i32, e.row) * 32 + 16;
        if (e.walking(now, t)) {
            const p: i32 = @intCast(now -% e.stepAt);
            const ms: i32 = @intCast(t.step_ms);
            x += @divTrunc((@as(i32, e.fromCol) - e.col) * 32 * (ms - p), ms);
            y += @divTrunc((@as(i32, e.fromRow) - e.row) * 32 * (ms - p), ms);
        }
        obj.worldX = @intCast(x);
        obj.worldY = @intCast(y);
        const n = position.frameCount(obj);
        if (e.state == .windup or e.state == .dying) {
            obj.curFrame = n - 1;
        } else {
            const walk_frames: u32 = if (t.attacks and n > 1) @intCast(n - 1) else @intCast(n);
            obj.curFrame = @intCast((now -% e.animAt) / tuning.anim_ms % walk_frames);
        }
        return .{ .white = e.state == .dying };
    }
    return null;
}

/// A white copy of a sprite strip's bits (every pixel but the transparent key), made once.
pub fn whiteBits(g: *Game, bd: *Backdrop, src: *const object.Dib) []const u8 {
    for (&g.fair.whites) |*w| {
        if (w.*) |x| {
            if (x.src == src) return x.bits;
            continue;
        }
        const bits = g.local().dupe(u8, src.bits) catch return src.bits;
        const white = nearest(bd, 0xffffff, g.spriteKey);
        for (bits) |*p| {
            if (p.* != g.spriteKey) p.* = white;
        }
        w.* = .{ .src = src, .bits = bits };
        return bits;
    }
    return src.bits;
}

/// The palette entry nearest `rgb` (0xRRGGBB), never `avoid`.
fn nearest(bd: *const Backdrop, rgb: u32, avoid: u8) u8 {
    const r: i32 = @intCast(rgb >> 16 & 0xff);
    const gr: i32 = @intCast(rgb >> 8 & 0xff);
    const b: i32 = @intCast(rgb & 0xff);
    var best: u8 = 0;
    var best_d: i32 = std.math.maxInt(i32);
    for (bd.bmiColors, 0..) |q, i| {
        if (i == avoid) continue;
        const d = (r - q.red) * (r - q.red) + (gr - q.green) * (gr - q.green) + (b - q.blue) * (b - q.blue);
        if (d < best_d) {
            best_d = d;
            best = @intCast(i);
        }
    }
    return best;
}

/// The face's frame a step worse for `face_ms` after a hit (`hud.drawHud`).
pub fn faceFrame(g: *Game, frame: i16, count: i16) i16 {
    if (!active(g)) return frame;
    const at = g.fair.hurtAt orelse return frame;
    if (g.plat.ticks() -% at >= tuning.face_ms) return frame;
    return @min(frame + 1, count - 1);
}

/// After the hands, before the view goes to the window: the red border of a hit and the
/// debug overlay.
pub fn drawOverlay(g: *Game, bd: *Backdrop) void {
    if (!active(g)) return;
    const f = &g.fair;
    const s = bd.surface();
    if (f.hurtAt) |at| {
        if (g.plat.ticks() -% at < tuning.border_ms) {
            const l = bd.viewX;
            const t = bd.viewY;
            const r = bd.viewX + bd.viewW;
            const b = bd.viewY + bd.viewH;
            const w = tuning.border_px;
            const red: u32 = 0x0000ff; // COLORREF: red
            hud.fillRect(s, red, l, t, r, t + w);
            hud.fillRect(s, red, l, b - w, r, b);
            hud.fillRect(s, red, l, t, l + w, b);
            hud.fillRect(s, red, r - w, t, r, b);
        }
    }
    if (f.overlay and f.bd == bd) {
        var buf: [96]u8 = undefined;
        const style: platform.TextStyle = .{ .color = 0x0000ffff, .bk_mode = .transparent };
        const n = nearestEnemy(g, bd);
        const line = if (n) |e|
            std.fmt.bufPrint(&buf, "{t} {d},{d} {t} d{d}  hp {d} lives {d}  hits {d}/{d}", .{ e.kind, e.col, e.row, e.state, cheb(e.row, e.col, bd.playerY >> 5, bd.playerX >> 5), bd.health, bd.lives, f.hits, f.damage }) catch buf[0..0]
        else
            std.fmt.bufPrint(&buf, "no enemy  hp {d} lives {d}", .{ bd.health, bd.lives }) catch buf[0..0];
        _ = g.plat.textOut(s, style, bd.viewX + 6, bd.viewY + 6, line);
    }
}

fn nearestEnemy(g: *Game, bd: *Backdrop) ?*Enemy {
    var best: ?*Enemy = null;
    var best_d: i32 = std.math.maxInt(i32);
    for (g.fair.enemies[0..g.fair.count]) |*e| {
        if (!e.alive()) continue;
        const d = cheb(e.row, e.col, bd.playerY >> 5, bd.playerX >> 5);
        if (d < best_d) {
            best_d = d;
            best = e;
        }
    }
    return best;
}

/// F9 (Debug builds): the overlay and the per-tick log.
pub const vk_f9: u16 = 0x78;
pub const debug_build = builtin.mode == .debug;
/// `zig build -Djardim-probe` (`tools/jardim_plan.py`): the log from the start, with the map's
/// objects and doors when they change, and no motion frames.
pub const probe = build_options.jardim_probe;

pub fn toggleOverlay(g: *Game) void {
    g.fair.overlay = !g.fair.overlay;
}

/// One stderr line per game tick while the overlay is on (Debug, not the web): the player and
/// every enemy that is not idle.
fn log(g: *Game, bd: *Backdrop) void {
    if (!(debug_build or probe) or builtin.target.cpu.arch.isWasm()) return;
    var buf: [4096]u8 = undefined;
    var w = std.Io.Writer.fixed(&buf);
    const now = g.plat.ticks();
    const weapon = if (bd.hands) |h| h.curStrip else 0;
    w.print("[{d}] fair player {d},{d} a{d} hp {d} lives {d} ammo {d} weapon {d} shot {d} score {d} level {d} hits {d}/{d} |", .{ now, bd.playerX, bd.playerY, bd.viewAngle, bd.health, bd.lives, bd.ammo, weapon, bd.shotInFlight, bd.score, bd.level, g.fair.hits, g.fair.damage }) catch {};
    for (g.fair.enemies[0..g.fair.count]) |*e| {
        if (e.state == .dead or (e.state == .idle and !probe)) continue;
        w.print(" {t}@{d},{d}:{t}", .{ e.kind, e.col, e.row, e.state }) catch break;
    }
    std.debug.print("{s}\n", .{w.buffered()});
    if (probe) logMap(g, bd, now);
}

/// The probe's map: every object's cell and kind letter, and the closed doors, when changed.
fn logMap(g: *Game, bd: *Backdrop, now: u32) void {
    const s = bd.scene orelse return;
    var buf: [8192]u8 = undefined;
    var w = std.Io.Writer.fixed(&buf);
    w.print("[{d}] map", .{now}) catch {};
    for (0..world.map_rows) |r| {
        for (0..world.map_cols) |c| {
            const o = bd.objectRows[r][c] orelse continue;
            const k: u8 = if (o == s.enemyA) 'A' else if (o == s.enemyB) 'B' else if (o == s.goal) 'F' else if (o == s.crossbow) 'C' else if (o == s.secondWeapon) 'W' else if (o == s.medkit) 'M' else if (o == s.beer) 'R' else if (o == s.snack) 'S' else if (o == s.arrows) 'a' else if (o == s.bombs) 'b' else if (o == bd.shot) '*' else '?';
            w.print(" {d},{d}{c}", .{ c, r, k }) catch {};
        }
    }
    w.print(" | doors", .{}) catch {};
    for (0..world.map_rows) |r| {
        for (0..world.map_cols) |c| {
            if (bd.wallRows[r][c] >= 9) w.print(" {d},{d}", .{ c, r }) catch {};
        }
    }
    const h = std.hash.Wyhash.hash(0, w.buffered()[std.mem.indexOfScalar(u8, w.buffered(), ' ').?..]);
    if (h == g.fair.mapHash) return;
    g.fair.mapHash = h;
    std.debug.print("{s}\n", .{w.buffered()});
}

/// The respawn (`labyrinth_scene.respawn`): before `placeObjects`, the living enemies leave
/// their cells.
pub fn beforeRespawn(g: *Game, bd: *Backdrop) void {
    if (!active(g) or g.fair.bd != bd) return;
    for (g.fair.enemies[0..g.fair.count]) |*e| {
        const slot = &bd.objectRows[@intCast(e.row)][@intCast(e.col)];
        if (slot.* == e.obj) slot.* = null;
    }
}

/// After `placeObjects`: every enemy (the killed ones too, as in the original) at home, idle,
/// with its state rebuilt.
pub fn afterRespawn(g: *Game, bd: *Backdrop) void {
    if (!active(g) or g.fair.bd != bd) return;
    const f = &g.fair;
    const now = g.plat.ticks();
    for (f.enemies[0..f.count]) |*e| {
        const home = &bd.objectRows[@intCast(e.homeRow)][@intCast(e.homeCol)];
        home.* = e.obj;
        e.* = .{ .obj = e.obj, .kind = e.kind, .homeRow = e.homeRow, .homeCol = e.homeCol, .row = e.homeRow, .col = e.homeCol, .fromRow = e.homeRow, .fromCol = e.homeCol, .animAt = e.animAt };
    }
    f.respawning = false;
    f.invulnUntil = now;
    f.lives = bd.lives;
}

// ---- tests ----

const testing = std.testing;

test "the numbers" {
    const t = &tuning;
    try testing.expectEqual(@as(u32, 600), t.of(.bussuf).step_ms);
    try testing.expectEqual(@as(u32, 800), t.of(.seios).step_ms);
    try testing.expectEqual(@as(u32, 800), t.of(.bicho).step_ms);
    try testing.expectEqual(@as(u32, 450), t.of(.alemao).step_ms);
    try testing.expectEqual(@as(i16, 4), t.of(.alemao).reach);
    try testing.expectEqual(@as(i16, 10), t.of(.siri).damage);
    try testing.expect(!t.of(.goal).attacks);
}

test "a clear line stops at walls" {
    var bd: Backdrop = .{};
    bd.wallRows[3][5] = 1;
    try testing.expect(clearLine(&bd, 16, 16 + 3 * 32, 16 + 4 * 32, 16 + 3 * 32));
    try testing.expect(!clearLine(&bd, 16, 16 + 3 * 32, 16 + 8 * 32, 16 + 3 * 32));
}
