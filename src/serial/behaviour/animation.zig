//! Port unit `animation` (behaviour) of SERIAL.EXE. SceneObject slots 27-2E 35 37 (frames, play, stopAndRedraw(Dc), tick incl. the Gun's, stop, getTimerId, isRunning), AnimationVtbl playOnce, animation_set_strip.
//!
//! As TIRO's (src/tiro/behaviour/animation.zig): GetDC/ReleaseDC pairs are
//! gone, hwnd and hdc parameters are dropped. Gun, Target and Bullet are
//! Actor2Ds (Animations); the control_panel is an Animated3D (thunks to the
//! Animation methods); the status_bar takes the SceneObject defaults.
//! Unlike TIRO, animation_tick invalidates (slot 1E) instead of blitting
//! (no blitToDc, no GetDC) and animation_set_strip is out of line.

const msg = @import("../../core/msg.zig");
const Game = @import("../core/game.zig").Game;
const object = @import("../core/object.zig");
const Object = object.Object;
const Frame = object.Frame;
const world = @import("../core/world.zig");
const Backdrop = world.Backdrop;
const panels = @import("../panels.zig");
const position = @import("position.zig");
const render = @import("render.zig");
const visibility = @import("visibility.zig");

/// SceneObject slot 27 nextFrame: actor2d_next_frame (gun, target, bullet), animated3d_next_frame (panel) / default.
pub fn nextFrame(g: *Game, obj: *Object) i16 {
    _ = g;
    return switch (obj.kind) {
        // @orig 1088:2b2a actor2d_next_frame
        // @orig 1088:2e6e animated3d_next_frame
        .gun, .target, .bullet, .control_panel => animationNextFrame(obj),
        // scene_object_next_frame_default (absorbed)
        .status_bar => 0,
    };
}

// @orig 1088:24ca animation_next_frame
fn animationNextFrame(obj: *Object) i16 {
    if (position.curStrip(obj).count -% obj.curFrame == 1) {
        obj.curFrame = 0;
    } else {
        obj.curFrame +%= 1;
    }
    return obj.curFrame;
}

/// SceneObject slot 28 prevFrame: actor2d_prev_frame (gun, target, bullet), animated3d_prev_frame (panel) / default.
pub fn prevFrame(g: *Game, obj: *Object) i16 {
    _ = g;
    return switch (obj.kind) {
        // @orig 1088:2b4a actor2d_prev_frame
        // @orig 1088:2e8e animated3d_prev_frame
        .gun, .target, .bullet, .control_panel => animationPrevFrame(obj),
        // scene_object_prev_frame_default (absorbed)
        .status_bar => 0,
    };
}

// @orig 1088:252c animation_prev_frame
fn animationPrevFrame(obj: *Object) i16 {
    if (obj.curFrame == 0) {
        obj.curFrame = position.curStrip(obj).count -% 1;
    } else {
        obj.curFrame -%= 1;
    }
    return obj.curFrame;
}

/// SceneObject slot 29 play (hwnd dropped): gun_play (gun), animation_play (target, bullet), animated3d_play (panel) / default.
pub fn play(g: *Game, obj: *Object, bd: *Backdrop) void {
    switch (obj.kind) {
        // @orig 1068:05d1 gun_play
        .gun => gunPlay(g, obj, bd),
        // @orig 1088:2d94 animated3d_play
        .target, .bullet, .control_panel => animationPlay(g, obj, bd),
        // scene_object_play_default (absorbed)
        .status_bar => {},
    }
}

/// Only re-arms the Mover's timer (this-0x16 id, this-0x14 period):
/// running and playOnce stay as they are.
fn gunPlay(g: *Game, obj: *Object, bd: *Backdrop) void {
    _ = bd;
    g.setSystemTimer(@bitCast(obj.mover.timerId), @bitCast(obj.mover.timerPeriod));
}

// @orig 1028:163d animation_play
fn animationPlay(g: *Game, obj: *Object, bd: *Backdrop) void {
    _ = bd;
    obj.anim.running = 1;
    obj.anim.playOnce = 0;
    g.setSystemTimer(@bitCast(obj.anim.timerId), @bitCast(obj.anim.timerPeriod));
}

/// SceneObject slot 2A playIdle (default only).
pub fn playIdle(g: *Game, obj: *Object, bd: *Backdrop) void {
    // scene_object_play_idle_default (absorbed)
    _ = g;
    _ = obj;
    _ = bd;
}

/// SceneObject slot 2B stopAndRedrawDc (hdc, hwnd dropped): actor2d_stop_and_redraw_dc (gun, target, bullet), animated3d_stop_and_redraw_dc (panel) / default.
pub fn stopAndRedrawDc(g: *Game, obj: *Object, bd: *Backdrop) void {
    switch (obj.kind) {
        // @orig 1088:2a28 actor2d_stop_and_redraw_dc
        .gun, .target, .bullet => {
            _ = setStrip(g, obj, 0, bd);
            animationStopAndRedrawDc(g, obj, bd);
        },
        // @orig 1088:2de0 animated3d_stop_and_redraw_dc
        .control_panel => animationStopAndRedrawDc(g, obj, bd),
        // scene_object_stop_and_redraw_dc_default (absorbed)
        .status_bar => {},
    }
}

// @orig 1028:170b animation_stop_and_redraw_dc
fn animationStopAndRedrawDc(g: *Game, obj: *Object, bd: *Backdrop) void {
    stop(g, obj);
    visibility.redraw(g, obj, bd);
    visibility.invalidate(g, obj);
}

