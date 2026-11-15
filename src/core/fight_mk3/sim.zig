//! The fight's simulation: two fighters on a fixed time step (`tables.tick_hz`),
//! deterministic, no drawing and no clock of its own (`Match` in
//! `fight_mk3.zig` feeds it time). Mortal Kombat 3's mechanics from the
//! leaked UMK3 (3DO) source, as docs/fights/MK3.md lists them: walk, crouch,
//! jumps with no air control, four punches and kicks (standing, crouching,
//! jumping), the uppercut and the sweep, a block button, chip damage, hit
//! and block stun, pushback, knockdown and get-up, facing that flips when
//! fighters cross, walls, KO.
//!
//! A character knows no move data: hurt and hit boxes come from the frame
//! each fighter is showing (`Character`), so the art decides what touches.
//! Positions are fixed point, 1/`fp` px, on the 640-px screen; y is the
//! height above the ground, up positive.

const std = @import("std");
const character = @import("character.zig");
const Character = character.Character;
const Anim = character.Anim;
const t = @import("tables.zig");

pub const fp: i32 = 256;

/// One tick's input from a fighter's controller: held directions and the
/// block button, and the buttons pressed since the last tick (`press`).
pub const Input = struct {
    left: bool = false,
    right: bool = false,
    up: bool = false,
    down: bool = false,
    block: bool = false,
    /// Pressed since the last tick (a tap between ticks is not lost).
    lp: bool = false,
    hp: bool = false,
    lk: bool = false,
    hk: bool = false,
};

pub const Move = t.Move;

pub const State = enum {
    idle,
    crouch,
    walk,
    block,
    attack,
    air,
    air_attack,
    hit,
    blockstun,
    /// Thrown or struck off its feet: the fall's arc.
    fall,
    down,
    getup,
    win,
};

pub const Event = enum { whiff_swing, hit_light, hit_heavy, block, knockdown, ko, land };

pub const Fighter = struct {
    /// The feet anchor and the height above the ground, fixed point.
    x: i32,
    y: i32 = 0,
    vx: i32 = 0,
    vy: i32 = 0,
    /// The previous tick's, for interpolating the picture.
    px: i32 = 0,
    py: i32 = 0,
    /// +1 facing right, -1 left.
    face: i8 = 1,
    state: State = .idle,
    /// Ticks in this state.
    st: u16 = 0,
    /// Ticks the state lasts (stun, down, getup; attacks use `move`).
    len: u16 = 0,
    anim: Anim = .stance,
    /// Ticks since `anim` began; `anim_len` > 0 stretches the clip over that
    /// many ticks, 0 plays it in real time.
    anim_t: u16 = 0,
    anim_len: u16 = 0,
    move: Move = .lp,
    /// The attack has connected (or been blocked): once per move.
    spent: bool = false,
    /// Jump direction relative to the facing at take-off: -1, 0, 1.
    jump_dir: i8 = 0,
    crouching: bool = false,
    health: i16 = t.health_max,
    /// Pushback still to be applied: fixed-point px and ticks left.
    push: i32 = 0,
    push_left: u16 = 0,
    /// A won round's winner.
    winner: bool = false,
    /// Hits taken in a row without regaining control (a combo's count).
    combo: u8 = 0,

    pub fn grounded(f: *const Fighter) bool {
        return f.y == 0 and f.vy == 0;
    }
};

