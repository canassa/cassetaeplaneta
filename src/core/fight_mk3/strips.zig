//! XILINDRO's own art as MK3 characters: the fighter (`sb*.bmp`, 231x266,
//! the player) and the inmate (`sa*.bmp`, 252x295, the opponent), each with
//! its own pictures and no palette swap, built in memory from the strips the
//! game has loaded (the disc's files: nothing private, no pack, nothing to
//! ship: docs/fights/MK3.md "Sprites"; `fight_mk3/xilindro.zig` hands in the
//! DIBs).
//!
//! The 11 strips are stacked frames, 8 bits, the key colour 11 transparent
//! (`g_unk00A8`, what the original blits skip) and a floor shadow baked in
//! (colour 44 in the fighter's strips, 39 in the inmate's). The inmate faces
//! left in the art: its pictures are mirrored here, so every character's
//! frames face right as `character.zig` wants.
//!
//! The converter's rules (the table of which strip plays which move is
//! `fighter_clips` / `inmate_clips` below; docs/fights/MK3.md "Sprites"):
//! - Every strip is drawn on one registration (the art's own: the frames
//!   of all strips share one box and the feet stay put), so a `reg` frame
//!   anchors at the stance's feet (x: the centre of the legs of the rest
//!   strip's frame 0, y: its bottom edge) and the body moves as authored;
//!   an `air` frame keeps that x but anchors its own feet (the lowest body
//!   pixel; the engine lifts it on the jump's arc), a `low` frame anchors
//!   its own centroid and feet (the travelling frames: jumps, falls).
//! - The shadow is split from the body (a frame of its own, `Frame.shadow`)
//!   and drawn on the floor, so a jumper's shadow stays on the ground.
//! - Hurt box: the body's pixels within `trunk` px of the anchor (a limb
//!   out in front is not hittable). Hit box (the active frames of an
//!   attack): the pixels more than `limb_from` px in front of the anchor.
//!   A crouching move's hurt box is capped at 0.6 of the stance's height:
//!   the art has no crouch, and the engine's crouch has to avoid the high
//!   blows.
//! - Native size: a source pixel is a screen pixel (`scale` 1).

const std = @import("std");
const character = @import("character.zig");
const Anim = character.Anim;
const Frame = character.Frame;
const Box = character.Box;

pub const Who = enum { fighter, inmate };

/// The strips in the game's order (`g_fighterStripFiles`: soco chme rast chal
/// anda pula defa defe cai sego, then the fighter's `flut`, the inmate's
/// `come`).
pub const S = enum(u8) { soco, chme, rast, chal, anda, pula, defa, defe, cai, sego, last };
pub const strip_count = @typeInfo(S).@"enum".field_names.len;

/// One strip's pixels: `count` frames of `width` x `height` stacked, rows
/// padded to 4 bytes, bottom-up when `bottom_up` (a DIB's).
pub const Strip = struct {
    bits: []const u8,
    width: u16,
    height: u16,
    count: u16,
    bottom_up: bool = true,

    fn at(s: Strip, f: usize, x: usize, y: usize) u8 {
        const total = @as(usize, s.height) * s.count;
        const rr = f * s.height + y;
        const row = if (s.bottom_up) total - 1 - rr else rr;
        const stride = (@as(usize, s.width) + 3) & ~@as(usize, 3);
        return s.bits[row * stride + x];
    }
};

pub const Art = struct {
    strips: [strip_count]Strip,
    /// The DIB's colour table, RGB.
    palette: [256][3]u8,
};

/// The transparent colour index of the sprites.
const key: u8 = 11;
/// Pixels this far (px) either side of the anchor are the trunk (hurt box).
pub const trunk: i32 = 34;
/// A limb: the pixels farther than this (px) in front of the anchor.
pub const limb_from: i32 = 30;
/// A crouching hurt box's top, of the stance's height.
const crouch_cap_pct: i32 = 60;

/// The inmate's art reaches 140 px with a punch or a sweep, the fighter's 72
/// to 86: its hit boxes are cut to this (about 1.25 times the fighter's
/// longest reach; the Original's opponent hits from 130 px, the fighter from
/// 100, 1.3 times).
const inmate_reach: i32 = 105;

const Mode = enum { reg, air, low };

const Ref = struct { s: S, f: u8, ms: u32 };

fn r(s: S, f: u8, ms: u32) Ref {
    return .{ .s = s, .f = f, .ms = ms };
}

