//! Port unit `occupancy` (behaviour) of ENCAIXE.EXE. SceneObject slots 24-28 (occupy, vacate, attach, canStep, isStepBlocked) and reattach.
//!
//! Virtual-slot dispatchers owned by this unit keep the signatures the
//! skeleton declared (other units already call them). Each switches on
//! `obj.kind` and calls one function per original implementation.

const plat = @import("../../platform/platform.zig");
const backdrop_unit = @import("../backdrop.zig");
const position = @import("position.zig");
const visibility = @import("visibility.zig");
const Game = @import("../core/game.zig").Game;
const object = @import("../core/object.zig");
const Object = object.Object;
const world = @import("../core/world.zig");
const Backdrop = world.Backdrop;

/// What the do-nothing occupy/vacate overrides leave in AX: the DS selector
/// (`MOV AX,0x1018`); callers ignore it.
const ds_selector: i16 = 0x1018;

/// SceneObject slot 24 occupy: ControlPanel's / StatusBar's (empty) / SceneObject's.
pub fn occupy(g: *Game, obj: *Object, bd: *Backdrop) i16 {
    return switch (obj.kind) {
        // @orig 1008:6410 control_panel_occupy
        // @orig 1008:a656 status_bar_occupy
        .control_panel, .status_bar => ds_selector,
        .piece => sceneObjectOccupy(g, obj, bd),
    };
}

// @orig 1008:54bc scene_object_occupy
fn sceneObjectOccupy(g: *Game, obj: *Object, bd: *Backdrop) i16 {
    return backdrop_unit.occupy(g, bd, obj);
}

/// SceneObject slot 25 vacate.
pub fn vacate(g: *Game, obj: *Object, bd: *Backdrop) i16 {
    return switch (obj.kind) {
        // @orig 1008:6414 control_panel_vacate
        // @orig 1008:a65a status_bar_vacate
        .control_panel, .status_bar => ds_selector,
        .piece => sceneObjectVacate(g, obj, bd),
    };
}

// @orig 1008:54d2 scene_object_vacate
fn sceneObjectVacate(g: *Game, obj: *Object, bd: *Backdrop) i16 {
    return backdrop_unit.vacate(g, bd, obj);
}

/// SceneObject slot 26 attach: Actor2D's (piece), ControlPanel's, StatusBar's.
/// Returns the object (the original's null-`this` case does not exist here).
pub fn attach(g: *Game, obj: *Object, bd: *Backdrop) ?*Object {
    return switch (obj.kind) {
        .piece => actor2dAttach(g, obj, bd),
        .control_panel => controlPanelAttach(g, obj, bd),
        .status_bar => statusBarAttach(g, obj, bd),
    };
}

/// Copies the backdrop's BITMAPINFO header (the colours and palette handle
/// have no counterpart in `Object`) and sizes it to the current strip.
fn bindToBackdrop(obj: *Object, bd: *const Backdrop) void {
    obj.bmiHeader = bd.bmiHeader;
    obj.dibFormatOk = @intFromBool(plat.wingRecommendDibFormat(&obj.bmiHeader));
    const f = &obj.frames[@intCast(obj.curStrip)];
    obj.bmiHeader.biWidth = f.width;
    // MUL: AX stored, the high word zeroed, then IMUL by dibFormatOk.
    const size: u16 = @bitCast(f.height *% f.count);
    obj.bmiHeader.biHeight = obj.dibFormatOk *% @as(i32, size);
}

fn resetRects(obj: *Object) void {
    const f = &obj.frames[@intCast(obj.curStrip)];
    obj.dirty.left = 0;
    obj.clip.left = 0;
    obj.dirty.top = 0;
    obj.clip.top = 0;
    obj.dirty.right = f.width;
    obj.clip.right = f.width;
    obj.dirty.bottom = f.height;
    obj.clip.bottom = f.height;
}

// @orig 1008:72e0 scene_object_attach
fn sceneObjectAttach(g: *Game, obj: *Object, bd: *Backdrop) *Object {
    if (obj.attached == 0) {
        obj.attached = 1;
        obj.unk452 = 0;
        obj.queued = 0;
        bindToBackdrop(obj, bd);
        resetRects(obj);
        if (obj.visible != 0) visibility.show(g, obj, bd);
        obj.linked = null;
    }
    return obj;
}

