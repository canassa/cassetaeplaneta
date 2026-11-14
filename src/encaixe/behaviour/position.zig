//! Port unit `position` (behaviour) of ENCAIXE.EXE. SceneObject slots 08-0C getX/getY/getStep, 3B setPosition, 4E unk4E, 50/51 overlap tests, 52-5C defaults; next_object_id.
//!
//! Virtual-slot dispatchers owned by this unit are declared below with
//! their final signatures; their bodies panic until the unit is ported
//! (docs/encaixe/DESIGN.md "Virtual slots"). Replace each body, keep the
//! signature (other units already call it). Each implementation function
//! carries `// @orig <1008:xxxx> <name>` with the ENCAIXE address.

const std = @import("std");
const stub = @import("../../core/stub.zig");
const msg = @import("../../core/msg.zig");
const Msg = msg.Msg;
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

/// SceneObject slot 08 getX: Mover's (piece) / SceneObject's.
pub fn getX(g: *Game, obj: *Object) i16 {
    _ = g;
    return switch (obj.kind) {
        // @orig 1008:5794 mover_get_x
        .piece => obj.mover.prevX,
        // @orig 1008:5270 scene_object_get_x
        else => obj.x,
    };
}

/// SceneObject slot 09 getY.
pub fn getY(g: *Game, obj: *Object) i16 {
    _ = g;
    return switch (obj.kind) {
        // @orig 1008:57a2 mover_get_y
        .piece => obj.mover.prevY,
        // @orig 1008:527e scene_object_get_y
        else => obj.y,
    };
}

/// SceneObject slot 0A getStepX: Mover's (piece) / default.
pub fn getStepX(g: *Game, obj: *Object) i16 {
    _ = g;
    return switch (obj.kind) {
        // @orig 1008:57b0 mover_get_step_x
        .piece => abs16(obj.mover.stepX),
        // @orig 1008:528c scene_object_get_step_x_default (absorbed)
        else => 0,
    };
}

/// SceneObject slot 0B getStepY.
pub fn getStepY(g: *Game, obj: *Object) i16 {
    _ = g;
    return switch (obj.kind) {
        // @orig 1008:57c2 mover_get_step_y
        .piece => abs16(obj.mover.stepY),
        // @orig 1008:5292 scene_object_get_step_y_default (absorbed)
        else => 0,
    };
}

/// SceneObject slot 0C slot11 (default only).
pub fn slot11(g: *Game, obj: *Object, arg: u16) i16 {
    _ = g;
    _ = obj;
    _ = arg;
    // @orig 1008:5298 scene_object_slot11_default (absorbed)
    return 0;
}

/// SceneObject slot 3B setPosition: Actor2D's (piece) / SceneObject's.
pub fn setPosition(g: *Game, obj: *Object, x: i16, y: i16) void {
    _ = g;
    switch (obj.kind) {
        // @orig 1008:5ca6 actor2d_set_position
        .piece => {
            obj.mover.prevX = obj.x;
            obj.mover.prevY = obj.y;
            obj.x = x;
            obj.y = y;
        },
        // @orig 1008:5558 scene_object_set_position
        else => {
            obj.x = x;
            obj.y = y;
        },
    }
}

/// SceneObject slot 4E unk4E (returns "").
pub fn unk4E(g: *Game, obj: *Object) []const u8 {
    _ = g;
    _ = obj;
    // @orig 1008:55de scene_object_unk4e
    return "";
}

/// SceneObject slot 50 hitboxOverlaps.
pub fn hitboxOverlaps(g: *Game, obj: *Object, other: *Object) bool {
    _ = g;
    // @orig 1008:73c8 scene_object_hitbox_overlaps
    const o = &other.frames[@intCast(other.curStrip)];
    const t = &obj.frames[@intCast(obj.curStrip)];
    if (add(add(t.hitX, t.hitW), obj.x) < add(o.hitX, other.x)) return false;
    if (add(add(o.hitX, o.hitW), other.x) < add(t.hitX, obj.x)) return false;
    if (add(add(t.hitY, t.hitH), obj.y) < add(o.hitY, other.y)) return false;
    if (add(add(o.hitY, o.hitH), other.y) < add(t.hitY, obj.y)) return false;
    return true;
}

/// SceneObject slot 51 boundsOverlap.
pub fn boundsOverlap(g: *Game, obj: *Object, other: *Object) bool {
    _ = g;
    // @orig 1008:7452 scene_object_bounds_overlap
    const t = &obj.frames[@intCast(obj.curStrip)];
    if (add(t.width, obj.x) < other.x) return false;
    const o = &other.frames[@intCast(other.curStrip)];
    if (add(o.width, other.x) < obj.x) return false;
    if (add(t.height, obj.y) < other.y) return false;
    if (add(o.height, other.y) < obj.y) return false;
    return true;
}

/// SceneObject slot 52 slot5B (default only).
pub fn slot5B(g: *Game, obj: *Object, arg: i16) i16 {
    _ = g;
    _ = obj;
    _ = arg;
    // @orig 1008:55ea scene_object_slot5b_default (absorbed)
    return 0;
}

/// SceneObject slot 53 slot5C (default only).
pub fn slot5C(g: *Game, obj: *Object, arg: i16) i16 {
    _ = g;
    _ = obj;
    _ = arg;
    // @orig 1008:55e4 scene_object_slot5c_default (absorbed)
    return 0;
}

/// SceneObject slot 56 isEnabled (default only).
pub fn isEnabled(g: *Game, obj: *Object) bool {
    _ = g;
    _ = obj;
    // @orig 1008:55fc scene_object_is_enabled_default (absorbed)
    return false;
}

/// SceneObject slot 57 getExitIndex (default only).
pub fn getExitIndex(g: *Game, obj: *Object) i16 {
    _ = g;
    _ = obj;
    // @orig 1008:5602 scene_object_get_exit_index_default (absorbed)
    return -1;
}

/// The next SceneObject serial number: returns `g_nextId`, then increments it.
pub fn nextObjectId(g: *Game) i16 {
    // @orig 1008:6c50 next_object_id
    const id = g.nextId;
    g.nextId +%= 1;
    return id;
}

test "position basics" {
    var g: Game = undefined;
    var o: Object = .{ .kind = .piece, .x = 3, .y = 4 };
    setPosition(&g, &o, 10, 20);
    try std.testing.expectEqual(@as(i16, 3), getX(&g, &o));
    try std.testing.expectEqual(@as(i16, 4), getY(&g, &o));
    o.mover.stepX = -5;
    try std.testing.expectEqual(@as(i16, 5), getStepX(&g, &o));
    o.kind = .status_bar;
    try std.testing.expectEqual(@as(i16, 10), getX(&g, &o));
    try std.testing.expectEqual(@as(i16, 0), getStepY(&g, &o));
}
