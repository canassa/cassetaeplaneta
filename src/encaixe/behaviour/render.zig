//! Port unit `render` (behaviour) of ENCAIXE.EXE. SceneObject slots 13-1C (dirty rects, overlap, restore background, drawDirtyTo, draw, unk18, drawClip(To), erase, slot1F) and the DC hooks.
//!
//! Virtual-slot dispatchers owned by this unit; each switches on the object
//! kind between the override (piece / control panel) and the SceneObject
//! default (docs/encaixe/DESIGN.md "Virtual slots"). Each implementation
//! function carries `// @orig <1008:xxxx> <name>` with the ENCAIXE address.

const std = @import("std");
const Game = @import("../core/game.zig").Game;
const object = @import("../core/object.zig");
const Object = object.Object;
const Frame = object.Frame;
const BitmapInfoHeader = object.BitmapInfoHeader;
const world = @import("../core/world.zig");
const Backdrop = world.Backdrop;
const dib = @import("../dib.zig");
const panels = @import("../panels.zig");
const position = @import("position.zig");

fn blitFailed(err: dib.Error) noreturn {
    std.debug.panic("encaixe render: sprite blit left its buffers ({s})", .{@errorName(err)});
}

fn strip(obj: *Object) *const Frame {
    return &obj.frames[@intCast(obj.curStrip)];
}

/// SceneObject slot 13 addDirtyRect.
pub fn addDirtyRect(g: *Game, obj: *Object, x: i16, y: i16, w: i16, h: i16) void {
    _ = g;
    soAddDirtyRect(obj, x, y, w, h);
}

// @orig 1008:52da scene_object_add_dirty_rect
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

/// SceneObject slot 14 computeOverlap.
pub fn computeOverlap(g: *Game, obj: *Object, other: *Object) bool {
    _ = g;
    return soComputeOverlap(obj, other);
}

// @orig 1008:74b6 scene_object_compute_overlap
fn soComputeOverlap(obj: *Object, other: *Object) bool {
    const d = &obj.dirty;
    const c = &obj.clip;
    const od = &other.dirty;
    const of = strip(other);
    const sf = strip(obj);
    if (obj.x +% d.left +% d.right < other.x) return false;
    if (obj.x +% d.left > of.width +% other.x) return false;
    if (obj.y +% d.top +% d.bottom < other.y) return false;
    if (obj.y +% d.top > of.height +% other.y) return false;

    if (obj.x +% d.left < other.x) {
        od.left = 0;
        c.left = other.x -% obj.x;
    } else {
        od.left = (d.left -% other.x) +% obj.x;
        c.left = d.left;
    }
    if (c.left < 0) c.left = 0;

    if (obj.y +% d.top < other.y) {
        od.top = 0;
        c.top = other.y -% obj.y;
    } else {
        od.top = (d.top -% other.y) +% obj.y;
        c.top = d.top;
    }
    if (c.top < 0) c.top = 0;

    if (obj.x +% d.left +% d.right < of.width +% other.x) {
        od.right = (((d.left -% od.left) -% other.x) +% d.right) +% obj.x;
    } else {
        od.right = of.width -% od.left;
    }
    if (sf.width < od.right +% c.left) {
        c.right = sf.width -% c.left;
    } else {
        c.right = od.right;
    }

    if (obj.y +% d.top +% d.bottom < of.height +% other.y) {
        od.bottom = (((d.top -% od.top) -% other.y) +% d.bottom) +% obj.y;
    } else {
        od.bottom = of.height -% od.top;
    }
    if (sf.height < od.bottom +% c.top) {
        c.bottom = sf.height -% c.top;
    } else {
        c.bottom = od.bottom;
    }
    return true;
}

/// SceneObject slot 15 restoreBackground: the piece's own (te_piece_restore_background) / SceneObject's.
pub fn restoreBackground(g: *Game, obj: *Object, bd: *Backdrop, flag: i16) void {
    switch (obj.kind) {
        .piece => tePieceRestoreBackground(g, obj, bd),
        .control_panel, .status_bar => soRestoreBackground(g, obj, bd, flag),
    }
}

