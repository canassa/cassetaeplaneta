//! Port unit `game_input` (module) of TIRO.EXE. game_handle_message (GameVtbl slot 00, 3.7 KB: the engine default under the TIRO scene's handler, which answers every key, timer and mouse message) and the Portable pick-up/drop it calls.
//!
//! `gallery.handleMessage` sees every message first; this default runs
//! only for what it declines: WM_DESTROY, WM_ACTIVATE, 0x203 and the rest
//! (all answered 0 here). The scene has a player (the crossbow) but no
//! control panel, status bar, exits or portables, so everything below the
//! dispatch is unreachable; it is ported whole anyway.
//!
//! Same source as ENCAIXE's `game_input`; only the build differs (medium
//! model /Od). Differences in the port: the update-list flush and discard
//! are calls (`lists.updateFlush`/`updateDiscard`, `render.resetRects`)
//! guarded by `updateIsEmpty`, not inlined loops; the `hwnd`/`hdc`
//! parameters are dropped (the uninitialised hdc word handed to
//! redrawOverlapping in the WM_SYSTIMER panel path is one of them).
//!
//! The player is never a DirectionalPlayer, so `asDirectionalPlayer()` is
//! null and the inventory list `+0x40` is DGROUP:0x40, which in TIRO holds
//! string data (not zeros as in ENCAIXE): the paths that read it panic as
//! `panels.drawInventory` does. No Portable is ever constructed either.

const std = @import("std");
const msg = @import("../core/msg.zig");
const Msg = msg.Msg;
const Game = @import("core/game.zig").Game;
const object = @import("core/object.zig");
const Object = object.Object;
const ObjectList = object.ObjectList;
const world = @import("core/world.zig");
const Backdrop = world.Backdrop;
const Scene = world.Scene;
const backdrop_unit = @import("backdrop.zig");
const game_unit = @import("game.zig");
const gallery = @import("gallery.zig");
const lists = @import("lists.zig");
const panels = @import("panels.zig");
const scene_unit = @import("scene.zig");
const animation = @import("behaviour/animation.zig");
const movement = @import("behaviour/movement.zig");
const position = @import("behaviour/position.zig");
const render = @import("behaviour/render.zig");
const space3d = @import("behaviour/space3d.zig");
const visibility = @import("behaviour/visibility.zig");

/// The original's unchecked pointers: a missing one is a crash there.
fn must(comptime T: type, p: ?*T) *T {
    return p orelse @panic("tiro.game_input: null pointer");
}

fn sceneOf(g: *Game) *Scene {
    return must(Scene, g.scene);
}

/// The current scene's backdrop (the original re-reads it at every use).
fn bdOf(g: *Game) *Backdrop {
    return must(Backdrop, sceneOf(g).backdrop);
}

fn hasPlayer(g: *Game) bool {
    return scene_unit.getHasPlayer(g, sceneOf(g));
}

fn hasPanel(g: *Game) bool {
    return scene_unit.getHasControlPanel(g, sceneOf(g));
}

fn hasStatusBar(g: *Game) bool {
    return scene_unit.getHasStatusBar(g, sceneOf(g));
}

fn panelOf(g: *Game) *Object {
    return must(Object, g.controlPanel);
}

fn playerOf(g: *Game) *Object {
    return must(Object, g.player);
}

fn timerIs(g: *Game, obj: *Object, id: u16) bool {
    return @as(u16, @bitCast(animation.getTimerId(g, obj))) == id;
}

/// A mouse coordinate plus the backdrop's scroll origin (16-bit).
fn scrolled(coord: u16, origin: i16) i16 {
    return @as(i16, @bitCast(coord)) +% origin;
}

/// `x / 2` as the compiler does it for a signed word (truncating).
fn half(v: i16) i16 {
    return @divTrunc(v, 2);
}

fn abs16(v: i16) i16 {
    const s = v >> 15;
    return (v ^ s) -% s;
}