/// Re-binds a persistent object to the new scene's backdrop; unlike attach
/// it always runs. Called by `game.takeExit`. The `hdc` parameter is dropped
/// (SelectPalette + RealizePalette realize the backdrop's palette).
// @orig 1008:71ee scene_object_reattach
pub fn reattach(g: *Game, obj: *Object, bd: *Backdrop) *Object {
    obj.unk452 = 0;
    obj.queued = 0;
    _ = g.plat.realizePalette(&bd.bmiColors);
    bindToBackdrop(obj, bd);
    obj.linked = null;
    if (obj.attached == 0) {
        obj.attached = 1;
        obj.id = position.nextObjectId(g);
    }
    resetRects(obj);
    return obj;
}

// @orig 1008:254a object3d_attach
fn object3dAttach(g: *Game, obj: *Object, bd: *Backdrop) *Object {
    return sceneObjectAttach(g, obj, bd);
}

// @orig 1008:5bde actor2d_attach
fn actor2dAttach(g: *Game, obj: *Object, bd: *Backdrop) *Object {
    _ = sceneObjectAttach(g, obj, bd);
    obj.linked = null;
    return obj;
}

// @orig 1008:b116 status_bar_attach
fn statusBarAttach(g: *Game, obj: *Object, bd: *Backdrop) *Object {
    _ = sceneObjectAttach(g, obj, bd);
    obj.status.text[0] = 0;
    obj.status.textX = 10;
    return obj;
}

// @orig 1008:b1dc control_panel_attach
fn controlPanelAttach(g: *Game, obj: *Object, bd: *Backdrop) *Object {
    _ = object3dAttach(g, obj, bd);
    obj.panel.text[0] = 0;
    obj.panel.textX = 10;
    obj.panel.textColor = 0x0000ffff; // yellow (COLORREF 0x00BBGGRR)
    // AddFontResource("arialbd.fot") (not on the disc: fails) and
    // SendMessage(0, WM_FONTCHANGE, 0, 0) (hwnd 0, goes nowhere): no effect.
    obj.panel.isOpen = 0;
    obj.panel.slideDir = 0;
    obj.panel.slideStepsLeft = 0;
    const f = &obj.frames[@intCast(obj.curStrip)];
    obj.o3d.worldX = 0;
    obj.o3d.worldDepth = 0;
    obj.o3d.worldElev = 0;
    obj.o3d.sizeW = f.width;
    obj.o3d.sizeH = f.height;
    obj.o3d.sizeD = 1;
    return obj;
}

/// SceneObject slot 27 canStep: Actor2D's (piece) / default.
pub fn canStep(g: *Game, obj: *Object, bd: *Backdrop) bool {
    return switch (obj.kind) {
        // @orig 1008:5c1c actor2d_can_step
        .piece => moverCanStep(g, obj, bd),
        // @orig 1008:54e8 scene_object_can_step_default (absorbed)
        .control_panel, .status_bar => false,
    };
}

// @orig 1008:762a mover_can_step
fn moverCanStep(g: *Game, obj: *Object, bd: *Backdrop) bool {
    const f = &obj.frames[@intCast(obj.curStrip)];
    const q = backdrop_unit.queryRectFirst(g, bd, f.hitX +% obj.nextX, f.hitY +% obj.nextY, f.hitW, f.hitH);
    obj.linked = q.obj;
    if (q.result <= 0) {
        obj.linked = null;
        return q.result == 0;
    }
    if (q.flag == -1) {
        obj.linked = null;
        return false;
    }
    const blocker = q.obj orelse return true;
    if (obj.id == blocker.id) {
        if (obj.id == q.first.?.id) {
            obj.linked = null;
            return true;
        }
        obj.linked = q.first;
    }
    return false;
}

/// SceneObject slot 28 isStepBlocked.
// @orig 1008:54ee scene_object_is_step_blocked
pub fn isStepBlocked(g: *Game, obj: *Object, bd: *Backdrop) bool {
    return !canStep(g, obj, bd);
}

test "analyze all" {
    _ = .{ &occupy, &vacate, &attach, &canStep, &isStepBlocked, &reattach };
}
