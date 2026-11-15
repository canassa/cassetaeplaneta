//! The fights' fair fight (SALGIN and XILINDRO, which share the engine; a
//! Corrigida addition, `fight_fair`, the owner's decision; not a port unit,
//! no original code). docs/fights/FAIRNESS.md is the research behind it,
//! docs/salgin/DESIGN.md "Decisions" the summary.
//!
//! In the Original the opponent's damage lands on the beat its attack
//! starts, from beyond the fighter's reach, with nothing on screen to say
//! it is coming. Here it runs a Punch-Out!!-style cycle on the 200 ms beat:
//! approach -> wind-up (the tell: frame 0 of the attack and the attack's
//! own wave, `WINDUP_BEATS`) -> strike (damage only if the fighter is
//! still in reach and is not blocking it, jumping the sweep or reeling) ->
//! recovery in range (the punish window) -> a 100-px jump back -> a pause
//! with a little jitter -> again; now and then a feint (it comes in and
//! backs off). It decides on its schedule and on what the screen shows,
//! never on the player's keys.
//!
//! This file holds what both fights share: the numbers (`Tuning`), the AI's
//! state (`Ai`), the rules (`strikeOutcome`) and the debug overlay. Each
//! program's `arena.zig` drives its own objects with them (its fields and
//! waves differ).

const std = @import("std");
const builtin = @import("builtin");
const msg = @import("msg.zig");
const Msg = msg.Msg;
const Fixes = @import("fixes.zig").Fixes;
const fight_controls = @import("fight_controls.zig");
const platform = @import("../platform/platform.zig");
const Platform = platform.Platform;
const Surface = platform.Surface;

/// The attack strips, the same in both fights: 0 punch, 1 middle kick
/// (SALGIN's voadora), 2 sweep, 3 high kick (SALGIN's salto).
pub const sweep: i16 = 2;

/// Every number of the fair fight, one set per fight. Beats are the
/// handler's (one per >= 200 ms, so 200-250 ms each); distances are the
/// gap |opponent.x - fighter.x| in px.
pub const Tuning = struct {
    /// The tell: beats between the wind-up pose (with its wave) and the
    /// strike. The fairness dial: 2 (400-500 ms) is reactable once the tells
    /// are learnt, 3 is easy, 1 a guess.
    windup_beats: u8 = 2,
    /// The wind-up in the round's first `opening_s` seconds (a gentler
    /// start, Punch-Out's time markers); `opening_s` 0 turns it off.
    opening_windup_beats: u8 = 3,
    opening_s: i16 = 0,
    /// The opponent walks in (32 px a beat) while the gap is above this,
    /// so it stops 69-100 px away, inside the fighter's reach.
    approach_stop: i16 = 100,
    /// The strike lands only if the gap is still at most this: one 32-px
    /// step back from where it stopped dodges.
    opp_reach: i16 = 100,
    /// The fighter's blows land at a gap of at most this (the Original's:
    /// XILINDRO 100, SALGIN 120).
    fighter_reach: i16 = 100,
    /// Beats the opponent stands in range, frozen in its follow-through,
    /// after its attack before it jumps back: the punish window.
    recovery_beats: u8 = 1,
    /// How far it jumps back after an attack, a feint or a reel in range.
    retreat_px: i16 = 100,
    /// Beats it stands after jumping back, plus 0..`jitter_beats` from the
    /// game's own rand() (so a run stays deterministic).
    pause_beats: u8 = 1,
    jitter_beats: u8 = 1,
    /// Footsies: one step out of reach (the edge, gap at most
    /// `approach_stop` + 32) it stands this many beats (+ 0..`jitter_beats`)
    /// before it steps in...
    edge_beats: u8 = 1,
    /// ...or at once when the fighter starts a blow there (a whiff it can
    /// see), so a blow thrown out of reach is punished: the fighter is
    /// still in its 3-beat move when the strike comes.
    whiff_punish: bool = true,
    /// One arrival in this many is a feint: it stands `feint_beats` beats
    /// in its guard and backs off without attacking (0: never).
    feint_one_in: u8 = 6,
    feint_beats: u8 = 1,
    /// Without the controls screen (whose PORRADA intro already holds the
    /// round), the opponent stands this many beats first.
    start_delay_beats: u8 = 10,
    /// The fighter's blows by strip (the Original's x 2: {1, 2, 1, 2}).
    fighter_damage: [4]i16 = .{ 2, 4, 2, 4 },
    /// Damage a block takes from a blockable attack (0: a block holds).
    block_chip: i16 = 0,
    /// Which attacks a block (strip 7) holds: the punch and both kicks; the
    /// sweep goes under it.
    blockable: [4]bool = .{ true, true, false, true },
    /// Which attacks a jump (strip 5) clears: the sweep.
    jumpable: [4]bool = .{ false, false, true, false },
};

