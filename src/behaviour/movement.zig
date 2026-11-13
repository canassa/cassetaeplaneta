//! Port unit `movement` (behaviour). SceneObject slots 37-3C, 3E and Mover placeAt: walking, edge walks, stop, movement tick.
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

/// SceneObject slot 37 (skeleton stub: unported until this unit is).
pub fn moveTo(g: *Game, obj: *Object, x: i16, y: i16, bd: *Backdrop) void {
    _ = .{ g, x, y, bd };
    switch (obj.kind) {
        // @orig 1010:1b1a scene_object_move_to_default (absorbed)
        .local, .animated, .exit, .control_panel, .status_bar => {},
        else => stub.unported("movement.moveTo"),
    }
}

/// SceneObject slot 38 (skeleton stub: unported until this unit is).
pub fn moveToEdgeH(g: *Game, obj: *Object, bd: *Backdrop, dir: i16) void {
    _ = .{ g, bd, dir };
    switch (obj.kind) {
        // @orig 1010:1b24 scene_object_move_to_edge_h_default (absorbed)
        .local, .animated, .exit, .control_panel, .status_bar => {},
        else => stub.unported("movement.moveToEdgeH"),
    }
}

/// SceneObject slot 39 (skeleton stub: unported until this unit is).
pub fn moveToEdgeV(g: *Game, obj: *Object, bd: *Backdrop, dir: i16) void {
    _ = .{ g, bd, dir };
    switch (obj.kind) {
        // @orig 1010:1b2e scene_object_move_to_edge_v_default (absorbed)
        .local, .animated, .exit, .control_panel, .status_bar => {},
        else => stub.unported("movement.moveToEdgeV"),
    }
}

/// SceneObject slot 3A (skeleton stub: unported until this unit is).
pub fn stopMovingDc(g: *Game, obj: *Object, bd: *Backdrop) void {
    _ = .{ g, bd };
    switch (obj.kind) {
        // @orig 1010:1b42 scene_object_stop_moving_dc_default (absorbed)
        .local, .animated, .exit, .control_panel, .status_bar => {},
        else => stub.unported("movement.stopMovingDc"),
    }
}

/// SceneObject slot 3B (skeleton stub: unported until this unit is).
pub fn stopMoving(g: *Game, obj: *Object, bd: *Backdrop) void {
    _ = .{ g, bd };
    switch (obj.kind) {
        // @orig 1010:1b38 scene_object_stop_moving_default (absorbed)
        .local, .animated, .exit, .control_panel, .status_bar => {},
        else => stub.unported("movement.stopMoving"),
    }
}

/// SceneObject slot 3C (skeleton stub: unported until this unit is).
pub fn moveTick(g: *Game, obj: *Object, bd: *Backdrop) void {
    _ = .{ g, bd };
    switch (obj.kind) {
        // @orig 1010:1b4c scene_object_move_tick_default (absorbed)
        .local, .animated, .exit, .control_panel, .status_bar => {},
        else => stub.unported("movement.moveTick"),
    }
}

/// SceneObject slot 3E (skeleton stub: unported until this unit is).
pub fn isMoving(g: *Game, obj: *Object) bool {
    _ = .{g};
    return switch (obj.kind) {
        // @orig 1010:1b64 scene_object_is_moving_default (absorbed)
        .local, .animated, .exit, .control_panel, .status_bar => false,
        else => stub.unported("movement.isMoving"),
    };
}

/// Mover slot 00 (DirectionalPlayer slot 00) (skeleton stub: unported until this unit is).
pub fn placeAt(g: *Game, obj: *Object, x: i16, y: i16, bd: *Backdrop) void {
    _ = .{ g, obj, x, y, bd };
    stub.unported("movement.placeAt");
}
