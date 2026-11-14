//! Port unit `piece_vertical` (module) of ENCAIXE.EXE. the down move and rotation workers (BUGS.md E2).
//!
//! See docs/encaixe/DESIGN.md "How to port an ENCAIXE unit". Each function
//! carries `// @orig <1008:xxxx> <name>` with the ENCAIXE address.

const std = @import("std");
const Game = @import("core/game.zig").Game;
const object = @import("core/object.zig");
const Object = object.Object;
const PiecePart = object.PiecePart;

// The board is `board[col][row]`, cells '0' (free) and '1' (filled); the
// shapes are in docs/encaixe/GAME.md. Each worker tests the cells the move
// enters, then rewrites the board cell by cell in the original's order. All
// addressing goes through `PiecePart.cell`, the original's flat
// `col * 14 + row` byte.

/// One row down: the new bottom row must be <= 13 and the entered cells free;
/// then the vacated top cells become '0', the entered ones '1' and `row`
/// grows. Blocked: the board is untouched. Either way the result is stored
/// in `Piece.canFall`. Returns 1 (moved, or an unknown rotation) or 0.
pub fn moveDown(obj: *Object, kind: i16, rotation: i16) i16 {
    return moveDownPart(&obj.piece, kind, rotation);
}

/// One clockwise rotation (`rotation` is the current one, the caller stores
/// the new one): the shape's cells for (rotation + 1) % 4 at the same top-left.
/// Returns 1 or 0 (blocked; board untouched).
pub fn rotate(g: *const Game, obj: *Object, kind: i16, rotation: i16) i16 {
    return rotatePart(&obj.piece, kind, rotation, g.fixes.encaixe_rotation_stays_on_board);
}

fn set(p: *PiecePart, col: i16, row: i16, v: u8) void {
    p.cell(col, row).* = v;
}

fn full(p: *PiecePart, col: i16, row: i16) bool {
    return p.cell(col, row).* == '1';
}

