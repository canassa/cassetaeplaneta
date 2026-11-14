//! Port unit `occupancy` (behaviour) of INFERNO.EXE. SceneObject slots 22-26
//! (occupy, vacate, attach, canStep, isStepBlocked) and reattach.
//!
//! Virtual-slot dispatchers owned by this unit keep the signatures the
//! skeleton declared (other units already call them). INFERNO's four kinds
//! (hero, platform, prop, hazard) are all Actor2D: attach and canStep have
//! one override (actor2d_*), occupy/vacate/isStepBlocked are the base's.

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

/// SceneObject slot 22 occupy.
// @orig 1080:2340 scene_object_occupy
pub fn occupy(g: *Game, obj: *Object, bd: *Backdrop) i16 {
    return backdrop_unit.occupy(g, bd, obj);
}

/// SceneObject slot 23 vacate.
// @orig 1080:236c scene_object_vacate
pub fn vacate(g: *Game, obj: *Object, bd: *Backdrop) i16 {
    return backdrop_unit.vacate(g, bd, obj);
}

/// SceneObject slot 24 attach: actor2d_attach (every kind).
/// Returns the object (the original's null-`this` case does not exist here).
pub fn attach(g: *Game, obj: *Object, bd: *Backdrop) ?*Object {
    return actor2dAttach(g, obj, bd);
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

// @orig 1028:0c7c scene_object_attach
fn sceneObjectAttach(g: *Game, obj: *Object, bd: *Backdrop) *Object {
    if (obj.attached == 0) {
        obj.attached = 1;
        obj.unk466 = 0;
        obj.queued = 0;
        bindToBackdrop(obj, bd);
        render.resetRects(obj);
        if (obj.visible != 0) visibility.show(g, obj, bd);
        obj.id = position.nextObjectId(g);
        obj.linked = null;
    }
    return obj;
}

/// Re-binds a persistent object to the new scene's backdrop; unlike attach
/// it always runs. The `hdc` parameter is dropped (SelectPalette +
/// RealizePalette realize the backdrop's palette).
// @orig 1028:0b52 scene_object_reattach
pub fn reattach(g: *Game, obj: *Object, bd: *Backdrop) *Object {
    obj.unk466 = 0;
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

// @orig 1080:2b3e mover_attach
fn moverAttach(g: *Game, obj: *Object, bd: *Backdrop) *Object {
    _ = sceneObjectAttach(g, obj, bd);
    obj.linked = null;
    return obj;
}

// @orig 1080:3118 actor2d_attach
fn actor2dAttach(g: *Game, obj: *Object, bd: *Backdrop) *Object {
    return moverAttach(g, obj, bd);
}

/// SceneObject slot 25 canStep: actor2d_can_step (every kind).
// @orig 1080:3144 actor2d_can_step
pub fn canStep(g: *Game, obj: *Object, bd: *Backdrop) bool {
    return moverCanStep(g, obj, bd);
}

// @orig 1028:1292 mover_can_step
fn moverCanStep(g: *Game, obj: *Object, bd: *Backdrop) bool {
    const q = backdrop_unit.queryRect(g, bd, obj.hitX +% obj.nextX, obj.hitY +% obj.nextY, obj.hitW, obj.hitH);
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
        obj.linked = null;
        return true;
    }
    return false;
}

/// SceneObject slot 26 isStepBlocked.
// @orig 1080:23b2 scene_object_is_step_blocked
pub fn isStepBlocked(g: *Game, obj: *Object, bd: *Backdrop) bool {
    return !canStep(g, obj, bd);
}

test "analyze all" {
    _ = .{ &occupy, &vacate, &attach, &canStep, &isStepBlocked, &reattach };
}
