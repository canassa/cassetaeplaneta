//! Port unit `space3d` (behaviour). Object3D: SceneObject slots 05-0C, 12-15, 40 and the Object3D vtable (support, stacking, depth order).
//!
//! The Object3D part lives in `Object.o3d`; every kind but `status_bar`
//! has one. The backdrop's getters (eye distance, vanishing x) are plain
//! field reads on the only backdrop class, as in `projection.zig`.

const Game = @import("../core/game.zig").Game;
const object = @import("../core/object.zig");
const Object = object.Object;
const world = @import("../core/world.zig");
const Backdrop = world.Backdrop;
const frames = @import("../frames.zig");
const position = @import("position.zig");
const projection = @import("../projection.zig");

/// SceneObject slot 05.
pub fn getWorldX(g: *Game, obj: *Object) i16 {
    _ = g;
    return switch (obj.kind) {
        // @orig 1010:1342 scene_object_get_world_x_default (absorbed)
        .status_bar => 0,
        else => object3dGetWorldX(obj),
    };
}

// @orig 1010:4eb4 object3d_get_world_x
fn object3dGetWorldX(obj: *Object) i16 {
    return obj.o3d.worldX;
}

/// SceneObject slot 06.
pub fn getWorldDepth(g: *Game, obj: *Object) i16 {
    _ = g;
    return switch (obj.kind) {
        // @orig 1010:134e scene_object_get_world_depth_default (absorbed)
        .status_bar => 0,
        else => object3dGetWorldDepth(obj),
    };
}

// @orig 1010:4eca object3d_get_world_depth
fn object3dGetWorldDepth(obj: *Object) i16 {
    return obj.o3d.worldDepth;
}

/// SceneObject slot 07.
pub fn getWorldElev(g: *Game, obj: *Object) i16 {
    _ = g;
    return switch (obj.kind) {
        // @orig 1010:135a scene_object_get_world_elev_default (absorbed)
        .status_bar => 0,
        else => object3dGetWorldElev(obj),
    };
}

// @orig 1010:4ee0 object3d_get_world_elev
fn object3dGetWorldElev(obj: *Object) i16 {
    return obj.o3d.worldElev;
}

/// SceneObject slot 08.
pub fn getSizeW(g: *Game, obj: *Object) i16 {
    _ = g;
    return switch (obj.kind) {
        // @orig 1010:1366 scene_object_get_size_w_default (absorbed)
        .status_bar => 0,
        else => object3dGetSizeW(obj),
    };
}

// @orig 1010:4ef6 object3d_get_size_w
fn object3dGetSizeW(obj: *Object) i16 {
    return obj.o3d.sizeW;
}

/// SceneObject slot 09.
pub fn getSizeH(g: *Game, obj: *Object) i16 {
    _ = g;
    return switch (obj.kind) {
        // @orig 1010:1372 scene_object_get_size_h_default (absorbed)
        .status_bar => 0,
        else => object3dGetSizeH(obj),
    };
}

// @orig 1010:4f0c object3d_get_size_h
fn object3dGetSizeH(obj: *Object) i16 {
    return obj.o3d.sizeH;
}

/// SceneObject slot 0A.
pub fn getSizeD(g: *Game, obj: *Object) i16 {
    _ = g;
    return switch (obj.kind) {
        // @orig 1010:137e scene_object_get_size_d_default (absorbed)
        .status_bar => 0,
        else => object3dGetSizeD(obj),
    };
}

// @orig 1010:4f22 object3d_get_size_d
fn object3dGetSizeD(obj: *Object) i16 {
    return obj.o3d.sizeD;
}

/// SceneObject slot 0B.
pub fn getAnchorX(g: *Game, obj: *Object) i16 {
    _ = g;
    return switch (obj.kind) {
        // @orig 1010:138a scene_object_get_anchor_x_default (absorbed)
        .status_bar => 0,
        else => object3dGetAnchorX(obj),
    };
}

// @orig 1010:31bc object3d_get_anchor_x
fn object3dGetAnchorX(obj: *Object) i16 {
    return obj.o3d.anchorX;
}

/// SceneObject slot 0C.
pub fn getAnchorY(g: *Game, obj: *Object) i16 {
    _ = g;
    return switch (obj.kind) {
        // @orig 1010:1396 scene_object_get_anchor_y_default (absorbed)
        .status_bar => 0,
        else => object3dGetAnchorY(obj),
    };
}

// @orig 1010:31d2 object3d_get_anchor_y
fn object3dGetAnchorY(obj: *Object) i16 {
    return obj.o3d.anchorY;
}

