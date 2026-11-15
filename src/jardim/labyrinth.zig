//! Port unit `labyrinth` (module) of JARDIM.EXE. LabyrinthBackdrop: ctor, create (BackdropVtbl slot 00: tables, map, start, timer 1), paint, a frame (sky and floor, walls, sprites, hands, HUD), blit to the window.
//!
//! The backdrop is `world.Backdrop` (Backdrop + LabyrinthBackdrop flattened); the vtable is the
//! port's dispatch (slot 00 is `create`, slot 17 `labyrinth_input.handleMessage`). hwnd and hdc
//! parameters are dropped; GetDC/ReleaseDC have no counterpart, SelectPalette + RealizePalette is
//! `plat.realizePalette`. The minimap's pens and brushes (`g_hPen*`, `g_hBrush*`, created by
//! `create`) have no counterpart (the colours are `hud`'s).

const std = @import("std");
const Game = @import("core/game.zig").Game;
const object = @import("core/object.zig");
const Object = object.Object;
const world = @import("core/world.zig");
const Backdrop = world.Backdrop;
const SpriteQueue = world.SpriteQueue;
const backdrop = @import("backdrop.zig");
const dib = @import("dib.zig");
const hud = @import("hud.zig");
const labmap = @import("labmap.zig");
const panels = @import("panels.zig");
const raycast = @import("raycast.zig");
const sprites = @import("sprites.zig");
const tables = @import("tables.zig");
const render = @import("behaviour/render.zig");
const wolf = @import("wolf.zig");
const enemies = @import("enemies.zig");

// @orig 1028:0dfb labyrinth_backdrop_ctor
/// The base constructor on `bmpName` (origin 0,0, view 640 x 480), the vtable, and the state
/// carried across phases (`g_carryHealth` ...). The caller allocates `bd`.
pub fn ctor(g: *Game, bd: *Backdrop, bmp_name: []const u8) *Backdrop {
    _ = backdrop.ctor(g, bd, bmp_name, 0, 0, 0x280, 0x1e0);
    bd.active = 0;
    bd.moveFlag = 0;
    bd.floorScrollX = 0;
    bd.skyScrollX = 0;
    bd.floorScrollY = 0;
    bd.moveRamp = 0;
    bd.moveSpeed = 0x10;
    bd.shotInFlight = 0;
    bd.health = g.carryHealth;
    bd.lives = g.carryLives;
    bd.ammo = g.carryAmmo;
    bd.score = g.carryScore;
    bd.level = g.carryLevel;
    return bd;
}

// @orig 1028:2191 labyrinth_backdrop_create
/// LabyrinthBackdropVtbl slot 00 create (labyrinth_backdrop_create; hwnd dropped): the tables, the map, the start, timer 1.
pub fn create(g: *Game, bd: *Backdrop) *Backdrop {
    if (bd.active != 0) return bd;
    if (g.startTickPending != 0) {
        g.startTickPending = 0;
        g.startTick = g.plat.ticks();
    }
    bd.velY = 0;
    bd.velX = 0;
    labmap.allocMapRows(bd);
    tables.build(g) catch std.debug.panic("jardim labyrinth: out of memory building the tables", .{});
    _ = labmap.loadMap(g, bd, bd.scene.?.mapFile);
    bd.playerX = g.startX;
    bd.startX = g.startX;
    bd.playerY = g.startY;
    bd.startY = g.startY;
    bd.viewAngle = 0x1e0;
    bd.secAt = @truncate(@as(u32, @bitCast(bd.viewAngle)));
    bd.cscAt = @truncate(@as(u32, @bitCast(bd.viewAngle)));
    bd.floorScrollX = 0;
    bd.skyScrollX = 0;
    bd.floorScrollY = 0;
    _ = backdrop.create(g, bd);
    bd.viewX = 0x14;
    bd.viewY = 0x2a;
    bd.viewW = 0x1e0;
    bd.viewH = 300;
    bd.viewBottom = bd.viewY +% bd.viewH;
    bd.viewRight = bd.viewX +% bd.viewW;
    bd.viewHalfH = @divTrunc(bd.viewH, 2);
    bd.horizonY = bd.viewY +% bd.viewHalfH;
    const q = g.local().create(SpriteQueue) catch std.debug.panic("jardim labyrinth: out of memory for the sprite queue", .{});
    q.* = .{};
    bd.spriteQueue = sprites.ctor(q);
    g.setSystemTimer(1, 0x37);
    // Not in the original: the Corrigida's motion timer (`wolf.zig`).
    if (g.fixes.jardim_smooth_movement) wolf.start(g);
    return bd;
}

/// One opaque rectangle of the background picture into the surface, at the same place
/// unless the source differs (dib_copy_rect; the original ignores a missing bitmap).
fn copyBg(g: *Game, bd: *Backdrop, dx: i16, dy: i16, sx: i16, sy: i16, w: i16, h: i16) void {
    const bg = bd.background orelse return;
    if (bd.pixels.len == 0) return;
    _ = dib.copyRect(&bd.bmiHeader, bd.pixels, dx, dy, bg.bits, &bg.header, sx, sy, w, h, g.fixes) catch |e|
        std.debug.panic("jardim labyrinth: sky and floor left their buffers ({s})", .{@errorName(e)});
}

