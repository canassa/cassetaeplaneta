//! SALGIN's table for the strip converter (`strips.zig`): the fighter
//! (`vb*.bmp`, 173x279, the player: the Casseta kid in the cap) and the
//! bodybuilder (`ma*.bmp`, 216x295, the opponent), each with its own pictures
//! and no palette swap (docs/fights/MK3.md "Sprites"). The 11 strips are
//! SALGIN's moves in the game's order (docs/salgin/GAME.md "The fight"):
//! soco (punch), voadora, rasteira (sweep), salto (jump kick), ginga (walk),
//! the jump, the guard (the rest pose), defesa (block), tombo (fall), the
//! reel, the victory (11 frames for the fighter, 22 for the bodybuilder), with a floor shadow baked
//! in (colour 100 in both). The bodybuilder faces left in the art.

const std = @import("std");
const strips = @import("strips.zig");
const Clip = strips.Clip;
const Ref = strips.Ref;
const Spec = strips.Spec;

pub const S = enum(u8) { soco, voo, ras, sal, gan, sat, gin, def, tomb, mup, win };

fn r(s: S, f: u8, ms: u32) Ref {
    return .{ .s = @backingInt(s), .f = f, .ms = ms };
}

/// The disc's strip files in the game's order (`g_fighterStripFiles`,
/// `g_opponentStripFiles`).
const fighter_files = [strips.strip_count][]const u8{
    "assets/SALGIN/VBBSOC.BMP", "assets/SALGIN/VBBVOO.BMP", "assets/SALGIN/VBRAS.BMP",  "assets/SALGIN/VBBSAL.BMP",
    "assets/SALGIN/VBBGAN.BMP", "assets/SALGIN/VBBSAT.BMP", "assets/SALGIN/VBGIN.BMP",  "assets/SALGIN/VBBDEF.BMP",
    "assets/SALGIN/VBTOMB.BMP", "assets/SALGIN/VBBMUP.BMP", "assets/SALGIN/VBBMEN.BMP",
};
const opponent_files = [strips.strip_count][]const u8{
    "assets/SALGIN/MAGASO.BMP", "assets/SALGIN/MACHVI.BMP", "assets/SALGIN/MABAND.BMP", "assets/SALGIN/MACHSA.BMP",
    "assets/SALGIN/MAGAAN.BMP", "assets/SALGIN/MAGASA.BMP", "assets/SALGIN/MAGING.BMP", "assets/SALGIN/MAGADE.BMP",
    "assets/SALGIN/MATOMB.BMP", "assets/SALGIN/MATOUP.BMP", "assets/SALGIN/MACOFI.BMP",
};

// ---- the fighter (the player; faces right) -----------------------------------

const f_punch = [_]Ref{ r(.soco, 0, 60), r(.soco, 1, 60), r(.soco, 2, 60) };
/// The jump kick's horizontal kick (frame 1), back to the stance after it.
const f_kick = [_]Ref{ r(.sal, 0, 60), r(.sal, 1, 60), r(.sal, 0, 60) };
/// The flip into the flying kick: the blow is the last frame.
const f_high = [_]Ref{ r(.voo, 0, 60), r(.voo, 1, 60), r(.voo, 2, 60), r(.voo, 0, 60) };
const f_sweep = [_]Ref{ r(.ras, 0, 60), r(.ras, 1, 60), r(.ras, 2, 60) };
const f_hit = [_]Ref{ r(.mup, 0, 60), r(.mup, 1, 140), r(.mup, 2, 60) };
const f_jump = [_]Ref{ r(.sat, 0, 130), r(.sat, 1, 130), r(.sat, 2, 130) };
const f_win = [_]Ref{ r(.win, 2, 110), r(.win, 3, 110), r(.win, 4, 110), r(.win, 5, 110), r(.win, 6, 110), r(.win, 7, 110), r(.win, 8, 110), r(.win, 9, 110), r(.win, 10, 110) };

