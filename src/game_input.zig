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

const Game = @import("core/game.zig").Game;
const object = @import("core/object.zig");
const Object = object.Object;
const world = @import("core/world.zig");
const Backdrop = world.Backdrop;
const Scene = world.Scene;
const cstr = @import("core/cstr.zig");
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
const projection = @import("projection.zig");
const sound = @import("sound.zig");
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
        } else if (g.selectedItem) |sel| {
            if (timerIs(g, sel, id)) {
                if (movement.isMoving(g, sel)) {
                    movement.moveTick(g, sel, bdOf(g));
                } else {
                    _ = space3d.setElevation(g, sel, bdOf(g), @bitCast(g.unk001A));
                }
            }
        }
        if (hasPanel(g)) render.draw(g, must(Object, g.controlPanel), bdOf(g));
        if (hasStatusBar(g)) render.draw(g, must(Object, g.statusBar), bdOf(g));
    }
    flushUpdates(g);
    return 0;
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
    if (hasPlayer(g)) {
        const player = must(Object, g.player);
        const half_w: i16 = @divTrunc(frames.hitW(obj), 2);
        var d: i16 = player.x -% obj.x -% half_w;
        d +%= @divTrunc(frames.hitW(player), 2);
        d -%= frames.hitX(obj);
        const a: i16 = frames.hitX(player) +% d;
        const dist: i16 = if (a < 0) 0 -% a else a;
        const limit: i16 = @divTrunc(frames.hitW(player) *% 3, 2);
        if (dist >= limit) return false;
    }
    return exit_mod.isEnabled(g, obj);
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
    if (support) |sup| {
        if (!position.hitboxOverlaps(g, sel, sup)) {
            // Rest on the top of the support, halfway between its near and
            // far edge, but never below the bottom strip of the view.
            const front = projection.projectPoint(bdOf(g), space3d.getWorldX(g, sup), space3d.getWorldDepth(g, sup), space3d.getWorldElev(g, sup) +% space3d.getSizeH(g, sup));
            const back = projection.projectPoint(bdOf(g), space3d.getWorldX(g, sup), space3d.getWorldDepth(g, sup) +% space3d.getSizeD(g, sup), space3d.getWorldElev(g, sup) +% space3d.getSizeH(g, sup));
            var y: i16 = @divTrunc(frames.height(sel), 2) +% @divTrunc(front.y +% back.y, 2);
            const limit: i16 = bdOf(g).viewHeight -% 100;
            if (limit < y) y = limit;
            movement.moveTo(g, sel, sx, y, bdOf(g));
            g.unk001A = @bitCast(space3d.getSizeH(g, sup));
        }
    } else {
        movement.moveTo(g, sel, sx, bdOf(g).viewHeight -% 100, bdOf(g));
    }
    render.draw(g, panel, bdOf(g));
    _ = visibility.invalidate(g, panel);
    frames.resetRects(sel);
    render.draw(g, sel, bdOf(g));
    _ = visibility.invalidate(g, sel);
    return 1;
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
