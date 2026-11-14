//! Port unit `saucer` (module) of INV.EXE. the saucer: creation, SaucerVtbl armTimer (the 10 s launch) and checkEdge, saucer_explode.
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

/// SaucerVtbl slot 01 armTimer (saucer_arm_timer; hwnd dropped): arms the
/// launch timer (`kind` 3 from inv_create_saucer: id 0xe, 10 s); returns
/// the saucer, as the original returns `this`.
pub fn armTimer(g: *Game, obj: *Object, timer_id: u16, period: u16, kind: i16) *Object {
    _ = g;
    _ = obj;
    _ = timer_id;
    _ = period;
    _ = kind;
    stub.unported("inv.saucer.armTimer");
}

/// SaucerVtbl slot 03 checkEdge (saucer_check_edge; hwnd dropped): the 0xc
/// tick: stop, hide and park at x >= 518, else one step.
pub fn checkEdge(g: *Game, obj: *Object, bd: *Backdrop) void {
    _ = g;
    _ = obj;
    _ = bd;
    stub.unported("inv.saucer.checkEdge");
}
