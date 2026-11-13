//! Port unit `render` (behaviour). SceneObject slots 17-1E: dirty rects, overlap, restore background, draw, draw clip, erase.
//!
//! All drawing goes into the backdrop's bitmap (`bd.pixels`, described by
//! `bd.bmiHeader`) through `dib.copyTransparent` (skipping source pixels
//! equal to `g.unk001C`, the transparency key) or, for run-length encoded
//! sprites, `dib.rleBlitTransparent`.
//!
//! The slots return nothing, so the blits' `error.LimitExceeded` (where the
//! original would run off its buffers and corrupt memory) cannot propagate;
//! it panics (`blitFailed`). The shipped data never triggers it.

const std = @import("std");
const Game = @import("../core/game.zig").Game;
const object = @import("../core/object.zig");
const Object = object.Object;
const BitmapInfoHeader = object.BitmapInfoHeader;
const world = @import("../core/world.zig");
const Backdrop = world.Backdrop;
const dib = @import("../dib.zig");
const frames = @import("../frames.zig");
const panels = @import("../panels.zig");
const misc = @import("misc.zig");
const position = @import("position.zig");

fn blitFailed(err: dib.Error) noreturn {
    std.debug.panic("render: sprite blit left its buffers ({s})", .{@errorName(err)});
}

/// SceneObject slot 17: grows the dirty rectangle (frame-relative) to
/// include the rectangle `x, y, w, h`.
pub fn addDirtyRect(g: *Game, obj: *Object, x: i16, y: i16, w: i16, h: i16) void {
    _ = g;
    soAddDirtyRect(obj, x, y, w, h);
}

// @orig 1010:15cc scene_object_add_dirty_rect
fn soAddDirtyRect(obj: *Object, x: i16, y: i16, w_in: i16, h_in: i16) void {
    const d = &obj.dirty;
    var w = w_in;
    var h = h_in;
    const old_x = d.left;
    if (x < old_x) {
        if (w +% x < d.right +% old_x) w = (d.right +% old_x) -% x;
        d.right = w;
        d.left = x;
    } else if (d.left +% d.right < w +% x) {
        d.right = (w -% d.left) +% x;
    }
    if (y < d.top) {
        if (h +% y < d.top +% d.bottom) h = (d.top +% d.bottom) -% y;
        d.bottom = h;
        d.top = y;
        return;
    }
    if (d.top +% d.bottom < h +% y) {
        d.bottom = (h -% d.top) +% y;
    }
}

/// SceneObject slot 18: intersects this object's dirty rectangle with
/// `other`'s frame; on overlap stores it as `other`'s dirty rectangle and
/// this object's clip rectangle and returns true.
pub fn computeOverlap(g: *Game, obj: *Object, other: *Object) bool {
    _ = g;
    return soComputeOverlap(obj, other);
}

// @orig 1010:bda8 scene_object_compute_overlap
fn soComputeOverlap(obj: *Object, other: *Object) bool {
    const d = &obj.dirty;
    const c = &obj.clip;
    const od = &other.dirty;
    if (obj.x +% d.left +% d.right < other.x) return false;
    if (obj.x +% d.left > frames.width(other) +% other.x) return false;
    if (obj.y +% d.top +% d.bottom < other.y) return false;
    if (obj.y +% d.top > frames.height(other) +% other.y) return false;

    if (obj.x +% d.left < other.x) {
        od.left = 0;
        c.left = other.x -% obj.x;
    } else {
        od.left = (obj.x -% other.x) +% d.left;
        c.left = d.left;
    }
    if (c.left < 0) c.left = 0;

    if (obj.y +% d.top < other.y) {
        od.top = 0;
        c.top = other.y -% obj.y;
    } else {
        od.top = (obj.y -% other.y) +% d.top;
        c.top = d.top;
    }
    if (c.top < 0) c.top = 0;

    if (obj.x +% d.left +% d.right < frames.width(other) +% other.x) {
        od.right = (((obj.x -% other.x) -% od.left) +% d.left) +% d.right;
    } else {
        od.right = frames.width(other) -% od.left;
    }
    if (frames.width(obj) < od.right +% c.left) {
        c.right = frames.width(obj) -% c.left;
    } else {
        c.right = od.right;
    }

    if (obj.y +% d.top +% d.bottom < frames.height(other) +% other.y) {
        od.bottom = (((obj.y -% other.y) -% od.top) +% d.top) +% d.bottom;
    } else {
        od.bottom = frames.height(other) -% od.top;
    }
    if (frames.height(obj) < od.bottom +% c.top) {
        c.bottom = frames.height(obj) -% c.top;
    } else {
        c.bottom = od.bottom;
    }
    return true;
}

