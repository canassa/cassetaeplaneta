//! Port unit `animation` (behaviour) of SAUNA.EXE. SceneObject slots 2D-34 3B 3D (frames, play, playIdle incl. Pacman's, stopAndRedraw(Dc) incl. Pacman's, tick incl. Pacman's, stop, getTimerId, isRunning), AnimationVtbl 00-05 (the AVI stubs, playOnce), PacmanVtbl refreshPowerStrip (BUGS.md P4), animation_set_strip.
//!
//! Virtual-slot dispatchers owned by this unit are declared below with
//! their final signatures; their bodies panic until the unit is ported
//! (docs/sauna/DESIGN.md "Virtual slots"). Replace each body, keep the
//! signature (other units already call it). Each implementation function
//! carries `// @orig <seg:xxxx> <name>` with the SAUNA address.

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

/// SceneObject slot 2D nextFrame: animated3d_next_frame (panel), actor2d_next_frame (pacman, ghost) / default.
pub fn nextFrame(g: *Game, obj: *Object) i16 {
    _ = g;
    _ = obj;
    stub.unported("sauna.animation.nextFrame");
}

/// SceneObject slot 2E prevFrame: animated3d_prev_frame (panel), actor2d_prev_frame (pacman, ghost) / default.
pub fn prevFrame(g: *Game, obj: *Object) i16 {
    _ = g;
    _ = obj;
    stub.unported("sauna.animation.prevFrame");
}

/// SceneObject slot 2F play (hwnd dropped): animated3d_play (panel), animation_play (pacman, ghost) / default.
pub fn play(g: *Game, obj: *Object, bd: *Backdrop) void {
    _ = g;
    _ = obj;
    _ = bd;
    stub.unported("sauna.animation.play");
}

/// SceneObject slot 30 playIdle: pacman_play_idle (pacman) / default.
pub fn playIdle(g: *Game, obj: *Object, bd: *Backdrop) void {
    _ = g;
    _ = obj;
    _ = bd;
    stub.unported("sauna.animation.playIdle");
}

/// SceneObject slot 31 stopAndRedrawDc (hdc, hwnd dropped): animated3d_stop_and_redraw_dc (panel), pacman_stop_and_redraw_dc (pacman), actor2d_stop_and_redraw_dc (ghost) / default.
pub fn stopAndRedrawDc(g: *Game, obj: *Object, bd: *Backdrop) void {
    _ = g;
    _ = obj;
    _ = bd;
    stub.unported("sauna.animation.stopAndRedrawDc");
}

/// SceneObject slot 32 stopAndRedraw: animated3d_stop_and_redraw (panel), pacman_stop_and_redraw (pacman), actor2d_stop_and_redraw (ghost) / default.
pub fn stopAndRedraw(g: *Game, obj: *Object, bd: *Backdrop) void {
    _ = g;
    _ = obj;
    _ = bd;
    stub.unported("sauna.animation.stopAndRedraw");
}

/// SceneObject slot 33 tick: control_panel_tick (panel), pacman_tick (pacman), animation_tick (ghost) / default.
pub fn tick(g: *Game, obj: *Object, bd: *Backdrop) void {
    _ = g;
    _ = obj;
    _ = bd;
    stub.unported("sauna.animation.tick");
}

/// SceneObject slot 34 stop: animated3d_stop (panel), actor2d_stop (pacman, ghost) / default.
pub fn stop(g: *Game, obj: *Object) void {
    _ = g;
    _ = obj;
    stub.unported("sauna.animation.stop");
}

/// SceneObject slot 3B getTimerId: animated3d_get_timer_id (panel), actor2d_get_timer_id (pacman, ghost) / default.
pub fn getTimerId(g: *Game, obj: *Object) i16 {
    _ = g;
    _ = obj;
    stub.unported("sauna.animation.getTimerId");
}

/// SceneObject slot 3D isRunning: animation_is_running (panel, pacman, ghost) / default.
pub fn isRunning(g: *Game, obj: *Object) bool {
    _ = g;
    _ = obj;
    stub.unported("sauna.animation.isRunning");
}

/// AnimationVtbl / ControlPanelVtbl slot 00 setAvi (animation_set_avi: Animation+0x14 = 1; nothing live calls it).
pub fn setAvi(g: *Game, obj: *Object) void {
    _ = g;
    _ = obj;
    stub.unported("sauna.animation.setAvi");
}

/// AnimationVtbl / ControlPanelVtbl slot 01 isAvi (animation_is_avi).
pub fn isAvi(g: *Game, obj: *Object) bool {
    _ = g;
    _ = obj;
    stub.unported("sauna.animation.isAvi");
}

/// AnimationVtbl / ControlPanelVtbl slot 02 aviSlot2 (animation_avi_slot2: calls isAvi, returns 0).
pub fn aviSlot2(g: *Game, obj: *Object) i16 {
    _ = g;
    _ = obj;
    stub.unported("sauna.animation.aviSlot2");
}

/// AnimationVtbl / ControlPanelVtbl slot 03 aviSlot3 (animation_avi_slot3: calls isAvi, returns 0).
pub fn aviSlot3(g: *Game, obj: *Object) i16 {
    _ = g;
    _ = obj;
    stub.unported("sauna.animation.aviSlot3");
}

/// AnimationVtbl / ControlPanelVtbl slot 04 aviSlot4 (animation_avi_slot4: calls isAvi, returns 0).
pub fn aviSlot4(g: *Game, obj: *Object) i16 {
    _ = g;
    _ = obj;
    stub.unported("sauna.animation.aviSlot4");
}

/// AnimationVtbl / ControlPanelVtbl slot 05 playOnce (animation_play_once).
pub fn playOnce(g: *Game, obj: *Object, bd: *Backdrop) void {
    _ = g;
    _ = obj;
    _ = bd;
    stub.unported("sauna.animation.playOnce");
}

/// PacmanVtbl slot 01 refreshPowerStrip (pacman_refresh_power_strip; hwnd dropped): strip g_powerStrip + (dir == 2 ? 1 : 2), then play (BUGS.md P4: every caller passes 2).
pub fn refreshPowerStrip(g: *Game, obj: *Object, bd: *Backdrop, dir: i16) void {
    _ = g;
    _ = obj;
    _ = bd;
    _ = dir;
    stub.unported("sauna.animation.refreshPowerStrip");
}
