//! The one-button control mode: the whole game with the left button (or a
//! touch screen) alone. Not in the original and not a fix: a front-end
//! option (`--one-button`, the web page's "Controle com um botão"). Off,
//! nothing here runs and the input reaches the game unchanged.
//!
//! `enable` installs `filter`, which sees every queued message before the
//! window procedure (`Game.dispatchPending`) and turns a left press into
//! what the original's right button would have done, as messages to the
//! window procedure (`Game.dispatch`), so scene handlers see a real right
//! click:
//!
//! - On the open control panel: the right button there (Opções, or the
//!   inventory item under it). An item released on its own slot stays
//!   selected (tap) and the next click drops or offers it where it lands
//!   (or, on the panel, puts it back); released anywhere else it is
//!   dropped or offered there (drag). The bottom strip that slides the
//!   panel open does not walk.
//! - In a scene with the player: a click on something a right click acts on
//!   (`target`) is a right click on it; an exit out of reach is walked to
//!   first (a left click beside it, horizontally), and right-clicked when
//!   the walk ends (0x404). Anything else is the left click: a walk.
//! - In a scene without the player: the right button, except in the menus
//!   (`left_scenes`), click-to-continue scenes and one-animation scenes,
//!   which take the left one.
//!
//! A new press, a key, a right press or a scene start cancels a pending
//! walk-then-act.

const std = @import("std");
const core_game = @import("core/game.zig");
const Game = core_game.Game;
const object = @import("core/object.zig");
const Object = object.Object;
const ObjectList = object.ObjectList;
const world = @import("core/world.zig");
const Backdrop = world.Backdrop;
const Scene = world.Scene;
const cstr = @import("core/cstr.zig");
const msg = @import("core/msg.zig");
const Msg = msg.Msg;
const wm = msg.wm;
const noite = msg.noite;
const platform = @import("platform/platform.zig");
const scene_mod = @import("scene.zig");
const backdrop = @import("backdrop.zig");
const panels = @import("panels.zig");
const frames = @import("frames.zig");
const game_input = @import("game_input.zig");
const movement = @import("behaviour/movement.zig");

/// Turns the mode on (before the first message is dispatched).
pub fn enable(g: *Game) void {
    g.oneButton = .{ .filter = filter };
}

/// Scenes without the player whose handlers take the left button as a
/// press (they treat both buttons alike): the menus.
const left_scenes = [_][]const u8{ "fundinic", "fundini1", "salvar2" };

/// Scene objects that are neither exits, items nor animations but that the
/// scene's handler acts on when right-clicked (scenes with the player).
const handler_targets = [_]struct { []const u8, []const i16 }{
    .{ "2ftaxi", &.{0x109} }, // the taxi stand
    .{ "2fpontoc", &.{ 1, 2 } }, // the bus stop, the car stop
    .{ "4finifes", &.{0x113} }, // the hint sign
};

/// A tall object that is not an exit (a character, the corridor's
/// invisible bathroom-door hotspot) counts for its upper two thirds: its
/// bottom is where it meets the floor.
const tall = 150;

fn filter(g: *Game, m: Msg) bool {
    const ob = &g.oneButton;
    switch (m.id) {
        wm.lbuttondown => {
            ob.pending = null;
            return leftDown(g, m);
        },
        wm.lbuttonup => return leftUp(g, m),
        wm.rbuttondown, wm.keydown, noite.scene_started => ob.pending = null,
        noite.movement_finished => return arrived(g, m),
        else => {},
    }
    return false;
}

/// The scene can take a click now (the window procedure would act on it).
fn current(g: *Game) ?*Scene {
    if (g.appInitialized == 0 or g.inputLocked != 0) return null;
    const scene = g.scene orelse return null;
    if (scene.backdrop == null) return null;
    return scene;
}

fn nameIs(scene: *Scene, name: []const u8) bool {
    return std.ascii.eqlIgnoreCase(std.mem.trim(u8, cstr.slice(&scene.name), " "), name);
}

fn send(g: *Game, id: u16, x: u16, y: u16) void {
    const buttons: u16 = switch (id) {
        wm.lbuttondown => msg.mk.lbutton,
        wm.rbuttondown => msg.mk.rbutton,
        else => 0,
    };
    g.dispatch(Msg.make(id, buttons, x, y));
}

