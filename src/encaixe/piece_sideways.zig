//! Port unit `piece_sideways` (module) of ENCAIXE.EXE. the left and right move workers (switch kind/rotation over the board; BUGS.md E1).
//!
//! See docs/encaixe/DESIGN.md "How to port an ENCAIXE unit". Each function
//! carries `// @orig <1008:xxxx> <name>` with the ENCAIXE address.

const std = @import("std");
const Game = @import("core/game.zig").Game;
const object = @import("core/object.zig");
const Object = object.Object;
const PiecePart = object.PiecePart;
const TestGame = @import("core/game.zig").TestGame;

fn full(p: *PiecePart, c: i16, r: i16) bool {
    return p.cell(c, r).* == '1';
}

fn put(p: *PiecePart, c: i16, r: i16, v: u8) void {
    p.cell(c, r).* = v;
}

/// Move the piece one column right: validate the entered cells, then
/// erase the vacated ones and write the new ones. `obj` is `this`, which is
/// always `g_piece` (the original reads `column` through the global and
/// `row` through `this`). 0 = blocked, the board untouched; an unknown kind
/// or rotation returns 1 without touching anything.
// @orig 1008:c41a te_piece_move_right
pub fn moveRight(g: *Game, obj: *Object, kind: i16, rotation: i16) i16 {
    _ = g;
    const p = &obj.piece;
    const c = p.column;
    const r = p.row;
    switch (kind) {
        0 => switch (rotation) {
            0 => {
                if (10 < c + 3) return 0;
                if (full(p, c + 3, r) or full(p, c + 2, r + 1) or full(p, c + 2, r + 2) or full(p, c + 2, r + 3)) return 0;
                put(p, c, r, '0');
                p.column += 1;
                var i = r + 1;
                while (i < r + 4) : (i += 1) {
                    put(p, c + 1, i, '0');
                    put(p, c + 2, i, '1');
                }
                put(p, c + 3, r, '1');
            },
            1 => {
                if (10 < c + 4) return 0;
                if (full(p, c + 4, r) or full(p, c + 4, r + 1) or full(p, c + 4, r + 2)) return 0;
                put(p, c + 3, r, '0');
                put(p, c + 3, r + 2, '0');
                put(p, c, r + 1, '0');
                p.column += 1;
                put(p, c + 4, r, '1');
                put(p, c + 4, r + 2, '1');
                put(p, c + 4, r + 1, '1');
            },
            2 => {
                if (10 < c + 3) return 0;
                if (full(p, c + 3, r + 3) or full(p, c + 2, r) or full(p, c + 2, r + 1) or full(p, c + 2, r + 2)) return 0;
                put(p, c, r + 3, '0');
                p.column += 1;
                var i = r;
                while (i < r + 3) : (i += 1) {
                    put(p, c + 1, i, '0');
                    put(p, c + 2, i, '1');
                }
                put(p, c + 3, r + 3, '1');
            },
            3 => {
                if (10 < c + 4) return 0;
                if (full(p, c + 4, r + 1) or full(p, c + 1, r) or full(p, c + 1, r + 2)) return 0;
                put(p, c, r, '0');
                put(p, c, r + 1, '0');
                put(p, c, r + 2, '0');
                p.column += 1;
                put(p, c + 1, r, '1');
                put(p, c + 4, r + 1, '1');
                put(p, c + 1, r + 2, '1');
            },
            else => {},
        },
        1 => switch (rotation) {
            0 => {
                if (10 < c + 3) return 0;
                if (full(p, c + 3, r) or full(p, c + 2, r + 1)) return 0;
                put(p, c, r, '0');
                p.column += 1;
                put(p, c + 1, r + 1, '0');
                put(p, c + 2, r + 1, '1');
                put(p, c + 3, r, '1');
            },
            1 => {
                if (10 < c + 2) return 0;
                if (full(p, c + 2, r) or full(p, c + 2, r + 1) or full(p, c + 2, r + 2)) return 0;
                put(p, c + 1, r, '0');
                put(p, c + 1, r + 2, '0');
                p.column += 1;
                put(p, c, r + 1, '0');
                put(p, c + 2, r, '1');
                put(p, c + 2, r + 2, '1');
                put(p, c + 1, r + 1, '1');
                put(p, c + 2, r + 1, '1');
            },
            2 => {
                if (10 < c + 3) return 0;
                if (full(p, c + 3, r + 1) or full(p, c + 2, r)) return 0;
                put(p, c, r + 1, '0');
                p.column += 1;
                put(p, c + 1, r, '0');
                put(p, c + 2, r, '1');
                put(p, c + 3, r + 1, '1');
            },
            3 => {
                if (10 < c + 2) return 0;
                if (full(p, c + 2, r + 1) or full(p, c + 1, r) or full(p, c + 1, r + 2)) return 0;
                put(p, c, r, '0');
                put(p, c, r + 1, '0');
                put(p, c, r + 2, '0');
                p.column += 1;
                put(p, c + 1, r, '1');
                put(p, c + 2, r + 1, '1');
                put(p, c + 1, r + 2, '1');
            },
            else => {},
        },
        2 => switch (rotation) {
            0 => {
                if (10 < c + 2) return 0;
                if (full(p, c + 2, r) or full(p, c + 2, r + 1) or full(p, c + 2, r + 2)) return 0;
                put(p, c, r, '0');
                p.column += 1;
                var i = r + 1;
                while (i < r + 3) : (i += 1) {
                    put(p, c + 1, i, '0');
                    put(p, c + 2, i, '1');
                }
                put(p, c + 2, r, '1');
            },
            1 => {
                if (10 < c + 3) return 0;
                if (full(p, c + 3, r) or full(p, c + 3, r + 1)) return 0;
                put(p, c + 2, r, '0');
                put(p, c, r + 1, '0');
                p.column += 1;
                put(p, c + 3, r, '1');
                put(p, c + 3, r + 1, '1');
            },
            2 => {
                if (10 < c + 2) return 0;
                if (full(p, c + 1, r) or full(p, c + 1, r + 1) or full(p, c + 2, r + 2)) return 0;
                var i = r;
                while (i < r + 3) : (i += 1) {
                    put(p, c, i, '0');
                    put(p, c + 1, i, '1');
                }
                put(p, c + 2, r + 2, '1');
                p.column += 1;
            },
            3 => {
                if (10 < c + 3) return 0;
                if (full(p, c + 3, r) or full(p, c + 1, r + 1)) return 0;
                put(p, c, r, '0');
                put(p, c, r + 1, '0');
                p.column += 1;
                put(p, c + 3, r, '1');
                put(p, c + 1, r + 1, '1');
            },
            else => {},
        },
        3 => switch (rotation) {
            0 => {
                if (10 < c + 2) return 0;
                if (full(p, c + 2, r) or full(p, c + 1, r + 1) or full(p, c + 1, r + 2)) return 0;
                put(p, c, r, '0');
                var i = r + 1;
                while (i < r + 3) : (i += 1) {
                    put(p, c, i, '0');
                    put(p, c + 1, i, '1');
                }
                p.column += 1;
                put(p, c + 2, r, '1');
            },
            1 => {
                if (10 < c + 3) return 0;
                if (full(p, c + 3, r) or full(p, c + 3, r + 1)) return 0;
                put(p, c, r, '0');
                put(p, c + 2, r + 1, '0');
                p.column += 1;
                put(p, c + 3, r, '1');
                put(p, c + 3, r + 1, '1');
            },
            2 => {
                if (10 < c + 2) return 0;
                if (full(p, c + 2, r) or full(p, c + 2, r + 1) or full(p, c + 2, r + 2)) return 0;
                p.column += 1;
                var i = r;
                while (i < r + 2) : (i += 1) {
                    put(p, c + 1, i, '0');
                    put(p, c + 2, i, '1');
                }
                put(p, c, r + 2, '0');
                put(p, c + 2, r + 2, '1');
            },
            3 => {
                if (10 < c + 3) return 0;
                if (full(p, c + 3, r + 1) or full(p, c + 1, r)) return 0;
                put(p, c, r, '0');
                put(p, c, r + 1, '0');
                p.column += 1;
                put(p, c + 1, r, '1');
                put(p, c + 3, r + 1, '1');
            },
            else => {},
        },
        4 => switch (rotation) {
            1, 3 => {
                if (!(c + 4 < 11) or full(p, c + 4, r)) return 0;
                put(p, c, r, '0');
                p.column += 1;
                put(p, c + 4, r, '1');
                return 1;
            },
            0, 2 => {
                if (10 < c + 1) return 0;
                if (full(p, c + 1, r) or full(p, c + 1, r + 1) or full(p, c + 1, r + 2) or full(p, c + 1, r + 3)) return 0;
                var i = r;
                while (i < r + 4) : (i += 1) {
                    put(p, c, i, '0');
                    put(p, c + 1, i, '1');
                }
                p.column += 1;
            },
            else => {},
        },
        5 => {
            if (rotation < 0 or 3 < rotation) return 1;
            if (10 < c + 2) return 0;
            if (full(p, c + 2, r) or full(p, c + 2, r + 1)) return 0;
            put(p, c + 2, r, '1');
            put(p, c + 2, r + 1, '1');
            put(p, c, r, '0');
            put(p, c, r + 1, '0');
            p.column += 1;
        },
        else => {},
    }
    return 1;
}