const Clip = struct {
    anim: Anim,
    mode: Mode,
    refs: []const Ref,
    /// Active frames of an attack (indices into `refs`): they get the hit box.
    active: ?[2]u16 = null,
    loop: bool = false,
    hurt: bool = true,
    /// The hurt box is capped (crouching).
    cap: bool = false,
};

const Spec = struct {
    /// The shadow's colour index in the strips.
    shadow: u8,
    faces_left: bool,
    /// The farthest a hit box reaches from the anchor, px (the art's reach
    /// is cut to it).
    max_reach: i32 = 1 << 20,
    /// The rest pose: the anchors come from it.
    rest: Ref,
    clips: []const Clip,
};

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

const fighter_spec: Spec = .{ .shadow = 44, .faces_left = false, .rest = r(.defa, 0, 0), .clips = &fighter_clips };

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

const inmate_spec: Spec = .{ .shadow = 39, .faces_left = true, .max_reach = inmate_reach, .rest = r(.defa, 0, 0), .clips = &inmate_clips };

// ---- the converter -------------------------------------------------------------------

/// A frame's picture, found once: the body's bounding box ([x0, x1) by
/// [y0, y1), strip coordinates after the mirroring), where its trimmed pixels
/// are in the blob, the same for the shadow, the body's centroid x.
const Pic = struct {
    x0: i32,
    y0: i32,
    x1: i32,
    y1: i32,
    off: u32,
    cx: i32,
    sx0: i32 = 0,
    sy0: i32 = 0,
    sx1: i32 = 0,
    sy1: i32 = 0,
    soff: u32 = 0,
    has_shadow: bool = false,
};

