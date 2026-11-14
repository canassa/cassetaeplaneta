//! Port unit `animation` (behaviour) of ENCAIXE.EXE. SceneObject slots 29-30 37 39 (frames, play, playIdle, stopAndRedraw(Dc), tick, stop, getTimerId, isRunning) and AnimationVtbl playOnce.
//!
//! GetDC/ReleaseDC pairs are gone (the DC is the platform screen); hwnd and
//! hdc parameters are dropped. Only the piece (Actor2D) and the
//! control_panel (Animated3D) are Animations; the status_bar takes the
//! SceneObject defaults.

const msg = @import("../../core/msg.zig");
const Game = @import("../core/game.zig").Game;
const object = @import("../core/object.zig");
const Object = object.Object;
const Frame = object.Frame;
const world = @import("../core/world.zig");
const Backdrop = world.Backdrop;
const visibility = @import("visibility.zig");
const panels = @import("../panels.zig");

/// `frames[curStrip]`.
fn curStripFrame(obj: *Object) *Frame {
    return &obj.frames[@intCast(obj.curStrip)];
}

/// SceneObject slot 29 nextFrame: Actor2D's (piece), Animated3D's (control_panel).
pub fn nextFrame(g: *Game, obj: *Object) i16 {
    _ = g;
    return switch (obj.kind) {
        // @orig 1008:5c30 actor2d_next_frame
        // @orig 1008:5df8 animated3d_next_frame
        .piece, .control_panel => blk: {
            if (curStripFrame(obj).count -% obj.curFrame == 1) {
                obj.curFrame = 0;
            } else {
                obj.curFrame +%= 1;
            }
            break :blk obj.curFrame;
        },
        // scene_object_next_frame_default (absorbed)
        .status_bar => 0,
    };
}

/// SceneObject slot 2A prevFrame.
pub fn prevFrame(g: *Game, obj: *Object) i16 {
    _ = g;
    return switch (obj.kind) {
        // @orig 1008:5c64 actor2d_prev_frame
        // @orig 1008:5e2c animated3d_prev_frame
        .piece, .control_panel => blk: {
            if (obj.curFrame == 0) {
                obj.curFrame = curStripFrame(obj).count -% 1;
            } else {
                obj.curFrame -%= 1;
            }
            break :blk obj.curFrame;
        },
        // scene_object_prev_frame_default (absorbed)
        .status_bar => 0,
    };
}

/// SceneObject slot 2B play (hwnd dropped): Animation's (piece), Animated3D's (control_panel).
pub fn play(g: *Game, obj: *Object, bd: *Backdrop) void {
    switch (obj.kind) {
        // @orig 1008:5d40 animated3d_play
        .piece, .control_panel => animationPlay(g, obj, bd),
        // scene_object_play_default (absorbed)
        .status_bar => {},
    }
}

// @orig 1008:7ce8 animation_play
fn animationPlay(g: *Game, obj: *Object, bd: *Backdrop) void {
    _ = bd;
    obj.anim.running = 1;
    obj.anim.playOnce = 0;
    g.setSystemTimer(@bitCast(obj.anim.timerId), @bitCast(obj.anim.timerPeriod));
}

/// SceneObject slot 2C playIdle (default only).
pub fn playIdle(g: *Game, obj: *Object, bd: *Backdrop) void {
    // scene_object_play_idle_default (absorbed)
    _ = g;
    _ = obj;
    _ = bd;
}

/// SceneObject slot 2D stopAndRedrawDc (hdc, hwnd dropped).
pub fn stopAndRedrawDc(g: *Game, obj: *Object, bd: *Backdrop) void {
    switch (obj.kind) {
        // @orig 1008:5aa6 actor2d_stop_and_redraw_dc
        .piece => {
            actor2dSetStripZero(g, obj, bd);
            animationStopAndRedrawDc(g, obj, bd);
        },
        // @orig 1008:5d64 animated3d_stop_and_redraw_dc
        .control_panel => animationStopAndRedrawDc(g, obj, bd),
        // scene_object_stop_and_redraw_dc_default (absorbed)
        .status_bar => {},
    }
}

/// The inlined animation_set_strip(0) of the Actor2D stop-and-redraw pair:
/// when strip 0 has another frame size the object is hidden, switched and
/// shown again (each with an invalidate).
fn actor2dSetStripZero(g: *Game, obj: *Object, bd: *Backdrop) void {
    const cur = curStripFrame(obj);
    const first = &obj.frames[0];
    if (cur.width == first.width and first.height == cur.height) {
        obj.curStrip = 0;
        obj.curFrame = 0;
    } else {
        visibility.hide(g, obj, bd);
        visibility.invalidate(g, obj);
        obj.curStrip = 0;
        obj.curFrame = 0;
        visibility.show(g, obj, bd);
        visibility.invalidate(g, obj);
    }
}

