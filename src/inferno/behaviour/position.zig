//! Port unit `position` (behaviour) of INFERNO.EXE. SceneObject slots 00-11
//! 38 (Object3D getters/setters: defaults only, INFERNO builds no Object3D),
//! 08-0C getX/getY/getStep, 39 setPosition, 4C getSceneName, 4E/4F overlap
//! tests, 50/51 54/55 defaults; the /Od out-of-line accessors (strip, size,
//! frame, dib); next_object_id, message_box_printf.
//!
//! Virtual-slot dispatchers owned by this unit are declared below with
//! their final signatures; their bodies panic until the unit is ported
//! (docs/inferno/DESIGN.md "Virtual slots"). Replace each body, keep the
//! signature (other units already call it). Each implementation function
//! carries `// @orig <seg:xxxx> <name>` with the INFERNO address.

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

/// abs as the CRT computes it (wraps at -32768).
fn abs16(v: i16) i16 {
    return if (v < 0) 0 -% v else v;
}

/// `sprintf(g_messageText, fmt, arg)` then a MB_ICONEXCLAMATION box. The
/// original (far cdecl: format, arg, caption) is varargs; every caller
/// passes one word (0) or a string.
// @orig 1038:059a message_box_printf
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

// ---- the /Od out-of-line accessors ----

/// The current strip's Frame: `frames + curStrip * 0x12`.
// @orig 1080:4010 scene_object_cur_strip
pub fn curStrip(obj: *Object) *Frame {
    return &obj.frames[@intCast(obj.curStrip)];
}

// @orig 1080:403a scene_object_width
pub fn width(obj: *Object) i16 {
    return curStrip(obj).width;
}

// @orig 1080:4064 scene_object_height
pub fn height(obj: *Object) i16 {
    return curStrip(obj).height;
}

// @orig 1080:20d6 scene_object_frame_count
pub fn frameCount(obj: *Object) i16 {
    return curStrip(obj).count;
}

/// The DIB of the current strip.
// @orig 1080:56a4 scene_object_dib
pub fn dib(obj: *Object) ?*object.Dib {
    return curStrip(obj).dib;
}

/// x of frame `index` in the strip bitmap: always 0 (frames are stacked).
// @orig 1080:5844 frame_cell_x
pub fn frameCellX(frame: *Frame, index: i16) i16 {
    _ = frame;
    _ = index;
    return 0;
}

/// y of frame `index` in the strip bitmap: `height * index` (16-bit).
// @orig 1080:585e frame_cell_y
pub fn frameCellY(frame: *Frame, index: i16) i16 {
    return frame.height *% index;
}

// @orig 1080:573e scene_object_frame_src_x
pub fn frameSrcX(obj: *Object) i16 {
    return frameCellX(curStrip(obj), obj.curFrame);
}

// @orig 1080:576e scene_object_frame_src_y
pub fn frameSrcY(obj: *Object) i16 {
    return frameCellY(curStrip(obj), obj.curFrame);
}

// ---- SceneObject slots: the defaults (absorbed) ----

/// SceneObject slot 00 getWorldX: default only (returns 0).
pub fn getWorldX(g: *Game, obj: *Object) i16 {
    _ = g;
    _ = obj;
    return 0;
}

/// SceneObject slot 01 getWorldDepth: default only.
pub fn getWorldDepth(g: *Game, obj: *Object) i16 {
    _ = g;
    _ = obj;
    return 0;
}

/// SceneObject slot 02 getWorldElev: default only.
pub fn getWorldElev(g: *Game, obj: *Object) i16 {
    _ = g;
    _ = obj;
    return 0;
}

/// SceneObject slot 03 getSizeW: default only.
pub fn getSizeW(g: *Game, obj: *Object) i16 {
    _ = g;
    _ = obj;
    return 0;
}

/// SceneObject slot 04 getSizeH: default only.
pub fn getSizeH(g: *Game, obj: *Object) i16 {
    _ = g;
    _ = obj;
    return 0;
}

/// SceneObject slot 05 getSizeD: default only.
pub fn getSizeD(g: *Game, obj: *Object) i16 {
    _ = g;
    _ = obj;
    return 0;
}

/// SceneObject slot 06 getAnchorX: default only.
pub fn getAnchorX(g: *Game, obj: *Object) i16 {
    _ = g;
    _ = obj;
    return 0;
}

/// SceneObject slot 07 getAnchorY: default only.
pub fn getAnchorY(g: *Game, obj: *Object) i16 {
    _ = g;
    _ = obj;
    return 0;
}

/// SceneObject slot 08 getX: mover_get_x (every live kind is a Mover;
/// the base's scene_object_get_x is dead).
pub fn getX(g: *Game, obj: *Object) i16 {
    _ = g;
    // @orig 1080:2c2e mover_get_x
    return obj.mover.prevX;
}

/// SceneObject slot 09 getY.
pub fn getY(g: *Game, obj: *Object) i16 {
    _ = g;
    // @orig 1080:2c4c mover_get_y
    return obj.mover.prevY;
}

/// SceneObject slot 0A getStepX.
pub fn getStepX(g: *Game, obj: *Object) i16 {
    _ = g;
    // @orig 1080:2c6a mover_get_step_x
    return abs16(obj.mover.stepX);
}

