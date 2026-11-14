//! Port unit `target` (module) of TIRO.EXE. the targets: creation, TargetVtbl checkEdge (the wrap), hit (+150 girl / -150 traveco), respawn, the score box.
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

/// TargetVtbl slot 02 checkEdge (target_wrap_at_edge; hwnd dropped): the
/// edge test of target `index` (0-3): wrap round (stop, erase) or one step.
pub fn checkEdge(g: *Game, obj: *Object, bd: *Backdrop, index: i16) void {
    _ = g;
    _ = obj;
    _ = bd;
    _ = index;
    stub.unported("tiro.target.checkEdge");
}
