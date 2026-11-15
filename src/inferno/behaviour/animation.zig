//! Port unit `animation` (behaviour) of INFERNO.EXE. SceneObject slots 27-2E
//! 35 37 (frames, play, playIdle, stopAndRedraw(Dc), tick, stop, getTimerId,
//! isRunning), AnimationVtbl playOnce, animation_set_strip.
//!
//! GetDC/ReleaseDC pairs are gone (the DC is the platform screen); hwnd and
//! hdc parameters are dropped. Unlike TIRO's, INFERNO's animation_tick
//! invalidates (no blitToDc, no rect reset) and animation_stop posts
//! nothing.

const Game = @import("../core/game.zig").Game;
const object = @import("../core/object.zig");
const Object = object.Object;
const Frame = object.Frame;
const world = @import("../core/world.zig");
const Backdrop = world.Backdrop;
const hero = @import("../hero.zig");
const ledge = @import("../ledge.zig");
const position = @import("position.zig");
const visibility = @import("visibility.zig");

/// SceneObject slot 27 nextFrame: actor2d_next_frame (every kind).
pub fn nextFrame(g: *Game, obj: *Object) i16 {
    _ = g;
    // @orig 1080:3170 actor2d_next_frame
    return animationNextFrame(obj);
}

// @orig 1080:28f0 animation_next_frame
fn animationNextFrame(obj: *Object) i16 {
    if (position.curStrip(obj).count -% obj.curFrame == 1) {
        obj.curFrame = 0;
    } else {
        obj.curFrame +%= 1;
    }
    return obj.curFrame;
}

/// SceneObject slot 28 prevFrame: actor2d_prev_frame (every kind).
pub fn prevFrame(g: *Game, obj: *Object) i16 {
    _ = g;
    // @orig 1080:3192 actor2d_prev_frame
    return animationPrevFrame(obj);
}

// @orig 1080:2980 animation_prev_frame
fn animationPrevFrame(obj: *Object) i16 {
    if (obj.curFrame == 0) {
        obj.curFrame = position.curStrip(obj).count -% 1;
    } else {
        obj.curFrame -%= 1;
    }
    return obj.curFrame;
}

/// SceneObject slot 29 play (hwnd dropped): hero.play (hero), ledge.play
/// (platform), animation_play (prop, hazard).
pub fn play(g: *Game, obj: *Object, bd: *Backdrop) void {
    switch (obj.kind) {
        .hero => hero.play(g, obj, bd),
        .platform => ledge.play(g, obj, bd),
        .prop, .hazard => animationPlay(g, obj, bd),
    }
}

// @orig 1028:2129 animation_play
fn animationPlay(g: *Game, obj: *Object, bd: *Backdrop) void {
    _ = bd;
    obj.anim.running = 1;
    obj.anim.playOnce = 0;
    g.setSystemTimer(@bitCast(obj.anim.timerId), @bitCast(obj.anim.timerPeriod));
}

/// SceneObject slot 2A playIdle: default only.
pub fn playIdle(g: *Game, obj: *Object, bd: *Backdrop) void {
    // scene_object_play_idle_default (absorbed)
    _ = g;
    _ = obj;
    _ = bd;
}

/// SceneObject slot 2B stopAndRedrawDc: actor2d_stop_and_redraw_dc (every
/// kind).
pub fn stopAndRedrawDc(g: *Game, obj: *Object, bd: *Backdrop) void {
    // @orig 1080:303c actor2d_stop_and_redraw_dc
    _ = setStrip(g, obj, 0, bd);
    animationStopAndRedrawDc(g, obj, bd);
}

// @orig 1028:2245 animation_stop_and_redraw_dc
fn animationStopAndRedrawDc(g: *Game, obj: *Object, bd: *Backdrop) void {
    obj.anim.running = 0;
    obj.anim.playOnce = 0;
    g.killSystemTimer(@bitCast(obj.anim.timerId));
    visibility.redraw(g, obj, bd);
    visibility.invalidate(g, obj);
}

/// SceneObject slot 2C stopAndRedraw: actor2d_stop_and_redraw (every kind).
pub fn stopAndRedraw(g: *Game, obj: *Object, bd: *Backdrop) void {
    // @orig 1080:2ff6 actor2d_stop_and_redraw
    _ = setStrip(g, obj, 0, bd);
    animationStopAndRedraw(g, obj, bd);
}

// @orig 1028:21ce animation_stop_and_redraw
/// GetDC/ReleaseDC dropped around the (virtual) stopAndRedrawDc.
fn animationStopAndRedraw(g: *Game, obj: *Object, bd: *Backdrop) void {
    obj.anim.running = 0;
    obj.anim.playOnce = 0;
    stopAndRedrawDc(g, obj, bd);
}

/// SceneObject slot 2D tick: hero.tick (hero), animation_tick (platform,
/// prop, hazard).
pub fn tick(g: *Game, obj: *Object, bd: *Backdrop) void {
    switch (obj.kind) {
        .hero => hero.tick(g, obj, bd),
        .platform, .prop, .hazard => animationTick(g, obj, bd),
    }
}

// @orig 1028:230f animation_tick
/// Timer tick: next frame, redraw, invalidate; in play-once mode counts the
/// frame down and stops at zero.
pub fn animationTick(g: *Game, obj: *Object, bd: *Backdrop) void {
    _ = nextFrame(g, obj);
    visibility.redraw(g, obj, bd);
    visibility.invalidate(g, obj);
    if (obj.anim.playOnce != 0) {
        obj.anim.framesLeft -%= 1;
        if (obj.anim.framesLeft == 0) stop(g, obj);
    }
}

/// SceneObject slot 2E stop: actor2d_stop (every kind).
pub fn stop(g: *Game, obj: *Object) void {
    // @orig 1080:31b4 actor2d_stop
    animationStop(g, obj);
}

// @orig 1028:22d9 animation_stop
fn animationStop(g: *Game, obj: *Object) void {
    obj.anim.running = 0;
    obj.anim.playOnce = 0;
    g.killSystemTimer(@bitCast(obj.anim.timerId));
}

/// SceneObject slot 35 getTimerId: actor2d_get_timer_id (every kind); the
/// Mover's timer (Animation-6), as TIRO's.
pub fn getTimerId(g: *Game, obj: *Object) i16 {
    _ = g;
    // @orig 1080:2efa actor2d_get_timer_id
    return obj.mover.timerId;
}

/// SceneObject slot 37 isRunning: animation_is_running (every kind).
pub fn isRunning(g: *Game, obj: *Object) bool {
    _ = g;
    // @orig 1080:28d2 animation_is_running
    return obj.anim.running != 0;
}

/// AnimationVtbl slot 00 playOnce (animation_play_once, every table).
// @orig 1028:216a animation_play_once
pub fn playOnce(g: *Game, obj: *Object, bd: *Backdrop) void {
    _ = bd;
    obj.anim.running = 1;
    obj.anim.framesLeft = position.frameCount(obj) -% 1;
    obj.anim.playOnce = 1;
    g.setSystemTimer(@bitCast(obj.anim.timerId), @bitCast(obj.anim.timerPeriod));
}

/// Animation::set_strip: when strip `strip` has another frame size than the
/// current one the object is hidden, invalidated, switched, shown and
/// invalidated again. Returns the (new) current strip's Frame.
// @orig 1080:4146 animation_set_strip
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
