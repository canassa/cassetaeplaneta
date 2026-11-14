//! Port unit `animation` (behaviour) of INV.EXE. SceneObject slots 27-2E 35 37 (frames, play, stopAndRedraw(Dc), tick incl. the Cannon's play and tick, stop, getTimerId, isRunning), AnimationVtbl playOnce, animation_set_strip.
//!
//! GetDC/ReleaseDC pairs are gone (the DC is the platform screen); hwnd and
//! hdc parameters are dropped. The cannon, saucer, bomb, shot, column and
//! explosion are Actor2Ds (Animations); the control_panel is an Animated3D
//! (thunks to the Animation methods); the status_bar takes the SceneObject
//! defaults. INV's animation_set_strip (`setStrip`) takes its own DC and
//! calls scene_object_blit_to_dc directly after hide and show (TIRO:
//! `invalidate`). cannon_play and cannon_tick are never called (the
//! cannon's timer is a Mover's).

const msg = @import("../../core/msg.zig");
const Game = @import("../core/game.zig").Game;
const object = @import("../core/object.zig");
const Object = object.Object;
const Frame = object.Frame;
const world = @import("../core/world.zig");
const Backdrop = world.Backdrop;
const panels = @import("../panels.zig");
const occupancy = @import("occupancy.zig");
const position = @import("position.zig");
const render = @import("render.zig");
const visibility = @import("visibility.zig");

/// SceneObject slot 27 nextFrame: actor2d_next_frame (cannon, saucer, bomb, shot, column, explosion), animated3d_next_frame (panel) / default.
pub fn nextFrame(g: *Game, obj: *Object) i16 {
    _ = g;
    return switch (obj.kind) {
        // @orig 1088:2456 actor2d_next_frame
        // @orig 1088:279a animated3d_next_frame
        .cannon, .saucer, .bomb, .shot, .invader_column, .invader_explosion, .control_panel => animationNextFrame(obj),
        // scene_object_next_frame_default (absorbed)
        .status_bar => 0,
    };
}

// @orig 1088:1df6 animation_next_frame
fn animationNextFrame(obj: *Object) i16 {
    if (position.curStrip(obj).count -% obj.curFrame == 1) {
        obj.curFrame = 0;
    } else {
        obj.curFrame +%= 1;
    }
    return obj.curFrame;
}

/// SceneObject slot 28 prevFrame: actor2d_prev_frame (cannon, saucer, bomb, shot, column, explosion), animated3d_prev_frame (panel) / default.
pub fn prevFrame(g: *Game, obj: *Object) i16 {
    _ = g;
    return switch (obj.kind) {
        // @orig 1088:2476 actor2d_prev_frame
        // @orig 1088:27ba animated3d_prev_frame
        .cannon, .saucer, .bomb, .shot, .invader_column, .invader_explosion, .control_panel => animationPrevFrame(obj),
        // scene_object_prev_frame_default (absorbed)
        .status_bar => 0,
    };
}

// @orig 1088:1e58 animation_prev_frame
fn animationPrevFrame(obj: *Object) i16 {
    if (obj.curFrame == 0) {
        obj.curFrame = position.curStrip(obj).count -% 1;
    } else {
        obj.curFrame -%= 1;
    }
    return obj.curFrame;
}

/// SceneObject slot 29 play (hwnd dropped): cannon_play (cannon), animation_play (saucer, bomb, shot, column, explosion), animated3d_play (panel) / default.
pub fn play(g: *Game, obj: *Object, bd: *Backdrop) void {
    switch (obj.kind) {
        // @orig 1068:096a cannon_play
        .cannon => cannonPlay(g, obj, bd),
        // @orig 1088:26c0 animated3d_play
        .saucer, .bomb, .shot, .invader_column, .invader_explosion, .control_panel => animationPlay(g, obj, bd),
        // scene_object_play_default (absorbed)
        .status_bar => {},
    }
}