fn leftDown(g: *Game, m: Msg) bool {
    const ob = &g.oneButton;
    ob.press = .none;
    const scene = current(g) orelse return false;
    const bd = scene.backdrop.?;
    const sx = @as(i16, @bitCast(m.lo())) +% bd.originX;
    const sy = @as(i16, @bitCast(m.hi())) +% bd.originY;

    // An item selected by a tap: this click drops or offers it.
    if (ob.held) {
        ob.held = false;
        if (g.itemSelected != 0) {
            send(g, wm.rbuttonup, m.lo(), m.hi());
            ob.press = .swallow;
            return true;
        }
    }

    if (scene_mod.getHasControlPanel(g, scene)) {
        if (g.controlPanel) |panel| {
            if (panels.isOpen(g, panel) and panels.contains(g, panel, sx, sy)) {
                send(g, wm.rbuttondown, m.lo(), m.hi());
                if (g.scene != scene) {
                    ob.press = .swallow; // Opções
                } else if (g.itemSelected != 0 and g.selectedItem != null) {
                    g.drag.item = g.selectedItem;
                    ob.press = .slot;
                } else {
                    ob.press = .right;
                }
                return true;
            }
            // The move there slides the panel open: no walk to the edge.
            if (m.hi() > 0x1b8) {
                ob.press = .swallow;
                return true;
            }
        }
    }

    if (scene.isClickExit != 0 or scene.is1Animation != 0) return false;
    if (!scene_mod.getHasPlayer(g, scene)) {
        for (left_scenes) |name| if (nameIs(scene, name)) return false;
        send(g, wm.rbuttondown, m.lo(), m.hi());
        ob.press = .right;
        return true;
    }

    const t = target(g, scene, bd, sx, sy) orelse return false; // a walk
    ob.press = .swallow;
    const player = g.player orelse return false;
    if (t.is(.exit) and !game_input.exitInReach(g, t)) {
        const a = approach(bd, player, t);
        send(g, wm.lbuttondown, a.x, a.y);
        send(g, wm.lbuttonup, a.x, a.y);
        if (g.scene != scene) return true;
        if (movement.isMoving(g, player)) {
            ob.pending = .{ .scene = scene, .target = t, .x = sx, .y = sy };
            return true;
        }
    }
    act(g, t, sx, sy);
    return true;
}

fn leftUp(g: *Game, m: Msg) bool {
    const ob = &g.oneButton;
    const press = ob.press;
    ob.press = .none;
    switch (press) {
        .none => return false,
        .swallow => return true,
        .right => {},
        .slot => {
            if (g.itemSelected == 0) return true;
            // Released on the slot it was taken from: a tap, it stays
            // selected for the next click.
            if (onSlotOf(g, m, g.selectedItem)) {
                ob.held = true;
                return true;
            }
        },
    }
    send(g, wm.rbuttonup, m.lo(), m.hi());
    return true;
}

/// Whether (client) point `m` is on the open panel's slot holding `item`.
fn onSlotOf(g: *Game, m: Msg, item: ?*Object) bool {
    const scene = g.scene orelse return false;
    const bd = scene.backdrop orelse return false;
    if (!scene_mod.getHasControlPanel(g, scene)) return false;
    const panel = g.controlPanel orelse return false;
    const player = g.player orelse return false;
    const sx = @as(i16, @bitCast(m.lo())) +% bd.originX;
    const sy = @as(i16, @bitCast(m.hi())) +% bd.originY;
    if (!panels.isOpen(g, panel) or !panels.contains(g, panel, sx, sy)) return false;
    return item != null and panels.getInventoryItemAt(g, panel, &player.actor.inventory, sx, sy) == item;
}

/// 0x404: the player's walk to a pending target ended.
fn arrived(g: *Game, m: Msg) bool {
    const ob = &g.oneButton;
    const pend = ob.pending orelse return false;
    const player = g.player orelse return false;
    if (m.wparam != @as(u16, @bitCast(player.id))) return false;
    ob.pending = null;
    g.dispatch(m);
    const scene = current(g) orelse return true;
    if (scene == pend.scene) act(g, pend.target, pend.x, pend.y);
    return true;
}

const Box = struct {
    x: i16,
    y: i16,
    w: i16,
    h: i16,
};

/// The object's hit box in backdrop coordinates (its picture when it has
/// no hit box).
fn hitBox(obj: *Object) Box {
    const w = frames.hitW(obj);
    const h = frames.hitH(obj);
    if (w <= 0 or h <= 0) return .{ .x = obj.x, .y = obj.y, .w = frames.width(obj), .h = frames.height(obj) };
    return .{ .x = obj.x +% frames.hitX(obj), .y = obj.y +% frames.hitY(obj), .w = w, .h = h };
}