const fighter_clips = [_]Clip{
    .{ .anim = .stance, .mode = .reg, .loop = true, .refs = &.{ r(.gin, 0, 200), r(.gin, 1, 200), r(.gin, 2, 200), r(.gin, 1, 200) } },
    // The art has no crouch: the sweep's lowest pose, on its own feet.
    .{ .anim = .crouch, .mode = .low, .loop = true, .cap = true, .refs = &.{r(.ras, 1, 100)} },
    .{ .anim = .walk_f, .mode = .reg, .loop = true, .refs = &.{ r(.gan, 0, 90), r(.gan, 1, 90), r(.gan, 2, 90), r(.gan, 1, 90) } },
    .{ .anim = .walk_b, .mode = .reg, .loop = true, .refs = &.{ r(.gan, 2, 90), r(.gan, 1, 90), r(.gan, 0, 90), r(.gan, 1, 90) } },
    .{ .anim = .jump_u, .mode = .low, .refs = &f_jump },
    .{ .anim = .jump_f, .mode = .low, .refs = &f_jump },
    .{ .anim = .jump_b, .mode = .low, .refs = &f_jump },
    .{ .anim = .lp, .mode = .reg, .refs = &f_punch, .active = .{ 1, 1 } },
    .{ .anim = .hp, .mode = .reg, .refs = &f_punch, .active = .{ 1, 1 } },
    // The kick is the jump kick's mid-air frame: on its own feet (in the art's
    // registration it floats above the opponent's head).
    .{ .anim = .lk, .mode = .air, .refs = &f_kick, .active = .{ 1, 1 } },
    .{ .anim = .hk, .mode = .reg, .refs = &f_high, .active = .{ 2, 2 } },
    .{ .anim = .roundhouse, .mode = .reg, .refs = &f_high, .active = .{ 2, 2 } },
    .{ .anim = .c_lp, .mode = .reg, .cap = true, .refs = &f_punch, .active = .{ 1, 1 } },
    .{ .anim = .uppercut, .mode = .reg, .cap = true, .refs = &f_punch, .active = .{ 1, 1 } },
    .{ .anim = .c_lk, .mode = .air, .cap = true, .refs = &f_kick, .active = .{ 1, 1 } },
    .{ .anim = .sweep, .mode = .reg, .cap = true, .refs = &f_sweep, .active = .{ 1, 1 } },
    .{ .anim = .j_lp, .mode = .air, .refs = &f_punch, .active = .{ 1, 1 } },
    .{ .anim = .j_hp, .mode = .air, .refs = &f_punch, .active = .{ 1, 1 } },
    .{ .anim = .j_lk, .mode = .air, .refs = &f_kick, .active = .{ 1, 1 } },
    .{ .anim = .j_hk, .mode = .air, .refs = &f_high, .active = .{ 2, 2 } },
    .{ .anim = .throw, .mode = .reg, .refs = &f_punch, .active = .{ 1, 1 } },
    .{ .anim = .block_hi, .mode = .reg, .loop = true, .refs = &.{r(.def, 1, 100)} },
    .{ .anim = .block_lo, .mode = .reg, .loop = true, .cap = true, .refs = &.{r(.def, 1, 100)} },
    .{ .anim = .hit_hi, .mode = .reg, .refs = &f_hit },
    .{ .anim = .hit_lo, .mode = .reg, .cap = true, .refs = &f_hit },
    .{ .anim = .fall, .mode = .low, .hurt = false, .refs = &.{r(.tomb, 1, 100)} },
    .{ .anim = .down, .mode = .low, .hurt = false, .loop = true, .refs = &.{r(.tomb, 2, 100)} },
    .{ .anim = .win, .mode = .reg, .loop = true, .refs = &f_win },
    .{ .anim = .getup, .mode = .low, .refs = &.{ r(.tomb, 2, 40), r(.tomb, 1, 40), r(.tomb, 0, 40) } },
};

const fighter_spec: Spec = .{
    .name = "salgin-fighter",
    .shadow = 100,
    .faces_left = false,
    .rest = r(.gin, 0, 0),
    .clips = &fighter_clips,
    .files = fighter_files,
    .frame_h = 279,
};

/// The bodybuilder's art reaches 108 px with a punch or a kick, the fighter's
/// 90: its hit boxes are cut to this (1.1 times; the fair fight's opponent and
/// fighter both struck from a gap of 100 in SALGIN, and uncut a novice bot
/// wins 77 rounds in 100 instead of 87).
const bodybuilder_reach: i32 = 98;

// ---- the bodybuilder (the opponent; faces left in the art) -------------------

const o_punch = [_]Ref{ r(.soco, 0, 60), r(.soco, 1, 60), r(.soco, 2, 60) };
/// Its front kick (voadora, frame 1), then the stance.
const o_kick = [_]Ref{ r(.voo, 0, 60), r(.voo, 1, 60), r(.voo, 0, 60) };
/// The high kick: the blow is the last frame.
const o_high = [_]Ref{ r(.voo, 0, 60), r(.voo, 1, 60), r(.voo, 2, 60), r(.voo, 0, 60) };
/// Its lunge (the sweep strip's frame 1; frame 2 turns its back).
const o_sweep = [_]Ref{ r(.ras, 0, 60), r(.ras, 1, 60), r(.ras, 1, 60) };
/// The jump kick: the stride, then the flying kick.
const o_air = [_]Ref{ r(.sal, 0, 60), r(.sal, 1, 60), r(.sal, 2, 60) };
const o_hit = [_]Ref{ r(.mup, 0, 60), r(.mup, 1, 140), r(.mup, 2, 60) };
const o_jump = [_]Ref{ r(.sat, 0, 130), r(.sat, 1, 130), r(.sat, 2, 130) };
const o_win = blk: {
    var refs: [20]Ref = undefined;
    for (&refs, 0..) |*e, i| e.* = r(.win, @intCast(i + 2), 100);
    break :blk refs;
};

