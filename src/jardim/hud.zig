//! Port unit `hud` (module) of JARDIM.EXE. The minimap (walls, the player square, the panel refresh) and the HUD (level, ammo, health, score, lives, the face, the control panel strip).
//!
//! This unit owns no virtual slot: its functions are called directly (the
//! LabyrinthBackdrop's paint, frame and message handler). The window DC the
//! original gets with `GetDC(hwnd)` / `ReleaseDC` and the `SelectPalette` +
//! `RealizePalette` before a `WinGBitBlt` are the platform's: the `hwnd` /
//! `hdc` parameters are dropped (`hdc` of the backdrop's own surface is
//! `bd.surface()`).
//!
//! The minimap's brushes (`g_hBrushMinimapWall` green, `g_hBrushMinimapPlayer`
//! red, created in `labyrinth_backdrop_create` with CreateSolidBrush) are
//! COLORREFs here; FillRect on a palette DIB fills with the colour table's
//! nearest entry (`nearestIndex`).
//!
//! The HUD text colour is COLORREF 0x0000ffff (the original pushes the
//! dwords 0, -1): yellow, although GAME.md says white.

const std = @import("std");
const Game = @import("core/game.zig").Game;
const world = @import("core/world.zig");
const Backdrop = world.Backdrop;
const platform = @import("../platform/platform.zig");
const dib = @import("dib.zig");
const panels = @import("panels.zig");
const position = @import("behaviour/position.zig");
const render = @import("behaviour/render.zig");
const visibility = @import("behaviour/visibility.zig");

/// `g_hBrushMinimapWall`: CreateSolidBrush(0xff00).
const wall_color: u32 = 0x00ff00;
/// `g_hBrushMinimapPlayer`: CreateSolidBrush(0xff).
const player_color: u32 = 0x0000ff;

/// The minimap's rectangle (x 0x201, y 0x2a, 0x72 x 0xa0).
const map_x: i16 = 0x201;
const map_y: i16 = 0x2a;
const map_w: i16 = 0x72;
const map_h: i16 = 0xa0;

/// The HUD numbers' box (0xe1, 0x19a, 0x172 x 0x14).
const hud_x: i16 = 0xe1;
const hud_y: i16 = 0x19a;
const hud_w: i16 = 0x172;
const hud_h: i16 = 0x14;

/// GDI's colour match for a DIB: the nearest table entry (lowest index on ties).
fn nearestIndex(colors: *const [256]platform.RgbQuad, color: u32) u8 {
    const r: i32 = @intCast(color & 0xff);
    const g: i32 = @intCast(color >> 8 & 0xff);
    const b: i32 = @intCast(color >> 16 & 0xff);
    var best: u8 = 0;
    var best_d: i32 = std.math.maxInt(i32);
    for (colors, 0..) |q, i| {
        const dr = r - q.red;
        const dg = g - q.green;
        const db = b - q.blue;
        const d = dr * dr + dg * dg + db * db;
        if (d < best_d) {
            best_d = d;
            best = @intCast(i);
        }
    }
    return best;
}

// @orig 1028:075a labyrinth_fill_rect
/// FillRect(hdc, RECT(left, top, right, bottom), brush): the rectangle
/// [left, right) x [top, bottom) in `target`'s top-down coordinates, clipped
/// to it, in the brush colour's nearest table entry.
pub fn fillRect(target: platform.Surface, color: u32, left: i16, top: i16, right: i16, bottom: i16) void {
    const idx = nearestIndex(target.colors, color);
    const stride = target.stride();
    const h: i32 = target.height;
    const w: i32 = target.width;
    var y: i32 = @max(top, 0);
    const y_end: i32 = @min(bottom, h);
    const x0: i32 = @max(left, 0);
    const x1: i32 = @min(right, w);
    while (y < y_end) : (y += 1) {
        const srow: usize = @intCast(if (target.bottom_up) h - 1 - y else y);
        var x = x0;
        while (x < x1) : (x += 1) {
            const i = srow * stride + @as(usize, @intCast(x));
            if (i < target.pixels.len) target.pixels[i] = idx;
        }
    }
}