/// Move the piece one column left (the mirror of `moveRight`). BUGS.md E1:
/// the O piece (kind 5) clears its right column and moves `column` but never
/// writes its new left column; `g.fixes.encaixe_o_piece_moves_left_whole`
/// writes it. 0 = blocked.
// @orig 1008:ce8c te_piece_move_left
pub fn moveLeft(g: *Game, obj: *Object, kind: i16, rotation: i16) i16 {
    const p = &obj.piece;
    const c = p.column;
    const r = p.row;
    switch (kind) {
        0 => switch (rotation) {
            0 => {
                if (c < 1) return 0;
                if (full(p, c - 1, r) or full(p, c, r + 1) or full(p, c, r + 2) or full(p, c, r + 3)) return 0;
                put(p, c + 2, r, '0');
                var i = r + 1;
                while (i < r + 4) : (i += 1) {
                    put(p, c, i, '1');
                    put(p, c + 1, i, '0');
                }
                p.column -= 1;
                put(p, c - 1, r, '1');
            },
            1 => {
                if (c < 1) return 0;
                if (full(p, c + 2, r) or full(p, c + 2, r + 2) or full(p, c - 1, r + 1)) return 0;
                var i = r;
                while (i < r + 3) : (i += 1) put(p, c + 3, i, '0');
                put(p, c + 2, r, '1');
                put(p, c + 2, r + 2, '1');
                put(p, c - 1, r + 1, '1');
                p.column -= 1;
            },
            2 => {
                if (c < 1) return 0;
                if (full(p, c - 1, r + 3) or full(p, c, r) or full(p, c, r + 1) or full(p, c, r + 2)) return 0;
                put(p, c + 2, r + 3, '0');
                var i = r;
                while (i < r + 3) : (i += 1) {
                    put(p, c, i, '1');
                    put(p, c + 1, i, '0');
                }
                p.column -= 1;
                put(p, c - 1, r + 3, '1');
            },
            3 => {
                if (c < 1) return 0;
                if (full(p, c - 1, r) or full(p, c - 1, r + 1) or full(p, c - 1, r + 2)) return 0;
                put(p, c, r, '0');
                put(p, c, r + 2, '0');
                put(p, c + 3, r + 1, '0');
                p.column -= 1;
                var i = r;
                while (i < r + 3) : (i += 1) put(p, c - 1, i, '1');
            },
            else => {},
        },
        1 => switch (rotation) {
            0 => {
                if (c < 1) return 0;
                if (full(p, c - 1, r) or full(p, c, r + 1)) return 0;
                put(p, c + 2, r, '0');
                put(p, c + 1, r + 1, '0');
                put(p, c, r + 1, '1');
                put(p, c - 1, r, '1');
                p.column -= 1;
            },
            1 => {
                if (c < 1) return 0;
                if (full(p, c, r) or full(p, c - 1, r + 1) or full(p, c, r + 2)) return 0;
                var i = r;
                while (i < r + 3) : (i += 1) put(p, c + 1, i, '0');
                put(p, c, r, '1');
                put(p, c, r + 2, '1');
                p.column -= 1;
                put(p, c - 1, r + 1, '1');
            },
            2 => {
                if (c < 1) return 0;
                if (full(p, c - 1, r + 1) or full(p, c, r)) return 0;
                put(p, c + 2, r + 1, '0');
                put(p, c + 1, r, '0');
                put(p, c, r, '1');
                put(p, c - 1, r + 1, '1');
                p.column -= 1;
            },
            3 => {
                if (c < 1) return 0;
                if (full(p, c - 1, r + 1) or full(p, c - 1, r) or full(p, c - 1, r + 2)) return 0;
                put(p, c, r, '0');
                put(p, c, r + 2, '0');
                put(p, c + 1, r + 1, '0');
                p.column -= 1;
                var i = r;
                while (i < r + 3) : (i += 1) put(p, c - 1, i, '1');
            },
            else => {},
        },
        2 => switch (rotation) {
            0 => {
                if (c < 1) return 0;
                if (full(p, c - 1, r) or full(p, c, r + 1) or full(p, c, r + 2)) return 0;
                put(p, c + 1, r, '0');
                var i = r + 1;
                while (i < r + 3) : (i += 1) {
                    put(p, c + 1, i, '0');
                    put(p, c, i, '1');
                }
                put(p, c - 1, r, '1');
                p.column -= 1;
            },
            1 => {
                if (c < 1) return 0;
                if (full(p, c + 1, r) or full(p, c - 1, r + 1)) return 0;
                put(p, c + 2, r, '0');
                put(p, c + 2, r + 1, '0');
                put(p, c + 1, r, '1');
                put(p, c - 1, r + 1, '1');
                p.column -= 1;
            },
            2 => {
                if (c < 1) return 0;
                if (full(p, c - 1, r) or full(p, c - 1, r + 1) or full(p, c - 1, r + 2)) return 0;
                var i = r;
                while (i < r + 3) : (i += 1) {
                    put(p, c, i, '0');
                    put(p, c - 1, i, '1');
                }
                put(p, c + 1, r + 2, '0');
                put(p, c, r + 2, '1');
                p.column -= 1;
            },
            3 => {
                if (c < 1) return 0;
                if (full(p, c - 1, r) or full(p, c - 1, r + 1)) return 0;
                put(p, c + 2, r, '0');
                put(p, c, r + 1, '0');
                p.column -= 1;
                put(p, c - 1, r, '1');
                put(p, c - 1, r + 1, '1');
            },
            else => {},
        },
        3 => switch (rotation) {
            0 => {
                if (c < 1) return 0;
                if (full(p, c - 1, r) or full(p, c - 1, r + 1) or full(p, c - 1, r + 2)) return 0;
                put(p, c + 1, r, '0');
                var i = r + 1;
                while (i < r + 3) : (i += 1) {
                    put(p, c, i, '0');
                    put(p, c - 1, i, '1');
                }
                p.column -= 1;
                put(p, c - 1, r, '1');
            },
            1 => {
                if (c < 1) return 0;
                if (full(p, c - 1, r) or full(p, c + 1, r + 1)) return 0;
                put(p, c + 2, r, '0');
                p.column -= 1;
                put(p, c + 2, r + 1, '0');
                put(p, c - 1, r, '1');
                put(p, c + 1, r + 1, '1');
            },
            2 => {
                if (c < 1) return 0;
                if (full(p, c, r) or full(p, c, r + 1) or full(p, c - 1, r + 2)) return 0;
                p.column -= 1;
                var i = r;
                while (i < r + 3) : (i += 1) {
                    put(p, c + 1, i, '0');
                    put(p, c, i, '1');
                }
                put(p, c - 1, r + 2, '1');
            },
            3 => {
                if (c < 1) return 0;
                if (full(p, c - 1, r + 1) or full(p, c - 1, r)) return 0;
                put(p, c, r, '0');
                put(p, c + 2, r + 1, '0');
                p.column -= 1;
                put(p, c - 1, r, '1');
                put(p, c - 1, r + 1, '1');
            },
            else => {},
        },
        4 => switch (rotation) {
            1, 3 => {
                if (c < 1 or full(p, c - 1, r)) return 0;
                put(p, c + 3, r, '0');
                p.column -= 1;
                put(p, c - 1, r, '1');
                return 1;
            },
            0, 2 => {
                if (c < 1) return 0;
                if (full(p, c - 1, r) or full(p, c - 1, r + 1) or full(p, c - 1, r + 2) or full(p, c - 1, r + 3)) return 0;
                var i = r;
                while (i < r + 4) : (i += 1) {
                    put(p, c, i, '0');
                    put(p, c - 1, i, '1');
                }
                p.column -= 1;
            },
            else => {},
        },
        5 => {
            if (rotation < 0 or 3 < rotation) return 1;
            if (c < 1) return 0;
            if (full(p, c - 1, r) or full(p, c - 1, r + 1)) return 0;
            put(p, c + 1, r, '0');
            put(p, c + 1, r + 1, '0');
            // E1: the original never writes the new left column here.
            if (g.fixes.encaixe_o_piece_moves_left_whole) {
                put(p, c - 1, r, '1');
                put(p, c - 1, r + 1, '1');
            }
            p.column -= 1;
        },
        else => {},
    }
    return 1;
}

