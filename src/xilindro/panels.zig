//! Port unit `panels` (module) of XILINDRO.EXE. the ControlPanel/XilindroPanel and StatusBar methods (ControlPanelVtbl 01-08), draw, tick, inventory icons; created and attached, never shown.
//!
//! Same source as SERIAL's and TIRO's panels unit. The panel is created and
//! attached but never shown: `isOpen` stays 0 so its icons are never drawn.

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

/// Inventory slots: first slot x and slot width.
const slot_x: i16 = 0x5c;
const slot_w: i16 = 0x38;

fn curStripFrame(obj: *Object) *Frame {
    return &obj.frames[@intCast(obj.curStrip)];
}

// @orig 1018:2157 portable_draw_icon
/// Draws the item's icon, transparent where it equals `g_unk00A8`, into the
/// backdrop bitmap at (`x`, `y`). A missing icon or bitmap is skipped (the
/// original would fault; no Portable is ever constructed).
pub fn drawIcon(g: *Game, obj: *Object, bd: *Backdrop, x: i16, y: i16) dib.Error!void {
    const p = &obj.portable;
    const icon = p.icon orelse return;
    if (bd.pixels.len == 0) return;
    const orient: i16 = @truncate(obj.dibFormatOk);
    _ = try dib.copyTransparent(&bd.bmiHeader, bd.pixels, x, y, icon.bits, &icon.header, 0, 0, p.iconW, orient *% p.iconH, g.unk00A8);
}

// @orig 1088:526c control_panel_is_open
/// ControlPanelVtbl slot 01 isOpen.
pub fn isOpen(g: *Game, obj: *Object) bool {
    _ = g;
    return obj.panel.isOpen != 0;
}

// @orig 1088:4d14 control_panel_get_visible_height
/// ControlPanelVtbl slot 02 getVisibleHeight (XilindroPanel's): (frame + 2) * 20.
pub fn getVisibleHeight(g: *Game, obj: *Object) i16 {
    _ = g;
    return (obj.curFrame +% 2) *% 0x14;
}

// @orig 1058:03a3 control_panel_slide
/// ControlPanelVtbl slot 03 slide (hwnd dropped).
pub fn slide(g: *Game, obj: *Object, bd: *Backdrop, direction: i16) void {
    obj.panel.slideDir = direction;
    const up: i16 = if (direction == 4) 1 else 0;
    obj.panel.slideStepsLeft = curStripFrame(obj).count -% up;
    obj.curFrame = 0;
    animation.play(g, obj, bd);
}

// @orig 1058:0540 control_panel_draw_inventory
/// ControlPanelVtbl slot 04 drawInventory. The original reads the list head
/// at `asDirectionalPlayer() + 0x40`; the player (the fighter) is never a
/// DirectionalPlayer (the slot default returns 0), so that is DGROUP:0x40,
/// not a field of the fighter. The panel is never shown
/// (`isOpen` stays 0), so this is not reached.
pub fn drawInventory(g: *Game, obj: *Object, bd: *Backdrop) i16 {
    _ = .{ g, obj, bd };
    @panic("xilindro.panels.drawInventory: reached, but the original reads DGROUP:0x40 as a list head");
}

// @orig 1058:05e5 control_panel_is_outside
/// ControlPanelVtbl slot 05 isOutside: true outside the panel rectangle.
pub fn isOutside(g: *Game, obj: *Object, x: i16, y: i16) bool {
    _ = g;
    if (obj.x > x) return true;
    if (obj.x +% curStripFrame(obj).width < x) return true;
    if (obj.y > y) return true;
    if (curStripFrame(obj).height +% obj.y < y) return true;
    return false;
}

// @orig 1088:52b2 control_panel_contains
/// ControlPanelVtbl slot 06 contains.
pub fn contains(g: *Game, obj: *Object, x: i16, y: i16) bool {
    return !isOutside(g, obj, x, y);
}

// @orig 1058:06ba control_panel_get_inventory_item_at
/// ControlPanelVtbl slot 07 getInventoryItemAt.
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

// @orig 1058:066f control_panel_draw_inventory_item
/// ControlPanelVtbl slot 08 drawInventoryItem: icon at (0x5c + 0x38 * index, panel y + 0x46).
pub fn drawInventoryItem(g: *Game, obj: *Object, bd: *Backdrop, item: ?*Object, index: i16) void {
    const it = item orelse return;
    // The original ignores the blit's result.
    drawIcon(g, it, bd, index *% slot_w +% slot_x, obj.y +% 0x46) catch {};
}

// @orig 1058:02dd control_panel_draw_texts
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

// @orig 1058:014c control_panel_draw
/// SceneObject slot 16 draw (XilindroPanel): the icons only when open and not
/// running (not while sliding), animation_draw, then the message text.
pub fn draw(g: *Game, obj: *Object, bd: *Backdrop) void {
    if (obj.panel.isOpen != 0 and obj.anim.running == 0) _ = drawInventory(g, obj, bd);
    render.drawDirtyTo(g, obj, &bd.bmiHeader, bd.pixels);
    drawTexts(g, obj, bd);
}

// @orig 1058:0411 control_panel_tick
/// SceneObject slot 2D tick (XilindroPanel; hwnd/hdc dropped): one slide step
/// (4 = next frame, else previous); on the last stops and sets isOpen (0
/// when closing, direction 8); then erase, draw and redraw the overlapping.
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

// @orig 1088:4058 control_panel_dtor
/// The panel's own part has nothing to destroy: chains to animated3d_dtor.
pub fn dtor(obj: *Object) void {
    object_create.animated3dDtor(obj);
}

// @orig 1088:4004 control_panel_vbase_dtor
/// Complete-object destructor: control_panel_dtor, then object3d_dtor and
/// scene_object_dtor on the virtual bases.
pub fn vbaseDtor(obj: *Object) void {
    dtor(obj);
    object_create.object3dDtor(obj);
    object_create.sceneObjectDtor(obj);
}

// @orig 1088:3fa0 control_panel_scalar_dtor
/// Scalar deleting destructor: vbaseDtor, then `operator delete` when bit 0
/// of `flags` is set. Returns `obj`.
pub fn scalarDtor(g: *Game, obj: *Object, flags: u16) *Object {
    vbaseDtor(obj);
    if (flags & 1 != 0) g.local().destroy(obj);
    return obj;
}

// @orig 1088:4038 status_bar_dtor
/// The SceneObject destructor on the base.
pub fn statusBarDtor(obj: *Object) void {
    object_create.sceneObjectDtor(obj);
}

// @orig 1088:3fd2 status_bar_scalar_dtor
/// Scalar deleting destructor: statusBarDtor, then `operator delete` when
/// bit 0 of `flags` is set. Returns `obj`.
pub fn statusBarScalarDtor(g: *Game, obj: *Object, flags: u16) *Object {
    statusBarDtor(obj);
    if (flags & 1 != 0) g.local().destroy(obj);
    return obj;
}