pub const Sim = struct {
    chars: [2]*const Character,
    f: [2]Fighter,
    tick: u32 = 0,
    over: bool = false,
    /// 0 or 1 when somebody won by KO.
    ko_winner: ?u1 = null,
    held: [2]Input = .{ .{}, .{} },
    latch: [2]Input = .{ .{}, .{} },
    latch_age: [2]u8 = .{ 0, 0 },
    events: [16]struct { kind: Event, who: u1 } = undefined,
    n_events: u8 = 0,
    /// Ticks since the KO (the end of the round waits for the fall).
    since_over: u16 = 0,
    /// Tuning statistics: landed hits and blocked hits by attacker and move.
    landed: [2][t.moves.len]u16 = @splat(@splat(0)),
    blocked: [2][t.moves.len]u16 = @splat(@splat(0)),

    pub fn init(a: *const Character, b: *const Character) Sim {
        var s: Sim = .{
            .chars = .{ a, b },
            .f = .{ .{ .x = t.start_x[0] * fp, .face = 1 }, .{ .x = t.start_x[1] * fp, .face = -1 } },
        };
        for (&s.f) |*f| {
            f.px = f.x;
            f.py = f.y;
        }
        return s;
    }

    /// Records what a controller did: held directions, taps latched until
    /// the next tick.
    pub fn setHeld(s: *Sim, who: u1, i: Input) void {
        s.held[who] = .{ .left = i.left, .right = i.right, .up = i.up, .down = i.down, .block = i.block };
        s.latch[who].lp = s.latch[who].lp or i.lp;
        s.latch[who].hp = s.latch[who].hp or i.hp;
        s.latch[who].lk = s.latch[who].lk or i.lk;
        s.latch[who].hk = s.latch[who].hk or i.hk;
    }

    fn emit(s: *Sim, kind: Event, who: u1) void {
        if (s.n_events < s.events.len) {
            s.events[s.n_events] = .{ .kind = kind, .who = who };
            s.n_events += 1;
        }
    }

    pub fn takeEvents(s: *Sim, out: []@TypeOf(s.events[0])) usize {
        const n = @min(out.len, s.n_events);
        @memcpy(out[0..n], s.events[0..n]);
        s.n_events = 0;
        return n;
    }

    // ---- boxes ---------------------------------------------------------

    /// The frame `f` shows now (the clip's index into `Character.frames`).
    pub fn frameOf(s: *const Sim, who: u1) *const character.Frame {
        const c = s.chars[who];
        const f = &s.f[who];
        const clip = c.clip(f.anim);
        return c.frame(clip.frames[frameIndex(s, who)]);
    }

    pub fn frameIndex(s: *const Sim, who: u1) usize {
        const c = s.chars[who];
        const f = &s.f[who];
        const clip = c.clip(f.anim);
        const ms: u32 = ticksToMs(f.anim_t);
        if (f.state == .attack or f.state == .air_attack) {
            const d = t.moves[@backingInt(f.move)];
            return attackFrame(clip, f.anim_t, d.startup, d.active, d.recovery);
        }
        if (f.anim_len > 0) {
            const total = clip.totalMs();
            const scaled: u32 = @intCast(@divTrunc(@as(u64, f.anim_t) * total, f.anim_len));
            return character.frameAtMs(clip, @min(scaled, total -| 1));
        }
        return character.frameAtMs(clip, ms);
    }

    /// A world-space rectangle (fixed-point px; y is screen-down from the
    /// ground, so negative above it).
    pub const Rect = struct { x0: i32, y0: i32, x1: i32, y1: i32 };

    fn toWorld(s: *const Sim, who: u1, b: character.Box) Rect {
        const f = &s.f[who];
        const sc: i32 = s.chars[who].scale() * fp;
        const bx0: i32 = b[0];
        const bx1: i32 = b[2];
        const by0: i32 = b[1];
        const by1: i32 = b[3];
        const x0 = if (f.face > 0) f.x + bx0 * sc else f.x - bx1 * sc;
        const x1 = if (f.face > 0) f.x + bx1 * sc else f.x - bx0 * sc;
        return .{ .x0 = x0, .x1 = x1, .y0 = -f.y + by0 * sc, .y1 = -f.y + by1 * sc };
    }

    pub fn hurtBox(s: *const Sim, who: u1) ?Rect {
        const fr = s.frameOf(who);
        const b = fr.hurt orelse return null;
        return s.toWorld(who, b);
    }

    pub fn hitBox(s: *const Sim, who: u1) ?Rect {
        const f = &s.f[who];
        if (f.state != .attack and f.state != .air_attack) return null;
        if (f.move == .throw) return null;
        const d = t.moves[@backingInt(f.move)];
        if (f.anim_t < d.startup or f.anim_t >= @as(u16, d.startup) + d.active) return null;
        const fr = s.frameOf(who);
        const b = fr.hit orelse return null;
        return s.toWorld(who, b);
    }

    fn overlap(a: Rect, b: Rect) bool {
        return a.x0 < b.x1 and b.x0 < a.x1 and a.y0 < b.y1 and b.y0 < a.y1;
    }

    // ---- control -------------------------------------------------------

    fn setAnim(f: *Fighter, a: Anim, len: u16) void {
        f.anim = a;
        f.anim_t = 0;
        f.anim_len = len;
    }

    fn enter(f: *Fighter, st: State, len: u16) void {
        f.state = st;
        f.st = 0;
        f.len = len;
    }

    fn canAct(f: *const Fighter) bool {
        return switch (f.state) {
            .idle, .crouch, .walk, .block => true,
            else => false,
        };
    }

    fn forward(f: *const Fighter) i32 {
        return f.face;
    }

    fn control(s: *Sim, who: u1) void {
        const f = &s.f[who];
        const inp = s.held[who];
        const lat = s.latch[who];
        if (canAct(f)) {
            s.latch[who] = .{};
            s.latch_age[who] = 0;
        } else if (f.state != .air) {
            // A tap while busy waits a few ticks for the move to end.
            s.latch_age[who] +|= 1;
            if (s.latch_age[who] > t.input_buffer_ticks) s.latch[who] = .{};
        }
        if (s.over and f.state != .win and f.state != .fall and f.state != .down) {
            if (f.grounded() and canAct(f)) {
                f.vx = 0;
                f.crouching = false;
                setIdle(f);
            }
            return;
        }
        if (!canAct(f)) return;
        // Block (standing, or crouching with down held): no moving.
        if (inp.block) {
            const crouch = inp.down;
            if (f.state != .block or f.crouching != crouch) {
                f.crouching = crouch;
                enter(f, .block, 0);
                setAnim(f, if (crouch) .block_lo else .block_hi, 0);
            }
            f.vx = 0;
            return;
        }
        if (f.state == .block) {
            f.crouching = false;
            enter(f, .idle, 0);
            setAnim(f, .stance, 0);
        }
        // Jump.
        if (inp.up) {
            const dir: i8 = if (inp.right) (if (f.face > 0) 1 else -1) else if (inp.left) (if (f.face > 0) -1 else 1) else 0;
            s.startJump(who, dir);
            return;
        }
        // Attacks.
        const crouch = inp.down;
        const back = if (f.face > 0) inp.left else inp.right;
        const close = s.closeEnough(who);
        const pick: ?Move = if (lat.lp) (if (crouch) Move.c_lp else if (close) Move.throw else Move.lp) else if (lat.hp) (if (crouch) Move.uppercut else Move.hp) else if (lat.lk) (if (crouch) Move.c_lk else if (back) Move.sweep else Move.lk) else if (lat.hk) (if (crouch) Move.sweep else if (back) Move.roundhouse else Move.hk) else null;
        if (pick) |m| {
            f.vx = 0;
            f.crouching = crouch;
            s.startAttack(who, m);
            return;
        }
        if (crouch) {
            if (f.state != .crouch) {
                f.crouching = true;
                enter(f, .crouch, 0);
                setAnim(f, .crouch, 0);
            }
            f.vx = 0;
            return;
        }
        f.crouching = false;
        const dir: i32 = (if (inp.right) @as(i32, 1) else 0) - (if (inp.left) @as(i32, 1) else 0);
        if (dir != 0) {
            const fwd = dir == f.face;
            const want: Anim = if (fwd) .walk_f else .walk_b;
            if (f.state != .walk or f.anim != want) {
                enter(f, .walk, 0);
                setAnim(f, want, 0);
            }
            f.vx = dir * (if (fwd) t.walk_fwd else t.walk_back);
        } else {
            f.vx = 0;
            if (f.state != .idle) {
                enter(f, .idle, 0);
                setAnim(f, .stance, 0);
            }
        }
    }

    /// Close enough, and the other on the ground, for LP to be a throw.
    fn closeEnough(s: *const Sim, who: u1) bool {
        const f = &s.f[who];
        const o = &s.f[1 - who];
        const gap = @abs(o.x - f.x);
        return o.grounded() and gap <= @as(u32, @intCast(t.throw_range * fp));
    }

    /// The throw connects at its `startup` tick: the other still in reach,
    /// on his feet, not in stun, not holding away.
    fn tryThrow(s: *Sim, a: u1) void {
        const d: u1 = 1 - a;
        const af = &s.f[a];
        const df = &s.f[d];
        af.spent = true;
        const stunned = switch (df.state) {
            .idle, .crouch, .walk, .block, .attack => false,
            else => true,
        };
        const away = if (df.face > 0) s.held[d].left else s.held[d].right;
        if (stunned or away or !s.closeEnough(a) or untouchable(df)) return;
        const m = t.moves[@backingInt(Move.throw)];
        df.health -= @intCast(m.damage);
        df.vx = 0;
        df.combo = 0;
        df.face = -af.face;
        if (df.health <= 0) {
            df.health = 0;
            s.over = true;
            s.ko_winner = a;
            s.emit(.ko, d);
        } else s.emit(.knockdown, d);
        s.knock(a, d, m);
    }

    fn setIdle(f: *Fighter) void {
        enter(f, .idle, 0);
        setAnim(f, .stance, 0);
    }

    /// `dir` is relative to the facing: 1 toward the opponent.
    fn startJump(s: *Sim, who: u1, dir: i8) void {
        const f = &s.f[who];
        f.vy = t.jump_vy;
        f.y = 1;
        f.jump_dir = dir;
        f.vx = @as(i32, dir) * f.face * t.jump_vx;
        f.crouching = false;
        f.spent = false;
        enter(f, .air, 0);
        setAnim(f, if (dir > 0) .jump_f else if (dir < 0) .jump_b else .jump_u, t.airTicks());
    }

    fn startAttack(s: *Sim, who: u1, m: Move) void {
        const f = &s.f[who];
        const d = t.moves[@backingInt(m)];
        f.move = m;
        f.spent = false;
        enter(f, .attack, 0);
        setAnim(f, d.anim, d.startup + d.active + d.recovery);
        s.emit(.whiff_swing, who);
    }

    fn startAirAttack(s: *Sim, who: u1, m: Move) void {
        const f = &s.f[who];
        const d = t.moves[@backingInt(m)];
        f.move = m;
        f.spent = false;
        f.state = .air_attack;
        f.st = 0;
        setAnim(f, d.anim, d.startup + d.active + d.recovery);
        s.emit(.whiff_swing, who);
    }

    // ---- one tick ------------------------------------------------------

    pub fn step(s: *Sim) void {
        for (&s.f) |*f| {
            f.px = f.x;
            f.py = f.y;
        }
        s.control(0);
        s.control(1);
        // Air attacks start from the air state.
        for ([2]u1{ 0, 1 }) |w| s.airControl(w);
        s.progress(0);
        s.progress(1);
        s.collide();
        s.faceAndSeparate();
        for (&s.f) |*f| {
            f.st +|= 1;
            f.anim_t +|= 1;
        }
        if (s.over) {
            s.since_over +|= 1;
            s.endPoses();
        }
        s.tick +%= 1;
    }

    /// What the buttons do in the air (one attack a jump).
    fn airControl(s: *Sim, who: u1) void {
        const f = &s.f[who];
        if (f.state != .air or s.over) return;
        const lat = s.latch[who];
        s.latch[who] = .{};
        const m: ?Move = if (lat.lp) Move.j_lp else if (lat.hp) Move.j_hp else if (lat.lk) Move.j_lk else if (lat.hk) Move.j_hk else null;
        if (m) |mv| s.startAirAttack(who, mv);
    }

    fn progress(s: *Sim, who: u1) void {
        const f = &s.f[who];
        // Knock-back still to apply.
        if (f.push_left > 0) {
            const stepv = @divTrunc(f.push, @as(i32, f.push_left));
            f.x += stepv;
            f.push -= stepv;
            f.push_left -= 1;
        }
        f.x += f.vx;
        if (f.y > 0 or f.vy != 0) {
            // As the source: gravity first, then the move.
            f.vy -= t.gravity;
            f.y += f.vy;
            if (f.y <= 0 and f.vy < 0) {
                f.y = 0;
                f.vy = 0;
                f.vx = 0;
                s.emit(.land, who);
                if (f.state == .air or f.state == .air_attack) {
                    f.crouching = false;
                    enter(f, .idle, 0);
                    setAnim(f, .stance, 0);
                }
            }
        }
        switch (f.state) {
            .attack, .air_attack => {
                const d = t.moves[@backingInt(f.move)];
                if (f.move == .throw and f.state == .attack and !f.spent and f.anim_t >= d.startup) s.tryThrow(who);
                if (f.state == .attack and f.anim_t >= d.startup + d.active + d.recovery) {
                    enter(f, .idle, 0);
                    setAnim(f, .stance, 0);
                }
            },
            .hit => if (f.st >= f.len) {
                f.combo = 0;
                enter(f, .idle, 0);
                setAnim(f, .stance, 0);
            },
            .blockstun => if (f.st >= f.len) {
                enter(f, .idle, 0);
                setAnim(f, .stance, 0);
            },
            .fall => if (f.st >= f.len and f.grounded()) {
                f.vx = 0;
                f.combo = 0;
                enter(f, .down, t.down_ticks);
                setAnim(f, .down, 0);
            },
            .down => if (f.st >= f.len and !s.over) {
                enter(f, .getup, t.getup_ticks);
                setAnim(f, .crouch, 0);
            },
            .getup => if (f.st >= f.len) {
                f.crouching = false;
                enter(f, .idle, 0);
                setAnim(f, .stance, 0);
            },
            else => {},
        }
    }

    fn inBlock(f: *const Fighter) bool {
        return f.state == .block or f.state == .blockstun;
    }

    fn untouchable(f: *const Fighter) bool {
        return switch (f.state) {
            .fall, .down, .win => true,
            .getup => f.st < t.getup_invuln,
            else => false,
        };
    }

    fn collide(s: *Sim) void {
        var hit: [2]bool = .{ false, false };
        for ([2]u1{ 0, 1 }) |a| {
            const af = &s.f[a];
            if (af.spent) continue;
            const d: u1 = 1 - a;
            if (untouchable(&s.f[d])) continue;
            const hb = s.hitBox(a) orelse continue;
            const ub = s.hurtBox(d) orelse continue;
            if (overlap(hb, ub)) hit[a] = true;
        }
        for ([2]u1{ 0, 1 }) |a| if (hit[a]) s.resolve(a, 1 - a);
    }

    fn resolve(s: *Sim, a: u1, d: u1) void {
        const af = &s.f[a];
        const df = &s.f[d];
        const m = t.moves[@backingInt(af.move)];
        af.spent = true;
        const airborne = !df.grounded();
        defer s.landed[a][@backingInt(af.move)] +|= 1;
        if (inBlock(df) and !airborne and !m.unblockable and t.blocks(df.crouching, m.low)) {
            const chip: i16 = @intCast(@max(1, @divTrunc(@as(i32, m.damage) * t.chip_pct, 100)));
            df.health = @max(1, df.health - chip);
            enter(df, .blockstun, m.blockstun);
            setAnim(df, if (df.crouching) .block_lo else .block_hi, 0);
            df.vx = 0;
            s.pushOff(a, d, m.block_push);
            s.blocked[a][@backingInt(af.move)] +|= 1;
            s.landed[a][@backingInt(af.move)] -|= 1;
            s.emit(.block, d);
            return;
        }
        df.health -= @intCast(m.damage);
        df.combo +|= 1;
        const was_air = airborne;
        df.vx = 0;
        if (df.health <= 0) {
            df.health = 0;
            s.knock(a, d, m);
            s.over = true;
            s.ko_winner = a;
            s.emit(.ko, d);
            return;
        }
        if (m.knockdown or was_air) {
            s.knock(a, d, m);
            s.emit(.knockdown, d);
        } else {
            df.crouching = df.crouching and df.state != .attack;
            enter(df, .hit, m.hitstun);
            setAnim(df, if (df.crouching) .hit_lo else .hit_hi, m.hitstun);
            s.pushOff(a, d, m.hit_push);
            s.emit(if (m.damage >= t.heavy_damage) .hit_heavy else .hit_light, d);
        }
    }

    fn knock(s: *Sim, a: u1, d: u1, m: t.MoveData) void {
        const df = &s.f[d];
        df.crouching = false;
        if (df.grounded()) {
            enter(df, .fall, m.fall_ticks);
            setAnim(df, .fall, m.fall_ticks);
            s.pushOff(a, d, m.knock_push);
            return;
        }
        // Struck in the air: thrown back with a small hop (MK3: vx 3.5,
        // vy -6, gravity 0.5 arcade), the fall plays out where it is.
        const dir: i32 = if (df.x >= s.f[a].x) 1 else -1;
        df.vx = dir * t.air_hit_vx;
        df.vy = t.air_hit_vy;
        df.push_left = 0;
        // The fall's picture plays over the flight and a short slide.
        var n: u16 = 0;
        var y = df.y;
        var vy = df.vy;
        while (n < 200) : (n += 1) {
            vy -= t.gravity;
            y += vy;
            if (y <= 0) break;
        }
        enter(df, .fall, n + 8);
        setAnim(df, .fall, n + 8);
    }

    /// Pushes `d` away from `a` by `px` over a few ticks; what a wall will
    /// not give moves the attacker back instead (the corner rule).
    fn pushOff(s: *Sim, a: u1, d: u1, px: i32) void {
        const df = &s.f[d];
        const af = &s.f[a];
        const dir: i32 = if (df.x >= af.x) 1 else -1;
        const want = px * fp;
        const room = if (dir > 0) t.arena_max * fp - df.x else df.x - t.arena_min * fp;
        const given = @min(want, @max(0, room));
        df.push = dir * given;
        df.push_left = t.push_ticks;
        const rest = want - given;
        if (rest > 0) {
            af.push = -dir * rest;
            af.push_left = t.push_ticks;
        }
    }

    fn faceAndSeparate(s: *Sim) void {
        for ([2]u1{ 0, 1 }) |w| {
            const f = &s.f[w];
            const o = &s.f[1 - w];
            const turns = switch (f.state) {
                .idle, .crouch, .walk, .block, .blockstun, .hit => f.grounded(),
                else => false,
            };
            if (turns and o.x != f.x) f.face = if (o.x > f.x) 1 else -1;
        }
        // Walls.
        for (&s.f) |*f| f.x = std.math.clamp(f.x, t.arena_min * fp, t.arena_max * fp);
        // Two fighters on the ground do not overlap; one in the air passes.
        const a = &s.f[0];
        const b = &s.f[1];
        if (a.grounded() and b.grounded()) {
            const gap = @abs(b.x - a.x);
            const need: i32 = t.min_sep * fp;
            if (gap < need) {
                // Eased apart (a landing inside the other is not a jump cut).
                const over = @min(need - @as(i32, @intCast(gap)), t.separate_per_tick * fp);
                const dir: i32 = if (b.x >= a.x) 1 else -1;
                // The one that moves yields: split, a wall gives it all to the other.
                var ha = @divTrunc(over, 2);
                var hb = over - ha;
                if (dir > 0) {
                    if (a.x - ha < t.arena_min * fp) {
                        hb += ha - (a.x - t.arena_min * fp);
                        ha = a.x - t.arena_min * fp;
                    }
                    if (b.x + hb > t.arena_max * fp) {
                        ha += hb - (t.arena_max * fp - b.x);
                        hb = t.arena_max * fp - b.x;
                    }
                    a.x -= ha;
                    b.x += hb;
                } else {
                    if (a.x + ha > t.arena_max * fp) {
                        hb += ha - (t.arena_max * fp - a.x);
                        ha = t.arena_max * fp - a.x;
                    }
                    if (b.x - hb < t.arena_min * fp) {
                        ha += hb - (b.x - t.arena_min * fp);
                        hb = b.x - t.arena_min * fp;
                    }
                    a.x += ha;
                    b.x -= hb;
                }
            }
        }
    }

    fn endPoses(s: *Sim) void {
        const w = s.ko_winner orelse return;
        const f = &s.f[w];
        if (s.since_over > t.win_after_ticks and f.winner == false and f.grounded() and
            (f.state == .idle or f.state == .crouch or f.state == .walk or f.state == .block))
        {
            f.winner = true;
            enter(f, .win, 0);
            setAnim(f, .win, 0);
            f.vx = 0;
        }
    }

    /// The round ended on the clock: `winner` takes the win pose.
    pub fn finishOnTime(s: *Sim, winner: u1) void {
        s.over = true;
        s.ko_winner = null;
        const f = &s.f[winner];
        f.winner = true;
        if (f.grounded() and canAct(f)) {
            f.vx = 0;
            enter(f, .win, 0);
            setAnim(f, .win, 0);
        }
    }

    /// 0 .. 1: how much of the tick has passed (for the picture).
    pub fn lerpX(s: *const Sim, who: u1, alpha: i32) i32 {
        const f = &s.f[who];
        return f.px + @divTrunc((f.x - f.px) * alpha, 256);
    }

    pub fn lerpY(s: *const Sim, who: u1, alpha: i32) i32 {
        const f = &s.f[who];
        return f.py + @divTrunc((f.y - f.py) * alpha, 256);
    }
};

