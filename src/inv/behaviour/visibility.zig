//! Port unit `visibility` (behaviour) of INV.EXE. SceneObject slots 1B-21 (redraw, hideAndInvalidate, blitToDc incl. the Cannon's, invalidate, slot24, hide, show) and 4D redrawOverlapping.
//!
//! Virtual-slot dispatchers owned by this unit switch on `obj.kind` and call
//! one function per original implementation (docs/inv/DESIGN.md "SceneObject
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

/// SceneObject slot 1B redraw: actor2d_redraw (cannon, saucer, bomb, shot, column, explosion), animated3d_redraw (panel) / SceneObject's.
pub fn redraw(g: *Game, obj: *Object, bd: *Backdrop) void {
    switch (obj.kind) {
        .cannon, .saucer, .bomb, .shot, .invader_column, .invader_explosion => actor2dRedraw(g, obj, bd),
        .control_panel => animated3dRedraw(g, obj, bd),
        .status_bar => sceneObjectRedraw(g, obj, bd),
    }
}

// @orig 1088:176e scene_object_redraw
fn sceneObjectRedraw(g: *Game, obj: *Object, bd: *Backdrop) void {
    render.erase(g, obj, bd);
    _ = occupancy.occupy(g, obj, bd);
    render.draw(g, obj, bd);
}

// @orig 1088:238e actor2d_redraw
fn actor2dRedraw(g: *Game, obj: *Object, bd: *Backdrop) void {
    sceneObjectRedraw(g, obj, bd);
}

// @orig 1088:2734 animated3d_redraw
fn animated3dRedraw(g: *Game, obj: *Object, bd: *Backdrop) void {
    sceneObjectRedraw(g, obj, bd);
}

/// SceneObject slot 1C hideAndInvalidate. INV's (1088:17a4) hides, then calls
/// `scene_object_blit_to_dc` on its hdc (TIRO's calls the virtual
/// `invalidate`): `unused` is that hdc, which the port drops.
pub fn hideAndInvalidate(g: *Game, obj: *Object, unused: u16, bd: *Backdrop) void {
    _ = unused;
    sceneObjectHideAndInvalidate(g, obj, bd);
}

// @orig 1088:17a4 scene_object_hide_and_invalidate
fn sceneObjectHideAndInvalidate(g: *Game, obj: *Object, bd: *Backdrop) void {
    hide(g, obj, bd);
    sceneObjectBlitToDc(g, obj, bd);
}

/// SceneObject slot 1D blitToDc (hdc dropped): cannon_blit_to_dc (cannon), actor2d_blit_to_dc (saucer, bomb, shot, column, explosion) / SceneObject's.
pub fn blitToDc(g: *Game, obj: *Object, bd: *Backdrop) void {
    switch (obj.kind) {
        .cannon => cannonBlitToDc(g, obj, bd),
        .saucer, .bomb, .shot, .invader_column, .invader_explosion => actor2dBlitToDc(g, obj, bd),
        .control_panel, .status_bar => sceneObjectBlitToDc(g, obj, bd),
    }
}

/// WinGBitBlt of the object's strip rectangle at (x, y) (SelectPalette and
/// RealizePalette are the platform's).
fn blitRect(g: *Game, obj: *Object, bd: *Backdrop, x: i16, y: i16) void {
    g.plat.wingBitBlt(x -% bd.originX, y -% bd.originY, position.width(obj), position.height(obj), bd.surface(), x, y);
}

// @orig 1028:0041 scene_object_blit_to_dc
pub fn sceneObjectBlitToDc(g: *Game, obj: *Object, bd: *Backdrop) void {
    blitRect(g, obj, bd, obj.x, obj.y);
}

// @orig 1088:23bc actor2d_blit_to_dc
fn actor2dBlitToDc(g: *Game, obj: *Object, bd: *Backdrop) void {
    moverBlitToDc(g, obj, bd);
}

// @orig 1028:013a mover_blit_to_dc
fn moverBlitToDc(g: *Game, obj: *Object, bd: *Backdrop) void {
    blitRect(g, obj, bd, obj.mover.prevX, obj.mover.prevY);
    if (obj.mover.prevX != obj.x or obj.mover.prevY != obj.y) sceneObjectBlitToDc(g, obj, bd);
}

// @orig 1068:087c cannon_blit_to_dc
// One rect, a step (getStepX, slot 0A) wider on each side, so the 20-px
// trail is erased.
fn cannonBlitToDc(g: *Game, obj: *Object, bd: *Backdrop) void {
    const step = position.getStepX(g, obj);
    const src_x = obj.x -% step;
    g.plat.wingBitBlt(src_x -% bd.originX, obj.y -% bd.originY, step *% 2 +% position.width(obj), position.height(obj), bd.surface(), src_x, obj.y);
}

/// SceneObject slot 1E invalidate: mover_invalidate (cannon, saucer, bomb, shot, column, explosion) / SceneObject's.
pub fn invalidate(g: *Game, obj: *Object) void {
    switch (obj.kind) {
        .cannon, .saucer, .bomb, .shot, .invader_column, .invader_explosion => moverInvalidate(g, obj),
        .control_panel, .status_bar => sceneObjectInvalidate(g, obj),
    }
}

