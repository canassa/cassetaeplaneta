//! Port unit `animation` (behaviour) of TIRO.EXE. SceneObject slots 27-2E 35 37 (frames, play, stopAndRedraw(Dc), tick incl. Crossbow's and Target's, stop, getTimerId, isRunning), AnimationVtbl playOnce, animation_set_strip.
//!
//! GetDC/ReleaseDC pairs are gone (the DC is the platform screen); hwnd and
//! hdc parameters are dropped. Crossbow, Target and Arrow are Actor2Ds
//! (Animations); the control_panel is an Animated3D (thunks to the
//! Animation methods); the status_bar takes the SceneObject defaults.
//! Unlike ENCAIXE, animation_set_strip is out of line (`setStrip`) and
//! the Actor2D stop-and-redraw pair calls it.

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

/// SceneObject slot 27 nextFrame: actor2d_next_frame (crossbow, target, arrow), animated3d_next_frame (panel) / default.
pub fn nextFrame(g: *Game, obj: *Object) i16 {
    _ = g;
    return switch (obj.kind) {
        // @orig 1088:2324 actor2d_next_frame
        // @orig 1088:2668 animated3d_next_frame
        .crossbow, .target, .arrow, .control_panel => animationNextFrame(obj),
        // scene_object_next_frame_default (absorbed)
        .status_bar => 0,
    };
}

// @orig 1088:1cc4 animation_next_frame
fn animationNextFrame(obj: *Object) i16 {
    if (position.curStrip(obj).count -% obj.curFrame == 1) {
        obj.curFrame = 0;
    } else {
        obj.curFrame +%= 1;
    }
    return obj.curFrame;
}

/// SceneObject slot 28 prevFrame: actor2d_prev_frame (crossbow, target, arrow), animated3d_prev_frame (panel) / default.
pub fn prevFrame(g: *Game, obj: *Object) i16 {
    _ = g;
    return switch (obj.kind) {
        // @orig 1088:2344 actor2d_prev_frame
        // @orig 1088:2688 animated3d_prev_frame
        .crossbow, .target, .arrow, .control_panel => animationPrevFrame(obj),
        // scene_object_prev_frame_default (absorbed)
        .status_bar => 0,
    };
}

// @orig 1088:1d26 animation_prev_frame
fn animationPrevFrame(obj: *Object) i16 {
    if (obj.curFrame == 0) {
        obj.curFrame = position.curStrip(obj).count -% 1;
    } else {
        obj.curFrame -%= 1;
    }
    return obj.curFrame;
}

/// SceneObject slot 29 play (hwnd dropped): crossbow_play (crossbow), animation_play (target, arrow), animated3d_play (panel) / default.
pub fn play(g: *Game, obj: *Object, bd: *Backdrop) void {
    switch (obj.kind) {
        // @orig 1068:0586 crossbow_play
        .crossbow => crossbowPlay(g, obj, bd),
        // @orig 1088:258e animated3d_play
        .target, .arrow, .control_panel => animationPlay(g, obj, bd),
        // scene_object_play_default (absorbed)
        .status_bar => {},
    }
}

/// Only re-arms the timer: running and playOnce stay as they are.
fn crossbowPlay(g: *Game, obj: *Object, bd: *Backdrop) void {
    _ = bd;
    g.setSystemTimer(@bitCast(obj.anim.timerId), @bitCast(obj.anim.timerPeriod));
}

// @orig 1028:1645 animation_play
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

/// SceneObject slot 2B stopAndRedrawDc (hdc, hwnd dropped): actor2d_stop_and_redraw_dc (crossbow, target, arrow), animated3d_stop_and_redraw_dc (panel) / default.
pub fn stopAndRedrawDc(g: *Game, obj: *Object, bd: *Backdrop) void {
    switch (obj.kind) {
        // @orig 1088:2222 actor2d_stop_and_redraw_dc
        .crossbow, .target, .arrow => {
            _ = setStrip(g, obj, 0, bd);
            animationStopAndRedrawDc(g, obj, bd);
        },
        // @orig 1088:25da animated3d_stop_and_redraw_dc
        .control_panel => animationStopAndRedrawDc(g, obj, bd),
        // scene_object_stop_and_redraw_dc_default (absorbed)
        .status_bar => {},
    }
}

// @orig 1028:1713 animation_stop_and_redraw_dc
fn animationStopAndRedrawDc(g: *Game, obj: *Object, bd: *Backdrop) void {
    stop(g, obj);
    visibility.redraw(g, obj, bd);
    visibility.blitToDc(g, obj, bd);
}

