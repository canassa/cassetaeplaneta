//! Port unit `occupancy` (behaviour) of SAUNA.EXE. SceneObject slots 28-2C (occupy, vacate, attach, canStep, isStepBlocked) incl. Pacman's and the Ghosts' own occupy/vacate/canStep: the meetings (BUGS.md P1, P2).
//!
//! Virtual-slot dispatchers owned by this unit keep the signatures the
//! skeleton declared (other units already call them). Each switches on
//! `obj.kind` and calls one function per original implementation.
//! Pacman's and the Ghosts' occupy/vacate/canStep are the same code at
//! different offsets: one body serves both tags.

const std = @import("std");
const platform = @import("../../platform/platform.zig");
const backdrop_unit = @import("../backdrop.zig");
const ghost = @import("../ghost.zig");
const score = @import("../score.zig");
const position = @import("position.zig");
const render = @import("render.zig");
const visibility = @import("visibility.zig");
const Game = @import("../core/game.zig").Game;
const object = @import("../core/object.zig");
const Object = object.Object;
const world = @import("../core/world.zig");
const Backdrop = world.Backdrop;
const OccupancyGrid = world.OccupancyGrid;

/// What the empty occupy/vacate overrides leave in AX; callers ignore it.
const empty_result: i16 = 0;

const cell_total = world.grid_rows * world.grid_cols;

/// The ghosts' home, where an eaten ghost goes.
const home_x: i16 = 300;
const home_y: i16 = 230;

/// x86 `SAR r16, CL`: the count is masked to 5 bits, 16+ gives the sign.
fn sar(v: i16, shift: i16) i16 {
    const s: u5 = @intCast(@as(u16, @bitCast(shift)) & 0x1f);
    if (s > 15) return if (v < 0) -1 else 0;
    return v >> @intCast(s);
}

/// The cells' flat index, `row * 81 + col` in 16 bits (the original's
/// `row * 0x144 + col * 4`); null outside the matrix.
fn cellIndex(row: i16, col: i16) ?usize {
    const v: i16 = row *% 81 +% col;
    const idx: usize = @as(u16, @bitCast(v));
    return if (idx < cell_total) idx else null;
}

fn flatCount(g: *Game) *[cell_total]i8 {
    return @ptrCast(&g.occupancy.count);
}

fn flatObject(g: *Game) *[cell_total]?*Object {
    return @ptrCast(&g.occupancy.object);
}

/// The cell range under the actor's hit box at its position, as the
/// original's loops bound it (both ends inclusive).
const Span = struct { r0: i16, r1: i16, c0: i16, c1: i16 };

fn hitSpan(grid: *const OccupancyGrid, so: *Object) Span {
    return .{
        .r0 = sar(position.hitY(so) +% so.y, grid.rowShift),
        .c0 = sar(position.hitX(so) +% so.x, grid.colShift),
        .r1 = sar(position.hitH(so) +% position.hitY(so) +% so.y, grid.rowShift),
        .c1 = sar(position.hitW(so) +% position.hitX(so) +% so.x, grid.colShift),
    };
}

/// SceneObject slot 28 occupy: ControlPanel's (empty) / Pacman's, Ghost's / SceneObject's.
pub fn occupy(g: *Game, obj: *Object, bd: *Backdrop) i16 {
    return switch (obj.kind) {
        // @orig 10a0:3356 control_panel_occupy
        .control_panel => empty_result,
        // @orig 1080:0000 pacman_occupy
        // @orig 1080:13be ghost_occupy
        .pacman, .ghost => actorOccupy(g, obj, bd),
        .dot => sceneObjectOccupy(g, obj, bd),
    };
}

/// Marks every cell under the hit box: the object and a count of exactly 1
/// (wall cells keep -1). Nothing for a negative position.
fn actorOccupy(g: *Game, so: *Object, bd: *Backdrop) i16 {
    if (so.x >= 0 and so.y >= 0) {
        const grid = bd.grid.?;
        const s = hitSpan(grid, so);
        var row = s.r0;
        while (row <= s.r1) : (row += 1) {
            var col = s.c0;
            while (col <= s.c1) : (col += 1) {
                if (cellIndex(row, col)) |i| {
                    // P2 (sauna_vacate_own_cells): a cell held by another actor stays its.
                    const held = flatObject(g)[i];
                    if (!(g.fixes.sauna_vacate_own_cells and held != null and held.? != so)) {
                        flatObject(g)[i] = so;
                        flatCount(g)[i] = if (flatCount(g)[i] < 0) -1 else 1;
                    }
                }
                if (col == std.math.maxInt(i16)) break;
            }
            if (row == std.math.maxInt(i16)) break;
        }
    }
    return empty_result;
}

// @orig 10a0:39a8 scene_object_occupy
fn sceneObjectOccupy(g: *Game, obj: *Object, bd: *Backdrop) i16 {
    return backdrop_unit.occupy(g, bd, obj);
}