// @orig 1008:7d86 animation_stop_and_redraw_dc
fn animationStopAndRedrawDc(g: *Game, obj: *Object, bd: *Backdrop) void {
    stop(g, obj);
    visibility.redraw(g, obj, bd);
    visibility.blitToDc(g, obj, bd);
}

/// SceneObject slot 2E stopAndRedraw.
pub fn stopAndRedraw(g: *Game, obj: *Object, bd: *Backdrop) void {
    switch (obj.kind) {
        // @orig 1008:5a24 actor2d_stop_and_redraw
        .piece => {
            actor2dSetStripZero(g, obj, bd);
            animationStopAndRedraw(g, obj, bd);
        },
        // @orig 1008:5d52 animated3d_stop_and_redraw
        .control_panel => animationStopAndRedraw(g, obj, bd),
        // scene_object_stop_and_redraw_default (absorbed)
        .status_bar => {},
    }
}

// @orig 1008:7d4e animation_stop_and_redraw
/// GetDC/ReleaseDC dropped around the (virtual) stopAndRedrawDc.
fn animationStopAndRedraw(g: *Game, obj: *Object, bd: *Backdrop) void {
    stopAndRedrawDc(g, obj, bd);
}

/// SceneObject slot 2F tick: Player2D's (piece), ControlPanel's (panels.tick).
pub fn tick(g: *Game, obj: *Object, bd: *Backdrop) void {
    switch (obj.kind) {
        // @orig 1008:7ed8 player2d_tick
        .piece => animationTick(g, obj, bd),
        .control_panel => panels.tick(g, obj, bd),
        // scene_object_tick_default (absorbed)
        .status_bar => {},
    }
}

// @orig 1008:7dec animation_tick
/// Timer tick: next frame, dirty and clip rects = the whole frame, redraw
/// and blit; in play-once mode counts the frame down and stops at zero.
/// (Unlike NOITE's, no invalidate.)
fn animationTick(g: *Game, obj: *Object, bd: *Backdrop) void {
    _ = nextFrame(g, obj);
    obj.dirty.left = 0;
    obj.clip.left = 0;
    obj.dirty.top = 0;
    obj.clip.top = 0;
    const w = curStripFrame(obj).width;
    obj.dirty.right = w;
    obj.clip.right = w;
    const h = curStripFrame(obj).height;
    obj.dirty.bottom = h;
    obj.clip.bottom = h;
    visibility.redraw(g, obj, bd);
    visibility.blitToDc(g, obj, bd);
    if (obj.anim.playOnce != 0) {
        obj.anim.framesLeft -%= 1;
        if (obj.anim.framesLeft == 0) stop(g, obj);
    }
}

/// SceneObject slot 30 stop.
pub fn stop(g: *Game, obj: *Object) void {
    switch (obj.kind) {
        // @orig 1008:5c98 actor2d_stop
        // @orig 1008:5e60 animated3d_stop
        .piece, .control_panel => animationStop(g, obj),
        // scene_object_stop_default (absorbed)
        .status_bar => {},
    }
}

// @orig 1008:7db8 animation_stop
fn animationStop(g: *Game, obj: *Object) void {
    obj.anim.playOnce = 0;
    obj.anim.running = 0;
    _ = g.post(.{ .id = msg.noite.animation_finished, .wparam = @bitCast(obj.id) });
    g.killSystemTimer(@bitCast(obj.anim.timerId));
}

/// SceneObject slot 37 getTimerId.
pub fn getTimerId(g: *Game, obj: *Object) i16 {
    _ = g;
    return switch (obj.kind) {
        // @orig 1008:58bc actor2d_get_timer_id
        .piece => obj.mover.timerId,
        // @orig 1008:5e6e animated3d_get_timer_id
        .control_panel => obj.anim.timerId,
        // scene_object_get_timer_id_default (absorbed)
        .status_bar => -1,
    };
}

/// SceneObject slot 39 isRunning.
pub fn isRunning(g: *Game, obj: *Object) bool {
    _ = g;
    return switch (obj.kind) {
        // @orig 1008:5626 animation_is_running
        .piece, .control_panel => obj.anim.running != 0,
        // scene_object_is_running_default (absorbed)
        .status_bar => false,
    };
}

/// AnimationVtbl / ControlPanelVtbl slot 00 playOnce.
// @orig 1008:7d0e animation_play_once
pub fn playOnce(g: *Game, obj: *Object, bd: *Backdrop) void {
    _ = bd;
    obj.anim.running = 1;
    obj.anim.framesLeft = curStripFrame(obj).count -% 1;
    obj.anim.playOnce = 1;
    g.setSystemTimer(@bitCast(obj.anim.timerId), @bitCast(obj.anim.timerPeriod));
}
