//! Port unit `hud` (module) of SALGIN.EXE. What is drawn around the fight: the PORRADA banner, the energy bar and its tiles (energy_bar_add_mark), the round clock (draw, blit), the arena band redraw.
//!
//! This unit owns no virtual slot: its functions are called directly (the
//! scene handler, `game.onCreate`). The window DC the original gets with
//! `GetDC(hwnd)` / `ReleaseDC` and the `SelectPalette` + `RealizePalette`
//! before a `WinGBitBlt` are the platform's: the `hwnd` / `hdc` parameters
//! are dropped.

const std = @import("std");
const Game = @import("core/game.zig").Game;
const object = @import("core/object.zig");
const Object = object.Object;
const world = @import("core/world.zig");
const Backdrop = world.Backdrop;
const Scene = world.Scene;
const platform = @import("../platform/platform.zig");
const dib = @import("dib.zig");
const object_create = @import("object_create.zig");
const occupancy = @import("behaviour/occupancy.zig");
const render = @import("behaviour/render.zig");
const visibility = @import("behaviour/visibility.zig");

/// `salgin_redraw_arena`'s band: y 0x8c, 640 x 0x127.
const band_y: i16 = 0x8c;
const band_w: i16 = 0x280;
const band_h: i16 = 0x127;

// @orig 1068:0119 salgin_create_banner
/// The PORRADA title: `g_banner` = Banner at (200, 200), one strip
/// (porrada.bmp, 232 x 42, 1 frame), hit box 0, 0 and strip 0's size, timer
/// 10 at 0x44c ms, step 0x20 x 0, visible. Attached (`scene_object_attach`
/// is `occupancy.attach`: the Actor2D part only clears `linked`, which
/// attach leaves null), `curStrip` = `curFrame` = 0, one blit to the window.
/// A failed allocation stores NULL in the original and dereferences it
/// next; here it is the error.
pub fn createBanner(g: *Game, bd: *Backdrop) object_create.Error!void {
    const obj = g.local().create(Object) catch {
        g.banner = null;
        return error.OutOfMemory;
    };
    obj.* = .{ .kind = .banner };
    try object_create.bannerCtor(g, obj, 200, 200, 1, &g.bannerStripFiles, &g.bannerStripFrames, &g.bannerStripWidths, &g.bannerStripHeights, 0, 0, g.bannerStripWidths[0], g.bannerStripHeights[0], 10, 0x44c, 0x20, 0, 1, 0, true);
    g.banner = obj;
    _ = occupancy.attach(g, obj, bd);
    obj.curStrip = 0;
    obj.curFrame = 0;
    visibility.blitToDc(g, obj, bd);
}

// @orig 1068:01ea salgin_create_energy_bar
/// `g_energyBar` = EnergyBar at (0x113, 0x14), one strip (energia.bmp,
/// 16 x 19, 1 frame), hit box 0, 0 and strip 0's size, timer 10 at 0x44c ms,
/// step 0x20 x 0, not visible. Attached, `curStrip` = `curFrame` = 0 (no
/// blit); `leftEdge` 0x122, `rightEdge` 0x14d, both energies 91.
pub fn createEnergyBar(g: *Game, bd: *Backdrop) object_create.Error!void {
    const obj = g.local().create(Object) catch {
        g.energyBar = null;
        return error.OutOfMemory;
    };
    obj.* = .{ .kind = .energy_bar };
    try object_create.energyBarCtor(g, obj, 0x113, 0x14, 1, &g.energyStripFiles, &g.energyStripFrames, &g.energyStripWidths, &g.energyStripHeights, 0, 0, g.energyStripWidths[0], g.energyStripHeights[0], 10, 0x44c, 0x20, 0, 0, 0, true);
    g.energyBar = obj;
    _ = occupancy.attach(g, obj, bd);
    obj.curStrip = 0;
    obj.curFrame = 0;
    const bar = &obj.energyBar;
    bar.rightEdge = 0x14d;
    bar.leftEdge = 0x122;
    bar.opponentEnergy = 0x5b;
    bar.playerEnergy = bar.opponentEnergy;
}

