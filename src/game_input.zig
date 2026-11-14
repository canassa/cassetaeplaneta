//! Port unit `game_input` (module). game_handle_message: the engine default for input, timers and private messages.
//!
//! GameVtbl slot 00, run after the scene's handler (`scene.handleMessage`)
//! and the derived-class hook (`game_hook`, slot 01) have declined a
//! message. It handles: arrow keys (walk, stop), WM_SYSTIMER ticks of the
//! control panel, the player and the carried item, the mouse move that
//! slides the control panel, left click (walk), right click (the options
//! button, picking an item out of the panel, exits, pick-up, animations),
//! right button release (dropping the carried item) and 0x402 (exit
//! finished). Returns 1 when handled, 0 when the message goes on to
//! DefWindowProc. Note the original returns 0 for WM_SYSTIMER even though
//! it handled it.
//!
//! DC handling (GetDC/ReleaseDC around the update-list flush and the
//! status-bar erase) has no counterpart: the DC is the platform screen.

const std = @import("std");
const Game = @import("core/game.zig").Game;
const object = @import("core/object.zig");
const Object = object.Object;
const world = @import("core/world.zig");
const Backdrop = world.Backdrop;
const Scene = world.Scene;
const cstr = @import("core/cstr.zig");
const ini = @import("ini.zig");
const msg_mod = @import("core/msg.zig");
const Msg = msg_mod.Msg;
const wm = msg_mod.wm;
const noite = msg_mod.noite;
const vk = msg_mod.vk;
const scene_mod = @import("scene.zig");
const game_hook = @import("game_hook.zig");
const game_scenes = @import("game_scenes.zig");
const panels = @import("panels.zig");
const portable = @import("portable.zig");
const exit_mod = @import("exit.zig");
const frames = @import("frames.zig");
const object_list = @import("object_list.zig");
const update_list = @import("update_list.zig");
const draw_list = @import("draw_list.zig");
const projection = @import("projection.zig");
const sound = @import("sound.zig");
const dib = @import("dib.zig");
const backdrop_mod = @import("backdrop.zig");
const animation = @import("behaviour/animation.zig");
const misc = @import("behaviour/misc.zig");
const movement = @import("behaviour/movement.zig");
const occupancy = @import("behaviour/occupancy.zig");
const position = @import("behaviour/position.zig");
const render = @import("behaviour/render.zig");
const space3d = @import("behaviour/space3d.zig");
const tick = @import("behaviour/tick.zig");
const visibility = @import("behaviour/visibility.zig");

/// The original's unchecked pointers: a missing one is a crash there.
fn must(comptime T: type, p: ?*T) *T {
    return p orelse @panic("game_input: null pointer");
}

fn sceneOf(g: *Game) *Scene {
    return must(Scene, g.scene);
}

/// The current scene's backdrop (the original re-reads it at every use).
fn bdOf(g: *Game) *Backdrop {
    return must(Backdrop, sceneOf(g).backdrop);
}

fn hasPlayer(g: *Game) bool {
    return scene_mod.getHasPlayer(g, sceneOf(g));
}

fn hasPanel(g: *Game) bool {
    return scene_mod.getHasControlPanel(g, sceneOf(g));
}

fn hasStatusBar(g: *Game) bool {
    return scene_mod.getHasStatusBar(g, sceneOf(g));
}

fn timerIs(g: *Game, obj: *Object, id: u16) bool {
    return @as(u16, @bitCast(animation.getTimerId(g, obj))) == id;
}

/// A mouse coordinate plus the backdrop's scroll origin (16-bit).
fn scrolled(coord: u16, origin: i16) i16 {
    return @as(i16, @bitCast(coord)) +% origin;
}

/// `if (!update_list_is_empty) { GetDC; update_list_flush; ReleaseDC }`.
fn flushUpdates(g: *Game) void {
    if (!update_list.isEmpty(&g.updateList)) update_list.flush(&g.updateList, g.plat, bdOf(g));
}

