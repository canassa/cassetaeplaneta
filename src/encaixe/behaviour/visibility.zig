//! Port unit `visibility` (behaviour) of ENCAIXE.EXE. SceneObject slots 1D-23 (redraw, hideAndInvalidate, blitToDc, invalidate, slot24, hide, show) and 4F redrawOverlapping.
//!
//! Virtual-slot dispatchers owned by this unit switch on `obj.kind` and call
//! one function per original implementation (docs/encaixe/DESIGN.md
//! "Virtual slots"). The `hdc` parameters are dropped.

const Game = @import("../core/game.zig").Game;
const object = @import("../core/object.zig");
const Object = object.Object;
const Frame = object.Frame;
const world = @import("../core/world.zig");
const Backdrop = world.Backdrop;
const lists = @import("../lists.zig");
const occupancy = @import("occupancy.zig");
const render = @import("render.zig");
const space3d = @import("space3d.zig");

fn strip(obj: *Object) *const Frame {
    return &obj.frames[@intCast(obj.curStrip)];
}

/// SceneObject slot 1D redraw: Actor2D's (piece), Animated3D's (control_panel), SceneObject's.
pub fn redraw(g: *Game, obj: *Object, bd: *Backdrop) void {
    switch (obj.kind) {
        .piece => actor2dRedraw(g, obj, bd),
        .control_panel => animated3dRedraw(g, obj, bd),
        .status_bar => sceneObjectRedraw(g, obj, bd),
    }
}

/// erase, occupy, draw.
fn eraseOccupyDraw(g: *Game, obj: *Object, bd: *Backdrop) void {
    render.erase(g, obj, bd);
    _ = occupancy.occupy(g, obj, bd);
    render.draw(g, obj, bd);
}

// @orig 1008:5412 scene_object_redraw
fn sceneObjectRedraw(g: *Game, obj: *Object, bd: *Backdrop) void {
    eraseOccupyDraw(g, obj, bd);
}

// @orig 1008:5b2c actor2d_redraw
fn actor2dRedraw(g: *Game, obj: *Object, bd: *Backdrop) void {
    eraseOccupyDraw(g, obj, bd);
}

// @orig 1008:5d76 animated3d_redraw
fn animated3dRedraw(g: *Game, obj: *Object, bd: *Backdrop) void {
    eraseOccupyDraw(g, obj, bd);
}

/// SceneObject slot 1E hideAndInvalidate.
pub fn hideAndInvalidate(g: *Game, obj: *Object, unused: u16, bd: *Backdrop) void {
    _ = unused;
    sceneObjectHideAndInvalidate(g, obj, bd);
}

// @orig 1008:543e scene_object_hide_and_invalidate
fn sceneObjectHideAndInvalidate(g: *Game, obj: *Object, bd: *Backdrop) void {
    hide(g, obj, bd);
    invalidate(g, obj);
}

/// SceneObject slot 1F blitToDc (hdc dropped): Actor2D's (piece) / SceneObject's.
pub fn blitToDc(g: *Game, obj: *Object, bd: *Backdrop) void {
    switch (obj.kind) {
        .piece => actor2dBlitToDc(g, obj, bd),
        .control_panel, .status_bar => sceneObjectBlitToDc(g, obj, bd),
    }
}

/// WinGBitBlt of the object's frame rectangle at (x, y) (SelectPalette and
/// RealizePalette are the platform's).
fn blitRect(g: *Game, obj: *Object, bd: *Backdrop, x: i16, y: i16) void {
    const f = strip(obj);
    g.plat.wingBitBlt(x -% bd.originX, y -% bd.originY, f.width, f.height, bd.surface(), x, y);
}

// @orig 1008:6ca4 scene_object_blit_to_dc
fn sceneObjectBlitToDc(g: *Game, obj: *Object, bd: *Backdrop) void {
    blitRect(g, obj, bd, obj.x, obj.y);
}

// @orig 1008:5b62 actor2d_blit_to_dc
fn actor2dBlitToDc(g: *Game, obj: *Object, bd: *Backdrop) void {
    moverBlitToDc(g, obj, bd);
}

// @orig 1008:6da8 mover_blit_to_dc
fn moverBlitToDc(g: *Game, obj: *Object, bd: *Backdrop) void {
    blitRect(g, obj, bd, obj.mover.prevX, obj.mover.prevY);
    if (obj.mover.prevX != obj.x or obj.mover.prevY != obj.y) sceneObjectBlitToDc(g, obj, bd);
}

/// The update list's add, inlined at both callers: queue once; a full list
/// (30) is a message box and the object stays unqueued.
fn queue(g: *Game, obj: *Object) void {
    if (obj.queued != 0) return;
    const ul = &g.updateList;
    if (ul.count == world.max_update) {
        lists.messageBoxPrintf(g, "Erro Fatal!!", "N\xe3o foi pos\xedvel inserir um objeto na lista de atualiza\xe7\xf5es de tela\r\nAumente o valor da constante MAX_OBJECT_QTY", 0);
        return;
    }
    ul.items[@intCast(ul.count)] = obj;
    obj.queued = 1;
    obj.queueIndex = ul.count;
    ul.count +%= 1;
}

