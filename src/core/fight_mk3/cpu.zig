//! The CPU fighter: MK3's drone (`MKDRONE.C`) at its lowest rung, `diff` 0
//! (docs/fights/MK3.md "CPU"), as the decision tables of the source say:
//! it re-decides whenever it has finished an action, by how far the human
//! is (bands of 110, 192 and 384 px); it may stand in its stance (20% of the
//! decisions, twice a round); it never attacks a human in hit stun; it reacts
//! to only 15% of the human's new attacks, blocking 90% of those and
//! countering 10%, and counters every time a move has hit it three times in
//! its last six hits; no specials, no running, no combos, no throw reversal.
//! It reads the sim's state like a human watching, never the keys.

const std = @import("std");
const sim_mod = @import("sim.zig");
const Sim = sim_mod.Sim;
const Input = sim_mod.Input;
const Move = sim_mod.Move;
const t = @import("tables.zig");

/// The pause after a strike (ticks): MK3's drone has none (it decides at
/// every action end); this keeps the diff-0 CPU slow enough for a beginner.
/// MK3 counters every time a move has hit it 3 times in its last 6 hits; here
/// only this often (a beginner mashing one button would be swept forever).
pub const anti_spam_pct: u32 = 60;
/// MK3's diff 0 reacts to 15% of the human's attacks; see MK3.md "CPU".
pub const react_pct: u32 = 30;
/// Stands in its stance at most this often a round (MK3: twice).
pub const max_hangouts: u8 = 1;
pub const pause_min: u16 = 2;
pub const pause_var: u32 = 8;

pub const Rng = struct {
    s: u32,

    pub fn next(r: *Rng) u32 {
        var x = r.s;
        x ^= x << 13;
        x ^= x >> 17;
        x ^= x << 5;
        r.s = x;
        return x;
    }

    /// 0 .. n-1
    pub fn below(r: *Rng, n: u32) u32 {
        return r.next() % n;
    }

    /// True `pct` times in 100.
    pub fn pct(r: *Rng, p: u32) bool {
        return r.below(100) < p;
    }
};

/// What the human is doing, for the reaction gate and the repeat counter.
pub const Act = enum { none, punch, kick, sweep, uppercut, roundhouse, throw, jump_attack };

pub fn actOf(f: *const sim_mod.Fighter) Act {
    if (f.state != .attack and f.state != .air_attack) return .none;
    return switch (f.move) {
        .lp, .hp, .c_lp => .punch,
        .lk, .hk, .c_lk => .kick,
        .sweep => .sweep,
        .uppercut => .uppercut,
        .roundhouse => .roundhouse,
        .throw => .throw,
        .j_lp, .j_hp, .j_lk, .j_hk => .jump_attack,
    };
}

const Plan = enum { think, pause, hangout, walk_in, walk_out, strike, jump_in, guard };

