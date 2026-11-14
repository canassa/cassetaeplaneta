//! Port unit `visibility` (behaviour) of INFERNO.EXE. SceneObject slots 1B-21
//! (redraw, hideAndInvalidate, blitToDc, invalidate, slot24, hide, show) and
//! 4D redrawOverlapping.
//!
//! Every INFERNO object is an Actor2D (Mover), so each dispatcher calls the
//! Actor2D/Mover implementation directly. The `hdc` parameters are dropped.

const Game = @import("../core/game.zig").Game;
const object = @import("../core/object.zig");
const Object = object.Object;
const world = @import("../core/world.zig");
const Backdrop = world.Backdrop;
const lists = @import("../lists.zig");
const occupancy = @import("occupancy.zig");
const position = @import("position.zig");
const render = @import("render.zig");

/// SceneObject slot 1B redraw: actor2d_redraw (every kind).
pub fn redraw(g: *Game, obj: *Object, bd: *Backdrop) void {
    actor2dRedraw(g, obj, bd);
}

// @orig 1080:227e scene_object_redraw
fn sceneObjectRedraw(g: *Game, obj: *Object, bd: *Backdrop) void {
    render.erase(g, obj, bd);
    _ = occupancy.occupy(g, obj, bd);
    render.draw(g, obj, bd);
}

// @orig 1080:3084 actor2d_redraw
fn actor2dRedraw(g: *Game, obj: *Object, bd: *Backdrop) void {
    sceneObjectRedraw(g, obj, bd);
}

/// SceneObject slot 1C hideAndInvalidate.
pub fn hideAndInvalidate(g: *Game, obj: *Object, unused: u16, bd: *Backdrop) void {
    _ = unused;
    sceneObjectHideAndInvalidate(g, obj, bd);
}

// @orig 1080:22d8 scene_object_hide_and_invalidate
fn sceneObjectHideAndInvalidate(g: *Game, obj: *Object, bd: *Backdrop) void {
    hide(g, obj, bd);
    invalidate(g, obj);
}

/// SceneObject slot 1D blitToDc (hdc dropped): actor2d_blit_to_dc (every kind).
pub fn blitToDc(g: *Game, obj: *Object, bd: *Backdrop) void {
    actor2dBlitToDc(g, obj, bd);
}

/// WinGBitBlt of the object's strip rectangle at (x, y) (SelectPalette and
/// RealizePalette are the platform's).
fn blitRect(g: *Game, obj: *Object, bd: *Backdrop, x: i16, y: i16) void {
    g.plat.wingBitBlt(x -% bd.originX, y -% bd.originY, position.width(obj), position.height(obj), bd.surface(), x, y);
}

// @orig 1028:0048 scene_object_blit_to_dc
pub fn sceneObjectBlitToDc(g: *Game, obj: *Object, bd: *Backdrop) void {
    blitRect(g, obj, bd, obj.x, obj.y);
}

// @orig 1080:30bc actor2d_blit_to_dc
fn actor2dBlitToDc(g: *Game, obj: *Object, bd: *Backdrop) void {
    moverBlitToDc(g, obj, bd);
}

// @orig 1028:01ab mover_blit_to_dc
fn moverBlitToDc(g: *Game, obj: *Object, bd: *Backdrop) void {
    blitRect(g, obj, bd, obj.mover.prevX, obj.mover.prevY);
    if (obj.mover.prevX != obj.x or obj.mover.prevY != obj.y) sceneObjectBlitToDc(g, obj, bd);
}

/// SceneObject slot 1E invalidate: mover_invalidate (every kind).
pub fn invalidate(g: *Game, obj: *Object) void {
    moverInvalidate(g, obj);
}

// @orig 1028:001b scene_object_invalidate
fn sceneObjectInvalidate(g: *Game, obj: *Object) void {
    _ = lists.updateAdd(g, &g.updateList, obj);
}

// @orig 1028:014c mover_invalidate
fn moverInvalidate(g: *Game, obj: *Object) void {
    // The original's null test is a NULL object's sub-object offset; `obj`
    // is never null.
    sceneObjectInvalidate(g, obj);
}

/// SceneObject slot 1F slot24 (hdc dropped): mover_slot24 (every kind).
pub fn slot24(g: *Game, obj: *Object, bd: *Backdrop) void {
    moverSlot24(g, obj, bd);
}

// @orig 1028:00ca scene_object_slot24
fn sceneObjectSlot24(g: *Game, obj: *Object, bd: *Backdrop) void {
    blitRect(g, obj, bd, obj.x, obj.y);
}

// @orig 1028:02ab mover_slot24
fn moverSlot24(g: *Game, obj: *Object, bd: *Backdrop) void {
    blitRect(g, obj, bd, obj.mover.prevX, obj.mover.prevY);
    if (obj.mover.prevX != obj.x or obj.mover.prevY != obj.y) sceneObjectSlot24(g, obj, bd);
}

/// SceneObject slot 20 hide: mover_hide (every kind).
pub fn hide(g: *Game, obj: *Object, bd: *Backdrop) void {
    moverHide(g, obj, bd);
}

// @orig 1080:2cf2 mover_hide
fn moverHide(g: *Game, obj: *Object, bd: *Backdrop) void {
    render.restoreBackground(g, obj, bd, 1);
    _ = occupancy.vacate(g, obj, bd);
    obj.visible = 0;
    obj.mover.prevX = obj.x;
    obj.mover.prevY = obj.y;
}

/// SceneObject slot 21 show: actor2d_show (every kind). Opens with
/// scene_object_dc_hook(1), an empty call.
pub fn show(g: *Game, obj: *Object, bd: *Backdrop) void {
    actor2dShow(g, obj, bd);
}

// @orig 1080:30ec actor2d_show
fn actor2dShow(g: *Game, obj: *Object, bd: *Backdrop) void {
    moverShow(g, obj, bd);
}

// @orig 1080:2db6 mover_show
fn moverShow(g: *Game, obj: *Object, bd: *Backdrop) void {
    obj.curFrame = 0;
    render.drawDirtyTo(g, obj, &bd.bmiHeader, bd.pixels);
    _ = occupancy.occupy(g, obj, bd);
    obj.visible = 1;
    obj.mover.prevX = obj.x;
    obj.mover.prevY = obj.y;
}

/// SceneObject slot 4D redrawOverlapping (hdc dropped): scene_object_redraw_overlapping
/// (no override in INFERNO).
pub fn redrawOverlapping(g: *Game, obj: *Object, bd: *Backdrop, flag: i16) void {
    _ = flag;
    sceneObjectRedrawOverlapping(g, obj, bd);
}

// @orig 1028:17ee scene_object_redraw_overlapping
// INFERNO repaints the linked object with draw then the invalidate slot
// (like SERIAL; TIRO calls blitToDc). `flag` and `hdc` are unused.
fn sceneObjectRedrawOverlapping(g: *Game, obj: *Object, bd: *Backdrop) void {
    if (obj.linked) |l| {
        render.draw(g, l, bd);
        invalidate(g, l);
    }
}
