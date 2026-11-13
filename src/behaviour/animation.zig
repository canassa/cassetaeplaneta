//! Port unit `animation` (behaviour). SceneObject slots 2D-2F, 31-33, 35, 36, 3D, 3F and Animation playOnce/setStrip: frames, idle, stop, timer id.
//!
//! The GetDC/ReleaseDC pairs of the originals are gone (the DC is the
//! platform screen); `hwnd` and `hdc` parameters are dropped. The
//! originals' `Animated3D`/`Actor` wrappers that only forward to a base
//! implementation keep their own functions (and `@orig` tags) so the call
//! structure stays the same.

const Game = @import("../core/game.zig").Game;
const msg = @import("../core/msg.zig");
const object = @import("../core/object.zig");
const Object = object.Object;
const Frame = object.Frame;
const world = @import("../core/world.zig");
const Backdrop = world.Backdrop;
const avi = @import("../avi.zig");
const frames = @import("../frames.zig");
const tick = @import("tick.zig");
const visibility = @import("visibility.zig");

/// SceneObject slot 2D: is the animation an AVI clip.
pub fn isAvi(g: *Game, obj: *Object) bool {
    _ = .{g};
    return switch (obj.kind) {
        // @orig 1010:1ab0 scene_object_is_avi_default (absorbed)
        .local, .moveable, .portable, .status_bar => false,
        .animated, .actor, .player, .exit, .control_panel => animationIsAvi(obj),
    };
}

// @orig 1010:20a8 animation_is_avi
fn animationIsAvi(obj: *Object) bool {
    return obj.anim.isAvi != 0;
}

/// SceneObject slot 2E: next frame of the current strip, wrapping to 0.
pub fn nextFrame(g: *Game, obj: *Object) i16 {
    _ = .{g};
    return switch (obj.kind) {
        // @orig 1010:1abc scene_object_next_frame_default (absorbed)
        .local, .moveable, .status_bar => 0,
        .animated, .actor, .player, .exit, .control_panel => animated3dNextFrame(obj),
        .portable => portableNextFrame(obj),
    };
}

// @orig 1010:3614 animated3d_next_frame
fn animated3dNextFrame(obj: *Object) i16 {
    return animationNextFrame(obj);
}

// @orig 1010:25f4 animation_next_frame
fn animationNextFrame(obj: *Object) i16 {
    if (obj.curFrame -% frames.curStrip(obj).count == -1) {
        obj.curFrame = 0;
    } else {
        obj.curFrame +%= 1;
    }
    return obj.curFrame;
}

// @orig 1010:42a2 portable_next_frame
fn portableNextFrame(obj: *Object) i16 {
    if (obj.curFrame -% frames.curStrip(obj).count == -1) {
        obj.curFrame = 0;
    } else {
        obj.curFrame +%= 1;
    }
    return obj.curFrame;
}

/// SceneObject slot 2F: previous frame of the current strip, wrapping to the last.
pub fn prevFrame(g: *Game, obj: *Object) i16 {
    _ = .{g};
    return switch (obj.kind) {
        // @orig 1010:1ac8 scene_object_prev_frame_default (absorbed)
        .local, .moveable, .status_bar => 0,
        .animated, .actor, .player, .exit, .control_panel => animated3dPrevFrame(obj),
        .portable => portablePrevFrame(obj),
    };
}

// @orig 1010:362c animated3d_prev_frame
fn animated3dPrevFrame(obj: *Object) i16 {
    return animationPrevFrame(obj);
}

// @orig 1010:2660 animation_prev_frame
fn animationPrevFrame(obj: *Object) i16 {
    if (obj.curFrame == 0) {
        obj.curFrame = frames.curStrip(obj).count -% 1;
    } else {
        obj.curFrame -%= 1;
    }
    return obj.curFrame;
}

// @orig 1010:430c portable_prev_frame
fn portablePrevFrame(obj: *Object) i16 {
    if (obj.curFrame == 0) {
        obj.curFrame = frames.curStrip(obj).count -% 1;
    } else {
        obj.curFrame -%= 1;
    }
    return obj.curFrame;
}

/// SceneObject slot 31: start the idle pose.
pub fn playIdle(g: *Game, obj: *Object, bd: *Backdrop) void {
    switch (obj.kind) {
        // @orig 1010:1ade scene_object_play_idle_default (absorbed)
        .local, .animated, .moveable, .actor, .exit, .portable, .control_panel, .status_bar => {},
        .player => directionalPlayerPlayIdle(g, obj, bd),
    }
}

// @orig 1010:e59e directional_player_play_idle
/// Strip 3 (facing the camera), looping.
fn directionalPlayerPlayIdle(g: *Game, obj: *Object, bd: *Backdrop) void {
    _ = setStrip(g, obj, 3, bd);
    tick.play(g, obj, bd);
}

