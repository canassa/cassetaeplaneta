//! Port unit `visibility` (behaviour). SceneObject slots 16, 20-23, 25, 26, 58: redraw, blit to screen, invalidate, hide, show, redraw overlapping, debug bounds.
//!
//! Virtual-slot dispatchers owned by this unit keep the signatures the
//! skeleton declared (other units already call them). The `hdc` parameters
//! of the blits are dropped (one window; `plat.wingBitBlt` writes the screen).

const std = @import("std");
const frames = @import("../frames.zig");
const update_list = @import("../update_list.zig");
const scene_mod = @import("../scene.zig");
const panels = @import("../panels.zig");
const cstr = @import("../core/cstr.zig");
const Game = @import("../core/game.zig").Game;
const object = @import("../core/object.zig");
const Object = object.Object;
const world = @import("../core/world.zig");
const Backdrop = world.Backdrop;
const render = @import("render.zig");
const occupancy = @import("occupancy.zig");
const space3d = @import("space3d.zig");
const movement = @import("movement.zig");

/// SceneObject slot 16.
pub fn drawBounds(g: *Game, obj: *Object, bd: *Backdrop) ?*Object {
    return switch (obj.kind) {
        // @orig 1010:1442 scene_object_draw_bounds_default (absorbed)
        .status_bar => obj,
        else => object3dDrawBounds(g, obj, bd),
    };
}

// @orig 1010:4a94 object3d_draw_bounds
/// Debug view: the original projects the 12 edges of the object's 3D box
/// and draws them with a yellow GDI pen on the given DC. The platform has no
/// line drawing and nothing calls this slot, so only the return value (the
/// SceneObject sub-object, i.e. the object) is kept.
fn object3dDrawBounds(g: *Game, obj: *Object, bd: *Backdrop) ?*Object {
    _ = .{ g, bd };
    return obj;
}

/// SceneObject slot 20.
pub fn redraw(g: *Game, obj: *Object, bd: *Backdrop) void {
    // @orig 1010:35a8 animated3d_redraw: A Ac P E C, calls scene_object_redraw
    sceneObjectRedraw(g, obj, bd);
}

// @orig 1010:173e scene_object_redraw
/// Erases the object, marks its cells in the occupancy grid, draws it again.
fn sceneObjectRedraw(g: *Game, obj: *Object, bd: *Backdrop) void {
    render.erase(g, obj, bd);
    _ = occupancy.occupy(g, obj, bd);
    render.draw(g, obj, bd);
}

/// SceneObject slot 21.
pub fn hideAndInvalidate(g: *Game, obj: *Object, unused: i16, bd: *Backdrop) void {
    _ = unused;
    sceneObjectHideAndInvalidate(g, obj, bd);
}

// @orig 1010:1794 scene_object_hide_and_invalidate
fn sceneObjectHideAndInvalidate(g: *Game, obj: *Object, bd: *Backdrop) void {
    hide(g, obj, bd);
    _ = invalidate(g, obj);
}

/// SceneObject slot 22.
pub fn blitToDc(g: *Game, obj: *Object, bd: *Backdrop) void {
    switch (obj.kind) {
        .moveable, .actor, .player, .portable => moveableBlitToDc(g, obj, bd),
        else => sceneObjectBlitToDc(g, obj, bd),
    }
}

// @orig 1010:b098 scene_object_blit_to_dc
/// Copies the object's frame rectangle from the backdrop bitmap to the screen.
fn sceneObjectBlitToDc(g: *Game, obj: *Object, bd: *Backdrop) void {
    blitRect(g, obj, bd, obj.x, obj.y);
}

fn blitRect(g: *Game, obj: *Object, bd: *Backdrop, x: i16, y: i16) void {
    const w = frames.width(obj);
    const h = frames.height(obj);
    g.plat.wingBitBlt(x -% bd.originX, y -% bd.originY, w, h, bd.surface(), x, y);
}

// @orig 1010:b1ce mover_blit_to_dc
/// Blits the frame rectangle at the previous position, and at the current
/// one when the object moved.
fn moverBlitToDc(g: *Game, obj: *Object, bd: *Backdrop) void {
    blitRect(g, obj, bd, obj.mover.prevX, obj.mover.prevY);
    if (obj.x != obj.mover.prevX or obj.y != obj.mover.prevY) sceneObjectBlitToDc(g, obj, bd);
}