/// What a click at backdrop point (sx, sy) of a scene with the player is
/// for, when a right click there does something: an exit, an item, an
/// animation, or an object the scene's handler acts on (`handler_targets`).
/// Null: the floor (or scenery), the left click walks there.
///
/// The original's right click probes a 16x16 rectangle right of and below
/// the point, on a grid of 16-pixel cells that keeps one object per cell,
/// so it finds objects up to 31 pixels right of or below the point and
/// cells overhang the objects' right and bottom edges. Here an item counts
/// anywhere in that probe, anything else only when the point is not right
/// of or below it (`counts`): the floor just under a door still walks.
/// When the probe finds an object that does not count, the point is for
/// the smallest one it is on (and that a probe nearby finds: the right
/// click goes there, `aim`), e.g. the corridor's right edge exit where the
/// bathroom door's cells overlap it.
fn target(g: *Game, scene: *Scene, bd: *Backdrop, sx: i16, sy: i16) ?*Object {
    const q = backdrop.queryRect(g, bd, sx, sy, 16, 16);
    if (q.result <= 0) return null;
    if (q.obj) |o| if (o.kind == .portable or counts(scene, o, sx, sy, false)) return o;
    var best: ?*Object = null;
    var best_area: i32 = std.math.maxInt(i32);
    const lists = [2]?*ObjectList{ bd.sceneList, &g.globalObjects };
    for (lists) |list| {
        var cur: ?*Object = if (list) |l| l.head else null;
        while (cur) |o| : (cur = o.next) {
            if (!counts(scene, o, sx, sy, true)) continue;
            const box = hitBox(o);
            const area = @as(i32, box.w) * box.h;
            if (area >= best_area or aim(g, bd, o, sx, sy) == null) continue;
            best = o;
            best_area = area;
        }
    }
    return best;
}

/// Whether a click at (sx, sy) is for `obj` (`target`): on it, or (not
/// `on`) left of or above it, where the probe finds it.
fn counts(scene: *Scene, obj: *Object, sx: i16, sy: i16, on: bool) bool {
    if (obj.visible == 0) return false;
    switch (obj.kind) {
        .exit, .animated, .portable => {},
        .local, .moveable, .actor => if (!handlerTarget(scene, obj)) return false,
        .player, .control_panel, .status_bar => return false,
    }
    const box = hitBox(obj);
    if (sx >= box.x +% box.w or sy >= box.y +% box.h) return false;
    if (on and (sx < box.x or sy < box.y)) return false;
    // A tall hotspot (not a door: those are exits) meets the floor at its
    // bottom: only its upper two thirds count.
    return obj.kind == .exit or box.h < tall or sy -% box.y <= @divTrunc(box.h *% 2, 3);
}

fn handlerTarget(scene: *Scene, obj: *Object) bool {
    for (handler_targets) |entry| {
        if (!nameIs(scene, entry[0])) continue;
        for (entry[1]) |id| if (obj.id == id) return true;
    }
    return false;
}

const Point = struct { x: u16, y: u16 };

fn clientPoint(x: i16, y: i16) Point {
    return .{
        .x = @intCast(std.math.clamp(x, 0, platform.client_width - 1)),
        .y = @intCast(std.math.clamp(y, 0, platform.client_height - 1)),
    };
}

/// Where a left click walks the player (horizontally, on the row it
/// stands on) so that its hit box's centre is on the exit's, which is
/// within `game_input.exitInReach`.
fn approach(bd: *Backdrop, player: *Object, t: *Object) Point {
    const box = hitBox(t);
    const centre = box.x +% @divTrunc(box.w, 2);
    const px = centre -% frames.hitX(player) -% @divTrunc(frames.hitW(player), 2);
    // movement.moveTo puts the sprite's bottom centre on the point.
    return clientPoint(px +% @divTrunc(frames.width(player), 2) -% bd.originX, player.y +% frames.height(player) -% bd.originY);
}

/// A right click on `t`, where the original's probe finds it (`aim`).
fn act(g: *Game, t: *Object, sx: i16, sy: i16) void {
    const scene = g.scene.?;
    const bd = scene.backdrop.?;
    const at = aim(g, bd, t, sx, sy) orelse Point2{ .x = sx, .y = sy };
    const p = clientPoint(at.x -% bd.originX, at.y -% bd.originY);
    send(g, wm.mousemove, p.x, p.y);
    send(g, wm.rbuttondown, p.x, p.y);
    if (g.scene == scene) send(g, wm.rbuttonup, p.x, p.y);
}

const Point2 = struct { x: i16, y: i16 };

/// Backdrop point (sx, sy) if the original's right-click probe there finds
/// `t`, else the first point of `t`'s hit box (top rows first) where it
/// does, as the player could have clicked it; null if none.
fn aim(g: *Game, bd: *Backdrop, t: *Object, sx: i16, sy: i16) ?Point2 {
    if (probeFinds(g, bd, t, sx, sy)) return .{ .x = sx, .y = sy };
    const box = hitBox(t);
    var y = box.y;
    while (y < box.y +% box.h) : (y +%= 8) {
        var x = box.x;
        while (x < box.x +% box.w) : (x +%= 8) {
            if (probeFinds(g, bd, t, x, y)) return .{ .x = x, .y = y };
        }
    }
    return null;
}

fn probeFinds(g: *Game, bd: *Backdrop, t: *Object, x: i16, y: i16) bool {
    const q = backdrop.queryRect(g, bd, x, y, 16, 16);
    return q.result > 0 and q.obj == t;
}
