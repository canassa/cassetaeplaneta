//! XILINDRO's table for the strip converter (`strips.zig`): the fighter
//! (`sb*.bmp`, 231x266, the player) and the inmate (`sa*.bmp`, 252x295, the
//! opponent), each with its own pictures and no palette swap (docs/fights/MK3.md
//! "Sprites"). The 11 strips are in the game's order (`g_fighterStripFiles`:
//! soco chme rast chal anda pula defa defe cai sego, then the fighter's
//! `flut`, the inmate's `come`), with a floor shadow baked in (colour 44 in the
//! fighter's strips, 39 in the inmate's). The inmate faces left in the art.

const strips = @import("strips.zig");
const Clip = strips.Clip;
const Ref = strips.Ref;
const Spec = strips.Spec;
const Anim = @import("character.zig").Anim;

pub const S = enum(u8) { soco, chme, rast, chal, anda, pula, defa, defe, cai, sego, last };

fn r(s: S, f: u8, ms: u32) Ref {
    return .{ .s = @backingInt(s), .f = f, .ms = ms };
}

/// The inmate's art reaches 140 px with a punch or a sweep, the fighter's 72
/// to 86: its hit boxes are cut to this (about 1.25 times the fighter's
/// longest reach; the Original's opponent hits from 130 px, the fighter from
/// 100, 1.3 times).
const inmate_reach: i32 = 105;

/// The disc's strip files (`assets/XILINDRO/<prefix><name>.BMP`) in the game's order.
fn files(comptime prefix: []const u8, comptime last: []const u8) [strips.strip_count][]const u8 {
    const names = [_][]const u8{ "SOCO", "CHME", "RAST", "CHAL", "ANDA", "PULA", "DEFA", "DEFE", "CAI", "SEGO", last };
    var out: [strips.strip_count][]const u8 = undefined;
    for (names, 0..) |n, i| out[i] = "assets/XILINDRO/" ++ prefix ++ n ++ ".BMP";
    return out;
}

// ---- the fighter (the player; faces right) -----------------------------------

const f_punch = [_]Ref{ r(.soco, 0, 60), r(.soco, 1, 60), r(.soco, 2, 60) };
const f_kick = [_]Ref{ r(.chme, 0, 60), r(.chme, 1, 60), r(.chme, 2, 60) };
const f_high = [_]Ref{ r(.chal, 0, 60), r(.chal, 1, 60), r(.chal, 2, 60) };
const f_sweep = [_]Ref{ r(.rast, 0, 60), r(.rast, 1, 60), r(.rast, 2, 60) };
const f_hit = [_]Ref{ r(.sego, 0, 60), r(.sego, 1, 140), r(.sego, 2, 60) };

