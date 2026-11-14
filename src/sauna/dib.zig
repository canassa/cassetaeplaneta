//! Port unit `dib` (module) of SAUNA.EXE. DIB loading, copies and the row blitters (1000:0148/0234 are NOITE's 32-bit row copies; the RLE copies of 1000/1008/1068/1088 are dead).
//!
//! See docs/sauna/DESIGN.md "How to port a SAUNA unit". Each function
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
