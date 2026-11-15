//! The fights' easy early-ladder opponent (SALGIN and XILINDRO, which share
//! the engine; a Corrigida addition, `fight_easy_ai`, the owner's request
//! after "still too hard"; not a port unit, no original code).
//! docs/fights/EASY_AI.md is the research behind it.
//!
//! The fair fight's opponent (`fight_fair.zig`) is a metronome: approach,
//! tell, strike, hop back, pause, again, a cycle of 6-7 beats whatever
//! happens. The easy opponent keeps the same moves, tells and rules
//! (`strikeOutcome`, the 2-beat wind-up, one blow at a time, a hop back
//! after every blow) and changes only what it *decides*: at each point where
//! it is free (arrived in range, a pause over, a wait or a guard over) it
//! rolls on a personality table (`Style`) for what to do next, the way the
//! arcade ladders' first opponents do: it walks in, but stops and dithers
//! on the way; it arrives and waits, or guards, or backs off, as often as it
//! attacks; it sometimes starts a blow from too far and whiffs; it guards
//! now and then (holds the punch and the kicks, not the sweep); it
//! sometimes counters a blocked blow; it sometimes takes a hit without
//! reacting; and when it is winning it takes its foot off the pedal. All its
//! choices come from the game's own `rand()` (deterministic in the harness)
//! and the screen's state; it never reads a key.
//!
//! This file is the decision logic, pure (no engine objects), so its tests
//! run anywhere; each program's `arena.zig` carries the choices out with
//! its own fields and waves.

const std = @import("std");
const crt = @import("crt.zig");

/// What it does next, when free.
pub const Choice = enum {
    /// Walk in (or stay in) the approach.
    advance,
    /// Stand in its stance for `Ai.left` beats.
    wait,
    /// Raise its guard for `Ai.left` beats.
    guard,
    /// Hop back, then pause.
    retreat,
    /// The wind-up (the tell), then the strike.
    attack,
    /// Come in, stand a beat, back off without attacking.
    feint,
};

/// Where the fighter is, by the gap.
pub const Zone = enum {
    /// More than one step out of reach.
    far,
    /// One step out of reach (`approach_stop` + 1..32): the edge.
    edge,
    /// Within the fighter's reach.
    reach,
};

/// What the opponent knows when it decides (all of it visible).
pub const Context = struct {
    zone: Zone,
    /// The fighter is in a blow it started (locked, open).
    fighter_busy: bool,
    fighter_energy: i16,
    opponent_energy: i16,
};

/// A personality: percent chances and weights, beats. The numbers are the
/// dials of docs/fights/EASY_AI.md "Tuning".
pub const Style = struct {
    /// The tell: beats between the wind-up pose and the strike (the fair
    /// fight's is 2); `slow` percent of the wind-ups are one beat longer (a
    /// lazy wind-up, readable even by a beginner).
    windup_beats: u8 = 2,
    slow: u8 = 25,
    /// The opponent's damage, percent of the game's table, and the fighter's
    /// percent of the fair fight's (which doubled the Original's).
    damage_pct: u16 = 100,
    fighter_damage_pct: u16 = 100,
    /// Walking in, each beat beyond the edge: the chance it stands instead
    /// (for `hesitate_beats` beats, 1 + 0..this - 1).
    hesitate: u8 = 20,
    hesitate_beats: u8 = 2,
    /// At the edge: the chance it starts a blow from there, out of reach (it
    /// whiffs unless the fighter walks in).
    whiff: u8 = 12,
    /// In reach: weights of attack / wait / guard / retreat / feint.
    w_attack: u8 = 58,
    w_wait: u8 = 15,
    w_guard: u8 = 10,
    w_retreat: u8 = 10,
    w_feint: u8 = 7,
    /// Beats of a wait, 1 + 0..wait_extra; of a guard, `guard_min` +
    /// 0..guard_extra.
    wait_extra: u8 = 3,
    guard_min: u8 = 2,
    guard_extra: u8 = 2,
    /// Hop back after a decision to retreat, px, and the pause after it.
    retreat_px: i16 = 64,
    /// The fighter is in a blow (open): the chance that, seeing it, the
    /// opponent attacks at once (else it decides as usual).
    opportunist: u8 = 35,
    /// The fighter whiffs a blow in front of it (the Original's tell for
    /// "attack now"): the chance it sees it and steps in at once.
    punish: u8 = 50,
    /// After a blocked blow: the chance of a counter (a wind-up of
    /// `counter_windup_beats`), else it stays in its guard.
    counter: u8 = 25,
    counter_windup_beats: u8 = 3,
    /// After it lands a hit: the beats it stands before it decides again
    /// (on top of the pause): mercy.
    mercy_beats: u8 = 1,
    /// After it is hit (once the reel is over): the chance of a guard, of a
    /// longer retreat, else the usual hop back and pause.
    guard_after_hurt: u8 = 15,
    back_off_after_hurt: u8 = 25,
    /// How far a back-off after a hit hops (px; the usual hop is the fair
    /// fight's `retreat_px`, 100).
    back_off_px: i16 = 100,
    /// A hit in a neutral phase (not the wind-up): the chance it takes it
    /// without reeling (it goes on with what it was doing).
    shrug: u8 = 10,
    /// The fighter's energy is below the opponent's by this much (of 91):
    /// every attack weight is scaled down to `rubber_scale` percent; and
    /// the opposite: it presses when it is behind (scaled up by `desperate`).
    rubber_lead: i16 = 18,
    rubber_scale: u8 = 50,
    desperate_lead: i16 = 25,
    desperate_scale: u8 = 150,
};

