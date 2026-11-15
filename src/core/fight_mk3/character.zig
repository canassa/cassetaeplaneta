//! A fighter's art and boxes, loaded from a pack (`tools/ryu_pack.py` writes
//! one; the SF3 Ryu pack is private, not in git, docs/fights/MK3.md "Sprites").
//! The engine knows no sprite: a character is a table of moves (`Anim`) to
//! clips (frames, ms per frame, loop, the active frames of an attack), and
//! each frame carries its picture (8-bit palette indices, facing right,
//! trimmed), the offset of its top-left from the fighter's feet anchor and
//! its hurt and hit boxes (anchor-relative, y up negative), all in source
//! pixels; `scale` is the on-screen size of a source pixel.
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

const Json = struct {
    name: []const u8,
    scale: u8 = 2,
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
        var c: Character = .{ .parsed = parsed, .data = bytes, .blob = bytes[8 + n ..], .gpa = gpa };
        errdefer c.parsed.deinit();
        inline for (@typeInfo(Anim).@"enum".field_names) |name| {
            const a: Anim = @field(Anim, name);
            for (c.parsed.value.clips) |*cl| {
                if (std.mem.eql(u8, cl.name, name)) c.clips[@backingInt(a)] = cl;
            }
            // Every move but the taunt is needed.
            if (c.clips[@backingInt(a)] == null and a != .taunt) return error.MissingClip;
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

    pub fn scale(c: *const Character) i32 {
        return c.parsed.value.scale;
    }

    pub fn palette(c: *const Character) []const [3]u8 {
        return c.parsed.value.palette;
    }

    pub fn clip(c: *const Character, a: Anim) *const Clip {
        return c.clips[@backingInt(a)] orelse c.clips[@backingInt(Anim.stance)].?;
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