pub const xilindro: Tuning = .{};
/// SALGIN's fighter reaches 100 px instead of 120 (equal reach: from 101-120
/// it would hit the opponent waiting at the edge); its opponent hits by
/// the player's table {1, 2, 1, 2} in the Corrigida (S1 is a choice),
/// unchanged.
pub const salgin: Tuning = .{};

pub const Phase = enum {
    /// The round's first beats without the controls screen.
    start,
    /// Walking in.
    approach,
    /// The tell: frame 0 of `Ai.attack`, `left` beats to the strike.
    windup,
    /// The attack's frames after the strike.
    strike,
    /// Standing in range after the attack, `left` beats.
    recovery,
    /// Standing after the jump back, `left` beats.
    pause,
    /// Came in, stands `left` beats, backs off.
    feint,
    /// Hit by the fighter: its reaction plays (it cannot be hit again).
    reel,
};

/// What the strike did.
pub const Outcome = enum { none, hit, blocked, jumped, dodged, protected };

pub const Ai = struct {
    phase: Phase = .approach,
    /// Beats left in the phase (wind-up, recovery, pause, feint, start).
    left: u8 = 0,
    /// The attack chosen at the wind-up's start (0-3).
    attack: i16 = 0,
    /// Fair beats so far.
    beat: u32 = 0,
    /// The last strike's outcome.
    last: Outcome = .none,
    /// Debug overlay and beat log on (F9, Debug builds).
    overlay: bool = false,
    /// Counts for the overlay and the log.
    windups: u16 = 0,
    interrupts: u16 = 0,
};

/// The strike's outcome against a fighter in `fighter_strip` at `gap`.
pub fn strikeOutcome(t: *const Tuning, attack: i16, fighter_strip: i16, gap: i16) Outcome {
    const a: usize = @intCast(attack & 3);
    if (gap > t.opp_reach) return .dodged;
    return switch (fighter_strip) {
        8, 9, 10 => .protected,
        7 => if (t.blockable[a]) .blocked else .hit,
        5 => if (t.jumpable[a]) .jumped else .hit,
        else => .hit,
    };
}

/// The wind-up's length at `seconds_left` on the 90-s clock.
pub fn windupBeats(t: *const Tuning, seconds_left: i16) u8 {
    return if (t.opening_s > 0 and 90 - seconds_left < t.opening_s) t.opening_windup_beats else t.windup_beats;
}

/// The pause after a jump back, `r` a rand() value.
pub fn pauseBeats(t: *const Tuning, r: i16) u8 {
    const j: i16 = @as(i16, t.jitter_beats) + 1;
    return t.pause_beats + @as(u8, @intCast(@rem(r & 0x7fff, j)));
}

/// The beats it stands at the edge, `r` a rand() value.
pub fn edgeBeats(t: *const Tuning, r: i16) u8 {
    const j: i16 = @as(i16, t.jitter_beats) + 1;
    return t.edge_beats + @as(u8, @intCast(@rem(r & 0x7fff, j)));
}

/// Whether this arrival is a feint, `r` a rand() value.
pub fn isFeint(t: *const Tuning, r: i16) bool {
    return t.feint_one_in != 0 and @rem(r & 0x7fff, @as(i16, t.feint_one_in)) == 0;
}

// ---- the debug overlay -------------------------------------------------------

/// F9 toggles the overlay (Debug builds, `fight_fair` on).
pub const vk_f9: u16 = 0x78;
pub const debug_build = builtin.mode == .debug;