// @orig 1008:d960 te_piece_move_down
fn moveDownPart(p: *PiecePart, kind: i16, rotation: i16) i16 {
    var result: u16 = 1;
    const col = p.column;
    moved: {
        switch (kind) {
            0 => switch (rotation) {
                0 => {
                    if (!(p.row + 4 < 14)) {
                        result = 0;
                        break :moved;
                    }
                    const r = p.row;
                    if (full(p, col, r + 1) or full(p, col + 2, r + 1) or full(p, col + 1, r + 4)) {
                        result = 0;
                        break :moved;
                    }
                    var i: i16 = 0;
                    while (i < 3) : (i += 1) set(p, col + i, p.row, '0');
                    set(p, col, p.row + 1, '1');
                    set(p, col + 2, p.row + 1, '1');
                    set(p, col + 1, p.row + 4, '1');
                    p.row += 1;
                },
                1 => {
                    if (!(p.row + 3 < 14)) {
                        result = 0;
                        break :moved;
                    }
                    const r = p.row;
                    if (full(p, col, r + 2) or full(p, col + 1, r + 2) or full(p, col + 2, r + 2) or full(p, col + 3, r + 3)) {
                        result = 0;
                        break :moved;
                    }
                    var i: i16 = 0;
                    while (i < 3) : (i += 1) {
                        set(p, col + i, p.row + 1, '0');
                        set(p, col + i, p.row + 2, '1');
                    }
                    set(p, col + 3, p.row, '0');
                    set(p, col + 3, p.row + 3, '1');
                    p.row += 1;
                },
                2 => {
                    if (!(p.row + 4 < 14)) {
                        result = 0;
                        break :moved;
                    }
                    const r = p.row;
                    if (full(p, col, r + 4) or full(p, col + 1, r + 4) or full(p, col + 2, r + 4)) {
                        result = 0;
                        break :moved;
                    }
                    set(p, col + 1, r, '0');
                    set(p, col, p.row + 3, '0');
                    set(p, col + 2, p.row + 3, '0');
                    var i: i16 = 0;
                    while (i < 3) : (i += 1) set(p, col + i, p.row + 4, '1');
                    p.row += 1;
                },
                3 => {
                    if (!(p.row + 3 < 14)) {
                        result = 0;
                        break :moved;
                    }
                    const r = p.row;
                    if (full(p, col, r + 3) or full(p, col + 1, r + 2) or full(p, col + 2, r + 2) or full(p, col + 3, r + 2)) {
                        result = 0;
                        break :moved;
                    }
                    var i: i16 = 1;
                    while (i < 4) : (i += 1) {
                        set(p, col + i, p.row + 1, '0');
                        set(p, col + i, p.row + 2, '1');
                    }
                    set(p, col, p.row, '0');
                    set(p, col, p.row + 3, '1');
                    p.row += 1;
                },
                else => {},
            },
            1 => switch (rotation) {
                0 => {
                    if (!(p.row + 2 < 14)) {
                        result = 0;
                        break :moved;
                    }
                    const r = p.row;
                    if (full(p, col, r + 1) or full(p, col + 2, r + 1) or full(p, col + 1, r + 2)) {
                        result = 0;
                        break :moved;
                    }
                    var i: i16 = 0;
                    while (i < 3) : (i += 1) set(p, col + i, p.row, '0');
                    set(p, col, p.row + 1, '1');
                    set(p, col + 2, p.row + 1, '1');
                    set(p, col + 1, p.row + 2, '1');
                    p.row += 1;
                },
                1 => {
                    if (!(p.row + 3 < 14)) {
                        result = 0;
                        break :moved;
                    }
                    const r = p.row;
                    if (full(p, col, r + 2) or full(p, col + 1, r + 3)) {
                        result = 0;
                        break :moved;
                    }
                    set(p, col, r + 1, '0');
                    set(p, col + 1, p.row, '0');
                    set(p, col, p.row + 2, '1');
                    set(p, col + 1, p.row + 3, '1');
                    p.row += 1;
                },
                2 => {
                    if (!(p.row + 2 < 14)) {
                        result = 0;
                        break :moved;
                    }
                    const r = p.row;
                    if (full(p, col, r + 2) or full(p, col + 1, r + 2) or full(p, col + 2, r + 2)) {
                        result = 0;
                        break :moved;
                    }
                    set(p, col + 1, r, '0');
                    set(p, col, p.row + 1, '0');
                    set(p, col + 2, p.row + 1, '0');
                    var i: i16 = 0;
                    while (i < 3) : (i += 1) set(p, col + i, p.row + 2, '1');
                    p.row += 1;
                },
                3 => {
                    if (!(p.row + 3 < 14)) {
                        result = 0;
                        break :moved;
                    }
                    const r = p.row;
                    if (full(p, col, r + 3) or full(p, col + 1, r + 2)) {
                        result = 0;
                        break :moved;
                    }
                    set(p, col, r, '0');
                    set(p, col + 1, p.row + 1, '0');
                    set(p, col + 1, p.row + 2, '1');
                    set(p, col, p.row + 3, '1');
                    p.row += 1;
                },
                else => {},
            },
            2 => switch (rotation) {
                0 => {
                    if (!(p.row + 3 < 14)) {
                        result = 0;
                        break :moved;
                    }
                    const r = p.row;
                    if (full(p, col, r + 1) or full(p, col + 1, r + 3)) {
                        result = 0;
                        break :moved;
                    }
                    set(p, col, r, '0');
                    set(p, col + 1, p.row, '0');
                    set(p, col, p.row + 1, '1');
                    set(p, col + 1, p.row + 3, '1');
                    p.row += 1;
                },
                1 => {
                    if (!(p.row + 2 < 14)) {
                        result = 0;
                        break :moved;
                    }
                    const r = p.row;
                    if (full(p, col, r + 2) or full(p, col + 1, r + 2) or full(p, col + 2, r + 2)) {
                        result = 0;
                        break :moved;
                    }
                    set(p, col + 2, r, '0');
                    set(p, col + 1, p.row + 1, '0');
                    set(p, col, p.row + 1, '0');
                    var i: i16 = 0;
                    while (i < 3) : (i += 1) set(p, col + i, p.row + 2, '1');
                    p.row += 1;
                },
                2 => {
                    if (!(p.row + 3 < 14)) {
                        result = 0;
                        break :moved;
                    }
                    const r = p.row;
                    if (full(p, col, r + 3) or full(p, col + 1, r + 3)) {
                        result = 0;
                        break :moved;
                    }
                    set(p, col, r, '0');
                    set(p, col + 1, p.row + 2, '0');
                    p.row += 1;
                    set(p, col + 1, p.row + 2, '1');
                    set(p, col, p.row + 2, '1');
                },
                3 => {
                    if (!(p.row + 2 < 14)) {
                        result = 0;
                        break :moved;
                    }
                    const r = p.row;
                    if (full(p, col, r + 2) or full(p, col + 1, r + 1) or full(p, col + 2, r + 1)) {
                        result = 0;
                        break :moved;
                    }
                    var i: i16 = 0;
                    while (i < 3) : (i += 1) {
                        set(p, col + i, p.row, '0');
                        set(p, col + i, p.row + 1, '1');
                    }
                    set(p, col, p.row + 2, '1');
                    p.row += 1;
                },
                else => {},
            },
            3 => switch (rotation) {
                0 => {
                    if (!(p.row + 3 < 14)) {
                        result = 0;
                        break :moved;
                    }
                    const r = p.row;
                    if (full(p, col + 1, r + 1) or full(p, col, r + 3)) {
                        result = 0;
                        break :moved;
                    }
                    set(p, col, r, '0');
                    set(p, col + 1, p.row, '0');
                    set(p, col + 1, p.row + 1, '1');
                    set(p, col, p.row + 3, '1');
                    p.row += 1;
                },
                1 => {
                    if (!(p.row + 2 < 14)) {
                        result = 0;
                        break :moved;
                    }
                    const r = p.row;
                    if (full(p, col, r + 1) or full(p, col + 1, r + 1) or full(p, col + 2, r + 2)) {
                        result = 0;
                        break :moved;
                    }
                    var i: i16 = 0;
                    while (i < 3) : (i += 1) {
                        set(p, col + i, p.row, '0');
                        set(p, col + i, p.row + 1, '1');
                    }
                    set(p, col + 2, p.row + 2, '1');
                    p.row += 1;
                },
                2 => {
                    if (!(p.row + 3 < 14)) {
                        result = 0;
                        break :moved;
                    }
                    const r = p.row;
                    if (full(p, col, r + 3) or full(p, col + 1, r + 3)) {
                        result = 0;
                        break :moved;
                    }
                    set(p, col + 1, r, '0');
                    set(p, col, p.row + 2, '0');
                    p.row += 1;
                    set(p, col + 1, p.row + 2, '1');
                    set(p, col, p.row + 2, '1');
                },
                3 => {
                    if (!(p.row + 2 < 14)) {
                        result = 0;
                        break :moved;
                    }
                    const r = p.row;
                    if (full(p, col, r + 2) or full(p, col + 1, r + 2) or full(p, col + 2, r + 2)) {
                        result = 0;
                        break :moved;
                    }
                    set(p, col, r, '0');
                    var i: i16 = 0;
                    while (i < 3) : (i += 1) {
                        set(p, col + i, p.row + 1, '0');
                        set(p, col + i, p.row + 2, '1');
                    }
                    set(p, col, p.row + 1, '1');
                    p.row += 1;
                },
                else => {},
            },
            4 => switch (rotation) {
                0, 2 => {
                    if (!(p.row + 4 < 14)) {
                        result = 0;
                        break :moved;
                    }
                    const r = p.row;
                    if (full(p, col, r + 4)) {
                        result = 0;
                        break :moved;
                    }
                    p.row += 1;
                    set(p, col, r, '0');
                    set(p, col, p.row + 3, '1');
                },
                1, 3 => {
                    if (!(p.row + 1 < 14)) {
                        result = 0;
                        break :moved;
                    }
                    const r = p.row;
                    if (full(p, col, r + 1) or full(p, col + 1, r + 1) or full(p, col + 2, r + 1) or full(p, col + 3, r + 1)) {
                        result = 0;
                        break :moved;
                    }
                    var i: i16 = 0;
                    while (i < 4) : (i += 1) {
                        set(p, col + i, p.row, '0');
                        set(p, col + i, p.row + 1, '1');
                    }
                    p.row += 1;
                },
                else => {},
            },
            5 => {
                if (rotation < 0 or rotation > 3) break :moved;
                if (!(p.row + 2 < 14)) {
                    result = 0;
                    break :moved;
                }
                const r = p.row;
                if (full(p, col, r + 2) or full(p, col + 1, r + 2)) {
                    result = 0;
                    break :moved;
                }
                set(p, col, r + 2, '1');
                set(p, col + 1, p.row + 2, '1');
                set(p, col, p.row, '0');
                set(p, col + 1, p.row, '0');
                p.row += 1;
            },
            else => {},
        }
    }
    p.canFall = result;
    return @intCast(result);
}

