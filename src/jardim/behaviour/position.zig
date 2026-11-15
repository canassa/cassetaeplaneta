//! Port unit `position` (behaviour) of JARDIM.EXE. SceneObject slots 00-04 (slot00/01, RLE, scene name), 0D-11 getX/getY/getStep, 3E setPosition, 3F/40 scroll target, 54-57 overlaps, 5A/5B exit slots, 5C-60 defaults; the out-of-line accessors; next_object_id, message_box_printf.
//!
//! Virtual-slot dispatchers owned by this unit are declared below with
//! their final signatures; their bodies panic until the unit is ported
//! (docs/jardim/DESIGN.md "Virtual slots"). Replace each body, keep the
//! signature (other units already call it). Each implementation function
//! carries `// @orig <seg:xxxx> <name>` with the JARDIM address.

const std = @import("std");
const ini = @import("../../ini.zig");
const cstr = @import("../../core/cstr.zig");
const Game = @import("../core/game.zig").Game;
const object = @import("../core/object.zig");
const Object = object.Object;
const Frame = object.Frame;
const world = @import("../core/world.zig");
const Condition = world.Condition;
const game_unit = @import("../game.zig");

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
/// original is varargs (far cdecl); every caller passes one dword or a string.
// @orig 1020:063f message_box_printf
pub fn messageBoxPrintf(g: *Game, caption: []const u8, fmt: []const u8, arg: anytype) void {
    ini.messageBoxPrintf(g.plat, &g.messageText, caption, fmt, arg);
}

/// The next SceneObject serial number: returns `g_nextId`, then increments it.
// @orig 1038:0000 next_object_id
pub fn nextObjectId(g: *Game) i16 {
    const id = g.nextId;
    g.nextId +%= 1;
    return id;
}

// ---- the /Od out-of-line accessors ----

/// The current strip's Frame: `frames + curStrip * 0x1a`.
// @orig 10c0:2f32 scene_object_cur_strip
pub fn curStrip(obj: *Object) *Frame {
    return &obj.frames[@intCast(obj.curStrip)];
}

// @orig 10c0:45d2 scene_object_width
pub fn width(obj: *Object) i16 {
    return curStrip(obj).width;
}

// @orig 10c0:45fc scene_object_height
pub fn height(obj: *Object) i16 {
    return curStrip(obj).height;
}

// @orig 10c0:4a64 scene_object_hit_x
pub fn hitX(obj: *Object) i16 {
    return curStrip(obj).hitX;
}

// @orig 10c0:4a8e scene_object_hit_y
pub fn hitY(obj: *Object) i16 {
    return curStrip(obj).hitY;
}

// @orig 10c0:4686 scene_object_hit_w
pub fn hitW(obj: *Object) i16 {
    return curStrip(obj).hitW;
}

// @orig 10c0:46b0 scene_object_hit_h
pub fn hitH(obj: *Object) i16 {
    return curStrip(obj).hitH;
}

// @orig 10c0:46da scene_object_frame_count
pub fn frameCount(obj: *Object) i16 {
    return curStrip(obj).count;
}

/// The DIB of the current strip.
// @orig 10c0:45a4 scene_object_dib
pub fn dib(obj: *Object) ?*object.Dib {
    return curStrip(obj).dib;
}

/// x of frame `index` in the strip bitmap: always 0 (frames are stacked).
// @orig 10c0:479c frame_cell_x
pub fn frameCellX(frame: *Frame, index: i16) i16 {
    _ = frame;
    _ = index;
    return 0;
}

/// y of frame `index` in the strip bitmap: `height * index` (16-bit).
// @orig 10c0:47b6 frame_cell_y
pub fn frameCellY(frame: *Frame, index: i16) i16 {
    return frame.height *% index;
}

// @orig 10c0:4626 scene_object_frame_src_x
pub fn frameSrcX(obj: *Object) i16 {
    return frameCellX(curStrip(obj), obj.curFrame);
}

// @orig 10c0:4656 scene_object_frame_src_y
pub fn frameSrcY(obj: *Object) i16 {
    return frameCellY(curStrip(obj), obj.curFrame);
}

/// Sets +0x49a (isEnemy) to 1; called by the phase scenes' creates.
// @orig 10c0:854c scene_object_set_play_once_rewinds
pub fn setPlayOnceRewinds(obj: *Object) void {
    obj.isEnemy = 1;
}

/// SceneObject slot 00 slot00: marks the object (+0x48e = 1).
pub fn slot00(g: *Game, obj: *Object) void {
    _ = g;
    // @orig 10c0:3394 scene_object_slot00_default (absorbed)
    obj.slot00Flag = 1;
}

