//! Port unit `missiles` (module) of INV.EXE. the shot and the 2 bombs: creation (the null-pointer writes, BUGS.md INV Harmless), MissileVtbl armTimer and moveTick, shot_vanish, bomb_shot_down.
//!
//! Virtual-slot dispatchers owned by this unit are declared below with
//! their final signatures; their bodies panic until the unit is ported
//! (docs/inv/DESIGN.md "Virtual slots"). Replace each body, keep the
//! signature (other units already call it). Each implementation function
//! carries `// @orig <seg:xxxx> <name>` with the INV address.

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

/// MissileVtbl slot 01 armTimer (missile_arm_timer; hwnd dropped): a bomb's
/// drop timer (`kind` 2 sets `timer2Id` and `timer2IdB`, 5 only `timer2IdB`);
/// returns the missile, as the original returns `this`.
pub fn armTimer(g: *Game, obj: *Object, timer_id: u16, period: u16, kind: i16) *Object {
    _ = g;
    _ = obj;
    _ = timer_id;
    _ = period;
    _ = kind;
    stub.unported("inv.missiles.armTimer");
}

/// MissileVtbl slot 02 moveTick (missile_move_tick; hwnd dropped): stop
/// off-screen (the shot at y < 5, a bomb below y 470), else one step.
pub fn moveTick(g: *Game, obj: *Object, bd: *Backdrop) void {
    _ = g;
    _ = obj;
    _ = bd;
    stub.unported("inv.missiles.moveTick");
}
