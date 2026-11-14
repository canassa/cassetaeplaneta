//! Port unit `object_create` (module) of TIRO.EXE. constructors and destructors of the objects (Crossbow/Target/Arrow/Projectile, Player2D/Actor2D/Mover/Animation, TiroPanel/ControlPanel/Animated3D/Object3D, StatusBar, SceneObject) and frames.
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

/// FrameVtbl slot 00 getCell.
pub fn getCell(frame: *Frame, index: i16) ?*FrameCell {
    _ = frame;
    _ = index;
    stub.unported("tiro.object_create.getCell");
}
