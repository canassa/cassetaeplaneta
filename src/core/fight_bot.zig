//! A player bot for the fights (SALGIN and XILINDRO; a test tool, not in the
//! original and not a Corrigida fix): `noite --minigame xilindro --headless
//! --fight-bot PROFILE[,SEED]` plays the round itself, so `tools/fight_bots.py`
//! can measure how a fight goes for different players over many seeds.
//! docs/fights/EASY_AI.md "Measuring" has the numbers it gives.
//!
//! The bot sees what a player sees (`View`: the gap, the poses, the energies,
//! the clock) and never the opponent's AI state; it answers with the 1995
//! key codes, which the arena's handler takes like the keys of a keyboard
//! (`arena.botTick`, on every WM_TIMER, 50 ms). A human's reaction time is
//! modelled by showing the bot the screen as it was `reaction_ms` ago.
//!
//! Profiles:
//!  * `idle`: presses nothing.
//!  * `masher`: a random blow (72%) or step (28%) every 100-250 ms, whatever is
//!    on the screen; it never blocks or jumps.
//!  * `novice`: walks in, throws a random blow now and then, sometimes
//!    blocks or steps back when it sees a blow coming, 400-700 ms after it
//!    shows (a first-time player).
//!  * `decent`: answers each tell 250-350 ms after it shows (block, jump the
//!    sweep, or step back), and kicks while the opponent is open.
//!  * `expert`: the same, 220-300 ms, never wrong, and it goes after the
//!    opponent: the scripted playthroughs record it (`--fight-bot expert,N,log`).

const std = @import("std");
const fight_fair = @import("fight_fair.zig");
const fight_easy = @import("fight_easy.zig");

pub const Profile = enum { idle, masher, novice, decent, expert };

pub const Config = struct {
    profile: Profile,
    seed: u64 = 1,
    /// Every key the bot sends is printed (`[ms] fightbot-key VK down|up`):
    /// `tools/fight_plan.py --player bot` turns them into script lines.
    log_keys: bool = false,
    /// The bot sleeps until this time (ms): a run with two fights.
    after: u32 = 0,
};

/// Set by `--fight-bot` (main.zig); null: no bot.
pub var config: ?Config = null;

/// `PROFILE[,SEED][,log][,after=MS]`.
pub fn parse(text: []const u8) ?Config {
    var it = std.mem.splitScalar(u8, text, ',');
    const p = it.next() orelse return null;
    const profile = std.meta.stringToEnum(Profile, p) orelse return null;
    var seed: u64 = 1;
    if (it.next()) |s| seed = std.fmt.parseInt(u64, s, 10) catch return null;
    var cfg: Config = .{ .profile = profile, .seed = seed };
    while (it.next()) |opt| {
        if (std.mem.eql(u8, opt, "log")) {
            cfg.log_keys = true;
        } else if (std.mem.startsWith(u8, opt, "after=")) {
            cfg.after = std.fmt.parseInt(u32, opt["after=".len..], 10) catch return null;
        } else return null;
    }
    return cfg;
}

// The 1995 key codes of the fights' moves.
pub const vk_left: u16 = 0x25;
pub const vk_right: u16 = 0x27;
pub const vk_jump: u16 = 0x2d; // Insert
pub const vk_block: u16 = 0x23; // End
pub const vk_punch: u16 = 0x21; // PgUp
pub const vk_kick: u16 = 0x26; // Up
pub const vk_high: u16 = 0x24; // Home
pub const vk_sweep: u16 = 0x28; // Down
pub const vk_enter: u16 = 0x0d;

/// What the player sees at an instant.
pub const View = struct {
    /// The game's clock, ms.
    t: u32 = 0,
    /// The controls screen is up (any key takes it down).
    screen: bool = false,
    /// The PORRADA intro stands: the keys do nothing.
    intro: bool = false,
    /// The fight is over.
    over: bool = false,
    gap: i16 = 0,
    fighter_x: i16 = 0,
    fighter_strip: i16 = 6,
    opponent_strip: i16 = 4,
    opponent_frame: i16 = 0,
    fighter_energy: i16 = 91,
    opponent_energy: i16 = 91,
    seconds_left: i16 = 90,

    /// The fighter is standing or walking: a key starts a move.
    pub fn free(v: View) bool {
        return v.fighter_strip == 4 or v.fighter_strip == 6;
    }
    /// The opponent shows the first frame of an attack strip (0 punch, 1
    /// middle kick, 2 sweep, 3 high kick): the tell.
    pub fn tell(v: View) bool {
        return v.opponent_strip >= 0 and v.opponent_strip <= 3 and v.opponent_frame == 0;
    }
    /// The opponent is in the later frames of an attack: its follow-through.
    pub fn followThrough(v: View) bool {
        return v.opponent_strip >= 0 and v.opponent_strip <= 3 and v.opponent_frame > 0;
    }
};

