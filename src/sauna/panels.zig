//! Port unit `panels` (module) of SAUNA.EXE. the ControlPanel methods (ControlPanelVtbl 06-0D), draw, tick, inventory icons; built below the window, never seen.
//!
//! Virtual-slot dispatchers owned by this unit are declared below with
//! their final signatures; their bodies panic until the unit is ported
//! (docs/sauna/DESIGN.md "Virtual slots"). Replace each body, keep the
//! signature (other units already call it). Each implementation function
//! carries `// @orig <seg:xxxx> <name>` with the SAUNA address.

const std = @import("std");
const cstr = @import("../core/cstr.zig");
const platform = @import("../platform/platform.zig");
const Game = @import("core/game.zig").Game;
const object = @import("core/object.zig");
const Object = object.Object;
const ObjectList = object.ObjectList;
const Frame = object.Frame;
const world = @import("core/world.zig");
const Backdrop = world.Backdrop;
const dib = @import("dib.zig");
const animation = @import("behaviour/animation.zig");
const render = @import("behaviour/render.zig");
const visibility = @import("behaviour/visibility.zig");
const object_create = @import("object_create.zig");

/// Inventory slots: first slot x and slot width (SAUNA's: 0x78, 0x50).
const slot_x: i16 = 0x78;
const slot_w: i16 = 0x50;

fn curStripFrame(obj: *Object) *Frame {
    return &obj.frames[@intCast(obj.curStrip)];
}

// @orig 1030:3533 portable_draw_icon
/// Draws the item's icon, transparent where it equals `g_transparentColor`,
/// into the backdrop bitmap at (`x`, `y`). A missing icon or bitmap is
/// skipped (the original would fault; no Portable is ever constructed).
pub fn drawIcon(g: *Game, obj: *Object, bd: *Backdrop, x: i16, y: i16) dib.Error!void {
    const p = &obj.portable;
    const icon = p.icon orelse return;
    if (bd.pixels.len == 0) return;
    const orient: i16 = @truncate(obj.dibFormatOk);
    _ = try dib.copyTransparent(&bd.bmiHeader, bd.pixels, x, y, icon.bits, &icon.header, 0, 0, p.iconW, orient *% p.iconH, @truncate(g.transparentColor));
}

// @orig 10a0:6bc0 control_panel_is_open
/// ControlPanelVtbl slot 06 isOpen.
pub fn isOpen(g: *Game, obj: *Object) bool {
    _ = g;
    return obj.panel.isOpen != 0;
}

// @orig 10a0:6bde control_panel_get_visible_height_base
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
    obj.panel.slideStepsLeft = curStripFrame(obj).count -% up;
    obj.curFrame = 0;
    animation.play(g, obj, bd);
}

// @orig 1078:086e control_panel_draw_inventory
/// ControlPanelVtbl slot 09 drawInventory. The original walks the list at
/// `g_game->player->asPlayer() + 0x4c`; Pacman keeps SceneObject's
/// `isPlayer`, so `asPlayer()` is NULL and that is 0:0x4c, not a list. The
/// panel never opens (y 592, its slide timer is swallowed), so this is not
/// reached.
pub fn drawInventory(g: *Game, obj: *Object, bd: *Backdrop) i16 {
    _ = .{ g, obj, bd };
    @panic("sauna.panels.drawInventory: reached, but the original reads asPlayer() == NULL + 0x4c as a list");
}

// @orig 1078:0950 control_panel_is_outside
/// ControlPanelVtbl slot 0A isOutside: true outside the panel rectangle.
pub fn isOutside(g: *Game, obj: *Object, x: i16, y: i16) bool {
    _ = g;
    if (obj.x > x) return true;
    if (obj.x +% curStripFrame(obj).width < x) return true;
    if (obj.y > y) return true;
    if (curStripFrame(obj).height +% obj.y < y) return true;
    return false;
}

// @orig 10a0:6c0c control_panel_contains
/// ControlPanelVtbl slot 0B contains: not `isOutside` (slot 0A).
pub fn contains(g: *Game, obj: *Object, x: i16, y: i16) bool {
    return !isOutside(g, obj, x, y);
}

// @orig 1078:0b69 control_panel_get_inventory_item_at
/// ControlPanelVtbl slot 0C getInventoryItemAt.
pub fn getInventoryItemAt(g: *Game, obj: *Object, list: ?*ObjectList, x: i16, y: i16) ?*Object {
    _ = .{ g, obj, y };
    var item: ?*Object = null;
    if (list) |l| {
        if (l.head != null) {
            var slot: i16 = @divTrunc(x -% slot_x, slot_w);
            item = l.head;
            while (item) |it| {
                if (slot == 0) break;
                slot -%= 1;
                item = it.next;
            }
        }
    }
    const it = item orelse return null;
    return it.as(.portable);
}

