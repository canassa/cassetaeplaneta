//! Port unit `panels` (module). control panel (slide, inventory, texts, options button) and status bar text.
//!
//! Original bug reproduced (no Fixes flag: BUGS.md and fixes.zig are outside
//! this unit): `drawTexts` formats the 32-bit score with `%7.7d`, which
//! reads only the low 16 bits as a signed int, so scores above 32767 show
//! wrapped (and possibly negative).

const Game = @import("core/game.zig").Game;
const object = @import("core/object.zig");
const Object = object.Object;
const ObjectList = object.ObjectList;
const world = @import("core/world.zig");
const Backdrop = world.Backdrop;
const cstr = @import("core/cstr.zig");
const platform = @import("platform/platform.zig");
const frames = @import("frames.zig");
const object_list = @import("object_list.zig");
const portable = @import("portable.zig");
const tick = @import("behaviour/tick.zig");

/// Screen width the centred message is laid out against (0x280).
const screen_width: i16 = 640;
/// Screen height the texts are anchored to (0x1e0).
const screen_height: i16 = 480;
/// Inventory slots: first slot x and slot width.
const slot_x: i16 = 0x5c;
const slot_w: i16 = 0x38;

// @orig 1018:1ed2 status_bar_set_text
/// Copies `text` into the status bar's buffer and records its x position.
pub fn statusBarSetText(g: *Game, obj: *Object, x: i16, text: []const u8) void {
    _ = g;
    cstr.copy(&obj.status.text, text);
    obj.status.textX = x;
}

// @orig 1018:2070 control_panel_reset
/// Closed, idle state: not playing, no frames left, no slide steps, not open.
pub fn reset(g: *Game, obj: *Object) void {
    _ = g;
    obj.anim.playOnce = 0;
    obj.anim.running = 0;
    obj.framesLeft = 0;
    obj.panel.slideStepsLeft = 0;
    obj.panel.isOpen = 0;
}

// @orig 1018:20a0 control_panel_draw_texts
/// Draws the message (at its x, or centred when x is -1), the score and the
/// lives into the backdrop bitmap in the panel text colour, transparent
/// background, placed relative to the visible panel height.
pub fn drawTexts(g: *Game, obj: *Object, bd: *Backdrop) void {
    const p = &obj.panel;
    const style: platform.TextStyle = .{ .color = p.textColor, .bk_mode = .transparent };
    const surf = bd.surface();
    if (p.message[0] != 0) {
        const msg = cstr.slice(&p.message);
        var x: i16 = p.messageX;
        if (p.messageX == -1) {
            const w: i16 = @bitCast(@as(u16, @truncate(g.plat.textExtent(msg))));
            x = @bitCast(@as(u16, @bitCast(screen_width -% w)) >> 1);
        }
        const y = screen_height -% getVisibleHeight(g, obj);
        _ = g.plat.textOut(surf, style, x, y, msg);
    }
    // sprintf("%7.7d", g_score): the long argument is read as a 16-bit int
    // (BUGS.md B19; `Fixes.score_32bit` shows the whole score).
    const score: i32 = if (g.fixes.score_32bit) g.score else @as(i16, @truncate(g.score));
    const mag: u32 = @abs(score);
    if (score < 0) {
        _ = cstr.print(&p.scoreText, "-{d:0>7}", .{mag});
    } else {
        _ = cstr.print(&p.scoreText, "{d:0>7}", .{mag});
    }
    _ = cstr.print(&p.livesText, "{d}", .{g.lives});
    // The y follow the 20-pixel steps of the visible height, which the
    // panel art does not (BUGS.md B27; `Fixes.panel_text_follows_art`).
    var score_y = 0x208 -% getVisibleHeight(g, obj);
    var lives_y = 0x1db -% getVisibleHeight(g, obj);
    if (g.fixes.panel_text_follows_art and obj.curFrame >= 0 and obj.curFrame < art_score_y.len) {
        const f: usize = @intCast(obj.curFrame);
        score_y = art_score_y[f];
        lives_y = art_lives_y[f];
    }
    _ = g.plat.textOut(surf, style, 0x221, score_y, cstr.slice(&p.scoreText));
    _ = g.plat.textOut(surf, style, 4, lives_y, cstr.slice(&p.livesText));
}

/// `Fixes.panel_text_follows_art` (BUGS.md B27): per panel frame, the text
/// y that keeps the lives 2 px below the black badge's top (as when the
/// panel is closed: badge at 433/400/381/362) and the score 4 px below its
/// box's top (glyphs centred; box at 455/436/417, off screen when closed).
const art_lives_y = [_]i16{ 435, 402, 383, 364 };
const art_score_y = [_]i16{ 0x208 - 40, 459, 440, 421 };

// @orig 1010:45f0 control_panel_is_open
/// ControlPanel slot 08: fully slid up.
pub fn isOpen(g: *Game, obj: *Object) bool {
    _ = g;
    return obj.panel.isOpen != 0;
}

