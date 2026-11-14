//! Port unit `panels` (module) of SAUNA.EXE. the ControlPanel methods (ControlPanelVtbl 06-0D), draw, tick, inventory icons; built below the window, never seen.
//!
//! Virtual-slot dispatchers owned by this unit are declared below with
//! their final signatures; their bodies panic until the unit is ported
//! (docs/sauna/DESIGN.md "Virtual slots"). Replace each body, keep the
//! signature (other units already call it). Each implementation function
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

/// ControlPanelVtbl slot 06 isOpen.
pub fn isOpen(g: *Game, obj: *Object) bool {
    _ = g;
    _ = obj;
    stub.unported("sauna.panels.isOpen");
}

/// ControlPanelVtbl slot 07 getVisibleHeight (control_panel_get_visible_height_base).
pub fn getVisibleHeight(g: *Game, obj: *Object) i16 {
    _ = g;
    _ = obj;
    stub.unported("sauna.panels.getVisibleHeight");
}

/// ControlPanelVtbl slot 08 slide (hwnd dropped).
pub fn slide(g: *Game, obj: *Object, bd: *Backdrop, direction: i16) void {
    _ = g;
    _ = obj;
    _ = bd;
    _ = direction;
    stub.unported("sauna.panels.slide");
}

/// ControlPanelVtbl slot 09 drawInventory.
pub fn drawInventory(g: *Game, obj: *Object, bd: *Backdrop) i16 {
    _ = g;
    _ = obj;
    _ = bd;
    stub.unported("sauna.panels.drawInventory");
}

/// ControlPanelVtbl slot 0A isOutside.
pub fn isOutside(g: *Game, obj: *Object, x: i16, y: i16) bool {
    _ = g;
    _ = obj;
    _ = x;
    _ = y;
    stub.unported("sauna.panels.isOutside");
}

/// ControlPanelVtbl slot 0B contains.
pub fn contains(g: *Game, obj: *Object, x: i16, y: i16) bool {
    _ = g;
    _ = obj;
    _ = x;
    _ = y;
    stub.unported("sauna.panels.contains");
}

/// ControlPanelVtbl slot 0C getInventoryItemAt.
pub fn getInventoryItemAt(g: *Game, obj: *Object, list: ?*ObjectList, x: i16, y: i16) ?*Object {
    _ = g;
    _ = obj;
    _ = list;
    _ = x;
    _ = y;
    stub.unported("sauna.panels.getInventoryItemAt");
}

/// ControlPanelVtbl slot 0D drawInventoryItem.
pub fn drawInventoryItem(g: *Game, obj: *Object, bd: *Backdrop, item: ?*Object, index: i16) void {
    _ = g;
    _ = obj;
    _ = bd;
    _ = item;
    _ = index;
    stub.unported("sauna.panels.drawInventoryItem");
}

/// ControlPanel draw (`control_panel_draw`): called by render's draw
/// dispatcher for the panel.
pub fn draw(g: *Game, obj: *Object, bd: *Backdrop) void {
    _ = g;
    _ = obj;
    _ = bd;
    stub.unported("sauna.panels.draw");
}

/// ControlPanel tick (`control_panel_tick`): called by animation's tick
/// dispatcher for the panel.
pub fn tick(g: *Game, obj: *Object, bd: *Backdrop) void {
    _ = g;
    _ = obj;
    _ = bd;
    stub.unported("sauna.panels.tick");
}
