//! Port unit `panels` (module) of JARDIM.EXE. ControlPanel (ControlPanelVtbl 06-0D) and StatusBar methods, the inventory icons (portable_draw_icon): created, never shown.
//!
//! Each implementation function carries `// @orig <seg:xxxx> <name>` with
//! the JARDIM address (docs/jardim/DESIGN.md "Virtual slots").

const cstr = @import("../core/cstr.zig");
const Game = @import("core/game.zig").Game;
const object = @import("core/object.zig");
const Object = object.Object;
const ObjectList = object.ObjectList;
const world = @import("core/world.zig");
const Backdrop = world.Backdrop;
const dib = @import("dib.zig");
const animation = @import("behaviour/animation.zig");
const position = @import("behaviour/position.zig");
const lists = @import("lists.zig");

/// Inventory slots: first slot x and slot width (JARDIM's: 0x78, 0x50).
const slot_x: i16 = 0x78;
const slot_w: i16 = 0x50;

fn lo16(v: i32) i16 {
    return @truncate(v);
}

// @orig 1048:3533 portable_draw_icon
/// Draws the item's icon, transparent where it equals `g.spriteKey`, into the
/// backdrop bitmap at (`x`, `y`). The original dereferences the icon and the
/// bitmap unchecked; a missing one is skipped (none is ever missing).
pub fn drawIcon(g: *Game, obj: *Object, bd: *Backdrop, x: i16, y: i16) dib.Error!void {
    const p = &obj.portable;
    const icon = p.icon orelse return;
    if (bd.pixels.len == 0) return;
    const orient = lo16(obj.dibFormatOk);
    _ = try dib.copyTransparent(&bd.bmiHeader, bd.pixels, x, y, icon.bits, &icon.header, 0, 0, p.iconW, orient *% p.iconH, g.spriteKey);
}

// @orig 1078:005f status_bar_set_text
/// StatusBar: copies `text` into the bar's text buffer and sets its x.
pub fn statusBarSetText(obj: *Object, x: i16, text: []const u8) void {
    cstr.copy(&obj.status.text, text);
    obj.status.textX = x;
}

// @orig 10c0:6f42 control_panel_is_open
/// ControlPanelVtbl slot 06 isOpen.
pub fn isOpen(g: *Game, obj: *Object) bool {
    _ = g;
    return obj.panel.isOpen != 0;
}

// @orig 10c0:6f60 control_panel_get_visible_height
/// ControlPanelVtbl slot 07 getVisibleHeight: (frame + 2) * 20.
pub fn getVisibleHeight(g: *Game, obj: *Object) i16 {
    _ = g;
    return (obj.curFrame +% 2) *% 0x14;
}

// @orig 1078:060d control_panel_slide
/// ControlPanelVtbl slot 08 slide (hwnd dropped).
pub fn slide(g: *Game, obj: *Object, bd: *Backdrop, direction: i16) void {
    obj.panel.slideDir = direction;
    const up: i16 = if (direction == 4) 1 else 0;
    obj.panel.slideStepsLeft = position.frameCount(obj) -% up;
    obj.curFrame = 0;
    animation.play(g, obj, bd);
}

// @orig 1078:086e control_panel_draw_inventory
/// ControlPanelVtbl slot 09 drawInventory: every item of the player's
/// inventory drawn into its slot (slot 0D); returns that list.
pub fn drawInventory(g: *Game, obj: *Object, bd: *Backdrop) ?*ObjectList {
    var n: i16 = 0;
    const pl = (g.player orelse @panic("panels.drawInventory: no player")).as(.player) orelse
        @panic("panels.drawInventory: asPlayer returned NULL"); // the original dereferences NULL
    if (!lists.isEmpty(&pl.actor.inventory)) {
        var cur = pl.actor.inventory.head;
        while (cur) |it| : (cur = it.next) {
            drawInventoryItem(g, obj, bd, it.as(.portable), n);
            n +%= 1;
        }
    }
    return &pl.actor.inventory;
}

// @orig 1078:0950 control_panel_is_outside
/// ControlPanelVtbl slot 0A isOutside: true outside the panel rectangle.
pub fn isOutside(g: *Game, obj: *Object, x: i16, y: i16) bool {
    _ = g;
    if (x < obj.x) return true;
    if (position.width(obj) +% obj.x < x) return true;
    if (y < obj.y) return true;
    if (position.height(obj) +% obj.y < y) return true;
    return false;
}

// @orig 10c0:6f8e control_panel_contains
/// ControlPanelVtbl slot 0B contains: not `isOutside` (slot 0A).
pub fn contains(g: *Game, obj: *Object, x: i16, y: i16) bool {
    return !isOutside(g, obj, x, y);
}

// @orig 1078:0b69 control_panel_get_inventory_item_at_virtual
/// ControlPanelVtbl slot 0C getInventoryItemAt.
pub fn getInventoryItemAt(g: *Game, obj: *Object, list: *ObjectList, x: i16, y: i16) ?*Object {
    _ = .{ g, obj, y };
    var item: ?*Object = null;
    if (!lists.isEmpty(list)) {
        var slot: i16 = @divTrunc(x -% slot_x, slot_w);
        item = list.head;
        while (item) |it| {
            if (slot == 0) break;
            slot -%= 1;
            item = it.next;
        }
    }
    const it = item orelse return null;
    return it.as(.portable);
}

// @orig 1078:0b10 control_panel_draw_inventory_item_virtual
/// ControlPanelVtbl slot 0D drawInventoryItem: icon at (0x78 + 0x50 * index, panel y + 0x32).
pub fn drawInventoryItem(g: *Game, obj: *Object, bd: *Backdrop, item: ?*Object, index: i16) void {
    const it = item orelse return;
    // The original ignores the blit's result.
    drawIcon(g, it, bd, index *% slot_w +% slot_x, obj.y +% 0x32) catch {};
}
