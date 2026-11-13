//! Port unit `animation` (behaviour). SceneObject slots 2D-2F, 31-33, 35, 36, 3D, 3F and Animation playOnce/setStrip: frames, idle, stop, timer id.
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

/// SceneObject slot 2D (skeleton stub: unported until this unit is).
pub fn isAvi(g: *Game, obj: *Object) bool {
    _ = .{g};
    return switch (obj.kind) {
        // @orig 1010:1ab0 scene_object_is_avi_default (absorbed)
        .local, .moveable, .portable, .status_bar => false,
        else => stub.unported("animation.isAvi"),
    };
}

/// SceneObject slot 2E (skeleton stub: unported until this unit is).
pub fn nextFrame(g: *Game, obj: *Object) i16 {
    _ = .{g};
    return switch (obj.kind) {
        // @orig 1010:1abc scene_object_next_frame_default (absorbed)
        .local, .moveable, .status_bar => 0,
        else => stub.unported("animation.nextFrame"),
    };
}

/// SceneObject slot 2F (skeleton stub: unported until this unit is).
pub fn prevFrame(g: *Game, obj: *Object) i16 {
    _ = .{g};
    return switch (obj.kind) {
        // @orig 1010:1ac8 scene_object_prev_frame_default (absorbed)
        .local, .moveable, .status_bar => 0,
        else => stub.unported("animation.prevFrame"),
    };
}

/// SceneObject slot 31 (skeleton stub: unported until this unit is).
pub fn playIdle(g: *Game, obj: *Object, bd: *Backdrop) void {
    _ = .{ g, bd };
    switch (obj.kind) {
        // @orig 1010:1ade scene_object_play_idle_default (absorbed)
        .local, .animated, .moveable, .actor, .exit, .portable, .control_panel, .status_bar => {},
        else => stub.unported("animation.playIdle"),
    }
}

/// SceneObject slot 32 (skeleton stub: unported until this unit is).
pub fn stopAndRedrawDc(g: *Game, obj: *Object, bd: *Backdrop) void {
    _ = .{ g, bd };
    switch (obj.kind) {
        // @orig 1010:1af2 scene_object_stop_and_redraw_dc_default (absorbed)
        .local, .moveable, .portable, .status_bar => {},
        else => stub.unported("animation.stopAndRedrawDc"),
    }
}

/// SceneObject slot 33 (skeleton stub: unported until this unit is).
pub fn stopAndRedraw(g: *Game, obj: *Object, bd: *Backdrop) void {
    _ = .{ g, bd };
    switch (obj.kind) {
        // @orig 1010:1ae8 scene_object_stop_and_redraw_default (absorbed)
        .local, .moveable, .portable, .status_bar => {},
        else => stub.unported("animation.stopAndRedraw"),
    }
}

/// SceneObject slot 35 (skeleton stub: unported until this unit is).
pub fn stop(g: *Game, obj: *Object) void {
    _ = .{g};
    switch (obj.kind) {
        // @orig 1010:1b06 scene_object_stop_default (absorbed)
        .local, .moveable, .portable, .status_bar => {},
        else => stub.unported("animation.stop"),
    }
}

/// SceneObject slot 36 (skeleton stub: unported until this unit is).
pub fn advanceFrames(g: *Game, obj: *Object, unused: i16, bd: *Backdrop, n: i16) void {
    _ = .{ g, unused, bd, n };
    switch (obj.kind) {
        // @orig 1010:1b10 scene_object_advance_frames_default (absorbed)
        .local, .moveable, .portable, .status_bar => {},
        else => stub.unported("animation.advanceFrames"),
    }
}

/// SceneObject slot 3D (skeleton stub: unported until this unit is).
pub fn getTimerId(g: *Game, obj: *Object) i16 {
    _ = .{g};
    return switch (obj.kind) {
        // @orig 1010:1b56 scene_object_get_timer_id_default (absorbed)
        .local, .status_bar => -1,
        else => stub.unported("animation.getTimerId"),
    };
}

/// SceneObject slot 3F (skeleton stub: unported until this unit is).
pub fn isRunning(g: *Game, obj: *Object) bool {
    _ = .{g};
    return switch (obj.kind) {
        // @orig 1010:1b70 scene_object_is_running_default (absorbed)
        .local, .moveable, .portable, .status_bar => false,
        else => stub.unported("animation.isRunning"),
    };
}

/// Animation slot 07 (skeleton stub: unported until this unit is).
pub fn playOnce(g: *Game, obj: *Object, bd: *Backdrop) void {
    _ = .{ g, obj, bd };
    stub.unported("animation.playOnce");
}

/// DirectionalPlayer slot 01 (no callers) (skeleton stub: unported until this unit is).
pub fn playWalkH(g: *Game, obj: *Object, bd: *Backdrop, dir: i16) void {
    _ = .{ g, obj, bd, dir };
    stub.unported("animation.playWalkH");
}