/// SceneObject slot 01 slot01: reads the mark.
pub fn slot01(g: *Game, obj: *Object) i16 {
    _ = g;
    // @orig 10c0:33b4 scene_object_slot01_default (absorbed)
    return obj.slot00Flag;
}

/// SceneObject slot 02 enableRle: RLE drawing on; `rleBits` is the current
/// strip's pixels (dib + biSize + biClrUsed*4) and the header height is made
/// negative (16-bit abs and neg, sign-extended).
// @orig 1038:0813 scene_object_enable_rle
pub fn enableRle(g: *Game, obj: *Object) void {
    _ = g;
    obj.rleFlag = 1;
    const d = dib(obj).?;
    obj.rleBits = d.bits;
    const lo: i16 = @truncate(obj.bmiHeader.biHeight);
    obj.bmiHeader.biHeight = 0 -% abs16(lo);
}

/// SceneObject slot 03 isRle.
// @orig 10c0:33d2 scene_object_is_rle
pub fn isRle(g: *Game, obj: *Object) bool {
    _ = g;
    return obj.rleFlag != 0;
}

/// SceneObject slot 04 getSceneName: `this + 0x478`.
// @orig 10c0:33f0 scene_object_get_scene_name
pub fn getSceneName(g: *Game, obj: *Object) []const u8 {
    _ = g;
    return cstr.slice(&obj.sceneName);
}

/// SceneObject slot 0D getX: mover_get_x (portable, player) / SceneObject's.
pub fn getX(g: *Game, obj: *Object) i16 {
    _ = g;
    return switch (obj.kind) {
        // @orig 10c0:1bc2 mover_get_x
        .portable, .player => obj.mover.prevX,
        // @orig 10c0:34e0 scene_object_get_x
        else => obj.x,
    };
}

/// SceneObject slot 0E getY.
pub fn getY(g: *Game, obj: *Object) i16 {
    _ = g;
    return switch (obj.kind) {
        // @orig 10c0:1be0 mover_get_y
        .portable, .player => obj.mover.prevY,
        // @orig 10c0:34fe scene_object_get_y
        else => obj.y,
    };
}

/// SceneObject slot 0F getStepX: mover_get_step_x (portable, player) / default.
pub fn getStepX(g: *Game, obj: *Object) i16 {
    _ = g;
    return switch (obj.kind) {
        // @orig 10c0:1bfe mover_get_step_x
        .portable, .player => abs16(obj.mover.stepX),
        // @orig 10c0:351c scene_object_get_step_x_default (absorbed)
        else => 0,
    };
}

/// SceneObject slot 10 getStepY.
pub fn getStepY(g: *Game, obj: *Object) i16 {
    _ = g;
    return switch (obj.kind) {
        // @orig 10c0:1c24 mover_get_step_y
        .portable, .player => abs16(obj.mover.stepY),
        // @orig 10c0:3536 scene_object_get_step_y_default (absorbed)
        else => 0,
    };
}

/// SceneObject slot 11 slot11 (default only).
pub fn slot11(g: *Game, obj: *Object, arg1: i16, arg2: i16) i16 {
    _ = g;
    _ = obj;
    _ = arg1;
    _ = arg2;
    // @orig 10c0:3550 scene_object_slot11_default (absorbed)
    return 0;
}

/// SceneObject slot 3E setPosition: moveable_set_position (portable, player) / SceneObject's.
pub fn setPosition(g: *Game, obj: *Object, x: i16, y: i16) void {
    _ = g;
    switch (obj.kind) {
        // @orig 10c0:24c4 moveable_set_position
        // @orig 10c0:1b50 mover_set_position
        .portable, .player => {
            obj.mover.prevX = obj.x;
            obj.mover.prevY = obj.y;
            obj.x = x;
            obj.y = y;
        },
        // @orig 10c0:3ade scene_object_set_position
        else => {
            obj.x = x;
            obj.y = y;
        },
    }
}

/// SceneObject slot 3F isScrollTarget: player_is_scroll_target (player) / SceneObject's.
pub fn isScrollTarget(g: *Game, obj: *Object) bool {
    _ = g;
    return switch (obj.kind) {
        // @orig 10c0:270a player_is_scroll_target
        .player => true,
        // @orig 10c0:3b1e scene_object_is_scroll_target
        else => false,
    };
}

/// SceneObject slot 40 slot43 (default only: NULL).
pub fn slot43(g: *Game, obj: *Object) ?*anyopaque {
    _ = g;
    _ = obj;
    // @orig 10c0:3b38 scene_object_slot43_default (absorbed)
    return null;
}

