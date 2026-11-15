//! Port unit `render` (behaviour) of JARDIM.EXE. SceneObject slots 17-1F (dirty rects, overlap, restore background, drawDirtyTo, draw incl. the panel's and its texts, drawClip(To), erase, slot1F), the DC hooks, reset_rects.
//!
//! Virtual-slot dispatchers owned by this unit; each switches on the object
//! kind between the override (Mover / Animation / Exit / Player /
//! ControlPanel) and the SceneObject default (docs/jardim/DESIGN.md "Virtual
//! slots"). TIRO's `render` is the template (same `/Od` code, opaque
//! `dib_copy_rect` in restoreBackground, key `g_unk0010` = `g.spriteKey`);
//! NOITE's supplies the RLE branch of drawDirtyTo/drawClipTo and the
//! virtual addDirtyRect/getStep calls of the Mover's restoreBackground.

const std = @import("std");
const platform = @import("../../platform/platform.zig");
const cstr = @import("../../core/cstr.zig");
const Game = @import("../core/game.zig").Game;
const object = @import("../core/object.zig");
const Object = object.Object;
const BitmapInfoHeader = object.BitmapInfoHeader;
const world = @import("../core/world.zig");
const Backdrop = world.Backdrop;
const dib = @import("../dib.zig");
const panels = @import("../panels.zig");
const position = @import("position.zig");

fn blitFailed(err: dib.Error) noreturn {
    std.debug.panic("jardim render: sprite blit left its buffers ({s})", .{@errorName(err)});
}

/// SceneObject slot 17 addDirtyRect (SceneObject's).
pub fn addDirtyRect(g: *Game, obj: *Object, x: i16, y: i16, w: i16, h: i16) void {
    _ = g;
    soAddDirtyRect(obj, x, y, w, h);
}

// @orig 10c0:35f6 scene_object_add_dirty_rect
fn soAddDirtyRect(obj: *Object, x: i16, y: i16, w: i16, h: i16) void {
    const d = &obj.dirty;
    if (x < d.left) {
        if (w +% x < d.left +% d.right) {
            d.right = d.right +% (d.left -% x);
        } else {
            d.right = w;
        }
        d.left = x;
    } else if (d.left +% d.right < w +% x) {
        d.right = (w -% d.left) +% x;
    }
    if (y < d.top) {
        if (h +% y < d.top +% d.bottom) {
            d.bottom = d.bottom +% (d.top -% y);
        } else {
            d.bottom = h;
        }
        d.top = y;
    } else if (d.top +% d.bottom < h +% y) {
        d.bottom = (h -% d.top) +% y;
    }
}

// @orig 10c0:4ae6 scene_object_reset_rects
/// Dirty and clip rectangles back to the whole current frame.
pub fn resetRects(obj: *Object) void {
    obj.dirty.left = 0;
    obj.clip.left = 0;
    obj.dirty.top = 0;
    obj.clip.top = 0;
    obj.dirty.right = position.width(obj);
    obj.clip.right = obj.dirty.right;
    obj.dirty.bottom = position.height(obj);
    obj.clip.bottom = obj.dirty.bottom;
}

/// SceneObject slot 18 computeOverlap (SceneObject's).
pub fn computeOverlap(g: *Game, obj: *Object, other: *Object) bool {
    _ = g;
    return soComputeOverlap(obj, other);
}