/// Never called (the cannon is moved by key, not by an animation timer).
/// Turns the cannon's Mover direction (1 left, 2 right, 0 none, 4 ending)
/// by its strip: when the key direction and the current frame disagree,
/// the frame is switched through 0/1/2, then animation_play runs.
fn cannonPlay(g: *Game, obj: *Object, bd: *Backdrop) void {
    if (obj.mover.direction == 1) {
        if (obj.curFrame == 0) {
            obj.curFrame = 1;
        } else if (obj.curFrame == 2) {
            obj.curFrame = 1;
            obj.mover.direction = 4;
        }
    } else if (obj.mover.direction == 2) {
        if (obj.curFrame == 0) {
            obj.curFrame = 2;
        } else if (obj.curFrame == 1) {
            obj.curFrame = 0;
            obj.mover.direction = 4;
        }
    }
    animationPlay(g, obj, bd);
}

// @orig 1028:1619 animation_play
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

/// SceneObject slot 2B stopAndRedrawDc (hdc, hwnd dropped): actor2d_stop_and_redraw_dc (cannon, saucer, bomb, shot, column, explosion), animated3d_stop_and_redraw_dc (panel) / default.
pub fn stopAndRedrawDc(g: *Game, obj: *Object, bd: *Backdrop) void {
    switch (obj.kind) {
        // @orig 1088:2354 actor2d_stop_and_redraw_dc
        .cannon, .saucer, .bomb, .shot, .invader_column, .invader_explosion => {
            _ = setStrip(g, obj, 0, bd);
            animationStopAndRedrawDc(g, obj, bd);
        },
        // @orig 1088:270c animated3d_stop_and_redraw_dc
        .control_panel => animationStopAndRedrawDc(g, obj, bd),
        // scene_object_stop_and_redraw_dc_default (absorbed)
        .status_bar => {},
    }
}

// @orig 1028:16e7 animation_stop_and_redraw_dc
fn animationStopAndRedrawDc(g: *Game, obj: *Object, bd: *Backdrop) void {
    stop(g, obj);
    visibility.redraw(g, obj, bd);
    visibility.blitToDc(g, obj, bd);
}

/// SceneObject slot 2C stopAndRedraw: actor2d_stop_and_redraw (cannon, saucer, bomb, shot, column, explosion), animated3d_stop_and_redraw (panel) / default.
pub fn stopAndRedraw(g: *Game, obj: *Object, bd: *Backdrop) void {
    switch (obj.kind) {
        // @orig 1088:231e actor2d_stop_and_redraw
        .cannon, .saucer, .bomb, .shot, .invader_column, .invader_explosion => {
            _ = setStrip(g, obj, 0, bd);
            animationStopAndRedraw(g, obj, bd);
        },
        // @orig 1088:26e6 animated3d_stop_and_redraw
        .control_panel => animationStopAndRedraw(g, obj, bd),
        // scene_object_stop_and_redraw_default (absorbed)
        .status_bar => {},
    }
}

// @orig 1028:1696 animation_stop_and_redraw
/// GetDC/ReleaseDC dropped around the (virtual) stopAndRedrawDc.
fn animationStopAndRedraw(g: *Game, obj: *Object, bd: *Backdrop) void {
    stopAndRedrawDc(g, obj, bd);
}

/// SceneObject slot 2D tick: cannon_tick (cannon), animation_tick (saucer, bomb, shot, column, explosion), control_panel_tick (panel) / default.
pub fn tick(g: *Game, obj: *Object, bd: *Backdrop) void {
    switch (obj.kind) {
        // @orig 1068:0a19 cannon_tick
        .cannon => {
            occupancy.placeAt(g, obj, obj.x, obj.y, bd);
            visibility.blitToDc(g, obj, bd);
        },
        .saucer, .bomb, .shot, .invader_column, .invader_explosion => animationTick(g, obj, bd),
        .control_panel => panels.tick(g, obj, bd),
        // scene_object_tick_default (absorbed)
        .status_bar => {},
    }
}

