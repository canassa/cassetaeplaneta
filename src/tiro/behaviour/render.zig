//! Port unit `render` (behaviour) of TIRO.EXE. SceneObject slots 12-1A (dirty rects, overlap, restore background incl. Target's (BUGS.md T6), drawDirtyTo, draw, drawClip(To), erase, slot1F) and the DC hooks.
//!
//! Virtual-slot dispatchers owned by this unit; each switches on the object
//! kind between the override (Mover / Target / Animation / Player2D) and the
//! SceneObject default (docs/tiro/DESIGN.md "Virtual slots"). Each
//! implementation function carries `// @orig <seg:xxxx> <name>` with the
//! TIRO address. TIRO's blits all take the sprite key `g_unk00A8`
//! (`g.unk00A8`) and the backdrop's one WinG bitmap (`bd.pixels`).

const std = @import("std");
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
    std.debug.panic("tiro render: sprite blit left its buffers ({s})", .{@errorName(err)});
}

/// SceneObject slot 12 addDirtyRect.
pub fn addDirtyRect(g: *Game, obj: *Object, x: i16, y: i16, w: i16, h: i16) void {
    _ = g;
    soAddDirtyRect(obj, x, y, w, h);
}

// @orig 1088:14c0 scene_object_add_dirty_rect
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

// @orig 1088:146c scene_object_reset_rects
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
pub fn computeOverlap(g: *Game, obj: *Object, other: *Object) bool {
    _ = g;
    return soComputeOverlap(obj, other);
}

// @orig 1028:0adf scene_object_compute_overlap
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

/// SceneObject slot 14 restoreBackground: mover_restore_background (crossbow, arrow), target_restore_background (target) / SceneObject's.
pub fn restoreBackground(g: *Game, obj: *Object, bd: *Backdrop, flag: i16) void {
    switch (obj.kind) {
        .crossbow, .arrow => moverRestoreBackground(g, obj, bd),
        .target => targetRestoreBackground(g, obj, bd),
        .control_panel, .status_bar => soRestoreBackground(g, obj, bd, flag),
    }
}

// @orig 1028:0311 scene_object_restore_background
/// TIRO's is the opaque `dib_copy_rect` (no colour key), unlike ENCAIXE's.
fn soRestoreBackground(g: *Game, obj: *Object, bd: *Backdrop, flag: i16) void {
    _ = flag;
    const h = position.height(obj);
    const w = position.width(obj);
    const bg = bd.background orelse return;
    if (bd.pixels.len == 0) return;
    _ = dib.copyRect(&bd.bmiHeader, bd.pixels, obj.x, obj.y, bg.bits, &bg.header, obj.x, obj.y, w, h, g.fixes) catch |e| blitFailed(e);
}

// @orig 1028:0389 mover_restore_background
/// The rectangle covering the previous and current position plus one step:
/// marks it dirty, then copies it from the background to the working bitmap
/// with the colour key (ENCAIXE's piece version BitBlts instead).
fn moverRestoreBackground(g: *Game, obj: *Object, bd: *Backdrop) void {
    const left = @min(obj.mover.prevX, obj.x);
    const top = @min(obj.mover.prevY, obj.y);
    const w = position.getStepX(g, obj) +% position.width(obj);
    const h = position.getStepY(g, obj) +% position.height(obj);
    soAddDirtyRect(obj, left -% obj.x, top -% obj.y, w, h);
    copyBackground(g, bd, left, top, w, h);
}

// @orig 1068:0e2f target_restore_background
/// Target's override of slot 14. BUGS.md T6: |stepX| is added twice to the
/// width (the original calls getStepX twice); `tiro_target_restore_one_step`
/// adds it once, as the Mover's.
fn targetRestoreBackground(g: *Game, obj: *Object, bd: *Backdrop) void {
    const left = @min(obj.mover.prevX, obj.x);
    const top = @min(obj.mover.prevY, obj.y);
    const sx1 = position.getStepX(g, obj);
    var w = position.width(obj);
    w +%= sx1;
    if (!g.fixes.tiro_target_restore_one_step) w +%= position.getStepX(g, obj);
    const h = position.getStepY(g, obj) +% position.height(obj);
    soAddDirtyRect(obj, left -% obj.x, top -% obj.y, w, h);
    copyBackground(g, bd, left, top, w, h);
}

/// `dib_copy_transparent` of the background's (x, y, w, h) onto the working
/// bitmap, key `g_unk00A8`.
fn copyBackground(g: *Game, bd: *Backdrop, x: i16, y: i16, w: i16, h: i16) void {
    const bg = bd.background orelse return;
    if (bd.pixels.len == 0) return;
    _ = dib.copyTransparent(&bd.bmiHeader, bd.pixels, x, y, bg.bits, &bg.header, x, y, w, h, g.unk00A8) catch |e| blitFailed(e);
}

/// SceneObject slot 15 drawDirtyTo: mover_draw_dirty_to (crossbow, target, arrow) / SceneObject's.
pub fn drawDirtyTo(g: *Game, obj: *Object, dst_hdr: *const BitmapInfoHeader, dst_bits: []u8) void {
    switch (obj.kind) {
        .crossbow, .target, .arrow => moverDrawDirtyTo(g, obj, dst_hdr, dst_bits),
        .control_panel, .status_bar => soDrawDirtyTo(g, obj, dst_hdr, dst_bits),
    }
}

