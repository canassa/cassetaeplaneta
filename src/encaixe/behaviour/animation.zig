//! Port unit `animation` (behaviour) of ENCAIXE.EXE. SceneObject slots 29-30 37 39 (frames, play, playIdle, stopAndRedraw(Dc), tick, stop, getTimerId, isRunning) and AnimationVtbl playOnce.
//!
//! Virtual-slot dispatchers owned by this unit are declared below with
//! their final signatures; their bodies panic until the unit is ported
//! (docs/encaixe/DESIGN.md "Virtual slots"). Replace each body, keep the
//! signature (other units already call it). Each implementation function
//! carries `// @orig <1008:xxxx> <name>` with the ENCAIXE address.

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

/// SceneObject slot 29 nextFrame: Actor2D's (piece), Animated3D's (control_panel).
pub fn nextFrame(g: *Game, obj: *Object) i16 {
    _ = g;
    _ = obj;
    stub.unported("encaixe.animation.nextFrame");
}

/// SceneObject slot 2A prevFrame.
pub fn prevFrame(g: *Game, obj: *Object) i16 {
    _ = g;
    _ = obj;
    stub.unported("encaixe.animation.prevFrame");
}

/// SceneObject slot 2B play (hwnd dropped): Animation's (piece), Animated3D's (control_panel).
pub fn play(g: *Game, obj: *Object, bd: *Backdrop) void {
    _ = g;
    _ = obj;
    _ = bd;
    stub.unported("encaixe.animation.play");
}

/// SceneObject slot 2C playIdle (default only).
pub fn playIdle(g: *Game, obj: *Object, bd: *Backdrop) void {
    _ = g;
    _ = obj;
    _ = bd;
    stub.unported("encaixe.animation.playIdle");
}

/// SceneObject slot 2D stopAndRedrawDc (hdc, hwnd dropped).
pub fn stopAndRedrawDc(g: *Game, obj: *Object, bd: *Backdrop) void {
    _ = g;
    _ = obj;
    _ = bd;
    stub.unported("encaixe.animation.stopAndRedrawDc");
}

/// SceneObject slot 2E stopAndRedraw.
pub fn stopAndRedraw(g: *Game, obj: *Object, bd: *Backdrop) void {
    _ = g;
    _ = obj;
    _ = bd;
    stub.unported("encaixe.animation.stopAndRedraw");
}

/// SceneObject slot 2F tick: Player2D's (piece), ControlPanel's (panels.tick).
pub fn tick(g: *Game, obj: *Object, bd: *Backdrop) void {
    _ = g;
    _ = obj;
    _ = bd;
    stub.unported("encaixe.animation.tick");
}

/// SceneObject slot 30 stop.
pub fn stop(g: *Game, obj: *Object) void {
    _ = g;
    _ = obj;
    stub.unported("encaixe.animation.stop");
}

/// SceneObject slot 37 getTimerId.
pub fn getTimerId(g: *Game, obj: *Object) i16 {
    _ = g;
    _ = obj;
    stub.unported("encaixe.animation.getTimerId");
}

/// SceneObject slot 39 isRunning.
pub fn isRunning(g: *Game, obj: *Object) bool {
    _ = g;
    _ = obj;
    stub.unported("encaixe.animation.isRunning");
}

/// AnimationVtbl / ControlPanelVtbl slot 00 playOnce (animation_play_once).
pub fn playOnce(g: *Game, obj: *Object, bd: *Backdrop) void {
    _ = g;
    _ = obj;
    _ = bd;
    stub.unported("encaixe.animation.playOnce");
}
