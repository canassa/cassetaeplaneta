//! Port unit `space3d` (behaviour) of TIRO.EXE. SceneObject slots 00-07 0D-11 38 (Object3D getters/setters, drawBounds), the Object3DVtbl slots, the perspective math.
//!
//! Only the ControlPanel (`control_panel`) has an Object3D part; every other
//! kind takes the SceneObject default (0 / returns `this` / nothing). The
//! Object3DVtbl slots are the Object3D implementations themselves (the
//! panel is its only user). The backdrop's getters (vanish point, eye
//! distance, axis) are called through `backdrop.zig`'s dispatchers.
//!
//! Arithmetic follows the machine code: 16-bit `int`s, products and
//! quotients in 32 bits (low 32 bits kept), results truncated to 16. The
//! original divides without a zero check (a `#DE` fault); here it panics.
//! The perspective functions take a 7th word argument the original never reads.

const Game = @import("../core/game.zig").Game;
const object = @import("../core/object.zig");
const Object = object.Object;
const world = @import("../core/world.zig");
const Backdrop = world.Backdrop;
const backdrop_unit = @import("../backdrop.zig");
const position = @import("position.zig");
const visibility = @import("visibility.zig");
const render = @import("render.zig");

/// Object3DVtbl findSupport's results: the return value and `*out_support`.
pub const Support = struct { result: i16 = 0, support: ?*Object = null };

/// A screen position (the original's `*out_sx`, `*out_sy`).
pub const ScreenPoint = struct { x: i16, y: i16 };

/// A world position on the ground plane (`*out_x`, `*out_depth`).
pub const WorldPoint = struct { x: i16, depth: i16 };

/// `(a * m) / b` as the original's 32-bit helpers: the product keeps its
/// low 32 bits, the division truncates toward zero, the result is cut to 16.
fn mulDiv(a: i32, m: i32, b: i32) i16 {
    if (b == 0) @panic("space3d: division by zero (the original faults)");
    const prod: i32 = a *% m;
    const q: i64 = @divTrunc(@as(i64, prod), @as(i64, b));
    return @truncate(q);
}

/// `((sizeW * depth) / 2) / (eye + depth)` in 32 bits, truncated to 16.
fn perspectiveShift(size_w: i16, depth: i16, eye: i16) i16 {
    const prod: i32 = @as(i32, size_w) *% @as(i32, depth);
    const den: i32 = @as(i32, eye) + @as(i32, depth);
    if (den == 0) @panic("space3d: division by zero (the original faults)");
    const q: i64 = @divTrunc(@divTrunc(@as(i64, prod), 2), @as(i64, den));
    return @truncate(q);
}

fn abs16(v: i16) i16 {
    const s = v >> 15;
    return (v ^ s) -% s;
}

// @orig 1018:01cc perspective_project_point
/// Projects the world point (`x`, `depth`, `height`) onto the view; screen
/// `y` counts from the top of the view.
pub fn projectPoint(g: *Game, bd: *Backdrop, x: i16, depth: i16, height: i16) ScreenPoint {
    const xa: i16 = x -% backdrop_unit.getAxisX(g, bd);
    const eye = backdrop_unit.getEyeDistance(g, bd);
    const den: i32 = @as(i32, eye) + depth;
    const vx = backdrop_unit.getVanishX(g, bd);
    const sx = xa +% mulDiv(@as(i32, vx) - xa, depth, den);
    const vy = backdrop_unit.getVanishY(g, bd);
    const sy = (mulDiv(@as(i32, height) - vy, depth, den) +% bd.viewHeight) -% height;
    return .{ .x = sx, .y = sy };
}

// @orig 1018:00c2 perspective_unproject_point
/// Inverse of `projectPoint` for a point at `height`; `screen_y` counts up
/// from the bottom like the vanishing y. On the horizon row the depth is
/// the vanishing y (sic, as the original).
pub fn unprojectPoint(g: *Game, bd: *Backdrop, height: i16, screen_x: i16, screen_y: i16) WorldPoint {
    const vy = backdrop_unit.getVanishY(g, bd);
    if (vy == screen_y) {
        return .{ .x = backdrop_unit.getAxisX(g, bd) +% screen_x, .depth = backdrop_unit.getVanishY(g, bd) };
    }
    const sy: i32 = screen_y;
    const dy: i32 = sy - vy;
    const vx = backdrop_unit.getVanishX(g, bd);
    const axis = backdrop_unit.getAxisX(g, bd);
    const x = mulDiv(@as(i32, vx) - screen_x, sy - height, dy) +% axis +% screen_x;
    const eye = backdrop_unit.getEyeDistance(g, bd);
    const depth = mulDiv(@as(i32, height) - sy, eye, dy);
    return .{ .x = x, .depth = depth };
}

