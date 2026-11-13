//! Port unit `backdrop` (module). the scene backdrop: WinG view, palette, background, perspective parameters, autoscroll.
//!
//! Only PerspectiveBackdrop is instantiated, so Backdrop / GridBackdrop /
//! PerspectiveBackdrop are one flat struct and every slot is a plain
//! function. The WinG DC, palette and old-bitmap handles have no
//! counterpart (see `world.Backdrop`).
//!
//! Contract for this unit (docs/DESIGN.md "Backdrop, pixels and palette"):
//! the WinG bitmap is bgWidth × bgHeight, top-down (`dibOrientation` -1,
//! from `platform.wingRecommendDibFormat`), reached through
//! `Backdrop.surface()`; blits are `g.plat.wingBitBlt`, palette realizes
//! `g.plat.realizePalette(&bd.bmiColors)`, the static colours
//! `platform.getSystemPaletteEntries`. Slots 01–06 forward to the `grid`
//! unit's `backdrop*` functions; `createWithGrid` builds the grid with
//! `grid.init(g, grid, bd.bgWidth, bd.bgHeight, cell_shift, cell_shift)`.

const Game = @import("core/game.zig").Game;
const object = @import("core/object.zig");
const Object = object.Object;
const world = @import("core/world.zig");
const Backdrop = world.Backdrop;
const RectQuery = world.RectQuery;
const Error = @import("core/errors.zig").Error;
const platform = @import("platform/platform.zig");
const ini = @import("ini.zig");
const dib = @import("dib.zig");
const grid_unit = @import("grid.zig");
const position = @import("behaviour/position.zig");
const movement = @import("behaviour/movement.zig");
const visibility = @import("behaviour/visibility.zig");
const space3d = @import("behaviour/space3d.zig");

/// The 256 entries of the Win16 `LOGPALETTE256`.
pub const LogPalette = [256]platform.PaletteEntry;

// @orig 1010:0c80 backdrop_ctor
/// Base constructor: loads the background bitmap `path` and records the
/// view rectangle. If the bitmap cannot be opened the original shows the
/// "Erro Fatal!!" box and then dereferences the null pointer (a GPF), so
/// this returns `error.Fatal`.
fn backdropCtor(g: *Game, bd: *Backdrop, path: []const u8, origin_x: i16, origin_y: i16, view_w: i16, view_h: i16) Error!*Backdrop {
    bd.background = try dib.loadDib(g.gpa, g.plat, g.fixes, &g.dibPathBuf, &g.driveCD, path);
    const bg = bd.background orelse {
        // 1010:9344
        ini.messageBoxPrintf(g.plat, &g.messageBuf, "Erro Fatal!!", "N\xe3o foi poss\xedvel abrir o arquivo: %s", path);
        return error.Fatal;
    };
    bd.bgWidth = @truncate(bg.header.biWidth);
    bd.bgHeight = @truncate(bg.header.biHeight);
    bd.originX = origin_x;
    bd.originY = origin_y;
    bd.viewWidth = view_w;
    bd.viewHeight = view_h;
    bd.sceneList = null;
    return bd;
}

// @orig 1010:0eda grid_backdrop_ctor
fn gridBackdropCtor(g: *Game, bd: *Backdrop, path: []const u8, origin_x: i16, origin_y: i16, view_w: i16, view_h: i16) Error!*Backdrop {
    return backdropCtor(g, bd, path, origin_x, origin_y, view_w, view_h);
}

// @orig 1010:10ea perspective_backdrop_ctor
/// Constructor of the class every scene uses (the caller allocates `bd`).
pub fn ctor(g: *Game, bd: *Backdrop, path: []const u8, origin_x: i16, origin_y: i16, view_w: i16, view_h: i16) Error!*Backdrop {
    return gridBackdropCtor(g, bd, path, origin_x, origin_y, view_w, view_h);
}