// @orig 1028:07d8 labyrinth_minimap_player
/// The player marker: a 4 x 4 square centred on (x / 16 + 0x201, 0xca - y / 16)
/// (`x`, `y` the player's longs), drawn on the window.
pub fn minimapPlayer(g: *Game, bd: *Backdrop, x: i32, y: i32) void {
    const scr = g.plat.screen();
    const target: platform.Surface = .{
        .pixels = &scr.pixels,
        .width = platform.screen_width,
        .height = platform.screen_height,
        .bottom_up = false,
        .colors = &bd.bmiColors,
    };
    const px: i16 = @truncate(@divTrunc(x, 16) +% 0x201);
    const dy: i16 = 0 -% @as(i16, @truncate(@divTrunc(y, 16)));
    fillRect(target, player_color, px -% 2, dy +% 200, px +% 2, dy +% 0xcc);
}

// @orig 1028:0851 labyrinth_minimap_walls
/// The wall map into the backdrop's surface: for fileRow 0..79 and col
/// 0..56, a non-zero `wallRows[79 - fileRow][col]` is one pixel at
/// (col * 2 + 0x201, fileRow * 2 + 0x2a).
pub fn minimapWalls(bd: *Backdrop) void {
    const target = bd.surface();
    var file_row: i16 = 0;
    while (file_row < 0x50) : (file_row += 1) {
        var col: i16 = 0;
        while (col < 0x39) : (col += 1) {
            if (bd.wallRows[@intCast(79 - file_row)][@intCast(col)] == 0) continue;
            const row_px: i16 = @truncate(@divTrunc(@as(i32, file_row) << 5, 16));
            const col_px: i16 = @truncate(@divTrunc(@as(i32, col) << 5, 16));
            fillRect(target, wall_color, col_px +% 0x201, row_px +% 0x2a, col_px +% 0x202, row_px +% 0x2b);
        }
    }
}

// @orig 1028:111a labyrinth_present_minimap
/// WinGBitBlt of the minimap rectangle from the backdrop to the window.
pub fn presentMinimap(g: *Game, bd: *Backdrop) void {
    g.plat.wingBitBlt(map_x, map_y, map_w, map_h, bd.surface(), map_x, map_y);
}

// @orig 1028:257f labyrinth_refresh_map_panel
/// The minimap after a door opened: the walls into the surface, the window's
/// palette realized, the rectangle presented, the player marker on top.
pub fn refreshMapPanel(g: *Game, bd: *Backdrop) void {
    minimapWalls(bd);
    _ = g.plat.realizePalette(&bd.bmiColors);
    presentMinimap(g, bd);
    minimapPlayer(g, bd, bd.playerX, bd.playerY);
}

// @orig 1028:11b3 labyrinth_draw_hud_strip
/// The strip below the view: its background restored from the picture, the
/// control panel drawn (SceneObject's `scene_object_draw`: slot drawDirtyTo
/// into the backdrop), its inventory (slot 9), then the HUD numbers.
pub fn drawHudStrip(g: *Game, bd: *Backdrop) void {
    const y = bd.originY +% bd.viewY +% bd.viewH;
    if (bd.background) |bg| {
        if (bd.pixels.len != 0) {
            _ = dib.copyRect(&bd.bmiHeader, bd.pixels, bd.originX, y, bg.bits, &bg.header, bd.originX, y, bd.viewWidth, bd.viewHeight -% bd.viewY -% bd.viewH, g.fixes) catch |e|
                std.debug.panic("jardim hud: strip restore left its buffers ({s})", .{@errorName(e)});
        }
    }
    const cp = g.controlPanel.?;
    render.drawDirtyTo(g, cp, &bd.bmiHeader, bd.pixels);
    _ = panels.drawInventory(g, cp, bd);
    drawHud(g, bd);
}

// @orig 1028:12ce labyrinth_present_hud_strip
/// `drawHudStrip`, then the strip (0, viewY + viewH, width x the rest) to the window.
pub fn presentHudStrip(g: *Game, bd: *Backdrop) void {
    drawHudStrip(g, bd);
    g.plat.wingBitBlt(0, bd.viewY +% bd.viewH, bd.viewWidth, bd.viewHeight -% bd.viewY -% bd.viewH, bd.surface(), bd.originX, bd.originY +% bd.viewY +% bd.viewH);
}

// @orig 1028:438d labyrinth_present_hud
/// The HUD numbers' box from the surface to the window, then the face's
/// `blitToDc` (slot 0x22).
pub fn presentHud(g: *Game, bd: *Backdrop) void {
    g.plat.wingBitBlt(hud_x, hud_y, hud_w, hud_h, bd.surface(), hud_x, hud_y);
    visibility.blitToDc(g, bd.face.?, bd);
}