/// Copies the pristine background over `x, y, w, h` of the backdrop bitmap,
/// skipping background pixels equal to the key (the body shared by both
/// restoreBackground implementations). Nothing without a background or bitmap.
fn copyBackground(g: *Game, bd: *Backdrop, x: i16, y: i16, w: i16, h: i16) void {
    const bg = bd.background orelse return;
    if (bd.pixels.len == 0) return;
    _ = dib.copyTransparent(&bd.bmiHeader, bd.pixels, x, y, bg.bits, &bg.header, x, y, w, h, g.unk001C) catch |e| blitFailed(e);
}

/// SceneObject slot 19: restores the background under the object.
/// `flag` is unused by both implementations.
pub fn restoreBackground(g: *Game, obj: *Object, bd: *Backdrop, flag: i16) void {
    switch (obj.kind) {
        .moveable, .actor, .player, .portable => moverRestoreBackground(g, obj, bd, flag),
        .local, .animated, .exit, .control_panel, .status_bar => soRestoreBackground(g, obj, bd, flag),
    }
}

// @orig 1010:b366 scene_object_restore_background
fn soRestoreBackground(g: *Game, obj: *Object, bd: *Backdrop, flag: i16) void {
    _ = flag;
    copyBackground(g, bd, obj.x, obj.y, frames.width(obj), frames.height(obj));
}

// @orig 1010:b3fa mover_restore_background
/// Marks dirty and restores the background over the rectangle covering both
/// the previous and the current position (frame size plus one step).
fn moverRestoreBackground(g: *Game, obj: *Object, bd: *Backdrop, flag: i16) void {
    _ = flag;
    const x = @min(obj.x, obj.mover.prevX);
    const y = @min(obj.y, obj.mover.prevY);
    const w = frames.width(obj) +% position.getStepX(g, obj);
    const h = frames.height(obj) +% position.getStepY(g, obj);
    addDirtyRect(g, obj, x -% obj.x, y -% obj.y, w, h);
    copyBackground(g, bd, x, y, w, h);
}

/// SceneObject slot 1A: draws the dirty part of the current frame into the
/// 8-bit DIB `dst_bits` (described by `dst_hdr`).
pub fn drawDirtyTo(g: *Game, obj: *Object, dst_hdr: *const BitmapInfoHeader, dst_bits: []u8) void {
    switch (obj.kind) {
        .moveable, .actor, .player, .portable => moverDrawDirtyTo(g, obj, dst_hdr, dst_bits),
        .local, .animated, .exit, .control_panel, .status_bar => soDrawDirtyTo(g, obj, dst_hdr, dst_bits),
    }
}

/// Draws the `rect` part of the current frame (the dirty or the clip
/// rectangle) at the object's position; RLE sprites ignore `rect` in the
/// dirty variant (`whole_rle`) and use the clip in the clip variant.
fn drawRectTo(g: *Game, obj: *Object, dst_hdr: *const BitmapInfoHeader, dst_bits: []u8, rect: object.Rect, whole_rle: bool) void {
    const d = frames.dib(obj) orelse return;
    if (dst_bits.len == 0) return;
    const orient: i16 = @truncate(obj.dibFormatOk);
    if (!misc.isRle(g, obj)) {
        _ = dib.copyTransparent(
            dst_hdr,
            dst_bits,
            obj.x +% rect.left,
            obj.y +% rect.top,
            d.bits,
            &d.header,
            frames.frameSrcX(obj) +% rect.left,
            frames.frameSrcY(obj) +% rect.top,
            rect.right,
            orient *% rect.bottom,
            g.unk001C,
        ) catch |e| blitFailed(e);
    } else {
        const rle: []const u8 = obj.rleBits orelse &.{};
        if (whole_rle) {
            dib.rleBlitTransparent(dst_hdr, obj.x, obj.y, rle, frames.frameSrcX(obj), frames.frameSrcY(obj), frames.width(obj), orient *% frames.height(obj)) catch |e| blitFailed(e);
        } else {
            dib.rleBlitTransparent(dst_hdr, obj.x +% rect.left, obj.y +% rect.top, rle, frames.frameSrcX(obj) +% rect.left, frames.frameSrcY(obj) +% rect.top, rect.right, orient *% rect.bottom) catch |e| blitFailed(e);
        }
    }
}