// Expected values: the original workers run in tools/oracle (Unicorn,
// `--near`, ENCAIXE.EXE) on the same pseudo-random boards, over every kind
// 0..6 x rotation 0..4 (6 and 4 are outside the switches) x columns (right
// 0..10, left 0..7) x rows 0/4/10 x 6 boards (~25% full), blocked cases
// included. Each case's result, new `column` and whole board are folded
// into one FNV-1a hash.
fn sweepBoard(idx: u32) [154]u8 {
    var s: u32 = idx *% 2654435761 +% 1;
    var out: [154]u8 = undefined;
    for (&out) |*b| {
        s ^= s << 13;
        s ^= s >> 17;
        s ^= s << 5;
        b.* = if ((s >> 8) % 4 == 0) '1' else '0';
    }
    return out;
}

// @orig 1008:c41a te_piece_move_right oracle=emulated
// @orig 1008:ce8c te_piece_move_left oracle=emulated
test "the sideways workers match the original on every kind and rotation" {
    var t = try TestGame.init(std.testing.allocator);
    defer t.deinit();
    const g = t.game;
    var o: Object = .{ .kind = .piece };
    var hash = std.hash.Fnv1a_64.init();
    var idx: u32 = 0;
    for ([_]bool{ false, true }) |left| {
        const cols: i16 = if (left) 8 else 11;
        var kind: i16 = 0;
        while (kind < 7) : (kind += 1) {
            var rot: i16 = 0;
            while (rot < 5) : (rot += 1) {
                var col: i16 = 0;
                while (col < cols) : (col += 1) {
                    for ([_]i16{ 0, 4, 10 }) |row| {
                        for (0..6) |_| {
                            const b = sweepBoard(idx);
                            idx += 1;
                            @memcpy(std.mem.asBytes(&o.piece.board), &b);
                            o.piece.column = col;
                            o.piece.row = row;
                            const ret = if (left) moveLeft(g, &o, kind, rot) else moveRight(g, &o, kind, rot);
                            hash.update(&.{ @as(u8, @intCast(ret)), @as(u8, @truncate(@as(u16, @bitCast(o.piece.column)))) });
                            hash.update(std.mem.asBytes(&o.piece.board));
                        }
                    }
                }
            }
        }
    }
    try std.testing.expectEqual(@as(u32, 11970), idx);
    try std.testing.expectEqual(@as(u64, 0x30d426f17611c955), hash.final());
}