// @orig 1018:0000 game_handle_message
/// Game slot 00: offers the message to the scene, then to the hook, and
/// otherwise does the engine's default handling. Non-zero = handled.
pub fn handleMessage(g: *Game, m: Msg) i32 {
    if (scene_mod.handleMessage(g, sceneOf(g), m) != 0) return 1;
    if (game_hook.handleMessageHook(g, m) != 0) return 1;
    return switch (m.id) {
        wm.keydown => keyDown(g, m),
        wm.keyup => keyUp(g, m),
        wm.systimer => sysTimer(g, m),
        wm.mousemove => mouseMove(g, m),
        wm.lbuttondown => leftDown(g, m),
        wm.rbuttondown => rightDown(g, m),
        wm.rbuttonup => rightUp(g, m),
        noite.exit_finished => exitFinished(g, m),
        else => 0,
    };
}

fn keyDown(g: *Game, m: Msg) i32 {
    if (!hasPlayer(g)) return 0;
    const player = must(Object, g.player);
    switch (m.wparam) {
        vk.left => if (g.keyLeft == 0) {
            g.keyLeft = 1;
            movement.moveToEdgeH(g, player, bdOf(g), 1);
            movement.moveTick(g, player, bdOf(g));
        },
        vk.up => if (g.keyUp == 0) {
            g.keyUp = 1;
            movement.moveToEdgeV(g, player, bdOf(g), 4);
            movement.moveTick(g, player, bdOf(g));
        },
        vk.right => if (g.keyRight == 0) {
            g.keyRight = 1;
            movement.moveToEdgeH(g, player, bdOf(g), 2);
            movement.moveTick(g, player, bdOf(g));
        },
        vk.down => if (g.keyDown == 0) {
            g.keyDown = 1;
            movement.moveToEdgeV(g, player, bdOf(g), 8);
            movement.moveTick(g, player, bdOf(g));
        },
        else => return 0,
    }
    if (hasPanel(g)) render.draw(g, must(Object, g.controlPanel), bdOf(g));
    if (hasStatusBar(g)) render.draw(g, must(Object, g.statusBar), bdOf(g));
    flushUpdates(g);
    return 1;
}

fn keyUp(g: *Game, m: Msg) i32 {
    if (!hasPlayer(g)) return 0;
    switch (m.wparam) {
        vk.left => g.keyLeft = 0,
        vk.up => g.keyUp = 0,
        vk.right => g.keyRight = 0,
        vk.down => g.keyDown = 0,
        else => return 0,
    }
    movement.stopMoving(g, must(Object, g.player), bdOf(g));
    return 1;
}

/// Object timers of the engine: the control panel's slide (with the
/// player redrawn when it overlaps), the player's walk, the carried item.
fn sysTimer(g: *Game, m: Msg) i32 {
    const id = m.wparam;
    if (hasPanel(g) and timerIs(g, must(Object, g.controlPanel), id)) {
        const panel = must(Object, g.controlPanel);
        tick.tick(g, panel, bdOf(g));
        if (hasPlayer(g)) {
            const player = must(Object, g.player);
            if (position.hitboxOverlaps(g, panel, player)) {
                if (!movement.isMoving(g, player)) {
                    tick.tick(g, player, bdOf(g));
                } else {
                    render.draw(g, player, bdOf(g));
                    visibility.redrawOverlapping(g, player, bdOf(g), 0);
                }
            }
        }
        render.draw(g, panel, bdOf(g));
    } else {
        if (hasPlayer(g) and timerIs(g, must(Object, g.player), id)) {
            const player = must(Object, g.player);
            if (!movement.isMoving(g, player)) {
                tick.tick(g, player, bdOf(g));
            } else {
                movement.moveTick(g, player, bdOf(g));
            }
        } else if (id == movement.smooth_fall_timer) {
            movement.smoothFallTick(g, g.selectedItem, bdOf(g));
        } else if (g.selectedItem) |sel| {
            if (timerIs(g, sel, id)) {
                if (movement.isMoving(g, sel)) {
                    movement.moveTick(g, sel, bdOf(g));
                } else if (g.fixes.drop_falls_onto_support) {
                    // B30: keep the 3D place the drop gave it.
                    space3d.setElevationAtBottom(g, sel, bdOf(g), @bitCast(g.unk001A));
                } else {
                    _ = space3d.setElevation(g, sel, bdOf(g), @bitCast(g.unk001A));
                }
            }
        }
        if (hasPanel(g)) render.draw(g, must(Object, g.controlPanel), bdOf(g));
        if (hasStatusBar(g)) render.draw(g, must(Object, g.statusBar), bdOf(g));
    }
    if (g.fixes.panel_follows_inventory and hasPanel(g)) panelFollowsInventory(g);
    flushUpdates(g);
    return 0;
}

