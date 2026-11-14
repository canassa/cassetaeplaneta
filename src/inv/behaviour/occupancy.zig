//! Port unit `occupancy` (behaviour) of INV.EXE. SceneObject slots 22-26 (occupy, vacate, attach, canStep incl. the Cannon's, the Missile's and the InvaderColumn's, isStepBlocked), reattach, and Mover placeAt (slot 00 of MoverVtbl, SaucerVtbl, MissileVtbl, InvaderVtbl).
//!
//! Virtual-slot dispatchers owned by this unit keep the signatures the
//! skeleton declared (other units already call them). Each switches on
//! `obj.kind` and calls one function per original implementation.

const platform = @import("../../platform/platform.zig");
const backdrop_unit = @import("../backdrop.zig");
const position = @import("position.zig");
const render = @import("render.zig");
const visibility = @import("visibility.zig");
const Game = @import("../core/game.zig").Game;
const object = @import("../core/object.zig");
const Object = object.Object;
const world = @import("../core/world.zig");
const Backdrop = world.Backdrop;

/// What the empty occupy/vacate overrides leave in AX; callers ignore it.
const empty_result: i16 = 0;

/// SceneObject slot 22 occupy: ControlPanel's / StatusBar's (empty) / SceneObject's.
pub fn occupy(g: *Game, obj: *Object, bd: *Backdrop) i16 {
    return switch (obj.kind) {
        // @orig 1088:2e20 control_panel_occupy
        // @orig 1088:55a0 status_bar_occupy
        .control_panel, .status_bar => empty_result,
        .cannon, .saucer, .bomb, .shot, .invader_column, .invader_explosion => sceneObjectOccupy(g, obj, bd),
    };
}

// @orig 1088:17fc scene_object_occupy
fn sceneObjectOccupy(g: *Game, obj: *Object, bd: *Backdrop) i16 {
    return backdrop_unit.occupy(g, bd, obj);
}

/// SceneObject slot 23 vacate.
pub fn vacate(g: *Game, obj: *Object, bd: *Backdrop) i16 {
    return switch (obj.kind) {
        // @orig 1088:2e3a control_panel_vacate
        // @orig 1088:55ba status_bar_vacate
        .control_panel, .status_bar => empty_result,
        .cannon, .saucer, .bomb, .shot, .invader_column, .invader_explosion => sceneObjectVacate(g, obj, bd),
    };
}

// @orig 1088:1822 scene_object_vacate
fn sceneObjectVacate(g: *Game, obj: *Object, bd: *Backdrop) i16 {
    return backdrop_unit.vacate(g, bd, obj);
}

/// SceneObject slot 24 attach: Actor2D's (cannon, saucer, bomb, shot, column, explosion), ControlPanel's, StatusBar's.
/// Returns the object (the original's null-`this` case does not exist here).
pub fn attach(g: *Game, obj: *Object, bd: *Backdrop) ?*Object {
    return switch (obj.kind) {
        .cannon, .saucer, .bomb, .shot, .invader_column, .invader_explosion => actor2dAttach(g, obj, bd),
        .control_panel => controlPanelAttach(g, obj, bd),
        .status_bar => statusBarAttach(g, obj, bd),
    };
}

/// Copies the backdrop's BITMAPINFO header (the colours and palette handle
/// have no counterpart in `Object`) and sizes it to the current strip.
fn bindToBackdrop(obj: *Object, bd: *const Backdrop) void {
    obj.bmiHeader = bd.bmiHeader;
    obj.dibFormatOk = @intFromBool(platform.wingRecommendDibFormat(&obj.bmiHeader));
    obj.bmiHeader.biWidth = position.width(obj);
    const count = position.frameCount(obj);
    // The 16-bit MUL: AX stored, high word zeroed, then a long multiply by dibFormatOk.
    const size: u16 = @bitCast(count *% position.height(obj));
    obj.bmiHeader.biHeight = obj.dibFormatOk *% @as(i32, size);
}

