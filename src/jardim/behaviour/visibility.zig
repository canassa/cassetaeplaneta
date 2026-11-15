//! Port unit `visibility` (behaviour) of JARDIM.EXE. SceneObject slots 20-26 (redraw, hideAndInvalidate, blitToDc, invalidate, slot24, hide, show) and 53 redrawOverlapping.
//!
//! Virtual-slot dispatchers owned by this unit switch on `obj.kind` and call
//! one function per original implementation (docs/jardim/DESIGN.md "Virtual
//! slots"). The `hdc` parameters are dropped.

const std = @import("std");
const Game = @import("../core/game.zig").Game;
const object = @import("../core/object.zig");
const Object = object.Object;
const world = @import("../core/world.zig");
const Backdrop = world.Backdrop;
const lists = @import("../lists.zig");
const panels = @import("../panels.zig");
const scene = @import("../scene.zig");
const occupancy = @import("occupancy.zig");
const position = @import("position.zig");
const render = @import("render.zig");
const space3d = @import("space3d.zig");

/// SceneObject slot 20 redraw: animated3d_redraw (exit, player, control_panel) / SceneObject's.
pub fn redraw(g: *Game, obj: *Object, bd: *Backdrop) void {
    switch (obj.kind) {
        .exit, .player, .control_panel => animated3dRedraw(g, obj, bd),
        .scene_object, .wall_strip, .portable => sceneObjectRedraw(g, obj, bd),
    }
}

// @orig 10c0:2f98 scene_object_redraw
fn sceneObjectRedraw(g: *Game, obj: *Object, bd: *Backdrop) void {
    render.erase(g, obj, bd);
    _ = occupancy.occupy(g, obj, bd);
    render.draw(g, obj, bd);
}

// @orig 10c0:232a animated3d_redraw
fn animated3dRedraw(g: *Game, obj: *Object, bd: *Backdrop) void {
    sceneObjectRedraw(g, obj, bd);
}

/// SceneObject slot 21 hideAndInvalidate (SceneObject's).
pub fn hideAndInvalidate(g: *Game, obj: *Object, unused: u16, bd: *Backdrop) void {
    _ = unused;
    sceneObjectHideAndInvalidate(g, obj, bd);
}

// @orig 10c0:37b8 scene_object_hide_and_invalidate
fn sceneObjectHideAndInvalidate(g: *Game, obj: *Object, bd: *Backdrop) void {
    hide(g, obj, bd);
    invalidate(g, obj);
}

/// SceneObject slot 22 blitToDc (hdc dropped): moveable_blit_to_dc (portable, player) / SceneObject's.
pub fn blitToDc(g: *Game, obj: *Object, bd: *Backdrop) void {
    switch (obj.kind) {
        .portable, .player => moveableBlitToDc(g, obj, bd),
        .scene_object, .wall_strip, .exit, .control_panel => sceneObjectBlitToDc(g, obj, bd),
    }
}

/// WinGBitBlt of the object's strip rectangle at (x, y) (SelectPalette and
/// RealizePalette are the platform's).
fn blitRect(g: *Game, obj: *Object, bd: *Backdrop, x: i16, y: i16) void {
    g.plat.wingBitBlt(x -% bd.originX, y -% bd.originY, position.width(obj), position.height(obj), bd.surface(), x, y);
}

// @orig 1038:0048 scene_object_blit_to_dc
pub fn sceneObjectBlitToDc(g: *Game, obj: *Object, bd: *Backdrop) void {
    blitRect(g, obj, bd, obj.x, obj.y);
}

// @orig 1038:0179 mover_blit_to_dc
fn moverBlitToDc(g: *Game, obj: *Object, bd: *Backdrop) void {
    blitRect(g, obj, bd, obj.mover.prevX, obj.mover.prevY);
    if (obj.mover.prevX != obj.x or obj.mover.prevY != obj.y) sceneObjectBlitToDc(g, obj, bd);
}

