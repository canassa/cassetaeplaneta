//! Port unit `visibility` (behaviour) of SAUNA.EXE. SceneObject slots 21-27 (redraw, hideAndInvalidate, blitToDc, invalidate, slot24, hide, show) and 54 redrawOverlapping.
//!
//! Virtual-slot dispatchers owned by this unit switch on `obj.kind` and call
//! one function per original implementation (docs/sauna/DESIGN.md "Virtual
//! slots"). The `hdc` parameters are dropped.

const Game = @import("../core/game.zig").Game;
const object = @import("../core/object.zig");
const Object = object.Object;
const world = @import("../core/world.zig");
const Backdrop = world.Backdrop;
const lists = @import("../lists.zig");
const occupancy = @import("occupancy.zig");
const position = @import("position.zig");
const render = @import("render.zig");
const space3d = @import("space3d.zig");

/// SceneObject slot 21 redraw: actor2d_redraw (pacman, ghost), animated3d_redraw (panel) / SceneObject's.
pub fn redraw(g: *Game, obj: *Object, bd: *Backdrop) void {
    switch (obj.kind) {
        .pacman, .ghost => actor2dRedraw(g, obj, bd),
        .control_panel => animated3dRedraw(g, obj, bd),
        .dot => sceneObjectRedraw(g, obj, bd),
    }
}

// @orig 10a0:3858 scene_object_redraw
fn sceneObjectRedraw(g: *Game, obj: *Object, bd: *Backdrop) void {
    render.erase(g, obj, bd);
    _ = occupancy.occupy(g, obj, bd);
    render.draw(g, obj, bd);
}

// @orig 10a0:29ac actor2d_redraw
fn actor2dRedraw(g: *Game, obj: *Object, bd: *Backdrop) void {
    sceneObjectRedraw(g, obj, bd);
}

// @orig 10a0:2d56 animated3d_redraw
fn animated3dRedraw(g: *Game, obj: *Object, bd: *Backdrop) void {
    sceneObjectRedraw(g, obj, bd);
}

/// SceneObject slot 22 hideAndInvalidate.
pub fn hideAndInvalidate(g: *Game, obj: *Object, unused: u16, bd: *Backdrop) void {
    _ = unused;
    sceneObjectHideAndInvalidate(g, obj, bd);
}

// @orig 10a0:38b2 scene_object_hide_and_invalidate
fn sceneObjectHideAndInvalidate(g: *Game, obj: *Object, bd: *Backdrop) void {
    hide(g, obj, bd);
    invalidate(g, obj);
}

/// SceneObject slot 23 blitToDc (hdc dropped): actor2d_blit_to_dc (pacman, ghost) / SceneObject's.
pub fn blitToDc(g: *Game, obj: *Object, bd: *Backdrop) void {
    switch (obj.kind) {
        .pacman, .ghost => actor2dBlitToDc(g, obj, bd),
        .control_panel, .dot => sceneObjectBlitToDc(g, obj, bd),
    }
}

/// WinGBitBlt of the object's strip rectangle at (x, y) (SelectPalette and
/// RealizePalette are the platform's).
fn blitRect(g: *Game, obj: *Object, bd: *Backdrop, x: i16, y: i16) void {
    g.plat.wingBitBlt(x -% bd.originX, y -% bd.originY, position.width(obj), position.height(obj), bd.surface(), x, y);
}

// @orig 1020:0048 scene_object_blit_to_dc
pub fn sceneObjectBlitToDc(g: *Game, obj: *Object, bd: *Backdrop) void {
    blitRect(g, obj, bd, obj.x, obj.y);
}

// @orig 10a0:29e4 actor2d_blit_to_dc
fn actor2dBlitToDc(g: *Game, obj: *Object, bd: *Backdrop) void {
    moverBlitToDc(g, obj, bd);
}

// @orig 1020:01ab mover_blit_to_dc
fn moverBlitToDc(g: *Game, obj: *Object, bd: *Backdrop) void {
    blitRect(g, obj, bd, obj.mover.prevX, obj.mover.prevY);
    if (obj.mover.prevX != obj.x or obj.mover.prevY != obj.y) sceneObjectBlitToDc(g, obj, bd);
}

/// SceneObject slot 24 invalidate: mover_invalidate (pacman, ghost) / SceneObject's.
pub fn invalidate(g: *Game, obj: *Object) void {
    switch (obj.kind) {
        .pacman, .ghost => moverInvalidate(g, obj),
        .control_panel, .dot => sceneObjectInvalidate(g, obj),
    }
}

// @orig 1020:001b scene_object_invalidate
fn sceneObjectInvalidate(g: *Game, obj: *Object) void {
    _ = lists.updateAdd(g, &g.updateList, obj);
}

