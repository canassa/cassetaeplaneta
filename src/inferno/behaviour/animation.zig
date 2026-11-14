//! Port unit `animation` (behaviour) of INFERNO.EXE. SceneObject slots 27-2E
//! 35 37 (frames, play, playIdle, stopAndRedraw(Dc), tick, stop, getTimerId,
//! isRunning), AnimationVtbl playOnce, animation_set_strip.
//!
//! Virtual-slot dispatchers owned by this unit are declared below with
//! their final signatures; their bodies panic until the unit is ported
//! (docs/inferno/DESIGN.md "Virtual slots"). Replace each body, keep the
//! signature (other units already call it). Each implementation function
//! carries `// @orig <seg:xxxx> <name>` with the INFERNO address.

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

/// SceneObject slot 27 nextFrame: actor2d_next_frame (every kind).
pub fn nextFrame(g: *Game, obj: *Object) i16 {
    _ = g;
    _ = obj;
    stub.unported("inferno.animation.nextFrame");
}

/// SceneObject slot 28 prevFrame: actor2d_prev_frame (every kind).
pub fn prevFrame(g: *Game, obj: *Object) i16 {
    _ = g;
    _ = obj;
    stub.unported("inferno.animation.prevFrame");
}

/// SceneObject slot 29 play: hero.play (hero), ledge.play (platform),
/// animation_play (prop, hazard).
pub fn play(g: *Game, obj: *Object, bd: *Backdrop) void {
    _ = g;
    _ = obj;
    _ = bd;
    stub.unported("inferno.animation.play");
}

/// SceneObject slot 2A playIdle: default only.
pub fn playIdle(g: *Game, obj: *Object, bd: *Backdrop) void {
    _ = g;
    _ = obj;
    _ = bd;
    stub.unported("inferno.animation.playIdle");
}

/// SceneObject slot 2B stopAndRedrawDc: actor2d_stop_and_redraw_dc (every
/// kind).
pub fn stopAndRedrawDc(g: *Game, obj: *Object, bd: *Backdrop) void {
    _ = g;
    _ = obj;
    _ = bd;
    stub.unported("inferno.animation.stopAndRedrawDc");
}

/// SceneObject slot 2C stopAndRedraw: actor2d_stop_and_redraw (every kind).
pub fn stopAndRedraw(g: *Game, obj: *Object, bd: *Backdrop) void {
    _ = g;
    _ = obj;
    _ = bd;
    stub.unported("inferno.animation.stopAndRedraw");
}

/// SceneObject slot 2D tick: hero.tick (hero), animation_tick (platform,
/// prop, hazard).
pub fn tick(g: *Game, obj: *Object, bd: *Backdrop) void {
    _ = g;
    _ = obj;
    _ = bd;
    stub.unported("inferno.animation.tick");
}

/// SceneObject slot 2E stop: actor2d_stop (every kind).
pub fn stop(g: *Game, obj: *Object) void {
    _ = g;
    _ = obj;
    stub.unported("inferno.animation.stop");
}

/// SceneObject slot 35 getTimerId: actor2d_get_timer_id (every kind).
pub fn getTimerId(g: *Game, obj: *Object) i16 {
    _ = g;
    _ = obj;
    stub.unported("inferno.animation.getTimerId");
}

/// SceneObject slot 37 isRunning: animation_is_running (every kind).
pub fn isRunning(g: *Game, obj: *Object) bool {
    _ = g;
    _ = obj;
    stub.unported("inferno.animation.isRunning");
}

/// AnimationVtbl slot 00 playOnce (animation_play_once, every table).
pub fn playOnce(g: *Game, obj: *Object, bd: *Backdrop) void {
    _ = g;
    _ = obj;
    _ = bd;
    stub.unported("inferno.animation.playOnce");
}