/// SceneObject slot 00 getWorldX: Object3D's (panel) / default 0.
pub fn getWorldX(g: *Game, obj: *Object) i16 {
    _ = g;
    return switch (obj.kind) {
        // @orig 1018:0622 object3d_get_world_x
        .control_panel => obj.o3d.worldX,
        // @orig 1088:2d22 scene_object_get_world_x_default (absorbed)
        else => 0,
    };
}

/// SceneObject slot 01 getWorldDepth.
pub fn getWorldDepth(g: *Game, obj: *Object) i16 {
    _ = g;
    return switch (obj.kind) {
        // @orig 1018:063e object3d_get_world_depth
        .control_panel => obj.o3d.worldDepth,
        // @orig 1088:2d3e scene_object_get_world_depth_default (absorbed)
        else => 0,
    };
}

/// SceneObject slot 02 getWorldElev.
pub fn getWorldElev(g: *Game, obj: *Object) i16 {
    _ = g;
    return switch (obj.kind) {
        // @orig 1018:065a object3d_get_world_elev
        .control_panel => obj.o3d.worldElev,
        // @orig 1088:2d5a scene_object_get_world_elev_default (absorbed)
        else => 0,
    };
}

/// SceneObject slot 03 getSizeW.
pub fn getSizeW(g: *Game, obj: *Object) i16 {
    _ = g;
    return switch (obj.kind) {
        // @orig 1018:0676 object3d_get_size_w
        .control_panel => obj.o3d.sizeW,
        // @orig 1088:2d76 scene_object_get_size_w_default (absorbed)
        else => 0,
    };
}

/// SceneObject slot 04 getSizeH.
pub fn getSizeH(g: *Game, obj: *Object) i16 {
    _ = g;
    return switch (obj.kind) {
        // @orig 1018:0692 object3d_get_size_h
        .control_panel => obj.o3d.sizeH,
        // @orig 1088:2d92 scene_object_get_size_h_default (absorbed)
        else => 0,
    };
}

/// SceneObject slot 05 getSizeD.
pub fn getSizeD(g: *Game, obj: *Object) i16 {
    _ = g;
    return switch (obj.kind) {
        // @orig 1018:06ae object3d_get_size_d
        .control_panel => obj.o3d.sizeD,
        // @orig 1088:2dae scene_object_get_size_d_default (absorbed)
        else => 0,
    };
}

/// SceneObject slot 06 getAnchorX.
pub fn getAnchorX(g: *Game, obj: *Object) i16 {
    _ = g;
    return switch (obj.kind) {
        // @orig 1088:24ae object3d_get_anchor_x
        .control_panel => obj.o3d.anchorX,
        // @orig 1088:2dca scene_object_get_anchor_x_default (absorbed)
        else => 0,
    };
}

/// SceneObject slot 07 getAnchorY.
pub fn getAnchorY(g: *Game, obj: *Object) i16 {
    _ = g;
    return switch (obj.kind) {
        // @orig 1088:24ca object3d_get_anchor_y
        .control_panel => obj.o3d.anchorY,
        // @orig 1088:2de6 scene_object_get_anchor_y_default (absorbed)
        else => 0,
    };
}

/// SceneObject slot 0D setElevation (Ghidra: this, elev, backdrop).
pub fn setElevation(g: *Game, obj: *Object, bd: *Backdrop, elev: i16) ?*Object {
    return switch (obj.kind) {
        // @orig 1018:0a48 object3d_set_elevation
        .control_panel => {
            const sx = (obj.x -% bd.originX) +% obj.o3d.anchorX;
            const sy = ((bd.originY -% obj.y) -% obj.o3d.anchorY) +% bd.viewHeight;
            obj.o3d.worldElev = elev;
            const w = unprojectPoint(g, bd, elev, sx, sy);
            obj.o3d.worldX = w.x;
            obj.o3d.worldDepth = w.depth;
            return obj;
        },
        // @orig 1088:2e72 scene_object_set_elevation_default (absorbed)
        else => obj,
    };
}

/// SceneObject slot 0E setAnchor.
pub fn setAnchor(g: *Game, obj: *Object, x: i16, y: i16) ?*Object {
    _ = g;
    return switch (obj.kind) {
        // @orig 1018:0eee object3d_set_anchor
        .control_panel => {
            obj.o3d.anchorX = x;
            obj.o3d.anchorY = y;
            return obj;
        },
        // @orig 1088:2e8e scene_object_set_anchor_default (absorbed)
        else => obj,
    };
}