// @orig 1020:014c mover_invalidate
fn moverInvalidate(g: *Game, obj: *Object) void {
    // The original's null test (this == s_hdcOverflow + 6) is a NULL object's
    // sub-object offset; `obj` is never null.
    _ = lists.updateAdd(g, &g.updateList, obj);
}

/// SceneObject slot 25 slot24 (hdc dropped): mover_slot24 (pacman, ghost) / SceneObject's.
pub fn slot24(g: *Game, obj: *Object, bd: *Backdrop) void {
    switch (obj.kind) {
        .pacman, .ghost => moverSlot24(g, obj, bd),
        .control_panel, .dot => sceneObjectSlot24(g, obj, bd),
    }
}

// @orig 1020:00ca scene_object_slot24
fn sceneObjectSlot24(g: *Game, obj: *Object, bd: *Backdrop) void {
    blitRect(g, obj, bd, obj.x, obj.y);
}

// @orig 1020:02ab mover_slot24
fn moverSlot24(g: *Game, obj: *Object, bd: *Backdrop) void {
    blitRect(g, obj, bd, obj.mover.prevX, obj.mover.prevY);
    if (obj.mover.prevX != obj.x or obj.mover.prevY != obj.y) sceneObjectSlot24(g, obj, bd);
}

/// SceneObject slot 26 hide: mover_hide (pacman, ghost) / SceneObject's.
pub fn hide(g: *Game, obj: *Object, bd: *Backdrop) void {
    switch (obj.kind) {
        .pacman, .ghost => moverHide(g, obj, bd),
        .control_panel, .dot => sceneObjectHide(g, obj, bd),
    }
}

// @orig 10a0:38f0 scene_object_hide
fn sceneObjectHide(g: *Game, obj: *Object, bd: *Backdrop) void {
    render.erase(g, obj, bd);
    _ = occupancy.vacate(g, obj, bd);
    obj.visible = 0;
}

// @orig 10a0:261a mover_hide
fn moverHide(g: *Game, obj: *Object, bd: *Backdrop) void {
    render.restoreBackground(g, obj, bd, 1);
    _ = occupancy.vacate(g, obj, bd);
    obj.visible = 0;
    obj.mover.prevX = obj.x;
    obj.mover.prevY = obj.y;
}

/// SceneObject slot 27 show: actor2d_show (pacman, ghost), animated3d_show (panel) / SceneObject's.
/// Each opens with scene_object_dc_hook(1), an empty call.
pub fn show(g: *Game, obj: *Object, bd: *Backdrop) void {
    switch (obj.kind) {
        .pacman, .ghost => actor2dShow(g, obj, bd),
        .control_panel => animated3dShow(g, obj, bd),
        .dot => sceneObjectShow(g, obj, bd),
    }
}

// @orig 10a0:393e scene_object_show
fn sceneObjectShow(g: *Game, obj: *Object, bd: *Backdrop) void {
    obj.curFrame = 0;
    render.draw(g, obj, bd);
    _ = occupancy.occupy(g, obj, bd);
    obj.visible = 1;
}

// @orig 10a0:2d8e animated3d_show
fn animated3dShow(g: *Game, obj: *Object, bd: *Backdrop) void {
    obj.curFrame = 0;
    sceneObjectShow(g, obj, bd);
}

// @orig 10a0:2a14 actor2d_show
fn actor2dShow(g: *Game, obj: *Object, bd: *Backdrop) void {
    moverShow(g, obj, bd);
}

// @orig 10a0:26de mover_show
fn moverShow(g: *Game, obj: *Object, bd: *Backdrop) void {
    obj.curFrame = 0;
    render.drawDirtyTo(g, obj, &bd.bmiHeader, bd.pixels);
    _ = occupancy.occupy(g, obj, bd);
    obj.visible = 1;
    obj.mover.prevX = obj.x;
    obj.mover.prevY = obj.y;
}

/// SceneObject slot 54 redrawOverlapping (hdc dropped): object3d_redraw_overlapping (panel) / SceneObject's.
pub fn redrawOverlapping(g: *Game, obj: *Object, bd: *Backdrop, flag: i16) void {
    switch (obj.kind) {
        .control_panel => space3d.redrawOverlapping(g, obj, bd, flag),
        .pacman, .ghost, .dot => sceneObjectRedrawOverlapping(g, obj, bd),
    }
}

// @orig 1020:1a69 scene_object_redraw_overlapping
// SAUNA repaints the linked object with the draw slot then the invalidate
// slot (TIRO calls blitToDc); `flag` and the original's `hdc` are unused.
fn sceneObjectRedrawOverlapping(g: *Game, obj: *Object, bd: *Backdrop) void {
    if (obj.linked) |l| {
        render.draw(g, l, bd);
        invalidate(g, l);
    }
}
