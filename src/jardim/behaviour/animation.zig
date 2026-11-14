//! Port unit `animation` (behaviour) of JARDIM.EXE. SceneObject slots 2C-33 3A 3C (frames, play, stopAndRedraw(Dc), tick incl. the Exit's, stop, getTimerId, isRunning), AnimationVtbl 00-05, animation_set_strip, exit_has_key_object.
//!
//! Virtual-slot dispatchers owned by this unit are declared below with
//! their final signatures; their bodies panic until the unit is ported
//! (docs/jardim/DESIGN.md "Virtual slots"). Replace each body, keep the
//! signature (other units already call it). Each implementation function
//! carries `// @orig <seg:xxxx> <name>` with the JARDIM address.

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

/// SceneObject slot 2C nextFrame: animated3d_next_frame (exit, player, control_panel) / default.
pub fn nextFrame(g: *Game, obj: *Object) i16 {
    _ = g;
    _ = obj;
    stub.unported("jardim.animation.nextFrame");
}

/// SceneObject slot 2D prevFrame: animated3d_prev_frame (exit, player, control_panel) / default.
pub fn prevFrame(g: *Game, obj: *Object) i16 {
    _ = g;
    _ = obj;
    stub.unported("jardim.animation.prevFrame");
}

/// SceneObject slot 2E play (hwnd dropped): exit_play (exit), animated3d_play (player, control_panel) / default.
pub fn play(g: *Game, obj: *Object, bd: *Backdrop) void {
    _ = g;
    _ = obj;
    _ = bd;
    stub.unported("jardim.animation.play");
}

/// SceneObject slot 2F playIdle (default only).
pub fn playIdle(g: *Game, obj: *Object, bd: *Backdrop) void {
    _ = g;
    _ = obj;
    _ = bd;
    stub.unported("jardim.animation.playIdle");
}

/// SceneObject slot 30 stopAndRedrawDc (hdc, hwnd dropped): animated3d_stop_and_redraw_dc (exit, control_panel), actor_stop_and_redraw_dc (player) / default.
pub fn stopAndRedrawDc(g: *Game, obj: *Object, bd: *Backdrop) void {
    _ = g;
    _ = obj;
    _ = bd;
    stub.unported("jardim.animation.stopAndRedrawDc");
}

/// SceneObject slot 31 stopAndRedraw: animated3d_stop_and_redraw (exit, control_panel), actor_stop_and_redraw (player) / default.
pub fn stopAndRedraw(g: *Game, obj: *Object, bd: *Backdrop) void {
    _ = g;
    _ = obj;
    _ = bd;
    stub.unported("jardim.animation.stopAndRedraw");
}

/// SceneObject slot 32 tick: exit_tick (exit), player_tick (player), control_panel_tick (control_panel) / default.
pub fn tick(g: *Game, obj: *Object, bd: *Backdrop) void {
    _ = g;
    _ = obj;
    _ = bd;
    stub.unported("jardim.animation.tick");
}

/// SceneObject slot 33 stop: animated3d_stop (exit, player, control_panel) / default.
pub fn stop(g: *Game, obj: *Object) void {
    _ = g;
    _ = obj;
    stub.unported("jardim.animation.stop");
}

/// SceneObject slot 3A getTimerId: moveable_get_timer_id (portable), animated3d_get_timer_id (exit, control_panel), actor_get_timer_id (player) / default.
pub fn getTimerId(g: *Game, obj: *Object) i16 {
    _ = g;
    _ = obj;
    stub.unported("jardim.animation.getTimerId");
}

/// SceneObject slot 3C isRunning: animation_is_running (exit, player, control_panel) / default.
pub fn isRunning(g: *Game, obj: *Object) bool {
    _ = g;
    _ = obj;
    stub.unported("jardim.animation.isRunning");
}

/// AnimationVtbl / ControlPanelVtbl slot 00 lock (animation_lock).
pub fn lock(g: *Game, obj: *Object) void {
    _ = g;
    _ = obj;
    stub.unported("jardim.animation.lock");
}

/// AnimationVtbl / ControlPanelVtbl slot 01 isLocked (animation_is_locked).
pub fn isLocked(g: *Game, obj: *Object) bool {
    _ = g;
    _ = obj;
    stub.unported("jardim.animation.isLocked");
}

/// AnimationVtbl / ControlPanelVtbl slot 02 (animation_slot02_stub: isLocked, then 0; NOITE's AVI slot).
pub fn slot02(g: *Game, obj: *Object) i16 {
    _ = g;
    _ = obj;
    stub.unported("jardim.animation.slot02");
}

/// AnimationVtbl / ControlPanelVtbl slot 03 (animation_slot03_stub: isLocked, then 0; NOITE's AVI slot).
pub fn slot03(g: *Game, obj: *Object) i16 {
    _ = g;
    _ = obj;
    stub.unported("jardim.animation.slot03");
}

/// AnimationVtbl / ControlPanelVtbl slot 04 (animation_slot04_stub: isLocked, then 0; NOITE's AVI slot).
pub fn slot04(g: *Game, obj: *Object) i16 {
    _ = g;
    _ = obj;
    stub.unported("jardim.animation.slot04");
}

/// AnimationVtbl / ControlPanelVtbl slot 05 playOnce (animation_play_once; hwnd dropped).
pub fn playOnce(g: *Game, obj: *Object, bd: *Backdrop) void {
    _ = g;
    _ = obj;
    _ = bd;
    stub.unported("jardim.animation.playOnce");
}
