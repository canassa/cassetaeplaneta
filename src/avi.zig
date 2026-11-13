//! Port unit `avi` (module). Animation's AVI slots: name, MCI open/play/close/stop.
//!
//! Virtual-slot dispatchers owned by this unit are declared below with
//! their final signatures; their bodies panic until the unit is ported
//! (docs/DESIGN.md "Virtual slots → dispatchers"). Replace each body, keep
//! the signature (other units already call it).

const stub = @import("core/stub.zig");
const Game = @import("core/game.zig").Game;
const object = @import("core/object.zig");
const Object = object.Object;

/// Animation slot 00 (skeleton stub: unported until this unit is).
pub fn setAvi(g: *Game, obj: *Object) void {
    _ = .{ g, obj };
    stub.unported("avi.setAvi");
}

/// Animation slot 01 (skeleton stub: unported until this unit is).
pub fn setAviName(g: *Game, obj: *Object, name: []const u8) void {
    _ = .{ g, obj, name };
    stub.unported("avi.setAviName");
}

/// Animation slot 02 (skeleton stub: unported until this unit is).
pub fn getAviName(g: *Game, obj: *Object) []const u8 {
    _ = .{ g, obj };
    stub.unported("avi.getAviName");
}

/// Animation slot 03 (skeleton stub: unported until this unit is).
pub fn openAvi(g: *Game, obj: *Object, name: []const u8) u16 {
    _ = .{ g, obj, name };
    stub.unported("avi.openAvi");
}

/// Animation slot 04 (skeleton stub: unported until this unit is).
pub fn playAvi(g: *Game, obj: *Object, device: u16) void {
    _ = .{ g, obj, device };
    stub.unported("avi.playAvi");
}

/// Animation slot 05 (skeleton stub: unported until this unit is).
pub fn closeAvi(g: *Game, obj: *Object, device: u16) void {
    _ = .{ g, obj, device };
    stub.unported("avi.closeAvi");
}

/// Animation slot 06 (skeleton stub: unported until this unit is).
pub fn stopAvi(g: *Game, obj: *Object, device: u16) void {
    _ = .{ g, obj, device };
    stub.unported("avi.stopAvi");
}
