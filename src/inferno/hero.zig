//! Port unit `hero` (module) of INFERNO.EXE. the Hero class (the player, a
//! Player2D): its SceneObject overrides (play, tick, moveToEdgeV,
//! stopMoving(Dc), moveTick: walk, jump, the world scroll), the jump,
//! hero_collide (BUGS.md H5, H7), size toggle, pose reset.
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

/// SceneObject slot 29 play override (hero_play: hero_collide;
/// animation.play's hero arm).
pub fn play(g: *Game, obj: *Object, bd: *Backdrop) void {
    _ = g;
    _ = obj;
    _ = bd;
    stub.unported("inferno.hero.play");
}

/// SceneObject slot 2D tick override (hero_tick; animation.tick's hero arm).
pub fn tick(g: *Game, obj: *Object, bd: *Backdrop) void {
    _ = g;
    _ = obj;
    _ = bd;
    stub.unported("inferno.hero.tick");
}

/// SceneObject slot 31 moveToEdgeV override (hero_move_to_edge_v: the jump's
/// target; movement.moveToEdgeV's hero arm).
pub fn moveToEdgeV(g: *Game, obj: *Object, bd: *Backdrop, dir: i16) void {
    _ = g;
    _ = obj;
    _ = bd;
    _ = dir;
    stub.unported("inferno.hero.moveToEdgeV");
}

/// SceneObject slot 32 stopMovingDc override (hero_stop_moving_dc, hdc
/// dropped; movement.stopMovingDc's hero arm).
pub fn stopMovingDc(g: *Game, obj: *Object, bd: *Backdrop) void {
    _ = g;
    _ = obj;
    _ = bd;
    stub.unported("inferno.hero.stopMovingDc");
}

/// SceneObject slot 33 stopMoving override (hero_stop_moving;
/// movement.stopMoving's hero arm).
pub fn stopMoving(g: *Game, obj: *Object, bd: *Backdrop) void {
    _ = g;
    _ = obj;
    _ = bd;
    stub.unported("inferno.hero.stopMoving");
}

/// SceneObject slot 34 moveTick override (hero_move_tick: the walk, the jump,
/// the world's scroll; movement.moveTick's hero arm).
pub fn moveTick(g: *Game, obj: *Object, bd: *Backdrop) void {
    _ = g;
    _ = obj;
    _ = bd;
    stub.unported("inferno.hero.moveTick");
}