// @orig 1010:b746 scene_object_draw_dirty_to
fn soDrawDirtyTo(g: *Game, obj: *Object, dst_hdr: *const BitmapInfoHeader, dst_bits: []u8) void {
    drawRectTo(g, obj, dst_hdr, dst_bits, obj.dirty, true);
}

// @orig 1010:b8a0 mover_draw_dirty_to
/// Draws the whole current frame (the decompile's "previous position" is
/// wrong: the asm reads the SceneObject's x and y).
fn moverDrawDirtyTo(g: *Game, obj: *Object, dst_hdr: *const BitmapInfoHeader, dst_bits: []u8) void {
    const d = frames.dib(obj) orelse return;
    if (dst_bits.len == 0) return;
    const orient: i16 = @truncate(obj.dibFormatOk);
    _ = dib.copyTransparent(
        dst_hdr,
        dst_bits,
        obj.x,
        obj.y,
        d.bits,
        &d.header,
        frames.frameSrcX(obj),
        frames.frameSrcY(obj),
        frames.width(obj),
        orient *% frames.height(obj),
        g.unk001C,
    ) catch |e| blitFailed(e);
}

/// SceneObject slot 1B: draws the object into the backdrop bitmap.
pub fn draw(g: *Game, obj: *Object, bd: *Backdrop) void {
    switch (obj.kind) {
        .animated, .actor => animationDraw(g, obj, bd),
        .player => playerDraw(g, obj, bd),
        .exit => exitDraw(g, obj, bd),
        .control_panel => controlPanelDraw(g, obj, bd),
        .local, .moveable, .portable, .status_bar => soDraw(g, obj, bd),
    }
}

// @orig 1010:168c scene_object_draw
fn soDraw(g: *Game, obj: *Object, bd: *Backdrop) void {
    drawDirtyTo(g, obj, &bd.bmiHeader, bd.pixels);
}

// @orig 1010:26fc animation_draw
fn animationDraw(g: *Game, obj: *Object, bd: *Backdrop) void {
    drawDirtyTo(g, obj, &bd.bmiHeader, bd.pixels);
}

// @orig 1010:65ce player_draw
fn playerDraw(g: *Game, obj: *Object, bd: *Backdrop) void {
    animationDraw(g, obj, bd);
}

// @orig 1010:4202 exit_draw
fn exitDraw(g: *Game, obj: *Object, bd: *Backdrop) void {
    soDraw(g, obj, bd);
}

// @orig 1018:1f1c control_panel_draw
/// The frame; when open and not animating also the inventory icons; then
/// the texts.
fn controlPanelDraw(g: *Game, obj: *Object, bd: *Backdrop) void {
    animationDraw(g, obj, bd);
    if (obj.panel.isOpen != 0 and obj.anim.running == 0) {
        _ = panels.drawInventory(g, obj, bd);
    }
    panels.drawTexts(g, obj, bd);
}

/// SceneObject slot 1C: draws the clip part of the current frame into a DIB.
pub fn drawClipTo(g: *Game, obj: *Object, dst_hdr: *const BitmapInfoHeader, dst_bits: []u8) void {
    soDrawClipTo(g, obj, dst_hdr, dst_bits);
}

// @orig 1010:b56a scene_object_draw_clip_to
fn soDrawClipTo(g: *Game, obj: *Object, dst_hdr: *const BitmapInfoHeader, dst_bits: []u8) void {
    drawRectTo(g, obj, dst_hdr, dst_bits, obj.clip, false);
}

/// SceneObject slot 1D: draws the clip part into the backdrop bitmap.
pub fn drawClip(g: *Game, obj: *Object, bd: *Backdrop) void {
    soDrawClip(g, obj, bd);
}

// @orig 1010:16c2 scene_object_draw_clip
fn soDrawClip(g: *Game, obj: *Object, bd: *Backdrop) void {
    drawClipTo(g, obj, &bd.bmiHeader, bd.pixels);
}

/// SceneObject slot 1E: erases the object by restoring the background.
pub fn erase(g: *Game, obj: *Object, bd: *Backdrop) void {
    switch (obj.kind) {
        .animated, .actor, .player, .exit, .control_panel => animationErase(g, obj, bd),
        .local, .moveable, .portable, .status_bar => soErase(g, obj, bd),
    }
}

// @orig 1010:16f8 scene_object_erase
fn soErase(g: *Game, obj: *Object, bd: *Backdrop) void {
    restoreBackground(g, obj, bd, 1);
}

// @orig 1010:2740 animation_erase
fn animationErase(g: *Game, obj: *Object, bd: *Backdrop) void {
    restoreBackground(g, obj, bd, 1);
}
