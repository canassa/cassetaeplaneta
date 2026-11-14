//! Port unit `position` (behaviour) of INV.EXE. SceneObject slots 08-0C getX/getY/getStep, 39 setPosition, 4C unk4E, 4E/4F overlap tests, 50/51 54/55 defaults; the /Od out-of-line accessors (hit box, frame, size); next_object_id.
//!
//! Virtual-slot dispatchers owned by this unit are declared below with
//! their final signatures; their bodies panic until the unit is ported
//! (docs/inv/DESIGN.md "Virtual slots"). Replace each body, keep the
//! signature (other units already call it). Each implementation function
//! carries `// @orig <seg:xxxx> <name>` with the INV address.

const std = @import("std");
const ini = @import("../../ini.zig");
const Game = @import("../core/game.zig").Game;
const object = @import("../core/object.zig");
const Object = object.Object;
const ObjectList = object.ObjectList;
const Frame = object.Frame;
const FrameCell = object.FrameCell;
const BitmapInfoHeader = object.BitmapInfoHeader;
const world = @import("../core/world.zig");
const Backdrop = world.Backdrop;
const Scene = world.Scene;
const Condition = world.Condition;
const RectQuery = world.RectQuery;

/// Wrapping 16-bit add (the original's `ADD`).
fn add(a: i16, b: i16) i16 {
    return a +% b;
}

/// abs as the original computes it: `(v ^ (v >> 15)) - (v >> 15)`.
fn abs16(v: i16) i16 {
    const s = v >> 15;
    return (v ^ s) -% s;
}

/// `sprintf(g_messageText, fmt, arg)` then a MB_ICONEXCLAMATION box. The
/// original is varargs; every caller passes one word (0) or a string.
// @orig 1038:057f message_box_printf
pub fn messageBoxPrintf(g: *Game, caption: []const u8, fmt: []const u8, arg: anytype) void {
    ini.messageBoxPrintf(g.plat, &g.messageText, caption, fmt, arg);
}

/// The next SceneObject serial number: returns `g_nextId`, then increments it.
// @orig 1028:0000 next_object_id
pub fn nextObjectId(g: *Game) i16 {
    const id = g.nextId;
    g.nextId +%= 1;
    return id;
}

// ---- the /Od out-of-line accessors (ENCAIXE inlines them) ----

/// The current strip's Frame: `frames + curStrip * 0x16`.
// @orig 1088:3030 scene_object_cur_strip
pub fn curStrip(obj: *Object) *Frame {
    return &obj.frames[@intCast(obj.curStrip)];
}

// @orig 1088:3050 scene_object_width
pub fn width(obj: *Object) i16 {
    return curStrip(obj).width;
}

// @orig 1088:3074 scene_object_height
pub fn height(obj: *Object) i16 {
    return curStrip(obj).height;
}

// @orig 1088:152c scene_object_hit_x
pub fn hitX(obj: *Object) i16 {
    return curStrip(obj).hitX;
}

// @orig 1088:1550 scene_object_hit_y
pub fn hitY(obj: *Object) i16 {
    return curStrip(obj).hitY;
}

// @orig 1088:14e4 scene_object_hit_w
pub fn hitW(obj: *Object) i16 {
    return curStrip(obj).hitW;
}

// @orig 1088:1508 scene_object_hit_h
pub fn hitH(obj: *Object) i16 {
    return curStrip(obj).hitH;
}

// @orig 1088:1574 scene_object_frame_count
pub fn frameCount(obj: *Object) i16 {
    return curStrip(obj).count;
}

/// The DIB of the current strip.
// @orig 1088:3bb8 scene_object_dib
pub fn dib(obj: *Object) ?*object.Dib {
    return curStrip(obj).dib;
}

/// x of frame `index` in the strip bitmap: always 0 (frames are stacked).
// @orig 1088:3ca0 frame_cell_x
pub fn frameCellX(frame: *Frame, index: i16) i16 {
    _ = frame;
    _ = index;
    return 0;
}

/// y of frame `index` in the strip bitmap: `height * index` (16-bit).
// @orig 1088:3cbc frame_cell_y
pub fn frameCellY(frame: *Frame, index: i16) i16 {
    return frame.height *% index;
}

// @orig 1088:3c32 scene_object_frame_src_x
pub fn frameSrcX(obj: *Object) i16 {
    return frameCellX(curStrip(obj), obj.curFrame);
}

// @orig 1088:3c5a scene_object_frame_src_y
pub fn frameSrcY(obj: *Object) i16 {
    return frameCellY(curStrip(obj), obj.curFrame);
}

/// SceneObject slot 08 getX: mover_get_x (cannon, saucer, bomb, shot, column, explosion) / SceneObject's.
pub fn getX(g: *Game, obj: *Object) i16 {
    _ = g;
    return switch (obj.kind) {
        // @orig 1088:204c mover_get_x
        .cannon, .saucer, .bomb, .shot, .invader_column, .invader_explosion => obj.mover.prevX,
        // @orig 1088:2f34 scene_object_get_x
        else => obj.x,
    };
}

/// SceneObject slot 09 getY.
pub fn getY(g: *Game, obj: *Object) i16 {
    _ = g;
    return switch (obj.kind) {
        // @orig 1088:2068 mover_get_y
        .cannon, .saucer, .bomb, .shot, .invader_column, .invader_explosion => obj.mover.prevY,
        // @orig 1088:2f50 scene_object_get_y
        else => obj.y,
    };
}

