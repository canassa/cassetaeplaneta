//! Port unit `occupancy` (behaviour) of JARDIM.EXE. SceneObject slots 27-2B (occupy, vacate, attach incl. the wall strip's, canStep, isStepBlocked) and reattach.
//!
//! Virtual-slot dispatchers owned by this unit keep the signatures the
//! skeleton declared (other units already call them). Each switches on
//! `obj.kind` and calls one function per original implementation.
//!
//! The Backdrop is the LabyrinthBackdrop, which keeps the base class's
//! default occupancy slots (occupy/vacate answer 1, queryRect answers 0):
//! the grid is linked but dead.

const platform = @import("../../platform/platform.zig");
const position = @import("position.zig");
const render = @import("render.zig");
const space3d = @import("space3d.zig");
const visibility = @import("visibility.zig");
const Game = @import("../core/game.zig").Game;
const object = @import("../core/object.zig");
const Object = object.Object;
const world = @import("../core/world.zig");
const Backdrop = world.Backdrop;

/// SceneObject slot 27 occupy: player_occupy / control_panel_occupy (empty) / SceneObject's.
pub fn occupy(g: *Game, obj: *Object, bd: *Backdrop) i16 {
    return switch (obj.kind) {
        // @orig 10c0:275e player_occupy
        // @orig 10c0:292a control_panel_occupy
        .player, .control_panel => 0,
        .scene_object, .wall_strip, .portable, .exit => sceneObjectOccupy(g, obj, bd),
    };
}

// @orig 10c0:3844 scene_object_occupy
fn sceneObjectOccupy(g: *Game, obj: *Object, bd: *Backdrop) i16 {
    _ = .{ g, obj, bd };
    // backdrop vtbl slot 05: backdrop_occupy_default (10c0:43fe, absorbed).
    return 1;
}

/// SceneObject slot 28 vacate.
pub fn vacate(g: *Game, obj: *Object, bd: *Backdrop) i16 {
    return switch (obj.kind) {
        // @orig 10c0:2774 player_vacate
        // @orig 10c0:2940 control_panel_vacate
        .player, .control_panel => 0,
        .scene_object, .wall_strip, .portable, .exit => sceneObjectVacate(g, obj, bd),
    };
}

// @orig 10c0:3870 scene_object_vacate
fn sceneObjectVacate(g: *Game, obj: *Object, bd: *Backdrop) i16 {
    _ = .{ g, obj, bd };
    // backdrop vtbl slot 06: backdrop_vacate_default (10c0:4418, absorbed).
    return 1;
}

/// SceneObject slot 29 attach: the wall strip's, Moveable's (portable, player), Object3D's (exit), ControlPanel's, SceneObject's.
/// Returns the object (the original's null-`this` case does not exist here).
pub fn attach(g: *Game, obj: *Object, bd: *Backdrop) ?*Object {
    return switch (obj.kind) {
        .scene_object => sceneObjectAttach(g, obj, bd),
        .wall_strip => wallStripAttach(g, obj, bd),
        .portable, .player => moveableAttach(g, obj, bd),
        .exit => object3dAttach(g, obj, bd),
        .control_panel => controlPanelAttach(g, obj, bd),
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

// @orig 1038:0dee scene_object_attach
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

/// Re-binds a persistent object to the new scene's backdrop; unlike attach
/// it always runs. The `hdc` parameter is dropped (SelectPalette +
/// RealizePalette realize the backdrop's palette).
// @orig 1038:0cb5 scene_object_reattach
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

// @orig 1048:0000 object3d_attach
fn object3dAttach(g: *Game, obj: *Object, bd: *Backdrop) *Object {
    return sceneObjectAttach(g, obj, bd);
}

// @orig 10c0:1ad2 mover_attach
fn moverAttach(g: *Game, obj: *Object, bd: *Backdrop) *Object {
    _ = sceneObjectAttach(g, obj, bd);
    obj.linked = null;
    return obj;
}

// @orig 1048:0063 moveable_attach
fn moveableAttach(g: *Game, obj: *Object, bd: *Backdrop) *Object {
    return moverAttach(g, obj, bd);
}

// @orig 1028:47d6 wall_strip_attach
fn wallStripAttach(g: *Game, obj: *Object, bd: *Backdrop) *Object {
    if (obj.attached == 0) {
        _ = sceneObjectAttach(g, obj, bd);
        // IDIV by the texture count (6): the height of one texture.
        obj.framesLeft = @divTrunc(position.hitH(obj), obj.textureCount);
    }
    return obj;
}

// @orig 1078:0350 control_panel_attach
fn controlPanelAttach(g: *Game, obj: *Object, bd: *Backdrop) *Object {
    _ = object3dAttach(g, obj, bd);
    // SelectObject(bd.hdc, GetStockObject(SYSTEM_FONT)): the platform's
    // text rendering always uses the system font.
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

/// SceneObject slot 2A canStep: Portable's, Moveable's (player) / default.
pub fn canStep(g: *Game, obj: *Object, bd: *Backdrop) bool {
    return switch (obj.kind) {
        // @orig 10c0:389c scene_object_can_step_default (absorbed)
        .scene_object, .wall_strip, .exit, .control_panel => false,
        .portable => portableCanStep(g, obj, bd),
        .player => moveableCanStep(g, obj, bd),
    };
}

// @orig 1048:0afe portable_can_step
fn portableCanStep(g: *Game, obj: *Object, bd: *Backdrop) bool {
    _ = .{ g, obj, bd };
    return true;
}

/// Backdrop vtbl slot 04 queryRect: backdrop_query_rect_default (10c0:43ce,
/// absorbed) answers 0, "nothing there".
fn queryRectDefault(x: i16, y: i16, w: i16, h: i16) i8 {
    _ = .{ x, y, w, h };
    return 0;
}

// @orig 1048:0b17 moveable_can_step
fn moveableCanStep(g: *Game, obj: *Object, bd: *Backdrop) bool {
    const x = position.hitX(obj) +% obj.nextX;
    const y = position.hitY(obj) +% obj.nextY;
    const result = queryRectDefault(x, y, position.hitW(obj), position.hitH(obj));
    if (result > 0) {
        // Occupied: blocked only by a visible scene or global object whose
        // 3D box overlaps (the scene's list first, then the global one).
        const heads = [2]?*Object{
            if (bd.sceneList) |l| l.head else null,
            g.globalObjects.head,
        };
        for (heads) |head| {
            var o = head;
            while (o) |other| : (o = other.next) {
                if (other.visible != 0 and space3d.overlaps3d(g, obj, other, bd)) return false;
            }
        }
    }
    return result == 0;
}

/// SceneObject slot 2B isStepBlocked.
// @orig 10c0:38b6 scene_object_is_step_blocked
pub fn isStepBlocked(g: *Game, obj: *Object, bd: *Backdrop) bool {
    return !canStep(g, obj, bd);
}

test "analyze all" {
    _ = .{ &occupy, &vacate, &attach, &canStep, &isStepBlocked, &reattach };
}