/// SceneObject slot 0F setSize.
pub fn setSize(g: *Game, obj: *Object, w: i16, h: i16, d: i16) ?*Object {
    _ = g;
    return switch (obj.kind) {
        // @orig 1018:0eab object3d_set_size
        .control_panel => {
            obj.o3d.sizeW = w;
            obj.o3d.sizeH = h;
            obj.o3d.sizeD = d;
            return obj;
        },
        // @orig 1088:2eaa scene_object_set_size_default (absorbed)
        else => obj,
    };
}

/// SceneObject slot 10 setWorldElev (default only).
pub fn setWorldElev(g: *Game, obj: *Object, elev: i16) ?*Object {
    _ = g;
    _ = elev;
    // @orig 1088:2ec6 scene_object_set_world_elev_default (absorbed)
    return obj;
}

/// SceneObject slot 11 drawBounds (hdc dropped).
pub fn drawBounds(g: *Game, obj: *Object, bd: *Backdrop) ?*Object {
    _ = g;
    _ = bd;
    return switch (obj.kind) {
        // @orig 1018:0290 object3d_draw_bounds
        // Draws the projected 3D box as a wireframe (CreatePen/MoveTo/LineTo)
        // on the caller's DC. The DC is dropped from the signature, no caller
        // reaches the slot, and the projections have no other effect: nothing
        // to do but return this.
        .control_panel => obj,
        // @orig 1088:2ee2 scene_object_draw_bounds_default (absorbed)
        else => obj,
    };
}

/// SceneObject slot 38 moveToAndDrop.
pub fn moveToAndDrop(g: *Game, obj: *Object, x: i16, y: i16, bd: *Backdrop) void {
    switch (obj.kind) {
        // @orig 1018:0c93 object3d_move_to_and_drop
        .control_panel => {
            position.setPosition(g, obj, x, y);
            const s = findSupport(g, obj, bd);
            obj.o3d.support = s.support;
            _ = setElevation(g, obj, bd, s.result);
        },
        // @orig 1088:1946 scene_object_move_to_and_drop_default (absorbed)
        else => {},
    }
}

/// Object3DVtbl slot 00 (object3d_slot00).
pub fn slot00(g: *Game, obj: *Object) i16 {
    _ = g;
    _ = obj;
    // @orig 1088:24e6 object3d_slot00
    return 0;
}

