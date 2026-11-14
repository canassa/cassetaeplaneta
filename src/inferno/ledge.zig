//! Port unit `ledge` (module) of INFERNO.EXE. the Platform class (4 platforms
//! carrying the drinks): its SceneObject overrides (play, moveToEdgeH,
//! moveTick), PlatformVtbl moveTick (platform_tick, the respawn), drop_cross,
//! inferno_create_platforms.
//!
//! The class's SceneObject overrides are declared below with their final
//! signatures (the slot units' dispatchers call them; docs/inferno/DESIGN.md
//! "Virtual slots"); their bodies panic until the unit is ported. Replace
//! each body, keep the signature. Each function carries
//! `// @orig <seg:xxxx> <name>` with the INFERNO address.

const std = @import("std");
const stub = @import("../core/stub.zig");
const msg = @import("../core/msg.zig");
const Msg = msg.Msg;
const Game = @import("core/game.zig").Game;
const object = @import("core/object.zig");
const Object = object.Object;
const ObjectList = object.ObjectList;
const Frame = object.Frame;
const FrameCell = object.FrameCell;
const BitmapInfoHeader = object.BitmapInfoHeader;
const world = @import("core/world.zig");
const Backdrop = world.Backdrop;
const Scene = world.Scene;
const Condition = world.Condition;
const RectQuery = world.RectQuery;

/// SceneObject slot 29 play override (platform_play: +100 for the drink, or
/// the present; animation.play's platform arm).
pub fn play(g: *Game, obj: *Object, bd: *Backdrop) void {
    _ = g;
    _ = obj;
    _ = bd;
    stub.unported("inferno.ledge.play");
}

/// SceneObject slot 30 moveToEdgeH override (platform_move_to_edge_h;
/// movement.moveToEdgeH's platform arm).
pub fn moveToEdgeH(g: *Game, obj: *Object, bd: *Backdrop, dir: i16) void {
    _ = g;
    _ = obj;
    _ = bd;
    _ = dir;
    stub.unported("inferno.ledge.moveToEdgeH");
}

/// SceneObject slot 34 moveTick override (platform_move_tick;
/// movement.moveTick's platform arm).
pub fn moveTick(g: *Game, obj: *Object, bd: *Backdrop) void {
    _ = g;
    _ = obj;
    _ = bd;
    stub.unported("inferno.ledge.moveTick");
}
