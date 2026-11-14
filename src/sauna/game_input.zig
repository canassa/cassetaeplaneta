//! Port unit `game_input` (module) of SAUNA.EXE. game_handle_message (GameVtbl 00, 5.9 KB: the engine default under the SAUNA handler, which returns 0 for the mouse: a left click walks Pacman, BUGS.md P5) and the Portable pick-up/drop it calls.
//!
//! Virtual-slot dispatchers owned by this unit are declared below with
//! their final signatures; their bodies panic until the unit is ported
//! (docs/sauna/DESIGN.md "Virtual slots"). Replace each body, keep the
//! signature (other units already call it). Each implementation function
//! carries `// @orig <seg:xxxx> <name>` with the SAUNA address.

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

/// GameVtbl slot 00 handleMessage (game_handle_message): the engine default under the scene's handler.
pub fn handleMessage(g: *Game, m: Msg) i32 {
    _ = g;
    _ = m;
    stub.unported("sauna.game_input.handleMessage");
}