/// B34's fix (not in the original): the panel draws its icons into the
/// backdrop only, and only a slide or a drop puts them on the screen; an
/// item handed back by a give-item scene's reply (to the first slot) left
/// the old icons showing. When the inventory of the open, still panel is
/// not the one last shown, redraw it as a drop does.
fn panelFollowsInventory(g: *Game) void {
    const panel = must(Object, g.controlPanel);
    const key = inventoryKey(g);
    // A slide redraws the whole panel, its end with the icons.
    if (!panels.isOpen(g, panel) or animation.isRunning(g, panel)) {
        g.panelShows = key;
        return;
    }
    if (g.panelShows == key) return;
    g.panelShows = key;
    render.erase(g, panel, bdOf(g));
    visibility.redrawOverlapping(g, panel, bdOf(g), 1);
    render.draw(g, panel, bdOf(g));
    _ = visibility.invalidate(g, panel);
}

/// The items of the player's inventory, in panel order.
fn inventoryKey(g: *Game) u64 {
    var h = std.hash.Wyhash.init(0);
    const player = g.player orelse return 0;
    var it = player.actor.inventory.head;
    while (it) |o| : (it = o.next) h.update(std.mem.asBytes(&o.id));
    return h.final();
}

/// The control panel slides open at the bottom edge of the window (y >
/// 440) and closed above its top (y < 340) unless an item is held.
fn mouseMove(g: *Game, m: Msg) i32 {
    if (!hasPanel(g)) return 0;
    const panel = must(Object, g.controlPanel);
    if (m.hi() > 0x1b8) {
        if (panels.isOpen(g, panel)) return 1;
        if (animation.isRunning(g, panel)) return 1;
        if (hasStatusBar(g)) render.erase(g, must(Object, g.statusBar), bdOf(g));
        panels.slide(g, panel, bdOf(g), 4);
    } else {
        if (m.hi() >= 0x154) return 1;
        if (g.itemSelected != 0) return 1;
        if (!panels.isOpen(g, panel)) return 1;
        if (animation.isRunning(g, panel)) return 1;
        panels.slide(g, panel, bdOf(g), 8);
    }
    render.draw(g, panel, bdOf(g));
    return 1;
}

fn leftDown(g: *Game, m: Msg) i32 {
    if (!hasPlayer(g)) return 0;
    movement.moveTo(g, must(Object, g.player), @bitCast(m.lo()), @bitCast(m.hi()), bdOf(g));
    return 1;
}

