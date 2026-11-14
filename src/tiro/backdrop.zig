//! Port unit `backdrop` (module) of TIRO.EXE. Backdrop/GridBackdrop (one WinG bitmap), TiroBackdrop's create (the wall cells), the occupancy grid and its queries.
//!
//! Only TiroBackdrop is instantiated (Backdrop + GridBackdrop +
//! TiroBackdrop flattened in `world.Backdrop`). Its one WinG bitmap is a
//! top-down pixel buffer (`pixels`, `bgWidth` x `bgHeight`, rows padded to
//! 4) allocated from `g.gpa` and freed by `dtor`. The DC, the logical palette
//! and the old-bitmap handle have no counterpart. The occupancy grid object
//! (`new OccupancyGrid`, never freed) is on the task's local heap. The cells
//! are `g.occupancy`, addressed flat (`row * 81 + col`, 16-bit wrapping as
//! the original): an index outside the 65 x 81 cells would corrupt memory in
//! the original (past the "Estouro" boxes, which carry on); here reads see a
//! free cell and writes are dropped.

const std = @import("std");
const platform = @import("../platform/platform.zig");
const Game = @import("core/game.zig").Game;
const object = @import("core/object.zig");
const Object = object.Object;
const world = @import("core/world.zig");
const Backdrop = world.Backdrop;
const OccupancyGrid = world.OccupancyGrid;
const RectQuery = world.RectQuery;
const dib = @import("dib.zig");
const position = @import("behaviour/position.zig");
const movement = @import("behaviour/movement.zig");
const visibility = @import("behaviour/visibility.zig");

/// The 256 entries of the Win16 `LOGPALETTE256`.
pub const LogPalette = [256]platform.PaletteEntry;

/// Latin-1, as in the original's data segment (1090:0f0a, 0f18, 0f4a, 0f7e).
const msg_caption = "Erro FATAL !";
const msg_rows = "Estouro do n\xfamero de linhas da matriz de ocupa\xe7\xe3o";
const msg_cols = "Estouro do n\xfamero de colunas da matriz de ocupa\xe7\xe3o";
const msg_cannot_open = "N\xe3o foi poss\xedvel abrir o arquivo: %s";

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

