//! Not in the original (`Fixes.inv_arcade_rules`): the arcade's four destructible bunkers
//! (docs/inv/ARCADE.md "Bunkers"). INV has no bunker art, so a bunker is a grid of 3 x 3 px
//! blocks, each one pixel of the arcade's 22 x 16 shield picture, eroded by the arcade's
//! explosion pictures (one block per picture pixel).
//!
//! The shield and the two explosions are the arcade's own bytes (Computer Archeology's
//! annotated disassembly: `ShieldImage` 1D20, `ShotExploding` 1C91, `AShotExplo` 1CDC). Each
//! picture is stored by columns, left to right; a column's bits are its pixels from the bottom
//! (bit 0) up, which is how the arcade's rotated video memory holds them.

const std = @import("std");

/// A block's side in screen pixels (the arcade's pixel, scaled).
pub const block = 3;
pub const cols = 22;
pub const rows = 16;
pub const width = cols * block;
pub const height = rows * block;

/// `ShieldImage`: 22 columns of 2 bytes (the low byte holds the bottom 8 pixels).
const shield_bytes = [44]u8{
    0xFF, 0x0F, 0xFF, 0x1F, 0xFF, 0x3F, 0xFF, 0x7F, 0xFF, 0xFF, 0xFC, 0xFF, 0xF8, 0xFF, 0xF0, 0xFF,
    0xF0, 0xFF, 0xF0, 0xFF, 0xF0, 0xFF, 0xF0, 0xFF, 0xF0, 0xFF, 0xF0, 0xFF, 0xF8, 0xFF, 0xFC, 0xFF,
    0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0x7F, 0xFF, 0x3F, 0xFF, 0x1F, 0xFF, 0x0F,
};

/// `ShotExploding` (the player's shot hitting something): 8 x 8.
pub const shot_burst = [8]u8{ 0x99, 0x3C, 0x7E, 0x3D, 0xBC, 0x3E, 0x7C, 0x99 };
/// `AShotExplo` (an alien shot hitting something): 6 x 8.
pub const bomb_burst = [6]u8{ 0x4A, 0x15, 0xBE, 0x3F, 0x5E, 0x25 };