/// SceneObject slot 54 hitboxOverlaps.
// @orig 1038:0f26 scene_object_hitbox_overlaps
pub fn hitboxOverlaps(g: *Game, obj: *Object, other: *Object) bool {
    _ = g;
    if (add(add(hitX(obj), hitW(obj)), obj.x) < add(hitX(other), other.x)) return false;
    if (add(add(hitX(other), hitW(other)), other.x) < add(hitX(obj), obj.x)) return false;
    if (add(add(hitY(obj), hitH(obj)), obj.y) < add(hitY(other), other.y)) return false;
    if (add(add(hitY(other), hitH(other)), other.y) < add(hitY(obj), obj.y)) return false;
    return true;
}

/// SceneObject slot 55 boundsOverlap.
// @orig 1038:103b scene_object_bounds_overlap
pub fn boundsOverlap(g: *Game, obj: *Object, other: *Object) bool {
    _ = g;
    if (add(width(obj), obj.x) < other.x) return false;
    if (add(width(other), other.x) < obj.x) return false;
    if (add(height(obj), obj.y) < other.y) return false;
    if (add(height(other), other.y) < obj.y) return false;
    return true;
}

/// SceneObject slot 56 slot5B (default only).
pub fn slot5B(g: *Game, obj: *Object, arg: ?*anyopaque) i16 {
    _ = g;
    _ = obj;
    _ = arg;
    // @orig 10c0:3d54 scene_object_slot5b_default (absorbed)
    return 0;
}

/// SceneObject slot 57 slot5C (default only).
pub fn slot5C(g: *Game, obj: *Object, arg: ?*anyopaque) i16 {
    _ = g;
    _ = obj;
    _ = arg;
    // @orig 10c0:3d3a scene_object_slot5c_default (absorbed)
    return 0;
}

/// SceneObject slot 5A isEnabled: exit_is_enabled (exit) / default.
pub fn isEnabled(g: *Game, obj: *Object) bool {
    _ = g;
    return switch (obj.kind) {
        // @orig 10c0:278a exit_is_enabled
        .exit => blk: {
            const raw = obj.exit.condition orelse break :blk false;
            const cond: *const Condition = @ptrCast(@alignCast(raw));
            break :blk game_unit.evaluate(cond) != 0;
        },
        // @orig 10c0:3da4 scene_object_is_enabled_default (absorbed)
        else => false,
    };
}

/// SceneObject slot 5B getExitIndex: exit_get_exit_index (exit) / default.
pub fn getExitIndex(g: *Game, obj: *Object) i16 {
    _ = g;
    return switch (obj.kind) {
        // @orig 10c0:2808 exit_get_exit_index
        .exit => obj.exit.exitIndex,
        // @orig 10c0:3dbe scene_object_get_exit_index_default (absorbed)
        else => -1,
    };
}

/// SceneObject slot 5C slot61 (default only).
pub fn slot61(g: *Game, obj: *Object) i16 {
    _ = g;
    _ = obj;
    // @orig 10c0:3dd8 scene_object_slot61_default (absorbed)
    return 0;
}

/// SceneObject slot 5D slot62 (default only).
pub fn slot62(g: *Game, obj: *Object) i16 {
    _ = g;
    _ = obj;
    // @orig 10c0:3df2 scene_object_slot62_default (absorbed)
    return 0;
}

/// SceneObject slot 5E slot63 (default only).
pub fn slot63(g: *Game, obj: *Object) i16 {
    _ = g;
    _ = obj;
    // @orig 10c0:3e0c scene_object_slot63_default (absorbed)
    return 0;
}

/// SceneObject slot 5F slot64 (default only).
pub fn slot64(g: *Game, obj: *Object) i16 {
    _ = g;
    _ = obj;
    // @orig 10c0:3e26 scene_object_slot64_default (absorbed)
    return 0;
}

/// SceneObject slot 60 slot65 (default only).
pub fn slot65(g: *Game, obj: *Object) i16 {
    _ = g;
    _ = obj;
    // @orig 10c0:3e40 scene_object_slot65_default (absorbed)
    return 0;
}

test "position basics" {
    var g: Game = undefined;
    var o: Object = .{ .kind = .player, .x = 3, .y = 4 };
    setPosition(&g, &o, 10, 20);
    try std.testing.expectEqual(@as(i16, 3), getX(&g, &o));
    try std.testing.expectEqual(@as(i16, 4), getY(&g, &o));
    o.mover.stepX = -5;
    try std.testing.expectEqual(@as(i16, 5), getStepX(&g, &o));
    o.kind = .scene_object;
    try std.testing.expectEqual(@as(i16, 10), getX(&g, &o));
    try std.testing.expectEqual(@as(i16, 0), getStepY(&g, &o));
    try std.testing.expectEqual(@as(i16, -1), getExitIndex(&g, &o));
}
