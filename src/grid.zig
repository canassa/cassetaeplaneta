//! Port unit `grid` (module). occupancy grid (16 px cells, 65x81) and the grid backdrop queries.
//!
//! The cell arrays (`g_occupancyCount`, `g_occupancyObject`) live in `world.Grid`
//! and are addressed flat (`row * 81 + col`, 16-bit wrapping like the original),
//! so a column past 81 spills into the next row exactly as in the DGROUP array.
//! An index outside the 65x81 cells would be memory corruption in the original:
//! here reads see a free cell and writes are dropped.
//!
//! Naming: `occupancy_grid_*` functions take `*Grid` (`grid.occupy`); the
//! `grid_backdrop_*` virtual slots take the backdrop (`grid.backdropOccupy`).

const Game = @import("core/game.zig").Game;
const object = @import("core/object.zig");
const Object = object.Object;
const world = @import("core/world.zig");
const Backdrop = world.Backdrop;
const Grid = world.Grid;
const RectQuery = world.RectQuery;
const ini = @import("ini.zig");
const frames = @import("frames.zig");
const backdrop = @import("backdrop.zig");

/// Latin-1, as in the original's code segment (1010:9302, 1010:92d0, 1010:9310).
const msg_caption = "Erro FATAL !";
const msg_rows = "Estouro do n\xfamero de linhas da matriz de ocupa\xe7\xe3o";
const msg_cols = "Estouro do n\xfamero de colunas da matriz de ocupa\xe7\xe3o";

const cell_total = world.grid_rows * world.grid_cols;

fn flatCount(grid: *Grid) *[cell_total]i8 {
    return @ptrCast(&grid.count);
}

fn flatObject(grid: *Grid) *[cell_total]?*Object {
    return @ptrCast(&grid.object);
}

fn cellCount(grid: *Grid, idx: i32) i8 {
    if (idx < 0 or idx >= cell_total) return 0;
    return flatCount(grid)[@intCast(idx)];
}

fn cellObject(grid: *Grid, idx: i32) ?*Object {
    if (idx < 0 or idx >= cell_total) return null;
    return flatObject(grid)[@intCast(idx)];
}

fn storeCell(grid: *Grid, idx: i32, obj: ?*Object, count: ?i8) void {
    if (idx < 0 or idx >= cell_total) return;
    const i: usize = @intCast(idx);
    flatObject(grid)[i] = obj;
    if (count) |c| flatCount(grid)[i] = c;
}

/// 16-bit `row * 81 + col` (`IMUL BX,reg,0x51; ADD`), as an unsigned index.
fn index16(row: i16, col: i16) i32 {
    const v: i16 = row *% 81 +% col;
    return @as(u16, @bitCast(v));
}

/// x86 `SAR r16, CL`: the count is masked to 5 bits, 16+ gives the sign.
fn sar(v: i16, shift: i16) i16 {
    const s: u5 = @intCast(@as(u16, @bitCast(shift)) & 0x1f);
    if (s > 15) return if (v < 0) -1 else 0;
    return v >> @intCast(s);
}

/// x86 `SHR r16, CL`.
fn shr(v: u16, shift: i16) u16 {
    const s: u5 = @intCast(@as(u16, @bitCast(shift)) & 0x1f);
    if (s > 15) return 0;
    return v >> @intCast(s);
}

// @orig 1010:0b3a occupancy_grid_set_cell
/// Sets one cell's object and count (-1 = blocked). The index is a 32-bit
/// computation in the original.
pub fn setCell(grid: *Grid, obj: ?*Object, count: i16, col: i16, row: i16) void {
    const idx: i32 = @as(i32, row) * 81 + col;
    storeCell(grid, idx, obj, @truncate(count));
}

// @orig 1010:0ba6 occupancy_grid_ctor
/// Sets the shifts and the row/column counts for a `width` x `height`
/// background and clears those cells. Above 65 rows / 81 columns it shows
/// the "Erro FATAL !" box and carries on (the extra cells overflow the
/// arrays in the original; see the module notes).
pub fn init(g: *Game, grid: *Grid, width: i16, height: i16, col_shift: i16, row_shift: i16) *Grid {
    grid.rowShift = row_shift;
    grid.colShift = col_shift;
    grid.rowCount = @bitCast(shr(@bitCast(height), row_shift) +% 1);
    grid.colCount = @bitCast(shr(@bitCast(width), col_shift) +% 1);
    if (grid.rowCount > 0x41) {
        ini.messageBoxPrintf(g.plat, &g.messageBuf, msg_caption, msg_rows, 0);
    }
    if (grid.colCount > 0x51) {
        ini.messageBoxPrintf(g.plat, &g.messageBuf, msg_caption, msg_cols, 0);
    }
    var row: i16 = 0;
    while (row < grid.rowCount) : (row += 1) {
        var col: i16 = 0;
        while (col < grid.colCount) : (col += 1) {
            setCell(grid, null, 0, col, row);
        }
    }
    grid.lastCellObject = null;
    grid.firstObject = null;
    return grid;
}

