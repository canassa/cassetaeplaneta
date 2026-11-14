//! Port unit `game_hook` (module). noite_game_handle_message_hook: right button (exits, pick-up, options, closet picking).
//!
//! Game slot 01, called for every message after the scene's handler
//! declined. Only the right button (0x204) matters: over the open control
//! panel it opens the options scene (`fundini1`, remembering the current
//! scene in `g.savedPosition`) or selects an inventory item; elsewhere it
//! plays the enabled exit under the cursor, or (closet pick mode, armed by
//! the handler) records the portable item under it and switches to the
//! closet scene `3FPAPCLO`. Returns 1 when handled.

const Game = @import("core/game.zig").Game;
const Msg = @import("core/msg.zig").Msg;
const wm = @import("core/msg.zig").wm;
const world = @import("core/world.zig");
const Scene = world.Scene;
const Object = @import("core/object.zig").Object;
const Backdrop = world.Backdrop;
const cstr = @import("core/cstr.zig");
const frames = @import("frames.zig");
const panels = @import("panels.zig");
const scene_mod = @import("scene.zig");
const backdrop = @import("backdrop.zig");
const update_list = @import("update_list.zig");
const game_scenes = @import("game_scenes.zig");
const misc = @import("behaviour/misc.zig");
const tick = @import("behaviour/tick.zig");
const exit = @import("exit.zig");

/// The original's unchecked pointers: a missing one is a crash there.
fn must(comptime T: type, p: ?*T) *T {
    return p orelse @panic("game_hook: null pointer");
}

/// `x / 2` as the compiler emits it (CWD; SUB AX,DX; SAR AX,1): rounds toward zero.
fn half(x: i16) i16 {
    return @divTrunc(x, 2);
}

/// Leaves for the pick-mode scene: the update list is discarded, then
/// scene `3FPAPCLO` is built. Returns 1.
fn gotoCloset(g: *Game) i32 {
    update_list.discard(&g.updateList);
    _ = game_scenes.switchScene(g, "3FPAPCLO", 0, 0, 0, 0, 0, 0, 0);
    return 1;
}

// @orig 1018:c0fc noite_game_handle_message_hook
/// Game slot 01.
pub fn handleMessageHook(g: *Game, m: Msg) i32 {
    if (m.id != wm.rbuttondown) return 0;
    var scene = must(Scene, g.scene);
    const cx: i16 = @bitCast(m.lo());
    const cy: i16 = @bitCast(m.hi());
    var bd = must(Backdrop, scene.backdrop);
    const x = cx +% bd.originX;
    const y = cy +% bd.originY;

    if (scene_mod.getHasControlPanel(g, scene)) {
        const cp = must(Object, g.controlPanel);
        if (panels.isOpen(g, cp) and panels.contains(g, cp, x, y)) {
            if (!panels.isOnOptionsButton(g, cp, x, y)) {
                if (scene.mayDropObject != 0) {
                    const player = must(Object, g.player);
                    g.selectedItem = panels.getInventoryItemAt(g, cp, &player.actor.inventory, x, y);
                    if (g.selectedItem != null) {
                        g.itemSelected = 1;
                        if (g.fixes.drag_shows_item) g.drag.item = g.selectedItem;
                        return 0;
                    }
                    g.itemSelected = 0;
                }
            } else {
                // Remember where we are, then open the options scene.
                const sp = &g.savedPosition;
                cstr.copy(&sp.scene, cstr.slice(&scene.name));
                const player = must(Object, g.player);
                sp.playerX = player.x;
                sp.playerY = player.y;
                sp.hasPlayer = scene.hasPlayer;
                sp.hasControlPanel = scene.hasControlPanel;
                sp.hasStatusBar = scene.hasStatusBar;
                sp.is1Animation = scene.is1Animation;
                sp.isClickExit = scene.isClickExit;
                update_list.discard(&g.updateList);
                _ = game_scenes.switchScene(g, "fundini1", 0, 0, 0, 0, 0, 0, 0);
            }
        }
    }

    // The scene may have been replaced above (options): ask the new one.
    scene = must(Scene, g.scene);
    bd = must(Backdrop, scene.backdrop);
    const q = backdrop.queryRect(g, bd, cx +% bd.originX, cy +% bd.originY, 16, 16);
    const found = if (q.result > 0) q.obj else null;
    const obj = found orelse {
        if (g.pickArmed == 0) return 0;
        g.pickArmed = 0;
        g.pickActive = 1;
        return gotoCloset(g);
    };

    misc.slot00(g, obj);
    if (obj.is(.exit)) {
        var near = true;
        if (scene_mod.getHasPlayer(g, scene)) {
            const p = must(Object, g.player);
            var d: i16 = p.x -% obj.x -% half(frames.hitW(obj));
            d +%= half(frames.hitW(p));
            d -%= frames.hitX(obj);
            d +%= frames.hitX(p);
            const dist: i16 = if (d < 0) 0 -% d else d;
            near = dist < half(frames.hitW(p) *% 3);
        }
        if (near and exit.isEnabled(g, obj)) {
            if (g.pickActive != 0) {
                g.pickActive = 0;
                g.pickArmed = 1;
            }
            tick.play(g, obj, must(Backdrop, scene.backdrop));
            g.exitPending = 1;
        }
        return 1;
    }

    if (obj.is(.portable) and g.pickArmed != 0) {
        // Unchecked in the original: a 4th pick overwrites the pick flags
        // (BUGS.md L8; 3fpapclo opens only through B38 or `pope_closet_reachable`).
        if (g.pickedCount >= g.pickedItems.len) @panic("game_hook: 4th closet pick overruns pickedItems (BUGS.md L8)");
        const slot = &g.pickedItems[g.pickedCount];
        slot.object = obj;
        slot.x = obj.x;
        slot.y = obj.y;
        g.pickAdded = 1;
        g.pickArmed = 0;
        g.pickActive = 1;
        g.pickedCount +%= 1;
        return gotoCloset(g);
    }
    if (g.pickArmed == 0) return 0;
    g.pickArmed = 0;
    g.pickActive = 1;
    return gotoCloset(g);
}