/// Stores the object and the count of a cell (dropped outside the matrix).
fn storeCell(g: *Game, idx: i32, obj: ?*Object, count: i8) void {
    if (idx < 0 or idx >= cell_total) return;
    const i: usize = @intCast(idx);
    flatObject(g)[i] = obj;
    flatCount(g)[i] = count;
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

// @orig 1088:5d9e occupancy_grid_set_cell
/// Stores `obj` and the (byte) `count` in cell (`col`, `row`).
pub fn setCell(g: *Game, grid: *OccupancyGrid, obj: ?*Object, count: i16, col: i16, row: i16) void {
    _ = grid;
    storeCell(g, index16(row, col), obj, @truncate(count));
}

// @orig 1088:3b96 occupancy_grid_occupy_cell
/// Stores `obj` in the cell and moves its count one step away from zero
/// (down if blocked, up otherwise).
fn occupyCell(g: *Game, grid: *OccupancyGrid, obj: *Object, col: i16, row: i16) void {
    _ = grid;
    const idx = index16(row, col);
    const c = cellCount(g, idx);
    storeCell(g, idx, obj, if (c < 0) c -% 1 else c +% 1);
}

// @orig 1088:3bf4 occupancy_grid_vacate_cell
/// Clears the cell's object and moves its count one step back to zero.
fn vacateCell(g: *Game, grid: *OccupancyGrid, col: i16, row: i16) void {
    _ = grid;
    const idx = index16(row, col);
    const c = cellCount(g, idx);
    storeCell(g, idx, null, if (c < 1) c +% 1 else c -% 1);
}

/// The cell range under an object's hit box: rows `r0..r1`, columns `c0..c1`.
/// The accessors are out of line in TIRO (`position.hitX` ...); the sums are
/// the original's `hitW + hitX + x`.
const Span = struct { r0: i16, r1: i16, c0: i16, c1: i16 };

fn hitSpan(grid: *const OccupancyGrid, obj: *Object) Span {
    return .{
        .r0 = sar(position.hitY(obj) +% obj.y, grid.rowShift),
        .c0 = sar(position.hitX(obj) +% obj.x, grid.colShift),
        .c1 = sar(position.hitW(obj) +% position.hitX(obj) +% obj.x, grid.colShift),
        .r1 = sar(position.hitH(obj) +% position.hitY(obj) +% obj.y, grid.rowShift),
    };
}

// @orig 1030:0000 occupancy_grid_occupy
/// Occupies every cell under the object's hit box (columns outside, rows
/// inside, as the original; ENCAIXE inlines it the other way round). Returns
/// 1, or -1 when the object's position is negative.
pub fn gridOccupy(g: *Game, grid: *OccupancyGrid, obj: *Object) i8 {
    if (obj.x < 0 or obj.y < 0) return -1;
    const s = hitSpan(grid, obj);
    var col = s.c0;
    while (col <= s.c1) : (col +%= 1) {
        var row = s.r0;
        while (row <= s.r1) : (row +%= 1) occupyCell(g, grid, obj, col, row);
    }
    return 1;
}

// @orig 1030:00e4 occupancy_grid_vacate
/// Vacates every cell under the object's hit box. Returns 1, or -1 when the
/// object's position is negative.
pub fn gridVacate(g: *Game, grid: *OccupancyGrid, obj: *Object) i8 {
    if (obj.x < 0 or obj.y < 0) return -1;
    const s = hitSpan(grid, obj);
    var col = s.c0;
    while (col <= s.c1) : (col +%= 1) {
        var row = s.r0;
        while (row <= s.r1) : (row +%= 1) vacateCell(g, grid, col, row);
    }
    return 1;
}

// @orig 1030:0200 occupancy_grid_query_rect
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
        var row = row0;
        while (row <= row1) : (row += 1) {
            var col = col0;
            while (col <= col1) : (col += 1) {
                const idx = index16(row, col);
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
                if (col == std.math.maxInt(i16)) break;
            }
            if (row == std.math.maxInt(i16)) break;
        }
        if (res == 0) res = q.flag;
    }
    q.result = res;
    q.first = grid.firstObject;
    return q;
}

// @orig 1030:043c backdrop_init_dib_header
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

// @orig 1030:050c backdrop_set_static_colors
/// Entries 0-9 and 246-255 of the system palette into the colour table;
/// their `peFlags` are cleared. (ENCAIXE has no such step.)
pub fn setStaticColors(bd: *Backdrop, pal: *LogPalette) void {
    for (0..10) |i| {
        for ([2]usize{ i, 246 + i }) |k| {
            bd.bmiColors[k] = .{ .red = pal[k].red, .green = pal[k].green, .blue = pal[k].blue, .reserved = 0 };
            pal[k].flags = 0;
        }
    }
}

// @orig 1030:05da backdrop_set_dib_colors
/// Entries 10-245 of the background picture's colour table into the
/// backdrop's colour table and the logical palette (flags PC_RESERVED).
/// (ENCAIXE copies all 256.)
pub fn setDibColors(bd: *Backdrop, pal: *LogPalette) void {
    const bg = bd.background orelse return;
    for (10..246) |k| {
        const c = bg.colors[k];
        bd.bmiColors[k] = .{ .red = c.red, .green = c.green, .blue = c.blue, .reserved = 0 };
        pal[k] = .{ .red = c.red, .green = c.green, .blue = c.blue, .flags = 1 };
    }
}

// @orig 1088:3a3e backdrop_blit_to_dc
/// Copies the view (`viewWidth` x `viewHeight` at the origin) to the window
/// (`hdc` dropped).
pub fn blitToDc(g: *Game, bd: *const Backdrop) void {
    g.plat.wingBitBlt(0, 0, bd.viewWidth, bd.viewHeight, bd.surface(), bd.originX, bd.originY);
}

// @orig 1088:3c50 backdrop_clear
/// PatBlt(BLACKNESS) over the whole bitmap.
pub fn clear(bd: *Backdrop) void {
    @memset(bd.pixels, 0);
}

