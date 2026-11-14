//! Port unit `panels` (module) of TIRO.EXE. the ControlPanel/TiroPanel and StatusBar methods (ControlPanelVtbl 01-08), draw, tick, inventory icons; created and attached, never shown.
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

/// ControlPanelVtbl slot 01 isOpen.
pub fn isOpen(g: *Game, obj: *Object) bool {
    _ = g;
    _ = obj;
    stub.unported("tiro.panels.isOpen");
}

/// ControlPanelVtbl slot 02 getVisibleHeight (TiroPanel's).
pub fn getVisibleHeight(g: *Game, obj: *Object) i16 {
    _ = g;
    _ = obj;
    stub.unported("tiro.panels.getVisibleHeight");
}

/// ControlPanelVtbl slot 03 slide (hwnd dropped).
pub fn slide(g: *Game, obj: *Object, bd: *Backdrop, direction: i16) void {
    _ = g;
    _ = obj;
    _ = bd;
    _ = direction;
    stub.unported("tiro.panels.slide");
}

/// ControlPanelVtbl slot 04 drawInventory.
pub fn drawInventory(g: *Game, obj: *Object, bd: *Backdrop) i16 {
    _ = g;
    _ = obj;
    _ = bd;
    stub.unported("tiro.panels.drawInventory");
}

/// ControlPanelVtbl slot 05 isOutside.
pub fn isOutside(g: *Game, obj: *Object, x: i16, y: i16) bool {
    _ = g;
    _ = obj;
    _ = x;
    _ = y;
    stub.unported("tiro.panels.isOutside");
}

/// ControlPanelVtbl slot 06 contains.
pub fn contains(g: *Game, obj: *Object, x: i16, y: i16) bool {
    _ = g;
    _ = obj;
    _ = x;
    _ = y;
    stub.unported("tiro.panels.contains");
}

/// ControlPanelVtbl slot 07 getInventoryItemAt.
pub fn getInventoryItemAt(g: *Game, obj: *Object, list: ?*ObjectList, x: i16, y: i16) ?*Object {
    _ = g;
    _ = obj;
    _ = list;
    _ = x;
    _ = y;
    stub.unported("tiro.panels.getInventoryItemAt");
}

/// ControlPanelVtbl slot 08 drawInventoryItem.
pub fn drawInventoryItem(g: *Game, obj: *Object, bd: *Backdrop, item: ?*Object, index: i16) void {
    _ = g;
    _ = obj;
    _ = bd;
    _ = item;
    _ = index;
    stub.unported("tiro.panels.drawInventoryItem");
}