/// Object3DVtbl slot 01 findSupport: the support found (out parameter) and the result.
// @orig 1018:11ae object3d_find_support
pub fn findSupport(g: *Game, obj: *Object, bd: *Backdrop) Support {
    // First the backdrop's scene objects, then the global objects.
    const lists = [2]?*object.ObjectList{ bd.sceneList, &g.globalObjects };
    for (lists) |list| {
        var cur: ?*Object = if (list) |l| l.head else null;
        while (cur) |other| : (cur = other.next) {
            if (other.visible != 0 and obj.id != other.id) {
                if (isAboveOnScreen(g, obj, other, bd) or position.hitboxOverlaps(g, obj, other)) {
                    return .{
                        .result = getWorldElev(g, other) +% getSizeH(g, other),
                        .support = other,
                    };
                }
            }
        }
    }
    return .{ .result = 0, .support = null };
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

/// The anchor point's screen position for the unprojection at (`x`, `y`).
fn anchorScreen(obj: *const Object, bd: *const Backdrop, x: i16, y: i16) struct { x: i16, y: i16 } {
    return .{
        .x = (x -% bd.originX) +% obj.o3d.anchorX,
        .y = ((bd.originY -% y) -% obj.o3d.anchorY) +% bd.viewHeight,
    };
}

/// Object3DVtbl slot 02 isBelow.
// @orig 1018:0f5c object3d_is_below
pub fn isBelow(g: *Game, obj: *Object, other: *Object, bd: *Backdrop) bool {
    const s = anchorScreen(obj, bd, obj.x, obj.y);
    const w = unprojectPoint(g, bd, obj.o3d.worldElev, s.x, s.y);
    var x = w.x;
    if (w.depth < 1) {
        x +%= @divTrunc(obj.o3d.sizeW, 2);
    } else {
        x +%= perspectiveShift(obj.o3d.sizeW, w.depth, backdrop_unit.getEyeDistance(g, bd));
    }
    const o = boxOf(g, other);
    if (obj.o3d.sizeW +% x < o.x) return false;
    if (o.w +% o.x < x) return false;
    if (obj.o3d.sizeD +% w.depth < o.depth) return false;
    if (o.d +% o.depth < w.depth) return false;
    return obj.o3d.worldElev < o.elev;
}

/// Object3DVtbl slot 03 isAboveOnScreen (the backdrop is unused).
// @orig 1018:10cc object3d_is_above_on_screen
pub fn isAboveOnScreen(g: *Game, obj: *Object, other: *Object, bd: *Backdrop) bool {
    _ = g;
    _ = bd;
    const left = obj.x +% position.hitX(obj);
    if (left +% position.hitW(obj) < position.hitX(other) +% other.x) return false;
    if (position.hitX(other) +% position.hitW(other) +% other.x < left) return false;
    return position.hitY(obj) +% obj.y < position.hitY(other) +% other.y;
}

/// Object3DVtbl slot 04 isInFrontOf (the draw list's order).
// @orig 1018:128e object3d_is_in_front_of
pub fn isInFrontOf(g: *Game, obj: *Object, other: *Object, bd: *Backdrop) bool {
    if (obj.o3d.worldDepth > other.o3d.worldDepth +% other.o3d.sizeD) return false;
    if (obj.o3d.worldDepth +% obj.o3d.sizeD < other.o3d.worldDepth) return true;
    if (isBelow(g, obj, other, bd)) return false;
    if (isBelow(g, other, obj, bd)) return true;
    if (!position.hitboxOverlaps(g, obj, other)) return true;
    if (obj.x +% obj.o3d.anchorX <= 0) return false;
    const p = projectPoint(g, bd, other.o3d.worldX, other.o3d.worldDepth, other.o3d.worldElev);
    const vx = backdrop_unit.getVanishX(g, bd);
    const vx2 = backdrop_unit.getVanishX(g, bd);
    const mine = abs16((vx -% obj.x) -% obj.o3d.anchorX);
    const theirs = abs16(vx2 -% p.x);
    return mine <= theirs;
}

/// Object3DVtbl slot 05 overlaps3d.
// @orig 1018:06ca object3d_overlaps_3d
pub fn overlaps3d(g: *Game, obj: *Object, other: *Object, bd: *Backdrop) bool {
    // This object's anchor at the screen position held in nextX/nextY.
    const s = anchorScreen(obj, bd, obj.nextX, obj.nextY);
    const w = unprojectPoint(g, bd, obj.o3d.worldElev, s.x, s.y);
    const x = w.x +% perspectiveShift(obj.o3d.sizeW, w.depth, backdrop_unit.getEyeDistance(g, bd));
    const o = boxOf(g, other);
    if (obj.o3d.sizeW +% x < o.x) return false;
    if (o.w +% o.x < x) return false;
    if (obj.o3d.sizeD +% w.depth < o.depth) return false;
    if (o.d +% o.depth < w.depth) return false;
    if (obj.o3d.worldElev +% obj.o3d.sizeH < o.elev) return false;
    if (o.h +% o.elev < obj.o3d.worldElev) return false;
    return true;
}

/// Object3DVtbl slot 06 moveToAtElev.
// @orig 1018:0cf5 object3d_move_to_at_elev
pub fn moveToAtElev(g: *Game, obj: *Object, x: i16, y: i16, bd: *Backdrop, elev: i16) void {
    position.setPosition(g, obj, x, y);
    _ = setElevation(g, obj, bd, elev);
}

/// Object3DVtbl slot 07 dropToSupport.
// @orig 1018:0971 object3d_drop_to_support
pub fn dropToSupport(g: *Game, obj: *Object, bd: *Backdrop) void {
    const s = findSupport(g, obj, bd);
    obj.o3d.support = s.support;
    _ = setElevation(g, obj, bd, s.result);
}

/// SceneObject slot 4D redrawOverlapping's Object3D override (hdc dropped;
/// `flag` is unused). The dispatcher lives in `visibility`.
// @orig 1018:1424 object3d_redraw_overlapping
pub fn redrawOverlapping(g: *Game, obj: *Object, bd: *Backdrop, flag: i16) void {
    _ = flag;
    var node = g.drawList.head;
    while (node) |n| : (node = n.next) {
        const other = n.item.?;
        if (other.visible == 0) continue;
        if (other.id == obj.id) continue;
        if (!render.computeOverlap(g, obj, other)) continue;
        render.draw(g, other, bd);
        if (obj.visible != 0 and isInFrontOf(g, obj, other, bd)) {
            render.drawClip(g, obj, bd);
        }
        visibility.invalidate(g, obj);
    }
    visibility.invalidate(g, obj);
}
