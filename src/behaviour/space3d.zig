//! Port unit `space3d` (behaviour). Object3D: SceneObject slots 05-0C, 12-15, 40 and the Object3D vtable (support, stacking, depth order).
//!
//! Virtual-slot dispatchers owned by this unit are declared below with
//! their final signatures; their bodies panic until the unit is ported
//! (docs/DESIGN.md "Virtual slots → dispatchers"). Replace each body, keep
//! the signature (other units already call it).

const stub = @import("../core/stub.zig");
const Game = @import("../core/game.zig").Game;
const object = @import("../core/object.zig");
const Object = object.Object;
const world = @import("../core/world.zig");
const Backdrop = world.Backdrop;

/// SceneObject slot 05 (skeleton stub: unported until this unit is).
pub fn getWorldX(g: *Game, obj: *Object) i16 {
    _ = .{g};
    return switch (obj.kind) {
        // @orig 1010:1342 scene_object_get_world_x_default (absorbed)
        .status_bar => 0,
        else => stub.unported("space3d.getWorldX"),
    };
}

/// SceneObject slot 06 (skeleton stub: unported until this unit is).
pub fn getWorldDepth(g: *Game, obj: *Object) i16 {
    _ = .{g};
    return switch (obj.kind) {
        // @orig 1010:134e scene_object_get_world_depth_default (absorbed)
        .status_bar => 0,
        else => stub.unported("space3d.getWorldDepth"),
    };
}

/// SceneObject slot 07 (skeleton stub: unported until this unit is).
pub fn getWorldElev(g: *Game, obj: *Object) i16 {
    _ = .{g};
    return switch (obj.kind) {
        // @orig 1010:135a scene_object_get_world_elev_default (absorbed)
        .status_bar => 0,
        else => stub.unported("space3d.getWorldElev"),
    };
}

/// SceneObject slot 08 (skeleton stub: unported until this unit is).
pub fn getSizeW(g: *Game, obj: *Object) i16 {
    _ = .{g};
    return switch (obj.kind) {
        // @orig 1010:1366 scene_object_get_size_w_default (absorbed)
        .status_bar => 0,
        else => stub.unported("space3d.getSizeW"),
    };
}

/// SceneObject slot 09 (skeleton stub: unported until this unit is).
pub fn getSizeH(g: *Game, obj: *Object) i16 {
    _ = .{g};
    return switch (obj.kind) {
        // @orig 1010:1372 scene_object_get_size_h_default (absorbed)
        .status_bar => 0,
        else => stub.unported("space3d.getSizeH"),
    };
}

/// SceneObject slot 0A (skeleton stub: unported until this unit is).
pub fn getSizeD(g: *Game, obj: *Object) i16 {
    _ = .{g};
    return switch (obj.kind) {
        // @orig 1010:137e scene_object_get_size_d_default (absorbed)
        .status_bar => 0,
        else => stub.unported("space3d.getSizeD"),
    };
}

/// SceneObject slot 0B (skeleton stub: unported until this unit is).
pub fn getAnchorX(g: *Game, obj: *Object) i16 {
    _ = .{g};
    return switch (obj.kind) {
        // @orig 1010:138a scene_object_get_anchor_x_default (absorbed)
        .status_bar => 0,
        else => stub.unported("space3d.getAnchorX"),
    };
}

/// SceneObject slot 0C (skeleton stub: unported until this unit is).
pub fn getAnchorY(g: *Game, obj: *Object) i16 {
    _ = .{g};
    return switch (obj.kind) {
        // @orig 1010:1396 scene_object_get_anchor_y_default (absorbed)
        .status_bar => 0,
        else => stub.unported("space3d.getAnchorY"),
    };
}

/// SceneObject slot 12 (skeleton stub: unported until this unit is).
pub fn setElevation(g: *Game, obj: *Object, bd: *Backdrop, elev: i16) ?*Object {
    _ = .{ g, bd, elev };
    return switch (obj.kind) {
        // @orig 1010:13f2 scene_object_set_elevation_default (absorbed)
        .status_bar => obj,
        else => stub.unported("space3d.setElevation"),
    };
}

