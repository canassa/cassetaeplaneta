//! Port unit `panels` (module). control panel (slide, inventory, texts, options button) and status bar text.
//!
//! Virtual-slot dispatchers owned by this unit are declared below with
//! their final signatures; their bodies panic until the unit is ported
//! (docs/DESIGN.md "Virtual slots → dispatchers"). Replace each body, keep
//! the signature (other units already call it).

const stub = @import("core/stub.zig");
const Game = @import("core/game.zig").Game;
const object = @import("core/object.zig");
const Object = object.Object;
const ObjectList = object.ObjectList;
const world = @import("core/world.zig");
const Backdrop = world.Backdrop;

/// ControlPanel slot 08 (skeleton stub: unported until this unit is).
pub fn isOpen(g: *Game, obj: *Object) bool {
    _ = .{ g, obj };
    stub.unported("panels.isOpen");
}

/// ControlPanel slot 09 (skeleton stub: unported until this unit is).
pub fn getVisibleHeight(g: *Game, obj: *Object) i16 {
    _ = .{ g, obj };
    stub.unported("panels.getVisibleHeight");
}

/// ControlPanel slot 0A (skeleton stub: unported until this unit is).
pub fn isOnOptionsButton(g: *Game, obj: *Object, x: i16, y: i16) bool {
    _ = .{ g, obj, x, y };
    stub.unported("panels.isOnOptionsButton");
}

/// ControlPanel slot 0B (skeleton stub: unported until this unit is).
pub fn slide(g: *Game, obj: *Object, bd: *Backdrop, direction: i16) void {
    _ = .{ g, obj, bd, direction };
    stub.unported("panels.slide");
}

/// ControlPanel slot 0C (skeleton stub: unported until this unit is).
pub fn drawInventory(g: *Game, obj: *Object, bd: *Backdrop) ?*ObjectList {
    _ = .{ g, obj, bd };
    stub.unported("panels.drawInventory");
}

/// ControlPanel slot 0D (skeleton stub: unported until this unit is).
pub fn isOutside(g: *Game, obj: *Object, x: i16, y: i16) bool {
    _ = .{ g, obj, x, y };
    stub.unported("panels.isOutside");
}

/// ControlPanel slot 0E (skeleton stub: unported until this unit is).
pub fn contains(g: *Game, obj: *Object, x: i16, y: i16) bool {
    _ = .{ g, obj, x, y };
    stub.unported("panels.contains");
}

/// ControlPanel slot 0F (skeleton stub: unported until this unit is).
pub fn getInventoryItemAt(g: *Game, obj: *Object, list: *ObjectList, x: i16, y: i16) ?*Object {
    _ = .{ g, obj, list, x, y };
    stub.unported("panels.getInventoryItemAt");
}

/// ControlPanel slot 10 (skeleton stub: unported until this unit is).
pub fn drawInventoryItem(g: *Game, obj: *Object, bd: *Backdrop, item: *Object, index: i16) void {
    _ = .{ g, obj, bd, item, index };
    stub.unported("panels.drawInventoryItem");
}
