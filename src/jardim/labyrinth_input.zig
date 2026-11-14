//! Port unit `labyrinth_input` (module) of JARDIM.EXE. LabyrinthBackdrop slot 17 handleMessage (the keys, the 55-ms tick, the shot, doors, the result 0x40a; BUGS.md J1, J6) and labyrinth_move_and_render (a step and its collisions).
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

/// LabyrinthBackdropVtbl slot 17 handleMessage (labyrinth_backdrop_handle_message; hwnd dropped).
pub fn handleMessage(g: *Game, bd: *Backdrop, m: Msg) u16 {
    _ = g;
    _ = bd;
    _ = m;
    stub.unported("jardim.labyrinth_input.handleMessage");
}