const opponent_clips = [_]Clip{
    .{ .anim = .stance, .mode = .reg, .loop = true, .refs = &.{ r(.gin, 0, 200), r(.gin, 1, 200), r(.gin, 2, 200), r(.gin, 1, 200) } },
    .{ .anim = .crouch, .mode = .low, .loop = true, .cap = true, .refs = &.{r(.ras, 1, 100)} },
    .{ .anim = .walk_f, .mode = .reg, .loop = true, .refs = &.{ r(.gan, 0, 110), r(.gan, 1, 110), r(.gan, 2, 110), r(.gan, 1, 110) } },
    .{ .anim = .walk_b, .mode = .reg, .loop = true, .refs = &.{ r(.gan, 2, 110), r(.gan, 1, 110), r(.gan, 0, 110), r(.gan, 1, 110) } },
    .{ .anim = .jump_u, .mode = .low, .refs = &o_jump },
    .{ .anim = .jump_f, .mode = .low, .refs = &o_jump },
    .{ .anim = .jump_b, .mode = .low, .refs = &o_jump },
    .{ .anim = .lp, .mode = .reg, .refs = &o_punch, .active = .{ 1, 1 } },
    .{ .anim = .hp, .mode = .reg, .refs = &o_punch, .active = .{ 1, 1 } },
    .{ .anim = .lk, .mode = .reg, .refs = &o_kick, .active = .{ 1, 1 } },
    .{ .anim = .hk, .mode = .reg, .refs = &o_high, .active = .{ 2, 2 } },
    .{ .anim = .roundhouse, .mode = .reg, .refs = &o_high, .active = .{ 2, 2 } },
    .{ .anim = .c_lp, .mode = .reg, .cap = true, .refs = &o_punch, .active = .{ 1, 1 } },
    .{ .anim = .uppercut, .mode = .reg, .cap = true, .refs = &o_punch, .active = .{ 1, 1 } },
    .{ .anim = .c_lk, .mode = .reg, .cap = true, .refs = &o_kick, .active = .{ 1, 1 } },
    .{ .anim = .sweep, .mode = .reg, .cap = true, .refs = &o_sweep, .active = .{ 1, 1 } },
    .{ .anim = .j_lp, .mode = .air, .refs = &o_punch, .active = .{ 1, 1 } },
    .{ .anim = .j_hp, .mode = .air, .refs = &o_punch, .active = .{ 1, 1 } },
    .{ .anim = .j_lk, .mode = .air, .refs = &o_air, .active = .{ 2, 2 } },
    .{ .anim = .j_hk, .mode = .air, .refs = &o_air, .active = .{ 2, 2 } },
    .{ .anim = .throw, .mode = .reg, .refs = &o_punch, .active = .{ 1, 1 } },
    .{ .anim = .block_hi, .mode = .reg, .loop = true, .refs = &.{r(.def, 1, 100)} },
    .{ .anim = .block_lo, .mode = .reg, .loop = true, .cap = true, .refs = &.{r(.def, 1, 100)} },
    .{ .anim = .hit_hi, .mode = .reg, .refs = &o_hit },
    .{ .anim = .hit_lo, .mode = .reg, .cap = true, .refs = &o_hit },
    .{ .anim = .fall, .mode = .low, .hurt = false, .refs = &.{r(.tomb, 1, 100)} },
    .{ .anim = .down, .mode = .low, .hurt = false, .loop = true, .refs = &.{r(.tomb, 2, 100)} },
    .{ .anim = .win, .mode = .reg, .loop = true, .refs = &o_win },
    .{ .anim = .getup, .mode = .low, .refs = &.{ r(.tomb, 2, 40), r(.tomb, 1, 40), r(.tomb, 0, 40) } },
};

const opponent_spec: Spec = .{
    .name = "salgin-bodybuilder",
    .max_reach = bodybuilder_reach,
    .shadow = 100,
    .faces_left = true,
    .rest = r(.gin, 0, 0),
    .clips = &opponent_clips,
    .files = opponent_files,
    .frame_h = 295,
};

pub const pair: strips.Pair = .{ &fighter_spec, &opponent_spec };

// ---- tests -----------------------------------------------------------------------

test "the disc's strips make both characters, every move" {
    var reach: [2]i32 = undefined;
    for (pair, 0..) |spec, i| reach[i] = try strips.checkSpec(spec);
    // The bodybuilder outreaches the fighter, a little (the cut).
    try std.testing.expect(reach[1] > reach[0] and reach[1] <= bodybuilder_reach);
}
