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
//!   `messageBuf` (an overflow of DGROUP, BUGS.md L6); here it is truncated
//!   to 99 bytes.
//! - `flush` blits `dirty.right` x `dirty.bottom` pixels: the original reads
//!   those two fields (SceneObject+0x46c/+0x46e, named dirtyW/dirtyH) as the
//!   width and height, whatever `dirty.left/top` are.
//! - The WinGBitBlt and the palette realize are the platform's
//!   (`plat.wingBitBlt` from `bd.surface()`, `plat.realizePalette`); the
//!   source coordinates are scene coordinates in the background-sized WinG
//!   bitmap (docs/DESIGN.md "Backdrop").

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
    _ = plat.realizePalette(&bd.bmiColors);
    var i: usize = 0;
    while (i < @as(usize, @intCast(@max(list.count, 0)))) : (i += 1) {
        const obj = list.items[i].?;
        plat.wingBitBlt(obj.x -% bd.originX +% obj.dirty.left, obj.y -% bd.originY +% obj.dirty.top, obj.dirty.right, obj.dirty.bottom, bd.surface(), obj.x +% obj.dirty.left, obj.y +% obj.dirty.top);
        obj.queued = 0;
        frames.resetRects(obj);
    }
    list.count = 0;
}