// @orig 1048:139c moveable_blit_to_dc
/// Mover blit, then (the debug aid the shipped game keeps) the anchor's
/// screen point and the world x/depth/elevation in the status bar.
fn moveableBlitToDc(g: *Game, obj: *Object, bd: *Backdrop) void {
    moverBlitToDc(g, obj, bd);
    const sx = obj.x +% obj.o3d.anchorX;
    const sy = bd.viewHeight -% obj.y -% obj.o3d.anchorY;
    var buf: [50]u8 = undefined;
    var w: std.Io.Writer = .fixed(buf[0 .. buf.len - 1]);
    w.print("({f},{f})=>({f},{f},{f})", .{ D3{ .v = sx }, D3{ .v = sy }, D3{ .v = obj.o3d.worldX }, D3{ .v = obj.o3d.worldDepth }, D3{ .v = obj.o3d.worldElev } }) catch {};
    const n = w.buffered().len;
    buf[n] = 0;
    if (scene.getHasStatusBar(g, g.scene.?)) panels.statusBarSetText(g.statusBar.?, 100, buf[0..n]);
}

/// C `%03d` of an int.
const D3 = struct {
    v: i16,
    pub fn format(self: D3, w: *std.Io.Writer) std.Io.Writer.Error!void {
        const neg = self.v < 0;
        const mag: u32 = @abs(@as(i32, self.v));
        var digits: [8]u8 = undefined;
        const s = std.fmt.bufPrint(&digits, "{d}", .{mag}) catch unreachable;
        const len = s.len + @intFromBool(neg);
        if (neg) try w.writeByte('-');
        var i = len;
        while (i < 3) : (i += 1) try w.writeByte('0');
        try w.writeAll(s);
    }
};

/// SceneObject slot 23 invalidate: moveable_invalidate (portable, player) / SceneObject's.
pub fn invalidate(g: *Game, obj: *Object) void {
    switch (obj.kind) {
        .portable, .player => moveableInvalidate(g, obj),
        .scene_object, .wall_strip, .exit, .control_panel => sceneObjectInvalidate(g, obj),
    }
}

// @orig 1038:001b scene_object_invalidate
fn sceneObjectInvalidate(g: *Game, obj: *Object) void {
    _ = lists.updateAdd(g, &g.updateList, obj);
}

// @orig 1048:00b6 moveable_invalidate
fn moveableInvalidate(g: *Game, obj: *Object) void {
    // The original's null test (this == 0x38) is a NULL object's sub-object
    // offset; `obj` is never null.
    _ = lists.updateAdd(g, &g.updateList, obj);
}

/// SceneObject slot 24 slot24 (hdc dropped): mover_slot24 (portable, player) / default.
pub fn slot24(g: *Game, obj: *Object, bd: *Backdrop) void {
    switch (obj.kind) {
        .portable, .player => moverSlot24(g, obj, bd),
        .scene_object, .wall_strip, .exit, .control_panel => sceneObjectSlot24Default(g, obj, bd),
    }
}

// @orig 1038:00b1 scene_object_slot24_default (absorbed)
fn sceneObjectSlot24Default(g: *Game, obj: *Object, bd: *Backdrop) void {
    blitRect(g, obj, bd, obj.x, obj.y);
}

// @orig 1038:0260 mover_slot24
fn moverSlot24(g: *Game, obj: *Object, bd: *Backdrop) void {
    blitRect(g, obj, bd, obj.mover.prevX, obj.mover.prevY);
    if (obj.mover.prevX != obj.x or obj.mover.prevY != obj.y) sceneObjectSlot24Default(g, obj, bd);
}

/// SceneObject slot 25 hide: mover_hide (portable, player) / SceneObject's.
pub fn hide(g: *Game, obj: *Object, bd: *Backdrop) void {
    switch (obj.kind) {
        .portable, .player => moverHide(g, obj, bd),
        .scene_object, .wall_strip, .exit, .control_panel => sceneObjectHide(g, obj, bd),
    }
}

// @orig 10c0:37f6 scene_object_hide
fn sceneObjectHide(g: *Game, obj: *Object, bd: *Backdrop) void {
    render.erase(g, obj, bd);
    _ = occupancy.vacate(g, obj, bd);
    obj.visible = 0;
}