fn rightDown(g: *Game, m: Msg) i32 {
    const scene0 = sceneOf(g);
    const sx = scrolled(m.lo(), bdOf(g).originX);
    const sy = scrolled(m.hi(), bdOf(g).originY);
    if (scene_mod.getHasControlPanel(g, scene0)) {
        const panel = must(Object, g.controlPanel);
        if (panels.isOpen(g, panel) and panels.contains(g, panel, sx, sy)) {
            if (panels.isOnOptionsButton(g, panel, sx, sy)) {
                // Remember where we were, then open the options screen.
                const player = must(Object, g.player);
                cstr.copy(&g.savedPosition.scene, cstr.slice(&scene0.name));
                g.savedPosition.playerX = player.x;
                g.savedPosition.playerY = player.y;
                g.savedPosition.hasPlayer = scene0.hasPlayer;
                g.savedPosition.hasControlPanel = scene0.hasControlPanel;
                g.savedPosition.hasStatusBar = scene0.hasStatusBar;
                g.savedPosition.is1Animation = scene0.is1Animation;
                g.savedPosition.isClickExit = scene0.isClickExit;
                update_list.discard(&g.updateList);
                _ = game_scenes.switchScene(g, "opcoes", 0, 0, 0, 0, 0, 0, 0); // 1018:1ba8
            } else if (scene0.mayDropObject != 0) {
                const player = must(Object, g.player);
                g.selectedItem = panels.getInventoryItemAt(g, panel, &player.actor.inventory, sx, sy);
                if (g.selectedItem != null) {
                    g.itemSelected = 1;
                    if (g.fixes.drag_shows_item) g.drag.item = g.selectedItem;
                    return 1;
                }
                g.itemSelected = 0;
            }
        }
    }

    // Whatever is under the click (the scene may have just changed).
    const bd = bdOf(g);
    const q = backdrop_mod.queryRect(g, bd, scrolled(m.lo(), bd.originX), scrolled(m.hi(), bd.originY), 16, 16);
    if (q.result <= 0) return 1;
    const obj = q.obj orelse return 1;
    misc.slot00(g, obj);
    if (obj.is(.exit)) {
        if (!exitTakesClick(g, obj)) return 1;
        tick.play(g, obj, bdOf(g));
        g.exitPending = 1;
    } else if (obj.is(.portable)) {
        const player = must(Object, g.player);
        if (object_list.isFull(&player.actor.inventory)) return 1;
        const p = obj.as(.portable).?;
        _ = portable.pickUp(g, p, player);
        frames.resetRects(p);
        visibility.hideAndInvalidate(g, p, 0, bdOf(g));
        visibility.redrawOverlapping(g, p, bdOf(g), 0);
        frames.resetRects(p);
        if (p.unk492 != 0 and p.frames.len == 2) _ = frames.setStrip(p, 1, bdOf(g));
        g.score +%= p.portable.scoreTake;
        misc.slot1F(g, must(Object, g.controlPanel), bdOf(g));
    } else if (obj.is(.animation)) {
        animation.playOnce(g, obj.as(.animation).?, bdOf(g));
    }
    return 1;
}

/// Whether a right click on exit `obj` takes it: the player (when the
/// scene has one) stands within one and a half of its own hit widths of
/// the exit, and the exit is enabled.
pub fn exitTakesClick(g: *Game, obj: *Object) bool {
    if (hasPlayer(g) and !exitInReach(g, obj)) return false;
    return exit_mod.isEnabled(g, obj);
}

/// The reach part of `exitTakesClick`: the centres of the player's and the
/// exit's hit boxes are less than one and a half of the player's hit
/// widths apart horizontally.
pub fn exitInReach(g: *Game, obj: *Object) bool {
    const player = must(Object, g.player);
    const half_w: i16 = @divTrunc(frames.hitW(obj), 2);
    var d: i16 = player.x -% obj.x -% half_w;
    d +%= @divTrunc(frames.hitW(player), 2);
    d -%= frames.hitX(obj);
    const a: i16 = frames.hitX(player) +% d;
    const dist: i16 = if (a < 0) 0 -% a else a;
    const limit: i16 = @divTrunc(frames.hitW(player) *% 3, 2);
    return dist < limit;
}

