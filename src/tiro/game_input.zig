//! Port unit `game_input` (module) of TIRO.EXE. game_handle_message (GameVtbl 00, 3.7 KB: the engine default under the TIRO handler, which takes every input) and the Portable pick-up/drop it calls.
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

/// GameVtbl slot 00 handleMessage (game_handle_message): the engine default under the scene's handler.
pub fn handleMessage(g: *Game, m: Msg) i32 {
    _ = g;
    _ = m;
    stub.unported("tiro.game_input.handleMessage");
}
