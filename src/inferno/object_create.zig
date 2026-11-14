//! Port unit `object_create` (module) of INFERNO.EXE. constructors and
//! destructors of the objects (Hero, Platform, Prop, Hazard;
//! Player2D/Actor2D/Mover/Animation, SceneObject) and the frames (FrameVtbl
//! getCell).
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

/// FrameVtbl slot 00 getCell (frame_get_cell).
pub fn getCell(frame: *Frame, index: i16) ?*FrameCell {
    _ = frame;
    _ = index;
    stub.unported("inferno.object_create.getCell");
}
