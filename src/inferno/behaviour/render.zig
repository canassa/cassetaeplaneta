//! Port unit `render` (behaviour) of INFERNO.EXE. SceneObject slots 12-1A
//! (dirty rects, overlap, restoreBackground, drawDirtyTo, draw, drawClip(To),
//! erase, slot1F) and the DC hooks. INFERNO builds only Actor2D-derived
//! objects, so every kind takes the Mover/Animation override; the blits take
//! the sprite key `g_unk0082` (`g.unk0082`) and the backdrop's one WinG
//! bitmap (`bd.pixels`).

const std = @import("std");
const Game = @import("../core/game.zig").Game;
const object = @import("../core/object.zig");
const Object = object.Object;
const BitmapInfoHeader = object.BitmapInfoHeader;
const world = @import("../core/world.zig");
const Backdrop = world.Backdrop;
const dib = @import("../dib.zig");
const position = @import("position.zig");
const prop = @import("../prop.zig");

fn blitFailed(err: dib.Error) noreturn {
    std.debug.panic("inferno render: sprite blit left its buffers ({s})", .{@errorName(err)});
}

/// SceneObject slot 12 addDirtyRect.
// @orig 1080:2100 scene_object_add_dirty_rect
/// INFERNO's is the plain version: no clamping of the width/height against
/// the old rectangle (TIRO's 1088:14c0 has the extra `w + x < left + right`
/// branches).
pub fn addDirtyRect(g: *Game, obj: *Object, x: i16, y: i16, w: i16, h: i16) void {
    _ = g;
    const d = &obj.dirty;
    if (x < d.left) d.left = x;
    if (y < d.top) d.top = y;
    if (d.left +% d.right < w +% x) d.right = (w -% d.left) +% x;
    if (d.top +% d.bottom < h +% y) d.bottom = (h -% d.top) +% y;
}

// @orig 1080:579e scene_object_reset_rects
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

