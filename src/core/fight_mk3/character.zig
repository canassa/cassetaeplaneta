//! A fighter's art and boxes: loaded from a pack (`tools/ryu_pack.py` writes
//! one; the SF3 Ryu pack is private, not in git) or built from XILINDRO's
//! own strips (`strips.zig`; docs/fights/MK3.md "Sprites").
//! The engine knows no sprite: a character is a table of moves (`Anim`) to
//! clips (frames, ms per frame, loop, the active frames of an attack), and
//! each frame carries its picture (8-bit palette indices, facing right,
//! trimmed), the offset of its top-left from the fighter's feet anchor and
//! its hurt and hit boxes (anchor-relative, y up negative), all in source
//! pixels; `scale_fp` is the on-screen size of a source pixel (1/256 px):
//! the pack says how tall the fighter stands (`stand`, source px) and the
//! engine sizes it to MK3's standing height (`setStandPx`).
//!
//! Pack file: `MK3P`, u32 JSON length, the JSON, the pixel blob.

const std = @import("std");

/// The moves a character must have (clip names in the pack).
pub const Anim = enum(u8) {
    stance,
    crouch,
    walk_f,
    walk_b,
    jump_u,
    jump_f,
    jump_b,
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
    block_hi,
    block_lo,
    hit_hi,
    hit_lo,
    fall,
    down,
    win,
    taunt,
    /// Optional: a character without it gets up with its `crouch`.
    getup,

    pub const count = @typeInfo(Anim).@"enum".field_names.len;
};

pub const Box = [4]i16;

pub const Frame = struct {
    w: u16,
    h: u16,
    ox: i16,
    oy: i16,
    off: u32,
    hurt: ?Box = null,
    hit: ?Box = null,
    /// The picture's floor shadow, when the art has it apart from the body
    /// (index into the frame table): drawn on the floor under the fighter
    /// whatever the height of the body (its `ox` is from the body's anchor
    /// x, its `oy` from the floor).
    shadow: ?u16 = null,
};

pub const Clip = struct {
    name: []const u8,
    frames: []const u16,
    ms: []const u32,
    loop: bool = false,
    active: ?[2]u16 = null,

    /// Native length of the clip, ms.
    pub fn totalMs(c: *const Clip) u32 {
        var t: u32 = 0;
        for (c.ms) |m| t += m;
        return t;
    }
};

pub const Json = struct {
    name: []const u8,
    scale: f64 = 2,
    /// The stance's height, source px (0: the pack's `scale` stands).
    stand: f64 = 0,
    /// Screen px: how close two grounded fighters stand and how far a throw
    /// reaches (0: the engine's, `tables.min_sep` / `throw_range`, which
    /// are Ryu's wide pictures'): a character's own art sets them.
    min_sep: i32 = 0,
    throw_range: i32 = 0,
    palette: []const [3]u8,
    frames: []const Frame,
    clips: []const Clip,
};