/// SceneObject slot 2C stopAndRedraw: actor2d_stop_and_redraw (crossbow, target, arrow), animated3d_stop_and_redraw (panel) / default.
pub fn stopAndRedraw(g: *Game, obj: *Object, bd: *Backdrop) void {
    switch (obj.kind) {
        // @orig 1088:21ec actor2d_stop_and_redraw
        .crossbow, .target, .arrow => {
            _ = setStrip(g, obj, 0, bd);
            animationStopAndRedraw(g, obj, bd);
        },
        // @orig 1088:25b4 animated3d_stop_and_redraw
        .control_panel => animationStopAndRedraw(g, obj, bd),
        // scene_object_stop_and_redraw_default (absorbed)
        .status_bar => {},
    }
}

// @orig 1028:16c2 animation_stop_and_redraw
/// GetDC/ReleaseDC dropped around the (virtual) stopAndRedrawDc.
fn animationStopAndRedraw(g: *Game, obj: *Object, bd: *Backdrop) void {
    stopAndRedrawDc(g, obj, bd);
}

/// SceneObject slot 2D tick: crossbow_tick (crossbow), target_tick (target), animation_tick (arrow), control_panel_tick (panel) / default.
pub fn tick(g: *Game, obj: *Object, bd: *Backdrop) void {
    switch (obj.kind) {
        // @orig 1068:05b0 crossbow_tick
        .crossbow => {
            visibility.redraw(g, obj, bd);
            visibility.blitToDc(g, obj, bd);
        },
        // @orig 1068:07f4 target_tick
        .target => {
            _ = nextFrame(g, obj);
            visibility.redraw(g, obj, bd);
            visibility.redrawOverlapping(g, obj, bd, 1);
            visibility.blitToDc(g, obj, bd);
        },
        .arrow => animationTick(g, obj, bd),
        .control_panel => panels.tick(g, obj, bd),
        // scene_object_tick_default (absorbed)
        .status_bar => {},
    }
}

// @orig 1028:17c5 animation_tick
/// Timer tick: next frame, rects reset to the whole frame, redraw and blit;
/// in play-once mode counts the frame down and stops at zero.
fn animationTick(g: *Game, obj: *Object, bd: *Backdrop) void {
    _ = nextFrame(g, obj);
    render.resetRects(obj);
    visibility.redraw(g, obj, bd);
    visibility.blitToDc(g, obj, bd);
    if (obj.anim.playOnce != 0) {
        obj.anim.framesLeft -%= 1;
        if (obj.anim.framesLeft == 0) stop(g, obj);
    }
}

/// SceneObject slot 2E stop: actor2d_stop (crossbow, target, arrow), animated3d_stop (panel) / default.
pub fn stop(g: *Game, obj: *Object) void {
    switch (obj.kind) {
        // @orig 1088:2364 actor2d_stop
        // @orig 1088:26a8 animated3d_stop
        .crossbow, .target, .arrow, .control_panel => animationStop(g, obj),
        // scene_object_stop_default (absorbed)
        .status_bar => {},
    }
}

// @orig 1028:1781 animation_stop
fn animationStop(g: *Game, obj: *Object) void {
    obj.anim.playOnce = 0;
    obj.anim.running = 0;
    _ = g.post(.{ .id = msg.noite.animation_finished, .wparam = @bitCast(obj.id) });
    g.killSystemTimer(@bitCast(obj.anim.timerId));
}

/// SceneObject slot 35 getTimerId: actor2d_get_timer_id (crossbow, target, arrow), animated3d_get_timer_id (panel) / default.
pub fn getTimerId(g: *Game, obj: *Object) i16 {
    _ = g;
    return switch (obj.kind) {
        // @orig 1088:2124 actor2d_get_timer_id
        .crossbow, .target, .arrow => obj.mover.timerId,
        // @orig 1088:26ca animated3d_get_timer_id
        .control_panel => animationGetTimerId(obj),
        // scene_object_get_timer_id_default (absorbed)
        .status_bar => -1,
    };
}

// @orig 1088:1d82 animation_get_timer_id
fn animationGetTimerId(obj: *Object) i16 {
    return obj.anim.timerId;
}

/// SceneObject slot 37 isRunning: animation_is_running (crossbow, target, arrow, panel) / default.
pub fn isRunning(g: *Game, obj: *Object) bool {
    _ = g;
    return switch (obj.kind) {
        // @orig 1088:1ca8 animation_is_running
        .crossbow, .target, .arrow, .control_panel => obj.anim.running != 0,
        // scene_object_is_running_default (absorbed)
        .status_bar => false,
    };
}

/// AnimationVtbl / ControlPanelVtbl slot 00 playOnce (animation_play_once).
// @orig 1028:1679 animation_play_once
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
// @orig 1088:2fda animation_set_strip
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