// @orig 1010:5716 moveable_blit_to_dc
/// Mover blit, then (debug aid the shipped game keeps) the anchor's screen
/// point and the world x/depth/elevation in the status bar.
fn moveableBlitToDc(g: *Game, obj: *Object, bd: *Backdrop) void {
    moverBlitToDc(g, obj, bd);
    const sx = obj.x +% obj.o3d.anchorX;
    const sy = bd.viewHeight -% obj.y -% obj.o3d.anchorY;
    var buf: [50]u8 = undefined;
    var w: std.Io.Writer = .fixed(buf[0 .. buf.len - 1]);
    w.print("({f},{f})=>({f},{f},{f})", .{ D3{ .v = sx }, D3{ .v = sy }, D3{ .v = obj.o3d.worldX }, D3{ .v = obj.o3d.worldDepth }, D3{ .v = obj.o3d.worldElev } }) catch {};
    const n = w.buffered().len;
    buf[n] = 0;
    if (scene_mod.getHasStatusBar(g, g.scene.?)) panels.statusBarSetText(g, g.statusBar.?, 100, buf[0..n]);
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

/// SceneObject slot 23: queues the object for the next screen update and
/// returns its index in the update list.
pub fn invalidate(g: *Game, obj: *Object) i16 {
    return switch (obj.kind) {
        .moveable, .actor, .player, .portable => moveableInvalidate(g, obj),
        else => sceneObjectInvalidate(g, obj),
    };
}

// @orig 1010:b072 scene_object_invalidate
fn sceneObjectInvalidate(g: *Game, obj: *Object) i16 {
    return update_list.add(&g.updateList, g.plat, &g.messageBuf, obj);
}

// @orig 1010:47e8 moveable_invalidate
fn moveableInvalidate(g: *Game, obj: *Object) i16 {
    return update_list.add(&g.updateList, g.plat, &g.messageBuf, obj);
}

// @orig 1010:b180 mover_invalidate
/// The standalone Mover's override (not in any instantiated vtable).
fn moverInvalidate(g: *Game, obj: *Object) i16 {
    return update_list.add(&g.updateList, g.plat, &g.messageBuf, obj);
}

comptime {
    _ = moverInvalidate;
}

/// SceneObject slot 25.
pub fn hide(g: *Game, obj: *Object, bd: *Backdrop) void {
    switch (obj.kind) {
        .moveable, .actor, .player, .portable => moverHide(g, obj, bd),
        else => sceneObjectHide(g, obj, bd),
    }
}

// @orig 1010:17d0 scene_object_hide
/// Erases the object, clears its grid cells, marks it invisible.
fn sceneObjectHide(g: *Game, obj: *Object, bd: *Backdrop) void {
    render.erase(g, obj, bd);
    _ = occupancy.vacate(g, obj, bd);
    obj.visible = 0;
}

// @orig 1010:2c26 mover_hide
/// Restores the background, frees the grid cells, marks invisible and sets
/// the previous position to the current one.
fn moverHide(g: *Game, obj: *Object, bd: *Backdrop) void {
    render.restoreBackground(g, obj, bd, 1);
    _ = occupancy.vacate(g, obj, bd);
    obj.visible = 0;
    obj.mover.prevX = obj.x;
    obj.mover.prevY = obj.y;
}

/// SceneObject slot 26.
pub fn show(g: *Game, obj: *Object, bd: *Backdrop) void {
    switch (obj.kind) {
        .animated, .exit, .control_panel => animated3dShow(g, obj, bd),
        .moveable, .portable => moverShow(g, obj, bd),
        .actor, .player => actorShow(g, obj, bd),
        else => sceneObjectShow(g, obj, bd),
    }
}

// @orig 1010:1822 scene_object_show
/// First frame, drawn into the backdrop bitmap, cells occupied, visible.
/// (The call to FUN_1010_b348 passes the WinG DC to an empty helper.)
fn sceneObjectShow(g: *Game, obj: *Object, bd: *Backdrop) void {
    obj.curFrame = 0;
    render.draw(g, obj, bd);
    _ = occupancy.occupy(g, obj, bd);
    obj.visible = 1;
}

// @orig 1010:35d8 animated3d_show
fn animated3dShow(g: *Game, obj: *Object, bd: *Backdrop) void {
    obj.curFrame = 0;
    sceneObjectShow(g, obj, bd);
}

// @orig 1010:2cac mover_show
fn moverShow(g: *Game, obj: *Object, bd: *Backdrop) void {
    obj.curFrame = 0;
    render.drawDirtyTo(g, obj, &bd.bmiHeader, bd.pixels);
    _ = occupancy.occupy(g, obj, bd);
    obj.visible = 1;
    obj.mover.prevX = obj.x;
    obj.mover.prevY = obj.y;
}

// @orig 1010:4078 actor_show
fn actorShow(g: *Game, obj: *Object, bd: *Backdrop) void {
    obj.curFrame = 0;
    moverShow(g, obj, bd);
}

/// SceneObject slot 58.
pub fn redrawOverlapping(g: *Game, obj: *Object, bd: *Backdrop, flag: i16) void {
    _ = flag;
    switch (obj.kind) {
        // @orig 1010:c36e scene_object_redraw_overlapping_default (absorbed)
        .status_bar => {},
        else => object3dRedrawOverlapping(g, obj, bd),
    }
}

// @orig 1010:5e10 object3d_redraw_overlapping
/// Redraws every visible draw-list object (then the player) whose image
/// overlaps this one, redrawing this object clipped on top when it is in
/// front of it; each hit invalidates this object. Always invalidates it last.
fn object3dRedrawOverlapping(g: *Game, obj: *Object, bd: *Backdrop) void {
    var node = g.drawList.head;
    while (node) |n| : (node = n.next) {
        const other = n.item.?;
        if (other.visible == 0) continue;
        if (other.id == obj.id) continue;
        if (!render.computeOverlap(g, obj, other)) continue;
        render.draw(g, other, bd);
        if (obj.visible != 0 and space3d.isInFrontOf(g, obj, other, bd)) render.drawClip(g, obj, bd);
        _ = invalidate(g, obj);
    }
    if (scene_mod.getHasPlayer(g, g.scene.?)) {
        const player = g.player.?;
        if (obj.id != player.id and movement.isMoving(g, obj) and render.computeOverlap(g, obj, player)) {
            render.draw(g, player, bd);
            if (obj.visible != 0) {
                if (space3d.isInFrontOf(g, obj, player.as(.player).?, bd)) render.drawClip(g, obj, bd);
            }
            _ = invalidate(g, obj);
        }
    }
    _ = invalidate(g, obj);
}
