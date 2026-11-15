//! Port unit `space3d` (behaviour) of JARDIM.EXE. SceneObject slots 05-0C 12-16 3D (Object3D getters and setters, drawBounds, moveToAndDrop) and the Object3DVtbl slots, the perspective math.
//!
//! The Object3D part (`Object.o3d`) belongs to the Portable, Exit, Player and
//! ControlPanel; the plain SceneObject and the WallStrip take the SceneObject
//! default (0 / returns `this` / nothing). The Player and the Portable are
//! Moveables (their elevation and drops differ), the Exit and the
//! ControlPanel use Object3D's.
//!
//! The backdrop's perspective getters (vanish point, eye distance, axis) are
//! the Backdrop defaults in JARDIM (`10c0:44b6`..`4504`, slots 0C-0F and 10-11,
//! shared by the LabyrinthBackdrop, which overrides none of them): they all
//! return 0, so the perspective runs with a vanish point, axis and eye distance
//! of 0 and the unprojected depth is always 0.
//!
//! Arithmetic follows the machine code: 16-bit `int`s, products and quotients
//! in 32 bits (low 32 bits kept, `_aFlmul`/`_aFldiv`), results truncated to 16.
//! The original divides without a zero check (a `#DE` fault); here it panics.
//! The perspective functions take a 7th word argument the original never reads.

const Game = @import("../core/game.zig").Game;
const object = @import("../core/object.zig");
const Object = object.Object;
const world = @import("../core/world.zig");
const Backdrop = world.Backdrop;
const position = @import("position.zig");

/// Object3DVtbl.findSupport's result (the out parameter joins the return).
pub const Support = struct {
    result: i16 = 0,
    support: ?*Object = null,
};

/// A screen position (the original's `*out_sx`, `*out_sy`).
pub const ScreenPoint = struct { x: i16, y: i16 };

/// A world position on the ground plane (`*out_x`, `*out_depth`).
pub const WorldPoint = struct { x: i16, depth: i16 };

/// BackdropVtbl slots 0C/10 getVanishX, 0D/11 getVanishY, 0E getEyeDistance,
/// 0F getAxisX: the Backdrop defaults (JARDIM's only backdrop class overrides none).
fn getVanishX(g: *Game, bd: *Backdrop) i16 {
    _ = .{ g, bd };
    return 0;
}

fn getVanishY(g: *Game, bd: *Backdrop) i16 {
    _ = .{ g, bd };
    return 0;
}

fn getEyeDistance(g: *Game, bd: *Backdrop) i16 {
    _ = .{ g, bd };
    return 0;
}

fn getAxisX(g: *Game, bd: *Backdrop) i16 {
    _ = .{ g, bd };
    return 0;
}

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

/// Whether the kind carries an Object3D part (Portable, Exit, Player, ControlPanel).
fn hasObject3d(obj: *const Object) bool {
    return obj.is(.object3d);
}

// @orig 1048:024b perspective_project_point
/// Projects the world point (`x`, `depth`, `height`) onto the view; screen
/// `y` counts from the top of the view.
pub fn projectPoint(g: *Game, bd: *Backdrop, x: i16, depth: i16, height: i16) ScreenPoint {
    const xa: i16 = x -% getAxisX(g, bd);
    const eye = getEyeDistance(g, bd);
    const den: i32 = @as(i32, eye) + depth;
    const vx = getVanishX(g, bd);
    const sx = xa +% mulDiv(@as(i32, vx) - xa, depth, den);
    const den2: i32 = @as(i32, getEyeDistance(g, bd)) + depth;
    const vy = getVanishY(g, bd);
    const sy = (mulDiv(@as(i32, height) - vy, depth, den2) +% bd.viewHeight) -% height;
    return .{ .x = sx, .y = sy };
}

// @orig 1048:0115 perspective_unproject_point
/// Inverse of `projectPoint` for a point at `height`; `screen_y` counts up
/// from the bottom like the vanishing y. On the horizon row the depth is
/// the vanishing y (sic, as the original).
pub fn unprojectPoint(g: *Game, bd: *Backdrop, height: i16, screen_x: i16, screen_y: i16) WorldPoint {
    const sy: i32 = screen_y;
    if (getVanishY(g, bd) == screen_y) {
        return .{ .x = getAxisX(g, bd) +% screen_x, .depth = getVanishY(g, bd) };
    }
    const dy: i32 = sy - getVanishY(g, bd);
    const vx = getVanishX(g, bd);
    const x = mulDiv(@as(i32, vx) - screen_x, sy - height, dy) +% getAxisX(g, bd) +% screen_x;
    const dy2: i32 = sy - getVanishY(g, bd);
    const depth = mulDiv(@as(i32, height) - sy, getEyeDistance(g, bd), dy2);
    return .{ .x = x, .depth = depth };
}

