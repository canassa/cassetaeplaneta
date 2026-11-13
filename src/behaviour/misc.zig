//! Port unit `misc` (behaviour). SceneObject slots 00-04 (touched mark, RLE mode, scene name) and 1F (empty debug hook).
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

/// SceneObject slot 00 (skeleton stub: unported until this unit is).
pub fn slot00(g: *Game, obj: *Object) void {
    _ = .{ g, obj };
    stub.unported("misc.slot00");
}

/// SceneObject slot 01 (skeleton stub: unported until this unit is).
pub fn slot01(g: *Game, obj: *Object) i16 {
    _ = .{ g, obj };
    stub.unported("misc.slot01");
}

/// SceneObject slot 02 (skeleton stub: unported until this unit is).
pub fn enableRle(g: *Game, obj: *Object) void {
    _ = .{ g, obj };
    stub.unported("misc.enableRle");
}

/// SceneObject slot 03 (skeleton stub: unported until this unit is).
pub fn isRle(g: *Game, obj: *Object) bool {
    _ = .{ g, obj };
    stub.unported("misc.isRle");
}

/// SceneObject slot 04 (skeleton stub: unported until this unit is).
pub fn getSceneName(g: *Game, obj: *Object) []const u8 {
    _ = .{ g, obj };
    stub.unported("misc.getSceneName");
}

/// SceneObject slot 1F (skeleton stub: unported until this unit is).
pub fn slot1F(g: *Game, obj: *Object, bd: *Backdrop) void {
    _ = .{ g, obj, bd };
    stub.unported("misc.slot1F");
}