// @orig 1028:134f labyrinth_draw_sky_floor
/// The view's background from the picture, with the scrolls as cyclic shifts: the sky (rows
/// viewY..horizonY) shifted by `skyScrollX`; the floor (horizonY..viewBottom) by `floorScrollX`
/// and `floorScrollY`, in 1, 2 or 4 pieces. All three 0: one copy of the whole view.
pub fn drawSkyFloor(g: *Game, bd: *Backdrop) void {
    const sx = bd.skyScrollX;
    const fx = bd.floorScrollX;
    const fy = bd.floorScrollY;
    if (sx == 0 and fx == 0 and fy == 0) {
        copyBg(g, bd, bd.viewX, bd.viewY, bd.viewX, bd.viewY, bd.viewW, bd.viewH);
        return;
    }
    if (sx == 0) {
        copyBg(g, bd, bd.viewX, bd.viewY, bd.viewX, bd.viewY, bd.viewW, bd.viewHalfH);
    } else {
        copyBg(g, bd, bd.viewX, bd.viewY, sx +% bd.viewX, bd.viewY, bd.viewW -% sx, bd.viewHalfH);
        copyBg(g, bd, bd.viewRight -% sx, bd.viewY, bd.viewX, bd.viewY, sx, bd.viewHalfH);
    }
    // piece A: the top left of the floor; B: the wrapped columns; C: the wrapped rows; D: both
    copyBg(g, bd, bd.viewX, bd.horizonY, fx +% bd.viewX, fy +% bd.horizonY, bd.viewW -% fx, bd.viewHalfH -% fy);
    if (fx != 0) copyBg(g, bd, bd.viewRight -% fx, bd.horizonY, bd.viewX, fy +% bd.horizonY, fx, bd.viewHalfH -% fy);
    if (fy != 0) copyBg(g, bd, bd.viewX, bd.viewBottom -% fy, fx +% bd.viewX, bd.horizonY, bd.viewW -% fx, fy);
    if (fx != 0 and fy != 0) copyBg(g, bd, bd.viewRight -% fx, bd.viewBottom -% fy, bd.viewX, bd.horizonY, fx, fy);
}

// @orig 1028:114e labyrinth_present_view
/// WinGBitBlt of the 3-D view rectangle from the surface to the window.
pub fn presentView(g: *Game, bd: *Backdrop) void {
    g.plat.wingBitBlt(bd.viewX, bd.viewY, bd.viewW, bd.viewH, bd.surface(), bd.originX +% bd.viewX, bd.originY +% bd.viewY);
}

// @orig 1028:2406 labyrinth_paint
/// WM_PAINT of the whole page (only when active): background, view, minimap walls, sprites,
/// hands, the control panel and its inventory, the HUD.
pub fn paint(g: *Game, bd: *Backdrop) void {
    if (bd.active == 0) return;
    backdrop.restoreBackground(g, bd) catch |e|
        std.debug.panic("jardim labyrinth: paint left its buffers ({s})", .{@errorName(e)});
    raycast.renderView(g, bd, bd.playerX, bd.playerY, bd.viewAngle);
    hud.minimapWalls(bd);
    sprites.flush(g, bd.spriteQueue.?, bd);
    render.draw(g, bd.hands.?, bd);
    enemies.drawOverlay(g, bd); // Not in the original: the fair enemies' hit border.
    if (g.controlPanel) |cp| {
        render.drawDirtyTo(g, cp, &bd.bmiHeader, bd.pixels);
        _ = panels.drawInventory(g, cp, bd);
    }
    hud.drawHud(g, bd);
}

// @orig 1028:251d labyrinth_blit_to_dc
/// The whole surface to the window (palette realized), then the player's minimap marker.
pub fn blitToDc(g: *Game, bd: *Backdrop) void {
    _ = g.plat.realizePalette(&bd.bmiColors);
    backdrop.blitToDc(g, bd);
    hud.minimapPlayer(g, bd, bd.playerX, bd.playerY);
}

// @orig 1028:4655 labyrinth_render_frame
/// A frame without moving the player (a turn, a punch, a door, the 55 ms idle tick): sky and
/// floor, walls, `carried` (the object the shot displaced from its cell, may be null) queued
/// at its depth, sprites, hands, then the view and the HUD to the window; a life lost during
/// the frame runs the scene's `onLifeLost`.
pub fn renderFrame(g: *Game, bd: *Backdrop, carried: ?*Object) void {
    // Not in the original: the planner's probe build (`enemies.probe`) draws nothing with the
    // fair enemies, whose frames change no state.
    if (enemies.probe and enemies.active(g)) return;
    const lives_before = bd.lives;
    bd.moveFlag = 0;
    drawSkyFloor(g, bd);
    raycast.renderView(g, bd, bd.playerX, bd.playerY, bd.viewAngle);
    if (carried) |obj| {
        const diff: i32 = @as(i32, obj.worldY) -% bd.playerY;
        const csc: i32 = g.tables.trig[6][bd.cscAt];
        const depth: i32 = diff *% csc;
        _ = sprites.insert(bd.spriteQueue.?, -1, -1, @truncate(bd.viewAngle), @truncate(depth >> 16), obj);
    }
    sprites.flush(g, bd.spriteQueue.?, bd);
    render.draw(g, bd.hands.?, bd);
    enemies.drawOverlay(g, bd); // Not in the original: the fair enemies' hit border.
    _ = g.plat.realizePalette(&bd.bmiColors);
    presentView(g, bd);
    hud.drawHud(g, bd);
    hud.presentHud(g, bd);
    if (bd.lives != lives_before) bd.scene.?.onLifeLost(g);
}
