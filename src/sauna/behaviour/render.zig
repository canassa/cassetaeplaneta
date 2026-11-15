//! Port unit `render` (behaviour) of SAUNA.EXE. SceneObject slots 03 isRle, 17-20 (dirty rects, overlap, restoreBackground incl. Pacman's (eating, the win) and the Ghosts', drawDirtyTo, draw, unk18, drawClip(To), erase, slot1F) and the DC hooks.
//!
//! Virtual-slot dispatchers owned by this unit; each switches on the object
//! kind between the override (Mover / Animation / Player2D / ControlPanel)
//! and the SceneObject default (docs/sauna/DESIGN.md "Virtual slots").
//! Each implementation function carries `// @orig <seg:xxxx> <name>` with
//! the SAUNA address. SAUNA's blits take the sprite key `g_transparentColor`
//! (`g.transparentColor`); the backdrop has two bitmaps (`pixels`, and
//! `pixels2`: the background with the dots, which the restores copy from).

const std = @import("std");
const msg = @import("../../core/msg.zig");
const Game = @import("../core/game.zig").Game;
const object = @import("../core/object.zig");
const Object = object.Object;
const BitmapInfoHeader = object.BitmapInfoHeader;
const world = @import("../core/world.zig");
const Backdrop = world.Backdrop;
const dib = @import("../dib.zig");
const panels = @import("../panels.zig");
const score = @import("../score.zig");
const position = @import("position.zig");
const visibility = @import("visibility.zig");

fn blitFailed(err: dib.Error) noreturn {
    std.debug.panic("sauna render: sprite blit left its buffers ({s})", .{@errorName(err)});
}

/// The colour key `g_transparentColor` (pushed as a byte).
fn key(g: *Game) u8 {
    return @truncate(g.transparentColor);
}

/// SceneObject slot 03 isRle.
// @orig 10a0:33fa scene_object_is_rle
pub fn isRle(g: *Game, obj: *Object) bool {
    _ = g;
    _ = obj;
    // Reads +0x490 (the high word of `wave`, never set on a SAUNA object;
    // `enableRle` is never called): always 0, the RLE path is dead.
    return false;
}

fn rleDead() noreturn {
    std.debug.panic("sauna render: RLE sprite (the RLE path is dead, nothing calls enableRle)", .{});
}

/// SceneObject slot 17 addDirtyRect.
pub fn addDirtyRect(g: *Game, obj: *Object, x: i16, y: i16, w: i16, h: i16) void {
    _ = g;
    soAddDirtyRect(obj, x, y, w, h);
}

// @orig 10a0:361e scene_object_add_dirty_rect
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

// @orig 10a0:211c scene_object_reset_rects
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

/// SceneObject slot 18 computeOverlap.
pub fn computeOverlap(g: *Game, obj: *Object, other: *Object) bool {
    _ = g;
    return soComputeOverlap(obj, other);
}

// @orig 1020:1144 scene_object_compute_overlap
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

/// SceneObject slot 19 restoreBackground: pacman_restore_background (pacman), ghost_restore_background (ghost) / SceneObject's.
pub fn restoreBackground(g: *Game, obj: *Object, bd: *Backdrop, flag: i16) void {
    switch (obj.kind) {
        .pacman => pacmanRestoreBackground(g, obj, bd),
        .ghost => ghostRestoreBackground(g, obj, bd),
        .dot, .control_panel => soRestoreBackground(g, obj, bd, flag),
    }
}

// @orig 1020:03ff scene_object_restore_background
/// SAUNA's is the opaque `dib_copy_rect` (no colour key), as TIRO's.
fn soRestoreBackground(g: *Game, obj: *Object, bd: *Backdrop, flag: i16) void {
    _ = flag;
    const h = position.height(obj);
    const w = position.width(obj);
    const bg = bd.background orelse return;
    if (bd.pixels.len == 0) return;
    _ = dib.copyRect(&bd.bmiHeader, bd.pixels, obj.x, obj.y, bg.bits, &bg.header, obj.x, obj.y, w, h, g.fixes) catch |e| blitFailed(e);
}