// @orig 1008:e392 te_piece_rotate
fn rotatePart(p: *PiecePart, kind: i16, rotation: i16, stays_on_board: bool) i16 {
    const col = p.column;
    // E2: the original lets the new shape's bottom row reach row index 14,
    // one past the column (`14 < row + h` fails); the fix stops at 13.
    const lastRow: i16 = if (stays_on_board) 13 else 14;
    switch (kind) {
        0 => switch (rotation) {
            0 => {
                if (10 < col + 3) return 0;
                const r = p.row;
                if (full(p, col + 3, r) or full(p, col + 3, r + 1) or full(p, col + 3, r + 2) or
                    full(p, col + 2, r + 1) or full(p, col, r + 1)) return 0;
                var i: i16 = 0;
                while (i < 3) : (i += 1) set(p, col + i, p.row, '0');
                var k = p.row + 2;
                while (k < p.row + 4) : (k += 1) set(p, col + 1, k, '0');
                i = 0;
                while (i < 4) : (i += 1) set(p, col + i, p.row + 1, '1');
                set(p, col + 3, p.row, '1');
                set(p, col + 3, p.row + 2, '1');
            },
            1 => {
                if (lastRow < p.row + 3) return 0;
                const r = p.row;
                if (full(p, col + 1, r) or full(p, col + 1, r + 2) or full(p, col + 1, r + 3) or
                    full(p, col, r + 3) or full(p, col + 2, r + 3)) return 0;
                var k = p.row;
                while (k < p.row + 3) : (k += 1) {
                    set(p, col + 1, k, '1');
                    set(p, col + 3, k, '0');
                }
                set(p, col, p.row + 1, '0');
                set(p, col + 2, p.row + 1, '0');
                var i: i16 = 0;
                while (i < 3) : (i += 1) set(p, col + i, p.row + 3, '1');
            },
            2 => {
                if (10 < col + 3) return 0;
                const r = p.row;
                if (full(p, col + 3, r + 1) or full(p, col + 2, r + 1) or full(p, col, r) or
                    full(p, col, r + 1) or full(p, col, r + 2)) return 0;
                var i: i16 = 0;
                while (i < 3) : (i += 1) set(p, col + i, p.row + 3, '0');
                set(p, col + 1, p.row, '0');
                set(p, col + 1, p.row + 2, '0');
                var k = p.row;
                while (k < p.row + 3) : (k += 1) set(p, col, k, '1');
                set(p, col + 2, p.row + 1, '1');
                set(p, col + 3, p.row + 1, '1');
            },
            3 => {
                if (lastRow < p.row + 3) return 0;
                const r = p.row;
                if (full(p, col + 1, r) or full(p, col + 2, r) or full(p, col + 1, r + 2) or
                    full(p, col + 1, r + 3)) return 0;
                set(p, col, r + 1, '0');
                set(p, col, p.row + 2, '0');
                set(p, col + 2, p.row + 1, '0');
                set(p, col + 3, p.row + 1, '0');
                set(p, col + 1, p.row, '1');
                set(p, col + 2, p.row, '1');
                set(p, col + 1, p.row + 2, '1');
                set(p, col + 1, p.row + 3, '1');
            },
            else => {},
        },
        1 => switch (rotation) {
            0 => {
                if (lastRow < p.row + 2) return 0;
                const r = p.row;
                if (full(p, col, r + 1) or full(p, col + 1, r + 2)) return 0;
                set(p, col, r, '0');
                set(p, col + 2, p.row, '0');
                set(p, col, p.row + 1, '1');
                set(p, col + 1, p.row + 2, '1');
            },
            1 => {
                if (10 < col + 2) return 0;
                if (full(p, col + 2, p.row + 1)) return 0;
                set(p, col + 1, p.row + 2, '0');
                set(p, col + 2, p.row + 1, '1');
            },
            2 => {
                if (lastRow < p.row + 2) return 0;
                const r = p.row;
                if (full(p, col, r) or full(p, col, r + 2)) return 0;
                set(p, col + 1, r, '0');
                set(p, col + 2, p.row + 1, '0');
                set(p, col, p.row, '1');
                set(p, col, p.row + 2, '1');
            },
            3 => {
                if (10 < col + 2) return 0;
                const r = p.row;
                if (full(p, col + 2, r) or full(p, col + 1, r)) return 0;
                set(p, col, r + 1, '0');
                set(p, col, p.row + 2, '0');
                set(p, col + 1, p.row, '1');
                set(p, col + 2, p.row, '1');
            },
            else => {},
        },
        2 => switch (rotation) {
            0 => {
                if (10 < col + 2) return 0;
                const r = p.row;
                if (full(p, col + 2, r) or full(p, col, r + 1) or full(p, col + 2, r + 1)) return 0;
                set(p, col, r, '0');
                set(p, col + 1, p.row, '0');
                set(p, col + 1, p.row + 2, '0');
                var k = p.row;
                while (k < p.row + 2) : (k += 1) set(p, col + 2, k, '1');
                set(p, col, p.row + 1, '1');
            },
            1 => {
                if (lastRow < p.row + 2) return 0;
                const r = p.row;
                if (full(p, col, r) or full(p, col + 1, r + 2) or full(p, col, r + 2)) return 0;
                set(p, col + 2, r, '0');
                set(p, col + 2, p.row + 1, '0');
                set(p, col + 1, p.row + 1, '0');
                set(p, col, p.row, '1');
                set(p, col, p.row + 2, '1');
                set(p, col + 1, p.row + 2, '1');
            },
            2 => {
                if (10 < col + 2) return 0;
                if (full(p, col + 1, p.row) or full(p, col + 2, p.row)) return 0;
                var i: i16 = 0;
                while (i < 2) : (i += 1) {
                    set(p, col + i, p.row + 2, '0');
                    set(p, col + 1 + i, p.row, '1');
                }
            },
            3 => {
                if (lastRow < p.row + 2) return 0;
                const r = p.row;
                if (full(p, col + 1, r + 2) or full(p, col + 1, r + 1)) return 0;
                set(p, col + 2, r, '0');
                set(p, col, p.row + 1, '0');
                set(p, col + 1, p.row + 1, '1');
                set(p, col + 1, p.row + 2, '1');
            },
            else => {},
        },
        3 => switch (rotation) {
            0 => {
                if (10 < col + 2) return 0;
                if (full(p, col + 2, p.row) or full(p, col + 2, p.row + 1)) return 0;
                var i: i16 = 0;
                while (i < 2) : (i += 1) {
                    set(p, col, p.row + 1 + i, '0');
                    set(p, col + 2, p.row + i, '1');
                }
            },
            1 => {
                if (lastRow < p.row + 2) return 0;
                const r = p.row;
                if (full(p, col, r + 2) or full(p, col + 1, r + 1) or full(p, col + 1, r + 2)) return 0;
                set(p, col, r, '0');
                var i: i16 = 0;
                while (i < 2) : (i += 1) {
                    set(p, col + 2, p.row + i, '0');
                    set(p, col + 1, p.row + 1 + i, '1');
                }
                set(p, col, p.row + 2, '1');
            },
            2 => {
                if (10 < col + 2) return 0;
                const r = p.row;
                if (full(p, col, r) or full(p, col + 2, r + 1) or full(p, col, r + 1)) return 0;
                set(p, col + 1, r, '0');
                var i: i16 = 0;
                while (i < 2) : (i += 1) set(p, col + i, p.row + 2, '0');
                var k = p.row;
                while (k < p.row + 2) : (k += 1) set(p, col, k, '1');
                set(p, col + 2, p.row + 1, '1');
            },
            3 => {
                if (lastRow < p.row + 2) return 0;
                const r = p.row;
                if (full(p, col, r + 2) or full(p, col + 1, r)) return 0;
                set(p, col + 1, r + 1, '0');
                set(p, col + 2, p.row + 1, '0');
                set(p, col + 1, p.row, '1');
                set(p, col, p.row + 2, '1');
            },
            else => {},
        },
        4 => switch (rotation) {
            0, 2 => {
                if (!(col + 3 < 11)) return 0;
                const r = p.row;
                if (full(p, col + 1, r) or full(p, col + 2, r) or full(p, col + 3, r)) return 0;
                var i: i16 = 0;
                while (i < 3) : (i += 1) {
                    set(p, col, p.row + 1 + i, '0');
                    set(p, col + 1 + i, p.row, '1');
                }
            },
            1, 3 => {
                if (lastRow < p.row + 3) return 0;
                const r = p.row;
                if (full(p, col, r + 1) or full(p, col, r + 2) or full(p, col, r + 3)) return 0;
                var i: i16 = 0;
                while (i < 3) : (i += 1) {
                    set(p, col, p.row + 1 + i, '1');
                    set(p, col + 1 + i, p.row, '0');
                }
            },
            else => {},
        },
        5 => if (rotation >= 0 and rotation < 4) {
            if (10 < col + 2) return 0;
            if (p.row + 2 < 14) return 1;
            return 0;
        },
        else => {},
    }
    return 1;
}