pub fn isToggle(fixes: Fixes, m: Msg) bool {
    return debug_build and fixes.fight_fair and m.id == msg.wm.keydown and m.wparam == vk_f9;
}

/// The overlay's box, above the arena band (y 140) and below the clock.
pub const box = struct {
    pub const x: i16 = 8;
    pub const y: i16 = 44;
    pub const w: i16 = 624;
    pub const h: i16 = 40;
};

pub const View = struct {
    gap: i16,
    fighter_x: i16,
    opponent_x: i16,
    fighter_strip: i16,
    opponent_strip: i16,
    fighter_energy: i16,
    opponent_energy: i16,
    seconds_left: i16,
};

fn line1(buf: []u8, ai: *const Ai, v: View) []const u8 {
    return std.fmt.bufPrint(buf, "gap {d}  {t} {d}  atk {d}  beat {d}  last {t}", .{ v.gap, ai.phase, ai.left, ai.attack, ai.beat, ai.last }) catch buf[0..0];
}

fn line2(buf: []u8, ai: *const Ai, v: View) []const u8 {
    return std.fmt.bufPrint(buf, "fx {d} ox {d}  strips {d}/{d}  energy {d}/{d}  tells {d} cut {d}", .{ v.fighter_x, v.opponent_x, v.fighter_strip, v.opponent_strip, v.fighter_energy, v.opponent_energy, ai.windups, ai.interrupts }) catch buf[0..0];
}

/// Draws the overlay into `s` (the backdrop): a dark box and two lines.
pub fn drawOverlay(plat: Platform, s: Surface, ai: *const Ai, v: View) void {
    fight_controls.fill(s, box.x, box.y, box.w, box.h, fight_controls.nearest(s.colors, 0));
    var b1: [128]u8 = undefined;
    var b2: [128]u8 = undefined;
    const style: platform.TextStyle = .{ .color = 0x0000ffff, .bk_mode = .transparent };
    _ = plat.textOut(s, style, box.x + 4, box.y + 3, line1(&b1, ai, v));
    _ = plat.textOut(s, style, box.x + 4, box.y + 21, line2(&b2, ai, v));
}

/// One stderr line per beat while the overlay is on (Debug, not the web):
/// what `tools/fight_plan.py` reads.
pub fn log(now: u32, ai: *const Ai, v: View) void {
    if (!debug_build or builtin.target.cpu.arch.isWasm()) return;
    var b1: [128]u8 = undefined;
    var b2: [128]u8 = undefined;
    std.debug.print("[{d}] fair {s}  {s}  clock {d}\n", .{ now, line1(&b1, ai, v), line2(&b2, ai, v), v.seconds_left });
}

test "the strike's answers" {
    const t = &xilindro;
    try std.testing.expectEqual(Outcome.dodged, strikeOutcome(t, 0, 6, 101));
    try std.testing.expectEqual(Outcome.hit, strikeOutcome(t, 0, 6, 100));
    for ([_]i16{ 0, 1, 3 }) |a| try std.testing.expectEqual(Outcome.blocked, strikeOutcome(t, a, 7, 80));
    try std.testing.expectEqual(Outcome.hit, strikeOutcome(t, sweep, 7, 80));
    try std.testing.expectEqual(Outcome.jumped, strikeOutcome(t, sweep, 5, 80));
    try std.testing.expectEqual(Outcome.hit, strikeOutcome(t, 3, 5, 80));
    try std.testing.expectEqual(Outcome.protected, strikeOutcome(t, 0, 9, 80));
    try std.testing.expectEqual(Outcome.hit, strikeOutcome(t, 0, 1, 80));
}

test "pauses, feints and the opening wind-up" {
    const t = &xilindro;
    try std.testing.expectEqual(@as(u8, 1), pauseBeats(t, 4));
    try std.testing.expectEqual(@as(u8, 2), pauseBeats(t, 5));
    try std.testing.expect(isFeint(t, 12) and !isFeint(t, 13));
    try std.testing.expectEqual(@as(u8, 2), windupBeats(t, 90));
    const easy: Tuning = .{ .opening_s = 60 };
    try std.testing.expectEqual(@as(u8, 3), windupBeats(&easy, 85));
    try std.testing.expectEqual(@as(u8, 2), windupBeats(&easy, 20));
}
