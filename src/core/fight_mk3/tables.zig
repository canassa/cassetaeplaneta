//! The fight's numbers: Mortal Kombat 3's, from the leaked UMK3 source
//! (docs/fights/MK3.md says, for each, whether it is verified from the code
//! or approximated, and where it comes from). One place to tune.
//!
//! Units: the source's arcade pixels (400 to a screen width) times 1.6 give
//! our 640-px screen; a velocity in arcade px/tick is x 1.6 px/tick at the
//! 55 ticks/s of `ONE_SECOND`. Fixed point is 1/256 px (`sim.fp`).

const Anim = @import("character.zig").Anim;

/// UMK3's `ONE_SECOND`.
pub const tick_hz: u32 = 55;

/// The health bar: 166 units, `MAX_HEALTH`-ish (MK3.md "Damage").
pub const health_max: i16 = 166;

// ---- the screen -------------------------------------------------------------

/// Where the feet stand on the 640x480 picture and the band the fight redraws.
pub const ground_y: i32 = 424;
pub const band_y: i32 = 0x8c;
pub const band_h: i32 = 0x127;

pub const start_x = [2]i32{ 215, 425 };
/// The walls (the arena is one screen wide here; MK3 scrolls a 960-px one).
pub const arena_min: i32 = 72;
pub const arena_max: i32 = 578;
/// Two fighters on the ground keep this far apart; the correction takes at
/// most `separate_per_tick` px a tick.
pub const separate_per_tick: i32 = 6;
/// A fighter struck in the air: vx 3.5, vy -6 (up), 23 ticks in the air.
pub const air_hit_vx: i32 = 1434; // 5.6 px/tick
pub const air_hit_vy: i32 = 2458; // 9.6 px/tick
pub const air_hit_ticks: u16 = 26;
/// Two fighters on the ground keep this far apart (64 arcade px, wider for
/// Ryu's sprite).
pub const min_sep: i32 = 140;

// ---- movement (fixed point px per tick) -----------------------------------------

/// Walk forward 3.25 arcade px/tick (most fighters), back 2.25 (MK3.md "Movement").
pub const walk_fwd: i32 = 1331; // 5.2 px/tick = 286 px/s
pub const walk_back: i32 = 922; // 3.6 px/tick = 198 px/s

/// Jump: vy0 -10, gravity 0.5, vx +-4 arcade px/tick; no air control.
pub const jump_vy: i32 = 4096; // 16 px/tick
pub const gravity: i32 = 205; // 0.8 px/tick^2
pub const jump_vx: i32 = 1638; // 6.4 px/tick

/// Ticks of a jump (the sprite clip is stretched over it).
pub fn airTicks() u16 {
    var y: i32 = 1;
    var vy: i32 = jump_vy;
    var n: u16 = 0;
    while (true) {
        vy -= gravity;
        y += vy;
        n += 1;
        if (y <= 0 or n > 200) return n;
    }
}

// ---- moves -----------------------------------------------------------------------

pub const Move = enum(u8) {
    lp,
    hp,
    lk,
    hk,
    roundhouse,
    c_lp,
    uppercut,
    c_lk,
    sweep,
    j_lp,
    j_hp,
    j_lk,
    j_hk,
    throw,
};

pub const MoveData = struct {
    anim: Anim,
    /// A low attack: a standing block does not stop it.
    low: bool = false,
    damage: u8,
    startup: u8,
    active: u8,
    recovery: u8,
    /// Pushback of the defender (px) on a hit and on a block.
    hit_push: i16 = 0,
    block_push: i16 = 38,
    hitstun: u8 = 0,
    blockstun: u8 = 12,
    knockdown: bool = false,
    /// A knockdown's push (px) and the fall's length (ticks).
    knock_push: i16 = 0,
    fall_ticks: u8 = 30,
    unblockable: bool = false,
};

