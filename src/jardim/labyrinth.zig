//! Port unit `labyrinth` (module) of JARDIM.EXE. LabyrinthBackdrop: ctor, create (BackdropVtbl slot 00: tables, map, start, timer 1), paint, a frame (sky and floor, walls, sprites, hands, HUD), blit to the window.
//!
//! Virtual-slot dispatchers owned by this unit are declared below with
//! their final signatures; their bodies panic until the unit is ported
//! (docs/jardim/DESIGN.md "Virtual slots"). Replace each body, keep the
//! signature (other units already call it). Each implementation function
//! carries `// @orig <seg:xxxx> <name>` with the JARDIM address.

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

/// LabyrinthBackdropVtbl slot 00 create (labyrinth_backdrop_create; hwnd dropped): the tables, the map, the start, timer 1.
pub fn create(g: *Game, bd: *Backdrop) *Backdrop {
    _ = g;
    _ = bd;
    stub.unported("jardim.labyrinth.create");
}