const Builder = struct {
    art: *const Art,
    spec: *const Spec,
    arena: std.mem.Allocator,
    gpa: std.mem.Allocator,
    blob: std.ArrayList(u8) = .empty,
    frames: std.ArrayList(Frame) = .empty,
    pics: [strip_count][4]?Pic = @splat(@splat(null)),
    /// The rest pose's anchor: the legs' centre and the floor line.
    ax: i32 = 0,
    gy: i32 = 0,
    stand: i32 = 0,

    fn pix(b: *const Builder, s: S, f: usize, x: usize, y: usize) u8 {
        const st = b.art.strips[@backingInt(s)];
        const xx = if (b.spec.faces_left) st.width - 1 - x else x;
        return st.at(f, xx, y);
    }

    fn remap(v: u8) u8 {
        return if (v == key) 0 else if (v == 0) key else v;
    }

    fn pic(b: *Builder, s: S, f: u8) !Pic {
        if (b.pics[@backingInt(s)][f]) |p| return p;
        const st = b.art.strips[@backingInt(s)];
        const w: usize = st.width;
        const h: usize = st.height;
        var p: Pic = .{ .x0 = 1 << 20, .y0 = 1 << 20, .x1 = -1, .y1 = -1, .off = 0, .cx = 0 };
        var sum: i64 = 0;
        var n: i64 = 0;
        var sh_x0: i32 = 1 << 20;
        var sh_y0: i32 = 1 << 20;
        var sh_x1: i32 = -1;
        var sh_y1: i32 = -1;
        for (0..h) |y| for (0..w) |x| {
            const v = b.pix(s, f, x, y);
            if (v == key) continue;
            const xi: i32 = @intCast(x);
            const yi: i32 = @intCast(y);
            if (v == b.spec.shadow) {
                sh_x0 = @min(sh_x0, xi);
                sh_y0 = @min(sh_y0, yi);
                sh_x1 = @max(sh_x1, xi + 1);
                sh_y1 = @max(sh_y1, yi + 1);
            } else {
                p.x0 = @min(p.x0, xi);
                p.y0 = @min(p.y0, yi);
                p.x1 = @max(p.x1, xi + 1);
                p.y1 = @max(p.y1, yi + 1);
                sum += xi;
                n += 1;
            }
        };
        if (n == 0) return error.EmptyFrame;
        p.cx = @intCast(@divTrunc(sum + @divTrunc(n, 2), n));
        p.off = @intCast(b.blob.items.len);
        try b.blob.ensureUnusedCapacity(b.gpa, @as(usize, @intCast((p.x1 - p.x0) * (p.y1 - p.y0))));
        var y: i32 = p.y0;
        while (y < p.y1) : (y += 1) {
            var x: i32 = p.x0;
            while (x < p.x1) : (x += 1) {
                const v = b.pix(s, f, @intCast(x), @intCast(y));
                b.blob.appendAssumeCapacity(if (v == b.spec.shadow) 0 else remap(v));
            }
        }
        if (sh_x1 > 0) {
            p.has_shadow = true;
            p.sx0 = sh_x0;
            p.sy0 = sh_y0;
            p.sx1 = sh_x1;
            p.sy1 = sh_y1;
            p.soff = @intCast(b.blob.items.len);
            y = sh_y0;
            while (y < sh_y1) : (y += 1) {
                var x: i32 = sh_x0;
                while (x < sh_x1) : (x += 1) {
                    const v = b.pix(s, f, @intCast(x), @intCast(y));
                    try b.blob.append(b.gpa, if (v == b.spec.shadow) remap(v) else 0);
                }
            }
        }
        b.pics[@backingInt(s)][f] = p;
        return p;
    }

    /// The bounding box, from the anchor, of the body's pixels whose x from
    /// the anchor is within [lo, hi] (null when there are none).
    fn boxWhere(b: *const Builder, s: S, f: u8, ax: i32, ay: i32, lo: i32, hi: i32) ?Box {
        const st = b.art.strips[@backingInt(s)];
        var x0: i32 = 1 << 20;
        var y0: i32 = 1 << 20;
        var x1: i32 = -(1 << 20);
        var y1: i32 = -(1 << 20);
        for (0..st.height) |y| for (0..st.width) |x| {
            const v = b.pix(s, f, x, y);
            if (v == key or v == b.spec.shadow) continue;
            const dx = @as(i32, @intCast(x)) - ax;
            if (dx < lo or dx > hi) continue;
            const dy = @as(i32, @intCast(y)) - ay;
            x0 = @min(x0, dx);
            y0 = @min(y0, dy);
            x1 = @max(x1, dx + 1);
            y1 = @max(y1, dy + 1);
        };
        if (x1 < x0) return null;
        return .{ @intCast(x0), @intCast(y0), @intCast(x1), @intCast(y1) };
    }

    fn anchors(b: *const Builder, p: Pic, mode: Mode) struct { x: i32, y: i32 } {
        return switch (mode) {
            .reg => .{ .x = b.ax, .y = b.gy },
            .air => .{ .x = b.ax, .y = p.y1 },
            .low => .{ .x = p.cx, .y = p.y1 },
        };
    }

    /// The anchors of the rest pose: the legs' centre (the body's pixels in
    /// the lowest third of the figure) and the floor line (its bottom edge).
    fn restAnchors(b: *Builder) !void {
        const rf = b.spec.rest;
        const p = try b.pic(rf.s, rf.f);
        const low = p.y1 - @max(1, @divTrunc((p.y1 - p.y0) * 3, 10));
        var sum: i64 = 0;
        var n: i64 = 0;
        var y: i32 = low;
        while (y < p.y1) : (y += 1) {
            var x: i32 = p.x0;
            while (x < p.x1) : (x += 1) {
                const v = b.pix(rf.s, rf.f, @intCast(x), @intCast(y));
                if (v == key or v == b.spec.shadow) continue;
                sum += x;
                n += 1;
            }
        }
        b.ax = @intCast(@divTrunc(sum + @divTrunc(n, 2), @max(n, 1)));
        b.gy = p.y1;
        b.stand = p.y1 - p.y0;
    }

    fn addFrame(b: *Builder, ref: Ref, c: Clip, idx: usize) !u16 {
        const p = try b.pic(ref.s, ref.f);
        const an = b.anchors(p, c.mode);
        var fr: Frame = .{
            .w = @intCast(p.x1 - p.x0),
            .h = @intCast(p.y1 - p.y0),
            .ox = @intCast(p.x0 - an.x),
            .oy = @intCast(p.y0 - an.y),
            .off = p.off,
        };
        if (c.hurt) {
            if (b.boxWhere(ref.s, ref.f, an.x, an.y, -trunk, trunk)) |hb| {
                var box = hb;
                if (c.cap) box[1] = @max(box[1], @as(i16, @intCast(-@divTrunc(b.stand * crouch_cap_pct, 100))));
                if (box[1] < box[3]) fr.hurt = box;
            }
        }
        if (c.active) |a| if (idx >= a[0] and idx <= a[1]) {
            // The limb: beyond `limb_from` and beyond half the farthest reach.
            const reach = b.boxWhere(ref.s, ref.f, an.x, an.y, 0, 1 << 20);
            const from = if (reach) |rb| @max(limb_from, @divTrunc(rb[2], 2)) else limb_from;
            fr.hit = b.boxWhere(ref.s, ref.f, an.x, an.y, from, 1 << 20) orelse
                b.boxWhere(ref.s, ref.f, an.x, an.y, 12, 1 << 20);
            if (fr.hit) |*hb| if (hb[2] > b.spec.max_reach) {
                hb[2] = @intCast(b.spec.max_reach);
                hb[0] = @min(hb[0], hb[2] - 12);
            };
        };
        if (p.has_shadow) {
            const sid: u16 = @intCast(b.frames.items.len);
            try b.frames.append(b.arena, .{
                .w = @intCast(p.sx1 - p.sx0),
                .h = @intCast(p.sy1 - p.sy0),
                .ox = @intCast(p.sx0 - an.x),
                .oy = @intCast(p.sy0 - b.gy),
                .off = p.soff,
            });
            fr.shadow = sid;
        }
        const id: u16 = @intCast(b.frames.items.len);
        try b.frames.append(b.arena, fr);
        return id;
    }
};

