//! Port unit `visibility` (behaviour) of TIRO.EXE. SceneObject slots 1B-21 (redraw, hideAndInvalidate, blitToDc, invalidate, slot24, hide, show) and 4D redrawOverlapping (Target's, Projectile's).
//!
//! Virtual-slot dispatchers owned by this unit switch on `obj.kind` and call
//! one function per original implementation (docs/tiro/DESIGN.md "Virtual
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

/// SceneObject slot 1B redraw: actor2d_redraw (crossbow, target, arrow), animated3d_redraw (panel) / SceneObject's.
pub fn redraw(g: *Game, obj: *Object, bd: *Backdrop) void {
    switch (obj.kind) {
        .crossbow, .target, .arrow => actor2dRedraw(g, obj, bd),
        .control_panel => animated3dRedraw(g, obj, bd),
        .status_bar => sceneObjectRedraw(g, obj, bd),
    }
}

// @orig 1088:1642 scene_object_redraw
fn sceneObjectRedraw(g: *Game, obj: *Object, bd: *Backdrop) void {
    render.erase(g, obj, bd);
    _ = occupancy.occupy(g, obj, bd);
    render.draw(g, obj, bd);
}

// @orig 1088:225c actor2d_redraw
fn actor2dRedraw(g: *Game, obj: *Object, bd: *Backdrop) void {
    sceneObjectRedraw(g, obj, bd);
}

// @orig 1088:2602 animated3d_redraw
fn animated3dRedraw(g: *Game, obj: *Object, bd: *Backdrop) void {
    sceneObjectRedraw(g, obj, bd);
}

/// SceneObject slot 1C hideAndInvalidate.
pub fn hideAndInvalidate(g: *Game, obj: *Object, unused: u16, bd: *Backdrop) void {
    _ = unused;
    sceneObjectHideAndInvalidate(g, obj, bd);
}

// @orig 1088:1678 scene_object_hide_and_invalidate
fn sceneObjectHideAndInvalidate(g: *Game, obj: *Object, bd: *Backdrop) void {
    hide(g, obj, bd);
    invalidate(g, obj);
}

/// SceneObject slot 1D blitToDc (hdc dropped): actor2d_blit_to_dc (crossbow, target, arrow) / SceneObject's.
pub fn blitToDc(g: *Game, obj: *Object, bd: *Backdrop) void {
    switch (obj.kind) {
        .crossbow, .target, .arrow => actor2dBlitToDc(g, obj, bd),
        .control_panel, .status_bar => sceneObjectBlitToDc(g, obj, bd),
    }
}

/// WinGBitBlt of the object's strip rectangle at (x, y) (SelectPalette and
/// RealizePalette are the platform's).
fn blitRect(g: *Game, obj: *Object, bd: *Backdrop, x: i16, y: i16) void {
    g.plat.wingBitBlt(x -% bd.originX, y -% bd.originY, position.width(obj), position.height(obj), bd.surface(), x, y);
}

// @orig 1028:0041 scene_object_blit_to_dc
fn sceneObjectBlitToDc(g: *Game, obj: *Object, bd: *Backdrop) void {
    blitRect(g, obj, bd, obj.x, obj.y);
}

// @orig 1088:228a actor2d_blit_to_dc
fn actor2dBlitToDc(g: *Game, obj: *Object, bd: *Backdrop) void {
    moverBlitToDc(g, obj, bd);
}

// @orig 1028:0152 mover_blit_to_dc
fn moverBlitToDc(g: *Game, obj: *Object, bd: *Backdrop) void {
    blitRect(g, obj, bd, obj.mover.prevX, obj.mover.prevY);
    if (obj.mover.prevX != obj.x or obj.mover.prevY != obj.y) sceneObjectBlitToDc(g, obj, bd);
}

/// SceneObject slot 1E invalidate: mover_invalidate (crossbow, target, arrow) / SceneObject's.
pub fn invalidate(g: *Game, obj: *Object) void {
    switch (obj.kind) {
        .crossbow, .target, .arrow => moverInvalidate(g, obj),
        .control_panel, .status_bar => sceneObjectInvalidate(g, obj),
    }
}

// @orig 1028:001b scene_object_invalidate
fn sceneObjectInvalidate(g: *Game, obj: *Object) void {
    _ = lists.updateAdd(g, &g.updateList, obj);
}

// @orig 1028:010f mover_invalidate
fn moverInvalidate(g: *Game, obj: *Object) void {
    // The original's null test (this == s_hdcOverflow + 6) is a NULL object's
    // sub-object offset; `obj` is never null.
    _ = lists.updateAdd(g, &g.updateList, obj);
}

/// SceneObject slot 1F slot24 (hdc dropped): mover_slot24 (crossbow, target, arrow) / SceneObject's.
pub fn slot24(g: *Game, obj: *Object, bd: *Backdrop) void {
    switch (obj.kind) {
        .crossbow, .target, .arrow => moverSlot24(g, obj, bd),
        .control_panel, .status_bar => sceneObjectSlot24(g, obj, bd),
    }
}