/// SceneObject slot 29 vacate: ControlPanel's (empty) / Pacman's, Ghost's / SceneObject's.
pub fn vacate(g: *Game, obj: *Object, bd: *Backdrop) i16 {
    return switch (obj.kind) {
        // @orig 10a0:336c control_panel_vacate
        .control_panel => empty_result,
        // @orig 1080:01c1 pacman_vacate
        // @orig 1080:157f ghost_vacate
        .pacman, .ghost => actorVacate(g, obj, bd),
        .dot => sceneObjectVacate(g, obj, bd),
    };
}

/// Clears every cell under the hit box: object null and count 0 (wall
/// cells keep -1), whoever owns the cell (P2).
fn actorVacate(g: *Game, so: *Object, bd: *Backdrop) i16 {
    if (so.x >= 0 and so.y >= 0) {
        const grid = bd.grid.?;
        const s = hitSpan(grid, so);
        var row = s.r0;
        while (row <= s.r1) : (row += 1) {
            var col = s.c0;
            while (col <= s.c1) : (col += 1) {
                if (cellIndex(row, col)) |i| {
                    if (!g.fixes.sauna_vacate_own_cells) {
                        flatObject(g)[i] = null;
                        flatCount(g)[i] = if (flatCount(g)[i] < 0) -1 else 0;
                    } else if (flatObject(g)[i] == so) {
                        flatObject(g)[i] = null;
                        flatCount(g)[i] = if (flatCount(g)[i] < 0) -1 else 0;
                        giveBack(g, grid, so, row, col, i);
                    }
                }
                if (col == std.math.maxInt(i16)) break;
            }
            if (row == std.math.maxInt(i16)) break;
        }
    }
    return empty_result;
}

/// P2's fix: a cell the mover left that lies under another actor's hit box
/// goes back to that actor.
fn giveBack(g: *Game, grid: *const OccupancyGrid, mover: *Object, row: i16, col: i16, idx: usize) void {
    if (flatCount(g)[idx] < 0) return;
    const others = [_]?*Object{ g.pacman, g.scene.?.ghosts[0], g.scene.?.ghosts[1], g.scene.?.ghosts[2], g.scene.?.ghosts[3] };
    for (others) |maybe| {
        const a = maybe orelse continue;
        if (a == mover or a.visible == 0 or a.x < 0 or a.y < 0) continue;
        const s = hitSpan(grid, a);
        if (row >= s.r0 and row <= s.r1 and col >= s.c0 and col <= s.c1) {
            flatObject(g)[idx] = a;
            flatCount(g)[idx] = 1;
            return;
        }
    }
}

// @orig 10a0:39d4 scene_object_vacate
fn sceneObjectVacate(g: *Game, obj: *Object, bd: *Backdrop) i16 {
    return backdrop_unit.vacate(g, bd, obj);
}

/// SceneObject slot 2A attach: ControlPanel's, Actor2D's (pacman, ghost) / SceneObject's.
/// Returns the object (the original's null-`this` case does not exist here).
pub fn attach(g: *Game, obj: *Object, bd: *Backdrop) ?*Object {
    return switch (obj.kind) {
        .pacman, .ghost => actor2dAttach(g, obj, bd),
        .control_panel => controlPanelAttach(g, obj, bd),
        .dot => sceneObjectAttach(g, obj, bd),
    };
}

/// Copies the backdrop's BITMAPINFO header (the colours and palette handle
/// have no counterpart in `Object`) and sizes it to the current strip.
fn bindToBackdrop(obj: *Object, bd: *const Backdrop) void {
    obj.bmiHeader = bd.bmiHeader;
    obj.dibFormatOk = @intFromBool(platform.wingRecommendDibFormat(&obj.bmiHeader));
    obj.bmiHeader.biWidth = position.width(obj);
    const count = position.frameCount(obj);
    // The 16-bit MUL: AX stored, high word zeroed.
    const size: u16 = @bitCast(count *% position.height(obj));
    obj.bmiHeader.biHeight = size;
}

// @orig 1020:0e52 scene_object_attach
fn sceneObjectAttach(g: *Game, obj: *Object, bd: *Backdrop) *Object {
    if (obj.attached == 0) {
        obj.attached = 1;
        obj.unk45E = 0;
        obj.queued = 0;
        bindToBackdrop(obj, bd);
        render.resetRects(obj);
        if (obj.visible != 0) visibility.show(g, obj, bd);
        obj.linked = null;
    }
    return obj;
}

/// Re-binds a persistent object to a new backdrop; unlike attach it always
/// runs. The `hdc` parameter is dropped (SelectPalette + RealizePalette
/// realize the backdrop's palette).
// @orig 1020:0d19 scene_object_reattach
pub fn reattach(g: *Game, obj: *Object, bd: *Backdrop) *Object {
    obj.unk45E = 0;
    obj.queued = 0;
    _ = g.plat.realizePalette(&bd.bmiColors);
    bindToBackdrop(obj, bd);
    obj.linked = null;
    if (obj.attached == 0) {
        obj.attached = 1;
        obj.id = position.nextObjectId(g);
    }
    render.resetRects(obj);
    return obj;
}

// @orig 1030:0000 object3d_attach
fn object3dAttach(g: *Game, obj: *Object, bd: *Backdrop) *Object {
    return sceneObjectAttach(g, obj, bd);
}