/// SceneObject slot 05 getWorldX: Object3D's (portable, exit, player, control_panel) / default 0.
pub fn getWorldX(g: *Game, obj: *Object) i16 {
    _ = g;
    // @orig 10c0:3410 scene_object_get_world_x_default (absorbed)
    if (!hasObject3d(obj)) return 0;
    // @orig 1048:087e object3d_get_world_x
    return obj.o3d.worldX;
}

/// SceneObject slot 06 getWorldDepth.
pub fn getWorldDepth(g: *Game, obj: *Object) i16 {
    _ = g;
    // @orig 10c0:342a scene_object_get_world_depth_default (absorbed)
    if (!hasObject3d(obj)) return 0;
    // @orig 1048:089b object3d_get_world_depth
    return obj.o3d.worldDepth;
}

/// SceneObject slot 07 getWorldElev.
pub fn getWorldElev(g: *Game, obj: *Object) i16 {
    _ = g;
    // @orig 10c0:3444 scene_object_get_world_elev_default (absorbed)
    if (!hasObject3d(obj)) return 0;
    // @orig 1048:08b8 object3d_get_world_elev
    return obj.o3d.worldElev;
}

/// SceneObject slot 08 getSizeW.
pub fn getSizeW(g: *Game, obj: *Object) i16 {
    _ = g;
    // @orig 10c0:345e scene_object_get_size_w_default (absorbed)
    if (!hasObject3d(obj)) return 0;
    // @orig 1048:08d5 object3d_get_size_w
    return obj.o3d.sizeW;
}

/// SceneObject slot 09 getSizeH.
pub fn getSizeH(g: *Game, obj: *Object) i16 {
    _ = g;
    // @orig 10c0:3478 scene_object_get_size_h_default (absorbed)
    if (!hasObject3d(obj)) return 0;
    // @orig 1048:08f2 object3d_get_size_h
    return obj.o3d.sizeH;
}

/// SceneObject slot 0A getSizeD.
pub fn getSizeD(g: *Game, obj: *Object) i16 {
    _ = g;
    // @orig 10c0:3492 scene_object_get_size_d_default (absorbed)
    if (!hasObject3d(obj)) return 0;
    // @orig 1048:090f object3d_get_size_d
    return obj.o3d.sizeD;
}

/// SceneObject slot 0B getAnchorX.
pub fn getAnchorX(g: *Game, obj: *Object) i16 {
    _ = g;
    // @orig 10c0:34ac scene_object_get_anchor_x_default (absorbed)
    if (!hasObject3d(obj)) return 0;
    // @orig 10c0:2232 object3d_get_anchor_x
    return obj.o3d.anchorX;
}

/// SceneObject slot 0C getAnchorY.
pub fn getAnchorY(g: *Game, obj: *Object) i16 {
    _ = g;
    // @orig 10c0:34c6 scene_object_get_anchor_y_default (absorbed)
    if (!hasObject3d(obj)) return 0;
    // @orig 10c0:2250 object3d_get_anchor_y
    return obj.o3d.anchorY;
}

/// The anchor point's screen position as the unprojection wants it
/// (`y` is measured up from the bottom of the view).
fn anchorScreen(obj: *const Object, bd: *const Backdrop, x: i16, y: i16) ScreenPoint {
    return .{
        .x = (x -% bd.originX) +% obj.o3d.anchorX,
        .y = ((bd.originY -% y) -% obj.o3d.anchorY) +% bd.viewHeight,
    };
}

// @orig 1048:0de1 object3d_set_elevation
fn object3dSetElevation(g: *Game, obj: *Object, bd: *Backdrop, elev: i16) ?*Object {
    const s = anchorScreen(obj, bd, obj.x, obj.y);
    obj.o3d.worldElev = elev;
    const w = unprojectPoint(g, bd, elev, s.x, s.y);
    obj.o3d.worldX = w.x;
    obj.o3d.worldDepth = w.depth;
    return obj;
}

// @orig 1048:0eba moveable_set_elevation
fn moveableSetElevation(g: *Game, obj: *Object, bd: *Backdrop, elev: i16) ?*Object {
    _ = object3dSetElevation(g, obj, bd, elev);
    // The shift runs only when `eye + depth` is positive (a signed 32-bit test;
    // NOITE's twin tests for non-zero).
    const den: i32 = @as(i32, getEyeDistance(g, bd)) + obj.o3d.worldDepth;
    if (den > 0) {
        obj.o3d.worldX +%= perspectiveShift(obj.o3d.sizeW, obj.o3d.worldDepth, getEyeDistance(g, bd));
    }
    return obj;
}