pub const Bunker = struct {
    /// Screen position of the top left.
    x: i32,
    y: i32,
    /// `cells[col][row]`, row 0 the bottom row.
    cells: [cols][rows]bool = undefined,

    pub fn init(x: i32, y: i32) Bunker {
        var b: Bunker = .{ .x = x, .y = y };
        for (0..cols) |c| {
            const bits: u16 = shield_bytes[2 * c] | @as(u16, shield_bytes[2 * c + 1]) << 8;
            for (0..rows) |r| b.cells[c][r] = bits >> @intCast(r) & 1 != 0;
        }
        return b;
    }

    pub fn bottom(b: *const Bunker) i32 {
        return b.y + height;
    }

    /// The block under screen point (px, py) as (col, row), or null outside the bunker.
    pub fn blockAt(b: *const Bunker, px: i32, py: i32) ?struct { c: i32, r: i32 } {
        if (px < b.x or px >= b.x + width or py < b.y or py >= b.bottom()) return null;
        return .{ .c = @divFloor(px - b.x, block), .r = @divFloor(b.bottom() - 1 - py, block) };
    }

    pub fn live(b: *const Bunker, c: i32, r: i32) bool {
        if (c < 0 or c >= cols or r < 0 or r >= rows) return false;
        return b.cells[@intCast(c)][@intCast(r)];
    }

    pub fn count(b: *const Bunker) usize {
        var n: usize = 0;
        for (b.cells) |col| for (col) |v| {
            if (v) n += 1;
        };
        return n;
    }

    /// The live blocks the screen rectangle [x0, x1] x [y0, y1] (inclusive) overlaps: how many, and
    /// the one highest on screen (`top_r` the greatest row), with its column.
    pub const Touch = struct { n: u32 = 0, top_r: i32 = -1, top_c: i32 = 0, low_r: i32 = rows, low_c: i32 = 0 };
    pub fn touch(b: *const Bunker, x0: i32, y0: i32, x1: i32, y1: i32) Touch {
        var t: Touch = .{};
        if (x1 < b.x or x0 >= b.x + width or y1 < b.y or y0 >= b.bottom()) return t;
        const c0 = @max(0, @divFloor(x0 - b.x, block));
        const c1 = @min(cols - 1, @divFloor(x1 - b.x, block));
        const r0 = @max(0, @divFloor(b.bottom() - 1 - y1, block));
        const r1 = @min(rows - 1, @divFloor(b.bottom() - 1 - y0, block));
        var c = c0;
        while (c <= c1) : (c += 1) {
            var r = r0;
            while (r <= r1) : (r += 1) {
                if (!b.cells[@intCast(c)][@intCast(r)]) continue;
                t.n += 1;
                if (r > t.top_r) {
                    t.top_r = r;
                    t.top_c = c;
                }
                if (r < t.low_r) {
                    t.low_r = r;
                    t.low_c = c;
                }
            }
        }
        return t;
    }

    /// Clears the blocks the screen rectangle overlaps (an invader walking over the bunker, a shot's
    /// own pixels).
    pub fn erase(b: *Bunker, x0: i32, y0: i32, x1: i32, y1: i32) void {
        if (x1 < b.x or x0 >= b.x + width or y1 < b.y or y0 >= b.bottom()) return;
        const c0 = @max(0, @divFloor(x0 - b.x, block));
        const c1 = @min(cols - 1, @divFloor(x1 - b.x, block));
        const r0 = @max(0, @divFloor(b.bottom() - 1 - y1, block));
        const r1 = @min(rows - 1, @divFloor(b.bottom() - 1 - y0, block));
        var c = c0;
        while (c <= c1) : (c += 1) {
            var r = r0;
            while (r <= r1) : (r += 1) b.cells[@intCast(c)][@intCast(r)] = false;
        }
    }

    /// Clears the picture's set pixels with its bottom left at block (c0, r0).
    pub fn carve(b: *Bunker, picture: []const u8, c0: i32, r0: i32) void {
        for (picture, 0..) |col, i| {
            const c = c0 + @as(i32, @intCast(i));
            if (c < 0 or c >= cols) continue;
            for (0..8) |j| {
                if (col >> @intCast(j) & 1 == 0) continue;
                const r = r0 + @as(i32, @intCast(j));
                if (r < 0 or r >= rows) continue;
                b.cells[@intCast(c)][@intCast(r)] = false;
            }
        }
    }
};

test "the shield is the arcade's: 22 x 16, chamfered top corners, a notch at the bottom" {
    const b = Bunker.init(0, 0);
    // Column 0 holds the bottom 12 pixels; column 4 is whole; the notch is 4 deep in the middle.
    try std.testing.expect(b.live(0, 0) and b.live(0, 11) and !b.live(0, 12));
    try std.testing.expect(b.live(4, 15) and b.live(4, 0));
    try std.testing.expect(!b.live(7, 3) and b.live(7, 4));
    try std.testing.expect(!b.live(10, 3) and b.live(10, 4) and b.live(10, 15));
    try std.testing.expect(b.live(21, 11) and !b.live(21, 12));
    var bits: usize = 0;
    for (shield_bytes) |v| bits += @popCount(v);
    try std.testing.expectEqual(bits, b.count());
}

test "a burst clears its own pixels and only those" {
    var b = Bunker.init(0, 0);
    const before = b.count();
    b.carve(&shot_burst, 6, 4);
    var gone: usize = 0;
    for (shot_burst) |v| gone += @popCount(v);
    // Every pixel of the picture lay on lit shield here, so all of them clear.
    try std.testing.expectEqual(before - gone, b.count());
    // The picture's holes stay lit: column 6's bit 1 is clear in 0x99.
    try std.testing.expect(b.live(6, 5));
    try std.testing.expect(!b.live(6, 4));
}

test "touch finds the highest and the lowest live block of a rectangle" {
    const b = Bunker.init(100, 200);
    // The bunker's top row is at y 200..202; a rectangle over its whole width finds row 15.
    const t = b.touch(100, 190, 100 + width - 1, 210);
    try std.testing.expectEqual(@as(i32, 15), t.top_r);
    try std.testing.expect(t.n > 0);
    const none = b.touch(0, 0, 50, 50);
    try std.testing.expectEqual(@as(u32, 0), none.n);
}