// @orig 1010:d840 occupancy_grid_occupy_cell
/// Stores `obj` in the cell and moves its count one step away from zero
/// (down if blocked, up otherwise). Returns the new count.
pub fn occupyCell(grid: *Grid, obj: ?*Object, col: i16, row: i16) i8 {
    const idx = index16(row, col);
    const c = cellCount(grid, idx);
    const n: i8 = if (c < 0) c -% 1 else c +% 1;
    storeCell(grid, idx, obj, n);
    return n;
}

// @orig 1010:d884 occupancy_grid_vacate_cell
/// Clears the cell's object and moves its count one step back to zero.
/// (The original's `obj` argument is unused.) Returns the new count.
pub fn vacateCell(grid: *Grid, col: i16, row: i16) i8 {
    const idx = index16(row, col);
    const c = cellCount(grid, idx);
    const n: i8 = if (c > 0) c -% 1 else c +% 1;
    storeCell(grid, idx, null, n);
    return n;
}

/// The cell range under an object's hit box: rows `r0..r1`, columns `c0..c1`.
const Span = struct { r0: i16, r1: i16, c0: i16, c1: i16 };

fn hitSpan(grid: *Grid, obj: *Object) Span {
    const hy = frames.hitY(obj);
    const hx = frames.hitX(obj);
    return .{
        .r0 = sar(hy +% obj.y, grid.rowShift),
        .c0 = sar(hx +% obj.x, grid.colShift),
        .r1 = sar(frames.hitH(obj) +% (obj.y +% hy), grid.rowShift),
        .c1 = sar(frames.hitW(obj) +% (obj.x +% hx), grid.colShift),
    };
}

// @orig 1010:d8c2 occupancy_grid_occupy
/// Occupies every cell under the object's hit box. Returns 1, or -1 when
/// the object's position is negative.
pub fn occupy(grid: *Grid, obj: *Object) i8 {
    if (obj.x < 0 or obj.y < 0) return -1;
    const s = hitSpan(grid, obj);
    var row = s.r0;
    while (row <= s.r1) : (row +%= 1) {
        var col = s.c0;
        while (col <= s.c1) : (col +%= 1) {
            _ = occupyCell(grid, obj, col, row);
        }
    }
    return 1;
}

// @orig 1010:d9be occupancy_grid_vacate
/// Vacates every cell under the object's hit box. Returns 1, or -1 when
/// the object's position is negative.
pub fn vacate(grid: *Grid, obj: *Object) i8 {
    if (obj.x < 0 or obj.y < 0) return -1;
    const s = hitSpan(grid, obj);
    var row = s.r0;
    while (row <= s.r1) : (row +%= 1) {
        var col = s.c0;
        while (col <= s.c1) : (col +%= 1) {
            _ = vacateCell(grid, col, row);
        }
    }
    return 1;
}