pub const Cpu = struct {
    rng: Rng,
    plan: Plan = .pause,
    left: u16 = 40,
    hangouts: u8 = 0,
    /// The strike plan: up to three moves, `n` of them, the next is `i`.
    moves: [3]Move = undefined,
    n: u8 = 0,
    i: u8 = 0,
    /// Walk before striking (ticks).
    walk_first: u16 = 0,
    crouch_guard: bool = false,
    air_kick: bool = false,
    prev_act: Act = .none,
    /// The human's last six hits on it (MK3's hit queue).
    hit_q: [6]Act = @splat(.none),
    was_hurt: bool = false,
    /// Statistics: what it did (tests, tuning).
    attacks: u32 = 0,

    pub fn init(seed: u32) Cpu {
        return .{ .rng = .{ .s = seed | 1 } };
    }

    fn dist(sim: *const Sim, who: u1) i32 {
        return @divTrunc(@as(i32, @intCast(@abs(sim.f[1 - who].x - sim.f[who].x))), sim_mod.fp);
    }

    /// The direction (world) toward the human.
    fn toward(sim: *const Sim, who: u1) i32 {
        return if (sim.f[1 - who].x >= sim.f[who].x) 1 else -1;
    }

    fn move(inp: *Input, dir: i32) void {
        if (dir > 0) inp.right = true else inp.left = true;
    }

    fn busy(f: *const sim_mod.Fighter) bool {
        return switch (f.state) {
            .idle, .crouch, .walk, .block => false,
            else => true,
        };
    }

    fn humanStunned(h: *const sim_mod.Fighter) bool {
        return switch (h.state) {
            .hit, .blockstun, .fall, .down, .getup => true,
            else => false,
        };
    }

    /// The input for this tick, for fighter `who`.
    pub fn think(c: *Cpu, sim: *const Sim, who: u1, tick: u32) Input {
        _ = tick;
        var inp: Input = .{};
        const me = &sim.f[who];
        const h = &sim.f[1 - who];
        if (sim.over) return inp;

        // The hit queue: remember what has hit it.
        const hurt = me.state == .hit or me.state == .fall;
        if (hurt and !c.was_hurt) {
            const a = c.prev_act;
            if (a != .none) {
                std.mem.copyForwards(Act, c.hit_q[0..5], c.hit_q[1..6]);
                c.hit_q[5] = a;
            }
        }
        c.was_hurt = hurt;

        // The reaction gate: a new attack of the human's.
        const act = actOf(h);
        if (act != .none and c.prev_act == .none and !busy(me) and c.plan != .guard) c.react(sim, who, act);
        if (act != .none) c.prev_act = act else if (h.state != .attack and h.state != .air_attack) c.prev_act = .none;

        if (me.state == .air and c.air_kick and me.anim_t >= 12) {
            inp.hk = true;
            c.air_kick = false;
        }
        if (busy(me)) {
            // Hit, falling, mid-attack: whatever it planned is gone, but a
            // strike plan carries on its own move.
            if (me.state != .attack and me.state != .air_attack and me.state != .air) {
                c.plan = .pause;
                c.left = 6 + @as(u16, @intCast(c.rng.below(14)));
            }
            return inp;
        }

        switch (c.plan) {
            .guard => {
                inp.block = true;
                inp.down = c.crouch_guard;
                if (c.left == 0 or actOf(h) == .none and c.left < 6) c.plan = .pause;
                if (c.left > 0) c.left -= 1;
                if (c.plan == .pause) {
                    c.left = 8 + @as(u16, @intCast(c.rng.below(10)));
                }
            },
            .pause, .hangout => {
                if (c.left == 0) c.plan = .think else c.left -= 1;
            },
            .think => c.decide(sim, who),
            .walk_in => {
                if (dist(sim, who) <= t.ref(108) or c.left == 0) {
                    c.next(sim, who);
                } else {
                    c.left -= 1;
                    move(&inp, toward(sim, who));
                }
            },
            .walk_out => {
                if (c.left == 0 or dist(sim, who) >= t.ref(200)) {
                    c.plan = .pause;
                    c.left = 8 + @as(u16, @intCast(c.rng.below(16)));
                } else {
                    c.left -= 1;
                    move(&inp, -toward(sim, who));
                }
            },
            .strike => c.strike(sim, who, &inp),
            .jump_in => {
                // Up and forward now, the kick near the top of the arc.
                inp.up = true;
                move(&inp, toward(sim, who));
                c.air_kick = true;
                c.plan = .pause;
                c.left = 34;
            },
        }
        // A jump has started: the air control is the kick.
        return inp;
    }

    fn react(c: *Cpu, sim: *const Sim, who: u1, act: Act) void {
        const me = &sim.f[who];
        const h = &sim.f[1 - who];
        _ = me;
        var repeats: u8 = 0;
        for (c.hit_q) |q| {
            if (q == act) repeats += 1;
        }
        const gate = (repeats >= 3 and c.rng.pct(anti_spam_pct)) or c.rng.pct(react_pct);
        if (!gate or act == .throw or act == .jump_attack) return;
        const d = dist(sim, who);
        if (repeats >= 3 or c.rng.pct(10)) {
            // A counter: the sweep, if it reaches.
            if (d < t.ref(190)) {
                c.plan = .strike;
                c.moves[0] = .sweep;
                c.n = 1;
                c.i = 0;
                c.walk_first = 0;
            }
            return;
        }
        c.plan = .guard;
        c.crouch_guard = act == .sweep or (h.state == .attack and (h.move == .c_lk or h.move == .sweep));
        c.left = 40;
    }

    fn decide(c: *Cpu, sim: *const Sim, who: u1) void {
        const h = &sim.f[1 - who];
        const d = dist(sim, who);
        // Stands in its stance now and then.
        if (c.hangouts < max_hangouts and c.rng.pct(20)) {
            c.hangouts += 1;
            c.plan = .hangout;
            c.left = 48 + @as(u16, @intCast(c.rng.below(128)));
            return;
        }
        // Never strikes a human in hit stun: waits, or backs off.
        if (humanStunned(h)) {
            c.plan = .pause;
            c.left = 10;
            return;
        }
        if (d < t.ref(110)) {
            if (c.rng.pct(30)) {
                c.plan = .walk_out;
                c.left = 40;
                return;
            }
            switch (c.rng.below(4)) {
                0 => c.strikes(&.{.hp}, 0),
                1 => c.strikes(&.{.lk}, 0),
                2 => c.strikes(&.{.throw}, 0),
                else => c.strikes(&.{.hk}, 0),
            }
        } else if (d < t.ref(192)) {
            switch (c.rng.below(6)) {
                0 => c.strikes(&.{.sweep}, 0),
                1 => c.strikes(&.{.lk}, 0),
                2 => c.strikes(&.{.hk}, 20),
                3 => c.strikes(&.{ .lp, .lp, .lp }, 0),
                4 => c.strikes(&.{.hp}, 48),
                else => c.strikes(&.{.lk}, 0),
            }
        } else if (d < t.ref(384)) {
            if (c.rng.pct(30)) {
                c.plan = .walk_out;
                c.left = 30;
            } else if (d >= t.ref(290) and c.rng.pct(40)) {
                c.plan = .jump_in;
            } else {
                c.plan = .walk_in;
                c.left = 120;
            }
        } else {
            if (c.rng.pct(30)) {
                c.plan = .pause;
                c.left = 20;
            } else if (c.rng.pct(25)) {
                c.plan = .jump_in;
            } else {
                c.plan = .walk_in;
                c.left = 160;
            }
        }
    }

    fn strikes(c: *Cpu, list: []const Move, walk_first: u16) void {
        c.n = @intCast(list.len);
        for (list, 0..) |m, k| c.moves[k] = m;
        c.i = 0;
        c.walk_first = walk_first;
        c.plan = .strike;
        c.attacks += 1;
    }

    /// Arrived: strike if the human is in reach, else decide again.
    fn next(c: *Cpu, sim: *const Sim, who: u1) void {
        _ = who;
        _ = sim;
        c.plan = .think;
    }

    fn strike(c: *Cpu, sim: *const Sim, who: u1, inp: *Input) void {
        if (c.walk_first > 0) {
            c.walk_first -= 1;
            move(inp, toward(sim, who));
            return;
        }
        if (c.i >= c.n) {
            c.plan = .pause;
            c.left = pause_min + @as(u16, @intCast(c.rng.below(pause_var)));
            return;
        }
        const m = c.moves[c.i];
        c.i += 1;
        switch (m) {
            .lp, .throw => inp.lp = true,
            .hp => inp.hp = true,
            .lk => inp.lk = true,
            .hk => inp.hk = true,
            .sweep => {
                inp.down = true;
                inp.hk = true;
            },
            else => {},
        }
        // The next move of a string waits for this one to end: the plan
        // returns here each time the fighter is free again.
    }
};
