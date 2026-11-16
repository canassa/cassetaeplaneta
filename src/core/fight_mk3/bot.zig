//! Player bots for tests and tuning (`fight_mk3` is judged by whether a casual
//! player beats the CPU): they read the sim like a person looking at the
//! screen, with a reaction delay, and press only what the keys could. The
//! profiles, from the least to the most skilled:
//!   idle    does nothing;
//!   masher  walks in and taps random buttons;
//!   casual  walks in to a comfortable distance, pokes with a random move
//!           now and then, ducks or blocks an attack it sees about half the
//!           time after a quarter of a second;
//!   decent  as casual but blocks most attacks, mixes low and high, and
//!           backs off when low on health.

const std = @import("std");
const sim_mod = @import("sim.zig");
const Sim = sim_mod.Sim;
const Input = sim_mod.Input;
const cpu = @import("cpu.zig");
const t = @import("tables.zig");

pub const Profile = enum { idle, masher, casual, decent };

pub const Bot = struct {
    rng: cpu.Rng,
    profile: Profile,
    /// Ticks until it may act again.
    wait: u16 = 20,
    /// Seen an attack begin this many ticks ago (its reaction timer).
    seen: i16 = -1,
    seen_low: bool = false,
    guard_left: u16 = 0,
    guard_crouch: bool = false,
    walk_left: u16 = 0,
    prev_act: cpu.Act = .none,

    pub fn init(profile: Profile, seed: u32) Bot {
        return .{ .rng = .{ .s = seed *% 2654435761 | 1 }, .profile = profile };
    }

    fn dist(sim: *const Sim) i32 {
        return @divTrunc(@as(i32, @intCast(@abs(sim.f[1].x - sim.f[0].x))), sim_mod.fp);
    }

    fn fwd(sim: *const Sim) i32 {
        return if (sim.f[1].x >= sim.f[0].x) 1 else -1;
    }

    fn walk(inp: *Input, dir: i32) void {
        if (dir > 0) inp.right = true else inp.left = true;
    }

    pub fn think(b: *Bot, sim: *const Sim, tick: u32) Input {
        _ = tick;
        var inp: Input = .{};
        if (b.profile == .idle or sim.over) return inp;
        const me = &sim.f[0];
        const o = &sim.f[1];
        const busy = switch (me.state) {
            .idle, .crouch, .walk, .block => false,
            else => true,
        };
        const d = dist(sim);

        // Watching the CPU: a new attack starts a reaction timer.
        const act = cpu.actOf(o);
        if (act != .none and b.prev_act == .none) {
            b.seen = 0;
            b.seen_low = o.move == .sweep or o.move == .c_lk;
        }
        b.prev_act = act;
        if (b.seen >= 0) b.seen += 1;
        const react_after: i16 = switch (b.profile) {
            .casual => 14,
            .decent => 9,
            else => 1000,
        };
        const react_pct: u32 = switch (b.profile) {
            .casual => 45,
            .decent => 80,
            else => 0,
        };
        if (b.seen == react_after and act != .none and d < t.ref(230)) {
            if (b.rng.pct(react_pct)) {
                b.guard_left = 28;
                b.guard_crouch = b.seen_low;
            }
            b.seen = -1;
        }
        if (act == .none) b.seen = -1;
        if (b.guard_left > 0 and !busy) {
            b.guard_left -= 1;
            inp.block = true;
            inp.down = b.guard_crouch;
            return inp;
        }
        if (busy) return inp;
        if (b.wait > 0) {
            b.wait -= 1;
            // Standing around, drifting toward a comfortable distance.
            return inp;
        }
        const reach: i32 = switch (b.profile) {
            .masher => t.ref(150),
            .casual => t.ref(165),
            .decent => t.ref(170),
            .idle => 0,
        };
        if (d > reach) {
            walk(&inp, fwd(sim));
            return inp;
        }
        // In reach: back off a step when low (decent), else strike.
        if (b.profile == .decent and me.health < t.health_max / 4 and d < t.ref(130) and b.rng.pct(30)) {
            walk(&inp, -fwd(sim));
            b.wait = 10;
            return inp;
        }
        const pick = b.rng.below(6);
        switch (b.profile) {
            .masher => switch (pick) {
                0 => inp.lp = true,
                1 => inp.hp = true,
                2 => inp.lk = true,
                3 => inp.hk = true,
                4 => inp.lk = true,
                else => inp.lp = true,
            },
            else => switch (pick) {
                0 => inp.lp = true,
                1 => inp.hp = true,
                2 => inp.lk = true,
                3 => inp.hk = true,
                4 => {
                    inp.down = true;
                    inp.hk = true;
                },
                else => {
                    inp.down = true;
                    inp.hp = true;
                },
            },
        }
        b.wait = switch (b.profile) {
            .masher => 6 + @as(u16, @intCast(b.rng.below(10))),
            .casual => 22 + @as(u16, @intCast(b.rng.below(30))),
            else => 14 + @as(u16, @intCast(b.rng.below(18))),
        };
        return inp;
    }
};