// @orig 1010:dc12 backdrop_dtor
/// Releases the background bitmap (the WinG DC, bitmap and palette have no
/// counterpart; the pixels live in the scene arena).
pub fn dtor(g: *Game, bd: *Backdrop) void {
    if (bd.background) |bg| {
        g.gpa.free(bg.bits);
        g.gpa.destroy(bg);
        bd.background = null;
    }
}

// @orig 1018:2ae6 backdrop_scalar_dtor
/// Destructor wrapper; freeing the object itself (`flags & 1`) is up to
/// whoever allocated it.
pub fn scalarDtor(g: *Game, bd: *Backdrop, flags: u16) *Backdrop {
    _ = flags;
    dtor(g, bd);
    return bd;
}

// @orig 1010:0d1a backdrop_blit_to_dc
/// Copies the view (`viewWidth` × `viewHeight` at the origin) to the window.
pub fn blitToDc(g: *Game, bd: *const Backdrop) void {
    g.plat.wingBitBlt(0, 0, bd.viewWidth, bd.viewHeight, bd.surface(), bd.originX, bd.originY);
}

// @orig 1010:0d50 backdrop_clear
/// PatBlt(BLACKNESS) over the whole bitmap.
pub fn clear(bd: *Backdrop) void {
    @memset(bd.pixels, 0);
}

// @orig 1010:0d7e backdrop_draw_background
/// Copies the whole background picture into the bitmap.
pub fn drawBackground(g: *Game, bd: *Backdrop) Error!void {
    const bg = bd.background orelse return;
    _ = try dib.copy(&bd.bmiHeader, bd.pixels, 0, 0, bg.bits, &bg.header, g.fixes);
}

// @orig 1010:a7f6 backdrop_restore_background
/// Identical to `drawBackground`.
pub fn restoreBackground(g: *Game, bd: *Backdrop) Error!void {
    return drawBackground(g, bd);
}

// @orig 1010:de94 backdrop_set_static_colors
/// Entries 0-9 and 246-255 of the system palette into the colour table;
/// their `peFlags` are cleared.
pub fn setStaticColors(bd: *Backdrop, pal: *LogPalette) void {
    for (0..10) |i| {
        for ([2]usize{ i, 246 + i }) |k| {
            bd.bmiColors[k] = .{ .red = pal[k].red, .green = pal[k].green, .blue = pal[k].blue, .reserved = 0 };
            pal[k].flags = 0;
        }
    }
}

// @orig 1010:df10 backdrop_set_dib_colors
/// Entries 10-245 of the background picture's colour table into the
/// backdrop's colour table and the logical palette (flags PC_RESERVED).
pub fn setDibColors(bd: *Backdrop, pal: *LogPalette) void {
    const bg = bd.background orelse return;
    for (10..246) |k| {
        const c = bg.colors[k];
        bd.bmiColors[k] = .{ .red = c.red, .green = c.green, .blue = c.blue, .reserved = 0 };
        pal[k] = .{ .red = c.red, .green = c.green, .blue = c.blue, .flags = 1 };
    }
}

// @orig 1010:ddea backdrop_init_dib_header
/// Asks WinG for the DIB format (always top-down here), then sets 8 bpp,
/// the background's width and height × orientation. Returns the
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

// @orig 1010:dc82 backdrop_create
/// Builds the palette and the WinG bitmap, clears it, shows it in the
/// window and draws the background. A bitmap that cannot be allocated shows
/// the original's box and returns null (the original goes on and faults).
/// CreatePalette, WinGCreateDC and their failure boxes have no counterpart.
fn createBase(g: *Game, bd: *Backdrop) ?*Backdrop {
    var pal: LogPalette = @splat(.{});
    _ = platform.getSystemPaletteEntries(0, pal[0..10]);
    _ = platform.getSystemPaletteEntries(246, pal[246..256]);
    setStaticColors(bd, &pal);
    setDibColors(bd, &pal);
    bd.dibOrientation = initDibHeader(bd);
    const w: usize = @as(u16, @bitCast(bd.bgWidth));
    const stride = (w + 3) & ~@as(usize, 3);
    const h: usize = @as(u16, @bitCast(bd.bgHeight));
    bd.pixels = g.scene_arena.allocator().alloc(u8, stride * h) catch {
        // 1010:e244
        ini.messageBoxPrintf(g.plat, &g.messageBuf, "Erro Fatal!!", "N\xe3o foi poss\xedvel criar o DDB para a o fundo da janela", 0);
        return null;
    };
    clear(bd);
    blitToDc(g, bd);
    drawBackground(g, bd) catch return null;
    return bd;
}