/// Releasing the right button over the scene drops the carried item there,
/// on top of whatever it lands on.
fn rightUp(g: *Game, m: Msg) i32 {
    if (g.itemSelected == 0) return 1;
    g.itemSelected = 0;
    const sx0 = scrolled(m.lo(), bdOf(g).originX);
    const sy = scrolled(m.hi(), bdOf(g).originY);
    const panel = must(Object, g.controlPanel);
    if (!panels.isOutside(g, panel, sx0, sy)) return 1;
    const sel = g.selectedItem orelse return 1;
    // B30's fix: an offer (the scene's handler has started the reply) is
    // not a drop; the item stays in the character's hands, as it does in
    // the original. Asked before the item enters the grid.
    const offered = g.fixes.drop_falls_onto_support and isOfferTarget(g, sx0, sy);

    render.erase(g, panel, bdOf(g));
    visibility.redrawOverlapping(g, panel, bdOf(g), 1);
    space3d.moveToAndDrop(g, sel, @divTrunc(frames.width(sel), 2) *% -1 +% sx0, @divTrunc(frames.height(sel), 2) *% -1 +% sy, bdOf(g));
    _ = space3d.setElevation(g, sel, bdOf(g), @bitCast(g.unk001A));
    const support = space3d.findSupport(g, sel, bdOf(g)).support;
    frames.resetRects(sel);
    render.draw(g, sel, bdOf(g));
    _ = occupancy.occupy(g, sel, bdOf(g));
    sel.visible = 1;
    // B25: moveToAndDrop left the pick-up position as the previous one;
    // unless a walk below resets it, the restore of the next pick-up
    // misses this image.
    if (g.fixes.drop_syncs_previous_position) {
        sel.mover.prevX = sel.x;
        sel.mover.prevY = sel.y;
    }
    _ = visibility.invalidate(g, sel);
    _ = portable.drop(g, sel, sceneOf(g));
    g.score -%= sel.portable.scoreTake;
    const sx: i16 = sx0 -% (@divTrunc(frames.width(sel), 2) +% bdOf(g).originX);
    g.unk001A = 0;
    if (g.fixes.drop_falls_onto_support) {
        // B30: fall straight down onto a real support, or to the floor.
        fallToRest(g, sel, offered);
    } else if (support) |sup| {
        if (!position.hitboxOverlaps(g, sel, sup)) {
            // Rest on the top of the support, halfway between its near and
            // far edge, but never below the bottom strip of the view.
            const front = projection.projectPoint(bdOf(g), space3d.getWorldX(g, sup), space3d.getWorldDepth(g, sup), space3d.getWorldElev(g, sup) +% space3d.getSizeH(g, sup));
            const back = projection.projectPoint(bdOf(g), space3d.getWorldX(g, sup), space3d.getWorldDepth(g, sup) +% space3d.getSizeD(g, sup), space3d.getWorldElev(g, sup) +% space3d.getSizeH(g, sup));
            var y: i16 = @divTrunc(frames.height(sel), 2) +% @divTrunc(front.y +% back.y, 2);
            const limit: i16 = bdOf(g).viewHeight -% 100;
            if (limit < y) y = limit;
            dropWalk(g, sel, sx, y);
            g.unk001A = @bitCast(space3d.getSizeH(g, sup));
        }
    } else {
        dropWalk(g, sel, sx, bdOf(g).viewHeight -% 100);
    }
    movement.smoothFallStart(g, sel);
    render.draw(g, panel, bdOf(g));
    _ = visibility.invalidate(g, panel);
    frames.resetRects(sel);
    render.draw(g, sel, bdOf(g));
    _ = visibility.invalidate(g, sel);
    return 1;
}

/// The walk of a dropped item to its resting place, bottom row `y` (window
/// rows). `sx` is the original's x (1018:0ee3-0ef7: the release point less
/// half the item's width), which moveTo (1010:c3ba) takes as the bottom
/// centre: the target is half the item to its left, and with the item's
/// horizontal step 0 (portable_ctor 1010:6e2c) a line wider than high
/// never arrives (B36). With the fix it falls straight down.
fn dropWalk(g: *Game, sel: *Object, sx: i16, y: i16) void {
    if (!g.fixes.drop_walk_straight) return movement.moveTo(g, sel, sx, y, bdOf(g));
    movement.fallTo(g, sel, y -% frames.height(sel) +% bdOf(g).originY, bdOf(g));
}

/// Whether the object under (`x`, `y`) (scrolled; the handlers' 16x16
/// query) takes offers: a `WAVE=` line of the current scene (the replies
/// to items given, `WAVE=<object>,<variant>,<item>,…`) names it. Not in
/// the original (B30's fix). Leaves the INI file anywhere: its readers seek
/// their section first.
fn isOfferTarget(g: *Game, x: i16, y: i16) bool {
    const q = backdrop_mod.queryRect(g, bdOf(g), x, y, 16, 16);
    if (q.result <= 0) return false;
    const obj = q.obj orelse return false;
    const fd = g.iniFile;
    const found = ini.seekSection(&g.ini, g.plat, g.fixes, fd, cstr.slice(&g.curSceneName), true) catch return false;
    if (found == 0) return false;
    // The section's lines, up to the next header: is one `WAVE=<id>,`?
    var line: [16]u8 = undefined;
    var n: usize = 0;
    var buf: [512]u8 = undefined;
    while (true) {
        const got = g.plat.read(fd, &buf);
        if (got == 0) return false;
        for (buf[0..got]) |c| {
            if (c == '\r' or c == '\n') {
                if (waveLineNames(line[0..n], obj.id)) return true;
                n = 0;
            } else if (n == 0 and (c == ' ' or c == '\t')) {
                continue;
            } else if (n == 0 and c == '[') {
                return false;
            } else if (n < line.len) {
                line[n] = c;
                n += 1;
            }
        }
    }
}

