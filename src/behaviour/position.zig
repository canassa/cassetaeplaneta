//! Port unit `position` (behaviour). SceneObject slots 0D-10 getX/getY/getStep, 41 setPosition, 42 isScrollTarget, 59/5A overlap tests.
//!
//! Virtual-slot dispatchers owned by this unit are declared below with
//! their final signatures; their bodies panic until the unit is ported
//! (docs/DESIGN.md "Virtual slots → dispatchers"). Replace each body, keep
//! the signature (other units already call it).

const Game = @import("../core/game.zig").Game;
const object = @import("../core/object.zig");
const frames = @import("../frames.zig");
const Object = object.Object;

/// SceneObject slot 0D.
pub fn getX(g: *Game, obj: *Object) i16 {
    _ = g;
    return switch (obj.kind) {
        .moveable, .actor, .player, .portable => moverGetX(obj),
        else => sceneObjectGetX(obj),
    };
}

// @orig 1010:13a2 scene_object_get_x
fn sceneObjectGetX(obj: *Object) i16 {
    return obj.x;
}

// @orig 1010:2b9a mover_get_x
fn moverGetX(obj: *Object) i16 {
    return obj.mover.prevX;
}

/// SceneObject slot 0E.
pub fn getY(g: *Game, obj: *Object) i16 {
    _ = g;
    return switch (obj.kind) {
        .moveable, .actor, .player, .portable => moverGetY(obj),
        else => sceneObjectGetY(obj),
    };
}

// @orig 1010:13b8 scene_object_get_y
fn sceneObjectGetY(obj: *Object) i16 {
    return obj.y;
}

// @orig 1010:2bb0 mover_get_y
fn moverGetY(obj: *Object) i16 {
    return obj.mover.prevY;
}

/// |v| the way the original computes it (CWD; XOR; SUB), so -32768 stays.
fn abs16(v: i16) i16 {
    const s = v >> 15;
    return (v ^ s) -% s;
}

/// SceneObject slot 0F.
pub fn getStepX(g: *Game, obj: *Object) i16 {
    _ = g;
    return switch (obj.kind) {
        .moveable, .actor, .player, .portable => moverGetStepX(obj),
        // @orig 1010:13ce scene_object_get_step_x_default (absorbed)
        else => 0,
    };
}

// @orig 1010:2bc6 mover_get_step_x
fn moverGetStepX(obj: *Object) i16 {
    return abs16(obj.mover.stepX);
}

/// SceneObject slot 10.
pub fn getStepY(g: *Game, obj: *Object) i16 {
    _ = g;
    return switch (obj.kind) {
        .moveable, .actor, .player, .portable => moverGetStepY(obj),
        // @orig 1010:13da scene_object_get_step_y_default (absorbed)
        else => 0,
    };
}

// @orig 1010:2be0 mover_get_step_y
fn moverGetStepY(obj: *Object) i16 {
    return abs16(obj.mover.stepY);
}

/// SceneObject slot 41.
pub fn setPosition(g: *Game, obj: *Object, x: i16, y: i16) void {
    _ = g;
    switch (obj.kind) {
        .moveable, .actor, .player, .portable => moveableSetPosition(obj, x, y),
        else => sceneObjectSetPosition(obj, x, y),
    }
}

// @orig 1010:1b7c scene_object_set_position
fn sceneObjectSetPosition(obj: *Object, x: i16, y: i16) void {
    obj.x = x;
    obj.y = y;
}

// @orig 1010:3ba6 moveable_set_position
fn moveableSetPosition(obj: *Object, x: i16, y: i16) void {
    moverSetPosition(obj, x, y);
}

// @orig 1010:2b62 mover_set_position
fn moverSetPosition(obj: *Object, x: i16, y: i16) void {
    obj.mover.prevX = obj.x;
    obj.mover.prevY = obj.y;
    obj.x = x;
    obj.y = y;
}

/// SceneObject slot 42.
pub fn isScrollTarget(g: *Game, obj: *Object) bool {
    _ = g;
    return switch (obj.kind) {
        .player => playerIsScrollTarget(),
        else => sceneObjectIsScrollTarget(),
    };
}

// @orig 1010:1ba8 scene_object_is_scroll_target
fn sceneObjectIsScrollTarget() bool {
    return false;
}

// @orig 1010:4148 player_is_scroll_target
fn playerIsScrollTarget() bool {
    return true;
}

/// SceneObject slot 59.
// @orig 1010:bc1e scene_object_hitbox_overlaps
pub fn hitboxOverlaps(g: *Game, obj: *Object, other: *Object) bool {
    _ = g;
    if (other.x +% frames.hitX(other) > obj.x +% frames.hitX(obj) +% frames.hitW(obj)) return false;
    if (obj.x +% frames.hitX(obj) > other.x +% frames.hitX(other) +% frames.hitW(other)) return false;
    if (other.y +% frames.hitY(other) > obj.y +% frames.hitY(obj) +% frames.hitH(obj)) return false;
    if (obj.y +% frames.hitY(obj) > other.y +% frames.hitY(other) +% frames.hitH(other)) return false;
    return true;
}

/// SceneObject slot 5A.
// @orig 1010:bd2a scene_object_bounds_overlap
pub fn boundsOverlap(g: *Game, obj: *Object, other: *Object) bool {
    _ = g;
    if (frames.width(obj) +% obj.x < other.x) return false;
    if (frames.width(other) +% other.x < obj.x) return false;
    if (frames.height(obj) +% obj.y < other.y) return false;
    if (frames.height(other) +% other.y < obj.y) return false;
    return true;
}