pub const Cmd = struct { vk: u16, down: bool };

pub const Out = struct {
    cmds: [4]Cmd = undefined,
    n: u8 = 0,

    fn push(o: *Out, vk: u16, down: bool) void {
        if (o.n < o.cmds.len) {
            o.cmds[o.n] = .{ .vk = vk, .down = down };
            o.n += 1;
        }
    }
    pub fn slice(o: *const Out) []const Cmd {
        return o.cmds[0..o.n];
    }
};

/// How a profile plays (percent chances; ms).
pub const Style = struct {
    reaction_min: u16,
    reaction_max: u16,
    /// A tell it sees: the chance to answer it at all.
    answer: u8,
    /// An answer: the chance it is the right one (block; jump for the sweep).
    right: u8,
    /// Of the wrong answers, the share that is a step back (the rest: a block).
    step_back: u8,
    /// Between two decisions, free.
    decide_min: u16,
    decide_max: u16,
    /// In reach, nothing shown: the chance to attack (else it waits, steps
    /// back, blocks).
    attack: u8,
    /// In reach, the opponent in its follow-through or reeling: the chance
    /// to attack.
    punish: u8,
    /// Out of reach: the chance to walk in (else it waits).
    walk_in: u8,
    /// Where it stops walking in, the gap.
    stop_at: i16,
};

pub const novice_style: Style = .{
    .reaction_min = 400,
    .reaction_max = 700,
    .answer = 75,
    .right = 60,
    .step_back = 50,
    .decide_min = 300,
    .decide_max = 700,
    .attack = 62,
    .punish = 72,
    .walk_in = 85,
    .stop_at = 100,
};

pub const expert_style: Style = .{
    .reaction_min = 220,
    .reaction_max = 300,
    .answer = 100,
    .right = 100,
    .step_back = 50,
    .decide_min = 100,
    .decide_max = 250,
    .attack = 55,
    .punish = 100,
    .walk_in = 100,
    .stop_at = 100,
};

pub const decent_style: Style = .{
    .reaction_min = 250,
    .reaction_max = 350,
    .answer = 92,
    .right = 96,
    .step_back = 50,
    .decide_min = 150,
    .decide_max = 400,
    .attack = 10,
    .punish = 75,
    .walk_in = 90,
    .stop_at = 100,
};

const ring_len = 48;

pub const Stats = struct {
    /// Moves it started, by kind.
    blows: u16 = 0,
    blocks: u16 = 0,
    jumps: u16 = 0,
    steps: u16 = 0,
    /// Energy lost by each side, in hits.
    landed: u16 = 0,
    taken: u16 = 0,
    /// Tells seen, tells answered.
    tells: u16 = 0,
    answered: u16 = 0,
};