/// BitBlt(pixels, x, y, w, h, pixels2, x, y, SRCCOPY): the dotted background
/// (hdc2) onto the working bitmap (hdc), clipped to the bitmaps.
pub fn bitBlt(bd: *Backdrop, x: i16, y: i16, w: i16, h: i16) void {
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

// @orig 1080:173c ghost_restore_background
/// Ghost's override of slot 19: the rectangle covering the previous and the
/// current position plus one step is marked dirty (relative to the object),
/// then BitBlt'ed from the dotted background.
fn ghostRestoreBackground(g: *Game, obj: *Object, bd: *Backdrop) void {
    const x = @min(obj.mover.prevX, obj.x);
    const y = @min(obj.mover.prevY, obj.y);
    const w = position.getStepX(g, obj) +% position.width(obj);
    const h = position.getStepY(g, obj) +% position.height(obj);
    addDirtyRect(g, obj, x -% obj.x, y -% obj.y, w, h);
    bitBlt(bd, x, y, w, h);
}

/// `g_maze[row * 0x29 + col]` as the flat DGROUP array (a cell past the
/// array reads as 0: the original would read the data after it).
fn mazeAt(g: *Game, row: i16, col: i16) i8 {
    const flat: []const u8 = std.mem.asBytes(&g.maze);
    const i: i32 = @as(i32, row) * 0x29 + @as(i32, col);
    if (i < 0 or i >= flat.len) return 0;
    return @bitCast(flat[@intCast(i)]);
}

fn mazeSet(g: *Game, row: i16, col: i16, c: u8) void {
    const flat: []u8 = std.mem.asBytes(&g.maze);
    const i: i32 = @as(i32, row) * 0x29 + @as(i32, col);
    if (i < 0 or i >= flat.len) return;
    flat[@intCast(i)] = c;
}

/// `v / 16` as the 16-bit `(v + (v >> 15 & 15)) >> 4`: truncating.
fn cell(v: i16) i16 {
    return @divTrunc(v, 16);
}

// @orig 1080:0d05 pacman_restore_background
/// Pacman's override of slot 19, called by `mover_place_at` after
/// `setPosition`. The restore rectangle of the Ghost's, marked dirty first;
/// then the dot test on the four cells at the top left of the position,
/// the first holding a '2' or '3' (default (20, 14), a blank):
/// (x>>4, y>>4), (x>>4, (y+16)>>4), ((x+16)>>4, y>>4), ((x+16)>>4, (y+16)>>4).
/// A peanut ('2'): cleared from the maze, `--g_dotsLeft`, `g_peanut` moved
/// to (16 col + 8, 16 row + 10), `sauna_eat_peanut`, the dot erased from the
/// second bitmap, `g_peanut` reset and invalidated. A cork ('3'): the same
/// with `g_cork` and `sauna_power_waves`, then `g_powerStrip = 4` and
/// `g_powerStartPending = 1`. Then the BitBlt, and at no dot left
/// SendMessage(WM_DESTROY, 0xffff): the win.
///
/// The test reads the object's own `x`/`y` (vbase + 0x12/0x14, the position
/// `mover_place_at` has just set through setPosition, which first copies
/// them to `prevX`/`prevY`), so Pacman eats the dot he steps onto.
fn pacmanRestoreBackground(g: *Game, obj: *Object, bd: *Backdrop) void {
    const rx = @min(obj.mover.prevX, obj.x);
    const ry = @min(obj.mover.prevY, obj.y);
    const rw = position.getStepX(g, obj) +% position.width(obj);
    const rh = position.getStepY(g, obj) +% position.height(obj);
    addDirtyRect(g, obj, rx -% obj.x, ry -% obj.y, rw, rh);

    const px = obj.x;
    const py = obj.y;
    var dot_col: i16 = 0x14;
    var dot_row: i16 = 0xe;
    if (mazeAt(g, cell(py), cell(px)) >= '2') {
        dot_col = cell(px);
        dot_row = cell(py);
    } else if (mazeAt(g, cell(py +% 0x10), cell(px)) >= '2') {
        dot_col = cell(px);
        dot_row = cell(py +% 0x10);
    } else if (mazeAt(g, cell(py), cell(px +% 0x10)) >= '2') {
        dot_col = cell(px +% 0x10);
        dot_row = cell(py);
    } else if (mazeAt(g, cell(py +% 0x10), cell(px +% 0x10)) > '1') {
        dot_col = cell(px +% 0x10);
        dot_row = cell(py +% 0x10);
    }
    const ch = mazeAt(g, dot_row, dot_col);
    if (ch == '2') {
        mazeSet(g, dot_row, dot_col, ' ');
        g.dotsLeft -%= 1;
        const pn = g.peanut.?;
        pn.x = dot_col *% 0x10 +% 8;
        pn.y = dot_row *% 0x10 +% 10;
        score.eatPeanut(g, bd);
        eraseDot(g, bd, pn);
        resetRects(pn);
        visibility.invalidate(g, pn);
    } else if (ch == '3') {
        mazeSet(g, dot_row, dot_col, ' ');
        g.dotsLeft -%= 1;
        const ck = g.cork.?;
        ck.x = dot_col *% 0x10 +% 8;
        ck.y = dot_row *% 0x10 +% 10;
        score.powerWaves(g);
        eraseDot(g, bd, ck);
        resetRects(ck);
        visibility.invalidate(g, ck);
        g.powerStrip = 4;
        g.powerStartPending = 1;
    }
    bitBlt(bd, rx, ry, rw, rh);
    if (g.dotsLeft == 0) {
        _ = g.send(.{ .id = msg.wm.destroy, .wparam = 0xffff });
    }
}

/// The dot picture's rectangle copied from the clean background into the
/// second bitmap (`bits2`), colour key `g_transparentColor`.
pub fn eraseDot(g: *Game, bd: *Backdrop, dot: *Object) void {
    const h = position.height(dot);
    const w = position.width(dot);
    const bg = bd.background orelse return;
    if (bd.pixels2.len == 0) return;
    _ = dib.copyTransparent(&bd.bmiHeader, bd.pixels2, dot.x, dot.y, bg.bits, &bg.header, dot.x, dot.y, w, h, key(g)) catch |e| blitFailed(e);
}

/// SceneObject slot 1A drawDirtyTo: mover_draw_dirty_to (pacman, ghost) / SceneObject's.
pub fn drawDirtyTo(g: *Game, obj: *Object, dst_hdr: *const BitmapInfoHeader, dst_bits: []u8) void {
    switch (obj.kind) {
        .pacman, .ghost => moverDrawDirtyTo(g, obj, dst_hdr, dst_bits),
        .dot, .control_panel => soDrawDirtyTo(g, obj, dst_hdr, dst_bits),
    }
}

// @orig 1020:08fa scene_object_draw_dirty_to
/// The dirty rectangle of the current frame, drawn at (x + dirtyX, y + dirtyY).
/// (An `id == 0x11` test only stores 0x11 back.) The RLE branch is dead.
fn soDrawDirtyTo(g: *Game, obj: *Object, dst_hdr: *const BitmapInfoHeader, dst_bits: []u8) void {
    if (isRle(g, obj)) rleDead();
    const d = obj.dirty;
    const orient: i16 = @truncate(obj.dibFormatOk);
    const h = orient *% d.bottom;
    const y_src = position.frameSrcY(obj) +% d.top;
    const x_src = position.frameSrcX(obj) +% d.left;
    const src = position.dib(obj) orelse return;
    if (dst_bits.len == 0) return;
    _ = dib.copyTransparent(dst_hdr, dst_bits, d.left +% obj.x, d.top +% obj.y, src.bits, &src.header, x_src, y_src, d.right, h, key(g)) catch |e| blitFailed(e);
}

// @orig 1020:0a7e mover_draw_dirty_to
/// Mover's override: the whole current frame at (x, y), ignoring the dirty
/// rectangle (and without the RLE test).
fn moverDrawDirtyTo(g: *Game, obj: *Object, dst_hdr: *const BitmapInfoHeader, dst_bits: []u8) void {
    const orient: i16 = @truncate(obj.dibFormatOk);
    const h = orient *% position.height(obj);
    const w = position.width(obj);
    const y_src = position.frameSrcY(obj);
    const x_src = position.frameSrcX(obj);
    const src = position.dib(obj) orelse return;
    if (dst_bits.len == 0) return;
    _ = dib.copyTransparent(dst_hdr, dst_bits, obj.x, obj.y, src.bits, &src.header, x_src, y_src, w, h, key(g)) catch |e| blitFailed(e);
}

/// SceneObject slot 1B draw: control_panel_draw (panel), player2d_draw (pacman), animation_draw (ghost) / SceneObject's.
pub fn draw(g: *Game, obj: *Object, bd: *Backdrop) void {
    switch (obj.kind) {
        .pacman => player2dDraw(g, obj, bd),
        .ghost => animationDraw(g, obj, bd),
        .control_panel => panels.draw(g, obj, bd),
        .dot => soDraw(g, obj, bd),
    }
}

// @orig 10a0:374c scene_object_draw
fn soDraw(g: *Game, obj: *Object, bd: *Backdrop) void {
    drawDirtyTo(g, obj, &bd.bmiHeader, bd.pixels);
}

// @orig 1020:27ae player2d_draw
fn player2dDraw(g: *Game, obj: *Object, bd: *Backdrop) void {
    animationDraw(g, obj, bd);
}

// @orig 10a0:2350 animation_draw
fn animationDraw(g: *Game, obj: *Object, bd: *Backdrop) void {
    drawDirtyTo(g, obj, &bd.bmiHeader, bd.pixels);
}

/// SceneObject slot 1C unk18 (ENCAIXE's: drawDirtyTo into the backdrop's second bitmap).
// @orig 10a0:3788 scene_object_unk18
pub fn unk18(g: *Game, obj: *Object, bd: *Backdrop) void {
    drawDirtyTo(g, obj, &bd.bmiHeader, bd.pixels2);
}

/// SceneObject slot 1D drawClipTo.
pub fn drawClipTo(g: *Game, obj: *Object, dst_hdr: *const BitmapInfoHeader, dst_bits: []u8) void {
    soDrawClipTo(g, obj, dst_hdr, dst_bits);
}

// @orig 1020:06f1 scene_object_draw_clip_to
/// The clip rectangle of the current frame, drawn at (x + clipX, y + clipY).
/// The RLE branch is dead.
fn soDrawClipTo(g: *Game, obj: *Object, dst_hdr: *const BitmapInfoHeader, dst_bits: []u8) void {
    if (isRle(g, obj)) rleDead();
    const c = obj.clip;
    const orient: i16 = @truncate(obj.dibFormatOk);
    const h = orient *% c.bottom;
    const y_src = position.frameSrcY(obj) +% c.top;
    const x_src = position.frameSrcX(obj) +% c.left;
    const src = position.dib(obj) orelse return;
    if (dst_bits.len == 0) return;
    _ = dib.copyTransparent(dst_hdr, dst_bits, c.left +% obj.x, c.top +% obj.y, src.bits, &src.header, x_src, y_src, c.right, h, key(g)) catch |e| blitFailed(e);
}

/// SceneObject slot 1E drawClip.
// @orig 10a0:37c4 scene_object_draw_clip
pub fn drawClip(g: *Game, obj: *Object, bd: *Backdrop) void {
    drawClipTo(g, obj, &bd.bmiHeader, bd.pixels);
}

/// SceneObject slot 1F erase: animation_erase (panel, pacman, ghost) / SceneObject's.
pub fn erase(g: *Game, obj: *Object, bd: *Backdrop) void {
    switch (obj.kind) {
        .pacman, .ghost, .control_panel => animationErase(g, obj, bd),
        .dot => soErase(g, obj, bd),
    }
}

// @orig 10a0:3800 scene_object_erase
fn soErase(g: *Game, obj: *Object, bd: *Backdrop) void {
    restoreBackground(g, obj, bd, 1);
}

// @orig 10a0:23a8 animation_erase
fn animationErase(g: *Game, obj: *Object, bd: *Backdrop) void {
    restoreBackground(g, obj, bd, 1);
}

/// SceneObject slot 20 slot1F: animation_slot1f (panel, pacman, ghost) / default.
pub fn slot1F(g: *Game, obj: *Object, bd: *Backdrop) void {
    _ = g;
    switch (obj.kind) {
        .pacman, .ghost, .control_panel => animationSlot1f(obj, bd),
        .dot => slot1fDefault(obj, bd),
    }
}

// @orig 10a0:23f2 animation_slot1f
fn animationSlot1f(obj: *Object, bd: *Backdrop) void {
    dcHook(obj, 1, bd);
}

// @orig 10a0:382e scene_object_slot1f_default (absorbed)
fn slot1fDefault(obj: *Object, bd: *Backdrop) void {
    dcHook(obj, 1, bd);
}

// @orig 1020:03d7 scene_object_dc_hook
fn dcHook(obj: *Object, flag: i16, bd: *Backdrop) void {
    _ = obj;
    _ = flag;
    _ = bd; // passes backdrop.hdc (no counterpart) to the empty hook
    emptyDcHook();
}

// @orig 1020:03ab scene_object_empty_dc_hook
fn emptyDcHook() void {}