const shapes = [6][4][]const [2]i8{
    .{ &.{ .{ 0, 0 }, .{ 1, 0 }, .{ 2, 0 }, .{ 1, 1 }, .{ 1, 2 }, .{ 1, 3 } }, &.{ .{ 3, 0 }, .{ 0, 1 }, .{ 1, 1 }, .{ 2, 1 }, .{ 3, 1 }, .{ 3, 2 } }, &.{ .{ 1, 0 }, .{ 1, 1 }, .{ 1, 2 }, .{ 0, 3 }, .{ 1, 3 }, .{ 2, 3 } }, &.{ .{ 0, 0 }, .{ 0, 1 }, .{ 1, 1 }, .{ 2, 1 }, .{ 3, 1 }, .{ 0, 2 } } },
    .{ &.{ .{ 0, 0 }, .{ 1, 0 }, .{ 2, 0 }, .{ 1, 1 } }, &.{ .{ 1, 0 }, .{ 0, 1 }, .{ 1, 1 }, .{ 1, 2 } }, &.{ .{ 1, 0 }, .{ 0, 1 }, .{ 1, 1 }, .{ 2, 1 } }, &.{ .{ 0, 0 }, .{ 0, 1 }, .{ 1, 1 }, .{ 0, 2 } } },
    .{ &.{ .{ 0, 0 }, .{ 1, 0 }, .{ 1, 1 }, .{ 1, 2 } }, &.{ .{ 2, 0 }, .{ 0, 1 }, .{ 1, 1 }, .{ 2, 1 } }, &.{ .{ 0, 0 }, .{ 0, 1 }, .{ 0, 2 }, .{ 1, 2 } }, &.{ .{ 0, 0 }, .{ 1, 0 }, .{ 2, 0 }, .{ 0, 1 } } },
    .{ &.{ .{ 0, 0 }, .{ 1, 0 }, .{ 0, 1 }, .{ 0, 2 } }, &.{ .{ 0, 0 }, .{ 1, 0 }, .{ 2, 0 }, .{ 2, 1 } }, &.{ .{ 1, 0 }, .{ 1, 1 }, .{ 0, 2 }, .{ 1, 2 } }, &.{ .{ 0, 0 }, .{ 0, 1 }, .{ 1, 1 }, .{ 2, 1 } } },
    .{ &.{ .{ 0, 0 }, .{ 0, 1 }, .{ 0, 2 }, .{ 0, 3 } }, &.{ .{ 0, 0 }, .{ 1, 0 }, .{ 2, 0 }, .{ 3, 0 } }, &.{ .{ 0, 0 }, .{ 0, 1 }, .{ 0, 2 }, .{ 0, 3 } }, &.{ .{ 0, 0 }, .{ 1, 0 }, .{ 2, 0 }, .{ 3, 0 } } },
    .{ &.{ .{ 0, 0 }, .{ 1, 0 }, .{ 0, 1 }, .{ 1, 1 } }, &.{ .{ 0, 0 }, .{ 1, 0 }, .{ 0, 1 }, .{ 1, 1 } }, &.{ .{ 0, 0 }, .{ 1, 0 }, .{ 0, 1 }, .{ 1, 1 } }, &.{ .{ 0, 0 }, .{ 1, 0 }, .{ 0, 1 }, .{ 1, 1 } } },
};