/// SceneObject slot 0B getStepY.
pub fn getStepY(g: *Game, obj: *Object) i16 {
    _ = g;
    // @orig 1080:2c90 mover_get_step_y
    return abs16(obj.mover.stepY);
}

/// SceneObject slot 0C slot11: default only.
pub fn slot11(g: *Game, obj: *Object, arg: u16) i16 {
    _ = g;
    _ = obj;
    _ = arg;
    return 0;
}

/// SceneObject slot 0D setElevation: default only (returns this).
pub fn setElevation(g: *Game, obj: *Object, bd: *Backdrop, elev: i16) ?*Object {
    _ = g;
    _ = bd;
    _ = elev;
    return obj;
}

/// SceneObject slot 0E setAnchor: default only (returns this).
pub fn setAnchor(g: *Game, obj: *Object, x: i16, y: i16) ?*Object {
    _ = g;
    _ = x;
    _ = y;
    return obj;
}

/// SceneObject slot 0F setSize: default only (returns this).
pub fn setSize(g: *Game, obj: *Object, w: i16, h: i16, d: i16) ?*Object {
    _ = g;
    _ = w;
    _ = h;
    _ = d;
    return obj;
}

/// SceneObject slot 10 setWorldElev: default only (returns this).
pub fn setWorldElev(g: *Game, obj: *Object, elev: i16) ?*Object {
    _ = g;
    _ = elev;
    return obj;
}

/// SceneObject slot 11 drawBounds: default only (returns this).
pub fn drawBounds(g: *Game, obj: *Object, bd: *Backdrop) ?*Object {
    _ = g;
    _ = bd;
    return obj;
}

/// SceneObject slot 38 moveToAndDrop: default only (does nothing).
pub fn moveToAndDrop(g: *Game, obj: *Object, x: i16, y: i16, bd: *Backdrop) void {
    _ = g;
    _ = obj;
    _ = x;
    _ = y;
    _ = bd;
}

/// SceneObject slot 39 setPosition: actor2d_set_position -> mover_set_position
/// (every live kind; the base's scene_object_set_position is dead).
pub fn setPosition(g: *Game, obj: *Object, x: i16, y: i16) void {
    _ = g;
    // @orig 1080:31d8 actor2d_set_position
    // @orig 1080:2bbc mover_set_position
    obj.mover.prevX = obj.x;
    obj.mover.prevY = obj.y;
    obj.x = x;
    obj.y = y;
}

/// SceneObject slot 4C getSceneName: default only (the empty string).
pub fn getSceneName(g: *Game, obj: *Object) []const u8 {
    _ = g;
    _ = obj;
    return "";
}

/// SceneObject slot 4E hitboxOverlaps (the hit box is in the SceneObject).
pub fn hitboxOverlaps(g: *Game, obj: *Object, other: *Object) bool {
    _ = g;
    // @orig 1028:0db1 scene_object_hitbox_overlaps
    if (add(add(obj.x, obj.hitX), obj.hitW) < add(other.x, other.hitX)) return false;
    if (add(add(other.x, other.hitX), other.hitW) < add(obj.x, obj.hitX)) return false;
    if (add(add(obj.y, obj.hitY), obj.hitH) < add(other.y, other.hitY)) return false;
    if (add(add(other.y, other.hitY), other.hitH) < add(obj.y, obj.hitY)) return false;
    return true;
}

/// SceneObject slot 4F boundsOverlap.
pub fn boundsOverlap(g: *Game, obj: *Object, other: *Object) bool {
    _ = g;
    // @orig 1028:0e92 scene_object_bounds_overlap
    if (add(width(obj), obj.x) < other.x) return false;
    if (add(width(other), other.x) < obj.x) return false;
    if (add(height(obj), obj.y) < other.y) return false;
    if (add(height(other), other.y) < obj.y) return false;
    return true;
}

/// SceneObject slot 50 slot5B: default only.
pub fn slot5B(g: *Game, obj: *Object, arg: i16) i16 {
    _ = g;
    _ = obj;
    _ = arg;
    return 0;
}

/// SceneObject slot 51 slot5C: default only.
pub fn slot5C(g: *Game, obj: *Object, arg: i16) i16 {
    _ = g;
    _ = obj;
    _ = arg;
    return 0;
}

/// SceneObject slot 54 isEnabled: default only.
pub fn isEnabled(g: *Game, obj: *Object) bool {
    _ = g;
    _ = obj;
    return false;
}

/// SceneObject slot 55 getExitIndex: default only.
pub fn getExitIndex(g: *Game, obj: *Object) i16 {
    _ = g;
    _ = obj;
    return -1;
}

test "position basics" {
    var g: Game = undefined;
    var o: Object = .{ .kind = .hero, .x = 3, .y = 4 };
    setPosition(&g, &o, 10, 20);
    try std.testing.expectEqual(@as(i16, 3), getX(&g, &o));
    try std.testing.expectEqual(@as(i16, 4), getY(&g, &o));
    o.mover.stepX = -5;
    try std.testing.expectEqual(@as(i16, 5), getStepX(&g, &o));
}