const fighter_clips = [_]Clip{
    .{ .anim = .stance, .mode = .reg, .loop = true, .refs = &.{ r(.defa, 0, 200), r(.defa, 1, 200) } },
    // The art has no crouch: the jump strip's deep squat, on its own feet.
    .{ .anim = .crouch, .mode = .low, .loop = true, .cap = true, .refs = &.{r(.pula, 2, 100)} },
    .{ .anim = .walk_f, .mode = .reg, .loop = true, .refs = &.{ r(.anda, 0, 90), r(.anda, 1, 90), r(.anda, 2, 90), r(.anda, 1, 90) } },
    .{ .anim = .walk_b, .mode = .reg, .loop = true, .refs = &.{ r(.anda, 2, 90), r(.anda, 1, 90), r(.anda, 0, 90), r(.anda, 1, 90) } },
    .{ .anim = .jump_u, .mode = .low, .refs = &.{ r(.pula, 0, 130), r(.pula, 1, 130), r(.pula, 2, 130) } },
    .{ .anim = .jump_f, .mode = .low, .refs = &.{ r(.pula, 0, 130), r(.pula, 1, 130), r(.pula, 2, 130) } },
    .{ .anim = .jump_b, .mode = .low, .refs = &.{ r(.pula, 0, 130), r(.pula, 1, 130), r(.pula, 2, 130) } },
    .{ .anim = .lp, .mode = .reg, .refs = &f_punch, .active = .{ 1, 1 } },
    .{ .anim = .hp, .mode = .reg, .refs = &f_punch, .active = .{ 1, 1 } },
    .{ .anim = .lk, .mode = .reg, .refs = &f_kick, .active = .{ 1, 1 } },
    .{ .anim = .hk, .mode = .reg, .refs = &f_high, .active = .{ 1, 1 } },
    .{ .anim = .roundhouse, .mode = .reg, .refs = &f_high, .active = .{ 1, 1 } },
    .{ .anim = .c_lp, .mode = .reg, .cap = true, .refs = &f_punch, .active = .{ 1, 1 } },
    .{ .anim = .uppercut, .mode = .reg, .cap = true, .refs = &f_punch, .active = .{ 1, 1 } },
    .{ .anim = .c_lk, .mode = .reg, .cap = true, .refs = &f_kick, .active = .{ 1, 1 } },
    .{ .anim = .sweep, .mode = .reg, .cap = true, .refs = &f_sweep, .active = .{ 1, 1 } },
    .{ .anim = .j_lp, .mode = .air, .refs = &f_punch, .active = .{ 1, 1 } },
    .{ .anim = .j_hp, .mode = .air, .refs = &f_punch, .active = .{ 1, 1 } },
    .{ .anim = .j_lk, .mode = .air, .refs = &f_high, .active = .{ 1, 1 } },
    .{ .anim = .j_hk, .mode = .air, .refs = &f_high, .active = .{ 1, 1 } },
    .{ .anim = .throw, .mode = .reg, .refs = &f_punch, .active = .{ 1, 1 } },
    .{ .anim = .block_hi, .mode = .reg, .loop = true, .refs = &.{r(.defe, 1, 100)} },
    .{ .anim = .block_lo, .mode = .reg, .loop = true, .cap = true, .refs = &.{r(.defe, 1, 100)} },
    .{ .anim = .hit_hi, .mode = .reg, .refs = &f_hit },
    .{ .anim = .hit_lo, .mode = .reg, .cap = true, .refs = &f_hit },
    .{ .anim = .fall, .mode = .low, .hurt = false, .refs = &.{r(.cai, 1, 100)} },
    .{ .anim = .down, .mode = .low, .hurt = false, .loop = true, .refs = &.{r(.cai, 2, 100)} },
    .{ .anim = .win, .mode = .reg, .loop = true, .refs = &.{ r(.last, 0, 150), r(.last, 1, 150), r(.last, 2, 150) } },
    .{ .anim = .getup, .mode = .low, .refs = &.{ r(.cai, 2, 40), r(.cai, 1, 40), r(.cai, 0, 40) } },
};

const fighter_spec: Spec = .{
    .name = "xilindro-fighter",
    .shadow = 44,
    .faces_left = false,
    .rest = r(.defa, 0, 0),
    .clips = &fighter_clips,
    .files = files("SB", "FLUT"),
    .frame_h = 266,
};

// ---- the inmate (the opponent; faces left in the art) ---------------------------

const i_punch = [_]Ref{ r(.soco, 0, 60), r(.soco, 1, 60), r(.soco, 2, 60) };
const i_kick = [_]Ref{ r(.chme, 0, 60), r(.chme, 1, 60), r(.chme, 0, 60) };
const i_high = [_]Ref{ r(.chal, 0, 60), r(.chal, 1, 60), r(.chal, 0, 60) };
const i_sweep = [_]Ref{ r(.chme, 0, 60), r(.rast, 0, 60), r(.rast, 1, 60), r(.rast, 2, 60) };
const i_hit = [_]Ref{ r(.sego, 0, 60), r(.sego, 1, 140), r(.sego, 2, 60) };