// @orig 1008:6ebc scene_object_restore_background
fn soRestoreBackground(g: *Game, obj: *Object, bd: *Backdrop, flag: i16) void {
    _ = flag;
    const bg = bd.background orelse return;
    if (bd.pixels.len == 0) return;
    const f = strip(obj);
    _ = dib.copyTransparent(&bd.bmiHeader, bd.pixels, obj.x, obj.y, bg.bits, &bg.header, obj.x, obj.y, f.width, f.height, g.unk0012) catch |e| blitFailed(e);
}

// @orig 1008:c304 te_piece_restore_background
/// The rectangle covering the previous and current position plus one step:
/// marks it dirty, then BitBlts SRCCOPY from the clean bitmap (`pixels2`,
/// DC +0xe) to the working one (`pixels`, DC +2).
fn tePieceRestoreBackground(g: *Game, obj: *Object, bd: *Backdrop) void {
    const x = @min(obj.x, obj.mover.prevX);
    const y = @min(obj.y, obj.mover.prevY);
    const f = strip(obj);
    const w = position.getStepX(g, obj) +% f.width;
    const h = position.getStepY(g, obj) +% f.height;
    addDirtyRect(g, obj, x -% obj.x, y -% obj.y, w, h);
    bitBlt(bd, x, y, w, h);
}

/// BitBlt(pixels, x, y, w, h, pixels2, x, y, SRCCOPY), clipped to the bitmaps.
fn bitBlt(bd: *Backdrop, x: i16, y: i16, w: i16, h: i16) void {
    const dst = bd.surface();
    const stride = dst.stride();
    const bw: i32 = dst.width;
    const bh: i32 = dst.height;
    var row: i32 = 0;
    while (row < h) : (row += 1) {
        const yy = @as(i32, y) + row;
        if (yy < 0 or yy >= bh) continue;
        const r: usize = @intCast(if (dst.bottom_up) bh - 1 - yy else yy);
        var col: i32 = 0;
        while (col < w) : (col += 1) {
            const xx = @as(i32, x) + col;
            if (xx < 0 or xx >= bw) continue;
            const i = r * stride + @as(usize, @intCast(xx));
            if (i >= bd.pixels.len or i >= bd.pixels2.len) continue;
            bd.pixels[i] = bd.pixels2[i];
        }
    }
}

/// SceneObject slot 16 drawDirtyTo: Mover's (piece) / SceneObject's (far bits and header).
pub fn drawDirtyTo(g: *Game, obj: *Object, dst_hdr: *const BitmapInfoHeader, dst_bits: []u8) void {
    switch (obj.kind) {
        .piece => moverDrawDirtyTo(g, obj, dst_hdr, dst_bits),
        .control_panel, .status_bar => soDrawDirtyTo(g, obj, dst_hdr, dst_bits),
    }
}

/// Draws the whole current frame at the object's position (neither variant
/// uses the dirty rectangle).
fn drawFrame(g: *Game, obj: *Object, dst_hdr: *const BitmapInfoHeader, dst_bits: []u8) void {
    const f = strip(obj);
    const d = f.dib orelse return;
    if (dst_bits.len == 0) return;
    const orient: i16 = @truncate(obj.dibFormatOk);
    _ = dib.copyTransparent(dst_hdr, dst_bits, obj.x, obj.y, d.bits, &d.header, 0, f.height *% obj.curFrame, f.width, f.height *% orient, g.unk0012) catch |e| blitFailed(e);
}

// @orig 1008:70a4 scene_object_draw_dirty_to
fn soDrawDirtyTo(g: *Game, obj: *Object, dst_hdr: *const BitmapInfoHeader, dst_bits: []u8) void {
    drawFrame(g, obj, dst_hdr, dst_bits);
}

// @orig 1008:70fe mover_draw_dirty_to
fn moverDrawDirtyTo(g: *Game, obj: *Object, dst_hdr: *const BitmapInfoHeader, dst_bits: []u8) void {
    drawFrame(g, obj, dst_hdr, dst_bits);
}