// @orig 10a0:2466 mover_attach
fn moverAttach(g: *Game, obj: *Object, bd: *Backdrop) *Object {
    _ = sceneObjectAttach(g, obj, bd);
    obj.linked = null;
    return obj;
}

// @orig 10a0:2a40 actor2d_attach
fn actor2dAttach(g: *Game, obj: *Object, bd: *Backdrop) *Object {
    return moverAttach(g, obj, bd);
}

// @orig 1078:0350 control_panel_attach
fn controlPanelAttach(g: *Game, obj: *Object, bd: *Backdrop) *Object {
    _ = object3dAttach(g, obj, bd);
    // SelectObject(backdrop DC, GetStockObject(SYSTEM_FIXED_FONT)): the
    // port draws text through the platform; no counterpart.
    obj.panel.text[0] = 0;
    obj.panel.textX = 10;
    obj.panel.textColor = 0x0000ffff; // yellow (COLORREF 0x00BBGGRR)
    obj.o3d.worldX = 0;
    obj.o3d.worldDepth = 0;
    obj.o3d.worldElev = 0;
    obj.o3d.sizeW = position.width(obj);
    obj.o3d.sizeH = position.height(obj);
    obj.o3d.sizeD = 1;
    return obj;
}

/// SceneObject slot 2B canStep: Pacman's, Ghost's / default (never steps).
pub fn canStep(g: *Game, obj: *Object, bd: *Backdrop) bool {
    return switch (obj.kind) {
        // @orig 1080:0874 pacman_can_step
        .pacman => actorCanStep(g, obj, bd, false),
        // @orig 1080:20fe ghost_can_step
        .ghost => actorCanStep(g, obj, bd, true),
        // The default canStep (absorbed).
        .control_panel, .dot => false,
    };
}

/// P1's fix: the first object in the next block's cells (row-major) that is
/// the other kind and not the mover; null if none.
fn otherKindInBlock(g: *Game, bd: *Backdrop, mover: *Object, x: i16, y: i16, w: i16, h: i16, want: object.Kind) ?*Object {
    const grid = bd.grid.?;
    if (x < 0 or y < 0) return null;
    const row0 = sar(y, grid.rowShift);
    const col0 = sar(x, grid.colShift);
    const row1 = sar(h, grid.rowShift) +% row0;
    const col1 = sar(w, grid.colShift) +% col0;
    var row = row0;
    while (row <= row1) : (row += 1) {
        var col = col0;
        while (col <= col1) : (col += 1) {
            if (cellIndex(row, col)) |i| {
                if (flatObject(g)[i]) |o| {
                    if (o != mover and o.kind == want) return o;
                }
            }
            if (col == std.math.maxInt(i16)) break;
        }
        if (row == std.math.maxInt(i16)) break;
    }
    return null;
}

/// The step test of Pacman (`is_ghost` false) and of a Ghost: the hit box
/// at the next position goes to the grid query; the object of the first
/// occupied cell decides. For Pacman anything but Pacman himself is a
/// meeting, for a Ghost only Pacman is. A meeting eats the ghost (power) or
/// costs a life, and the step is refused.
fn actorCanStep(g: *Game, obj: *Object, bd: *Backdrop, is_ghost: bool) bool {
    const x = position.hitX(obj) +% obj.nextX;
    const y = position.hitY(obj) +% obj.nextY;
    const w = position.hitW(obj);
    const h = position.hitH(obj);
    const q = backdrop_unit.gridQueryRect(g, bd.grid.?, x, y, w, h);
    var hit_obj = q.obj;
    if (g.fixes.sauna_meet_any_direction) {
        hit_obj = otherKindInBlock(g, bd, obj, x, y, w, h, if (is_ghost) .pacman else .ghost);
    }
    const meets = if (is_ghost)
        hit_obj == g.pacman
    else
        hit_obj != null and hit_obj != g.pacman;
    // P6 (sauna_no_catch_while_dying): the dying Pacman is not caught again.
    if (meets and !(g.fixes.sauna_no_catch_while_dying and g.pacmanDying != 0)) {
        const target = if (is_ghost) obj else hit_obj.?;
        if (g.powerStrip == 4) {
            score.eatGhost(g, bd);
            visibility.hide(g, target, bd);
            visibility.blitToDc(g, target, bd);
            target.x = home_x;
            target.nextX = target.x;
            target.y = home_y;
            target.nextY = target.y;
            visibility.show(g, target, bd);
            visibility.invalidate(g, target);
        } else {
            score.loseLife(g, bd);
            ghost.sendGhostsHome(g, g.saunaScene.?);
            g.pacmanDying = 1;
        }
        return false;
    }
    return q.flag != -1;
}

/// SceneObject slot 2C isStepBlocked.
// @orig 10a0:3a1a scene_object_is_step_blocked
pub fn isStepBlocked(g: *Game, obj: *Object, bd: *Backdrop) bool {
    return !canStep(g, obj, bd);
}

test "analyze all" {
    _ = .{ &occupy, &vacate, &attach, &canStep, &isStepBlocked, &reattach };
}