// @orig 1088:3c80 backdrop_draw_background
/// Copies the whole background picture into the bitmap.
pub fn drawBackground(g: *Game, bd: *Backdrop) dib.Error!void {
    const bg = bd.background orelse return;
    _ = try dib.copy(&bd.bmiHeader, bd.pixels, 0, 0, bg.bits, &bg.header, g.fixes);
}

// @orig 1030:033c backdrop_create
/// Builds the palette (static colours, then the picture's 10-245) and the
/// one WinG bitmap, clears it, shows it in the window and draws the
/// background. There are no failure checks in the original; a bitmap that
/// cannot be allocated returns null here. GetDC/ReleaseDC, CreatePalette,
/// WinGCreateDC and the old-bitmap handle have no counterpart. (ENCAIXE has
/// two bitmaps and realizes the palette; TIRO does neither.)
fn baseCreate(g: *Game, bd: *Backdrop) ?*Backdrop {
    var pal: LogPalette = @splat(.{});
    _ = platform.getSystemPaletteEntries(0, pal[0..10]);
    _ = platform.getSystemPaletteEntries(246, pal[246..256]);
    setStaticColors(bd, &pal);
    setDibColors(bd, &pal);
    bd.dibOrientation = initDibHeader(bd);
    const w: usize = @as(u16, @bitCast(bd.bgWidth));
    const stride = (w + 3) & ~@as(usize, 3);
    const h: usize = @as(u16, @bitCast(bd.bgHeight));
    bd.pixels = g.gpa.alloc(u8, stride * h) catch return null;
    clear(bd);
    blitToDc(g, bd);
    drawBackground(g, bd) catch return null;
    return bd;
}

// @orig 1088:5a08 occupancy_grid_ctor
/// The occupancy grid of a freshly created backdrop (`new OccupancyGrid`,
/// 12 bytes, never freed: the task's local heap): `1 << cell_shift` px
/// cells, the rows and columns that fit, the two "Estouro" boxes (direct
/// MessageBox calls; they carry on) and the cells cleared. Null when the
/// allocation fails.
fn newGrid(g: *Game, bd: *Backdrop, cell_shift: i16) ?*OccupancyGrid {
    const grid = g.local().create(OccupancyGrid) catch return null;
    grid.* = .{};
    grid.rowShift = cell_shift;
    grid.colShift = cell_shift;
    grid.rowCount = @bitCast(shr(@bitCast(bd.bgHeight), cell_shift) +% 1);
    grid.colCount = @bitCast(shr(@bitCast(bd.bgWidth), cell_shift) +% 1);
    if (grid.rowCount > 0x41) _ = g.plat.messageBox(msg_caption, msg_rows, platform.mb.iconexclamation);
    if (grid.colCount > 0x51) _ = g.plat.messageBox(msg_caption, msg_cols, platform.mb.iconexclamation);
    var row: i16 = 0;
    while (row < grid.rowCount) : (row +%= 1) {
        var col: i16 = 0;
        while (col < grid.colCount) : (col +%= 1) setCell(g, grid, null, 0, col, row);
    }
    grid.lastCellObject = null;
    grid.firstObject = null;
    return grid;
}

// @orig 1088:56cc grid_backdrop_create_with_grid
/// GridBackdropVtbl slot 13: `baseCreate` plus the occupancy grid.
pub fn createWithGrid(g: *Game, bd: *Backdrop, cell_shift: i16) ?*Backdrop {
    _ = baseCreate(g, bd);
    bd.grid = newGrid(g, bd, cell_shift);
    return bd;
}

// @orig 1068:0000 tiro_backdrop_create
/// BackdropVtbl slot 00 create (TiroBackdrop's; hwnd dropped): the grid
/// with 32-px cells (20 x 15), then the wall cells (count -1, no object):
/// columns 0 and 19 for rows 5-13, and row 13 for columns 0-18.
pub fn create(g: *Game, bd: *Backdrop) ?*Backdrop {
    _ = createWithGrid(g, bd, 5);
    const grid = bd.grid orelse return bd;
    var row: i16 = 5;
    while (row < 0xe) : (row += 1) {
        setCell(g, grid, null, -1, 0, row);
        setCell(g, grid, null, -1, 0x13, row);
    }
    var col: i16 = 0;
    while (col < 0x13) : (col += 1) setCell(g, grid, null, -1, col, 0xd);
    return bd;
}