// @orig 1010:462c control_panel_get_visible_height
/// ControlPanel slot 09: (current frame + 2) * 20 (40 closed .. 100 open).
pub fn getVisibleHeight(g: *Game, obj: *Object) i16 {
    _ = g;
    return (obj.curFrame +% 2) *% 0x14;
}

// @orig 1018:2650 control_panel_is_on_options_button
/// ControlPanel slot 0A: the Opcoes button, x 18..63, y 410..470.
pub fn isOnOptionsButton(g: *Game, obj: *Object, x: i16, y: i16) bool {
    _ = .{ g, obj };
    return x >= 0x12 and x <= 0x3f and y >= 0x19a and y <= 0x1d6;
}

// @orig 1018:2250 control_panel_slide
/// ControlPanel slot 0B: starts sliding; direction 4 = up (frames 1..3),
/// 8 = down (frames played backwards).
pub fn slide(g: *Game, obj: *Object, bd: *Backdrop, direction: i16) void {
    obj.panel.slideDir = direction;
    const up: i16 = if (direction == 4) 1 else 0;
    obj.panel.slideStepsLeft = frames.frameCount(obj) -% up;
    obj.curFrame = 0;
    // B48: frame 0 is the closed panel; the first step of a slide down
    // goes back to the open frame (prevFrame wraps), so until then any
    // redraw of the panel cut the closed frame into the open one.
    if (g.fixes.panel_close_keeps_open_frame and direction == 8) obj.curFrame = frames.curStrip(obj).count -% 1;
    tick.play(g, obj, bd);
}

// @orig 1018:23e2 control_panel_draw_inventory
/// ControlPanel slot 0C: draws every inventory object's icon into its slot;
/// returns the player's inventory list.
pub fn drawInventory(g: *Game, obj: *Object, bd: *Backdrop) ?*ObjectList {
    const player = g.player.?;
    const inv = &player.actor.inventory;
    if (!object_list.isEmpty(inv)) {
        var item = inv.head;
        var index: i16 = 0;
        while (item) |it| : (index +%= 1) {
            drawInventoryItem(g, obj, bd, it.as(.portable), index);
            item = it.next;
        }
    }
    return inv;
}

/// B49's fix (`Fixes.panel_icons_while_sliding`): the icons
/// drawn while the panel slides, lowered with its art. A frame shows the
/// art `getVisibleHeight` rows high, so the icons sit that much below
/// where the open frame puts them (clipped at the screen's bottom).
pub fn drawInventorySliding(g: *Game, obj: *Object, bd: *Backdrop) void {
    const open_h: i16 = (frames.frameCount(obj) -% 1 +% 2) *% 0x14;
    const dy = open_h -% getVisibleHeight(g, obj);
    const inv = &g.player.?.actor.inventory;
    var item = inv.head;
    var index: i16 = 0;
    while (item) |it| : (index +%= 1) {
        portable.drawIcon(g, it, bd, index *% slot_w +% slot_x, obj.y +% 0x46 +% dy) catch {};
        item = it.next;
    }
}

// @orig 1018:24a6 control_panel_is_outside
/// ControlPanel slot 0D: false when the point lies inside the panel's
/// rectangle (position + frame size).
pub fn isOutside(g: *Game, obj: *Object, x: i16, y: i16) bool {
    _ = g;
    if (obj.x > x) return true;
    if (obj.x +% frames.width(obj) < x) return true;
    if (obj.y > y) return true;
    if (obj.y +% frames.height(obj) < y) return true;
    return false;
}

// @orig 1010:4666 control_panel_contains
/// ControlPanel slot 0E: the negation of `isOutside`.
pub fn contains(g: *Game, obj: *Object, x: i16, y: i16) bool {
    return !isOutside(g, obj, x, y);
}

// @orig 1018:2584 control_panel_get_inventory_item_at
/// ControlPanel slot 0F: the portable in the slot under column `x`, or null.
pub fn getInventoryItemAt(g: *Game, obj: *Object, list: *ObjectList, x: i16, y: i16) ?*Object {
    _ = .{ g, obj, y };
    var item: ?*Object = null;
    if (!object_list.isEmpty(list)) {
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

// @orig 1018:253c control_panel_draw_inventory_item
/// ControlPanel slot 10: draws the item's icon into panel slot `index`
/// (x 92 + 56 * index, y = panel y + 70); nothing for null.
pub fn drawInventoryItem(g: *Game, obj: *Object, bd: *Backdrop, item: ?*Object, index: i16) void {
    const it = item orelse return;
    // The original ignores the icon blit's result.
    portable.drawIcon(g, it, bd, index *% slot_w +% slot_x, obj.y +% 0x46) catch {};
}

test "panels is analysed" {
    _ = &drawTexts;
    _ = &drawInventory;
    _ = &slide;
    _ = &getInventoryItemAt;
    _ = &statusBarSetText;
    _ = &reset;
}