/// `WAVE=<id>,…` (case-insensitive key, blanks around the number).
fn waveLineNames(line: []const u8, id: i16) bool {
    if (line.len < 5 or !std.ascii.eqlIgnoreCase(line[0..5], "WAVE=")) return false;
    const end = std.mem.indexOfScalar(u8, line, ',') orelse return false;
    const v = std.fmt.parseInt(i16, std.mem.trim(u8, line[5..end], " \t"), 10) catch return false;
    return v == id;
}

test "waveLineNames" {
    try std.testing.expect(waveLineNames("WAVE=6,0,68,fase2", 6));
    try std.testing.expect(waveLineNames("wave= 13 ,0,66", 13));
    try std.testing.expect(!waveLineNames("WAVE=6,0,68", 68));
    try std.testing.expect(!waveLineNames("Local=6,0,22", 6));
}

/// The window rows (back, front) of `other`'s top face, where a dropped
/// item may rest, or null when `other` is no support for it. Not in the
/// original (B30's fix).
///
/// A support is a thing with a 3D box (a table, furniture, another dropped
/// item; not a door or picture without a size, not a character) under the
/// item's centre. Its face is the projected near and far top edges. The
/// INI's 3D placement does not always match the picture (the corridor
/// table's top projects 90 rows above its drawn top), so the face is kept
/// inside the hit box, and put on the hit box's top row when the two do
/// not meet at all.
const RestFace = struct { back: i16, front: i16 };

fn restFace(g: *Game, sel: *Object, other: *Object) ?RestFace {
    const bd = bdOf(g);
    if (other.visible == 0 or other.id == sel.id) return null;
    switch (other.kind) {
        .local, .animated, .portable, .exit => {},
        .moveable, .actor, .player, .control_panel, .status_bar => return null,
    }
    const elev = space3d.getWorldElev(g, other);
    const h = space3d.getSizeH(g, other);
    if (space3d.getSizeW(g, other) <= 0 or h <= 0 or space3d.getSizeD(g, other) <= 0) return null;
    const centre = sel.x +% frames.hitX(sel) +% @divTrunc(frames.hitW(sel), 2);
    const left = other.x +% frames.hitX(other);
    if (centre < left or left +% frames.hitW(other) < centre) return null;
    const x = space3d.getWorldX(g, other);
    const depth = space3d.getWorldDepth(g, other);
    const near = projection.projectPoint(bd, x, depth, elev +% h).y;
    const far = projection.projectPoint(bd, x, depth +% space3d.getSizeD(g, other), elev +% h).y;
    const hit_top = other.y +% frames.hitY(other) -% bd.originY;
    const hit_bottom = hit_top +% frames.hitH(other);
    const back = @min(near, far);
    const front = @max(near, far);
    if (front < hit_top or back > hit_bottom) return .{ .back = hit_top, .front = hit_top };
    return .{ .back = std.math.clamp(back, hit_top, hit_bottom), .front = std.math.clamp(front, hit_top, hit_bottom) };
}