// @orig 1088:5abe backdrop_ctor
/// Base constructor: loads the background bitmap `path` and records the
/// view rectangle. If the bitmap cannot be opened the original shows the
/// box (the path as the text, the "Nao foi possivel" line as the caption)
/// and then reads the null header (taken as 0, as ENCAIXE's createScreen).
fn backdropCtor(g: *Game, bd: *Backdrop, path: []const u8, origin_x: i16, origin_y: i16, view_w: i16, view_h: i16) *Backdrop {
    bd.background = dib.loadDib(g.gpa, g.plat, g.fixes, path);
    if (bd.background == null) position.messageBoxPrintf(g, msg_cannot_open, path, 0x612);
    bd.bgWidth = if (bd.background) |bg| @truncate(bg.header.biWidth) else 0;
    bd.bgHeight = if (bd.background) |bg| @truncate(bg.header.biHeight) else 0;
    bd.originX = origin_x;
    bd.originY = origin_y;
    bd.viewWidth = view_w;
    bd.viewHeight = view_h;
    bd.sceneList = null;
    return bd;
}

// @orig 1088:5698 grid_backdrop_ctor
/// Base constructor (the GridBackdrop vtable has no counterpart: flattened).
fn gridBackdropCtor(g: *Game, bd: *Backdrop, path: []const u8, origin_x: i16, origin_y: i16, view_w: i16, view_h: i16) *Backdrop {
    return backdropCtor(g, bd, path, origin_x, origin_y, view_w, view_h);
}

// @orig 1088:554e tiro_backdrop_ctor
/// Constructor of the class TIRO's scene builds (the caller allocates `bd`).
pub fn ctor(g: *Game, bd: *Backdrop, path: []const u8, origin_x: i16, origin_y: i16, view_w: i16, view_h: i16) *Backdrop {
    return gridBackdropCtor(g, bd, path, origin_x, origin_y, view_w, view_h);
}

// @orig 1088:5fa2 backdrop_dtor
/// Releases the WinG bitmap and the background picture (the DC, the palette
/// and the old-bitmap handle have no counterpart).
pub fn dtor(g: *Game, bd: *Backdrop) void {
    if (bd.pixels.len != 0) g.gpa.free(bd.pixels);
    bd.pixels = &.{};
    if (bd.background) |bg| {
        g.gpa.free(bg.bits);
        g.gpa.destroy(bg);
        bd.background = null;
    }
}

// @orig 1088:5f70 backdrop_delete
/// Scalar deleting destructor: `dtor`; freeing the object itself
/// (`flags & 1`) is up to whoever allocated it.
pub fn delete(g: *Game, bd: *Backdrop, flags: u16) *Backdrop {
    _ = flags;
    dtor(g, bd);
    return bd;
}

// @orig 1030:0691 backdrop_autoscroll
/// For the player object at (`x`, `y`) (slot 3A isPlayer), scrolls the view
/// by 20 pixels when it is within 40 pixels of the left/top edge or beyond
/// 500/300 (clamped to the background), moves the object by the same amount,
/// redraws what it overlaps and blits the view. True if it scrolled.
/// (`hdc` dropped; no palette realize, unlike ENCAIXE.)
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
        if (bd.bgHeight < bd.originY +% bd.viewHeight +% 20) dy = 0;
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
    blitToDc(g, bd);
    return true;
}

/// BackdropVtbl slot 01 isRectOccupied (via isRectFree).
// @orig 1088:57fe grid_backdrop_is_rect_occupied
pub fn isRectOccupied(g: *Game, bd: *Backdrop, x: i16, y: i16, w: i16, h: i16) bool {
    return !isRectFree(g, bd, x, y, w, h);
}

/// BackdropVtbl slot 02 isRectFree (via queryRect, slot 04).
// @orig 1088:57c0 grid_backdrop_is_rect_free
pub fn isRectFree(g: *Game, bd: *Backdrop, x: i16, y: i16, w: i16, h: i16) bool {
    return queryRect(g, bd, x, y, w, h).result == 0;
}