/// SceneObject slot 20 invalidate: Mover's (piece) / SceneObject's.
pub fn invalidate(g: *Game, obj: *Object) void {
    switch (obj.kind) {
        .piece => moverInvalidate(g, obj),
        .control_panel, .status_bar => sceneObjectInvalidate(g, obj),
    }
}

// @orig 1008:6c58 scene_object_invalidate
fn sceneObjectInvalidate(g: *Game, obj: *Object) void {
    queue(g, obj);
}

// @orig 1008:6d48 mover_invalidate
fn moverInvalidate(g: *Game, obj: *Object) void {
    queue(g, obj);
}

/// SceneObject slot 21 slot24 (hdc dropped): Mover's (piece) / SceneObject's.
pub fn slot24(g: *Game, obj: *Object, bd: *Backdrop) void {
    switch (obj.kind) {
        .piece => moverSlot24(g, obj, bd),
        .control_panel, .status_bar => sceneObjectSlot24(g, obj, bd),
    }
}

// @orig 1008:6cf6 scene_object_slot24
fn sceneObjectSlot24(g: *Game, obj: *Object, bd: *Backdrop) void {
    blitRect(g, obj, bd, obj.x, obj.y);
}

// @orig 1008:6e26 mover_slot24
fn moverSlot24(g: *Game, obj: *Object, bd: *Backdrop) void {
    blitRect(g, obj, bd, obj.mover.prevX, obj.mover.prevY);
    if (obj.mover.prevX != obj.x or obj.mover.prevY != obj.y) sceneObjectSlot24(g, obj, bd);
}

/// SceneObject slot 22 hide: Mover's (piece) / SceneObject's.
pub fn hide(g: *Game, obj: *Object, bd: *Backdrop) void {
    switch (obj.kind) {
        .piece => moverHide(g, obj, bd),
        .control_panel, .status_bar => sceneObjectHide(g, obj, bd),
    }
}

// @orig 1008:545c scene_object_hide
fn sceneObjectHide(g: *Game, obj: *Object, bd: *Backdrop) void {
    render.erase(g, obj, bd);
    _ = occupancy.vacate(g, obj, bd);
    obj.visible = 0;
}

// @orig 1008:57f0 mover_hide
fn moverHide(g: *Game, obj: *Object, bd: *Backdrop) void {
    render.restoreBackground(g, obj, bd, 1);
    _ = occupancy.vacate(g, obj, bd);
    obj.visible = 0;
    obj.mover.prevX = obj.x;
    obj.mover.prevY = obj.y;
}

/// SceneObject slot 23 show: Actor2D's (piece), Animated3D's (control_panel), SceneObject's.
/// Each opens with scene_object_dc_hook(1), an empty call.
pub fn show(g: *Game, obj: *Object, bd: *Backdrop) void {
    switch (obj.kind) {
        .piece => actor2dShow(g, obj, bd),
        .control_panel => animated3dShow(g, obj, bd),
        .status_bar => sceneObjectShow(g, obj, bd),
    }
}

// @orig 1008:5486 scene_object_show
fn sceneObjectShow(g: *Game, obj: *Object, bd: *Backdrop) void {
    obj.curFrame = 0;
    render.draw(g, obj, bd);
    _ = occupancy.occupy(g, obj, bd);
    obj.visible = 1;
}

// @orig 1008:5dac animated3d_show
fn animated3dShow(g: *Game, obj: *Object, bd: *Backdrop) void {
    obj.curFrame = 0;
    render.draw(g, obj, bd);
    _ = occupancy.occupy(g, obj, bd);
    obj.visible = 1;
}

// @orig 1008:5b78 actor2d_show
fn actor2dShow(g: *Game, obj: *Object, bd: *Backdrop) void {
    obj.curFrame = 0;
    render.drawDirtyTo(g, obj, &bd.bmiHeader, bd.pixels);
    _ = occupancy.occupy(g, obj, bd);
    obj.visible = 1;
    obj.mover.prevX = obj.x;
    obj.mover.prevY = obj.y;
}

/// SceneObject slot 4F redrawOverlapping (hdc dropped): Object3D's (control_panel) / SceneObject's.
pub fn redrawOverlapping(g: *Game, obj: *Object, bd: *Backdrop, flag: i16) void {
    switch (obj.kind) {
        .control_panel => space3d.redrawOverlapping(g, obj, bd, flag),
        .piece, .status_bar => sceneObjectRedrawOverlapping(g, obj, bd),
    }
}

// @orig 1008:78e0 scene_object_redraw_overlapping
fn sceneObjectRedrawOverlapping(g: *Game, obj: *Object, bd: *Backdrop) void {
    if (obj.linked) |l| {
        render.draw(g, l, bd);
        blitToDc(g, l, bd);
    }
}