/// Backdrop slot 00: the grid backdrop's create is `createWithGrid(this, 4)`.
// @orig 1010:0f86 grid_backdrop_create
pub fn create(g: *Game, bd: *Backdrop) ?*Backdrop {
    return createWithGrid(g, bd, 4);
}

/// Backdrop slot 01.
pub fn isRectOccupied(g: *Game, bd: *Backdrop, x: i16, y: i16, w: i16, h: i16) bool {
    return grid_unit.backdropIsRectOccupied(g, bd, x, y, w, h);
}

/// Backdrop slot 02.
pub fn isRectFree(g: *Game, bd: *Backdrop, x: i16, y: i16, w: i16, h: i16) bool {
    return grid_unit.backdropIsRectFree(g, bd, x, y, w, h);
}

/// Backdrop slot 03.
pub fn queryRectFirst(g: *Game, bd: *Backdrop, x: i16, y: i16, w: i16, h: i16) RectQuery {
    _ = g;
    return grid_unit.backdropQueryRectFirst(bd, x, y, w, h);
}

/// Backdrop slot 04.
pub fn queryRect(g: *Game, bd: *Backdrop, x: i16, y: i16, w: i16, h: i16) RectQuery {
    _ = g;
    return grid_unit.backdropQueryRect(bd, x, y, w, h);
}

/// Backdrop slot 05.
pub fn occupy(g: *Game, bd: *Backdrop, obj: *Object) i16 {
    _ = g;
    return grid_unit.backdropOccupy(bd, obj);
}

/// Backdrop slot 06.
pub fn vacate(g: *Game, bd: *Backdrop, obj: *Object) i16 {
    const r = grid_unit.backdropVacate(bd, obj);
    // B29: the vacate cleared the object of cells other objects still occupy.
    if (g.fixes.vacate_keeps_other_occupants and r == 1) {
        grid_unit.repointOccupants(bd.grid.?, obj, &.{ if (bd.sceneList) |l| l.head else null, g.globalObjects.head });
    }
    return r;
}

/// Backdrop slot 07 (does nothing, returns 0).
// @orig 1010:0e18 FUN_1010_0e18
pub fn slot07(g: *Game, bd: *Backdrop) i16 {
    _ = .{ g, bd };
    return 0;
}

/// Backdrop slot 09: the vanishing point; `vanishY` is kept measured up
/// from the bottom of the view.
// @orig 1010:ad4a perspective_backdrop_set_vanish_point
pub fn setVanishPoint(g: *Game, bd: *Backdrop, vanish_x: i16, vanish_y: i16) *Backdrop {
    _ = g;
    bd.vanishX = vanish_x;
    bd.vanishY = bd.viewHeight -% vanish_y;
    return bd;
}

/// Backdrop slot 0A. `view_x` is unused. A zero divisor (`view3d_z` equal
/// to the view height minus `view_y`) is an integer-divide fault in the
/// original; the port panics.
// @orig 1010:ad76 perspective_backdrop_set_view
pub fn setView(g: *Game, bd: *Backdrop, view_x: i16, view_y: i16, view3d_x: i16, view3d_y: i16, view3d_z: i16) *Backdrop {
    _ = .{ g, view_x };
    const v = bd.viewHeight -% view_y;
    bd.view3dX = view3d_x;
    bd.view3dY = 0 -% view3d_y;
    bd.view3dZ = view3d_z;
    const den: i32 = view3d_z -% v;
    const num: i32 = @as(i32, v -% bd.vanishY) * @as(i32, view3d_y);
    if (den == 0) @panic("backdrop.setView: integer divide by zero (view3d_z == viewHeight - view_y)");
    bd.eyeDistance = @truncate(@divTrunc(num, den));
    return bd;
}