// @orig 1028:1799 animation_tick
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

/// SceneObject slot 2E stop: actor2d_stop (cannon, saucer, bomb, shot, column, explosion), animated3d_stop (panel) / default.
pub fn stop(g: *Game, obj: *Object) void {
    switch (obj.kind) {
        // @orig 1088:2496 actor2d_stop
        // @orig 1088:27da animated3d_stop
        .cannon, .saucer, .bomb, .shot, .invader_column, .invader_explosion, .control_panel => animationStop(g, obj),
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

/// SceneObject slot 35 getTimerId: actor2d_get_timer_id (cannon, saucer, bomb, shot, column, explosion), animated3d_get_timer_id (panel) / default.
pub fn getTimerId(g: *Game, obj: *Object) i16 {
    _ = g;
    return switch (obj.kind) {
        // @orig 1088:2256 actor2d_get_timer_id
        .cannon, .saucer, .bomb, .shot, .invader_column, .invader_explosion => obj.mover.timerId,
        // @orig 1088:27fc animated3d_get_timer_id
        .control_panel => animationGetTimerId(obj),
        // scene_object_get_timer_id_default (absorbed)
        .status_bar => -1,
    };
}

// @orig 1088:1eb4 animation_get_timer_id
fn animationGetTimerId(obj: *Object) i16 {
    return obj.anim.timerId;
}

/// SceneObject slot 37 isRunning: animation_is_running (cannon, saucer, bomb, shot, column, explosion, panel) / default.
pub fn isRunning(g: *Game, obj: *Object) bool {
    _ = g;
    return switch (obj.kind) {
        // @orig 1088:1dda animation_is_running
        .cannon, .saucer, .bomb, .shot, .invader_column, .invader_explosion, .control_panel => obj.anim.running != 0,
        // scene_object_is_running_default (absorbed)
        .status_bar => false,
    };
}

/// AnimationVtbl / ControlPanelVtbl slot 00 playOnce (animation_play_once).
// @orig 1028:164d animation_play_once
pub fn playOnce(g: *Game, obj: *Object, bd: *Backdrop) void {
    _ = bd;
    obj.anim.running = 1;
    obj.anim.framesLeft = position.frameCount(obj) -% 1;
    obj.anim.playOnce = 1;
    g.setSystemTimer(@bitCast(obj.anim.timerId), @bitCast(obj.anim.timerPeriod));
}

/// scene_object_blit_to_dc (1028:0041, `visibility` owns it, private there):
/// the object's strip rectangle at (x, y), whatever its class.
fn blitSceneObject(g: *Game, obj: *Object, bd: *Backdrop) void {
    g.plat.wingBitBlt(obj.x -% bd.originX, obj.y -% bd.originY, position.width(obj), position.height(obj), bd.surface(), obj.x, obj.y);
}

/// Animation::set_strip, out of line. When strip `strip` has another frame
/// size than the current one the object is hidden, switched and shown again
/// (each followed by a direct scene_object_blit_to_dc on the function's own DC). Returns the (new) current strip's Frame.
// @orig 1088:310c animation_set_strip
pub fn setStrip(g: *Game, obj: *Object, strip: i16, bd: *Backdrop) *Frame {
    const new = &obj.frames[@intCast(strip)];
    const cur = position.curStrip(obj);
    if (cur.width == new.width and cur.height == new.height) {
        obj.curStrip = strip;
        obj.curFrame = 0;
    } else {
        // hide, then scene_object_blit_to_dc: scene_object_hide_and_invalidate.
        visibility.hideAndInvalidate(g, obj, 0, bd);
        obj.curStrip = strip;
        obj.curFrame = 0;
        visibility.show(g, obj, bd);
        blitSceneObject(g, obj, bd);
    }
    return position.curStrip(obj);
}
