//! Port unit `backdrop` (module) of ENCAIXE.EXE. Backdrop/GridBackdrop (two WinG bitmaps), TetrisBackdrop's create (the wall cells, BUGS.md E9), the occupancy grid and its queries.
//!
//! Only TetrisBackdrop is instantiated (Backdrop + GridBackdrop +
//! TetrisBackdrop flattened in `world.Backdrop`). Its two WinG bitmaps are
//! two top-down pixel buffers (`pixels`, `pixels2`, `bgWidth` x `bgHeight`,
//! rows padded to 4) allocated from `g.gpa`, as is the occupancy grid; the
//! unit that deletes the backdrop frees them. The DCs, the logical palette
//! and the old-bitmap handles have no counterpart. The cells are
//! `g.occupancy`, addressed flat (`row * 81 + col`, 16-bit wrapping as the
//! original): an index outside the 65 x 81 cells would corrupt memory in the
//! original (past the "Estouro" boxes, which carry on); here reads see a free
//! cell and writes are dropped.

const std = @import("std");
const Game = @import("core/game.zig").Game;
const object = @import("core/object.zig");
const Object = object.Object;
const world = @import("core/world.zig");
const Backdrop = world.Backdrop;
const OccupancyGrid = world.OccupancyGrid;
const RectQuery = world.RectQuery;
const platform = @import("../platform/platform.zig");
const dib = @import("dib.zig");
const lists = @import("lists.zig");
const movement = @import("behaviour/movement.zig");
const visibility = @import("behaviour/visibility.zig");

/// The 256 entries of the Win16 `LOGPALETTE256`.
pub const LogPalette = [256]platform.PaletteEntry;

/// Latin-1, as in the original's data segment (1018:080c, 081a, 084c).
const msg_caption = "Erro FATAL !";
const msg_rows = "Estouro do n\xfamero de linhas da matriz de ocupa\xe7\xe3o";
const msg_cols = "Estouro do n\xfamero de colunas da matriz de ocupa\xe7\xe3o";

const cell_total = world.grid_rows * world.grid_cols;

fn flatCount(g: *Game) *[cell_total]i8 {
    return @ptrCast(&g.occupancy.count);
}

fn flatObject(g: *Game) *[cell_total]?*Object {
    return @ptrCast(&g.occupancy.object);
}

fn cellCount(g: *Game, idx: i32) i8 {
    if (idx < 0 or idx >= cell_total) return 0;
    return flatCount(g)[@intCast(idx)];
}

fn cellObject(g: *Game, idx: i32) ?*Object {
    if (idx < 0 or idx >= cell_total) return null;
    return flatObject(g)[@intCast(idx)];
}

fn storeCell(g: *Game, idx: i32, obj: ?*Object, count: ?i8) void {
    if (idx < 0 or idx >= cell_total) return;
    const i: usize = @intCast(idx);
    flatObject(g)[i] = obj;
    if (count) |c| flatCount(g)[i] = c;
}

/// 16-bit `row * 81 + col` (`IMUL`, `ADD`), as an unsigned index.
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

/// The cell range under an object's hit box: rows `r0..r1`, columns `c0..c1`.
const Span = struct { r0: i16, r1: i16, c0: i16, c1: i16 };

fn hitSpan(grid: *const OccupancyGrid, obj: *const Object) Span {
    const f = obj.frames[@intCast(obj.curStrip)];
    return .{
        .r0 = sar(f.hitY +% obj.y, grid.rowShift),
        .c0 = sar(f.hitX +% obj.x, grid.colShift),
        .r1 = sar(f.hitY +% f.hitH +% obj.y, grid.rowShift),
        .c1 = sar(f.hitX +% f.hitW +% obj.x, grid.colShift),
    };
}

