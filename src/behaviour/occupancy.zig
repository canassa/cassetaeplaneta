//! Port unit `occupancy` (behaviour). SceneObject slots 27-2C: occupy, vacate, reoccupy, attach, canStep; reattach on scene change.
//!
//! Virtual-slot dispatchers owned by this unit keep the signatures the
//! skeleton declared (other units already call them).

const frames = @import("../frames.zig");
const backdrop_unit = @import("../backdrop.zig");
const space3d = @import("space3d.zig");
const visibility = @import("visibility.zig");
const Game = @import("../core/game.zig").Game;
const object = @import("../core/object.zig");
const Object = object.Object;
const world = @import("../core/world.zig");
const Backdrop = world.Backdrop;
const platform = @import("../platform/platform.zig");

/// What the do-nothing occupy/vacate overrides leave in AX: the DS selector
/// (`MOV AX,0x1050`); callers ignore it.
const ds_selector: i16 = 0x1050;

/// SceneObject slot 27: mark the object's hit box in the occupancy grid.
pub fn occupy(g: *Game, obj: *Object, bd: *Backdrop) i16 {
    return switch (obj.kind) {
        // @orig 1010:417c player_occupy
        // @orig 1010:4652 control_panel_occupy
        // @orig 1010:46d4 status_bar_occupy
        .player, .control_panel, .status_bar => ds_selector,
        else => sceneObjectOccupy(g, obj, bd),
    };
}

// @orig 1010:19e0 scene_object_occupy
fn sceneObjectOccupy(g: *Game, obj: *Object, bd: *Backdrop) i16 {
    return backdrop_unit.occupy(g, bd, obj);
}

/// SceneObject slot 28: clear the object's hit box from the occupancy grid.
pub fn vacate(g: *Game, obj: *Object, bd: *Backdrop) i16 {
    return switch (obj.kind) {
        // @orig 1010:4186 player_vacate
        // @orig 1010:465c control_panel_vacate
        // @orig 1010:46de status_bar_vacate
        .player, .control_panel, .status_bar => ds_selector,
        else => sceneObjectVacate(g, obj, bd),
    };
}

// @orig 1010:1a06 scene_object_vacate
fn sceneObjectVacate(g: *Game, obj: *Object, bd: *Backdrop) i16 {
    return backdrop_unit.vacate(g, bd, obj);
}

/// SceneObject slot 29: vacate then occupy again (both virtual).
// @orig 1010:1a2c scene_object_reoccupy
pub fn reoccupy(g: *Game, obj: *Object, bd: *Backdrop) void {
    _ = vacate(g, obj, bd);
    _ = occupy(g, obj, bd);
}

/// SceneObject slot 2A: first-time setup against a backdrop. Returns the
/// object (the original's null-`this` case does not exist here).
pub fn attach(g: *Game, obj: *Object, bd: *Backdrop) ?*Object {
    return switch (obj.kind) {
        .local, .animated, .exit => object3dAttach(g, obj, bd),
        .moveable, .actor, .player, .portable => moveableAttach(g, obj, bd),
        .control_panel => controlPanelAttach(g, obj, bd),
        .status_bar => statusBarAttach(g, obj, bd),
    };
}

/// Shared by attach and reattach: bind the object's BITMAPINFO to the
/// backdrop's and size it to the current strip. The object keeps only the
/// header (`Object` has no colour table or palette handle: the original's
/// copies are never read).
fn bindToBackdrop(obj: *Object, bd: *const Backdrop) void {
    obj.bmiHeader = bd.bmiHeader;
    obj.dibFormatOk = @intFromBool(platform.wingRecommendDibFormat(&obj.bmiHeader));
    obj.bmiHeader.biWidth = frames.width(obj);
    const count = frames.curStrip(obj).count;
    const h = frames.height(obj);
    // MUL CX: AX stored, the high word zeroed.
    obj.bmiHeader.biHeight = @as(u16, @bitCast(count *% h));
}

// @orig 1010:bb32 scene_object_attach
fn sceneObjectAttach(g: *Game, obj: *Object, bd: *Backdrop) *Object {
    if (obj.attached == 0) {
        obj.attached = 1;
        obj.unk45E = 0;
        obj.queued = 0;
        bindToBackdrop(obj, bd);
        frames.resetRects(obj);
        if (obj.visible != 0) visibility.show(g, obj, bd);
        obj.linked = null;
    }
    return obj;
}

