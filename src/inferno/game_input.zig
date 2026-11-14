//! Port unit `game_input` (module) of INFERNO.EXE. game_handle_message
//! (GameVtbl 00, 4.9 KB: the engine default under the INFERNO handler; its
//! input cases are dead, the update-list tail draws every frame).
//!
//! Virtual-slot dispatchers owned by this unit are declared below with
//! their final signatures; their bodies panic until the unit is ported
//! (docs/inferno/DESIGN.md "Virtual slots"). Replace each body, keep the
//! signature (other units already call it). Each implementation function
//! carries `// @orig <seg:xxxx> <name>` with the INFERNO address.

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

/// GameVtbl slot 00 handleMessage (game_handle_message): non-zero = handled.
pub fn handleMessage(g: *Game, m: Msg) i32 {
    _ = g;
    _ = m;
    stub.unported("inferno.game_input.handleMessage");
}
