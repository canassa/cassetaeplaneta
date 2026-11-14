//! Port unit `target` (module) of SERIAL.EXE. the 15 figures: creation (srand(time)), TargetVtbl startTimer and checkEdge (the wrap), hit (by kind: -100 / +100 / +200), hide and blit, the score box.
//!
//! Virtual-slot dispatchers owned by this unit are declared below with
//! their final signatures; their bodies panic until the unit is ported
//! (docs/serial/DESIGN.md "Virtual slots"). Replace each body, keep the
//! signature (other units already call it). Each implementation function
//! carries `// @orig <seg:xxxx> <name>` with the SERIAL address.

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

/// TargetVtbl slot 01 startTimer (target_start_timer; hwnd dropped): stores
/// `timer_id` by `index` (0-12 timerId2, 13-14 timerId13, 99 clockTimerId)
/// and arms the system timer (`elapse` ms: the original's int, 60000 is
/// passed as -0x15a0). Returns the target.
pub fn startTimer(g: *Game, obj: *Object, timer_id: i16, elapse: i16, index: i16) *Object {
    _ = g;
    _ = obj;
    _ = timer_id;
    _ = elapse;
    _ = index;
    stub.unported("serial.target.startTimer");
}

/// TargetVtbl slot 03 checkEdge (target_wrap_at_edge; hwnd dropped): the
/// edge test of figure `index` (0-14): off the far edge (stop, hide, erase,
/// free the lane) or one step.
pub fn checkEdge(g: *Game, obj: *Object, bd: *Backdrop, index: i16) void {
    _ = g;
    _ = obj;
    _ = bd;
    _ = index;
    stub.unported("serial.target.checkEdge");
}