/// `sprintf(text, "%N.Nd", value)`: the precision pads the digits with
/// zeros to `prec` (a negative value: "-" then the digits), then `suffix`,
/// and the terminating NUL; the bytes after it keep the longer texts' tails
/// (the sprites' clip reads them).
fn formatInt(buf: *[16]u8, value: i16, comptime prec: usize, suffix: []const u8) []const u8 {
    const sign: []const u8 = if (value < 0) "-" else "";
    const text = std.fmt.bufPrint(buf[0 .. buf.len - 1], "{s}{d:0>" ++ std.fmt.comptimePrint("{d}", .{prec}) ++ "}{s}", .{ sign, @abs(value), suffix }) catch unreachable;
    buf[text.len] = 0;
    return text;
}

// @orig 1028:43e9 labyrinth_draw_hud
/// The numbers into the surface: the box restored from the picture, then
/// yellow transparent text at y 0x19a: level `%2.2d` at 0xe1, ammo `%3.3d`
/// at 0x134, health `%3.3d%%` at 0x188, score `%3.3d` at 0x1ed, lives
/// `%2.2d` at 0x246. The face's frame is `N + health / (-100 / N) - 1` (N
/// the strip's frame count, floored at 0) up to 100 health, 0 above; it is
/// erased and drawn (slots 0x1E, 0x1B).
pub fn drawHud(g: *Game, bd: *Backdrop) void {
    if (bd.background) |bg| {
        if (bd.pixels.len != 0) {
            _ = dib.copyRect(&bd.bmiHeader, bd.pixels, hud_x, hud_y, bg.bits, &bg.header, hud_x, hud_y, hud_w, hud_h, g.fixes) catch |e|
                std.debug.panic("jardim hud: numbers box restore left its buffers ({s})", .{@errorName(e)});
        }
    }
    const style: platform.TextStyle = .{ .color = 0xffff, .bk_mode = .transparent };
    const buf = &g.hudTextBuffer;
    const surf = bd.surface();
    _ = g.plat.textOut(surf, style, 0xe1, hud_y, formatInt(buf, bd.level, 2, ""));
    _ = g.plat.textOut(surf, style, 0x134, hud_y, formatInt(buf, bd.ammo, 3, ""));
    _ = g.plat.textOut(surf, style, 0x188, hud_y, formatInt(buf, bd.health, 3, "%"));
    _ = g.plat.textOut(surf, style, 0x1ed, hud_y, formatInt(buf, bd.score, 3, ""));
    _ = g.plat.textOut(surf, style, 0x246, hud_y, formatInt(buf, bd.lives, 2, ""));
    const face = bd.face.?;
    if (bd.health > 100) {
        face.curFrame = 0;
    } else {
        const n = position.curStrip(face).count;
        const q: i16 = @truncate(@divTrunc(@as(i32, -100), n));
        var frame: i16 = n +% (@divTrunc(bd.health, q) -% 1);
        if (frame < 0) frame = 0;
        face.curFrame = frame;
    }
    render.erase(g, face, bd);
    render.draw(g, face, bd);
}

test "formatInt is sprintf's %N.Nd" {
    var b: [16]u8 = undefined;
    try std.testing.expectEqualStrings("07", formatInt(&b, 7, 2, ""));
    try std.testing.expectEqualStrings("100%", formatInt(&b, 100, 3, "%"));
    try std.testing.expectEqualStrings("005%", formatInt(&b, 5, 3, "%"));
    try std.testing.expectEqualStrings("-005", formatInt(&b, -5, 3, ""));
    try std.testing.expectEqualStrings("-32768", formatInt(&b, std.math.minInt(i16), 3, ""));
    // A shorter text leaves the longer one's tail after its NUL.
    _ = formatInt(&b, 1234, 3, "");
    _ = formatInt(&b, 3, 2, "");
    try std.testing.expectEqualSlices(u8, &.{ '0', '3', 0, '4' }, b[0..4]);
}

test "fillRect clips and picks the nearest colour" {
    var colors: [256]platform.RgbQuad = @splat(.{});
    colors[5] = .{ .green = 255 };
    var px: [8 * 4]u8 = @splat(0);
    const s: platform.Surface = .{ .pixels = &px, .width = 8, .height = 4, .bottom_up = true, .colors = &colors };
    fillRect(s, wall_color, -1, 0, 2, 1);
    // top-down row 0 is the last stored row
    try std.testing.expectEqual(@as(u8, 5), px[3 * 8]);
    try std.testing.expectEqual(@as(u8, 5), px[3 * 8 + 1]);
    try std.testing.expectEqual(@as(u8, 0), px[3 * 8 + 2]);
    try std.testing.expectEqual(@as(u8, 0), px[2 * 8]);
}
