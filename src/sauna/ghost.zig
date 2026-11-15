//! Port unit `ghost` (module) of SAUNA.EXE. the ghost AI: GhostVtbl chooseDirection (rand) and isNextStepFree, SaunaSceneVtbl sendGhostsHome.
//!
//! Virtual-slot dispatchers owned by this unit are declared below with
//! their final signatures; their bodies panic until the unit is ported
//! (docs/sauna/DESIGN.md "Virtual slots"). Replace each body, keep the
//! signature (other units already call it). Each implementation function
//! carries `// @orig <seg:xxxx> <name>` with the SAUNA address.

const std = @import("std");
const backdrop_unit = @import("backdrop.zig");
const animation = @import("behaviour/animation.zig");
const movement = @import("behaviour/movement.zig");
const position = @import("behaviour/position.zig");
const visibility = @import("behaviour/visibility.zig");
const Game = @import("core/game.zig").Game;
const object = @import("core/object.zig");
const Object = object.Object;
const ObjectList = object.ObjectList;
const Frame = object.Frame;
const FrameCell = object.FrameCell;
const BitmapInfoHeader = object.BitmapInfoHeader;
const world = @import("core/world.zig");
const Backdrop = world.Backdrop;
const Scene = world.Scene;
const Condition = world.Condition;
const RectQuery = world.RectQuery;

/// The ghosts' home.
const home_x: i16 = 300;
const home_y: i16 = 230;

/// CRT `abs` (an int).
fn absI16(v: i16) i16 {
    return if (v < 0) 0 -% v else v;
}

/// GhostVtbl slot 01 chooseDirection (ghost_choose_direction; hwnd dropped): toward Pacman (away while powered) when aligned within 16 px and the next step is free, else `rand() % 4`.
// @orig 1080:1abe ghost_choose_direction
pub fn chooseDirection(g: *Game, obj: *Object, bd: *Backdrop) void {
    const pac = g.pacman.?;
    if (absI16(pac.x -% obj.x) < 0x11) {
        var dir: i16 = undefined;
        if (g.powerStrip == 0) {
            dir = if (pac.y < obj.y) 4 else 8;
        } else {
            dir = if (pac.y < obj.y) 8 else 4;
        }
        _ = animation.setStrip(g, obj, g.powerStrip +% (if (dir == 8) @as(i16, 3) else 2), bd);
        movement.moveToEdgeV(g, obj, bd, dir);
        if (isNextStepFree(g, obj, bd)) return;
    }
    if (absI16(pac.y -% obj.y) < 0x11) {
        var dir: i16 = undefined;
        if (g.powerStrip == 0) {
            dir = if (pac.x < obj.x) 1 else 2;
        } else {
            dir = if (pac.x < obj.x) 2 else 1;
        }
        _ = animation.setStrip(g, obj, g.powerStrip +% (if (dir == 2) @as(i16, 1) else 0), bd);
        movement.moveToEdgeH(g, obj, bd, dir);
        if (isNextStepFree(g, obj, bd)) return;
    }
    const r = @rem(g.rand.rand(), 4);
    const dir: i16 = @as(i16, 1) << @intCast(r);
    if (r < 2) {
        _ = animation.setStrip(g, obj, g.powerStrip +% (if (dir == 2) @as(i16, 1) else 0), bd);
        movement.moveToEdgeH(g, obj, bd, dir);
    } else {
        _ = animation.setStrip(g, obj, g.powerStrip +% (if (dir == 8) @as(i16, 3) else 2), bd);
        movement.moveToEdgeV(g, obj, bd, dir);
    }
}

/// GhostVtbl slot 02 isNextStepFree (ghost_is_next_step_free): no wall in the cells of the next step.
// @orig 1080:1958 ghost_is_next_step_free
pub fn isNextStepFree(g: *Game, obj: *Object, bd: *Backdrop) bool {
    const m = &obj.mover;
    var dx: i16 = 0;
    var dy: i16 = 0;
    if (m.errIncX == 0) {
        if (m.lineErr < 1) {
            dx = m.stepX;
            dy = m.stepY;
        } else {
            dy = m.stepY;
        }
    } else if (m.lineErr < 1) {
        dx = m.stepX;
    } else {
        dx = m.stepX;
        dy = m.stepY;
    }
    const x = position.hitX(obj) +% obj.nextX +% dx;
    const y = position.hitY(obj) +% obj.nextY +% dy;
    const w = position.hitW(obj);
    const h = position.hitH(obj);
    const q = backdrop_unit.gridQueryRect(g, bd.grid.?, x, y, w, h);
    return q.flag != -1;
}

/// SaunaSceneVtbl slot 10 sendGhostsHome (sauna_scene_send_ghosts_home): the four ghosts back to (300, 230), still walking their lines.
// @orig 1080:2404 sauna_scene_send_ghosts_home
pub fn sendGhostsHome(g: *Game, scene: *Scene) void {
    const bd = scene.backdrop.?;
    for (scene.ghosts) |gh| {
        const o = gh.?;
        visibility.hide(g, o, bd);
        visibility.blitToDc(g, o, bd);
        o.x = home_x;
        o.nextX = o.x;
        o.y = home_y;
        o.nextY = o.y;
        visibility.show(g, o, bd);
        visibility.invalidate(g, o);
    }
}

test "analyze all" {
    _ = .{ &chooseDirection, &isNextStepFree, &sendGhostsHome };
}