pub const Bot = struct {
    cfg: Config = .{ .profile = .idle },
    rng: std.Random.DefaultPrng = .init(1),
    started: bool = false,
    ended: bool = false,
    ring: [ring_len]View = undefined,
    ring_n: usize = 0,
    /// The key to release, and when.
    release_vk: u16 = 0,
    release_at: u32 = 0,
    next_at: u32 = 0,
    reaction: u32 = 500,
    resample_at: u32 = 0,
    /// When the round started for the bot (0: not yet).
    play_start: u32 = 0,
    /// A tell in the delayed view was already answered (or let go).
    tell_done: bool = false,
    last: View = .{},
    stats: Stats = .{},

    pub fn start(b: *Bot, cfg: Config) void {
        b.* = .{ .cfg = cfg, .rng = .init(cfg.seed), .started = true };
        b.reaction = b.between(styleOf(cfg.profile).reaction_min, styleOf(cfg.profile).reaction_max);
    }

    fn styleOf(p: Profile) Style {
        return switch (p) {
            .decent => decent_style,
            .expert => expert_style,
            else => novice_style,
        };
    }

    fn pct(b: *Bot, p: u8) bool {
        return b.rng.random().uintLessThan(u8, 100) < p;
    }

    fn between(b: *Bot, lo: u32, hi: u32) u32 {
        return lo + b.rng.random().uintLessThan(u32, hi - lo + 1);
    }

    /// The view `ms` ago (the oldest kept if the bot has not been running
    /// that long).
    fn delayed(b: *const Bot, now: u32, ms: u32) View {
        var best = b.ring[0];
        var i: usize = 0;
        while (i < b.ring_n) : (i += 1) {
            const v = b.ring[i];
            if (v.t +% ms <= now) best = v;
        }
        return best;
    }

    fn remember(b: *Bot, v: View) void {
        if (b.ring_n < ring_len) {
            b.ring[b.ring_n] = v;
            b.ring_n += 1;
        } else {
            std.mem.copyForwards(View, b.ring[0 .. ring_len - 1], b.ring[1..ring_len]);
            b.ring[ring_len - 1] = v;
        }
    }

    fn press(b: *Bot, o: *Out, vk: u16, hold_ms: u32, now: u32) void {
        o.push(vk, true);
        b.release_vk = vk;
        b.release_at = now +% hold_ms;
        switch (vk) {
            vk_punch, vk_kick, vk_high, vk_sweep => b.stats.blows += 1,
            vk_block => b.stats.blocks += 1,
            vk_jump => b.stats.jumps += 1,
            vk_left, vk_right => b.stats.steps += 1,
            else => {},
        }
    }

    /// One WM_TIMER (50 ms): the keys to send now.
    pub fn step(b: *Bot, v: View) Out {
        var out: Out = .{};
        const now = v.t;
        // Energy changes are hits.
        if (b.ring_n > 0) {
            if (v.opponent_energy < b.last.opponent_energy) b.stats.landed += 1;
            if (v.fighter_energy < b.last.fighter_energy) b.stats.taken += 1;
        }
        b.last = v;
        b.remember(v);
        if (b.release_vk != 0 and @as(i32, @bitCast(now -% b.release_at)) >= 0) {
            out.push(b.release_vk, false);
            b.release_vk = 0;
        }
        if (v.over or v.intro) return out;
        if (v.screen) {
            if (b.release_vk == 0 and now >= 300 and !b.tell_done) {
                b.tell_done = true;
                b.press(&out, vk_enter, 100, now);
            }
            return out;
        }
        // A player needs a moment after PORRADA before the first key.
        if (b.play_start == 0) {
            b.play_start = now | 1;
            b.next_at = now +% b.between(300, 700);
        }
        switch (b.cfg.profile) {
            .idle => {},
            .masher => b.mash(&out, v),
            .novice, .decent, .expert => b.play(&out, v, styleOf(b.cfg.profile)),
        }
        return out;
    }

    fn mash(b: *Bot, out: *Out, v: View) void {
        if (b.release_vk != 0 or @as(i32, @bitCast(v.t -% b.next_at)) < 0) return;
        b.next_at = v.t +% b.between(100, 250);
        const r = b.rng.random().uintLessThan(u8, 100);
        const hold: u32 = b.between(40, 200);
        const vk: u16 = if (r < 22) vk_punch else if (r < 42) vk_kick else if (r < 58) vk_high else if (r < 72) vk_sweep else if (r < 90) vk_right else vk_left;
        b.press(out, vk, hold, v.t);
    }

    fn blow(b: *Bot) u16 {
        const r = b.rng.random().uintLessThan(u8, 100);
        return if (r < 30) vk_punch else if (r < 60) vk_kick else if (r < 80) vk_high else vk_sweep;
    }

    fn play(b: *Bot, out: *Out, v: View, s: Style) void {
        const now = v.t;
        const dv = b.delayed(now, b.reaction);
        // A tell the player has just noticed (in the delayed view).
        if (!dv.tell()) {
            b.tell_done = false;
            // A new reaction time, between tells (the delayed view must not
            // jump while one is on the screen).
            if (!v.tell() and @as(i32, @bitCast(now -% b.resample_at)) >= 0) {
                b.reaction = b.between(s.reaction_min, s.reaction_max);
                b.resample_at = now +% 1000;
            }
        } else if (!b.tell_done) {
            b.tell_done = true;
            b.stats.tells += 1;
            if (v.free() and b.pct(s.answer)) {
                b.stats.answered += 1;
                b.answer(out, v, dv, s);
                b.next_at = now +% b.between(s.decide_min, s.decide_max);
                return;
            }
        }
        if (b.release_vk != 0 or !v.free() or @as(i32, @bitCast(now -% b.next_at)) < 0) return;
        b.next_at = now +% b.between(s.decide_min, s.decide_max);
        // The player knows where the opponent stands; what it is doing, as it
        // was `reaction` ago.
        if (v.gap > s.stop_at) {
            if (b.pct(s.walk_in)) b.press(out, vk_right, b.between(60, 250), now);
            return;
        }
        if (dv.followThrough() or dv.opponent_strip >= 8) {
            if (b.pct(s.punish)) b.press(out, b.blow(), 60, now);
            return;
        }
        if (b.pct(s.attack)) {
            b.press(out, b.blow(), 60, now);
        } else if (b.pct(30) and v.fighter_x >= 32) {
            b.press(out, vk_left, 60, now);
        }
    }

    /// The answer to a tell: the right one with chance `right`.
    fn answer(b: *Bot, out: *Out, v: View, dv: View, s: Style) void {
        const sweep = dv.opponent_strip == 2;
        if (b.pct(s.right)) {
            if (v.fighter_x >= 32 and b.pct(35)) {
                b.press(out, vk_left, 60, v.t);
            } else if (sweep) {
                b.press(out, vk_jump, 60, v.t);
            } else {
                b.press(out, vk_block, 60, v.t);
            }
        } else if (b.pct(s.step_back) and v.fighter_x >= 32) {
            b.press(out, vk_left, 60, v.t);
        } else if (sweep) {
            b.press(out, vk_block, 60, v.t);
        } else {
            b.press(out, vk_jump, 60, v.t);
        }
    }
};