// @orig 1068:02d1 energy_bar_add_mark
/// One more energia.bmp tile (the bar is never erased): side 0 (the
/// opponent lost) `rightEdge += 16` and the tile goes there, any other side
/// (the player lost) `leftEdge -= 16`. The tile's `mover.targetX`, `x` and
/// `nextX` are the edge, `y`, `mover.targetY` and `nextY` 0x14; it is drawn
/// into the backdrop (slot `draw`) and blitted to the window (slot
/// `blitToDc`). `this` is unused (the original works on `g_energyBar`).
pub fn addMark(g: *Game, side: i16, bd: *Backdrop) void {
    const obj = g.energyBar.?;
    const w = g.energyStripWidths[0];
    const bar = &obj.energyBar;
    if (side == 0) {
        bar.rightEdge +%= w;
        obj.mover.targetX = bar.rightEdge;
    } else {
        bar.leftEdge -%= w;
        obj.mover.targetX = bar.leftEdge;
    }
    obj.x = obj.mover.targetX;
    obj.nextX = obj.x;
    obj.y = 0x14;
    obj.mover.targetY = obj.y;
    obj.nextY = obj.mover.targetY;
    render.draw(g, obj, bd);
    visibility.blitToDc(g, obj, bd);
}

// @orig 1068:0c81 salgin_redraw_arena
/// Repaints the fighting band (0, 0x8c, 640 x 295): the background's band is
/// copied over the backdrop's (key `g_unk00A8`), the opponent then the
/// fighter (in front) are drawn, and the band is blitted to the window.
/// The banner and the energy bar are not redrawn (the banner, y 200, lies
/// in the band and is overwritten: BUGS.md S9). With `salgin_banner_shown`
/// the banner is drawn after the restore, behind the fighters, for the
/// round's first 2 s: the clock is still 90 or 89 (it loses one a second).
pub fn redrawArena(g: *Game, scene: *Scene) void {
    const bd = scene.backdrop.?;
    if (bd.background) |bg| {
        if (bd.pixels.len != 0) {
            _ = dib.copyTransparent(&bd.bmiHeader, bd.pixels, 0, band_y, bg.bits, &bg.header, 0, band_y, band_w, band_h, g.unk00A8) catch |e|
                std.debug.panic("salgin hud: arena band restore left its buffers ({s})", .{@errorName(e)});
        }
    }
    if (g.fixes.salgin_banner_shown and scene.clock >= 89) {
        if (g.banner) |b| render.draw(g, b, bd);
    }
    render.draw(g, g.opponent.?, bd);
    render.draw(g, g.fighter.?, bd);
    g.plat.wingBitBlt(0, band_y, band_w, band_h, bd.surface(), 0, band_y);
}

// @orig 1068:2aad salgin_blit_clock
/// WinGBitBlt of the clock box (0x14 x 0xf at 0x136, 0x16) from the backdrop
/// to the window.
pub fn blitClock(g: *Game, scene: *Scene) void {
    g.plat.wingBitBlt(0x136, 0x16, 0x14, 0xf, scene.backdrop.?.surface(), 0x136, 0x16);
}

// @orig 1068:2afa salgin_draw_clock
/// Restores the clock box (0x136, 0x16, 0x14 x 0xf) from the background onto
/// the backdrop (`dib_copy_rect`, opaque), then `TextOut`s
/// `sprintf("%2.2d", clock)` at (0x136, 0x16) in yellow (COLORREF 0xFFFF),
/// transparent. `%2.2d` is at least two digits (a minus sign before them),
/// so the buffer never holds more than the 6 bytes of a 16-bit value.
pub fn drawClock(g: *Game, scene: *Scene) void {
    const bd = scene.backdrop.?;
    if (bd.background) |bg| {
        if (bd.pixels.len != 0) {
            _ = dib.copyRect(&bd.bmiHeader, bd.pixels, 0x136, 0x16, bg.bits, &bg.header, 0x136, 0x16, 0x14, 0xf, g.fixes) catch |e|
                std.debug.panic("salgin hud: clock box restore left its buffers ({s})", .{@errorName(e)});
        }
    }
    const style: platform.TextStyle = .{ .color = 0xffff, .bk_mode = .transparent };
    var buf: [8]u8 = undefined;
    const text = formatClock(&buf, scene.clock);
    _ = g.plat.textOut(bd.surface(), style, 0x136, 0x16, text);
}

/// `sprintf(text, "%2.2d", clock)`: the precision pads to two digits with
/// zeros (a negative value: "-" then the digits).
fn formatClock(buf: *[8]u8, clock: i16) []const u8 {
    const sign: []const u8 = if (clock < 0) "-" else "";
    return std.fmt.bufPrint(buf, "{s}{d:0>2}", .{ sign, @abs(clock) }) catch unreachable;
}

test "formatClock is sprintf's %2.2d" {
    var b: [8]u8 = undefined;
    try std.testing.expectEqualStrings("90", formatClock(&b, 90));
    try std.testing.expectEqualStrings("05", formatClock(&b, 5));
    try std.testing.expectEqualStrings("00", formatClock(&b, 0));
    try std.testing.expectEqualStrings("-01", formatClock(&b, -1));
    try std.testing.expectEqualStrings("-32768", formatClock(&b, std.math.minInt(i16)));
}