const down_hashes = [6]u32{ 0x4dabec29, 0x79bb3a70, 0x8fa884ed, 0xe804cd1f, 0x1b5fd3c3, 0xa5c099c4 };
const rot_hashes = [6]u32{ 0x7e3bf3e9, 0x8504bee3, 0x1bea345b, 0x6ea7b298, 0x67e028f3, 0xfea9272e };

// Expected values: the original functions run in tools/oracle (Unicorn,
// `--near`, ENCAIXE.EXE 1008:d960 / 1008:e392) on the same cases: for every
// kind, rotation and position where the shape fits the board, an empty board
// plus the piece, one blocker at each of 20 cells around it, and 4 seeded
// random boards. One FNV-1a hash per kind over (result, canFall, board, row)
// after every call.

const variants = 25;

fn fnv(h: u32, bs: []const u8) u32 {
    var x = h;
    for (bs) |b| x = (x ^ b) *% 16777619;
    return x;
}

fn caseBoard(p: *PiecePart, kind: usize, rot: usize, col: i16, row: i16, v: usize, seed: u32) void {
    p.* = .{};
    var flat: *[154]u8 = @ptrCast(&p.board);
    var inShape: [154]bool = @splat(false);
    for (shapes[kind][rot]) |c| {
        const i: usize = @intCast((col + c[0]) * 14 + row + c[1]);
        inShape[i] = true;
        flat[i] = '1';
    }
    if (v >= 1 and v <= 20) {
        const dc: i16 = @intCast((v - 1) % 4);
        const dr: i16 = @intCast((v - 1) / 4);
        if (col + dc <= 10 and row + dr <= 13) {
            const i: usize = @intCast((col + dc) * 14 + row + dr);
            if (!inShape[i]) flat[i] = '1';
        }
    } else if (v > 20) {
        var x = seed;
        for (0..154) |i| {
            x = x *% 1103515245 +% 12345;
            if (!inShape[i] and ((x >> 16) & 0x7fff) % 12 == 0) flat[i] = '1';
        }
    }
    p.column = col;
    p.row = row;
}