/// The round's end, one line on stderr for `tools/fight_bots.py`: the
/// bot's own counts and the opponent's (the fair AI's, zeros without it).
pub fn report(b: *const Bot, v: View, ai: *const fight_fair.Ai) void {
    const s = b.stats;
    std.debug.print("[{d}] fightbot: end profile={t} seed={d} clock={d} fighter={d} opponent={d} landed={d} taken={d} blows={d} blocks={d} jumps={d} steps={d} tells={d} answered={d} windups={d} interrupts={d}", .{
        v.t, b.cfg.profile, b.cfg.seed, v.seconds_left, v.fighter_energy, v.opponent_energy, s.landed, s.taken, s.blows, s.blocks, s.jumps, s.steps, s.tells, s.answered, ai.windups, ai.interrupts,
    });
    inline for (@typeInfo(fight_fair.Phase).@"enum".field_names, 0..) |n, i| std.debug.print(" ph_{s}={d}", .{ n, ai.phase_beats[i] });
    inline for (@typeInfo(fight_fair.Outcome).@"enum".field_names, 0..) |n, i| std.debug.print(" out_{s}={d}", .{ n, ai.outcomes[i] });
    std.debug.print(" guards={d} shrugs={d} whiffs={d}", .{ ai.guards, ai.shrugs, ai.whiffs });
    inline for (@typeInfo(fight_easy.Choice).@"enum".field_names, 0..) |n, i| std.debug.print(" ch_{s}={d}", .{ n, ai.choices[i] });
    std.debug.print("\n", .{});
}

test "parse" {
    const c = parse("novice,7").?;
    try std.testing.expectEqual(Profile.novice, c.profile);
    try std.testing.expectEqual(@as(u64, 7), c.seed);
    try std.testing.expectEqual(@as(u64, 1), parse("decent").?.seed);
    try std.testing.expect(parse("nobody") == null);
    const o = parse("expert,3,log,after=5000").?;
    try std.testing.expect(o.log_keys and o.after == 5000 and o.seed == 3);
    try std.testing.expect(parse("expert,3,x") == null);
}

test "idle never presses a key" {
    var b: Bot = .{};
    b.start(.{ .profile = .idle });
    var t: u32 = 400;
    while (t < 20000) : (t += 50) {
        try std.testing.expectEqual(@as(u8, 0), b.step(.{ .t = t }).n);
    }
}

test "the decent player blocks a tell 250-350 ms after it shows, jumps the sweep" {
    for ([_]i16{ 0, 2 }) |strip| {
        var b: Bot = .{};
        b.start(.{ .profile = .decent, .seed = 3 });
        var seen: ?u32 = null;
        var t: u32 = 400;
        while (t < 3000) : (t += 50) {
            const tell = t >= 1000 and t < 1500;
            const out = b.step(.{ .t = t, .gap = 90, .fighter_x = 0, .opponent_strip = if (tell) strip else 4 });
            for (out.slice()) |c| if (c.down and t >= 1000 and seen == null) {
                seen = t;
                try std.testing.expectEqual(if (strip == 2) vk_jump else vk_block, c.vk);
            };
        }
        // 250-350 ms after the tell appears (a 50 ms timer on top).
        try std.testing.expect(seen != null and seen.? >= 1250 and seen.? <= 1400);
    }
}

test "the novice answers a tell later than the decent player" {
    var b: Bot = .{};
    b.start(.{ .profile = .novice, .seed = 5 });
    var t: u32 = 400;
    while (t < 1000) : (t += 50) _ = b.step(.{ .t = t, .gap = 90 });
    // Whatever it does, nothing comes inside 400 ms of the tell.
    t = 1000;
    while (t < 1400) : (t += 50) {
        const out = b.step(.{ .t = t, .gap = 90, .opponent_strip = 1 });
        for (out.slice()) |c| try std.testing.expect(!c.down or c.vk != vk_block);
    }
}
