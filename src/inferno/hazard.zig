//! Port unit `hazard` (module) of INFERNO.EXE. the Hazard class (coal, devil,
//! fire): its SceneObject overrides (stopMoving, moveTick), PropVtbl moveTick
//! (hazard_tick), spawn/despawn, hazard_hit_player (BUGS.md H6, H7),
//! inferno_create_hazards.
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

/// SceneObject slot 33 stopMoving override (hazard_stop_moving;
/// movement.stopMoving's hazard arm).
pub fn stopMoving(g: *Game, obj: *Object, bd: *Backdrop) void {
    _ = g;
    _ = obj;
    _ = bd;
    stub.unported("inferno.hazard.stopMoving");
}

/// SceneObject slot 34 moveTick override (hazard_move_tick;
/// movement.moveTick's hazard arm).
pub fn moveTick(g: *Game, obj: *Object, bd: *Backdrop) void {
    _ = g;
    _ = obj;
    _ = bd;
    stub.unported("inferno.hazard.moveTick");
}
