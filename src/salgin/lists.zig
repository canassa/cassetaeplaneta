//! Port unit `lists` (module) of SALGIN.EXE. ObjectList, DrawList, UpdateList (out of line) and message_box_printf's callers' helpers.
//!
//! See docs/salgin/DESIGN.md "How to port a unit". Each function
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