/// BackdropVtbl slot 03: the grid query plus the first object found.
// @orig 1088:577a grid_backdrop_query_rect_first
pub fn queryRectFirst(g: *Game, bd: *Backdrop, x: i16, y: i16, w: i16, h: i16) RectQuery {
    const grid = bd.grid.?;
    var q = gridQueryRect(g, grid, x, y, w, h);
    q.first = grid.firstObject;
    return q;
}

/// BackdropVtbl slot 04: the grid query (`first` is not part of it).
// @orig 1088:5746 grid_backdrop_query_rect
pub fn queryRect(g: *Game, bd: *Backdrop, x: i16, y: i16, w: i16, h: i16) RectQuery {
    var q = gridQueryRect(g, bd.grid.?, x, y, w, h);
    q.first = null;
    return q;
}

/// BackdropVtbl slot 05: 1, or -1 for a negative position.
// @orig 1088:5830 grid_backdrop_occupy
pub fn occupy(g: *Game, bd: *Backdrop, obj: *Object) i16 {
    return gridOccupy(g, bd.grid.?, obj);
}

/// BackdropVtbl slot 06: 1, or -1 for a negative position.
// @orig 1088:5856 grid_backdrop_vacate
pub fn vacate(g: *Game, bd: *Backdrop, obj: *Object) i16 {
    return gridVacate(g, bd.grid.?, obj);
}

/// BackdropVtbl slot 07 (default: 0).
// @orig 1088:5582 backdrop_slot07_default (absorbed)
pub fn slot07(g: *Game, bd: *Backdrop) i16 {
    _ = .{ g, bd };
    return 0;
}

/// BackdropVtbl slot 08 (default: nothing).
// @orig 1088:559e backdrop_slot08_default (absorbed)
pub fn slot08(g: *Game, bd: *Backdrop, arg2: i16, arg1: i16) void {
    _ = .{ g, bd, arg2, arg1 };
}

/// BackdropVtbl slot 09 (default: returns this).
// @orig 1088:55b8 backdrop_set_vanish_point_default (absorbed)
pub fn setVanishPoint(g: *Game, bd: *Backdrop, vanish_x: i16, vanish_y: i16) *Backdrop {
    _ = .{ g, vanish_x, vanish_y };
    return bd;
}

/// BackdropVtbl slot 0A (default: returns this).
// @orig 1088:55d4 backdrop_set_view_default (absorbed)
pub fn setView(g: *Game, bd: *Backdrop, view_x: i16, view_y: i16, view3d_x: i16, view3d_y: i16, view3d_z: i16) *Backdrop {
    _ = .{ g, view_x, view_y, view3d_x, view3d_y, view3d_z };
    return bd;
}

/// BackdropVtbl slot 0B (default: returns this).
// @orig 1088:55f0 backdrop_set_axis_default (absorbed)
pub fn setAxis(g: *Game, bd: *Backdrop, axis_x: i16, axis_y: i16) *Backdrop {
    _ = .{ g, axis_x, axis_y };
    return bd;
}

/// BackdropVtbl slots 0C and 10 (default: 0).
// @orig 1088:560c backdrop_get_vanish_x_default (absorbed)
pub fn getVanishX(g: *Game, bd: *Backdrop) i16 {
    _ = .{ g, bd };
    return 0;
}

/// BackdropVtbl slots 0D and 11 (default: 0).
// @orig 1088:5628 backdrop_get_vanish_y_default (absorbed)
pub fn getVanishY(g: *Game, bd: *Backdrop) i16 {
    _ = .{ g, bd };
    return 0;
}

/// BackdropVtbl slot 0E (default: 0).
// @orig 1088:5644 backdrop_get_eye_distance_default (absorbed)
pub fn getEyeDistance(g: *Game, bd: *Backdrop) i16 {
    _ = .{ g, bd };
    return 0;
}

/// BackdropVtbl slot 0F (default: 0).
// @orig 1088:5660 backdrop_get_axis_x_default (absorbed)
pub fn getAxisX(g: *Game, bd: *Backdrop) i16 {
    _ = .{ g, bd };
    return 0;
}

/// BackdropVtbl slot 12 (default: 0).
// @orig 1088:567c backdrop_get_view3d_z_default (absorbed)
pub fn getView3dZ(g: *Game, bd: *Backdrop) i16 {
    _ = .{ g, bd };
    return 0;
}