pub const Character = struct {
    parsed: std.json.Parsed(Json),
    data: []u8,
    blob: []const u8,
    gpa: std.mem.Allocator,
    clips: [Anim.count]?*const Clip = @splat(null),
    /// Screen px (1/256) per source pixel.
    scale_fp: i32 = 512,

    pub const Error = error{ BadPack, MissingClip, OutOfMemory };

    /// Parses `bytes` (the pack file, whose ownership passes to the
    /// character on success).
    pub fn load(gpa: std.mem.Allocator, bytes: []u8) Error!Character {
        if (bytes.len < 8 or !std.mem.eql(u8, bytes[0..4], "MK3P")) return error.BadPack;
        const n = std.mem.readInt(u32, bytes[4..8], .little);
        if (8 + n > bytes.len) return error.BadPack;
        const parsed = std.json.parseFromSlice(Json, gpa, bytes[8..][0..n], .{ .ignore_unknown_fields = true }) catch |e| switch (e) {
            error.OutOfMemory => return error.OutOfMemory,
            else => return error.BadPack,
        };
        return adopt(gpa, parsed, bytes, bytes[8 + n ..]);
    }

    /// A character made in memory (`strips.zig`): `parsed` is a
    /// `std.json.Parsed(Json)` whose arena the caller allocated from `gpa`,
    /// `blob` the pixels (`data` is what the character frees: the pack's
    /// bytes, or the blob itself; both are owned by it on success).
    pub fn adopt(gpa: std.mem.Allocator, parsed: std.json.Parsed(Json), data: []u8, blob: []const u8) Error!Character {
        var c: Character = .{ .parsed = parsed, .data = data, .blob = blob, .gpa = gpa };
        c.scale_fp = @intFromFloat(@round(parsed.value.scale * 256));
        errdefer c.parsed.deinit();
        inline for (@typeInfo(Anim).@"enum".field_names) |name| {
            const a: Anim = @field(Anim, name);
            for (c.parsed.value.clips) |*cl| {
                if (std.mem.eql(u8, cl.name, name)) c.clips[@backingInt(a)] = cl;
            }
            // Every move but the optional ones is needed.
            if (c.clips[@backingInt(a)] == null and a != .taunt and a != .getup) return error.MissingClip;
        }
        for (c.parsed.value.frames) |fr| {
            if (@as(usize, fr.off) + @as(usize, fr.w) * fr.h > c.blob.len) return error.BadPack;
        }
        return c;
    }

    pub fn deinit(c: *Character) void {
        c.parsed.deinit();
        c.gpa.free(c.data);
        c.* = undefined;
    }

    /// Sizes the fighter to stand `px` screen pixels tall (a pack with no
    /// `stand` keeps its own scale).
    pub fn setStandPx(c: *Character, px: f64) void {
        const st = c.parsed.value.stand;
        if (st > 0) c.scale_fp = @intFromFloat(@round(px * 256 / st));
    }

    /// The farthest a blow of this character reaches from its anchor, screen px.
    pub fn reachPx(c: *const Character) i32 {
        var r: i32 = 0;
        for (c.parsed.value.frames) |f| if (f.hit) |h| {
            r = @max(r, h[2]);
        };
        return @divTrunc(r * c.scale_fp, 256);
    }

    /// Half the width of the stance's hurt box, screen px.
    pub fn halfPx(c: *const Character) i32 {
        const clp = c.clip(.stance);
        const h = c.frame(clp.frames[0]).hurt orelse return 0;
        return @divTrunc(h[2] * c.scale_fp, 256);
    }

    pub fn palette(c: *const Character) []const [3]u8 {
        return c.parsed.value.palette;
    }

    pub fn clip(c: *const Character, a: Anim) *const Clip {
        const fallback: Anim = if (a == .getup) .crouch else .stance;
        return c.clips[@backingInt(a)] orelse c.clips[@backingInt(fallback)].?;
    }

    pub fn frame(c: *const Character, id: u16) *const Frame {
        return &c.parsed.value.frames[id];
    }

    pub fn pixels(c: *const Character, f: *const Frame) []const u8 {
        return c.blob[f.off..][0 .. @as(usize, f.w) * f.h];
    }
};

/// The frame of `clip` at `ms` into it (a looping clip wraps, the others
/// hold their last frame): the index into `clip.frames`.
pub fn frameAtMs(clip: *const Clip, ms: u32) usize {
    const total = clip.totalMs();
    if (total == 0) return 0;
    var t = if (clip.loop) ms % total else @min(ms, total - 1);
    for (clip.ms, 0..) |m, i| {
        if (t < m) return i;
        t -= m;
    }
    return clip.frames.len - 1;
}

test "frameAtMs wraps loops and holds the end" {
    const frames = [_]u16{ 0, 1, 2 };
    const ms = [_]u32{ 100, 50, 50 };
    var c: Clip = .{ .name = "x", .frames = &frames, .ms = &ms, .loop = true };
    try std.testing.expectEqual(@as(usize, 0), frameAtMs(&c, 99));
    try std.testing.expectEqual(@as(usize, 1), frameAtMs(&c, 100));
    try std.testing.expectEqual(@as(usize, 2), frameAtMs(&c, 199));
    try std.testing.expectEqual(@as(usize, 0), frameAtMs(&c, 200));
    c.loop = false;
    try std.testing.expectEqual(@as(usize, 2), frameAtMs(&c, 5000));
}