/// SceneObject slot 12 setElevation (Ghidra: this, elev, backdrop).
pub fn setElevation(g: *Game, obj: *Object, bd: *Backdrop, elev: i16) ?*Object {
    return switch (obj.kind) {
        // @orig 10c0:356a scene_object_set_elevation_default (absorbed)
        .scene_object, .wall_strip => obj,
        // @orig 1048:0fd4 portable_set_elevation
        .portable => moveableSetElevation(g, obj, bd, elev),
        .player => moveableSetElevation(g, obj, bd, elev),
        .exit, .control_panel => object3dSetElevation(g, obj, bd, elev),
    };
}

/// SceneObject slot 13 setAnchor.
pub fn setAnchor(g: *Game, obj: *Object, x: i16, y: i16) ?*Object {
    _ = g;
    // @orig 10c0:3586 scene_object_set_anchor_default (absorbed)
    if (!hasObject3d(obj)) return obj;
    // @orig 1048:14f8 object3d_set_anchor
    obj.o3d.anchorX = x;
    obj.o3d.anchorY = y;
    return obj;
}

/// SceneObject slot 14 setSize.
pub fn setSize(g: *Game, obj: *Object, w: i16, h: i16, d: i16) ?*Object {
    _ = g;
    // @orig 10c0:35a2 scene_object_set_size_default (absorbed)
    if (!hasObject3d(obj)) return obj;
    // @orig 1048:1498 object3d_set_size
    obj.o3d.sizeW = w;
    obj.o3d.sizeH = h;
    obj.o3d.sizeD = d;
    return obj;
}

/// SceneObject slot 15 setWorldElev: the Portable's / default.
pub fn setWorldElev(g: *Game, obj: *Object, elev: i16) ?*Object {
    _ = g;
    // @orig 10c0:35be scene_object_set_world_elev_default (absorbed)
    if (obj.kind != .portable) return obj;
    // @orig 10c0:2898 portable_set_world_elev
    obj.o3d.worldElev = elev;
    return obj;
}

/// SceneObject slot 16 drawBounds (hdc dropped).
pub fn drawBounds(g: *Game, obj: *Object, bd: *Backdrop) ?*Object {
    _ = g;
    _ = bd;
    // @orig 10c0:35da scene_object_draw_bounds_default (absorbed)
    if (!hasObject3d(obj)) return obj;
    // @orig 1048:032b object3d_draw_bounds
    // A debug view: draws the projected 3D box as a yellow wireframe
    // (CreatePen/MoveTo/LineTo) on the caller's DC. The DC is dropped from the
    // signature, nothing reaches the slot, and the projections have no other
    // effect: nothing to do but return this.
    return obj;
}

/// SceneObject slot 3D moveToAndDrop.
pub fn moveToAndDrop(g: *Game, obj: *Object, x: i16, y: i16, bd: *Backdrop) void {
    switch (obj.kind) {
        // @orig 10c0:3b08 scene_object_move_to_and_drop_default (absorbed)
        .scene_object, .wall_strip => {},
        // @orig 1048:109d moveable_move_to_and_drop
        .player => {
            position.setPosition(g, obj, x, y); // mover_set_position
            _ = setElevation(g, obj, bd, 0);
        },
        // @orig 1048:1003 portable_move_to_and_drop
        .portable => {
            position.setPosition(g, obj, x, y); // mover_set_position; the backdrop is unused
            obj.o3d.worldElev = 0;
            obj.o3d.worldDepth = 0;
            obj.o3d.worldX = 0;
        },
        // @orig 1048:115c object3d_move_to_and_drop
        .exit, .control_panel => {
            position.setPosition(g, obj, x, y); // scene_object_set_position
            const s = findSupport(g, obj, bd);
            obj.o3d.support = s.support;
            _ = setElevation(g, obj, bd, s.result);
        },
    }
}

/// Object3DVtbl slot 00 (object3d_slot00).
pub fn slot00(g: *Game, obj: *Object) i16 {
    _ = g;
    _ = obj;
    // @orig 10c0:4cc4 object3d_slot00
    return 0;
}

/// Object3DVtbl slot 01 findSupport: the support found (out parameter) and the result.
// @orig 1048:188a object3d_find_support
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

/// Object3DVtbl slot 02 isBelow (portable_is_below forwards to Object3D's).
pub fn isBelow(g: *Game, obj: *Object, other: *Object, bd: *Backdrop) bool {
    // @orig 1048:154e portable_is_below
    return object3dIsBelow(g, obj, other, bd);
}

