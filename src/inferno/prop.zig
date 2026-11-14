//! Port unit `prop` (module) of INFERNO.EXE. the Prop class (drinks, rocks,
//! the cross): its SceneObject overrides (restoreBackground, moveToEdgeH,
//! moveTick; slot 5A isPowerUp), PropVtbl moveTick/stepMove/tryStep, the
//! cross tick, inferno_create_rocks_and_cross.
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

/// SceneObject slot 5A isPowerUp (dispatcher): prop_is_power_up (prop,
/// hazard: `powerUp`) / default 0 (hero, platform).
pub fn isPowerUp(g: *Game, obj: *Object) bool {
    _ = g;
    _ = obj;
    stub.unported("inferno.prop.isPowerUp");
}

/// SceneObject slot 14 restoreBackground override (prop_restore_background;
/// render.restoreBackground's prop and hazard arm).
pub fn restoreBackground(g: *Game, obj: *Object, bd: *Backdrop, flag: i16) void {
    _ = g;
    _ = obj;
    _ = bd;
    _ = flag;
    stub.unported("inferno.prop.restoreBackground");
}

/// SceneObject slot 30 moveToEdgeH override (prop_move_to_edge_h;
/// movement.moveToEdgeH's prop and hazard arm).
pub fn moveToEdgeH(g: *Game, obj: *Object, bd: *Backdrop, dir: i16) void {
    _ = g;
    _ = obj;
    _ = bd;
    _ = dir;
    stub.unported("inferno.prop.moveToEdgeH");
}

/// SceneObject slot 34 moveTick override (prop_move_tick; movement.moveTick's
/// prop arm).
pub fn moveTick(g: *Game, obj: *Object, bd: *Backdrop) void {
    _ = g;
    _ = obj;
    _ = bd;
    stub.unported("inferno.prop.moveTick");
}
