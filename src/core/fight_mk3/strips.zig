//! The strip converter: a game's own fighter art as MK3 characters, built in
//! memory from the strips the game has loaded (the disc's files: nothing
//! private, no pack, nothing to ship: docs/fights/MK3.md "Sprites"). Generic
//! over the game: each game's table (`art_xilindro.zig`, `art_salgin.zig`:
//! a `Spec` per character) names the strips, the shadow colour, the facing,
//! the move-to-strip clips and the tuning (reach caps, separation, throw
//! range); `glue.zig` hands in the loaded DIBs.
//!
//! The strips are stacked frames, 8 bits, the key colour 11 transparent
//! (`g_unk00A8`, what the original blits skip) and a floor shadow baked in
//! (its colour index is the spec's). A character whose art faces left is
//! mirrored here, so every character's frames face right as `character.zig`
//! wants.
//!
//! The converter's rules (docs/fights/MK3.md "Sprites"):
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

/// Strips per character (both games' fighters have 11; a strip's frame count
/// is the game's, up to `max_frames`).
pub const strip_count = 11;
pub const max_frames = 24;

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

pub const Mode = enum { reg, air, low };

/// A frame of a strip (`s`: the strip's index in the game's order, an enum
/// in the game's table) for `ms` milliseconds.
pub const Ref = struct { s: u8, f: u8, ms: u32 };

pub const Clip = struct {
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

/// One character's table: everything the converter needs that the pictures
/// do not say.
pub const Spec = struct {
    /// The character's name (the `Json` name).
    name: []const u8,
    /// The shadow's colour index in the strips.
    shadow: u8,
    /// The art faces left (the frames are mirrored).
    faces_left: bool,
    /// The farthest a hit box reaches from the anchor, px (the art's reach
    /// is cut to it).
    max_reach: i32 = 1 << 20,
    /// Screen px: how close two grounded fighters stand and how far a throw
    /// reaches (a punch has to reach a body at the closest they stand).
    min_sep: i32 = 2 * trunk + 20,
    throw_range: i32 = 2 * trunk + 24,
    /// The rest pose: the anchors come from it.
    rest: Ref,
    clips: []const Clip,
    /// The disc's strip files (relative to the repo, in the game's strip
    /// order) and the height of one frame: the tests' loader reads them.
    files: [strip_count][]const u8,
    frame_h: u16,
};

/// A game's two characters (the player, the opponent).
pub const Pair = [2]*const Spec;

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
    pics: [strip_count][max_frames]?Pic = @splat(@splat(null)),
    /// The rest pose's anchor: the legs' centre and the floor line.
    ax: i32 = 0,
    gy: i32 = 0,
    stand: i32 = 0,

    fn pix(b: *const Builder, s: u8, f: usize, x: usize, y: usize) u8 {
        const st = b.art.strips[s];
        const xx = if (b.spec.faces_left) st.width - 1 - x else x;
        return st.at(f, xx, y);
    }

    fn remap(v: u8) u8 {
        return if (v == key) 0 else if (v == 0) key else v;
    }

    fn pic(b: *Builder, s: u8, f: u8) !Pic {
        if (b.pics[s][f]) |p| return p;
        const st = b.art.strips[s];
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
        b.pics[s][f] = p;
        return p;
    }

    /// The bounding box, from the anchor, of the body's pixels whose x from
    /// the anchor is within [lo, hi] (null when there are none).
    fn boxWhere(b: *const Builder, s: u8, f: u8, ax: i32, ay: i32, lo: i32, hi: i32) ?Box {
        const st = b.art.strips[s];
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

/// The character `spec` describes, from the strips in `art`.
pub fn build(gpa: std.mem.Allocator, art: *const Art, spec: *const Spec) Error!character.Character {
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
        .name = spec.name,
        .scale = 1,
        .stand = @floatFromInt(b.stand),
        .min_sep = spec.min_sep,
        .throw_range = spec.throw_range,
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

// ---- tests (each game's table runs them on its own spec: `art_*.zig`) ----------------

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

/// Loads the disc's strips of `spec` (the files stay in `files`: the caller
/// frees them).
pub fn loadDisc(gpa: std.mem.Allocator, io: std.Io, spec: *const Spec, files: *[strip_count][]u8) !Art {
    var art: Art = undefined;
    var n: usize = 0;
    errdefer for (files[0..n]) |f| gpa.free(f);
    for (spec.files, 0..) |path, i| {
        files[i] = try std.Io.Dir.cwd().readFileAlloc(io, path, gpa, .limited(1 << 22));
        n += 1;
        art.strips[i] = try parseBmp(files[i], spec.frame_h, &art.palette);
    }
    return art;
}

/// Every strip of the spec is a file with the frames its clips read.
fn framesExist(spec: *const Spec, art: *const Art) !void {
    for (spec.clips) |c| for (c.refs) |ref| {
        try std.testing.expect(ref.f < art.strips[ref.s].count);
    };
}

/// A game's table converts: every move present, hurt and hit boxes where the
/// art has a body and a blow, the blows reach a body at the closest the
/// fighters stand. Returns the character's reach (screen px).
pub fn checkSpec(spec: *const Spec) !i32 {
    const gpa = std.testing.allocator;
    var files: [strip_count][]u8 = undefined;
    const art = try loadDisc(gpa, std.testing.io, spec, &files);
    defer for (files) |f| gpa.free(f);
    try framesExist(spec, &art);
    var c = try build(gpa, &art, spec);
    defer c.deinit();
    inline for (@typeInfo(Anim).@"enum".field_names) |nm| {
        const a: Anim = @field(Anim, nm);
        if (a != .taunt) try std.testing.expect(c.clips[@backingInt(a)] != null);
    }
    // A standing figure has a hurt box and a shadow; the attacks' active
    // frames a hit box.
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
    // The stance's height: the converter's `stand`; native size.
    try std.testing.expect(c.parsed.value.stand > 100 and c.parsed.value.stand < 200);
    try std.testing.expectEqual(@as(i32, 256), c.scale_fp);
    // The punch, the kick and the sweep reach a body `trunk` px wide at the
    // closest two fighters stand (a throw is closer still).
    const sep = c.parsed.value.min_sep;
    for ([_]Anim{ .hp, .lk, .hk, .sweep }) |a| {
        const cl = c.clip(a);
        const hit = c.frame(cl.frames[cl.active.?[0]]).hit.?;
        try std.testing.expect(hit[2] >= sep - trunk);
    }
    try std.testing.expect(c.parsed.value.throw_range > sep);
    return c.reachPx();
}