pub const Error = error{ EmptyFrame, OutOfMemory } || character.Character.Error;

/// The character of `who` from the strips in `art`.
pub fn build(gpa: std.mem.Allocator, art: *const Art, who: Who) Error!character.Character {
    const spec: *const Spec = switch (who) {
        .fighter => &fighter_spec,
        .inmate => &inmate_spec,
    };
    const arena_ptr = try gpa.create(std.heap.ArenaAllocator);
    arena_ptr.* = .init(gpa);
    var adopted = false;
    errdefer if (!adopted) {
        arena_ptr.deinit();
        gpa.destroy(arena_ptr);
    };
    const a = arena_ptr.allocator();
    var b: Builder = .{ .art = art, .spec = spec, .arena = a, .gpa = gpa };
    errdefer b.blob.deinit(gpa);
    try b.restAnchors();

    const clips = try a.alloc(character.Clip, spec.clips.len);
    for (spec.clips, clips) |c, *out| {
        const ids = try a.alloc(u16, c.refs.len);
        const ms = try a.alloc(u32, c.refs.len);
        for (c.refs, 0..) |ref, i| {
            ids[i] = try b.addFrame(ref, c, i);
            ms[i] = ref.ms;
        }
        out.* = .{ .name = @tagName(c.anim), .frames = ids, .ms = ms, .loop = c.loop, .active = if (c.active) |x| .{ x[0], x[1] } else null };
    }
    const palette = try a.alloc([3]u8, 256);
    for (palette, 0..) |*e, i| e.* = art.palette[Builder.remap(@intCast(i))];
    const json: character.Json = .{
        .name = if (who == .fighter) "xilindro-fighter" else "xilindro-inmate",
        .scale = 1,
        .stand = @floatFromInt(b.stand),
        .min_sep = 2 * trunk + 20,
        .throw_range = 2 * trunk + 24,
        .palette = palette,
        .frames = b.frames.items,
        .clips = clips,
    };
    const owned = try b.blob.toOwnedSlice(gpa);
    errdefer gpa.free(owned);
    // From here `adopt` frees the arena when it fails.
    adopted = true;
    return character.Character.adopt(gpa, .{ .arena = arena_ptr, .value = json }, owned, owned);
}

// ---- tests ---------------------------------------------------------------------------

/// The disc's strips (`assets/XILINDRO/<prefix><name>.BMP`) for the tests.
pub const test_names = [strip_count][]const u8{ "SOCO", "CHME", "RAST", "CHAL", "ANDA", "PULA", "DEFA", "DEFE", "CAI", "SEGO", "" };

/// Reads one 8-bit BMP file into a `Strip` over `bytes` (owned by the caller)
/// and its colour table.
pub fn parseBmp(bytes: []const u8, frame_h: u16, pal: *[256][3]u8) !Strip {
    const rd = std.mem.readInt;
    const off = rd(u32, bytes[10..14], .little);
    const w: u16 = @intCast(rd(i32, bytes[18..22], .little));
    const hh = rd(i32, bytes[22..26], .little);
    for (0..256) |i| pal[i] = .{ bytes[54 + i * 4 + 2], bytes[54 + i * 4 + 1], bytes[54 + i * 4] };
    return .{
        .bits = bytes[off..],
        .width = w,
        .height = frame_h,
        .count = @intCast(@divTrunc(@abs(hh), frame_h)),
        .bottom_up = hh > 0,
    };
}