// @orig 1078:0b10 control_panel_draw_inventory_item
/// ControlPanelVtbl slot 0D drawInventoryItem: icon at (0x78 + 0x50 * index, panel y + 0x32).
pub fn drawInventoryItem(g: *Game, obj: *Object, bd: *Backdrop, item: ?*Object, index: i16) void {
    const it = item orelse return;
    // The original ignores the blit's result.
    drawIcon(g, it, bd, index *% slot_w +% slot_x, obj.y +% 0x32) catch {};
}

// @orig 1078:04f9 control_panel_draw_texts
/// The panel's message only (no score or lives): at textX, or centred when
/// -1, y = 480 - visible height. Only when the text is not empty.
fn drawTexts(g: *Game, obj: *Object, bd: *Backdrop) void {
    const p = &obj.panel;
    if (p.text[0] == 0) return;
    const style: platform.TextStyle = .{ .color = p.textColor, .bk_mode = .transparent };
    const text = cstr.slice(&p.text);
    var x: i16 = p.textX;
    if (p.textX == -1) {
        const w: i16 = @bitCast(@as(u16, @truncate(g.plat.textExtent(text))));
        x = @bitCast(@as(u16, @bitCast(640 -% w)) >> 1);
    }
    const y = 0x1e0 -% getVisibleHeight(g, obj);
    _ = g.plat.textOut(bd.surface(), style, x, y, text);
}

// @orig 1078:02be control_panel_draw
/// SceneObject slot 1B draw: the icons only when open and not running (not
/// while sliding), animation_draw, then the message text.
pub fn draw(g: *Game, obj: *Object, bd: *Backdrop) void {
    if (obj.panel.isOpen != 0 and obj.anim.running == 0) _ = drawInventory(g, obj, bd);
    render.drawDirtyTo(g, obj, &bd.bmiHeader, bd.pixels);
    drawTexts(g, obj, bd);
}

// @orig 1078:069d control_panel_tick
/// SceneObject slot 33 tick (hwnd/hdc dropped): one slide step (4 = next
/// frame, else previous); on the last stops and sets isOpen (0 when closing,
/// direction 8); then erase, draw and redraw the overlapping. Never runs in
/// SAUNA (the scene handler swallows the timer).
pub fn tick(g: *Game, obj: *Object, bd: *Backdrop) void {
    const p = &obj.panel;
    if (p.slideStepsLeft == 0) {
        obj.anim.playOnce = 0;
        obj.anim.running = 0;
        return;
    }
    p.slideStepsLeft -%= 1;
    if (p.slideDir == 4) {
        _ = animation.nextFrame(g, obj);
    } else {
        _ = animation.prevFrame(g, obj);
    }
    if (p.slideStepsLeft == 0) {
        animation.stop(g, obj);
        p.isOpen = if (p.slideDir == 8) 0 else 1;
    }
    render.erase(g, obj, bd);
    render.draw(g, obj, bd);
    visibility.redrawOverlapping(g, obj, bd, 1);
}

// @orig 10a0:8900 control_panel_dtor
/// The panel's own part has nothing to destroy: chains to animated3d_dtor.
pub fn dtor(obj: *Object) void {
    object_create.animated3dDtor(obj);
}

// @orig 10a0:889c control_panel_vbase_dtor
/// Complete-object destructor: control_panel_dtor, then object3d_dtor and
/// scene_object_dtor on the virtual bases.
pub fn vbaseDtor(g: *Game, obj: *Object) void {
    dtor(obj);
    object_create.object3dDtor(obj);
    object_create.sceneObjectDtor(g, obj);
}

// @orig 10a0:8820 control_panel_scalar_dtor
/// Scalar deleting destructor: vbaseDtor, then `operator delete` when bit 0
/// of `flags` is set. Returns `obj`.
pub fn scalarDtor(g: *Game, obj: *Object, flags: u16) *Object {
    vbaseDtor(g, obj);
    if (flags & 1 != 0) g.local().destroy(obj);
    return obj;
}

// @orig 10a0:88de status_bar_dtor
/// The SceneObject destructor on the base.
pub fn statusBarDtor(g: *Game, obj: *Object) void {
    object_create.sceneObjectDtor(g, obj);
}

// @orig 10a0:885e status_bar_scalar_dtor
/// Scalar deleting destructor: statusBarDtor, then `operator delete` when
/// bit 0 of `flags` is set. Returns `obj`.
pub fn statusBarScalarDtor(g: *Game, obj: *Object, flags: u16) *Object {
    statusBarDtor(g, obj);
    if (flags & 1 != 0) g.local().destroy(obj);
    return obj;
}
