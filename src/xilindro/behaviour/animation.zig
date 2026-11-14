//! Port unit `animation` (behaviour) of XILINDRO.EXE. SceneObject slots 27-2E 35 37 (frames, play, stopAndRedraw(Dc), tick incl. the Fighter's and the Opponent's, stop, getTimerId, isRunning), AnimationVtbl playOnce, animation_set_strip.
//!
//! As SERIAL's (src/salgin/behaviour/animation.zig) and TIRO's: GetDC/
//! ReleaseDC pairs are gone, hwnd and hdc parameters are dropped. Fighter,
//! Opponent, Banner and EnergyBar are Actor2Ds (Animations); the
//! control_panel is an Animated3D (thunks to the Animation methods); the
//! status_bar takes the SceneObject defaults. Like SERIAL's (unlike TIRO's)
//! animation_tick invalidates (slot 1E) instead of blitting. The Fighter and
//! the Opponent have their own ticks (no redraw, no invalidate: nextFrame,
//! running = 1, playOnce countdown); play is the Animation's for every kind.

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

/// SceneObject slot 27 nextFrame: actor2d_next_frame (fighter, opponent, banner, energy_bar), animated3d_next_frame (panel) / default.
pub fn nextFrame(g: *Game, obj: *Object) i16 {
    _ = g;
    return switch (obj.kind) {
        // @orig 1088:2324 actor2d_next_frame
        // @orig 1088:2668 animated3d_next_frame
        .fighter, .opponent, .banner, .energy_bar, .control_panel => animationNextFrame(obj),
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

/// SceneObject slot 28 prevFrame: actor2d_prev_frame (fighter, opponent, banner, energy_bar), animated3d_prev_frame (panel) / default.
pub fn prevFrame(g: *Game, obj: *Object) i16 {
    _ = g;
    return switch (obj.kind) {
        // @orig 1088:2344 actor2d_prev_frame
        // @orig 1088:2688 animated3d_prev_frame
        .fighter, .opponent, .banner, .energy_bar, .control_panel => animationPrevFrame(obj),
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

/// SceneObject slot 29 play (hwnd dropped): animation_play (fighter, opponent, banner, energy_bar), animated3d_play (panel) / default.
pub fn play(g: *Game, obj: *Object, bd: *Backdrop) void {
    switch (obj.kind) {
        // @orig 1088:258e animated3d_play
        .fighter, .opponent, .banner, .energy_bar, .control_panel => animationPlay(g, obj, bd),
        // scene_object_play_default (absorbed)
        .status_bar => {},
    }
}

// @orig 1028:161f animation_play
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

/// SceneObject slot 2B stopAndRedrawDc (hdc, hwnd dropped): actor2d_stop_and_redraw_dc (fighter, opponent, banner, energy_bar), animated3d_stop_and_redraw_dc (panel) / default.
pub fn stopAndRedrawDc(g: *Game, obj: *Object, bd: *Backdrop) void {
    switch (obj.kind) {
        // @orig 1088:2222 actor2d_stop_and_redraw_dc
        .fighter, .opponent, .banner, .energy_bar => {
            _ = setStrip(g, obj, 0, bd);
            animationStopAndRedrawDc(g, obj, bd);
        },
        // @orig 1088:25da animated3d_stop_and_redraw_dc
        .control_panel => animationStopAndRedrawDc(g, obj, bd),
        // scene_object_stop_and_redraw_dc_default (absorbed)
        .status_bar => {},
    }
}

// @orig 1028:16ed animation_stop_and_redraw_dc
fn animationStopAndRedrawDc(g: *Game, obj: *Object, bd: *Backdrop) void {
    stop(g, obj);
    visibility.redraw(g, obj, bd);
    visibility.invalidate(g, obj);
}

/// SceneObject slot 2C stopAndRedraw: actor2d_stop_and_redraw (fighter, opponent, banner, energy_bar), animated3d_stop_and_redraw (panel) / default.
pub fn stopAndRedraw(g: *Game, obj: *Object, bd: *Backdrop) void {
    switch (obj.kind) {
        // @orig 1088:21ec actor2d_stop_and_redraw
        .fighter, .opponent, .banner, .energy_bar => {
            _ = setStrip(g, obj, 0, bd);
            animationStopAndRedraw(g, obj, bd);
        },
        // @orig 1088:25b4 animated3d_stop_and_redraw
        .control_panel => animationStopAndRedraw(g, obj, bd),
        // scene_object_stop_and_redraw_default (absorbed)
        .status_bar => {},
    }
}

// @orig 1028:169c animation_stop_and_redraw
/// GetDC/ReleaseDC dropped around the (virtual) stopAndRedrawDc.
fn animationStopAndRedraw(g: *Game, obj: *Object, bd: *Backdrop) void {
    stopAndRedrawDc(g, obj, bd);
}

/// SceneObject slot 2D tick: fighter_tick (fighter), opponent_tick (opponent), animation_tick (banner, energy_bar), control_panel_tick (panel) / default.
pub fn tick(g: *Game, obj: *Object, bd: *Backdrop) void {
    switch (obj.kind) {
        // @orig 1068:0546 fighter_tick
        // @orig 1068:08dc opponent_tick
        .fighter, .opponent => stepTick(g, obj),
        .banner, .energy_bar => animationTick(g, obj, bd),
        .control_panel => panels.tick(g, obj, bd),
        // scene_object_tick_default (absorbed)
        .status_bar => {},
    }
}

/// fighter_tick / opponent_tick (same code, other offsets): next frame,
/// running = 1, and in play-once mode the framesLeft countdown to stop. No
/// redraw, no invalidate: the scene handler calls it by hand on its beat.
fn stepTick(g: *Game, obj: *Object) void {
    _ = nextFrame(g, obj);
    obj.anim.running = 1;
    if (obj.anim.playOnce != 0) {
        obj.anim.framesLeft -%= 1;
        if (obj.anim.framesLeft == 0) stop(g, obj);
    }
}

// @orig 1028:1799 animation_tick
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

/// SceneObject slot 2E stop: actor2d_stop (fighter, opponent, banner, energy_bar), animated3d_stop (panel) / default.
pub fn stop(g: *Game, obj: *Object) void {
    switch (obj.kind) {
        // @orig 1088:2364 actor2d_stop
        // @orig 1088:26a8 animated3d_stop
        .fighter, .opponent, .banner, .energy_bar, .control_panel => animationStop(g, obj),
        // scene_object_stop_default (absorbed)
        .status_bar => {},
    }
}

// @orig 1028:1755 animation_stop
fn animationStop(g: *Game, obj: *Object) void {
    obj.anim.playOnce = 0;
    obj.anim.running = 0;
    _ = g.post(.{ .id = msg.noite.animation_finished, .wparam = @bitCast(obj.id) });
    g.killSystemTimer(@bitCast(obj.anim.timerId));
}

/// SceneObject slot 35 getTimerId: actor2d_get_timer_id (fighter, opponent, banner, energy_bar), animated3d_get_timer_id (panel) / default.
pub fn getTimerId(g: *Game, obj: *Object) i16 {
    _ = g;
    return switch (obj.kind) {
        // @orig 1088:2124 actor2d_get_timer_id
        .fighter, .opponent, .banner, .energy_bar => obj.mover.timerId,
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

/// SceneObject slot 37 isRunning: animation_is_running (fighter, opponent, banner, energy_bar, panel) / default.
pub fn isRunning(g: *Game, obj: *Object) bool {
    _ = g;
    return switch (obj.kind) {
        // @orig 1088:1ca8 animation_is_running
        .fighter, .opponent, .banner, .energy_bar, .control_panel => obj.anim.running != 0,
        // scene_object_is_running_default (absorbed)
        .status_bar => false,
    };
}

/// AnimationVtbl / ControlPanelVtbl slot 00 playOnce (animation_play_once).
// @orig 1028:1653 animation_play_once
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