/// Loads the disc's strips for `who` (the files stay in `files`: the caller
/// frees them).
pub fn loadDisc(gpa: std.mem.Allocator, io: std.Io, who: Who, files: *[strip_count][]u8) !Art {
    var art: Art = undefined;
    const prefix = if (who == .fighter) "SB" else "SA";
    const last = if (who == .fighter) "FLUT" else "COME";
    const fh: u16 = if (who == .fighter) 266 else 295;
    var n: usize = 0;
    errdefer for (files[0..n]) |f| gpa.free(f);
    for (0..strip_count) |i| {
        const nm = if (i == strip_count - 1) last else test_names[i];
        const path = try std.fmt.allocPrint(gpa, "assets/XILINDRO/{s}{s}.BMP", .{ prefix, nm });
        defer gpa.free(path);
        files[i] = try std.Io.Dir.cwd().readFileAlloc(io, path, gpa, .limited(1 << 22));
        n += 1;
        art.strips[i] = try parseBmp(files[i], fh, &art.palette);
    }
    return art;
}

test "the disc's strips make both characters, every move" {
    const gpa = std.testing.allocator;
    for ([2]Who{ .fighter, .inmate }) |who| {
        var files: [strip_count][]u8 = undefined;
        const art = try loadDisc(gpa, std.testing.io, who, &files);
        defer for (files) |f| gpa.free(f);
        var c = try build(gpa, &art, who);
        defer c.deinit();
        inline for (@typeInfo(Anim).@"enum".field_names) |nm| {
            const a: Anim = @field(Anim, nm);
            if (a != .taunt) try std.testing.expect(c.clips[@backingInt(a)] != null);
        }
        // A standing figure has a hurt box; the attacks' active frames a hit box.
        const stance = c.clip(.stance);
        const sf = c.frame(stance.frames[0]);
        try std.testing.expect(sf.hurt != null and sf.shadow != null);
        for ([_]Anim{ .lp, .hp, .lk, .hk, .roundhouse, .c_lp, .uppercut, .c_lk, .sweep, .j_lp, .j_hp, .j_lk, .j_hk }) |a| {
            const cl = c.clip(a);
            const act = cl.active.?;
            const fr = c.frame(cl.frames[act[0]]);
            try std.testing.expect(fr.hit != null);
            try std.testing.expect(fr.hit.?[2] > 0);
        }
        // Falls and the floor have no hurt box.
        try std.testing.expect(c.frame(c.clip(.down).frames[0]).hurt == null);
        // The crouch is lower than the stance.
        const crouch = c.frame(c.clip(.crouch).frames[0]);
        try std.testing.expect(crouch.hurt.?[1] > sf.hurt.?[1]);
        // The stance's height: the converter's `stand`.
        try std.testing.expect(c.parsed.value.stand > 100 and c.parsed.value.stand < 200);
        try std.testing.expectEqual(@as(i32, 256), c.scale_fp);
    }
}

test "every blow reaches an opponent standing as close as the fighters can" {
    const gpa = std.testing.allocator;
    var reach: [2]i32 = undefined;
    for ([2]Who{ .fighter, .inmate }, 0..) |who, i| {
        var files: [strip_count][]u8 = undefined;
        const art = try loadDisc(gpa, std.testing.io, who, &files);
        defer for (files) |f| gpa.free(f);
        var c = try build(gpa, &art, who);
        defer c.deinit();
        reach[i] = c.reachPx();
        const sep = c.parsed.value.min_sep;
        // The punch, the kick and the sweep of either reach a body `trunk` px
        // wide at the closest two fighters stand (a throw is closer still).
        for ([_]Anim{ .hp, .lk, .hk, .sweep }) |a| {
            const cl = c.clip(a);
            const hit = c.frame(cl.frames[cl.active.?[0]]).hit.?;
            try std.testing.expect(hit[2] >= sep - trunk);
        }
        try std.testing.expect(c.parsed.value.throw_range > sep);
    }
    // The inmate outreaches the fighter, by about the Original's 1.3.
    try std.testing.expect(reach[1] > reach[0] and reach[1] <= inmate_reach);
}
