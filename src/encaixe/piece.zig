//! Port unit `piece` (module) of ENCAIXE.EXE. the Piece's game logic: spawn, new game, landing, line clear, PieceVtbl tryStep/moveTick, the score (cleared row, the %06d box).
//!
//! Virtual-slot dispatchers owned by this unit are declared below with
//! their final signatures; their bodies panic until the unit is ported
//! (docs/encaixe/DESIGN.md "Virtual slots"). Replace each body, keep the
//! signature (other units already call it). Each implementation function
//! carries `// @orig <1008:xxxx> <name>` with the ENCAIXE address.

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

/// PieceVtbl slot 01 tryStep (te_piece_try_move): the worker for `Mover.direction`; 0 = blocked.
pub fn tryStep(g: *Game, obj: *Object, bd: *Backdrop, kind: i16, rotation: i16) i16 {
    _ = g;
    _ = obj;
    _ = bd;
    _ = kind;
    _ = rotation;
    stub.unported("encaixe.piece.tryStep");
}

/// PieceVtbl slot 02 moveTick (te_piece_step_move, hwnd dropped).
pub fn moveTick(g: *Game, obj: *Object, bd: *Backdrop, kind: i16, rotation: i16) void {
    _ = g;
    _ = obj;
    _ = bd;
    _ = kind;
    _ = rotation;
    stub.unported("encaixe.piece.moveTick");
}
