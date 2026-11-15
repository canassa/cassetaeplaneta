//! Port unit `tables` (module) of JARDIM.EXE: the trigonometric tables.
//! `raycast_build_tables` computes seven 16.16 tables with the CRT's x87
//! math; the port embeds them, precomputed bit-exact by
//! `tools/jardim_tables.py` (an exact model of the x87 steps, every entry
//! checked against the original routine run in tools/oracle) into
//! `tables.bin` (docs/jardim/DESIGN.md "The tables").

const std = @import("std");
const game_mod = @import("core/game.zig");
const Game = game_mod.Game;

/// The angle index range of tables 0-3, 5, 6 (0..2880, 2880 = 0 again).
pub const angle_count = 2881;
/// Table 4: the angle offsets -240..240 from the view centre.
pub const view_count = 481;
const sizes = [7]usize{ angle_count, angle_count, angle_count, angle_count, view_count, angle_count, angle_count };

/// The seven tables back to back as little-endian i32 (17,767 entries).
const bin = @embedFile("tables.bin");

comptime {
    var n: usize = 0;
    for (sizes) |s| n += s;
    std.debug.assert(bin.len == 4 * n);
}

/// Entry `i` of table `k` from the embedded bytes (no alignment).
fn entry(k: usize, i: usize) i32 {
    var off: usize = 0;
    for (sizes[0..k]) |s| off += 4 * s;
    return std.mem.readInt(i32, bin[off + 4 * i ..][0..4], .little);
}

// @orig 1028:0077 raycast_build_tables
/// Allocates the seven tables from the task's heap (the original
/// `_fmalloc`s them on every labyrinth backdrop create and never frees
/// them) and fills them: [0] tan·65536, [1] 65536/tan, [2] ±32·|tan|·65536,
/// [3] ±32·|cot|·65536, [5] 65536/cos, [6] 65536/sin for i = 0..2880, and
/// [4][i+240] = 22500/cos·65536 for i = -240..240, of the angle
/// `angleToRadians(i)`; every value rounded to f32, clamped to ±2³¹ and
/// truncated by `_ftol`: the precomputed `tables.bin`.
pub fn build(g: *Game) error{OutOfMemory}!void {
    for (sizes, 0..) |n, k| {
        const t = try g.local().alloc(i32, n);
        for (t, 0..) |*v, i| v.* = entry(k, i);
        g.tables.trig[k] = t;
    }
}

// @orig 1028:003b raycast_angle_to_radians
/// The table angle index in radians (2880 per turn): an even index is
/// bumped to the next odd one, then (2i)·(π/2880) + 0.0003272 in the x87's
/// extended precision, stored as a float (`g_angleRadians`). Only the
/// tests call it: the tables are precomputed.
pub fn angleToRadians(index: i16) f32 {
    var i = index;
    if (i & 1 == 0) i +%= 1;
    const step: f64 = @bitCast(@as(u64, 0x3f51df46a25ca311)); // g_angleStep, 10d0:13ee
    const bias: f64 = @bitCast(@as(u64, 0x3f3571814c9bba05)); // g_angleBias, 10d0:13f6
    const a: f80 = @as(f80, @floatFromInt(i *% 2)) * @as(f80, step);
    return @floatCast(a + @as(f80, bias));
}

// ---- tests ----

test "tables.bin is the generator's output" {
    var h: [32]u8 = undefined;
    std.crypto.hash.sha2.Sha256.hash(bin, &h, .{});
    try std.testing.expectEqualStrings(
        "f952dae0962b3baab94014d467b16ad57577ec98cc807e533877410e1379a371",
        &std.fmt.bytesToHex(h, .lower),
    );
}

// @orig 1028:0077 raycast_build_tables oracle=emulated
test "build: 50 entries against the original run in tools/oracle" {
    // { table, index, value } from `tools/jardim_tables.py --spot`
    const spots = [_][3]i32{
        .{ 0, 0, 164 },          .{ 0, 1, 164 },          .{ 0, 361, 65865 },
        .{ 0, 719, 35338956 },   .{ 0, 720, -26122360 },  .{ 0, 1439, -121 },
        .{ 0, 2000, 181473 },    .{ 0, 2880, 164 },       .{ 1, 0, 26121754 },
        .{ 1, 359, 65779 },      .{ 1, 720, -164 },       .{ 1, 1081, -65865 },
        .{ 1, 1440, 26120664 },  .{ 1, 2159, 121 },       .{ 1, 2879, -35343728 },
        .{ 2, 0, 5261 },         .{ 2, 1, 5261 },         .{ 2, 718, 1130846592 },
        .{ 2, 1439, 3889 },      .{ 2, 1440, -5261 },     .{ 2, 2161, -835965888 },
        .{ 2, 2880, -5261 },     .{ 3, 0, 835896128 },    .{ 3, 719, 3889 },
        .{ 3, 720, -5261 },      .{ 3, 1500, -15626392 }, .{ 3, 2159, -3888 },
        .{ 3, 2160, 5261 },      .{ 3, 2880, 835911552 }, .{ 4, 0, 1700217856 },
        .{ 4, 1, 1700217856 },   .{ 4, 120, 1525556096 }, .{ 4, 239, 1474562560 },
        .{ 4, 240, 1474564608 }, .{ 4, 241, 1474564608 }, .{ 4, 480, 1705150464 },
        .{ 5, 0, 65536 },        .{ 5, 717, 10540141 },   .{ 5, 720, -26122442 },
        .{ 5, 1440, -65536 },    .{ 5, 2163, 9536483 },   .{ 5, 2700, 70862 },
        .{ 5, 2880, 65536 },     .{ 6, 0, 26121836 },     .{ 6, 3, 9536489 },
        .{ 6, 720, 65536 },      .{ 6, 1437, 10540013 },  .{ 6, 1442, -9536378 },
        .{ 6, 2160, -65536 },    .{ 6, 2880, 26122318 },
    };
    const t = try game_mod.TestGame.init(std.testing.allocator);
    defer t.deinit();
    const g = t.game;
    try build(g);
    for (sizes, 0..) |n, k| try std.testing.expectEqual(n, g.tables.trig[k].len);
    for (spots) |s| {
        const k: usize = @intCast(s[0]);
        const i: usize = @intCast(s[1]);
        try std.testing.expectEqual(s[2], g.tables.trig[k][i]);
    }
}

// @orig 1028:003b raycast_angle_to_radians oracle=emulated
test "angleToRadians against the oracle's g_angleRadians" {
    const spots = [_]struct { i16, u32 }{
        .{ 0, 0x3b246bb6 },    .{ 1, 0x3b246bb6 },    .{ 2, 0x3be13010 },    .{ 7, 0x3c7f923d },
        .{ 100, 0x3e61f8a2 },  .{ 239, 0x3f059109 },  .{ -240, 0xbf056626 }, .{ -1, 0xbaf31168 },
        .{ 240, 0x3f06aefd },  .{ 480, 0x3f865cc8 },  .{ 719, 0x3fc8d316 },  .{ 720, 0x3fc96210 },
        .{ 721, 0x3fc96210 },  .{ 1000, 0x400bc973 }, .{ 1439, 0x4048f178 }, .{ 1440, 0x404938f6 },
        .{ 2160, 0x4096e071 }, .{ 2500, 0x40ae9cfb }, .{ 2879, 0x40c900aa }, .{ 2880, 0x40c92468 },
    };
    for (spots) |s| try std.testing.expectEqual(s[1], @as(u32, @bitCast(angleToRadians(s[0]))));
}