fn sweep(comptime down: bool, kind: usize) u32 {
    var h: u32 = 2166136261;
    var seed: u32 = 1;
    for (0..4) |rot| {
        var w: i16 = 0;
        var ht: i16 = 0;
        for (shapes[kind][rot]) |c| {
            w = @max(w, c[0] + 1);
            ht = @max(ht, c[1] + 1);
        }
        var col: i16 = 0;
        while (col <= 11 - w) : (col += 1) {
            var row: i16 = 0;
            while (row <= 14 - ht) : (row += 1) {
                for (0..variants) |v| {
                    var p: PiecePart = .{};
                    caseBoard(&p, kind, rot, col, row, v, seed);
                    seed += 1;
                    const k: i16 = @intCast(kind);
                    const r: i16 = @intCast(rot);
                    const ret = if (down) moveDownPart(&p, k, r) else rotatePart(&p, k, r, false);
                    h = fnv(h, &.{@as(u8, @intCast(ret))});
                    h = fnv(h, std.mem.asBytes(&p.canFall));
                    h = fnv(h, std.mem.asBytes(&p.board));
                    h = fnv(h, std.mem.asBytes(&p.row));
                }
            }
        }
    }
    return h;
}

// @orig 1008:d960 te_piece_move_down oracle=emulated
test "moveDown matches the original on every kind and rotation" {
    for (0..6) |kind| try std.testing.expectEqual(down_hashes[kind], sweep(true, kind));
}

// @orig 1008:e392 te_piece_rotate oracle=emulated
test "rotate matches the original on every kind and rotation" {
    for (0..6) |kind| try std.testing.expectEqual(rot_hashes[kind], sweep(false, kind));
}

// E2 (BUGS.md): the I at row 11, columns 7-10 (kind 0 rotation 1) rotates to
// rotation 2 and writes its bottom row at index 14, which is row 0 of the
// next column (emulated: board[8..10][0]).
test "rotate near the floor writes one cell past the column (E2) unless fixed" {
    var q: PiecePart = .{};
    caseBoard(&q, 0, 1, 7, 11, 0, 0);
    var f = q;
    try std.testing.expectEqual(@as(i16, 1), rotatePart(&q, 0, 1, false));
    for (8..11) |c| try std.testing.expectEqual(@as(u8, '1'), q.board[c][0]);
    try std.testing.expectEqual(@as(u8, '0'), q.board[7][0]);
    try std.testing.expectEqual(@as(i16, 0), rotatePart(&f, 0, 1, true));
    for (0..11) |c| try std.testing.expectEqual(@as(u8, '0'), f.board[c][0]);
}
