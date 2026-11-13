//! Port unit `backdrop` (module). the scene backdrop: WinG view, palette, background, perspective parameters, autoscroll.
//!
//! Virtual-slot dispatchers owned by this unit are declared below with
//! their final signatures; their bodies panic until the unit is ported
//! (docs/DESIGN.md "Virtual slots → dispatchers"). Replace each body, keep
//! the signature (other units already call it).

const stub = @import("core/stub.zig");
const Game = @import("core/game.zig").Game;
const object = @import("core/object.zig");
const Object = object.Object;
const world = @import("core/world.zig");
const Backdrop = world.Backdrop;
const RectQuery = world.RectQuery;

/// Backdrop slot 00 (skeleton stub: unported until this unit is).
pub fn create(g: *Game, bd: *Backdrop) ?*Backdrop {
    _ = .{ g, bd };
    stub.unported("backdrop.create");
}

/// Backdrop slot 01 (skeleton stub: unported until this unit is).
pub fn isRectOccupied(g: *Game, bd: *Backdrop, x: i16, y: i16, w: i16, h: i16) bool {
    _ = .{ g, bd, x, y, w, h };
    stub.unported("backdrop.isRectOccupied");
}

/// Backdrop slot 02 (skeleton stub: unported until this unit is).
pub fn isRectFree(g: *Game, bd: *Backdrop, x: i16, y: i16, w: i16, h: i16) bool {
    _ = .{ g, bd, x, y, w, h };
    stub.unported("backdrop.isRectFree");
}

/// Backdrop slot 03 (skeleton stub: unported until this unit is).
pub fn queryRectFirst(g: *Game, bd: *Backdrop, x: i16, y: i16, w: i16, h: i16) RectQuery {
    _ = .{ g, bd, x, y, w, h };
    stub.unported("backdrop.queryRectFirst");
}

/// Backdrop slot 04 (skeleton stub: unported until this unit is).
pub fn queryRect(g: *Game, bd: *Backdrop, x: i16, y: i16, w: i16, h: i16) RectQuery {
    _ = .{ g, bd, x, y, w, h };
    stub.unported("backdrop.queryRect");
}

/// Backdrop slot 05 (skeleton stub: unported until this unit is).
pub fn occupy(g: *Game, bd: *Backdrop, obj: *Object) i16 {
    _ = .{ g, bd, obj };
    stub.unported("backdrop.occupy");
}

/// Backdrop slot 06 (skeleton stub: unported until this unit is).
pub fn vacate(g: *Game, bd: *Backdrop, obj: *Object) i16 {
    _ = .{ g, bd, obj };
    stub.unported("backdrop.vacate");
}

/// Backdrop slot 07 (skeleton stub: unported until this unit is).
pub fn slot07(g: *Game, bd: *Backdrop) i16 {
    _ = .{ g, bd };
    stub.unported("backdrop.slot07");
}

/// Backdrop slot 09 (skeleton stub: unported until this unit is).
pub fn setVanishPoint(g: *Game, bd: *Backdrop, vanish_x: i16, vanish_y: i16) *Backdrop {
    _ = .{ g, bd, vanish_x, vanish_y };
    stub.unported("backdrop.setVanishPoint");
}

/// Backdrop slot 0A (skeleton stub: unported until this unit is).
pub fn setView(g: *Game, bd: *Backdrop, view_x: i16, view_y: i16, view3d_x: i16, view3d_y: i16, view3d_z: i16) *Backdrop {
    _ = .{ g, bd, view_x, view_y, view3d_x, view3d_y, view3d_z };
    stub.unported("backdrop.setView");
}

/// Backdrop slot 0B (skeleton stub: unported until this unit is).
pub fn setAxis(g: *Game, bd: *Backdrop, axis_x: i16, axis_y: i16) *Backdrop {
    _ = .{ g, bd, axis_x, axis_y };
    stub.unported("backdrop.setAxis");
}

/// Backdrop slot 0C (skeleton stub: unported until this unit is).
pub fn getVanishX(g: *Game, bd: *Backdrop) i16 {
    _ = .{ g, bd };
    stub.unported("backdrop.getVanishX");
}

/// Backdrop slot 0D (skeleton stub: unported until this unit is).
pub fn getVanishY(g: *Game, bd: *Backdrop) i16 {
    _ = .{ g, bd };
    stub.unported("backdrop.getVanishY");
}

/// Backdrop slot 0E (skeleton stub: unported until this unit is).
pub fn getEyeDistance(g: *Game, bd: *Backdrop) i16 {
    _ = .{ g, bd };
    stub.unported("backdrop.getEyeDistance");
}

/// Backdrop slot 0F (skeleton stub: unported until this unit is).
pub fn getAxisX(g: *Game, bd: *Backdrop) i16 {
    _ = .{ g, bd };
    stub.unported("backdrop.getAxisX");
}

/// Backdrop slot 12 (skeleton stub: unported until this unit is).
pub fn getView3dZ(g: *Game, bd: *Backdrop) i16 {
    _ = .{ g, bd };
    stub.unported("backdrop.getView3dZ");
}

/// Backdrop slot 17 (skeleton stub: unported until this unit is).
pub fn createWithGrid(g: *Game, bd: *Backdrop, cell_shift: i16) ?*Backdrop {
    _ = .{ g, bd, cell_shift };
    stub.unported("backdrop.createWithGrid");
}

/// Backdrop slot 18 (skeleton stub: unported until this unit is).
pub fn slot18(g: *Game, bd: *Backdrop, obj: *Object, arg: i16) ?*Object {
    _ = .{ g, bd, obj, arg };
    stub.unported("backdrop.slot18");
}