/// Re-bind the object to a (new) backdrop on a scene change; unlike
/// `sceneObjectAttach` it always runs. The `hdc` parameter is dropped
/// (SelectPalette + RealizePalette on it realize the backdrop's palette
/// on the screen).
// @orig 1010:ba48 scene_object_reattach
pub fn reattach(g: *Game, obj: *Object, bd: *Backdrop) *Object {
    obj.unk45E = 0;
    obj.queued = 0;
    g.plat.realizePalette(&bd.bmiColors);
    bindToBackdrop(obj, bd);
    obj.linked = null;
    if (obj.attached == 0) obj.attached = 1;
    frames.resetRects(obj);
    return obj;
}

// @orig 1010:474e object3d_attach
fn object3dAttach(g: *Game, obj: *Object, bd: *Backdrop) *Object {
    return sceneObjectAttach(g, obj, bd);
}

// @orig 1010:2afe mover_attach
fn moverAttach(g: *Game, obj: *Object, bd: *Backdrop) *Object {
    _ = sceneObjectAttach(g, obj, bd);
    obj.linked = null;
    return obj;
}

// @orig 1010:47a2 moveable_attach
fn moveableAttach(g: *Game, obj: *Object, bd: *Backdrop) *Object {
    return moverAttach(g, obj, bd);
}

// @orig 1018:1e9a status_bar_attach
fn statusBarAttach(g: *Game, obj: *Object, bd: *Backdrop) *Object {
    _ = sceneObjectAttach(g, obj, bd);
    obj.status.text[0] = 0;
    obj.status.textX = 10;
    return obj;
}

// @orig 1018:1f90 control_panel_attach
fn controlPanelAttach(g: *Game, obj: *Object, bd: *Backdrop) *Object {
    _ = object3dAttach(g, obj, bd);
    // SelectObject(bd.hdc, GetStockObject(SYSTEM_FONT)): the platform's
    // text rendering always uses the system font.
    obj.panel.message[0] = 0;
    obj.panel.messageX = 10;
    obj.panel.textColor = 0x0000ffff; // yellow (COLORREF 0x00BBGGRR)
    obj.o3d.worldX = 0;
    obj.o3d.worldDepth = 0;
    obj.o3d.worldElev = 0;
    obj.o3d.sizeW = frames.width(obj);
    obj.o3d.sizeH = frames.height(obj);
    obj.o3d.sizeD = 1;
    return obj;
}

/// SceneObject slot 2B: may the mover take its next step on the grid?
pub fn canStep(g: *Game, obj: *Object, bd: *Backdrop) bool {
    return switch (obj.kind) {
        // @orig 1010:1a76 scene_object_can_step_default (absorbed)
        .local, .animated, .exit, .control_panel, .status_bar => false,
        .moveable, .actor, .player => moveableCanStep(g, obj, bd),
        .portable => portableCanStep(g, obj, bd),
    };
}

// @orig 1010:50d4 portable_can_step
fn portableCanStep(g: *Game, obj: *Object, bd: *Backdrop) bool {
    _ = .{ g, obj, bd };
    return true;
}

// @orig 1010:50e2 moveable_can_step
fn moveableCanStep(g: *Game, obj: *Object, bd: *Backdrop) bool {
    const x = frames.hitX(obj) +% obj.nextX;
    const y = frames.hitY(obj) +% obj.nextY;
    var flag: i8 = 0;
    var result: i8 = 0;
    if (obj.mover.allowOffscreen != 0 and (x < 0 or y < 0)) {
        result = 0;
    } else {
        const q = backdrop_unit.queryRect(g, bd, x, y, frames.hitW(obj), frames.hitH(obj));
        result = q.result;
        flag = q.flag;
    }
    if (result <= 0) return result == 0;
    // Occupied: blocked only by a visible scene or global object whose 3D
    // box overlaps (the scene's list first, then the game's global objects).
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
    return flag == 0;
}

/// SceneObject slot 2C: the negation of `canStep`.
// @orig 1010:1a82 scene_object_is_step_blocked
pub fn isStepBlocked(g: *Game, obj: *Object, bd: *Backdrop) bool {
    return !canStep(g, obj, bd);
}

// @orig 1010:c036 mover_can_step
// Never reached (the Mover class is never instantiated; Moveable has its own).
fn moverCanStep(g: *Game, obj: *Object, bd: *Backdrop) bool {
    const q = backdrop_unit.queryRectFirst(
        g,
        bd,
        frames.hitX(obj) +% obj.nextX,
        frames.hitY(obj) +% obj.nextY,
        frames.hitW(obj),
        frames.hitH(obj),
    );
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

comptime {
    _ = &moverCanStep;
}

test "analyze all" {
    _ = .{ &occupy, &vacate, &reoccupy, &attach, &canStep, &isStepBlocked, &reattach };
}