/// SceneObject slot 2C stopAndRedraw: actor2d_stop_and_redraw (gun, target, bullet), animated3d_stop_and_redraw (panel) / default.
pub fn stopAndRedraw(g: *Game, obj: *Object, bd: *Backdrop) void {
    switch (obj.kind) {
        // @orig 1088:29f2 actor2d_stop_and_redraw
        .gun, .target, .bullet => {
            _ = setStrip(g, obj, 0, bd);
            animationStopAndRedraw(g, obj, bd);
        },
        // @orig 1088:2dba animated3d_stop_and_redraw
        .control_panel => animationStopAndRedraw(g, obj, bd),
        // scene_object_stop_and_redraw_default (absorbed)
        .status_bar => {},
    }
}

// @orig 1028:16ba animation_stop_and_redraw
/// GetDC/ReleaseDC dropped around the (virtual) stopAndRedrawDc.
fn animationStopAndRedraw(g: *Game, obj: *Object, bd: *Backdrop) void {
    stopAndRedrawDc(g, obj, bd);
}

/// SceneObject slot 2D tick: gun_tick (gun), animation_tick (target, bullet), control_panel_tick (panel) / default.
pub fn tick(g: *Game, obj: *Object, bd: *Backdrop) void {
    switch (obj.kind) {
        // @orig 1068:05fb gun_tick
        .gun => {
            visibility.redraw(g, obj, bd);
            visibility.blitToDc(g, obj, bd);
        },
        .target, .bullet => animationTick(g, obj, bd),
        .control_panel => panels.tick(g, obj, bd),
        // scene_object_tick_default (absorbed)
        .status_bar => {},
    }
}

// @orig 1028:17b7 animation_tick
/// Timer tick: next frame, rects reset to the whole frame, redraw and
/// invalidate; in play-once mode counts the frame down and stops at zero.
fn animationTick(g: *Game, obj: *Object, bd: *Backdrop) void {
    _ = nextFrame(g, obj);
    render.resetRects(obj);
    visibility.redraw(g, obj, bd);
    visibility.invalidate(g, obj);
    if (obj.anim.playOnce != 0) {
        obj.anim.framesLeft -%= 1;
        if (obj.anim.framesLeft == 0) stop(g, obj);
    }
}

/// SceneObject slot 2E stop: actor2d_stop (gun, target, bullet), animated3d_stop (panel) / default.
pub fn stop(g: *Game, obj: *Object) void {
    switch (obj.kind) {
        // @orig 1088:2b6a actor2d_stop
        // @orig 1088:2eae animated3d_stop
        .gun, .target, .bullet, .control_panel => animationStop(g, obj),
        // scene_object_stop_default (absorbed)
        .status_bar => {},
    }
}

// @orig 1028:1773 animation_stop
fn animationStop(g: *Game, obj: *Object) void {
    obj.anim.playOnce = 0;
    obj.anim.running = 0;
    _ = g.post(.{ .id = msg.noite.animation_finished, .wparam = @bitCast(obj.id) });
    g.killSystemTimer(@bitCast(obj.anim.timerId));
}

/// SceneObject slot 35 getTimerId: actor2d_get_timer_id (gun, target, bullet), animated3d_get_timer_id (panel) / default.
pub fn getTimerId(g: *Game, obj: *Object) i16 {
    _ = g;
    return switch (obj.kind) {
        // @orig 1088:292a actor2d_get_timer_id
        .gun, .target, .bullet => obj.mover.timerId,
        // @orig 1088:2ed0 animated3d_get_timer_id
        .control_panel => animationGetTimerId(obj),
        // scene_object_get_timer_id_default (absorbed)
        .status_bar => -1,
    };
}

// @orig 1088:2588 animation_get_timer_id
fn animationGetTimerId(obj: *Object) i16 {
    return obj.anim.timerId;
}

/// SceneObject slot 37 isRunning: animation_is_running (gun, target, bullet, panel) / default.
pub fn isRunning(g: *Game, obj: *Object) bool {
    _ = g;
    return switch (obj.kind) {
        // @orig 1088:24ae animation_is_running
        .gun, .target, .bullet, .control_panel => obj.anim.running != 0,
        // scene_object_is_running_default (absorbed)
        .status_bar => false,
    };
}

/// AnimationVtbl / ControlPanelVtbl slot 00 playOnce (animation_play_once).
// @orig 1028:1671 animation_play_once
pub fn playOnce(g: *Game, obj: *Object, bd: *Backdrop) void {
    _ = bd;
    obj.anim.running = 1;
    obj.anim.framesLeft = position.frameCount(obj) -% 1;
    obj.anim.playOnce = 1;
    g.setSystemTimer(@bitCast(obj.anim.timerId), @bitCast(obj.anim.timerPeriod));
}

/// Animation::set_strip, out of line. When strip `strip` has another frame
/// size than the current one the object is hidden, switched and shown again
/// (each with an invalidate). Returns the (new) current strip's Frame.
// @orig 1088:37e0 animation_set_strip
pub fn setStrip(g: *Game, obj: *Object, strip: i16, bd: *Backdrop) *Frame {
    const new = &obj.frames[@intCast(strip)];
    const cur = position.curStrip(obj);
    if (cur.width == new.width and cur.height == new.height) {
        obj.curStrip = strip;
        obj.curFrame = 0;
    } else {
        visibility.hide(g, obj, bd);
        visibility.invalidate(g, obj);
        obj.curStrip = strip;
        obj.curFrame = 0;
        visibility.show(g, obj, bd);
        visibility.invalidate(g, obj);
    }
    return position.curStrip(obj);
}