/// Backdrop slot 0B. With `axis_x` 0 the axis is derived from the vanishing
/// point (a zero divisor faults in the original; the port panics).
// @orig 1010:add8 perspective_backdrop_set_axis
pub fn setAxis(g: *Game, bd: *Backdrop, axis_x: i16, axis_y: i16) *Backdrop {
    _ = g;
    const v = bd.viewHeight -% axis_y;
    if (axis_x == 0) {
        const den: i32 = bd.vanishY -% v;
        const num: i32 = @as(i32, bd.vanishX) * @as(i32, v);
        if (den == 0) @panic("backdrop.setAxis: integer divide by zero (vanishY == viewHeight - axis_y)");
        bd.axisX = @truncate(@divTrunc(num, den));
    } else {
        bd.axisX = 0 -% axis_x;
    }
    return bd;
}

/// Backdrop slots 0C and 10.
// @orig 1010:1128 perspective_backdrop_get_vanish_x
pub fn getVanishX(g: *Game, bd: *Backdrop) i16 {
    _ = g;
    return bd.vanishX;
}

/// Backdrop slots 0D and 11.
// @orig 1010:113e perspective_backdrop_get_vanish_y
pub fn getVanishY(g: *Game, bd: *Backdrop) i16 {
    _ = g;
    return bd.vanishY;
}

/// Backdrop slot 0E.
// @orig 1010:1154 perspective_backdrop_get_eye_distance
pub fn getEyeDistance(g: *Game, bd: *Backdrop) i16 {
    _ = g;
    return bd.eyeDistance;
}

/// Backdrop slot 0F.
// @orig 1010:116a perspective_backdrop_get_axis_x
pub fn getAxisX(g: *Game, bd: *Backdrop) i16 {
    _ = g;
    return bd.axisX;
}

/// Backdrop slot 12.
// @orig 1010:1180 perspective_backdrop_get_view3d_z
pub fn getView3dZ(g: *Game, bd: *Backdrop) i16 {
    _ = g;
    return bd.view3dZ;
}

/// Backdrop slot 17: `create` plus the occupancy grid (`operator new(0x10)`
/// in the original; null on failure). `cell_shift` is 4.
// @orig 1010:0f18 grid_backdrop_create_with_grid
pub fn createWithGrid(g: *Game, bd: *Backdrop, cell_shift: i16) ?*Backdrop {
    _ = createBase(g, bd);
    if (g.scene_arena.allocator().create(world.Grid)) |gr| {
        gr.* = .{};
        bd.grid = grid_unit.init(g, gr, bd.bgWidth, bd.bgHeight, cell_shift, cell_shift);
    } else |_| {
        bd.grid = null;
    }
    return bd;
}

/// Backdrop slot 18: the object's slot 12 (`setElevation`) with (`bd`, `arg`).
// @orig 1010:ad18 FUN_1010_ad18
pub fn slot18(g: *Game, bd: *Backdrop, obj: *Object, arg: i16) ?*Object {
    return space3d.setElevation(g, obj, bd, arg);
}

// @orig 1010:dfbe backdrop_autoscroll
/// For a scroll-target object at (`x`, `y`), scrolls the view by 20 pixels
/// when it is within 40 pixels of the left/top edge or beyond 500/300
/// (clamped to the background), moves the object by the same amount,
/// redraws what it overlaps and blits the view. True if it scrolled.
pub fn autoscroll(g: *Game, bd: *Backdrop, obj: *Object, x: i16, y: i16) bool {
    if (!position.isScrollTarget(g, obj)) return false;
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
        if (bd.originX +% bd.viewWidth +% 20 > bd.bgWidth) dx = 0;
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
    blitToDc(g, bd);
    return true;
}