// @orig 1038:10e0 scene_object_compute_overlap
fn soComputeOverlap(obj: *Object, other: *Object) bool {
    const d = &obj.dirty;
    const c = &obj.clip;
    const od = &other.dirty;
    if (obj.x +% d.left +% d.right < other.x) return false;
    if (position.width(other) +% other.x < d.left +% obj.x) return false;
    if (d.top +% d.bottom +% obj.y < other.y) return false;
    if (position.height(other) +% other.y < d.top +% obj.y) return false;

    if (d.left +% obj.x < other.x) {
        od.left = 0;
        c.left = other.x -% obj.x;
    } else {
        od.left = (obj.x -% other.x) +% d.left;
        c.left = d.left;
    }
    if (c.left < 0) c.left = 0;

    if (d.top +% obj.y < other.y) {
        od.top = 0;
        c.top = other.y -% obj.y;
    } else {
        od.top = (obj.y -% other.y) +% d.top;
        c.top = d.top;
    }
    if (c.top < 0) c.top = 0;

    if (obj.x +% d.left +% d.right < position.width(other) +% other.x) {
        od.right = ((obj.x -% other.x) -% od.left) +% d.left +% d.right;
    } else {
        od.right = position.width(other) -% od.left;
    }
    if (position.width(obj) < od.right +% c.left) {
        c.right = position.width(obj) -% c.left;
    } else {
        c.right = od.right;
    }

    if (obj.y +% d.top +% d.bottom < position.height(other) +% other.y) {
        od.bottom = ((obj.y -% other.y) -% od.top) +% d.top +% d.bottom;
    } else {
        od.bottom = position.height(other) -% od.top;
    }
    if (position.height(obj) < od.bottom +% c.top) {
        c.bottom = position.height(obj) -% c.top;
    } else {
        c.bottom = od.bottom;
    }
    return true;
}

/// SceneObject slot 19 restoreBackground: mover_restore_background (portable, player) / SceneObject's.
pub fn restoreBackground(g: *Game, obj: *Object, bd: *Backdrop, flag: i16) void {
    switch (obj.kind) {
        .portable, .player => moverRestoreBackground(g, obj, bd),
        .scene_object, .wall_strip, .exit, .control_panel => soRestoreBackground(g, obj, bd, flag),
    }
}

// @orig 1038:039b scene_object_restore_background
/// JARDIM's is the opaque `dib_copy_rect` (no colour key), as TIRO's.
fn soRestoreBackground(g: *Game, obj: *Object, bd: *Backdrop, flag: i16) void {
    _ = flag;
    const h = position.height(obj);
    const w = position.width(obj);
    const bg = bd.background orelse return;
    if (bd.pixels.len == 0) return;
    _ = dib.copyRect(&bd.bmiHeader, bd.pixels, obj.x, obj.y, bg.bits, &bg.header, obj.x, obj.y, w, h, g.fixes) catch |e| blitFailed(e);
}

// @orig 1038:0435 mover_restore_background
/// The rectangle covering the previous and current position plus one step:
/// marks it dirty (through slot 17), then copies it from the background to
/// the working bitmap with the colour key.
fn moverRestoreBackground(g: *Game, obj: *Object, bd: *Backdrop) void {
    const left = @min(obj.mover.prevX, obj.x);
    const top = @min(obj.mover.prevY, obj.y);
    const sx = position.getStepX(g, obj);
    const w = position.width(obj) +% sx;
    const sy = position.getStepY(g, obj);
    const h = position.height(obj) +% sy;
    addDirtyRect(g, obj, left -% obj.x, top -% obj.y, w, h);
    const bg = bd.background orelse return;
    if (bd.pixels.len == 0) return;
    _ = dib.copyTransparent(&bd.bmiHeader, bd.pixels, left, top, bg.bits, &bg.header, left, top, w, h, g.spriteKey) catch |e| blitFailed(e);
}

/// SceneObject slot 1A drawDirtyTo: mover_draw_dirty_to (portable, player) / SceneObject's.
pub fn drawDirtyTo(g: *Game, obj: *Object, dst_hdr: *const BitmapInfoHeader, dst_bits: []u8) void {
    switch (obj.kind) {
        .portable, .player => moverDrawDirtyTo(g, obj, dst_hdr, dst_bits),
        .scene_object, .wall_strip, .exit, .control_panel => soDrawDirtyTo(g, obj, dst_hdr, dst_bits),
    }
}

