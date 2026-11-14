//! Port unit `backdrop` (module) of INFERNO.EXE. Backdrop/GridBackdrop (one
//! WinG bitmap; BackdropVtbl 20 slots, GridBackdropVtbl 21),
//! InfernoBackdrop's ctor and create (the floor wall, row 23), the occupancy
//! grid (occupancy_grid_clear: BUGS.md H6) and its queries, autoscroll.
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

/// BackdropVtbl slot 00 create: InfernoBackdrop's (inferno_backdrop_create:
/// the grid and the floor wall; hwnd dropped).
pub fn create(g: *Game, bd: *Backdrop) ?*Backdrop {
    _ = g;
    _ = bd;
    stub.unported("inferno.backdrop.create");
}

/// BackdropVtbl slot 01 isRectOccupied (GridBackdrop's).
pub fn isRectOccupied(g: *Game, bd: *Backdrop, x: i16, y: i16, w: i16, h: i16) bool {
    _ = g;
    _ = bd;
    _ = x;
    _ = y;
    _ = w;
    _ = h;
    stub.unported("inferno.backdrop.isRectOccupied");
}

/// BackdropVtbl slot 02 isRectFree.
pub fn isRectFree(g: *Game, bd: *Backdrop, x: i16, y: i16, w: i16, h: i16) bool {
    _ = g;
    _ = bd;
    _ = x;
    _ = y;
    _ = w;
    _ = h;
    stub.unported("inferno.backdrop.isRectFree");
}

/// BackdropVtbl slot 03 queryRect (out parameters → RectQuery; INFERNO has no
/// queryRectFirst).
pub fn queryRect(g: *Game, bd: *Backdrop, x: i16, y: i16, w: i16, h: i16) RectQuery {
    _ = g;
    _ = bd;
    _ = x;
    _ = y;
    _ = w;
    _ = h;
    stub.unported("inferno.backdrop.queryRect");
}

/// BackdropVtbl slot 04 occupy.
pub fn occupy(g: *Game, bd: *Backdrop, obj: *Object) i16 {
    _ = g;
    _ = bd;
    _ = obj;
    stub.unported("inferno.backdrop.occupy");
}

/// BackdropVtbl slot 05 vacate.
pub fn vacate(g: *Game, bd: *Backdrop, obj: *Object) i16 {
    _ = g;
    _ = bd;
    _ = obj;
    stub.unported("inferno.backdrop.vacate");
}

/// BackdropVtbl slot 06 slot07 (default).
pub fn slot07(g: *Game, bd: *Backdrop) i16 {
    _ = g;
    _ = bd;
    stub.unported("inferno.backdrop.slot07");
}

/// BackdropVtbl slot 07 slot08 (default).
pub fn slot08(g: *Game, bd: *Backdrop, arg2: i16, arg1: i16) void {
    _ = g;
    _ = bd;
    _ = arg2;
    _ = arg1;
    stub.unported("inferno.backdrop.slot08");
}

/// BackdropVtbl slot 08 setVanishPoint (default).
pub fn setVanishPoint(g: *Game, bd: *Backdrop, vanish_x: i16, vanish_y: i16) *Backdrop {
    _ = g;
    _ = bd;
    _ = vanish_x;
    _ = vanish_y;
    stub.unported("inferno.backdrop.setVanishPoint");
}

/// BackdropVtbl slot 09 setView (default).
pub fn setView(g: *Game, bd: *Backdrop, view_x: i16, view_y: i16, view3d_x: i16, view3d_y: i16, view3d_z: i16) *Backdrop {
    _ = g;
    _ = bd;
    _ = view_x;
    _ = view_y;
    _ = view3d_x;
    _ = view3d_y;
    _ = view3d_z;
    stub.unported("inferno.backdrop.setView");
}

/// BackdropVtbl slot 0A setAxis (default).
pub fn setAxis(g: *Game, bd: *Backdrop, axis_x: i16, axis_y: i16) *Backdrop {
    _ = g;
    _ = bd;
    _ = axis_x;
    _ = axis_y;
    stub.unported("inferno.backdrop.setAxis");
}

/// BackdropVtbl slots 0B and 0F getVanishX (default).
pub fn getVanishX(g: *Game, bd: *Backdrop) i16 {
    _ = g;
    _ = bd;
    stub.unported("inferno.backdrop.getVanishX");
}

/// BackdropVtbl slots 0C and 10 getVanishY (default).
pub fn getVanishY(g: *Game, bd: *Backdrop) i16 {
    _ = g;
    _ = bd;
    stub.unported("inferno.backdrop.getVanishY");
}

/// BackdropVtbl slot 0D getEyeDistance (default).
pub fn getEyeDistance(g: *Game, bd: *Backdrop) i16 {
    _ = g;
    _ = bd;
    stub.unported("inferno.backdrop.getEyeDistance");
}

/// BackdropVtbl slot 0E getAxisX (default).
pub fn getAxisX(g: *Game, bd: *Backdrop) i16 {
    _ = g;
    _ = bd;
    stub.unported("inferno.backdrop.getAxisX");
}

/// BackdropVtbl slot 11 getView3dZ (default).
pub fn getView3dZ(g: *Game, bd: *Backdrop) i16 {
    _ = g;
    _ = bd;
    stub.unported("inferno.backdrop.getView3dZ");
}

/// BackdropVtbl slot 12 isGridBackdrop (GridBackdrop's: 1).
pub fn isGridBackdrop(g: *Game, bd: *Backdrop) bool {
    _ = g;
    _ = bd;
    stub.unported("inferno.backdrop.isGridBackdrop");
}

/// BackdropVtbl slot 13 asGridBackdrop (GridBackdrop's: the backdrop itself).
pub fn asGridBackdrop(g: *Game, bd: *Backdrop) ?*Backdrop {
    _ = g;
    _ = bd;
    stub.unported("inferno.backdrop.asGridBackdrop");
}

/// GridBackdropVtbl slot 14 createWithGrid (hwnd dropped).
pub fn createWithGrid(g: *Game, bd: *Backdrop, cell_shift: i16) ?*Backdrop {
    _ = g;
    _ = bd;
    _ = cell_shift;
    stub.unported("inferno.backdrop.createWithGrid");
}