/// Ticks to ms at the fixed rate.
pub fn ticksToMs(n: u32) u32 {
    return @intCast(@divTrunc(@as(u64, n) * 1000, t.tick_hz));
}

/// The clip frame shown `tick` ticks into an attack of `s` startup, `a`
/// active and `r` recovery ticks: the clip's frames before its active range
/// spread over the startup, the active ones over the active window, the
/// rest over the recovery (each in proportion to the art's own timing).
pub fn attackFrame(clip: *const character.Clip, tick: u16, s: u16, a: u16, r: u16) usize {
    const n = clip.frames.len;
    const act = clip.active orelse return @min(n - 1, @as(usize, tick) * n / @max(1, s + a + r));
    const a0: usize = act[0];
    const a1: usize = act[1];
    if (tick < s) return spread(clip, 0, a0, tick, s);
    if (tick < s + a) return spread(clip, a0, a1 + 1, tick - s, a);
    return spread(clip, a1 + 1, n, @min(tick - s - a, r -| 1), r);
}

/// The frame in [lo, hi) of `clip` for `k` of `of` ticks, weighted by the
/// frames' own ms. An empty range gives its edge.
fn spread(clip: *const character.Clip, lo: usize, hi: usize, k: u16, of: u16) usize {
    if (hi <= lo) return @min(lo, clip.frames.len - 1);
    var total: u64 = 0;
    for (clip.ms[lo..hi]) |m| total += m;
    if (total == 0 or of == 0) return lo;
    var want: u64 = @as(u64, k) * total / of;
    for (lo..hi) |i| {
        if (want < clip.ms[i]) return i;
        want -= clip.ms[i];
    }
    return hi - 1;
}