// @orig 1028:0899 scene_object_attach
fn sceneObjectAttach(g: *Game, obj: *Object, bd: *Backdrop) *Object {
    if (obj.attached == 0) {
        obj.attached = 1;
        obj.unk452 = 0;
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
// @orig 1028:07ca scene_object_reattach
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
    render.resetRects(obj);
    return obj;
}

// @orig 1018:0000 object3d_attach
fn object3dAttach(g: *Game, obj: *Object, bd: *Backdrop) *Object {
    return sceneObjectAttach(g, obj, bd);
}

// @orig 1088:1fb0 mover_attach
fn moverAttach(g: *Game, obj: *Object, bd: *Backdrop) *Object {
    _ = sceneObjectAttach(g, obj, bd);
    obj.linked = null;
    return obj;
}

// @orig 1088:240a actor2d_attach
fn actor2dAttach(g: *Game, obj: *Object, bd: *Backdrop) *Object {
    return moverAttach(g, obj, bd);
}

// @orig 1058:0000 status_bar_attach
fn statusBarAttach(g: *Game, obj: *Object, bd: *Backdrop) *Object {
    _ = sceneObjectAttach(g, obj, bd);
    obj.status.text[0] = 0;
    obj.status.textX = 10;
    return obj;
}

// @orig 1058:01b0 control_panel_attach
fn controlPanelAttach(g: *Game, obj: *Object, bd: *Backdrop) *Object {
    _ = object3dAttach(g, obj, bd);
    obj.panel.text[0] = 0;
    obj.panel.textX = 10;
    obj.panel.textColor = 0x0000ffff; // yellow (COLORREF 0x00BBGGRR)
    // AddFontResource(s_fontFile) (fails: not on the disc) and
    // SendMessage(0, WM_FONTCHANGE, 0, 0) (hwnd 0, goes nowhere): no effect.
    obj.panel.isOpen = 0;
    obj.panel.slideDir = 0;
    obj.panel.slideStepsLeft = 0;
    obj.o3d.worldX = 0;
    obj.o3d.worldDepth = 0;
    obj.o3d.worldElev = 0;
    obj.o3d.sizeW = position.width(obj);
    obj.o3d.sizeH = position.height(obj);
    obj.o3d.sizeD = 1;
    return obj;
}

/// SceneObject slot 25 canStep: the Cannon's, Actor2D's (saucer), the Missile's (bomb, shot), the InvaderColumn's (column, explosion) / default.
pub fn canStep(g: *Game, obj: *Object, bd: *Backdrop) bool {
    return switch (obj.kind) {
        .cannon => cannonCanStep(g, obj, bd),
        // @orig 1088:2430 actor2d_can_step
        .saucer => moverCanStep(g, obj, bd),
        .bomb, .shot => missileCanStep(g, obj, bd),
        .invader_column, .invader_explosion => invaderColumnCanStep(g, obj, bd),
        // The default canStep (absorbed): never steps.
        .control_panel, .status_bar => false,
    };
}

// @orig 1068:0837 cannon_can_step
fn cannonCanStep(g: *Game, obj: *Object, bd: *Backdrop) bool {
    if (!moverCanStep(g, obj, bd)) placeAt(g, obj, 0x26c, 0x1cc, bd);
    return true;
}

/// Sorts the blocker the last `moverCanStep` left in `linked` by the type
/// tests (slots 56..5A in this order). Returns the verdict and the class
/// character to store, null when none matched (the stored state stays).
fn classifyBlocker(blocker: *Object) struct { ok: bool, state: ?u8 } {
    if (blocker.is(.shot)) return .{ .ok = true, .state = '1' };
    if (blocker.is(.invader)) return .{ .ok = true, .state = '2' };
    if (blocker.is(.saucer)) return .{ .ok = true, .state = '3' };
    if (blocker.is(.cannon)) return .{ .ok = false, .state = '4' };
    if (blocker.is(.bomb)) return .{ .ok = true, .state = '5' };
    return .{ .ok = false, .state = null };
}

// @orig 1068:0fba missile_can_step
fn missileCanStep(g: *Game, obj: *Object, bd: *Backdrop) bool {
    if (moverCanStep(g, obj, bd)) return true;
    const blocker = obj.linked orelse return false;
    const c = classifyBlocker(blocker);
    if (c.state) |s| obj.missile.hitState = s;
    return c.ok;
}

// @orig 1068:1272 invader_column_can_step
fn invaderColumnCanStep(g: *Game, obj: *Object, bd: *Backdrop) bool {
    if (moverCanStep(g, obj, bd)) return true;
    const blocker = obj.linked orelse return false;
    const c = classifyBlocker(blocker);
    if (c.state) |s| obj.invader.hitState = s;
    return c.ok;
}

// @orig 1028:0d05 mover_can_step
fn moverCanStep(g: *Game, obj: *Object, bd: *Backdrop) bool {
    const q = backdrop_unit.queryRectFirst(g, bd, position.hitX(obj) +% obj.nextX, position.hitY(obj) +% obj.nextY, position.hitW(obj), position.hitH(obj));
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

/// SceneObject slot 26 isStepBlocked.
// @orig 1088:1864 scene_object_is_step_blocked
pub fn isStepBlocked(g: *Game, obj: *Object, bd: *Backdrop) bool {
    return !canStep(g, obj, bd);
}

/// MoverVtbl / SaucerVtbl / MissileVtbl / InvaderVtbl slot 00 placeAt
/// (mover_place_at): vacate, setPosition, restoreBackground, occupy, the DC
/// hook, draw. In `occupancy`, not `movement` as in TIRO: the canStep
/// overrides call it (docs/inv/DESIGN.md "Units").
// @orig 1028:070c mover_place_at
pub fn placeAt(g: *Game, obj: *Object, x: i16, y: i16, bd: *Backdrop) void {
    _ = vacate(g, obj, bd);
    position.setPosition(g, obj, x, y);
    render.restoreBackground(g, obj, bd, 1);
    _ = occupy(g, obj, bd);
    // scene_object_dc_hook (1028:02bc): an empty hook (render's).
    render.draw(g, obj, bd);
}

test "analyze all" {
    _ = .{ &occupy, &vacate, &attach, &canStep, &isStepBlocked, &reattach, &placeAt };
}