/// `if (!update_list_is_empty) { GETDC; update_list_flush; RELEASEDC }`.
fn flushUpdates(g: *Game, bd: *Backdrop) void {
    if (lists.updateIsEmpty(&g.updateList)) return;
    lists.updateFlush(g, &g.updateList, bd);
}

/// The tail shared by the key and timer paths: redraw the panel and the
/// status bar when the scene has them, then flush.
fn redrawAndFlush(g: *Game) void {
    if (hasPanel(g)) render.draw(g, panelOf(g), bdOf(g));
    if (hasStatusBar(g)) render.draw(g, must(Object, g.statusBar), bdOf(g));
    flushUpdates(g, bdOf(g));
}

/// GameVtbl slot 00 handleMessage (game_handle_message): the engine default under the scene's handler. Non-zero = handled.
// @orig 1040:0000 game_handle_message
pub fn handleMessage(g: *Game, m: Msg) i32 {
    if (gallery.handleMessage(g, sceneOf(g), m) != 0) return 1;
    return switch (m.id) {
        msg.wm.keydown => keyDown(g, m),
        msg.wm.keyup => keyUp(g, m),
        msg.wm.systimer => sysTimer(g, m),
        msg.wm.mousemove => mouseMove(g, m),
        msg.wm.lbuttondown => leftDown(g, m),
        msg.wm.rbuttondown => rightDown(g, m),
        msg.wm.rbuttonup => rightUp(g, m),
        msg.noite.exit_finished => exitFinished(g, m),
        else => 0,
    };
}

fn keyDown(g: *Game, m: Msg) i32 {
    if (!hasPlayer(g)) return 0;
    const p = playerOf(g);
    switch (m.wparam) {
        msg.vk.left => if (g.keyLeft == 0) {
            g.keyLeft = 1;
            movement.moveToEdgeH(g, p, bdOf(g), 1);
            movement.moveTick(g, p, bdOf(g));
        },
        msg.vk.up => if (g.keyUp == 0) {
            g.keyUp = 1;
            movement.moveToEdgeV(g, p, bdOf(g), 4);
            movement.moveTick(g, p, bdOf(g));
        },
        msg.vk.right => if (g.keyRight == 0) {
            g.keyRight = 1;
            movement.moveToEdgeH(g, p, bdOf(g), 2);
            movement.moveTick(g, p, bdOf(g));
        },
        msg.vk.down => if (g.keyDown == 0) {
            g.keyDown = 1;
            movement.moveToEdgeV(g, p, bdOf(g), 8);
            movement.moveTick(g, p, bdOf(g));
        },
        else => return 0,
    }
    redrawAndFlush(g);
    return 1;
}

fn keyUp(g: *Game, m: Msg) i32 {
    if (!hasPlayer(g)) return 0;
    switch (m.wparam) {
        msg.vk.left => g.keyLeft = 0,
        msg.vk.up => g.keyUp = 0,
        msg.vk.right => g.keyRight = 0,
        msg.vk.down => g.keyDown = 0,
        else => return 0,
    }
    movement.stopMoving(g, playerOf(g), bdOf(g));
    return 1;
}

/// The timers: the control panel's slide (the player redrawn when it
/// overlaps), the player's walk, the carried item's drop. Returns 0 even
/// when handled.
fn sysTimer(g: *Game, m: Msg) i32 {
    const id = m.wparam;
    if (hasPanel(g) and timerIs(g, panelOf(g), id)) {
        const panel = panelOf(g);
        animation.tick(g, panel, bdOf(g));
        if (hasPlayer(g) and position.hitboxOverlaps(g, panel, playerOf(g))) {
            const p = playerOf(g);
            render.draw(g, p, bdOf(g));
            // The hdc word is uninitialised here; the flag is 0.
            visibility.redrawOverlapping(g, p, bdOf(g), 0);
        }
        render.draw(g, panel, bdOf(g));
        flushUpdates(g, bdOf(g));
        return 0;
    }
    if (hasPlayer(g) and timerIs(g, playerOf(g), id)) {
        const p = playerOf(g);
        if (movement.isMoving(g, p)) {
            movement.moveTick(g, p, bdOf(g));
        } else {
            animation.tick(g, p, bdOf(g));
        }
    } else if (g.selectedItem) |item| {
        if (timerIs(g, item, id)) {
            movement.moveTick(g, item, bdOf(g));
            if (!movement.isMoving(g, item)) {
                _ = space3d.setElevation(g, item, bdOf(g), @bitCast(g.dropElevation));
                g.selectedItem = null;
            }
        }
    }
    redrawAndFlush(g);
    return 0;
}