/// Each fight's personality. Variables so that `--fight-tune` (a test
/// tool: `tools/fight_bots.py --tune`) can turn the dials without a rebuild.
pub var xilindro: Style = .{};
/// SALGIN's fighter has no recoil, so a player lands about 60 hits to
/// XILINDRO's 23 and knocks the opponent out inside a minute whatever it
/// does. Its easy opponent therefore takes the fighter's blows at the
/// Original's damage (the fair fight doubled them), hits for 2.5 times the
/// table's {1, 2, 1, 2}, shrugs most hits off (it goes on with its plan
/// instead of reeling) and winds up lazily half the time (docs/fights/EASY_AI.md
/// "Tuning").
pub var salgin: Style = .{ .damage_pct = 250, .fighter_damage_pct = 50, .shrug = 60, .slow = 50 };

/// `key=value,key=value`: sets those fields of `s` (`--fight-tune`). False
/// on an unknown key or a bad value.
pub fn tune(s: *Style, text: []const u8) bool {
    var it = std.mem.tokenizeScalar(u8, text, ',');
    outer: while (it.next()) |kv| {
        const eq = std.mem.indexOfScalar(u8, kv, '=') orelse return false;
        const v = std.fmt.parseInt(i16, kv[eq + 1 ..], 10) catch return false;
        inline for (@typeInfo(Style).@"struct".field_names) |name| {
            if (std.mem.eql(u8, kv[0..eq], name)) {
                const T = @TypeOf(@field(s.*, name));
                @field(s.*, name) = std.math.cast(T, v) orelse return false;
                continue :outer;
            }
        }
        return false;
    }
    return true;
}

fn pct(r: *crt.Rand, p: u8) bool {
    return @rem(r.rand() & 0x7fff, 100) < p;
}

fn below(r: *crt.Rand, n: u8) u8 {
    if (n == 0) return 0;
    return @intCast(@rem(r.rand() & 0x7fff, @as(i16, n)));
}

/// The attack weight after the rubber band: easier when the opponent leads,
/// harder when it trails.
pub fn scaledAttack(s: *const Style, c: Context) u16 {
    const lead = c.opponent_energy - c.fighter_energy;
    const base: u16 = s.w_attack;
    if (lead >= s.rubber_lead) return base * s.rubber_scale / 100;
    if (-lead >= s.desperate_lead) return base * s.desperate_scale / 100;
    return base;
}