/// SceneObject slot 32: stop and redraw with a given DC.
pub fn stopAndRedrawDc(g: *Game, obj: *Object, bd: *Backdrop) void {
    switch (obj.kind) {
        // @orig 1010:1af2 scene_object_stop_and_redraw_dc_default (absorbed)
        .local, .moveable, .portable, .status_bar => {},
        .animated, .exit, .control_panel => animated3dStopAndRedrawDc(g, obj, bd),
        .actor => actorStopAndRedrawDc(g, obj, bd),
        .player => directionalPlayerStopAndRedrawDc(g, obj, bd),
    }
}

// @orig 1010:3588 animated3d_stop_and_redraw_dc
fn animated3dStopAndRedrawDc(g: *Game, obj: *Object, bd: *Backdrop) void {
    animationStopAndRedrawDc(g, obj, bd);
}

// @orig 1010:d036 animation_stop_and_redraw_dc
/// Stops, then redraws the object and invalidates it.
fn animationStopAndRedrawDc(g: *Game, obj: *Object, bd: *Backdrop) void {
    stop(g, obj);
    visibility.redraw(g, obj, bd);
    _ = visibility.invalidate(g, obj);
}

// @orig 1010:40fc actor_stop_and_redraw_dc
/// Standing pose (strip 0), then the Animated3D stop-and-redraw.
fn actorStopAndRedrawDc(g: *Game, obj: *Object, bd: *Backdrop) void {
    _ = setStrip(g, obj, 0, bd);
    animated3dStopAndRedrawDc(g, obj, bd);
}

// @orig 1010:e870 directional_player_stop_and_redraw_dc
/// The Actor one, then the (virtual) idle pose.
fn directionalPlayerStopAndRedrawDc(g: *Game, obj: *Object, bd: *Backdrop) void {
    actorStopAndRedrawDc(g, obj, bd);
    playIdle(g, obj, bd);
}

/// SceneObject slot 33: stop and redraw.
pub fn stopAndRedraw(g: *Game, obj: *Object, bd: *Backdrop) void {
    switch (obj.kind) {
        // @orig 1010:1ae8 scene_object_stop_and_redraw_default (absorbed)
        .local, .moveable, .portable, .status_bar => {},
        .animated, .exit, .control_panel => animated3dStopAndRedraw(g, obj, bd),
        .actor => actorStopAndRedraw(g, obj, bd),
        .player => directionalPlayerStopAndRedraw(g, obj, bd),
    }
}

// @orig 1010:356a animated3d_stop_and_redraw
fn animated3dStopAndRedraw(g: *Game, obj: *Object, bd: *Backdrop) void {
    animationStopAndRedraw(g, obj, bd);
}

// @orig 1010:cfe6 animation_stop_and_redraw
/// Calls the (virtual) stopAndRedrawDc.
fn animationStopAndRedraw(g: *Game, obj: *Object, bd: *Backdrop) void {
    stopAndRedrawDc(g, obj, bd);
}

// @orig 1010:40b2 actor_stop_and_redraw
fn actorStopAndRedraw(g: *Game, obj: *Object, bd: *Backdrop) void {
    _ = setStrip(g, obj, 0, bd);
    animated3dStopAndRedraw(g, obj, bd);
}

// @orig 1010:e8c8 directional_player_stop_and_redraw
fn directionalPlayerStopAndRedraw(g: *Game, obj: *Object, bd: *Backdrop) void {
    stopAndRedrawDc(g, obj, bd);
}

/// SceneObject slot 35: stop the animation, post "animation finished", kill its timer.
pub fn stop(g: *Game, obj: *Object) void {
    switch (obj.kind) {
        // @orig 1010:1b06 scene_object_stop_default (absorbed)
        .local, .moveable, .portable, .status_bar => {},
        .animated, .actor, .player, .exit, .control_panel => animated3dStop(g, obj),
    }
}

// @orig 1010:3644 animated3d_stop
fn animated3dStop(g: *Game, obj: *Object) void {
    animationStop(g, obj);
}

// @orig 1010:d08e animation_stop
fn animationStop(g: *Game, obj: *Object) void {
    obj.anim.running = 0;
    obj.anim.playOnce = 0;
    _ = g.post(.{ .id = msg.noite.animation_finished, .wparam = @bitCast(obj.id) });
    g.killSystemTimer(@bitCast(obj.anim.timerId));
}

/// SceneObject slot 36: advance n+1 frames, redraw, invalidate.
pub fn advanceFrames(g: *Game, obj: *Object, unused: i16, bd: *Backdrop, n: i16) void {
    switch (obj.kind) {
        // @orig 1010:1b10 scene_object_advance_frames_default (absorbed)
        .local, .moveable, .portable, .status_bar => {},
        .animated, .actor, .player, .exit, .control_panel => animationAdvanceFrames(g, obj, unused, bd, n),
    }
}