/// SceneObject slot 12.
pub fn setElevation(g: *Game, obj: *Object, bd: *Backdrop, elev: i16) ?*Object {
    return switch (obj.kind) {
        // @orig 1010:13f2 scene_object_set_elevation_default (absorbed)
        .status_bar => obj,
        .moveable, .actor, .player, .portable => moveableSetElevation(g, obj, bd, elev),
        else => object3dSetElevation(obj, bd, elev),
    };
}

/// The anchor point's screen position as the unprojection wants it
/// (`y` is measured up from the bottom of the view).
fn anchorScreen(obj: *const Object, bd: *const Backdrop, x: i16, y: i16) struct { x: i16, y: i16 } {
    return .{
        .x = x -% bd.originX +% obj.o3d.anchorX,
        .y = bd.originY -% y -% obj.o3d.anchorY +% bd.viewHeight,
    };
}

// @orig 1010:531c object3d_set_elevation
fn object3dSetElevation(obj: *Object, bd: *Backdrop, elev: i16) ?*Object {
    const s = anchorScreen(obj, bd, obj.x, obj.y);
    obj.o3d.worldElev = elev;
    const w = projection.unprojectPoint(bd, elev, s.x, s.y);
    obj.o3d.worldX = w.x;
    obj.o3d.worldDepth = w.depth;
    return obj;
}

/// `((sizeW * depth) / 2) / den` in 32 bits (`den` = eye + depth, non-zero),
/// truncated to 16.
fn perspectiveShift(size_w: i16, depth: i16, den: i32) i16 {
    const prod: i32 = @as(i32, size_w) *% @as(i32, depth);
    const q: i64 = @divTrunc(@divTrunc(@as(i64, prod), 2), @as(i64, den));
    return @truncate(q);
}

// @orig 1010:53be moveable_set_elevation
fn moveableSetElevation(g: *Game, obj: *Object, bd: *Backdrop, elev: i16) ?*Object {
    _ = g;
    _ = object3dSetElevation(obj, bd, elev);
    const den: i32 = @as(i32, bd.eyeDistance) + obj.o3d.worldDepth;
    if (den != 0) {
        obj.o3d.worldX +%= perspectiveShift(obj.o3d.sizeW, obj.o3d.worldDepth, den);
    }
    return obj;
}

// @orig 1010:54ac portable_set_elevation (absorbed)

/// SceneObject slot 13.
pub fn setAnchor(g: *Game, obj: *Object, x: i16, y: i16) ?*Object {
    _ = g;
    return switch (obj.kind) {
        // @orig 1010:1406 scene_object_set_anchor_default (absorbed)
        .status_bar => obj,
        else => object3dSetAnchor(obj, x, y),
    };
}

// @orig 1010:5830 object3d_set_anchor
fn object3dSetAnchor(obj: *Object, x: i16, y: i16) ?*Object {
    obj.o3d.anchorX = x;
    obj.o3d.anchorY = y;
    return obj;
}

/// SceneObject slot 14.
pub fn setSize(g: *Game, obj: *Object, w: i16, h: i16, d: i16) ?*Object {
    _ = g;
    return switch (obj.kind) {
        // @orig 1010:141a scene_object_set_size_default (absorbed)
        .status_bar => obj,
        else => object3dSetSize(obj, w, h, d),
    };
}

// @orig 1010:57e2 object3d_set_size
fn object3dSetSize(obj: *Object, w: i16, h: i16, d: i16) ?*Object {
    obj.o3d.sizeW = w;
    obj.o3d.sizeH = h;
    obj.o3d.sizeD = d;
    return obj;
}

/// SceneObject slot 15.
pub fn setWorldElev(g: *Game, obj: *Object, elev: i16) ?*Object {
    _ = g;
    return switch (obj.kind) {
        // @orig 1010:142e scene_object_set_world_elev_default (absorbed)
        .local, .animated, .moveable, .actor, .player, .exit, .control_panel, .status_bar => obj,
        .portable => portableSetWorldElev(obj, elev),
    };
}

// @orig 1010:4258 portable_set_world_elev
fn portableSetWorldElev(obj: *Object, elev: i16) ?*Object {
    obj.o3d.worldElev = elev;
    return obj;
}

/// SceneObject slot 40.
pub fn moveToAndDrop(g: *Game, obj: *Object, x: i16, y: i16, bd: *Backdrop) void {
    switch (obj.kind) {
        // @orig 1010:1b9e scene_object_move_to_and_drop_default (absorbed)
        .status_bar => {},
        .moveable, .actor, .player => moveableMoveToAndDrop(g, obj, x, y, bd),
        .portable => portableMoveToAndDrop(g, obj, x, y),
        else => object3dMoveToAndDrop(g, obj, x, y, bd),
    }
}

// @orig 1010:5538 moveable_move_to_and_drop
fn moveableMoveToAndDrop(g: *Game, obj: *Object, x: i16, y: i16, bd: *Backdrop) void {
    position.setPosition(g, obj, x, y); // mover_set_position
    _ = setElevation(g, obj, bd, 0);
}

