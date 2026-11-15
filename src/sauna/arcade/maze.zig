//! Not in the original (`Fixes.sauna_arcade_rules`): SAUNA's maze as the arcade's tile grid.
//!
//! SAUNA's maze is 40 x 30 cells of 16 px with walls one cell thick and corridors two cells wide,
//! so a corridor's centre line runs along cell borders, and the peanuts (and corks) sit on that
//! line, at the corner shared by four cells. The tile grid is therefore the grid of those corners:
//! tile (a, b) is the 16-px square centred on pixel (16 a, 16 b), and it is floor when the four
//! cells around that corner are not wall. The dot of cell (c, r) is on tile (c + 1, r + 1). The
//! corridors are one tile wide, as the arcade's, with a junction every three tiles.
//!
//! Two repairs of the maze data (`g_maze`), both checked against the picture `3fpac2.bmp`:
//! - the cup in the middle is drawn closed except for a 4-cell door, but its maze rows leave four
//!   more cells open (16, 17, 22, 23 of row 12, drawn as wall): they are walls here;
//! - the pocket the picture draws closed (two boxes at the top and the four boxes in the middle) and
//!   everything else not reachable from Pacman's start is not floor.
//! The ghost house is the cup and its door; it is not floor (only the ghosts that leave it use it).

const std = @import("std");
const game = @import("../core/maze_data.zig");

/// Tiles across and down (corner points of the 40 x 30 cells, one more each way).
pub const w = game.maze_cols + 1;
pub const h = game.maze_rows + 1;

/// A tile.
pub const Tile = struct { a: i32, b: i32 };

/// Pacman's start, the tile under the cup (pixel (320, 320)).
pub const pac_start: Tile = .{ .a = 20, .b = 20 };
/// The door of the house (pixel (320, 192)); the tile above it is where the ghosts come out.
pub const door: Tile = .{ .a = 20, .b = 12 };

/// The house: the cup's inside (7 x 4 tiles), and the neck up to the door.
pub fn isHouse(a: i32, b: i32) bool {
    if (a >= 17 and a <= 23 and b >= 14 and b <= 17) return true;
    // The neck under the door is wider than the lane (the picture's door is 4 cells): all of it.
    return a >= 19 and a <= 21 and (b == 13 or b == 12);
}

pub const Tiles = struct {
    floor: [h][w]bool = @splat(@splat(false)),
    /// A dot: 1 a peanut, 2 a cork (an energizer).
    dots: [h][w]u8 = @splat(@splat(0)),
    dot_count: u16 = 0,

    /// Builds the grid from the maze rows ('1' wall, '2' peanut, '3' cork) as they are now.
    pub fn build(m: *const game.Maze) Tiles {
        var t: Tiles = .{};
        var raw: [h][w]bool = @splat(@splat(false));
        for (0..h) |bi| {
            for (0..w) |ai| {
                const a: i32 = @intCast(ai);
                const b: i32 = @intCast(bi);
                raw[bi][ai] = a >= 1 and b >= 1 and
                    !(wall(m, a - 1, b - 1) or wall(m, a, b - 1) or wall(m, a - 1, b) or wall(m, a, b)) and
                    !isHouse(a, b);
            }
        }
        // What Pacman can reach from his start.
        var stack: [h * w]Tile = undefined;
        var n: usize = 0;
        stack[0] = pac_start;
        n = 1;
        while (n > 0) {
            n -= 1;
            const p = stack[n];
            if (p.a < 0 or p.b < 0 or p.a >= w or p.b >= h) continue;
            const ai: usize = @intCast(p.a);
            const bi: usize = @intCast(p.b);
            if (!raw[bi][ai] or t.floor[bi][ai]) continue;
            t.floor[bi][ai] = true;
            for ([_]Tile{ .{ .a = 1, .b = 0 }, .{ .a = -1, .b = 0 }, .{ .a = 0, .b = 1 }, .{ .a = 0, .b = -1 } }) |d| {
                stack[n] = .{ .a = p.a + d.a, .b = p.b + d.b };
                n += 1;
            }
        }
        for (m, 0..) |row, r| {
            for (row[0..game.maze_cols], 0..) |ch, c| {
                const kind: u8 = switch (ch) {
                    '2' => 1,
                    '3' => 2,
                    else => continue,
                };
                if (t.floor[r + 1][c + 1]) {
                    t.dots[r + 1][c + 1] = kind;
                    t.dot_count += 1;
                }
            }
        }
        return t;
    }

    pub fn isFloor(t: *const Tiles, a: i32, b: i32) bool {
        if (a < 0 or b < 0 or a >= w or b >= h) return false;
        return t.floor[@intCast(b)][@intCast(a)];
    }
};

/// A maze cell is wall (outside the maze too), after the repair of the cup's shoulders.
fn wall(m: *const game.Maze, c: i32, r: i32) bool {
    if (c < 0 or r < 0 or c >= game.maze_cols or r >= game.maze_rows) return true;
    if (r == 12 and (c == 16 or c == 17 or c == 22 or c == 23)) return true;
    return m[@intCast(r)][@intCast(c)] == '1';
}

test "the tile grid of SAUNA's maze: corridors one tile wide, 100 dots, no dead ends" {
    const t = Tiles.build(&game.initial_maze);
    try std.testing.expectEqual(@as(u16, 100), t.dot_count);
    var corks: usize = 0;
    var junctions: usize = 0;
    var floor: usize = 0;
    for (0..h) |bi| {
        for (0..w) |ai| {
            const a: i32 = @intCast(ai);
            const b: i32 = @intCast(bi);
            if (t.dots[bi][ai] == 2) corks += 1;
            if (!t.isFloor(a, b)) continue;
            floor += 1;
            var exits: usize = 0;
            for ([_][2]i32{ .{ 1, 0 }, .{ -1, 0 }, .{ 0, 1 }, .{ 0, -1 } }) |d| {
                if (t.isFloor(a + d[0], b + d[1])) exits += 1;
            }
            // Never a dead end, and no 2 x 2 block of floor (a corridor is one tile wide).
            try std.testing.expect(exits >= 2);
            if (exits >= 3) junctions += 1;
            try std.testing.expect(!(t.isFloor(a + 1, b) and t.isFloor(a, b + 1) and t.isFloor(a + 1, b + 1)));
        }
    }
    try std.testing.expectEqual(@as(usize, 4), corks);
    try std.testing.expectEqual(@as(usize, 36), junctions);
    try std.testing.expectEqual(@as(usize, 323), floor);
    // The corners of the maze, the door's doormat, Pacman's start.
    try std.testing.expect(t.isFloor(2, 2) and t.isFloor(38, 26) and t.isFloor(20, 11) and t.isFloor(20, 20));
    // The house is not floor; neither is a closed box.
    try std.testing.expect(!t.isFloor(20, 15) and !t.isFloor(20, 12) and !t.isFloor(8, 11) and !t.isFloor(10, 3));
}
