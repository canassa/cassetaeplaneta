//! Port unit `update_list` (module). the screen update list (objects to blit, max 100).
//!
//! `world.UpdateList` holds the objects whose dirty rectangle must be copied
//! from the backdrop's offscreen buffer to the screen on the next flush.
//! Each object is queued at most once (`queued`, `queueIndex`).
//!
//! Faithful behaviours worth knowing:
//! - `add` on a full list (100) shows the "Erro Fatal!!" box and does not
//!   queue the object; it still returns `count - 1` (the last entry's index).
//!   The original formats the 111-byte text into the 100-byte shared
//!   `messageBuf` (an overflow of DGROUP); here it is truncated to 99 bytes.
//! - `flush` blits `dirty.right` x `dirty.bottom` pixels: the original reads
//!   those two fields (SceneObject+0x46c/+0x46e, named dirtyW/dirtyH) as the
//!   width and height, whatever `dirty.left/top` are.
//! - The WinG offscreen buffer is addressed through `Backdrop.dibOrientation`
//!   (1 bottom-up, -1 top-down) with rows padded to 4 bytes; the platform
//!   screen stands in for the window DC. SelectPalette + RealizePalette
//!   become "the screen palette is the backdrop's colour table".

const std = @import("std");
const Game = @import("core/game.zig").Game;
const object = @import("core/object.zig");
const Object = object.Object;
const world = @import("core/world.zig");
const Backdrop = world.Backdrop;
const UpdateList = world.UpdateList;
const frames = @import("frames.zig");
const ini = @import("ini.zig");
const Platform = @import("platform/platform.zig").Platform;
const platform = @import("platform/platform.zig");

/// Latin-1, as in the original's code segment (1010:9378 / 1010:936a).
const msg_full = "N\xe3o foi pos\xedvel inserir um objeto na lista de atualiza\xe7\xf5es de tela\r\nAumente o valor da constante MAX_OBJECT_QTY";
const caption_fatal = "Erro Fatal!!";

/// Sets the count to 0.
// @orig 1010:e2d0 update_list_ctor
pub fn ctor(list: *UpdateList) *UpdateList {
    list.count = 0;
    return list;
}

/// Queues `obj` for the next screen update, once: appends it and sets its
/// queued flag and index. Returns the object's index in the list. A full
/// list shows the fatal box and returns `count - 1` without queueing.
// @orig 1010:313c update_list_add
pub fn add(list: *UpdateList, plat: Platform, msg_buf: []u8, obj: *Object) i16 {
    if (obj.queued != 0) return obj.queueIndex;
    if (list.count == world.max_update) {
        ini.messageBoxPrintf(plat, msg_buf, caption_fatal, msg_full, 0);
    } else {
        list.items[@intCast(list.count)] = obj;
        obj.queued = 1;
        obj.queueIndex = list.count;
        list.count +%= 1;
    }
    return list.count -% 1;
}

/// Empties the list without drawing: clears each object's queued flag and
/// resets its rectangles.
// @orig 1010:e2f0 update_list_discard
pub fn discard(list: *UpdateList) void {
    var i: usize = 0;
    while (i < @as(usize, @intCast(@max(list.count, 0)))) : (i += 1) {
        const obj = list.items[i].?;
        obj.queued = 0;
        frames.resetRects(obj);
    }
    list.count = 0;
}

/// True if the list holds no objects.
// @orig 1010:e346 update_list_is_empty
pub fn isEmpty(list: *const UpdateList) bool {
    return list.count == 0;
}

/// Realizes the backdrop's palette on the screen, then blits each listed
/// object's dirty rectangle from the backdrop's buffer to the screen
/// (view-relative), clears the object's queued flag and rectangles, and
/// empties the list. (hdc is the platform screen.)
// @orig 1010:e362 update_list_flush
pub fn flush(list: *UpdateList, plat: Platform, bd: *const Backdrop) void {
    const scr = plat.screen();
    for (&scr.palette, bd.bmiColors) |*p, c| p.* = .{ .r = c.red, .g = c.green, .b = c.blue };
    var i: usize = 0;
    while (i < @as(usize, @intCast(@max(list.count, 0)))) : (i += 1) {
        const obj = list.items[i].?;
        blit(scr, bd, obj.x -% bd.originX +% obj.dirty.left, obj.y -% bd.originY +% obj.dirty.top, obj.dirty.right, obj.dirty.bottom, obj.x +% obj.dirty.left, obj.y +% obj.dirty.top);
        obj.queued = 0;
        frames.resetRects(obj);
    }
    list.count = 0;
}

/// WinGBitBlt(screen, dx, dy, w, h, backdrop, sx, sy): SRCCOPY, clipped to
/// the screen and to the backdrop's buffer.
fn blit(scr: *platform.Screen, bd: *const Backdrop, dx: i16, dy: i16, w: i16, h: i16, sx: i16, sy: i16) void {
    const bw: i32 = bd.viewWidth;
    const bh: i32 = bd.viewHeight;
    if (bw <= 0 or bh <= 0) return;
    const stride: usize = @intCast((bw + 3) & ~@as(i32, 3));
    var row: i32 = 0;
    while (row < h) : (row += 1) {
        const y = @as(i32, dy) + row;
        const syr = @as(i32, sy) + row;
        if (y < 0 or y >= platform.screen_height or syr < 0 or syr >= bh) continue;
        const srow: usize = @intCast(if (bd.dibOrientation < 0) syr else bh - 1 - syr);
        var col: i32 = 0;
        while (col < w) : (col += 1) {
            const x = @as(i32, dx) + col;
            const sxc = @as(i32, sx) + col;
            if (x < 0 or x >= platform.screen_width or sxc < 0 or sxc >= bw) continue;
            const si = srow * stride + @as(usize, @intCast(sxc));
            if (si >= bd.pixels.len) continue;
            scr.pixels[@as(usize, @intCast(y)) * platform.screen_width + @as(usize, @intCast(x))] = bd.pixels[si];
        }
    }
}