// @orig 1010:54d0 portable_move_to_and_drop
fn portableMoveToAndDrop(g: *Game, obj: *Object, x: i16, y: i16) void {
    position.setPosition(g, obj, x, y); // mover_set_position; the backdrop is unused
    obj.o3d.worldElev = 0;
    obj.o3d.worldDepth = 0;
    obj.o3d.worldX = 0;
}

// @orig 1010:55ce object3d_move_to_and_drop
fn object3dMoveToAndDrop(g: *Game, obj: *Object, x: i16, y: i16, bd: *Backdrop) void {
    position.setPosition(g, obj, x, y); // scene_object_set_position
    const s = findSupport(g, obj, bd);
    obj.o3d.support = s.support;
    _ = setElevation(g, obj, bd, s.top);
}

/// Object3D slot 00.
pub fn slot00(g: *Game, obj: *Object) i16 {
    _ = .{ g, obj };
    return object3dSlot00();
}

// @orig 1010:31e8 FUN_1010_31e8
fn object3dSlot00() i16 {
    return 0;
}

/// Object3D slot 01's result: the return value (top of the supporting
/// object, 0 when none) and `*out_support`, which the original always
/// writes (null when nothing supports the object).
pub const Support = struct { top: i16, support: ?*Object };

/// Object3D slot 01.
// @orig 1010:5b3c object3d_find_support
pub fn findSupport(g: *Game, obj: *Object, bd: *Backdrop) Support {
    // First the backdrop's scene objects, then the global objects.
    const lists = [2]?*object.ObjectList{ bd.sceneList, &g.globalObjects };
    for (lists) |list| {
        var cur: ?*Object = if (list) |l| l.head else null;
        while (cur) |other| : (cur = other.next) {
            if (other.visible != 0 and obj.id != other.id) {
                if (isAboveOnScreen(g, obj, other, bd) or position.hitboxOverlaps(g, obj, other)) {
                    return .{ .top = getWorldElev(g, other) +% getSizeH(g, other), .support = other };
                }
            }
        }
    }
    return .{ .top = 0, .support = null };
}

/// Object3D slot 02.
pub fn isBelow(g: *Game, obj: *Object, other: *Object, bd: *Backdrop) bool {
    return switch (obj.kind) {
        .portable => portableIsBelow(g, obj, other, bd),
        else => object3dIsBelow(g, obj, other, bd),
    };
}

// @orig 1010:5878 portable_is_below
fn portableIsBelow(g: *Game, obj: *Object, other: *Object, bd: *Backdrop) bool {
    return object3dIsBelow(g, obj, other, bd);
}

/// The other object's box as the SceneObject getters report it.
const Box = struct { x: i16, depth: i16, elev: i16, w: i16, h: i16, d: i16 };

fn boxOf(g: *Game, other: *Object) Box {
    return .{
        .x = getWorldX(g, other),
        .depth = getWorldDepth(g, other),
        .elev = getWorldElev(g, other),
        .w = getSizeW(g, other),
        .h = getSizeH(g, other),
        .d = getSizeD(g, other),
    };
}

// @orig 1010:58aa object3d_is_below
fn object3dIsBelow(g: *Game, obj: *Object, other: *Object, bd: *Backdrop) bool {
    const s = anchorScreen(obj, bd, obj.x, obj.y);
    const w = projection.unprojectPoint(bd, obj.o3d.worldElev, s.x, s.y);
    var x = w.x;
    if (w.depth <= 0) {
        x +%= @divTrunc(obj.o3d.sizeW, 2);
    } else {
        // The original divides unchecked (a zero `eye + depth` would fault).
        const den: i32 = @as(i32, bd.eyeDistance) + w.depth;
        if (den != 0) x +%= perspectiveShift(obj.o3d.sizeW, w.depth, den);
    }
    const o = boxOf(g, other);
    if (obj.o3d.sizeW +% x < o.x) return false;
    if (o.w +% o.x < x) return false;
    if (obj.o3d.sizeD +% w.depth < o.depth) return false;
    if (o.d +% o.depth < w.depth) return false;
    return obj.o3d.worldElev < o.elev;
}

/// Object3D slot 03.
// @orig 1010:5a2a object3d_is_above_on_screen
pub fn isAboveOnScreen(g: *Game, obj: *Object, other: *Object, bd: *Backdrop) bool {
    _ = .{ g, bd }; // the backdrop is unused by the original
    const left = obj.x +% frames.hitX(obj);
    if (left +% frames.hitW(obj) < other.x +% frames.hitX(other)) return false;
    if (left > other.x +% frames.hitX(other) +% frames.hitW(other)) return false;
    return obj.y +% frames.hitY(obj) < other.y +% frames.hitY(other);
}