// @orig 1028:001b scene_object_invalidate
fn sceneObjectInvalidate(g: *Game, obj: *Object) void {
    _ = lists.updateAdd(g, &g.updateList, obj);
}

// @orig 1028:00f7 mover_invalidate
fn moverInvalidate(g: *Game, obj: *Object) void {
    // The original's null test (this == s_hdcOverflow + 6) is a NULL object's
    // sub-object offset; `obj` is never null.
    _ = lists.updateAdd(g, &g.updateList, obj);
}

/// SceneObject slot 1F slot24 (hdc dropped): mover_slot24 (cannon, saucer, bomb, shot, column, explosion) / SceneObject's.
pub fn slot24(g: *Game, obj: *Object, bd: *Backdrop) void {
    switch (obj.kind) {
        .cannon, .saucer, .bomb, .shot, .invader_column, .invader_explosion => moverSlot24(g, obj, bd),
        .control_panel, .status_bar => sceneObjectSlot24(g, obj, bd),
    }
}

// @orig 1028:00a8 scene_object_slot24
fn sceneObjectSlot24(g: *Game, obj: *Object, bd: *Backdrop) void {
    blitRect(g, obj, bd, obj.x, obj.y);
}

// @orig 1028:01ee mover_slot24
fn moverSlot24(g: *Game, obj: *Object, bd: *Backdrop) void {
    blitRect(g, obj, bd, obj.mover.prevX, obj.mover.prevY);
    if (obj.mover.prevX != obj.x or obj.mover.prevY != obj.y) sceneObjectSlot24(g, obj, bd);
}

/// SceneObject slot 20 hide: mover_hide (cannon, saucer, bomb, shot, column, explosion) / SceneObject's.
pub fn hide(g: *Game, obj: *Object, bd: *Backdrop) void {
    switch (obj.kind) {
        .cannon, .saucer, .bomb, .shot, .invader_column, .invader_explosion => moverHide(g, obj, bd),
        .control_panel, .status_bar => sceneObjectHide(g, obj, bd),
    }
}

// @orig 1088:3098 scene_object_hide
fn sceneObjectHide(g: *Game, obj: *Object, bd: *Backdrop) void {
    render.erase(g, obj, bd);
    _ = occupancy.vacate(g, obj, bd);
    obj.visible = 0;
}

// @orig 1088:2104 mover_hide
fn moverHide(g: *Game, obj: *Object, bd: *Backdrop) void {
    render.restoreBackground(g, obj, bd, 1);
    _ = occupancy.vacate(g, obj, bd);
    obj.visible = 0;
    obj.mover.prevX = obj.x;
    obj.mover.prevY = obj.y;
}

/// SceneObject slot 21 show: actor2d_show (cannon, saucer, bomb, shot, column, explosion), animated3d_show (panel) / SceneObject's.
/// Each opens with scene_object_dc_hook(1), an empty call.
pub fn show(g: *Game, obj: *Object, bd: *Backdrop) void {
    switch (obj.kind) {
        .cannon, .saucer, .bomb, .shot, .invader_column, .invader_explosion => actor2dShow(g, obj, bd),
        .control_panel => animated3dShow(g, obj, bd),
        .status_bar => sceneObjectShow(g, obj, bd),
    }
}

// @orig 1088:30ca scene_object_show
fn sceneObjectShow(g: *Game, obj: *Object, bd: *Backdrop) void {
    obj.curFrame = 0;
    render.draw(g, obj, bd);
    _ = occupancy.occupy(g, obj, bd);
    obj.visible = 1;
}

// @orig 1088:2762 animated3d_show
fn animated3dShow(g: *Game, obj: *Object, bd: *Backdrop) void {
    obj.curFrame = 0;
    sceneObjectShow(g, obj, bd);
}

// @orig 1088:23e4 actor2d_show
fn actor2dShow(g: *Game, obj: *Object, bd: *Backdrop) void {
    moverShow(g, obj, bd);
}

// @orig 1088:217a mover_show
fn moverShow(g: *Game, obj: *Object, bd: *Backdrop) void {
    obj.curFrame = 0;
    render.drawDirtyTo(g, obj, &bd.bmiHeader, bd.pixels);
    _ = occupancy.occupy(g, obj, bd);
    obj.visible = 1;
    obj.mover.prevX = obj.x;
    obj.mover.prevY = obj.y;
}

/// SceneObject slot 4D redrawOverlapping (hdc dropped): object3d_redraw_overlapping (panel) / SceneObject's.
pub fn redrawOverlapping(g: *Game, obj: *Object, bd: *Backdrop, flag: i16) void {
    switch (obj.kind) {
        .control_panel => space3d.redrawOverlapping(g, obj, bd, flag),
        .cannon, .saucer, .bomb, .shot, .invader_column, .invader_explosion, .status_bar => sceneObjectRedrawOverlapping(g, obj, bd),
    }
}

// @orig 1028:10d6 scene_object_redraw_overlapping
// The original's `hdc` is never initialised (the same bug as ENCAIXE's); the
// port drops it.
fn sceneObjectRedrawOverlapping(g: *Game, obj: *Object, bd: *Backdrop) void {
    if (obj.linked) |l| {
        render.draw(g, l, bd);
        blitToDc(g, l, bd);
    }
}
