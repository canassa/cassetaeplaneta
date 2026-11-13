//! Port unit `exit` (module). exit links and key objects; SceneObject slots 5F isEnabled and 60 getExitIndex.
//!
//! Virtual-slot dispatchers owned by this unit are declared below with
//! their final signatures; their bodies panic until the unit is ported
//! (docs/DESIGN.md "Virtual slots → dispatchers"). Replace each body, keep
//! the signature (other units already call it).

const stub = @import("core/stub.zig");
const Game = @import("core/game.zig").Game;
const object = @import("core/object.zig");
const Object = object.Object;

/// SceneObject slot 5F (skeleton stub: unported until this unit is).
pub fn isEnabled(g: *Game, obj: *Object) bool {
    _ = .{g};
    return switch (obj.kind) {
        // @orig 1010:1cf8 scene_object_is_enabled_default (absorbed)
        .local, .animated, .moveable, .actor, .player, .portable, .control_panel, .status_bar => false,
        else => stub.unported("exit.isEnabled"),
    };
}

/// SceneObject slot 60 (skeleton stub: unported until this unit is).
pub fn getExitIndex(g: *Game, obj: *Object) i16 {
    _ = .{g};
    return switch (obj.kind) {
        // @orig 1010:1d04 scene_object_get_exit_index_default (absorbed)
        .local, .animated, .moveable, .actor, .player, .portable, .control_panel, .status_bar => -1,
        else => stub.unported("exit.getExitIndex"),
    };
}