// @orig 1008:8124 occupancy_grid_occupy
/// Occupies every cell under the object's hit box: stores `obj` and moves
/// the count one step away from zero (down if blocked, up otherwise).
/// Returns 1, or -1 when the object's position is negative.
pub fn gridOccupy(g: *Game, grid: *OccupancyGrid, obj: *Object) i8 {
    if (obj.x < 0 or obj.y < 0) return -1;
    const s = hitSpan(grid, obj);
    var row = s.r0;
    while (row <= s.r1) : (row +%= 1) {
        var col = s.c0;
        while (col <= s.c1) : (col +%= 1) {
            const idx = index16(row, col);
            const c = cellCount(g, idx);
            storeCell(g, idx, obj, if (c < 0) c -% 1 else c +% 1);
        }
    }
    return 1;
}

// @orig 1008:8214 occupancy_grid_vacate
/// Vacates every cell under the object's hit box: clears the object and
/// moves the count one step back to zero. Returns 1, or -1 when the
/// object's position is negative.
pub fn gridVacate(g: *Game, grid: *OccupancyGrid, obj: *Object) i8 {
    if (obj.x < 0 or obj.y < 0) return -1;
    const s = hitSpan(grid, obj);
    var row = s.r0;
    while (row <= s.r1) : (row +%= 1) {
        var col = s.c0;
        while (col <= s.c1) : (col +%= 1) {
            const idx = index16(row, col);
            const c = cellCount(g, idx);
            storeCell(g, idx, null, if (c > 0) c -% 1 else c +% 1);
        }
    }
    return 1;
}

