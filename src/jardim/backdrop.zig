//! Port unit `backdrop` (module) of JARDIM.EXE. Backdrop (WinG surface, palette, background, autoscroll) and its BackdropVtbl defaults.
//!
//! Only the LabyrinthBackdrop is instantiated (Backdrop + LabyrinthBackdrop
//! flattened in `world.Backdrop`); its base is NOITE's Backdrop (one WinG
//! bitmap, no grid), built as TIRO's: one top-down pixel buffer (`pixels`,
//! `bgWidth` x `bgHeight`, rows padded to 4) allocated from `g.gpa` and freed
//! by `dtor`. The DC, the logical palette and the old-bitmap handle have no
//! X
//! caller) are absorbed by their callers.

const platform = @import("../platform/platform.zig");
const Game = @import("core/game.zig").Game;
const object = @import("core/object.zig");
const Object = object.Object;
const world = @import("core/world.zig");
const Backdrop = world.Backdrop;
const dib = @import("dib.zig");
const position = @import("behaviour/position.zig");
const movement = @import("behaviour/movement.zig");
const visibility = @import("behaviour/visibility.zig");

/// The 256 entries of the Win16 `LOGPALETTE256`.
pub const LogPalette = [256]platform.PaletteEntry;

/// Latin-1, as in the original's data segment (10c0:480e, 4834).
const msg_fatal_caption = "Erro Fatal!!";
const msg_cannot_open = "N\xe3o foi poss\xedvel abrir o arquivo: %s";

// @orig 1030:052f backdrop_init_dib_header
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

// @orig 1030:064e backdrop_set_static_colors
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

// @orig 1030:0741 backdrop_set_dib_colors
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

// @orig 10c0:1794 backdrop_blit_to_dc
/// Copies the view (`viewWidth` x `viewHeight` at the origin) to the window
/// (`hdc` dropped; no palette realize).
pub fn blitToDc(g: *Game, bd: *const Backdrop) void {
    g.plat.wingBitBlt(0, 0, bd.viewWidth, bd.viewHeight, bd.surface(), bd.originX, bd.originY);
}

// @orig 10c0:49be backdrop_clear
/// PatBlt(BLACKNESS) over the whole bitmap.
pub fn clear(bd: *Backdrop) void {
    @memset(bd.pixels, 0);
}

// @orig 10c0:49f6 backdrop_draw_background
/// Copies the whole background picture into the bitmap.
pub fn drawBackground(g: *Game, bd: *Backdrop) dib.Error!void {
    const bg = bd.background orelse return;
    _ = try dib.copy(&bd.bmiHeader, bd.pixels, 0, 0, bg.bits, &bg.header, g.fixes);
}

// @orig 10c0:432c backdrop_restore_background
/// The same body as `drawBackground`.
pub fn restoreBackground(g: *Game, bd: *Backdrop) dib.Error!void {
    const bg = bd.background orelse return;
    _ = try dib.copy(&bd.bmiHeader, bd.pixels, 0, 0, bg.bits, &bg.header, g.fixes);
}

// @orig 1030:03e4 backdrop_create
/// BackdropVtbl slot 00 (hwnd dropped), called by the LabyrinthBackdrop's
/// create: builds the palette (static colours, then the picture's 10-245)
/// and the one WinG bitmap, clears it, shows it in the window and draws the
/// background. There are no failure checks in the original; a bitmap that
/// cannot be allocated returns null here. GetDC/ReleaseDC, CreatePalette,
/// WinGCreateDC and the old-bitmap handle have no counterpart.
pub fn create(g: *Game, bd: *Backdrop) ?*Backdrop {
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

// @orig 10c0:41de backdrop_ctor
/// Base constructor (the caller, the LabyrinthBackdrop's ctor, allocates
/// `bd`): loads the background bitmap `path` and records the view
/// rectangle. If the bitmap cannot be opened the original shows the box and
/// then reads the null header (taken as 0, as TIRO's).
pub fn ctor(g: *Game, bd: *Backdrop, path: []const u8, origin_x: i16, origin_y: i16, view_w: i16, view_h: i16) *Backdrop {
    bd.background = dib.loadDib(g.gpa, g.plat, g.fixes, path);
    if (bd.background == null) position.messageBoxPrintf(g, msg_fatal_caption, msg_cannot_open, path);
    bd.bgWidth = if (bd.background) |bg| @truncate(bg.header.biWidth) else 0;
    bd.bgHeight = if (bd.background) |bg| @truncate(bg.header.biHeight) else 0;
    bd.originX = origin_x;
    bd.originY = origin_y;
    bd.viewWidth = view_w;
    bd.viewHeight = view_h;
    bd.sceneList = null;
    return bd;
}

// @orig 10c0:42ae backdrop_dtor
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

// @orig 10c0:68ea backdrop_scalar_dtor
/// Scalar deleting destructor: `dtor`; freeing the object itself
/// (`flags & 1`) is up to whoever allocated it.
pub fn scalarDtor(g: *Game, bd: *Backdrop, flags: u16) *Backdrop {
    _ = flags;
    dtor(g, bd);
    return bd;
}

// @orig 1030:0809 backdrop_autoscroll
/// For a scroll-target object (only the Player; JARDIM never moves it, so
/// this never scrolls) at (`x`, `y`), scrolls the view by 20 pixels when it
/// is within 40 pixels of the left/top edge or beyond 500/300 (clamped to
/// the background), moves the object by the same amount, redraws what it
/// overlaps and blits the view. True if it scrolled. (`hdc` dropped; the
/// slot 07 call is the absorbed default, which does nothing.)
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
    movement.placeAt(g, obj, obj.x +% dx, obj.y +% dy, bd);
    visibility.redrawOverlapping(g, obj, bd, 1);
    blitToDc(g, bd);
    return true;
}