/// B30's fix. Rows are the item's middle row, as in the original's rest
/// position (middle on the support face's middle row, or bottom on
/// `viewHeight - 100`). The item falls straight down from where it was
/// released to the first support face met at or under that row, resting on
/// the face's middle row unless it was released lower on the face; with
/// none, it falls to the floor row. It never moves up: released on or
/// below its rest row, it stays. An `offered` item stays where it was
/// released (no support).
fn fallToRest(g: *Game, sel: *Object, offered: bool) void {
    const bd = bdOf(g);
    const half: i16 = @divTrunc(frames.height(sel), 2);
    const released: i16 = sel.y -% bd.originY +% half;
    const floor: i16 = bd.viewHeight -% 100 -% half;
    var rest: i16 = if (offered) released else @max(released, floor);
    var on: ?*Object = null;
    const lists = [2]?*object.ObjectList{ bd.sceneList, &g.globalObjects };
    for (if (offered) lists[0..0] else &lists) |list| {
        var cur: ?*Object = if (list) |l| l.head else null;
        while (cur) |other| : (cur = other.next) {
            const face = restFace(g, sel, other) orelse continue;
            if (face.front < released) continue; // its top is above the item
            const y = @max(released, @min(@divTrunc(face.back +% face.front, 2), floor));
            if (y < rest or (on == null and y == rest)) {
                rest = y;
                on = other;
            }
        }
    }
    // Sort the item into the draw list as it will rest (on the support's
    // top), not as it was released, so the support does not hide it.
    const elev: i16 = if (on) |sup| space3d.getWorldElev(g, sup) +% space3d.getSizeH(g, sup) else 0;
    g.unk001A = @bitCast(elev);
    const y = sel.y;
    sel.y = rest -% half +% bd.originY;
    space3d.setElevationAtBottom(g, sel, bd, elev);
    sel.y = y;
    draw_list.remove(&g.drawList, sel);
    _ = draw_list.insert(g, bd, sel);
    sel.portable.restElev = null;
    if (rest == released) {
        visibility.redrawOverlapping(g, sel, bd, 1);
        return;
    }
    // The walk's steps put it on the floor again; its stop restores this.
    sel.portable.restElev = elev;
    // Straight down its own column (as B36's fix), so the walk ends there.
    movement.fallTo(g, sel, rest -% half +% bd.originY, bd);
}

/// `Fixes.drag_shows_item` and the one-button mode (not in the original):
/// puts the dragged (or tap-selected) item's panel icon, centred on the
/// pointer, in the screen overlay the platform draws over the frame it
/// shows; hides it when no drag is on (released, or the selection cleared
/// by a drop, an offer, a scene change). Call it before presenting.
pub fn showDrag(g: *Game) void {
    const ov = &g.plat.screen().overlay;
    ov.shown = false;
    if (!g.showsDrag()) return;
    const item = g.drag.item orelse return;
    if (g.itemSelected == 0 or g.selectedItem != item) {
        g.drag.item = null;
        return;
    }
    const p = &item.portable;
    const icon = p.icon orelse return;
    const max: i16 = @TypeOf(ov.*).max_side;
    if (p.iconW <= 0 or p.iconH <= 0 or p.iconW > max or p.iconH > max) return;
    // The panel's blit (portable.drawIcon) into a top-down DIB of the
    // overlay's size, cleared to the transparent index.
    const stride: i16 = (p.iconW +% 3) & ~@as(i16, 3);
    const hdr: object.BitmapInfoHeader = .{ .biWidth = stride, .biHeight = -@as(i32, p.iconH) };
    const n: usize = @intCast(stride *% p.iconH);
    @memset(ov.pixels[0..n], g.unk001C);
    const orient: i16 = @truncate(item.dibFormatOk);
    const drawn = dib.copyTransparent(&hdr, ov.pixels[0..n], 0, 0, icon.bits, &icon.header, 0, 0, p.iconW, orient *% p.iconH, g.unk001C) catch false;
    if (!drawn) return;
    ov.width = @intCast(stride);
    ov.height = @intCast(p.iconH);
    ov.transparent = g.unk001C;
    ov.x = g.drag.x -% @divTrunc(p.iconW, 2);
    ov.y = g.drag.y -% @divTrunc(p.iconH, 2);
    ov.shown = true;
}

/// 0x402: the exit animation finished; take the exit (wParam = index).
fn exitFinished(g: *Game, m: Msg) i32 {
    if (g.exitPending == 0) return 0;
    g.exitPending = 0;
    update_list.discard(&g.updateList);
    sound.freeAll(&g.sound, g.plat);
    _ = game_scenes.takeExit(g, @bitCast(m.wparam));
    return 1;
}