/// SceneObject slot 13 computeOverlap.
// @orig 1028:0f37 scene_object_compute_overlap
pub fn computeOverlap(g: *Game, obj: *Object, other: *Object) bool {
    _ = g;
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
        od.left = (d.left -% other.x) +% obj.x;
        c.left = d.left;
    }
    if (c.left < 0) c.left = 0;

    if (d.top +% obj.y < other.y) {
        od.top = 0;
        c.top = other.y -% obj.y;
    } else {
        od.top = (d.top -% other.y) +% obj.y;
        c.top = d.top;
    }
    if (c.top < 0) c.top = 0;

    if (d.left +% d.right +% obj.x < position.width(other) +% other.x) {
        od.right = ((d.left -% other.x) -% od.left) +% d.right +% obj.x;
    } else {
        od.right = position.width(other) -% od.left;
    }
    if (position.width(obj) < od.right +% c.left) {
        c.right = position.width(obj) -% c.left;
    } else {
        c.right = od.right;
    }

    if (d.top +% d.bottom +% obj.y < position.height(other) +% other.y) {
        od.bottom = ((d.top -% other.y) -% od.top) +% d.bottom +% obj.y;
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

/// SceneObject slot 14 restoreBackground: mover_restore_background (hero,
/// platform), prop.restoreBackground (prop, hazard: prop_restore_background).
pub fn restoreBackground(g: *Game, obj: *Object, bd: *Backdrop, flag: i16) void {
    switch (obj.kind) {
        .hero, .platform => moverRestoreBackground(g, obj, bd),
        .prop, .hazard => prop.restoreBackground(g, obj, bd, flag),
    }
}

// @orig 1028:049d mover_restore_background
/// The rectangle covering the previous and current position plus one step:
/// marks it dirty (slot 0x48), then copies it from the background to the
/// working bitmap with the colour key `g_unk0082`.
fn moverRestoreBackground(g: *Game, obj: *Object, bd: *Backdrop) void {
    const left = @min(obj.mover.prevX, obj.x);
    const top = @min(obj.mover.prevY, obj.y);
    const w = position.width(obj) +% position.getStepX(g, obj);
    const h = position.height(obj) +% position.getStepY(g, obj);
    addDirtyRect(g, obj, left -% obj.x, top -% obj.y, w, h);
    const bg = bd.background orelse return;
    if (bd.pixels.len == 0) return;
    _ = dib.copyTransparent(&bd.bmiHeader, bd.pixels, left, top, bg.bits, &bg.header, left, top, w, h, g.unk0082) catch |e| blitFailed(e);
}

/// SceneObject slot 15 drawDirtyTo: mover_draw_dirty_to (every kind).
// @orig 1028:08a7 mover_draw_dirty_to
/// The whole current frame at (x, y), ignoring the dirty rectangle.
pub fn drawDirtyTo(g: *Game, obj: *Object, dst_hdr: *const BitmapInfoHeader, dst_bits: []u8) void {
    const orient: i16 = @truncate(obj.dibFormatOk);
    const h = orient *% position.height(obj);
    const w = position.width(obj);
    const y_src = position.frameSrcY(obj);
    const x_src = position.frameSrcX(obj);
    const src = position.dib(obj) orelse return;
    if (dst_bits.len == 0) return;
    _ = dib.copyTransparent(dst_hdr, dst_bits, obj.x, obj.y, src.bits, &src.header, x_src, y_src, w, h, g.unk0082) catch |e| blitFailed(e);
}

/// SceneObject slot 16 draw: animation_draw (every kind).
// @orig 1080:2a28 animation_draw
pub fn draw(g: *Game, obj: *Object, bd: *Backdrop) void {
    drawDirtyTo(g, obj, &bd.bmiHeader, bd.pixels);
}

/// SceneObject slot 17 drawClipTo (scene_object_draw_clip_to).
// @orig 1028:06f5 scene_object_draw_clip_to
/// The clip rectangle of the current frame, drawn at (x + clipX, y + clipY).
pub fn drawClipTo(g: *Game, obj: *Object, dst_hdr: *const BitmapInfoHeader, dst_bits: []u8) void {
    const c = obj.clip;
    const orient: i16 = @truncate(obj.dibFormatOk);
    const h = orient *% c.bottom;
    const y_src = position.frameSrcY(obj) +% c.top;
    const x_src = position.frameSrcX(obj) +% c.left;
    const src = position.dib(obj) orelse return;
    if (dst_bits.len == 0) return;
    _ = dib.copyTransparent(dst_hdr, dst_bits, c.left +% obj.x, c.top +% obj.y, src.bits, &src.header, x_src, y_src, c.right, h, g.unk0082) catch |e| blitFailed(e);
}

/// SceneObject slot 18 drawClip (scene_object_draw_clip).
// @orig 1080:21ea scene_object_draw_clip
pub fn drawClip(g: *Game, obj: *Object, bd: *Backdrop) void {
    drawClipTo(g, obj, &bd.bmiHeader, bd.pixels);
}

/// SceneObject slot 19 erase: animation_erase (every kind).
// @orig 1080:2a80 animation_erase
pub fn erase(g: *Game, obj: *Object, bd: *Backdrop) void {
    restoreBackground(g, obj, bd, 1);
}

/// SceneObject slot 1A slot1F: animation_slot1f (every kind).
// @orig 1080:2aca animation_slot1f
pub fn slot1F(g: *Game, obj: *Object, bd: *Backdrop) void {
    _ = g;
    dcHook(obj, 1, bd);
}

// @orig 1028:03d7 scene_object_dc_hook
fn dcHook(obj: *Object, flag: i16, bd: *Backdrop) void {
    _ = obj;
    _ = flag;
    _ = bd; // passes backdrop.hdc (no counterpart) to the empty hook
    emptyDcHook();
}

// @orig 1028:03ab scene_object_empty_dc_hook
fn emptyDcHook() void {}