/// The mouse at the screen's bottom edge opens the panel, away from it
/// closes it. 1 when handled (0 only without a panel).
fn mouseMove(g: *Game, m: Msg) i32 {
    if (!hasPanel(g)) return 0;
    const panel = panelOf(g);
    const y = m.hi();
    if (y > 0x1b8) {
        if (panels.isOpen(g, panel)) return 1;
        if (animation.isRunning(g, panel)) return 1;
        if (hasStatusBar(g)) render.erase(g, must(Object, g.statusBar), bdOf(g));
        panels.slide(g, panel, bdOf(g), 4);
    } else {
        if (y >= 0x154) return 1;
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
    movement.moveTo(g, playerOf(g), @bitCast(m.lo()), @bitCast(m.hi()), bdOf(g));
    return 1;
}

/// Right button: pick an item out of the panel, else act on the object under the pointer. Always 0.
fn rightDown(g: *Game, m: Msg) i32 {
    const bd0 = bdOf(g);
    const x = scrolled(m.lo(), bd0.originX);
    const y = scrolled(m.hi(), bd0.originY);
    if (hasPanel(g) and panels.contains(g, panelOf(g), x, y)) {
        // asDirectionalPlayer() is null: the list is DGROUP:0x40 (empty).
        g.selectedItem = panels.getInventoryItemAt(g, panelOf(g), null, x, y);
        if (g.selectedItem != null) {
            g.itemSelected = 1;
            return 0;
        }
    }
    const bd = bdOf(g);
    const q = backdrop_unit.queryRect(g, bd, scrolled(m.lo(), bd.originX), scrolled(m.hi(), bd.originY), 16, 16);
    if (q.result <= 0) return 0;
    const hit = q.obj orelse return 0;
    if (hit.is(.exit)) {
        if (hasPlayer(g)) {
            const p = playerOf(g);
            const d: i16 = ((half(position.hitW(p)) +% position.hitX(p)) -% half(position.hitW(hit)) -% position.hitX(hit)) +% p.x -% hit.x;
            if (abs16(d) >= half(position.hitW(p) *% 3)) return 0;
        }
        if (!position.isEnabled(g, hit)) return 0;
        animation.play(g, hit, bdOf(g));
        g.exitPending = 1;
        return 0;
    }
    if (hit.is(.portable)) {
        // The player's inventory is DGROUP:0x40, which in TIRO holds string
        // data, not a list: the original's full-test reads garbage.
        if (playerOf(g).as(.directional_player) == null) @panic("tiro.game_input: reached, but the original reads DGROUP:0x40 as the inventory list");
        const item = hit.as(.portable) orelse @panic("tiro.game_input: null pointer");
        _ = pickUp(g, item, playerOf(g));
        render.resetRects(item);
        visibility.hideAndInvalidate(g, item, 0, bdOf(g));
        visibility.redrawOverlapping(g, item, bdOf(g), 0);
        render.slot1F(g, panelOf(g), bdOf(g));
        return 0;
    }
    if (hit.is(.animation)) {
        const a = hit.as(.animation) orelse return 0;
        animation.playOnce(g, a, bdOf(g));
    }
    return 0;
}

/// Right button released: drop the carried item.
fn rightUp(g: *Game, m: Msg) i32 {
    if (g.itemSelected == 0) return 1;
    g.itemSelected = 0;
    const bd0 = bdOf(g);
    const x = scrolled(m.lo(), bd0.originX);
    const y = scrolled(m.hi(), bd0.originY);
    const panel = panelOf(g);
    if (!panels.isOutside(g, panel, x, y)) return 1;
    const item = must(Object, g.selectedItem);
    _ = drop(g, item, sceneOf(g));
    render.erase(g, panel, bdOf(g));
    visibility.redrawOverlapping(g, panel, bdOf(g), 1);
    const w0 = position.width(item);
    const h0 = position.height(item);
    space3d.moveToAndDrop(g, item, x -% half(w0), y -% half(h0), bdOf(g));
    const support = space3d.findSupport(g, item, bdOf(g)).support;
    visibility.show(g, item, bdOf(g));
    const x2 = x -% (half(position.width(item)) +% bdOf(g).originX);
    g.dropElevation = 0;
    if (support) |hit| {
        if (position.hitboxOverlaps(g, item, hit)) {
            g.selectedItem = null;
        } else {
            const bd = bdOf(g);
            const top = space3d.getWorldElev(g, hit) +% space3d.getSizeH(g, hit);
            const p1 = space3d.projectPoint(g, bd, space3d.getWorldX(g, hit), space3d.getWorldDepth(g, hit), top);
            const p2 = space3d.projectPoint(g, bd, space3d.getWorldX(g, hit), space3d.getWorldDepth(g, hit) +% space3d.getSizeD(g, hit), top);
            const y2 = half(p1.y +% p2.y) +% half(position.height(item));
            movement.moveTo(g, item, x2, y2, bd);
            g.dropElevation = @bitCast(space3d.getSizeH(g, hit));
        }
    } else {
        movement.moveTo(g, item, x2, bdOf(g).viewHeight -% 100, bdOf(g));
    }
    render.draw(g, panel, bdOf(g));
    visibility.invalidate(g, panel);
    visibility.invalidate(g, item);
    return 1;
}

/// 0x402: the exit animation finished.
fn exitFinished(g: *Game, m: Msg) i32 {
    if (g.exitPending == 0) return 0;
    g.exitPending = 0;
    lists.updateDiscard(&g.updateList);
    _ = game_unit.takeExit(g, @bitCast(m.wparam));
    return 1;
}

/// The owner's inventory (`owner + 0x40`): no DirectionalPlayer is ever constructed.
fn inventoryOf(owner: *Object) *ObjectList {
    _ = owner;
    @panic("tiro.game_input: DirectionalPlayer inventory (never constructed)");
}

/// Portable pickUp(owner): moves the item into the owner's inventory, off the draw list.
// @orig 1018:1ede portable_pick_up
pub fn pickUp(g: *Game, this: *Object, owner: *Object) *Object {
    const cur = this.portable.owner;
    if (cur == null) {
        _ = lists.remove(&g.globalObjects, this);
        this.portable.owner = owner;
        this.portable.prevSceneName[0] = 0;
        _ = lists.add(inventoryOf(owner), this);
    } else if (cur.? != owner) {
        _ = lists.remove(inventoryOf(cur.?), this);
        this.portable.owner = owner;
        _ = lists.add(inventoryOf(owner), this);
    }
    lists.drawRemove(&g.drawList, this);
    return this;
}

/// Portable drop(scene): back to the global list, scene name copied, into the draw list.
// @orig 1018:2006 portable_drop
pub fn drop(g: *Game, this: *Object, scene: *Scene) *Object {
    if (this.portable.owner) |o| {
        _ = lists.remove(inventoryOf(o), this);
        this.portable.owner = null;
        strncpy19(this, scene);
        _ = lists.add(&g.globalObjects, this);
    } else {
        strncpy19(this, scene);
        lists.drawRemove(&g.drawList, this);
    }
    _ = lists.drawInsert(g, must(Backdrop, scene.backdrop), this);
    return this;
}

/// strncpy(prevSceneName, scene.name, 19) (the +0x47 terminator byte has no field).
fn strncpy19(this: *Object, scene: *Scene) void {
    const dst = &this.portable.prevSceneName;
    var end = false;
    for (dst, 0..) |*d, i| {
        if (!end and scene.name[i] == 0) end = true;
        d.* = if (end) 0 else scene.name[i];
    }
}