// @orig 1038:0896 scene_object_draw_dirty_to
/// The dirty rectangle of the current frame at (x + dirtyX, y + dirtyY); an
/// RLE sprite is drawn whole at (x, y), ignoring the rectangle.
fn soDrawDirtyTo(g: *Game, obj: *Object, dst_hdr: *const BitmapInfoHeader, dst_bits: []u8) void {
    const orient: i16 = @truncate(obj.dibFormatOk);
    if (!position.isRle(g, obj)) {
        const d = obj.dirty;
        const h = orient *% d.bottom;
        const y_src = position.frameSrcY(obj) +% d.top;
        const x_src = position.frameSrcX(obj) +% d.left;
        const src = position.dib(obj) orelse return;
        if (dst_bits.len == 0) return;
        _ = dib.copyTransparent(dst_hdr, dst_bits, d.left +% obj.x, d.top +% obj.y, src.bits, &src.header, x_src, y_src, d.right, h, g.spriteKey) catch |e| blitFailed(e);
    } else {
        const h = orient *% position.height(obj);
        const w = position.width(obj);
        const y_src = position.frameSrcY(obj);
        const x_src = position.frameSrcX(obj);
        const rle: []const u8 = obj.rleBits orelse &.{};
        dib.rleBlitTransparent(dst_hdr, dst_bits, obj.x, obj.y, rle, x_src, y_src, w, h) catch |e| blitFailed(e);
    }
}

// @orig 1038:0a1a mover_draw_dirty_to
/// Mover's override: the whole current frame at (x, y), ignoring the dirty
/// rectangle (and RLE).
fn moverDrawDirtyTo(g: *Game, obj: *Object, dst_hdr: *const BitmapInfoHeader, dst_bits: []u8) void {
    const orient: i16 = @truncate(obj.dibFormatOk);
    const h = orient *% position.height(obj);
    const w = position.width(obj);
    const y_src = position.frameSrcY(obj);
    const x_src = position.frameSrcX(obj);
    const src = position.dib(obj) orelse return;
    if (dst_bits.len == 0) return;
    _ = dib.copyTransparent(dst_hdr, dst_bits, obj.x, obj.y, src.bits, &src.header, x_src, y_src, w, h, g.spriteKey) catch |e| blitFailed(e);
}

/// SceneObject slot 1B draw: exit_draw (exit), player_draw (player), control_panel_draw (control_panel) / SceneObject's.
pub fn draw(g: *Game, obj: *Object, bd: *Backdrop) void {
    switch (obj.kind) {
        .exit => exitDraw(g, obj, bd),
        .player => playerDraw(g, obj, bd),
        .control_panel => controlPanelDraw(g, obj, bd),
        .scene_object, .wall_strip, .portable => soDraw(g, obj, bd),
    }
}

// @orig 10c0:2f5c scene_object_draw
fn soDraw(g: *Game, obj: *Object, bd: *Backdrop) void {
    drawDirtyTo(g, obj, &bd.bmiHeader, bd.pixels);
}

// @orig 10c0:19bc animation_draw
fn animationDraw(g: *Game, obj: *Object, bd: *Backdrop) void {
    drawDirtyTo(g, obj, &bd.bmiHeader, bd.pixels);
}

// @orig 1048:243f player_draw
fn playerDraw(g: *Game, obj: *Object, bd: *Backdrop) void {
    animationDraw(g, obj, bd);
}

// @orig 10c0:2826 exit_draw
fn exitDraw(g: *Game, obj: *Object, bd: *Backdrop) void {
    soDraw(g, obj, bd);
}

// @orig 1078:02be control_panel_draw
/// The frame; the icons first (slot 9) only when open and not sliding; then
/// the message text (JARDIM draws no score or lives).
fn controlPanelDraw(g: *Game, obj: *Object, bd: *Backdrop) void {
    if (obj.panel.isOpen == 0 or obj.anim.running != 0) {
        animationDraw(g, obj, bd);
    } else {
        _ = panels.drawInventory(g, obj, bd);
        animationDraw(g, obj, bd);
    }
    controlPanelDrawTexts(g, obj, bd);
}

// @orig 1078:04f9 control_panel_draw_texts
/// The message in the panel's text colour, transparent background, at its x
/// (centred when -1) and 480 - visible height.
fn controlPanelDrawTexts(g: *Game, obj: *Object, bd: *Backdrop) void {
    const p = &obj.panel;
    if (p.text[0] == 0) return;
    const style: platform.TextStyle = .{ .color = p.textColor, .bk_mode = .transparent };
    const text = cstr.slice(&p.text);
    var x: i16 = p.textX;
    if (p.textX == -1) {
        const w: i16 = @bitCast(@as(u16, @truncate(g.plat.textExtent(text))));
        x = @bitCast(@as(u16, @bitCast(640 -% w)) >> 1);
    }
    const y = 0x1e0 -% panels.getVisibleHeight(g, obj);
    _ = g.plat.textOut(bd.surface(), style, x, y, text);
}

