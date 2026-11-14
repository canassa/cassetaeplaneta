//! Port unit `arrow` (module) of TIRO.EXE. the crossbow's aim and the arrow: creation, ProjectileVtbl stepMove/tryStep (the first hit stage), the shot wave.
//!
//! Virtual-slot dispatchers owned by this unit are declared below with
//! their final signatures; their bodies panic until the unit is ported
//! (docs/tiro/DESIGN.md "Virtual slots"). Replace each body, keep the
//! signature (other units already call it). Each implementation function
//! carries `// @orig <seg:xxxx> <name>` with the TIRO address.

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

/// ProjectileVtbl slot 02 stepMove (projectile_step_move; hwnd dropped):
/// one Bresenham step, `tryStep`, the redraw, the stop at the destination.
/// `dir` is the original's `int *outDir` (3 = a hit, BUGS.md T5).
pub fn stepMove(g: *Game, obj: *Object, bd: *Backdrop, dir: *i16) void {
    _ = g;
    _ = obj;
    _ = bd;
    _ = dir;
    stub.unported("tiro.arrow.stepMove");
}

/// ProjectileVtbl slot 03 tryStep (projectile_try_step): the occupancy
/// query of the next rect and the `isTarget` test of the blocker; returns
/// non-zero when the arrow may move on, sets `dir.*` = 3 on a hit.
pub fn tryStep(g: *Game, obj: *Object, bd: *Backdrop, dir: *i16) i16 {
    _ = g;
    _ = obj;
    _ = bd;
    _ = dir;
    stub.unported("tiro.arrow.tryStep");
}