// @orig 1028:00a8 scene_object_slot24
fn sceneObjectSlot24(g: *Game, obj: *Object, bd: *Backdrop) void {
    blitRect(g, obj, bd, obj.x, obj.y);
}

// @orig 1028:0206 mover_slot24
fn moverSlot24(g: *Game, obj: *Object, bd: *Backdrop) void {
    blitRect(g, obj, bd, obj.mover.prevX, obj.mover.prevY);
    if (obj.mover.prevX != obj.x or obj.mover.prevY != obj.y) sceneObjectSlot24(g, obj, bd);
}

/// SceneObject slot 20 hide: mover_hide (crossbow, target, arrow) / SceneObject's.
pub fn hide(g: *Game, obj: *Object, bd: *Backdrop) void {
    switch (obj.kind) {
        .crossbow, .target, .arrow => moverHide(g, obj, bd),
        .control_panel, .status_bar => sceneObjectHide(g, obj, bd),
    }
}

// @orig 1088:2f66 scene_object_hide
fn sceneObjectHide(g: *Game, obj: *Object, bd: *Backdrop) void {
    render.erase(g, obj, bd);
    _ = occupancy.vacate(g, obj, bd);
    obj.visible = 0;
}

// @orig 1088:1fd2 mover_hide
fn moverHide(g: *Game, obj: *Object, bd: *Backdrop) void {
    render.restoreBackground(g, obj, bd, 1);
    _ = occupancy.vacate(g, obj, bd);
    obj.visible = 0;
    obj.mover.prevX = obj.x;
    obj.mover.prevY = obj.y;
}

/// SceneObject slot 21 show: actor2d_show (crossbow, target, arrow), animated3d_show (panel) / SceneObject's.
/// Each opens with scene_object_dc_hook(1), an empty call.
pub fn show(g: *Game, obj: *Object, bd: *Backdrop) void {
    switch (obj.kind) {
        .crossbow, .target, .arrow => actor2dShow(g, obj, bd),
        .control_panel => animated3dShow(g, obj, bd),
        .status_bar => sceneObjectShow(g, obj, bd),
    }
}

// @orig 1088:2f98 scene_object_show
fn sceneObjectShow(g: *Game, obj: *Object, bd: *Backdrop) void {
    obj.curFrame = 0;
    render.draw(g, obj, bd);
    _ = occupancy.occupy(g, obj, bd);
    obj.visible = 1;
}

// @orig 1088:2630 animated3d_show
fn animated3dShow(g: *Game, obj: *Object, bd: *Backdrop) void {
    obj.curFrame = 0;
    sceneObjectShow(g, obj, bd);
}

// @orig 1088:22b2 actor2d_show
fn actor2dShow(g: *Game, obj: *Object, bd: *Backdrop) void {
    moverShow(g, obj, bd);
}

// @orig 1088:2048 mover_show
fn moverShow(g: *Game, obj: *Object, bd: *Backdrop) void {
    obj.curFrame = 0;
    render.drawDirtyTo(g, obj, &bd.bmiHeader, bd.pixels);
    _ = occupancy.occupy(g, obj, bd);
    obj.visible = 1;
    obj.mover.prevX = obj.x;
    obj.mover.prevY = obj.y;
}

/// SceneObject slot 4D redrawOverlapping (hdc dropped): target_redraw_overlapping (target), projectile_redraw_overlapping (arrow), object3d_redraw_overlapping (panel) / SceneObject's.
pub fn redrawOverlapping(g: *Game, obj: *Object, bd: *Backdrop, flag: i16) void {
    switch (obj.kind) {
        .target => targetRedrawOverlapping(g, bd),
        .arrow => projectileRedrawOverlapping(g, obj, bd),
        .control_panel => space3d.redrawOverlapping(g, obj, bd, flag),
        .crossbow, .status_bar => sceneObjectRedrawOverlapping(g, obj, bd),
    }
}

/// Draws each of the four targets whose `curFrame` (SceneObject+0x1a) is 0.
/// The original reads g_targets without a null test.
fn drawIdleTargets(g: *Game, bd: *Backdrop) void {
    for (g.targets) |t| {
        const target = t.?;
        if (target.curFrame == 0) render.draw(g, target, bd);
    }
}

// @orig 1068:06df target_redraw_overlapping
fn targetRedrawOverlapping(g: *Game, bd: *Backdrop) void {
    drawIdleTargets(g, bd);
}

// @orig 1068:1511 projectile_redraw_overlapping
fn projectileRedrawOverlapping(g: *Game, obj: *Object, bd: *Backdrop) void {
    drawIdleTargets(g, bd);
    render.draw(g, obj, bd);
}

// @orig 1028:1102 scene_object_redraw_overlapping
// The original's `hdc` is never initialised (the same bug as ENCAIXE's); the
// port drops it.
fn sceneObjectRedrawOverlapping(g: *Game, obj: *Object, bd: *Backdrop) void {
    if (obj.linked) |l| {
        render.draw(g, l, bd);
        blitToDc(g, l, bd);
    }
}
