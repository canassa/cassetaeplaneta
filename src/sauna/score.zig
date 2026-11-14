//! Port unit `score` (module) of SAUNA.EXE. the score and its waves: a peanut (+100), a ghost eaten (+500), a life lost (-500, the third sends WM_DESTROY), the power waves, the score box (BUGS.md P8).
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