/// The next choice, free in `c.zone`.
pub fn choose(s: *const Style, c: Context, r: *crt.Rand) Choice {
    switch (c.zone) {
        .far => return .advance,
        .edge => return if (pct(r, s.whiff)) .attack else .advance,
        .reach => {},
    }
    if (c.fighter_busy and pct(r, s.opportunist)) return .attack;
    const wa = scaledAttack(s, c);
    const total: u16 = wa + s.w_wait + s.w_guard + s.w_retreat + s.w_feint;
    var roll: u16 = @intCast(@rem(r.rand() & 0x7fff, @as(i16, @intCast(total))));
    if (roll < wa) return .attack;
    roll -= wa;
    if (roll < s.w_wait) return .wait;
    roll -= s.w_wait;
    if (roll < s.w_guard) return .guard;
    roll -= s.w_guard;
    if (roll < s.w_retreat) return .retreat;
    return .feint;
}

/// The wind-up's length: `windup_beats`, now and then one beat longer.
pub fn windupBeats(s: *const Style, r: *crt.Rand) u8 {
    return if (pct(r, s.slow)) s.windup_beats + 1 else s.windup_beats;
}

/// A damage of the game's table, after `damage_pct` (rounded).
pub fn scaleDamage(s: *const Style, d: i16) i16 {
    return @divTrunc(d * @as(i16, @intCast(s.damage_pct)) + 50, 100);
}

/// A blow of the fighter's damage in the fair fight, after `fighter_damage_pct`.
pub fn scaleFighterDamage(s: *const Style, d: i16) i16 {
    return @divTrunc(d * @as(i16, @intCast(s.fighter_damage_pct)) + 50, 100);
}

/// Beats of a wait.
pub fn waitBeats(s: *const Style, r: *crt.Rand) u8 {
    return 1 + below(r, s.wait_extra + 1);
}

/// Beats of a guard.
pub fn guardBeats(s: *const Style, r: *crt.Rand) u8 {
    return s.guard_min + below(r, s.guard_extra + 1);
}

/// Walking in: stands this many beats instead of stepping (0: steps).
pub fn hesitation(s: *const Style, r: *crt.Rand) u8 {
    if (!pct(r, s.hesitate)) return 0;
    return 1 + below(r, s.hesitate_beats);
}

/// A hit in the phase `windup`: always cuts the attack; otherwise the
/// opponent shrugs it off with chance `shrug`.
pub fn shrugsOff(s: *const Style, windup: bool, r: *crt.Rand) bool {
    return !windup and pct(r, s.shrug);
}

/// After the reel (hit by the fighter): what it does.
pub const AfterHurt = enum { usual, guard, back_off };

pub fn afterHurt(s: *const Style, r: *crt.Rand) AfterHurt {
    if (pct(r, s.guard_after_hurt)) return .guard;
    if (pct(r, s.back_off_after_hurt)) return .back_off;
    return .usual;
}

/// At the edge (one step out of reach): whether it starts a blow from there.
pub fn whiffs(s: *const Style, r: *crt.Rand) bool {
    return pct(r, s.whiff);
}

/// The fighter has whiffed a blow in front of it: whether the opponent
/// steps in to punish it.
pub fn punishes(s: *const Style, r: *crt.Rand) bool {
    return pct(r, s.punish);
}

/// A blow blocked: whether the opponent counters.
pub fn counters(s: *const Style, r: *crt.Rand) bool {
    return pct(r, s.counter);
}

test "far it advances, at the edge it mostly advances, in reach it rolls" {
    var r: crt.Rand = .{};
    const s: Style = .{};
    const far: Context = .{ .zone = .far, .fighter_busy = false, .fighter_energy = 91, .opponent_energy = 91 };
    for (0..50) |_| try std.testing.expectEqual(Choice.advance, choose(&s, far, &r));
    var edge = far;
    edge.zone = .edge;
    var starts: u32 = 0;
    for (0..1000) |_| {
        if (choose(&s, edge, &r) == .attack) starts += 1;
    }
    try std.testing.expect(starts > 70 and starts < 170);
}