/// SceneObject slot 13 (skeleton stub: unported until this unit is).
pub fn setAnchor(g: *Game, obj: *Object, x: i16, y: i16) ?*Object {
    _ = .{ g, x, y };
    return switch (obj.kind) {
        // @orig 1010:1406 scene_object_set_anchor_default (absorbed)
        .status_bar => obj,
        else => stub.unported("space3d.setAnchor"),
    };
}

/// SceneObject slot 14 (skeleton stub: unported until this unit is).
pub fn setSize(g: *Game, obj: *Object, w: i16, h: i16, d: i16) ?*Object {
    _ = .{ g, w, h, d };
    return switch (obj.kind) {
        // @orig 1010:141a scene_object_set_size_default (absorbed)
        .status_bar => obj,
        else => stub.unported("space3d.setSize"),
    };
}

/// SceneObject slot 15 (skeleton stub: unported until this unit is).
pub fn setWorldElev(g: *Game, obj: *Object, elev: i16) ?*Object {
    _ = .{ g, elev };
    return switch (obj.kind) {
        // @orig 1010:142e scene_object_set_world_elev_default (absorbed)
        .local, .animated, .moveable, .actor, .player, .exit, .control_panel, .status_bar => obj,
        else => stub.unported("space3d.setWorldElev"),
    };
}

/// SceneObject slot 40 (skeleton stub: unported until this unit is).
pub fn moveToAndDrop(g: *Game, obj: *Object, x: i16, y: i16, bd: *Backdrop) void {
    _ = .{ g, x, y, bd };
    switch (obj.kind) {
        // @orig 1010:1b9e scene_object_move_to_and_drop_default (absorbed)
        .status_bar => {},
        else => stub.unported("space3d.moveToAndDrop"),
    }
}

/// Object3D slot 00 (skeleton stub: unported until this unit is).
pub fn slot00(g: *Game, obj: *Object) i16 {
    _ = .{ g, obj };
    stub.unported("space3d.slot00");
}

/// Object3D slot 01's result: the return value (top of the supporting
/// object, 0 when none) and `*out_support`, which the original always
/// writes (null when nothing supports the object).
pub const Support = struct { top: i16, support: ?*Object };

/// Object3D slot 01 (skeleton stub: unported until this unit is).
pub fn findSupport(g: *Game, obj: *Object, bd: *Backdrop) Support {
    _ = .{ g, obj, bd };
    stub.unported("space3d.findSupport");
}

/// Object3D slot 02 (skeleton stub: unported until this unit is).
pub fn isBelow(g: *Game, obj: *Object, other: *Object, bd: *Backdrop) bool {
    _ = .{ g, obj, other, bd };
    stub.unported("space3d.isBelow");
}

/// Object3D slot 03 (skeleton stub: unported until this unit is).
pub fn isAboveOnScreen(g: *Game, obj: *Object, other: *Object, bd: *Backdrop) bool {
    _ = .{ g, obj, other, bd };
    stub.unported("space3d.isAboveOnScreen");
}

/// Object3D slot 04 (skeleton stub: unported until this unit is).
pub fn isInFrontOf(g: *Game, obj: *Object, other: *Object, bd: *Backdrop) bool {
    _ = .{ g, obj, other, bd };
    stub.unported("space3d.isInFrontOf");
}

/// Object3D slot 05 (skeleton stub: unported until this unit is).
pub fn overlaps3d(g: *Game, obj: *Object, other: *Object, bd: *Backdrop) bool {
    _ = .{ g, obj, other, bd };
    stub.unported("space3d.overlaps3d");
}

/// Object3D slot 06 (skeleton stub: unported until this unit is).
pub fn moveToAtElev(g: *Game, obj: *Object, x: i16, y: i16, bd: *Backdrop, elev: i16) void {
    _ = .{ g, obj, x, y, bd, elev };
    stub.unported("space3d.moveToAtElev");
}

/// Object3D slot 07 (skeleton stub: unported until this unit is).
pub fn dropToSupport(g: *Game, obj: *Object, bd: *Backdrop) void {
    _ = .{ g, obj, bd };
    stub.unported("space3d.dropToSupport");
}
