//! The fight's numbers: Mortal Kombat 3's, from the leaked UMK3 source
//! (docs/fights/MK3.md says, for each, whether it is verified from the code
//! or approximated, and where it comes from). One place to tune.
//!
//! Units: the source's arcade pixels (a 400 x 254 playfield) times `S` give
//! screen pixels, uniformly in x and y; a velocity in arcade px/tick is
//! x `S` px/tick at the 55 ticks/s of `ONE_SECOND`. Fixed point is 1/256 px
//! (`sim.fp`). Sprites are scaled so a fighter's standing height is MK3's
//! (`stand_arcade` x `S`): `character.Character.scaleFp`.

const Anim = @import("character.zig").Anim;

/// UMK3's `ONE_SECOND`.
pub const tick_hz: u32 = 55;

/// Screen pixels per arcade pixel (MK3.md section 1: 1.25 shows a 512-arcade-px
/// slice of the 640-px screen, a jump's apex clears the HUD with room, and
/// every per-tick number below is exact in 1/256 px).
pub const S: comptime_float = 1.25;

/// A fighter's standing height in arcade px (`ochar_ground_offsets`: Kano's
/// SCY(0x90), the table's 0x88..0x9e centre; MK3.md section 1).
pub const stand_arcade: comptime_float = 144;

/// An arcade distance or speed as fixed point (1/256 px) screen units.
pub fn fx(comptime arcade: comptime_float) i32 {
    return @intFromFloat(@round(arcade * S * 256));
}

/// Screen pixels per arcade pixel for the vertical arcs (jumps, air hits): MK3's
/// 254-line playfield on the 480-line screen, so a jump rises the same share of
/// the screen as in MK3 (the fighters stay at `S`, smaller than MK3's share).
pub const SY: comptime_float = 480.0 / 254.0;

/// A vertical arcade distance or speed at `SY`, fixed point.
pub fn fy(comptime arcade: comptime_float) i32 {
    return @intFromFloat(@round(arcade * SY * 256));
}

/// A pixel count tuned in the first version, at 1.6 px per arcade px
/// (pushes, the CPU's distance bands, the sprite-width margins): the same
/// proportion at `S`.
pub fn ref(n: i32) i32 {
    return @intFromFloat(@round(@as(f64, @floatFromInt(n)) * S / 1.6));
}

/// The health bar: 166 units, `MAX_HEALTH`-ish (MK3.md "Damage").
pub const health_max: i16 = 166;

// ---- the screen -------------------------------------------------------------

/// Where the feet stand on the 640x480 picture and the band the fight redraws.
pub const ground_y: i32 = 424;
pub const band_y: i32 = 0x8c;
pub const band_h: i32 = 0x127;

/// Where the fighters start: each one's origin (the animation point, the
/// body's centre line, our feet anchor) `set_x_woff` (`MKGUYS.C:608`) puts
/// `SCX(0x60)` = 96 arcade px in from its screen edge, the first from the
/// left, the second from the right (MK3.md section 7): 120 px at `S`.
pub const start_in: i32 = @intFromFloat(@round(96 * S));
pub const start_x = [2]i32{ start_in, 640 - start_in };
/// The walls: 58 arcade px from the left and 48 from the right of the
/// 512-arcade-px screen (`LEFT_PADDING` / `RIGHT_PADDING`, MK3.md section 7;
/// MK3 scrolls a wider world).
pub const arena_min: i32 = @intFromFloat(@round(58 * S));
pub const arena_max: i32 = @intFromFloat(@round(640 - 48 * S));
/// Two fighters on the ground keep this far apart; the correction takes at
/// most `separate_per_tick` px a tick.
pub const separate_per_tick: i32 = ref(6);
/// A fighter struck in the air: vx 3.5, vy -6 (up), 23 ticks in the air.
pub const air_hit_vx: i32 = fx(3.5);
pub const air_hit_vy: i32 = fy(6);
pub const air_hit_ticks: u16 = 26;
/// Two fighters on the ground keep this far apart (64 arcade px, wider for
/// Ryu's sprite).
pub const min_sep: i32 = ref(140);

// ---- movement (fixed point px per tick) -----------------------------------------

/// Walk forward 3.25 arcade px/tick (most fighters), back 2.25 (MK3.md "Movement").
pub const walk_fwd: i32 = fx(3.25);
pub const walk_back: i32 = fx(2.25);

/// Jump: vy0 -10, gravity 0.5 (at `SY`), vx +-4 arcade px/tick; no air control.
pub const jump_vy: i32 = fy(10);
pub const gravity: i32 = fy(0.5);
pub const jump_vx: i32 = fx(4);

/// Arc height (fixed point) over which an airborne frame's placement eases in
/// from the feet anchor, most of the rise (apex 95) (`sim.airLift`).
pub const air_ramp: i32 = fy(80);
/// A frame shorter than the stance hangs from the head line and sits this much
/// higher than that (1/256; 1.3: the flip's ball in MK3's pictures, MK3.md 3).
pub const air_tuck: i32 = 333;

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
    // The pushes were tuned at 1.6 px per arcade px.
    for (&m) |*d| {
        d.hit_push = @intCast(ref(d.hit_push));
        d.block_push = @intCast(ref(d.block_push));
        d.knock_push = @intCast(ref(d.knock_push));
    }
    break :blk m;
};

/// A throw's reach (LP, centre to centre; MK3: 64 arcade px).
pub const throw_range: i32 = ref(155);

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