/// Damage is of `health_max` = 166 (MK3.md "Damage": the source holds only
/// the throw's 24 and the air slam's 16; the rest are approximations
/// around MK3's known ratios). Timing: the punches' and kicks' structure
/// is from the source (`MKJOY`/animation scripts: 3 ticks a frame, 5-6 check
/// ticks); the startup/active/recovery split is approximated.
pub const moves = blk: {
    var m: [@typeInfo(Move).@"enum".field_names.len]MoveData = undefined;
    m[@backingInt(Move.lp)] = .{ .anim = .lp, .damage = 7, .startup = 6, .active = 5, .recovery = 12, .hit_push = 10, .hitstun = 10 };
    m[@backingInt(Move.hp)] = .{ .anim = .hp, .damage = 10, .startup = 7, .active = 5, .recovery = 14, .hit_push = 16, .hitstun = 12 };
    m[@backingInt(Move.lk)] = .{ .anim = .lk, .damage = 8, .startup = 5, .active = 5, .recovery = 10, .hit_push = 51, .hitstun = 11 };
    m[@backingInt(Move.hk)] = .{ .anim = .hk, .damage = 12, .startup = 6, .active = 6, .recovery = 14, .hit_push = 120, .hitstun = 16 };
    // Back + HK: knocks down and far (6.0 arcade px/tick, 31 ticks).
    m[@backingInt(Move.roundhouse)] = .{ .anim = .roundhouse, .damage = 18, .startup = 8, .active = 4, .recovery = 14, .knockdown = true, .knock_push = 150, .fall_ticks = 31 };
    m[@backingInt(Move.c_lp)] = .{ .anim = .c_lp, .damage = 8, .startup = 6, .active = 3, .recovery = 9, .hit_push = 38, .hitstun = 10 };
    // Down + HP: MK3's uppercut, the big launcher (63 ticks in the air in the source).
    m[@backingInt(Move.uppercut)] = .{ .anim = .uppercut, .damage = 22, .startup = 5, .active = 3, .recovery = 20, .knockdown = true, .knock_push = 130, .fall_ticks = 44 };
    m[@backingInt(Move.c_lk)] = .{ .anim = .c_lk, .low = true, .damage = 7, .startup = 5, .active = 3, .recovery = 9, .hit_push = 30, .hitstun = 11 };
    // Down + HK here (the owner's mapping), Back + LK in MK3: a low, knocks down in place.
    m[@backingInt(Move.sweep)] = .{ .anim = .sweep, .low = true, .damage = 12, .startup = 8, .active = 3, .recovery = 18, .block_push = 25, .blockstun = 8, .knockdown = true, .knock_push = 20, .fall_ticks = 22 };
    // Jumping attacks end when the fighter lands.
    m[@backingInt(Move.j_lp)] = .{ .anim = .j_lp, .damage = 13, .startup = 4, .active = 16, .recovery = 10, .hit_push = 40, .hitstun = 14 };
    m[@backingInt(Move.j_hp)] = .{ .anim = .j_hp, .damage = 13, .startup = 4, .active = 16, .recovery = 10, .hit_push = 40, .hitstun = 14 };
    m[@backingInt(Move.j_lk)] = .{ .anim = .j_lk, .damage = 15, .startup = 4, .active = 16, .recovery = 10, .hit_push = 40, .hitstun = 14 };
    m[@backingInt(Move.j_hk)] = .{ .anim = .j_hk, .damage = 15, .startup = 4, .active = 16, .recovery = 10, .hit_push = 40, .hitstun = 14 };
    // LP at close range: 24 damage, unblockable, the victim thrown 80 px.
    m[@backingInt(Move.throw)] = .{ .anim = .throw, .damage = 24, .startup = 8, .active = 1, .recovery = 38, .knockdown = true, .knock_push = 80, .fall_ticks = 36, .unblockable = true };
    break :blk m;
};

/// A throw's reach (LP, centre to centre; MK3: 64 arcade px).
pub const throw_range: i32 = 155;

/// A standing block stops everything but low attacks, a crouching one
/// everything (MK3.md "Block": `MKBLK`-level rule, which attacks are low is
/// approximated).
pub fn blocks(crouching: bool, low: bool) bool {
    return crouching or !low;
}

/// Chip damage on a block: ~12% of the hit, at least 1, never lethal.
pub const chip_pct: i32 = 12;

/// A hit this strong (damage) sounds heavy.
pub const heavy_damage: u8 = 12;

// ---- the ground game -----------------------------------------------------------------

pub const push_ticks: u16 = 8;
/// Lying on the floor after a fall, getting up (`getup_invuln`: the first
/// ticks cannot be hit).
pub const down_ticks: u16 = 26;
pub const getup_ticks: u16 = 12;
pub const getup_invuln: u16 = 6;
/// A tap during a move waits this many ticks for it to end.
pub const input_buffer_ticks: u8 = 5;
/// After a KO the winner takes the win pose when the loser has fallen.
pub const win_after_ticks: u16 = 70;