/// SceneObject slot 1C drawClipTo (SceneObject's).
pub fn drawClipTo(g: *Game, obj: *Object, dst_hdr: *const BitmapInfoHeader, dst_bits: []u8) void {
    soDrawClipTo(g, obj, dst_hdr, dst_bits);
}

// @orig 1038:068d scene_object_draw_clip_to
/// The clip rectangle of the current frame at (x + clipX, y + clipY), plain or RLE.
fn soDrawClipTo(g: *Game, obj: *Object, dst_hdr: *const BitmapInfoHeader, dst_bits: []u8) void {
    const c = obj.clip;
    const orient: i16 = @truncate(obj.dibFormatOk);
    const h = orient *% c.bottom;
    const y_src = position.frameSrcY(obj) +% c.top;
    const x_src = position.frameSrcX(obj) +% c.left;
    if (!position.isRle(g, obj)) {
        const src = position.dib(obj) orelse return;
        if (dst_bits.len == 0) return;
        _ = dib.copyTransparent(dst_hdr, dst_bits, c.left +% obj.x, c.top +% obj.y, src.bits, &src.header, x_src, y_src, c.right, h, g.spriteKey) catch |e| blitFailed(e);
    } else {
        const rle: []const u8 = obj.rleBits orelse &.{};
        dib.rleBlitTransparent(dst_hdr, dst_bits, obj.x +% c.left, obj.y +% c.top, rle, x_src, y_src, c.right, h) catch |e| blitFailed(e);
    }
}

/// SceneObject slot 1D drawClip (SceneObject's).
// @orig 10c0:3724 scene_object_draw_clip
pub fn drawClip(g: *Game, obj: *Object, bd: *Backdrop) void {
    drawClipTo(g, obj, &bd.bmiHeader, bd.pixels);
}

/// SceneObject slot 1E erase: animation_erase (exit, player, control_panel) / SceneObject's.
pub fn erase(g: *Game, obj: *Object, bd: *Backdrop) void {
    switch (obj.kind) {
        .exit, .player, .control_panel => animationErase(g, obj, bd),
        .scene_object, .wall_strip, .portable => soErase(g, obj, bd),
    }
}

// @orig 10c0:3760 scene_object_erase
fn soErase(g: *Game, obj: *Object, bd: *Backdrop) void {
    restoreBackground(g, obj, bd, 1);
}

// @orig 10c0:1a14 animation_erase
fn animationErase(g: *Game, obj: *Object, bd: *Backdrop) void {
    restoreBackground(g, obj, bd, 1);
}

/// SceneObject slot 1F slot1F: animation_slot1f (exit, player, control_panel) / default.
pub fn slot1F(g: *Game, obj: *Object, bd: *Backdrop) void {
    _ = g;
    switch (obj.kind) {
        .exit, .player, .control_panel => animationSlot1f(obj, bd),
        .scene_object, .wall_strip, .portable => slot1fDefault(obj, bd),
    }
}

// @orig 10c0:1a5e animation_slot1f
fn animationSlot1f(obj: *Object, bd: *Backdrop) void {
    dcHook(obj, 1, bd);
}

// @orig 10c0:378e scene_object_slot1f_default (absorbed)
fn slot1fDefault(obj: *Object, bd: *Backdrop) void {
    dcHook(obj, 1, bd);
}

// @orig 1038:0373 scene_object_dc_hook
fn dcHook(obj: *Object, flag: i16, bd: *Backdrop) void {
    _ = obj;
    _ = flag;
    _ = bd; // passes backdrop.hdc (no counterpart) to the empty hook
    emptyDcHook();
}

// @orig 1038:0347 scene_object_empty_dc_hook
fn emptyDcHook() void {}
