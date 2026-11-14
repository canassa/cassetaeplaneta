//! Port unit `fighters` (module) of SALGIN.EXE. The two fighters' own methods: the opponent's creation, FighterVtbl startTimer/walk, OpponentVtbl walk (the wall and stand-off clamps), the opponent's attack choice (srand(time) + rand), the blow and pain wave pairs.
//!
//! Virtual-slot dispatchers owned by this unit are declared below with
//! their final signatures; their bodies panic until the unit is ported
//! (docs/salgin/DESIGN.md "Virtual slots"). Replace each body, keep the
//! signature (other units already call it). Each implementation function
//! carries `// @orig <seg:xxxx> <name>` with the SALGIN address.

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

/// FighterVtbl slot 01 startTimer (fighter_start_timer; hwnd dropped):
/// stores `timer_id` in `Fighter.timerId` and starts the system timer
/// (`g.setSystemTimer`); returns the object.
pub fn startTimer(g: *Game, obj: *Object, timer_id: i16, period: i16) *Object {
    _ = g;
    _ = timer_id;
    _ = period;
    _ = obj;
    stub.unported("salgin.fighters.startTimer");
}

/// FighterVtbl slot 02 / OpponentVtbl slot 01 walk (hwnd dropped):
/// fighter_walk (fighter), opponent_walk (opponent): one 32-px step of the
/// walk in `mover.direction`, or the stop at a wall.
pub fn walk(g: *Game, obj: *Object, bd: *Backdrop) void {
    _ = g;
    _ = obj;
    _ = bd;
    stub.unported("salgin.fighters.walk");
}