// @orig 1010:d0ec animation_advance_frames
fn animationAdvanceFrames(g: *Game, obj: *Object, unused: i16, bd: *Backdrop, n: i16) void {
    _ = unused;
    var left = n +% 1;
    if (0 < left) {
        while (true) {
            _ = nextFrame(g, obj);
            left -%= 1;
            if (left == 0) break;
        }
    }
    frames.resetRects(obj);
    visibility.redraw(g, obj, bd);
    _ = visibility.invalidate(g, obj);
}

/// SceneObject slot 3D: the system-timer id (animation or movement).
pub fn getTimerId(g: *Game, obj: *Object) i16 {
    _ = .{g};
    return switch (obj.kind) {
        // @orig 1010:1b56 scene_object_get_timer_id_default (absorbed)
        .local, .status_bar => -1,
        .animated, .exit, .control_panel => animated3dGetTimerId(obj),
        .moveable, .portable => moveableGetTimerId(obj),
        .actor, .player => actorGetTimerId(obj),
    };
}

// @orig 1010:365e animated3d_get_timer_id
fn animated3dGetTimerId(obj: *Object) i16 {
    return animationGetTimerId(obj);
}

// @orig 1010:26e6 animation_get_timer_id
fn animationGetTimerId(obj: *Object) i16 {
    return obj.anim.timerId;
}

// @orig 1010:3bda moveable_get_timer_id
fn moveableGetTimerId(obj: *Object) i16 {
    return moverGetTimerId(obj);
}

// @orig 1010:2bfa mover_get_timer_id
fn moverGetTimerId(obj: *Object) i16 {
    return obj.mover.timerId;
}

// @orig 1010:3f8e actor_get_timer_id
fn actorGetTimerId(obj: *Object) i16 {
    return obj.mover.timerId;
}

/// SceneObject slot 3F: is the animation running.
pub fn isRunning(g: *Game, obj: *Object) bool {
    _ = .{g};
    return switch (obj.kind) {
        // @orig 1010:1b70 scene_object_is_running_default (absorbed)
        .local, .moveable, .portable, .status_bar => false,
        .animated, .actor, .player, .exit, .control_panel => animationIsRunning(obj),
    };
}

// @orig 1010:24e4 animation_is_running
fn animationIsRunning(obj: *Object) bool {
    return obj.anim.running != 0;
}

/// Switches to frame strip `strip` at its first frame; when the strip's
/// frame size differs the object is hidden first and shown again after
/// (each with an invalidate). Returns the new current strip. The original's
/// last parameter (hwnd) is dropped.
// @orig 1010:24fa animation_set_strip
pub fn setStrip(g: *Game, obj: *Object, strip: i16, bd: *Backdrop) *Frame {
    const new = &obj.frames[@as(u16, @bitCast(strip))];
    const old = &obj.frames[@as(u16, @bitCast(obj.curStrip))];
    if (old.width == new.width and old.height == new.height) {
        obj.curStrip = strip;
        obj.curFrame = 0;
        // B35: the player's new frame goes on screen whole at once, so another
        // animation's tick cannot patch it piecewise over the old one.
        if (g.fixes.player_strip_redraws and obj.kind == .player and obj.visible != 0) {
            frames.resetRects(obj);
            visibility.redraw(g, obj, bd);
            visibility.redrawOverlapping(g, obj, bd, 1);
        }
    } else {
        visibility.hide(g, obj, bd);
        _ = visibility.invalidate(g, obj);
        obj.curStrip = strip;
        obj.curFrame = 0;
        visibility.show(g, obj, bd);
        _ = visibility.invalidate(g, obj);
    }
    return frames.curStrip(obj);
}

/// Animation slot 07: play once. An AVI clip is opened and played; a
/// sprite is marked running in play-once mode with its frame countdown
/// set and its system timer started.
// @orig 1010:cf14 animation_play_once
pub fn playOnce(g: *Game, obj: *Object, bd: *Backdrop) void {
    _ = bd;
    if (!isAvi(g, obj)) {
        obj.anim.running = 1;
        const count = frames.frameCount(obj);
        obj.framesLeft = count -% @as(i16, if (obj.playOnceRewinds == 0) 1 else 0);
        obj.anim.playOnce = 1;
        g.setSystemTimer(@bitCast(obj.anim.timerId), @bitCast(obj.anim.timerPeriod));
    } else {
        const dev = avi.openAvi(g, obj, avi.getAviName(g, obj));
        if (dev != 0) avi.playAvi(g, obj, dev);
    }
}

/// DirectionalPlayer slot 01 (no callers): walk-right strip (1) when `dir`
/// is 2, else walk-left (2); starts the looping animation without moving.
// @orig 1010:e552 directional_player_play_walk_h
pub fn playWalkH(g: *Game, obj: *Object, bd: *Backdrop, dir: i16) void {
    const strip: i16 = if (dir == 2) 1 else 2;
    _ = setStrip(g, obj, strip, bd);
    tick.play(g, obj, bd);
}