const inmate_clips = [_]Clip{
    .{ .anim = .stance, .mode = .reg, .loop = true, .refs = &.{r(.defa, 0, 200)} },
    .{ .anim = .crouch, .mode = .low, .loop = true, .cap = true, .refs = &.{r(.pula, 0, 100)} },
    .{ .anim = .walk_f, .mode = .reg, .loop = true, .refs = &.{ r(.anda, 0, 110), r(.anda, 1, 110) } },
    .{ .anim = .walk_b, .mode = .reg, .loop = true, .refs = &.{ r(.anda, 1, 110), r(.anda, 0, 110) } },
    .{ .anim = .jump_u, .mode = .low, .refs = &.{ r(.pula, 0, 130), r(.pula, 1, 130), r(.pula, 2, 130) } },
    .{ .anim = .jump_f, .mode = .low, .refs = &.{ r(.pula, 0, 130), r(.pula, 1, 130), r(.pula, 2, 130) } },
    .{ .anim = .jump_b, .mode = .low, .refs = &.{ r(.pula, 0, 130), r(.pula, 1, 130), r(.pula, 2, 130) } },
    .{ .anim = .lp, .mode = .reg, .refs = &i_punch, .active = .{ 1, 1 } },
    .{ .anim = .hp, .mode = .reg, .refs = &i_punch, .active = .{ 1, 1 } },
    .{ .anim = .lk, .mode = .reg, .refs = &i_kick, .active = .{ 1, 1 } },
    .{ .anim = .hk, .mode = .reg, .refs = &i_high, .active = .{ 1, 1 } },
    .{ .anim = .roundhouse, .mode = .reg, .refs = &i_high, .active = .{ 1, 1 } },
    .{ .anim = .c_lp, .mode = .reg, .cap = true, .refs = &i_punch, .active = .{ 1, 1 } },
    .{ .anim = .uppercut, .mode = .reg, .cap = true, .refs = &i_punch, .active = .{ 1, 1 } },
    .{ .anim = .c_lk, .mode = .reg, .cap = true, .refs = &i_kick, .active = .{ 1, 1 } },
    .{ .anim = .sweep, .mode = .reg, .cap = true, .refs = &i_sweep, .active = .{ 1, 1 } },
    .{ .anim = .j_lp, .mode = .air, .refs = &i_punch, .active = .{ 1, 1 } },
    .{ .anim = .j_hp, .mode = .air, .refs = &i_punch, .active = .{ 1, 1 } },
    .{ .anim = .j_lk, .mode = .air, .refs = &i_high, .active = .{ 1, 1 } },
    .{ .anim = .j_hk, .mode = .air, .refs = &i_high, .active = .{ 1, 1 } },
    .{ .anim = .throw, .mode = .reg, .refs = &i_punch, .active = .{ 1, 1 } },
    .{ .anim = .block_hi, .mode = .reg, .loop = true, .refs = &.{r(.defe, 1, 100)} },
    .{ .anim = .block_lo, .mode = .reg, .loop = true, .cap = true, .refs = &.{r(.defe, 1, 100)} },
    .{ .anim = .hit_hi, .mode = .reg, .refs = &i_hit },
    .{ .anim = .hit_lo, .mode = .reg, .cap = true, .refs = &i_hit },
    .{ .anim = .fall, .mode = .low, .hurt = false, .refs = &.{r(.cai, 1, 100)} },
    .{ .anim = .down, .mode = .low, .hurt = false, .loop = true, .refs = &.{r(.cai, 2, 100)} },
    // Its `come` strip: fists up, guard, an arm raised (held).
    .{ .anim = .win, .mode = .reg, .refs = &.{ r(.last, 0, 150), r(.last, 1, 150), r(.last, 2, 400) } },
    .{ .anim = .getup, .mode = .low, .refs = &.{ r(.cai, 2, 40), r(.cai, 1, 40), r(.cai, 0, 40) } },
};

const inmate_spec: Spec = .{
    .name = "xilindro-inmate",
    .shadow = 39,
    .faces_left = true,
    .max_reach = inmate_reach,
    .rest = r(.defa, 0, 0),
    .clips = &inmate_clips,
    .files = files("SA", "COME"),
    .frame_h = 295,
};

pub const pair: strips.Pair = .{ &fighter_spec, &inmate_spec };

// ---- tests -----------------------------------------------------------------------

const std = @import("std");

test "the disc's strips make both characters, every move" {
    var reach: [2]i32 = undefined;
    for (pair, 0..) |spec, i| reach[i] = try strips.checkSpec(spec);
    // The inmate outreaches the fighter, by about the Original's 1.3.
    try std.testing.expect(reach[1] > reach[0] and reach[1] <= inmate_reach);
}