// @orig 1008:ce8c te_piece_move_left oracle=emulated
test "the O piece moving left loses its left column (E1), the flag keeps it" {
    var t = try TestGame.init(std.testing.allocator);
    defer t.deinit();
    const g = t.game;
    var o: Object = .{ .kind = .piece };
    for ([_]bool{ false, true }) |fix| {
        g.fixes.encaixe_o_piece_moves_left_whole = fix;
        o.piece.board = @splat(@splat('0'));
        o.piece.column = 4;
        o.piece.row = 5;
        for ([_][2]i16{ .{ 4, 5 }, .{ 4, 6 }, .{ 5, 5 }, .{ 5, 6 } }) |c| o.piece.cell(c[0], c[1]).* = '1';
        try std.testing.expectEqual(@as(i16, 1), moveLeft(g, &o, 5, 0));
        try std.testing.expectEqual(@as(i16, 3), o.piece.column);
        try std.testing.expectEqual(@as(u8, '1'), o.piece.cell(4, 5).*);
        try std.testing.expectEqual(@as(u8, '1'), o.piece.cell(4, 6).*);
        try std.testing.expectEqual(@as(u8, '0'), o.piece.cell(5, 5).*);
        try std.testing.expectEqual(@as(u8, if (fix) '1' else '0'), o.piece.cell(3, 5).*);
        try std.testing.expectEqual(@as(u8, if (fix) '1' else '0'), o.piece.cell(3, 6).*);
    }
}
