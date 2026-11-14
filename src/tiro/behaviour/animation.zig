//! Port unit `animation` (behaviour) of TIRO.EXE. SceneObject slots 27-2E 35 37 (frames, play, stopAndRedraw(Dc), tick incl. Crossbow's and Target's, stop, getTimerId, isRunning), AnimationVtbl playOnce, animation_set_strip.
//!
//! Virtual-slot dispatchers owned by this unit are declared below with
//! their final signatures; their bodies panic until the unit is ported
//! (docs/tiro/DESIGN.md "Virtual slots"). Replace each body, keep the
//! signature (other units already call it). Each implementation function
//! carries `// @orig <seg:xxxx> <name>` with the TIRO address.

const std = @import("std");
const stub = @import("../../core/stub.zig");
const msg = @import("../../core/msg.zig");
const Msg = msg.Msg;
const Game = @import("../core/game.zig").Game;
const object = @import("../core/object.zig");
const Object = object.Object;
const ObjectList = object.ObjectList;
const Frame = object.Frame;
const FrameCell = object.FrameCell;
const BitmapInfoHeader = object.BitmapInfoHeader;
const world = @import("../core/world.zig");
const Backdrop = world.Backdrop;
const Scene = world.Scene;
const Condition = world.Condition;
const RectQuery = world.RectQuery;

/// SceneObject slot 27 nextFrame: actor2d_next_frame (crossbow, target, arrow), animated3d_next_frame (panel) / default.
pub fn nextFrame(g: *Game, obj: *Object) i16 {
    _ = g;
    _ = obj;
    stub.unported("tiro.animation.nextFrame");
}

/// SceneObject slot 28 prevFrame: actor2d_prev_frame (crossbow, target, arrow), animated3d_prev_frame (panel) / default.
pub fn prevFrame(g: *Game, obj: *Object) i16 {
    _ = g;
    _ = obj;
    stub.unported("tiro.animation.prevFrame");
}

/// SceneObject slot 29 play (hwnd dropped): crossbow_play (crossbow), animation_play (target, arrow), animated3d_play (panel) / default.
pub fn play(g: *Game, obj: *Object, bd: *Backdrop) void {
    _ = g;
    _ = obj;
    _ = bd;
    stub.unported("tiro.animation.play");
}

/// SceneObject slot 2A playIdle (default only).
pub fn playIdle(g: *Game, obj: *Object, bd: *Backdrop) void {
    _ = g;
    _ = obj;
    _ = bd;
    stub.unported("tiro.animation.playIdle");
}

/// SceneObject slot 2B stopAndRedrawDc (hdc, hwnd dropped): actor2d_stop_and_redraw_dc (crossbow, target, arrow), animated3d_stop_and_redraw_dc (panel) / default.
pub fn stopAndRedrawDc(g: *Game, obj: *Object, bd: *Backdrop) void {
    _ = g;
    _ = obj;
    _ = bd;
    stub.unported("tiro.animation.stopAndRedrawDc");
}

/// SceneObject slot 2C stopAndRedraw: actor2d_stop_and_redraw (crossbow, target, arrow), animated3d_stop_and_redraw (panel) / default.
pub fn stopAndRedraw(g: *Game, obj: *Object, bd: *Backdrop) void {
    _ = g;
    _ = obj;
    _ = bd;
    stub.unported("tiro.animation.stopAndRedraw");
}

/// SceneObject slot 2D tick: crossbow_tick (crossbow), target_tick (target), animation_tick (arrow), control_panel_tick (panel) / default.
pub fn tick(g: *Game, obj: *Object, bd: *Backdrop) void {
    _ = g;
    _ = obj;
    _ = bd;
    stub.unported("tiro.animation.tick");
}

/// SceneObject slot 2E stop: actor2d_stop (crossbow, target, arrow), animated3d_stop (panel) / default.
pub fn stop(g: *Game, obj: *Object) void {
    _ = g;
    _ = obj;
    stub.unported("tiro.animation.stop");
}

/// SceneObject slot 35 getTimerId: actor2d_get_timer_id (crossbow, target, arrow), animated3d_get_timer_id (panel) / default.
pub fn getTimerId(g: *Game, obj: *Object) i16 {
    _ = g;
    _ = obj;
    stub.unported("tiro.animation.getTimerId");
}

/// SceneObject slot 37 isRunning: animation_is_running (crossbow, target, arrow, panel) / default.
pub fn isRunning(g: *Game, obj: *Object) bool {
    _ = g;
    _ = obj;
    stub.unported("tiro.animation.isRunning");
}

/// AnimationVtbl / ControlPanelVtbl slot 00 playOnce (animation_play_once).
pub fn playOnce(g: *Game, obj: *Object, bd: *Backdrop) void {
    _ = g;
    _ = obj;
    _ = bd;
    stub.unported("tiro.animation.playOnce");
}