// @orig 1008:8302 occupancy_grid_query_rect
/// Scans the cells covered by the rectangle. `result` is 0 if all are free,
/// else the count of the first occupied cell (`-1 - count` for a blocked
/// cell holding objects), -1 for a negative position. `flag` becomes -1 if
/// a blocked cell was seen; `obj` is the last object met before the first
/// occupied cell and `first` (also `grid.firstObject`) the first one.
pub fn gridQueryRect(g: *Game, grid: *OccupancyGrid, x: i16, y: i16, w: i16, h: i16) RectQuery {
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
                        const c = cellCount(g, idx);
                        if (c == -1) {
                            q.flag = -1;
                        } else if (res == 0) {
                            const o = cellObject(g, idx);
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

// @orig 1008:85b0 backdrop_init_dib_header
/// Asks WinG for the DIB format (always top-down here), then sets 8 bpp,
/// the background's width and height x orientation. Returns the
/// orientation (1 bottom-up, -1 top-down).
pub fn initDibHeader(bd: *Backdrop) i32 {
    var orient: i32 = 1;
    if (!platform.wingRecommendDibFormat(&bd.bmiHeader)) {
        bd.bmiHeader.biSize = 0x28;
        bd.bmiHeader.biPlanes = 1;
        bd.bmiHeader.biBitCount = 8;
        bd.bmiHeader.biCompression = 0;
        bd.bmiHeader.biSizeImage = 0;
        bd.bmiHeader.biClrUsed = 0;
        bd.bmiHeader.biClrImportant = 0;
    } else {
        bd.bmiHeader.biBitCount = 8;
        bd.bmiHeader.biCompression = 0;
        orient = if (bd.bmiHeader.biHeight < 0) -1 else 1;
    }
    bd.bmiHeader.biWidth = bd.bgWidth;
    bd.bmiHeader.biHeight = @as(i32, bd.bgHeight) *% orient;
    return orient;
}

// @orig 1008:8634 backdrop_set_dib_colors
/// All 256 colours of the background picture's colour table into the
/// backdrop's colour table and the logical palette (flags PC_RESERVED;
/// NOITE copies 10-245 only).
pub fn setDibColors(bd: *Backdrop, pal: *LogPalette) void {
    const bg = bd.background orelse return;
    for (0..256) |k| {
        const c = bg.colors[k];
        bd.bmiColors[k] = .{ .red = c.red, .green = c.green, .blue = c.blue, .reserved = 0 };
        pal[k] = .{ .red = c.red, .green = c.green, .blue = c.blue, .flags = 1 };
    }
}

/// Copies the view (`viewWidth` x `viewHeight` at the origin) of the first
/// bitmap to the window.
fn blitView(g: *Game, bd: *const Backdrop) void {
    g.plat.wingBitBlt(0, 0, bd.viewWidth, bd.viewHeight, bd.surface(), bd.originX, bd.originY);
}

// @orig 1008:8414 backdrop_create
/// Builds the palette and the two WinG bitmaps, clears both, shows the
/// first in the window and draws the background into both. There are no
/// failure checks in the original; a bitmap that cannot be allocated returns
/// null here. CreatePalette, WinGCreateDC and the old-bitmap handles have no
/// counterpart.
pub fn baseCreate(g: *Game, bd: *Backdrop) ?*Backdrop {
    var pal: LogPalette = @splat(.{});
    _ = platform.getSystemPaletteEntries(0, pal[0..10]);
    _ = platform.getSystemPaletteEntries(246, pal[246..256]);
    setDibColors(bd, &pal);
    bd.dibOrientation = initDibHeader(bd);
    const w: usize = @as(u16, @bitCast(bd.bgWidth));
    const stride = (w + 3) & ~@as(usize, 3);
    const h: usize = @as(u16, @bitCast(bd.bgHeight));
    bd.pixels = g.gpa.alloc(u8, stride * h) catch return null;
    bd.pixels2 = g.gpa.alloc(u8, stride * h) catch return null;
    @memset(bd.pixels, 0);
    @memset(bd.pixels2, 0);
    _ = g.plat.realizePalette(&bd.bmiColors);
    blitView(g, bd);
    const bg = bd.background orelse return bd;
    _ = dib.copy(&bd.bmiHeader, bd.pixels, 0, 0, bg.bits, &bg.header, g.fixes) catch return null;
    _ = dib.copy(&bd.bmiHeader, bd.pixels2, 0, 0, bg.bits, &bg.header, g.fixes) catch return null;
    return bd;
}

/// The occupancy grid of a freshly created backdrop (the inlined
/// `occupancy_grid_ctor`): 12 bytes, `1 << cell_shift` px cells, the rows
/// and columns that fit, the two "Estouro" boxes (they carry on) and the
/// cells cleared. Null when the allocation fails.
fn newGrid(g: *Game, bd: *Backdrop, cell_shift: i16) ?*OccupancyGrid {
    const grid = g.gpa.create(OccupancyGrid) catch return null;
    grid.* = .{};
    grid.rowShift = cell_shift;
    grid.colShift = cell_shift;
    grid.rowCount = @bitCast(shr(@bitCast(bd.bgHeight), cell_shift) +% 1);
    grid.colCount = @bitCast(shr(@bitCast(bd.bgWidth), cell_shift) +% 1);
    if (grid.rowCount > 0x41) lists.messageBoxPrintf(g, msg_caption, msg_rows, 0);
    if (grid.colCount > 0x51) lists.messageBoxPrintf(g, msg_caption, msg_cols, 0);
    var row: i16 = 0;
    while (row < grid.rowCount) : (row += 1) {
        var col: i16 = 0;
        while (col < grid.colCount) : (col += 1) {
            storeCell(g, @as(i32, row) * 81 + col, null, 0);
        }
    }
    grid.lastCellObject = null;
    grid.firstObject = null;
    return grid;
}

// @orig 1008:a8b4 grid_backdrop_create_with_grid
/// GridBackdropVtbl slot 13: `baseCreate` plus the occupancy grid.
pub fn createWithGrid(g: *Game, bd: *Backdrop, cell_shift: i16) ?*Backdrop {
    _ = baseCreate(g, bd);
    bd.grid = newGrid(g, bd, cell_shift);
    return bd;
}

// @orig 1008:b766 te_grid_backdrop_create_with_walls
/// BackdropVtbl slot 00 create (TetrisBackdrop's; hwnd dropped): the grid
/// with 32-px cells, then the wall cells (count -1, no object). BUGS.md E9:
/// the original blocks columns 0 and 15 for rows 1-10 and rows 1 and 13 for
/// columns 0-13 (the first index is the board column, the second the board
/// row); `encaixe_grid_walls_match_board` closes the 11 x 14 board's box
/// instead (the board in cells 1-11 x 1-14: first index 0 and 12, second
/// index 0 and 15).
pub fn create(g: *Game, bd: *Backdrop) ?*Backdrop {
    _ = baseCreate(g, bd);
    bd.grid = newGrid(g, bd, 5);
    if (g.fixes.encaixe_grid_walls_match_board) {
        var i: i32 = 0;
        while (i <= 15) : (i += 1) {
            storeCell(g, i * 81 + 0, null, -1);
            storeCell(g, i * 81 + 12, null, -1);
        }
        i = 0;
        while (i <= 12) : (i += 1) {
            storeCell(g, i * 81 + 0, null, -1);
            storeCell(g, i * 81 + 15, null, -1);
        }
        return bd;
    }
    var row: i32 = 1;
    while (row <= 10) : (row += 1) {
        storeCell(g, row * 81 + 0, null, -1);
        storeCell(g, row * 81 + 15, null, -1);
    }
    var col: i32 = 0;
    while (col <= 13) : (col += 1) {
        storeCell(g, 1 * 81 + col, null, -1);
        storeCell(g, 13 * 81 + col, null, -1);
    }
    return bd;
}

// @orig 1008:869a backdrop_autoscroll
/// For a player object at (`x`, `y`), scrolls the view by 20 pixels when it
/// is within 40 pixels of the left/top edge or beyond 500/300 (clamped to
/// the background), moves the object by the same amount, redraws what it
/// overlaps and blits the view. True if it scrolled. (`hdc` dropped.)
pub fn autoscroll(g: *Game, bd: *Backdrop, obj: *Object, x: i16, y: i16) bool {
    if (!obj.is(.player)) return false;
    var dx: i16 = 0;
    var dy: i16 = 0;
    if (x -% bd.originX > 500) {
        dx = 1;
    } else if (x -% bd.originX < 40) {
        dx = -1;
    }
    if (y -% bd.originY > 300) {
        dy = 1;
    } else if (y -% bd.originY < 40) {
        dy = -1;
    }
    if (dx == 0 and dy == 0) return false;
    if (dx > 0) {
        if (bd.bgWidth < bd.originX +% bd.viewWidth +% 20) dx = 0;
    } else if (dx < 0) {
        if (bd.originX -% 20 < 0) dx = 0;
    }
    if (dy > 0) {
        if (bd.originY +% bd.viewHeight +% 20 > bd.bgHeight) dy = 0;
    } else if (dy < 0) {
        if (bd.originY -% 20 < 0) dy = 0;
    }
    if (dx == 0 and dy == 0) return false;
    dx *%= 20;
    dy *%= 20;
    bd.originX +%= dx;
    bd.originY +%= dy;
    _ = slot07(g, bd);
    movement.placeAt(g, obj, obj.x +% dx, obj.y +% dy, bd);
    visibility.redrawOverlapping(g, obj, bd, 1);
    _ = g.plat.realizePalette(&bd.bmiColors);
    blitView(g, bd);
    return true;
}

/// GridBackdropVtbl slot 01 isRectOccupied (via queryRect, slot 04).
// @orig 1008:aa36 grid_backdrop_is_rect_occupied
pub fn isRectOccupied(g: *Game, bd: *Backdrop, x: i16, y: i16, w: i16, h: i16) bool {
    return queryRect(g, bd, x, y, w, h).result != 0;
}

/// GridBackdropVtbl slot 02 isRectFree (via queryRect, slot 04).
// @orig 1008:aa0c grid_backdrop_is_rect_free
pub fn isRectFree(g: *Game, bd: *Backdrop, x: i16, y: i16, w: i16, h: i16) bool {
    return queryRect(g, bd, x, y, w, h).result == 0;
}

/// GridBackdropVtbl slot 03: the grid query plus the first object found.
// @orig 1008:a9d8 grid_backdrop_query_rect_first
pub fn queryRectFirst(g: *Game, bd: *Backdrop, x: i16, y: i16, w: i16, h: i16) RectQuery {
    const grid = bd.grid.?;
    var q = gridQueryRect(g, grid, x, y, w, h);
    q.first = grid.firstObject;
    return q;
}

/// GridBackdropVtbl slot 04: the grid query (`first` is not part of it).
// @orig 1008:a9ba grid_backdrop_query_rect
pub fn queryRect(g: *Game, bd: *Backdrop, x: i16, y: i16, w: i16, h: i16) RectQuery {
    var q = gridQueryRect(g, bd.grid.?, x, y, w, h);
    q.first = null;
    return q;
}

/// GridBackdropVtbl slot 05: 1, or -1 for a negative position.
// @orig 1008:aa66 grid_backdrop_occupy
pub fn occupy(g: *Game, bd: *Backdrop, obj: *Object) i16 {
    return gridOccupy(g, bd.grid.?, obj);
}

/// GridBackdropVtbl slot 06: 1, or -1 for a negative position.
// @orig 1008:aa7c grid_backdrop_vacate
pub fn vacate(g: *Game, bd: *Backdrop, obj: *Object) i16 {
    return gridVacate(g, bd.grid.?, obj);
}

/// BackdropVtbl slot 07 (default: 0).
// @orig 1008:a86e backdrop_slot07_default (absorbed)
pub fn slot07(g: *Game, bd: *Backdrop) i16 {
    _ = .{ g, bd };
    return 0;
}

/// BackdropVtbl slot 08 (default: nothing).
// @orig 1008:a874 backdrop_slot08_default (absorbed)
pub fn slot08(g: *Game, bd: *Backdrop, arg2: i16, arg1: i16) void {
    _ = .{ g, bd, arg2, arg1 };
}

/// BackdropVtbl slot 09 (default: returns this).
// @orig 1008:a878 backdrop_set_vanish_point_default (absorbed)
pub fn setVanishPoint(g: *Game, bd: *Backdrop, vanish_x: i16, vanish_y: i16) *Backdrop {
    _ = .{ g, vanish_x, vanish_y };
    return bd;
}

/// BackdropVtbl slot 0A (default: returns this).
// @orig 1008:a882 backdrop_set_view_default (absorbed)
pub fn setView(g: *Game, bd: *Backdrop, view_x: i16, view_y: i16, view3d_x: i16, view3d_y: i16, view3d_z: i16) *Backdrop {
    _ = .{ g, view_x, view_y, view3d_x, view3d_y, view3d_z };
    return bd;
}

/// BackdropVtbl slot 0B (default: returns this).
// @orig 1008:a88c backdrop_set_axis_default (absorbed)
pub fn setAxis(g: *Game, bd: *Backdrop, axis_x: i16, axis_y: i16) *Backdrop {
    _ = .{ g, axis_x, axis_y };
    return bd;
}

/// BackdropVtbl slots 0C and 10 (default: 0).
// @orig 1008:a896 backdrop_get_vanish_x_default (absorbed)
pub fn getVanishX(g: *Game, bd: *Backdrop) i16 {
    _ = .{ g, bd };
    return 0;
}

/// BackdropVtbl slots 0D and 11 (default: 0).
// @orig 1008:a89c backdrop_get_vanish_y_default (absorbed)
pub fn getVanishY(g: *Game, bd: *Backdrop) i16 {
    _ = .{ g, bd };
    return 0;
}

/// BackdropVtbl slot 0E (default: 0).
// @orig 1008:a8a2 backdrop_get_eye_distance_default (absorbed)
pub fn getEyeDistance(g: *Game, bd: *Backdrop) i16 {
    _ = .{ g, bd };
    return 0;
}

/// BackdropVtbl slot 0F (default: 0).
// @orig 1008:a8a8 backdrop_get_axis_x_default (absorbed)
pub fn getAxisX(g: *Game, bd: *Backdrop) i16 {
    _ = .{ g, bd };
    return 0;
}

/// BackdropVtbl slot 12 (default: 0).
// @orig 1008:a8ae backdrop_get_view3d_z_default (absorbed)
pub fn getView3dZ(g: *Game, bd: *Backdrop) i16 {
    _ = .{ g, bd };
    return 0;
}