test "in reach every choice comes up, in about the table's proportions" {
    var r: crt.Rand = .{ .seed = 7 };
    const s: Style = .{};
    const c: Context = .{ .zone = .reach, .fighter_busy = false, .fighter_energy = 91, .opponent_energy = 91 };
    var n: [6]u32 = @splat(0);
    for (0..6000) |_| n[@backingInt(choose(&s, c, &r))] += 1;
    // 58 / 15 / 10 / 10 / 7 of 100.
    try std.testing.expect(n[@backingInt(Choice.attack)] > 3200 and n[@backingInt(Choice.attack)] < 3750);
    try std.testing.expect(n[@backingInt(Choice.wait)] > 700 and n[@backingInt(Choice.wait)] < 1100);
    try std.testing.expect(n[@backingInt(Choice.guard)] > 450 and n[@backingInt(Choice.guard)] < 750);
    try std.testing.expect(n[@backingInt(Choice.retreat)] > 450 and n[@backingInt(Choice.retreat)] < 750);
    try std.testing.expect(n[@backingInt(Choice.feint)] > 300 and n[@backingInt(Choice.feint)] < 560);
    try std.testing.expectEqual(@as(u32, 0), n[@backingInt(Choice.advance)]);
}

test "the rubber band: it eases off when ahead and presses when behind" {
    const s: Style = .{};
    var c: Context = .{ .zone = .reach, .fighter_busy = false, .fighter_energy = 91, .opponent_energy = 91 };
    try std.testing.expectEqual(@as(u16, 58), scaledAttack(&s, c));
    c.fighter_energy = 60;
    try std.testing.expectEqual(@as(u16, 29), scaledAttack(&s, c));
    c.fighter_energy = 91;
    c.opponent_energy = 60;
    try std.testing.expectEqual(@as(u16, 87), scaledAttack(&s, c));
}

test "an open fighter is punished only sometimes" {
    var r: crt.Rand = .{ .seed = 11 };
    const s: Style = .{};
    const c: Context = .{ .zone = .reach, .fighter_busy = true, .fighter_energy = 91, .opponent_energy = 91 };
    var attacks: u32 = 0;
    for (0..2000) |_| {
        if (choose(&s, c, &r) == .attack) attacks += 1;
    }
    // opportunist 35 + 65% of the table's 58%.
    try std.testing.expect(attacks > 1300 and attacks < 1600);
}

test "hesitation, waits, guards and shrugs stay in their ranges" {
    var r: crt.Rand = .{ .seed = 3 };
    const s: Style = .{};
    var stood: u32 = 0;
    for (0..1000) |_| {
        const h = hesitation(&s, &r);
        try std.testing.expect(h <= s.hesitate_beats);
        if (h > 0) stood += 1;
        const w = waitBeats(&s, &r);
        try std.testing.expect(w >= 1 and w <= 1 + s.wait_extra);
        const g = guardBeats(&s, &r);
        try std.testing.expect(g >= s.guard_min and g <= s.guard_min + s.guard_extra);
        try std.testing.expect(!shrugsOff(&s, true, &r));
    }
    try std.testing.expect(stood > 130 and stood < 280);
}

test "the damage scale rounds" {
    var s: Style = .{};
    try std.testing.expectEqual(@as(i16, 3), scaleDamage(&s, 3));
    s.damage_pct = 200;
    try std.testing.expectEqual(@as(i16, 6), scaleDamage(&s, 3));
    s.damage_pct = 150;
    try std.testing.expectEqual(@as(i16, 2), scaleDamage(&s, 1));
}

test "the wind-up is the fair fight's 2 beats, now and then a lazy 3" {
    var r: crt.Rand = .{ .seed = 5 };
    const s: Style = .{};
    var lazy: u32 = 0;
    for (0..1000) |_| {
        const w = windupBeats(&s, &r);
        try std.testing.expect(w == 2 or w == 3);
        if (w == 3) lazy += 1;
    }
    try std.testing.expect(lazy > 190 and lazy < 310);
}

test "tune sets the named fields" {
    var s: Style = .{};
    try std.testing.expect(tune(&s, "w_attack=70,retreat_px=32"));
    try std.testing.expectEqual(@as(u8, 70), s.w_attack);
    try std.testing.expectEqual(@as(i16, 32), s.retreat_px);
    try std.testing.expect(!tune(&s, "nonsense=1"));
    try std.testing.expect(!tune(&s, "w_attack=999"));
}
