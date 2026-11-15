//! Port unit `game_input` (module) of INFERNO.EXE. game_handle_message
//! (GameVtbl slot 00, 4.9 KB: the engine default under the INFERNO
//! scene's handler `hell.handleMessage`, which answers every key, timer
//! and mouse message first).
//!
//! The scene handler returns 1 for WM_ACTIVATE, the keys, the hero's and
//! the cross's timers, the mouse and a few more, so only what it declines
//! reaches the dispatch below: WM_DESTROY, 0x401, unclaimed timers and the
//! rest (all answered 0 here). The dispatch is ported whole anyway. What
//! INFERNO never builds (control panel, status bar, exits, portables) keeps
//! the original's guard and panics in its body (docs/inferno/DESIGN.md
//! "Decisions"): the 0x118 panel branch, 0x200, the panel and the exit and
//! portable arms of 0x204, the 0x205 drop (only after a 0x204 panel pick).
//!
//! Same source as TIRO's `game_input`; the build differs (large model).
//! Differences in the port: step 1 (the scene answered) falls into the
//! common tail instead of returning, and every path but the 0x401 exit
//! ends in that tail (flush of the update list, the only live part: the
//! scene has no control panel or status bar), so a declined key or a
//! missing player flushes too; 0x118 tests the player, then the panel,
//! then the carried item, and the panel branch only ticks; 0x200, 0x204
//! and 0x205 use INFERNO's ControlPanel slots (one lower) and omit the
//! draw after the slide, the inventory-full test, `resetRects` and the
//! `redrawOverlapping(1)` after the panel erase; the exit message is 0x401
//! (TIRO 0x402). There are no `hwnd`/`hdc` parameters (platform calls).

const msg = @import("../core/msg.zig");
const Msg = msg.Msg;
const Game = @import("core/game.zig").Game;
const Object = @import("core/object.zig").Object;
const world = @import("core/world.zig");
const Backdrop = world.Backdrop;
const Scene = world.Scene;
const backdrop_unit = @import("backdrop.zig");
const game_unit = @import("game.zig");
const hell = @import("hell.zig");
const lists = @import("lists.zig");
const scene_unit = @import("scene.zig");
const animation = @import("behaviour/animation.zig");
const movement = @import("behaviour/movement.zig");
const position = @import("behaviour/position.zig");

/// INFERNO's exit-finished message (TIRO's is 0x402).
const exit_finished: u16 = 0x401;

/// The original's unchecked pointers: a missing one is a crash there.
fn must(comptime T: type, p: ?*T) *T {
    return p orelse @panic("inferno.game_input: null pointer");
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

/// The common tail (1155-1329): when anything is queued, draw the panel
/// or the status bar (the scene has neither) and flush the update list.
fn tail(g: *Game) void {
    if (lists.updateIsEmpty(&g.updateList)) return;
    // The panel/status-bar draw (1155-1329).
    if (hasPanel(g)) @panic("INFERNO builds no ControlPanel");
    if (hasStatusBar(g)) @panic("INFERNO builds no StatusBar");
    lists.updateFlush(g, &g.updateList, bdOf(g));
}

/// GameVtbl slot 00 handleMessage (game_handle_message): the engine default under the scene's handler. Non-zero = handled.
// @orig 1040:0000 game_handle_message
pub fn handleMessage(g: *Game, m: Msg) i32 {
    var result: i32 = 1;
    if (hell.handleMessage(g, sceneOf(g), m) == 0) {
        result = switch (m.id) {
            msg.wm.keydown => keyDown(g, m),
            msg.wm.keyup => keyUp(g, m),
            msg.wm.systimer => sysTimer(g, m),
            msg.wm.mousemove => mouseMove(g),
            msg.wm.lbuttondown => leftDown(g, m),
            msg.wm.rbuttondown => rightDown(g, m),
            msg.wm.rbuttonup => rightUp(g),
            exit_finished => blk: {
                if (g.exitPending == 0) break :blk 0;
                g.exitPending = 0;
                lists.updateDiscard(&g.updateList);
                _ = game_unit.takeExit(g, @bitCast(m.wparam));
                return 1;
            },
            else => 0,
        };
    }
    tail(g);
    return result;
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

/// The timers: the player's walk, else the control panel's slide, else
/// the carried item's drop. Returns 0 even when handled.
fn sysTimer(g: *Game, m: Msg) i32 {
    const id = m.wparam;
    if (hasPlayer(g) and timerIs(g, playerOf(g), id)) {
        const p = playerOf(g);
        if (movement.isMoving(g, p)) {
            movement.moveTick(g, p, bdOf(g));
        } else {
            animation.tick(g, p, bdOf(g));
        }
    } else if (hasPanel(g)) {
        // 0596..: panel.getTimerId == id -> panel.tick.
        @panic("INFERNO builds no ControlPanel");
    } else if (g.selectedItem) |item| {
        if (timerIs(g, item, id)) {
            movement.moveTick(g, item, bdOf(g));
            if (!movement.isMoving(g, item)) {
                _ = position.setElevation(g, item, bdOf(g), g.dropElevation);
                g.selectedItem = null;
            }
        }
    }
    return 0;
}

/// 03cb..: the panel slides open/closed by the pointer's height; 0 without a panel.
fn mouseMove(g: *Game) i32 {
    if (!hasPanel(g)) return 0;
    @panic("INFERNO builds no ControlPanel");
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
    _ = .{ x, y };
    // The panel's contains/getInventoryItemAt (0823..).
    if (hasPanel(g)) @panic("INFERNO builds no ControlPanel");
    const bd = bdOf(g);
    const q = backdrop_unit.queryRect(g, bd, scrolled(m.lo(), bd.originX), scrolled(m.hi(), bd.originY), 16, 16);
    if (q.result <= 0) return 0;
    const hit = q.obj orelse return 0;
    if (hit.is(.exit)) @panic("INFERNO builds no Exit");
    if (hit.is(.portable)) @panic("INFERNO builds no Portable");
    if (hit.is(.animation)) {
        const a = hit.as(.animation) orelse return 0;
        animation.playOnce(g, a, bdOf(g));
    }
    return 0;
}

/// Right button released: drop the carried item (only after a panel pick).
fn rightUp(g: *Game) i32 {
    if (g.itemSelected == 0) return 1;
    g.itemSelected = 0;
    // panel.isOutside is called without the hasControlPanel test (0bec..).
    @panic("INFERNO builds no ControlPanel");
}