/// SceneObject slot 17 draw: te_piece_draw (piece), control_panel_draw (panels.draw), SceneObject's.
pub fn draw(g: *Game, obj: *Object, bd: *Backdrop) void {
    switch (obj.kind) {
        .piece => tePieceDraw(g, obj, bd),
        .control_panel => if (@hasDecl(panels, "draw")) panels.draw(g, obj, bd) else @panic("encaixe.panels.draw missing"),
        .status_bar => soDraw(g, obj, bd),
    }
}

// @orig 1008:5388 scene_object_draw
fn soDraw(g: *Game, obj: *Object, bd: *Backdrop) void {
    drawDirtyTo(g, obj, &bd.bmiHeader, bd.pixels);
}

// @orig 1008:f016 te_piece_draw
fn tePieceDraw(g: *Game, obj: *Object, bd: *Backdrop) void {
    drawDirtyTo(g, obj, &bd.bmiHeader, bd.pixels);
}

/// SceneObject slot 18 unk18 (ENCAIXE-only draw variant): draws into the second bitmap.
// @orig 1008:53a8 scene_object_unk18
pub fn unk18(g: *Game, obj: *Object, bd: *Backdrop) void {
    drawDirtyTo(g, obj, &bd.bmiHeader, bd.pixels2);
}

/// SceneObject slot 19 drawClipTo.
pub fn drawClipTo(g: *Game, obj: *Object, dst_hdr: *const BitmapInfoHeader, dst_bits: []u8) void {
    soDrawClipTo(g, obj, dst_hdr, dst_bits);
}

// @orig 1008:7038 scene_object_draw_clip_to
fn soDrawClipTo(g: *Game, obj: *Object, dst_hdr: *const BitmapInfoHeader, dst_bits: []u8) void {
    const f = strip(obj);
    const d = f.dib orelse return;
    if (dst_bits.len == 0) return;
    const c = obj.clip;
    const orient: i16 = @truncate(obj.dibFormatOk);
    _ = dib.copyTransparent(dst_hdr, dst_bits, c.left +% obj.x, c.top +% obj.y, d.bits, &d.header, c.left, (f.height *% obj.curFrame) +% c.top, c.right, orient *% c.bottom, g.unk0012) catch |e| blitFailed(e);
}

/// SceneObject slot 1A drawClip.
// @orig 1008:53c8 scene_object_draw_clip
pub fn drawClip(g: *Game, obj: *Object, bd: *Backdrop) void {
    drawClipTo(g, obj, &bd.bmiHeader, bd.pixels);
}

/// SceneObject slot 1B erase: Animation's (piece, control_panel) / SceneObject's.
pub fn erase(g: *Game, obj: *Object, bd: *Backdrop) void {
    switch (obj.kind) {
        .piece, .control_panel => animationErase(g, obj, bd),
        .status_bar => soErase(g, obj, bd),
    }
}

// @orig 1008:53e8 scene_object_erase
fn soErase(g: *Game, obj: *Object, bd: *Backdrop) void {
    restoreBackground(g, obj, bd, 1);
}

// @orig 1008:56d4 animation_erase
fn animationErase(g: *Game, obj: *Object, bd: *Backdrop) void {
    restoreBackground(g, obj, bd, 1);
}

/// SceneObject slot 1C slot1F: Animation's (piece, control_panel) / default
/// (1008:5400, absorbed). Both only reach the no-op DC hook.
pub fn slot1F(g: *Game, obj: *Object, bd: *Backdrop) void {
    _ = g;
    switch (obj.kind) {
        .piece, .control_panel => animationSlot1f(obj, bd),
        .status_bar => dcHook(obj, 1, bd),
    }
}

// @orig 1008:56f4 animation_slot1f
fn animationSlot1f(obj: *Object, bd: *Backdrop) void {
    dcHook(obj, 1, bd);
}

// @orig 1008:6ea8 scene_object_dc_hook
fn dcHook(obj: *Object, flag: i16, bd: *Backdrop) void {
    _ = obj;
    _ = flag;
    _ = bd; // passes backdrop.hdc (no counterpart) to the empty hook
    emptyDcHook();
}

// @orig 1008:6ea4 scene_object_empty_dc_hook
fn emptyDcHook() void {}