/// SceneObject slot 0A getStepX: mover_get_step_x (cannon, saucer, bomb, shot, column, explosion) / default.
pub fn getStepX(g: *Game, obj: *Object) i16 {
    _ = g;
    return switch (obj.kind) {
        // @orig 1088:2084 mover_get_step_x
        .cannon, .saucer, .bomb, .shot, .invader_column, .invader_explosion => abs16(obj.mover.stepX),
        // @orig 1088:2f6c scene_object_get_step_x_default (absorbed)
        else => 0,
    };
}

/// SceneObject slot 0B getStepY.
pub fn getStepY(g: *Game, obj: *Object) i16 {
    _ = g;
    return switch (obj.kind) {
        // @orig 1088:20a8 mover_get_step_y
        .cannon, .saucer, .bomb, .shot, .invader_column, .invader_explosion => abs16(obj.mover.stepY),
        // @orig 1088:2f88 scene_object_get_step_y_default (absorbed)
        else => 0,
    };
}

/// SceneObject slot 0C slot11 (default only).
pub fn slot11(g: *Game, obj: *Object, arg: u16) i16 {
    _ = g;
    _ = obj;
    _ = arg;
    // @orig 1088:14c8 scene_object_slot11_default (absorbed)
    return 0;
}

/// SceneObject slot 39 setPosition: Actor2D's (-> Mover's) / SceneObject's.
pub fn setPosition(g: *Game, obj: *Object, x: i16, y: i16) void {
    _ = g;
    switch (obj.kind) {
        // @orig 1088:24b8 actor2d_set_position
        // @orig 1088:2002 mover_set_position
        .cannon, .saucer, .bomb, .shot, .invader_column, .invader_explosion => {
            obj.mover.prevX = obj.x;
            obj.mover.prevY = obj.y;
            obj.x = x;
            obj.y = y;
        },
        // @orig 1088:1a52 scene_object_set_position
        else => {
            obj.x = x;
            obj.y = y;
        },
    }
}

/// SceneObject slot 4C unk4E (returns the empty string at DGROUP 05e2).
pub fn unk4E(g: *Game, obj: *Object) []const u8 {
    _ = g;
    _ = obj;
    // @orig 1088:1c8a scene_object_unk4e
    return "";
}

/// SceneObject slot 4E hitboxOverlaps.
pub fn hitboxOverlaps(g: *Game, obj: *Object, other: *Object) bool {
    _ = g;
    // @orig 1028:095b scene_object_hitbox_overlaps
    if (add(add(hitX(obj), hitW(obj)), obj.x) < add(hitX(other), other.x)) return false;
    if (add(add(hitX(other), hitW(other)), other.x) < add(hitX(obj), obj.x)) return false;
    if (add(add(hitY(obj), hitH(obj)), obj.y) < add(hitY(other), other.y)) return false;
    if (add(add(hitY(other), hitH(other)), other.y) < add(hitY(obj), obj.y)) return false;
    return true;
}

/// SceneObject slot 4F boundsOverlap.
pub fn boundsOverlap(g: *Game, obj: *Object, other: *Object) bool {
    _ = g;
    // @orig 1028:0a2f scene_object_bounds_overlap
    if (add(width(obj), obj.x) < other.x) return false;
    if (add(width(other), other.x) < obj.x) return false;
    if (add(height(obj), obj.y) < other.y) return false;
    if (add(height(other), other.y) < obj.y) return false;
    return true;
}

/// SceneObject slot 50 slot5B (default only).
pub fn slot5B(g: *Game, obj: *Object, arg: i16) i16 {
    _ = g;
    _ = obj;
    _ = arg;
    // @orig 1088:1cc2 scene_object_slot5b_default (absorbed)
    return 0;
}

/// SceneObject slot 51 slot5C (default only).
pub fn slot5C(g: *Game, obj: *Object, arg: i16) i16 {
    _ = g;
    _ = obj;
    _ = arg;
    // @orig 1088:1ca6 scene_object_slot5c_default (absorbed)
    return 0;
}

/// SceneObject slot 54 isEnabled (default only).
pub fn isEnabled(g: *Game, obj: *Object) bool {
    _ = g;
    _ = obj;
    // @orig 1088:1d16 scene_object_is_enabled_default (absorbed)
    return false;
}

/// SceneObject slot 55 getExitIndex (default only).
pub fn getExitIndex(g: *Game, obj: *Object) i16 {
    _ = g;
    _ = obj;
    // @orig 1088:1d32 scene_object_get_exit_index_default (absorbed)
    return -1;
}

test "position basics" {
    var g: Game = undefined;
    var o: Object = .{ .kind = .cannon, .x = 3, .y = 4 };
    setPosition(&g, &o, 10, 20);
    try std.testing.expectEqual(@as(i16, 3), getX(&g, &o));
    try std.testing.expectEqual(@as(i16, 4), getY(&g, &o));
    o.mover.stepX = -5;
    try std.testing.expectEqual(@as(i16, 5), getStepX(&g, &o));
    o.kind = .status_bar;
    try std.testing.expectEqual(@as(i16, 10), getX(&g, &o));
    try std.testing.expectEqual(@as(i16, 0), getStepY(&g, &o));
}