// @orig 1048:158c object3d_is_below
fn object3dIsBelow(g: *Game, obj: *Object, other: *Object, bd: *Backdrop) bool {
    const s = anchorScreen(obj, bd, obj.x, obj.y);
    const w = unprojectPoint(g, bd, obj.o3d.worldElev, s.x, s.y);
    var x = w.x;
    if (w.depth < 1) {
        x +%= @divTrunc(obj.o3d.sizeW, 2);
    } else {
        x +%= perspectiveShift(obj.o3d.sizeW, w.depth, getEyeDistance(g, bd));
    }
    const o = boxOf(g, other);
    if (obj.o3d.sizeW +% x < o.x) return false;
    if (o.w +% o.x < x) return false;
    if (obj.o3d.sizeD +% w.depth < o.depth) return false;
    if (o.d +% o.depth < w.depth) return false;
    return obj.o3d.worldElev < o.elev;
}

/// Object3DVtbl slot 03 isAboveOnScreen (the backdrop is unused).
// @orig 1048:175b object3d_is_above_on_screen
pub fn isAboveOnScreen(g: *Game, obj: *Object, other: *Object, bd: *Backdrop) bool {
    _ = g;
    _ = bd;
    const left = obj.x +% position.hitX(obj);
    if (left +% position.hitW(obj) < position.hitX(other) +% other.x) return false;
    if (position.hitX(other) +% position.hitW(other) +% other.x < left) return false;
    return position.hitY(obj) +% obj.y < position.hitY(other) +% other.y;
}

/// Object3DVtbl slot 04 isInFrontOf (the draw list's order).
// @orig 1048:19d2 object3d_is_in_front_of
pub fn isInFrontOf(g: *Game, obj: *Object, other: *Object, bd: *Backdrop) bool {
    if (other.o3d.worldDepth +% other.o3d.sizeD < obj.o3d.worldDepth) return false;
    if (obj.o3d.worldDepth +% obj.o3d.sizeD < other.o3d.worldDepth) return true;
    if (isBelow(g, obj, other, bd)) return false;
    if (isBelow(g, other, obj, bd)) return true;
    if (!position.hitboxOverlaps(g, obj, other)) return true;
    if (obj.x +% obj.o3d.anchorX <= 0) return false;
    const p = projectPoint(g, bd, other.o3d.worldX, other.o3d.worldDepth, other.o3d.worldElev);
    const mine = abs16((getVanishX(g, bd) -% obj.x) -% obj.o3d.anchorX);
    const theirs = abs16(getVanishX(g, bd) -% p.x);
    return mine <= theirs;
}

/// Object3DVtbl slot 05 overlaps3d.
// @orig 1048:092c object3d_overlaps_3d
pub fn overlaps3d(g: *Game, obj: *Object, other: *Object, bd: *Backdrop) bool {
    // This object's anchor at the screen position held in nextX/nextY.
    const s = anchorScreen(obj, bd, obj.nextX, obj.nextY);
    const w = unprojectPoint(g, bd, obj.o3d.worldElev, s.x, s.y);
    const x = w.x +% perspectiveShift(obj.o3d.sizeW, w.depth, getEyeDistance(g, bd));
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
pub fn moveToAtElev(g: *Game, obj: *Object, x: i16, y: i16, bd: *Backdrop, elev: i16) void {
    switch (obj.kind) {
        // @orig 1048:10f8 moveable_move_to_at_elev
        // @orig 1048:1068 portable_move_to_at_elev
        .player, .portable => {
            position.setPosition(g, obj, x, y); // mover_set_position
            _ = setElevation(g, obj, bd, elev);
        },
        // @orig 1048:11f2 object3d_move_to_at_elev
        else => {
            position.setPosition(g, obj, x, y); // scene_object_set_position
            _ = setElevation(g, obj, bd, elev);
        },
    }
}

/// Object3DVtbl slot 07 dropToSupport.
pub fn dropToSupport(g: *Game, obj: *Object, bd: *Backdrop) void {
    switch (obj.kind) {
        // @orig 1048:0d94 moveable_drop_to_support
        .player => {
            _ = setElevation(g, obj, bd, 0);
        },
        // @orig 1048:0d16 portable_drop_to_support
        .portable => {
            const s = findSupport(g, obj, bd);
            obj.o3d.support = s.support;
            _ = moveableSetElevation(g, obj, bd, s.result);
        },
        // @orig 1048:0ca7 object3d_drop_to_support
        else => {
            const s = findSupport(g, obj, bd);
            obj.o3d.support = s.support;
            _ = setElevation(g, obj, bd, s.result);
        },
    }
}