// @orig 1028:05a3 scene_object_draw_dirty_to
/// The dirty rectangle of the current frame, drawn at (x + dirtyX, y + dirtyY).
fn soDrawDirtyTo(g: *Game, obj: *Object, dst_hdr: *const BitmapInfoHeader, dst_bits: []u8) void {
    const d = obj.dirty;
    const orient: i16 = @truncate(obj.dibFormatOk);
    const h = orient *% d.bottom;
    const y_src = position.frameSrcY(obj) +% d.top;
    const x_src = position.frameSrcX(obj) +% d.left;
    const src = position.dib(obj) orelse return;
    if (dst_bits.len == 0) return;
    _ = dib.copyTransparent(dst_hdr, dst_bits, d.left +% obj.x, d.top +% obj.y, src.bits, &src.header, x_src, y_src, d.right, h, g.unk00A8) catch |e| blitFailed(e);
}

// @orig 1028:063d mover_draw_dirty_to
/// Mover's override: the whole current frame at (x, y), ignoring the dirty
/// rectangle.
fn moverDrawDirtyTo(g: *Game, obj: *Object, dst_hdr: *const BitmapInfoHeader, dst_bits: []u8) void {
    const orient: i16 = @truncate(obj.dibFormatOk);
    const h = orient *% position.height(obj);
    const w = position.width(obj);
    const y_src = position.frameSrcY(obj);
    const x_src = position.frameSrcX(obj);
    const src = position.dib(obj) orelse return;
    if (dst_bits.len == 0) return;
    _ = dib.copyTransparent(dst_hdr, dst_bits, obj.x, obj.y, src.bits, &src.header, x_src, y_src, w, h, g.unk00A8) catch |e| blitFailed(e);
}

/// SceneObject slot 16 draw: player2d_draw (crossbow), animation_draw (target, arrow), control_panel_draw (panel) / SceneObject's.
pub fn draw(g: *Game, obj: *Object, bd: *Backdrop) void {
    switch (obj.kind) {
        .crossbow => player2dDraw(g, obj, bd),
        .target, .arrow => animationDraw(g, obj, bd),
        .control_panel => panels.draw(g, obj, bd),
        .status_bar => soDraw(g, obj, bd),
    }
}

// @orig 1088:159a scene_object_draw
fn soDraw(g: *Game, obj: *Object, bd: *Backdrop) void {
    drawDirtyTo(g, obj, &bd.bmiHeader, bd.pixels);
}

// @orig 1028:1886 player2d_draw
fn player2dDraw(g: *Game, obj: *Object, bd: *Backdrop) void {
    animationDraw(g, obj, bd);
}

// @orig 1088:1d9e animation_draw
fn animationDraw(g: *Game, obj: *Object, bd: *Backdrop) void {
    drawDirtyTo(g, obj, &bd.bmiHeader, bd.pixels);
}

/// SceneObject slot 17 drawClipTo.
pub fn drawClipTo(g: *Game, obj: *Object, dst_hdr: *const BitmapInfoHeader, dst_bits: []u8) void {
    soDrawClipTo(g, obj, dst_hdr, dst_bits);
}

// @orig 1028:0509 scene_object_draw_clip_to
/// The clip rectangle of the current frame, drawn at (x + clipX, y + clipY).
fn soDrawClipTo(g: *Game, obj: *Object, dst_hdr: *const BitmapInfoHeader, dst_bits: []u8) void {
    const c = obj.clip;
    const orient: i16 = @truncate(obj.dibFormatOk);
    const h = orient *% c.bottom;
    const y_src = position.frameSrcY(obj) +% c.top;
    const x_src = position.frameSrcX(obj) +% c.left;
    const src = position.dib(obj) orelse return;
    if (dst_bits.len == 0) return;
    _ = dib.copyTransparent(dst_hdr, dst_bits, c.left +% obj.x, c.top +% obj.y, src.bits, &src.header, x_src, y_src, c.right, h, g.unk00A8) catch |e| blitFailed(e);
}

/// SceneObject slot 18 drawClip.
// @orig 1088:15ca scene_object_draw_clip
pub fn drawClip(g: *Game, obj: *Object, bd: *Backdrop) void {
    drawClipTo(g, obj, &bd.bmiHeader, bd.pixels);
}

/// SceneObject slot 19 erase: animation_erase (crossbow, target, arrow, panel) / SceneObject's.
pub fn erase(g: *Game, obj: *Object, bd: *Backdrop) void {
    switch (obj.kind) {
        .crossbow, .target, .arrow, .control_panel => animationErase(g, obj, bd),
        .status_bar => soErase(g, obj, bd),
    }
}

// @orig 1088:15fa scene_object_erase
fn soErase(g: *Game, obj: *Object, bd: *Backdrop) void {
    restoreBackground(g, obj, bd, 1);
}

// @orig 1088:1de0 animation_erase
fn animationErase(g: *Game, obj: *Object, bd: *Backdrop) void {
    restoreBackground(g, obj, bd, 1);
}

/// SceneObject slot 1A slot1F: animation_slot1f (crossbow, target, arrow, panel) / default.
pub fn slot1F(g: *Game, obj: *Object, bd: *Backdrop) void {
    _ = g;
    switch (obj.kind) {
        .crossbow, .target, .arrow, .control_panel => animationSlot1f(obj, bd),
        .status_bar => slot1fDefault(obj, bd),
    }
}

// @orig 1088:1e16 animation_slot1f
fn animationSlot1f(obj: *Object, bd: *Backdrop) void {
    dcHook(obj, 1, bd);
}

// @orig 1088:161e scene_object_slot1f_default (absorbed)
fn slot1fDefault(obj: *Object, bd: *Backdrop) void {
    dcHook(obj, 1, bd);
}

// @orig 1028:02ec scene_object_dc_hook
fn dcHook(obj: *Object, flag: i16, bd: *Backdrop) void {
    _ = obj;
    _ = flag;
    _ = bd; // passes backdrop.hdc (no counterpart) to the empty hook
    emptyDcHook();
}

// @orig 1028:02ba scene_object_empty_dc_hook
fn emptyDcHook() void {}