fn abs16(v: i16) i16 {
    return if (v < 0) 0 -% v else v;
}

/// Object3D slot 04.
// @orig 1010:5c5c object3d_is_in_front_of
pub fn isInFrontOf(g: *Game, obj: *Object, other: *Object, bd: *Backdrop) bool {
    if (other.o3d.worldDepth +% other.o3d.sizeD < obj.o3d.worldDepth) return false;
    if (obj.o3d.worldDepth +% obj.o3d.sizeD < other.o3d.worldDepth) return true;
    if (isBelow(g, obj, other, bd)) return false;
    if (isBelow(g, other, obj, bd)) return true;
    if (!position.hitboxOverlaps(g, obj, other)) return true;
    if (obj.x +% obj.o3d.anchorX <= 0) return false;
    const p = projection.projectPoint(bd, other.o3d.worldX, other.o3d.worldDepth, other.o3d.worldElev);
    const mine = abs16(bd.vanishX -% obj.x -% obj.o3d.anchorX);
    const theirs = abs16(bd.vanishX -% p.x);
    return mine <= theirs;
}

/// Object3D slot 05.
// @orig 1010:4f38 object3d_overlaps_3d
pub fn overlaps3d(g: *Game, obj: *Object, other: *Object, bd: *Backdrop) bool {
    // This object's anchor at the screen position held in nextX/nextY.
    const s = anchorScreen(obj, bd, obj.nextX, obj.nextY);
    const w = projection.unprojectPoint(bd, obj.o3d.worldElev, s.x, s.y);
    var x = w.x;
    const den: i32 = @as(i32, bd.eyeDistance) + w.depth;
    if (den != 0) x +%= perspectiveShift(obj.o3d.sizeW, w.depth, den);
    const o = boxOf(g, other);
    if (obj.o3d.sizeW +% x < o.x) return false;
    if (o.w +% o.x < x) return false;
    if (obj.o3d.sizeD +% w.depth < o.depth) return false;
    if (o.d +% o.depth < w.depth) return false;
    if (obj.o3d.worldElev +% obj.o3d.sizeH < o.elev) return false;
    if (o.h +% o.elev < obj.o3d.worldElev) return false;
    return true;
}

/// Object3D slot 06.
pub fn moveToAtElev(g: *Game, obj: *Object, x: i16, y: i16, bd: *Backdrop, elev: i16) void {
    switch (obj.kind) {
        .moveable, .actor, .player => moveableMoveToAtElev(g, obj, x, y, bd, elev),
        .portable => portableMoveToAtElev(g, obj, x, y, bd, elev),
        else => object3dMoveToAtElev(g, obj, x, y, bd, elev),
    }
}

// @orig 1010:557e moveable_move_to_at_elev
fn moveableMoveToAtElev(g: *Game, obj: *Object, x: i16, y: i16, bd: *Backdrop, elev: i16) void {
    position.setPosition(g, obj, x, y); // mover_set_position
    _ = setElevation(g, obj, bd, elev);
}

// @orig 1010:5510 portable_move_to_at_elev
fn portableMoveToAtElev(g: *Game, obj: *Object, x: i16, y: i16, bd: *Backdrop, elev: i16) void {
    moveableMoveToAtElev(g, obj, x, y, bd, elev);
}

// @orig 1010:5640 object3d_move_to_at_elev
fn object3dMoveToAtElev(g: *Game, obj: *Object, x: i16, y: i16, bd: *Backdrop, elev: i16) void {
    position.setPosition(g, obj, x, y); // scene_object_set_position
    _ = setElevation(g, obj, bd, elev);
}

/// Object3D slot 07.
pub fn dropToSupport(g: *Game, obj: *Object, bd: *Backdrop) void {
    switch (obj.kind) {
        .moveable, .actor, .player => moveableDropToSupport(g, obj, bd),
        .portable => portableDropToSupport(g, obj, bd),
        else => object3dDropToSupport(g, obj, bd),
    }
}

// @orig 1010:52e6 moveable_drop_to_support
fn moveableDropToSupport(g: *Game, obj: *Object, bd: *Backdrop) void {
    _ = setElevation(g, obj, bd, 0);
}

// @orig 1010:5290 portable_drop_to_support
fn portableDropToSupport(g: *Game, obj: *Object, bd: *Backdrop) void {
    const s = findSupport(g, obj, bd);
    obj.o3d.support = s.support;
    _ = moveableSetElevation(g, obj, bd, s.top);
}

// @orig 1010:5242 object3d_drop_to_support
fn object3dDropToSupport(g: *Game, obj: *Object, bd: *Backdrop) void {
    const s = findSupport(g, obj, bd);
    obj.o3d.support = s.support;
    _ = setElevation(g, obj, bd, s.top);
}