// @orig 10c0:1c86 mover_hide
fn moverHide(g: *Game, obj: *Object, bd: *Backdrop) void {
    render.restoreBackground(g, obj, bd, 1);
    _ = occupancy.vacate(g, obj, bd);
    obj.visible = 0;
    obj.mover.prevX = obj.x;
    obj.mover.prevY = obj.y;
}

/// SceneObject slot 26 show: mover_show (portable), animated3d_show (exit, control_panel), actor_show (player) / SceneObject's.
/// Each opens with scene_object_dc_hook(1), an empty call.
pub fn show(g: *Game, obj: *Object, bd: *Backdrop) void {
    switch (obj.kind) {
        .portable => moverShow(g, obj, bd),
        .exit, .control_panel => animated3dShow(g, obj, bd),
        .player => actorShow(g, obj, bd),
        .scene_object, .wall_strip => sceneObjectShow(g, obj, bd),
    }
}

// @orig 10c0:2ff2 scene_object_show
fn sceneObjectShow(g: *Game, obj: *Object, bd: *Backdrop) void {
    obj.curFrame = 0;
    render.draw(g, obj, bd);
    _ = occupancy.occupy(g, obj, bd);
    obj.visible = 1;
}

// @orig 10c0:2362 animated3d_show
fn animated3dShow(g: *Game, obj: *Object, bd: *Backdrop) void {
    obj.curFrame = 0;
    sceneObjectShow(g, obj, bd);
}

// @orig 10c0:1d4a mover_show
fn moverShow(g: *Game, obj: *Object, bd: *Backdrop) void {
    obj.curFrame = 0;
    render.drawDirtyTo(g, obj, &bd.bmiHeader, bd.pixels);
    _ = occupancy.occupy(g, obj, bd);
    obj.visible = 1;
    obj.mover.prevX = obj.x;
    obj.mover.prevY = obj.y;
}

// @orig 10c0:2632 actor_show
fn actorShow(g: *Game, obj: *Object, bd: *Backdrop) void {
    obj.curFrame = 0;
    moverShow(g, obj, bd);
}

/// SceneObject slot 53 redrawOverlapping (hdc dropped): object3d_redraw_overlapping (portable, exit, player, control_panel) / default.
pub fn redrawOverlapping(g: *Game, obj: *Object, bd: *Backdrop, flag: i16) void {
    _ = flag;
    switch (obj.kind) {
        .portable, .exit, .player, .control_panel => object3dRedrawOverlapping(g, obj, bd),
        .scene_object, .wall_strip => sceneObjectRedrawOverlappingDefault(g, obj, bd),
    }
}

// @orig 1038:1a05 scene_object_redraw_overlapping_default (absorbed)
// Draws the linked object into the backdrop and queues it for the screen
// update (JARDIM invalidates where TIRO blits).
fn sceneObjectRedrawOverlappingDefault(g: *Game, obj: *Object, bd: *Backdrop) void {
    if (obj.linked) |l| {
        render.draw(g, l, bd);
        invalidate(g, l);
    }
}

// @orig 1048:1bee object3d_redraw_overlapping
/// Redraws every visible draw-list object whose image overlaps this one,
/// redrawing this object clipped on top when it is in front of it; each hit
/// invalidates this object. Always invalidates it last. (No player pass:
/// JARDIM's version walks the draw list only.)
fn object3dRedrawOverlapping(g: *Game, obj: *Object, bd: *Backdrop) void {
    var node = g.drawList.head;
    while (node) |n| : (node = n.next) {
        const other = n.item.?;
        if (other.visible == 0) continue;
        if (other.id == obj.id) continue;
        if (!render.computeOverlap(g, obj, other)) continue;
        render.draw(g, other, bd);
        if (obj.visible != 0 and space3d.isInFrontOf(g, obj, other, bd)) render.drawClip(g, obj, bd);
        invalidate(g, obj);
    }
    invalidate(g, obj);
}