// @orig 1010:daba occupancy_grid_query_rect
/// Scans the cells covered by the rectangle. `result` is 0 if all are free,
/// else the count of the first occupied cell (`-1 - count` for a blocked
/// cell holding objects), -1 for a negative position. `flag` becomes -1 if
/// a blocked cell was seen; `obj` is the last object met before the first
/// occupied cell and `first` (also `grid.firstObject`) the first one.
pub fn queryRect(grid: *Grid, x: i16, y: i16, w: i16, h: i16) RectQuery {
    var q: RectQuery = .{};
    var res: i8 = 0;
    grid.lastCellObject = null;
    grid.firstObject = null;
    if (x < 0 or y < 0) {
        res = -1;
    } else {
        const row0 = sar(y, grid.rowShift);
        const col0 = sar(x, grid.colShift);
        const row1 = sar(h, grid.rowShift) +% row0;
        const col1 = sar(w, grid.colShift) +% col0;
        if (row1 >= row0) {
            var base: i16 = row0 *% 81;
            var rows: u16 = @bitCast(row1 -% row0 +% 1);
            while (true) {
                if (col1 >= col0) {
                    var col = col0;
                    while (true) {
                        const idx: i32 = @as(u16, @bitCast(base +% col));
                        const c = cellCount(grid, idx);
                        if (c == -1) {
                            q.flag = -1;
                        } else if (res == 0) {
                            const o = cellObject(grid, idx);
                            grid.lastCellObject = o;
                            if (o != null) {
                                if (grid.firstObject == null) grid.firstObject = o;
                                q.obj = o;
                            }
                            if (c > 0) {
                                res = c;
                            } else if (c < 0) {
                                res = -1 -% c;
                                q.flag = -1;
                            }
                        } else if (c < 0) {
                            q.flag = -1;
                        }
                        if (col >= col1) break;
                        col += 1;
                    }
                }
                base +%= 81;
                rows -%= 1;
                if (rows == 0) break;
            }
        }
        if (res == 0) res = q.flag;
    }
    q.result = res;
    q.first = grid.firstObject;
    return q;
}

// @orig 1010:0fac grid_backdrop_query_rect
/// Backdrop slot 04: the grid query (`first` is not part of this slot).
pub fn backdropQueryRect(bd: *Backdrop, x: i16, y: i16, w: i16, h: i16) RectQuery {
    var q = queryRect(bd.grid.?, x, y, w, h);
    q.first = null;
    return q;
}

// @orig 1010:0fd8 grid_backdrop_query_rect_first
/// Backdrop slot 03: the grid query plus the first object found (`first`).
pub fn backdropQueryRectFirst(bd: *Backdrop, x: i16, y: i16, w: i16, h: i16) RectQuery {
    const grid = bd.grid.?;
    var q = queryRect(grid, x, y, w, h);
    q.first = grid.firstObject;
    return q;
}

// @orig 1010:1024 grid_backdrop_is_rect_free
/// Backdrop slot 02: true when the (virtual) rectangle query reports 0.
pub fn backdropIsRectFree(g: *Game, bd: *Backdrop, x: i16, y: i16, w: i16, h: i16) bool {
    return backdrop.queryRect(g, bd, x, y, w, h).result == 0;
}

// @orig 1010:105e grid_backdrop_is_rect_occupied
/// Backdrop slot 01.
pub fn backdropIsRectOccupied(g: *Game, bd: *Backdrop, x: i16, y: i16, w: i16, h: i16) bool {
    return !backdropIsRectFree(g, bd, x, y, w, h);
}

// @orig 1010:1084 grid_backdrop_occupy
/// Backdrop slot 05: returns 1, or -1 for a negative position.
pub fn backdropOccupy(bd: *Backdrop, obj: *Object) i16 {
    return occupy(bd.grid.?, obj);
}

// @orig 1010:10a6 grid_backdrop_vacate
/// Backdrop slot 06: returns 1, or -1 for a negative position.
pub fn backdropVacate(bd: *Backdrop, obj: *Object) i16 {
    return vacate(bd.grid.?, obj);
}

test "cell counts step away from zero and back" {
    const std = @import("std");
    var grid: Grid = .{ .rowShift = 4, .colShift = 4 };
    try std.testing.expectEqual(@as(i8, 1), occupyCell(&grid, null, 3, 2));
    try std.testing.expectEqual(@as(i8, 2), occupyCell(&grid, null, 3, 2));
    try std.testing.expectEqual(@as(i8, 1), vacateCell(&grid, 3, 2));
    setCell(&grid, null, -1, 5, 5);
    try std.testing.expectEqual(@as(i8, -2), occupyCell(&grid, null, 5, 5));
    try std.testing.expectEqual(@as(i8, -1), vacateCell(&grid, 5, 5));
    // a blocked cell reports flag -1 and result 0
    const q = queryRect(&grid, 80, 80, 0, 0);
    try std.testing.expectEqual(@as(i8, -1), q.result);
    try std.testing.expectEqual(@as(i8, -1), q.flag);
    try std.testing.expectEqual(@as(i8, 1), queryRect(&grid, 48, 32, 16, 16).result);
    try std.testing.expectEqual(@as(i8, -1), queryRect(&grid, -1, 0, 1, 1).result);
    std.testing.refAllDecls(@This());
}
