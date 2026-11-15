//! Port unit `animation` (behaviour) of SAUNA.EXE. SceneObject slots 2D-34 3B 3D (frames, play, playIdle incl. Pacman's, stopAndRedraw(Dc) incl. Pacman's, tick incl. Pacman's, stop, getTimerId, isRunning), AnimationVtbl 00-05 (the AVI stubs, playOnce), PacmanVtbl refreshPowerStrip (BUGS.md P4), animation_set_strip.
//!
//! GetDC/ReleaseDC pairs are gone; hwnd and hdc parameters are dropped.
//! Unlike TIRO's, the tick and the stop-and-redraw call the virtual
//! `invalidate` (slot 24) where TIRO blits, `playOnce` leaves `running`
//! alone, and the SceneObject next/prev-frame defaults (dots) are real.

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

/// SceneObject slot 2D nextFrame: animated3d_next_frame (panel), actor2d_next_frame (pacman, ghost) / default (dots).
pub fn nextFrame(g: *Game, obj: *Object) i16 {
    _ = g;
    return switch (obj.kind) {
        // @orig 10a0:2dda animated3d_next_frame
        // @orig 10a0:2a98 actor2d_next_frame
        // scene_object_next_frame_default (absorbed: the same wrap)
        .control_panel, .pacman, .ghost, .dot => animationNextFrame(obj),
    };
}

// @orig 10a0:2218 animation_next_frame
fn animationNextFrame(obj: *Object) i16 {
    if (position.curStrip(obj).count -% obj.curFrame == 1) {
        obj.curFrame = 0;
    } else {
        obj.curFrame +%= 1;
    }
    return obj.curFrame;
}

/// SceneObject slot 2E prevFrame: animated3d_prev_frame (panel), actor2d_prev_frame (pacman, ghost) / default (dots).
pub fn prevFrame(g: *Game, obj: *Object) i16 {
    _ = g;
    return switch (obj.kind) {
        // @orig 10a0:2dfc animated3d_prev_frame
        // @orig 10a0:2aba actor2d_prev_frame
        // scene_object_prev_frame_default (absorbed: the same wrap)
        .control_panel, .pacman, .ghost, .dot => animationPrevFrame(obj),
    };
}

// @orig 10a0:22a8 animation_prev_frame
fn animationPrevFrame(obj: *Object) i16 {
    if (obj.curFrame == 0) {
        obj.curFrame = position.curStrip(obj).count -% 1;
    } else {
        obj.curFrame -%= 1;
    }
    return obj.curFrame;
}

/// SceneObject slot 2F play (hwnd dropped): animated3d_play (panel), animation_play (pacman, ghost) / default.
pub fn play(g: *Game, obj: *Object, bd: *Backdrop) void {
    switch (obj.kind) {
        // @orig 10a0:2cd4 animated3d_play
        .control_panel, .pacman, .ghost => animationPlay(g, obj, bd),
        // scene_object_play_default (absorbed)
        .dot => {},
    }
}

// @orig 1020:2456 animation_play
fn animationPlay(g: *Game, obj: *Object, bd: *Backdrop) void {
    _ = bd;
    if (isAvi(g, obj)) return;
    obj.anim.running = 1;
    obj.anim.playOnce = 0;
    g.setSystemTimer(@bitCast(obj.anim.timerId), @bitCast(obj.anim.timerPeriod));
}

/// SceneObject slot 30 playIdle: pacman_play_idle (pacman) / default.
pub fn playIdle(g: *Game, obj: *Object, bd: *Backdrop) void {
    switch (obj.kind) {
        // @orig 1080:0667 pacman_play_idle
        .pacman => animationPlay(g, obj, bd),
        // scene_object_play_idle_default (absorbed)
        .control_panel, .ghost, .dot => {},
    }
}

/// SceneObject slot 31 stopAndRedrawDc (hdc, hwnd dropped): animated3d_stop_and_redraw_dc (panel), pacman_stop_and_redraw_dc (pacman), actor2d_stop_and_redraw_dc (ghost) / default.
pub fn stopAndRedrawDc(g: *Game, obj: *Object, bd: *Backdrop) void {
    switch (obj.kind) {
        // @orig 1080:0696 pacman_stop_and_redraw_dc
        .pacman => {
            _ = setStrip(g, obj, g.powerStrip, bd);
            actor2dStopAndRedrawDc(g, obj, bd);
        },
        .ghost => actor2dStopAndRedrawDc(g, obj, bd),
        // @orig 10a0:2d28 animated3d_stop_and_redraw_dc
        .control_panel => animationStopAndRedrawDc(g, obj, bd),
        // scene_object_stop_and_redraw_dc_default (absorbed)
        .dot => {},
    }
}

// @orig 10a0:2964 actor2d_stop_and_redraw_dc
fn actor2dStopAndRedrawDc(g: *Game, obj: *Object, bd: *Backdrop) void {
    _ = setStrip(g, obj, 0, bd);
    animationStopAndRedrawDc(g, obj, bd);
}

// @orig 1020:25a7 animation_stop_and_redraw_dc
fn animationStopAndRedrawDc(g: *Game, obj: *Object, bd: *Backdrop) void {
    stop(g, obj);
    visibility.redraw(g, obj, bd);
    visibility.invalidate(g, obj);
}

/// SceneObject slot 32 stopAndRedraw: animated3d_stop_and_redraw (panel), pacman_stop_and_redraw (pacman), actor2d_stop_and_redraw (ghost) / default.
pub fn stopAndRedraw(g: *Game, obj: *Object, bd: *Backdrop) void {
    switch (obj.kind) {
        // @orig 1080:06e5 pacman_stop_and_redraw
        // GetDC/ReleaseDC dropped around the (virtual) stopAndRedrawDc.
        .pacman => stopAndRedrawDc(g, obj, bd),
        // @orig 10a0:291e actor2d_stop_and_redraw
        .ghost => {
            _ = setStrip(g, obj, 0, bd);
            animationStopAndRedraw(g, obj, bd);
        },
        // @orig 10a0:2cfe animated3d_stop_and_redraw
        .control_panel => animationStopAndRedraw(g, obj, bd),
        // scene_object_stop_and_redraw_default (absorbed)
        .dot => {},
    }
}

// @orig 1020:2542 animation_stop_and_redraw
fn animationStopAndRedraw(g: *Game, obj: *Object, bd: *Backdrop) void {
    stopAndRedrawDc(g, obj, bd);
}

/// SceneObject slot 33 tick: control_panel_tick (panel), pacman_tick (pacman), animation_tick (ghost) / default.
pub fn tick(g: *Game, obj: *Object, bd: *Backdrop) void {
    switch (obj.kind) {
        .control_panel => panels.tick(g, obj, bd),
        // @orig 1080:0c43 pacman_tick
        // No play-once countdown; GetDC/ReleaseDC dropped.
        .pacman => {
            _ = nextFrame(g, obj);
            render.resetRects(obj);
            visibility.redraw(g, obj, bd);
            visibility.invalidate(g, obj);
        },
        .ghost => animationTick(g, obj, bd),
        // scene_object_tick_default (absorbed)
        .dot => {},
    }
}

// @orig 1020:26a4 animation_tick
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

/// SceneObject slot 34 stop: animated3d_stop (panel), actor2d_stop (pacman, ghost) / default.
pub fn stop(g: *Game, obj: *Object) void {
    switch (obj.kind) {
        // @orig 10a0:2e1e animated3d_stop
        // @orig 10a0:2adc actor2d_stop
        .control_panel, .pacman, .ghost => animationStop(g, obj),
        // scene_object_stop_default (absorbed)
        .dot => {},
    }
}

// @orig 1020:264d animation_stop
fn animationStop(g: *Game, obj: *Object) void {
    obj.anim.running = 0;
    obj.anim.playOnce = 0;
    _ = g.post(.{ .id = msg.noite.animation_finished, .wparam = @bitCast(obj.id) });
    g.killSystemTimer(@bitCast(obj.anim.timerId));
}

/// SceneObject slot 3B getTimerId: animated3d_get_timer_id (panel), actor2d_get_timer_id (pacman, ghost) / default.
pub fn getTimerId(g: *Game, obj: *Object) i16 {
    _ = g;
    return switch (obj.kind) {
        // @orig 10a0:2e42 animated3d_get_timer_id
        .control_panel => animationGetTimerId(obj),
        // @orig 10a0:2822 actor2d_get_timer_id
        .pacman, .ghost => obj.mover.timerId,
        // scene_object_get_timer_id_default (absorbed)
        .dot => -1,
    };
}

// @orig 10a0:2332 animation_get_timer_id
fn animationGetTimerId(obj: *Object) i16 {
    return obj.anim.timerId;
}

/// SceneObject slot 3D isRunning: animation_is_running (panel, pacman, ghost) / default.
pub fn isRunning(g: *Game, obj: *Object) bool {
    _ = g;
    return switch (obj.kind) {
        // @orig 10a0:21fa animation_is_running
        .control_panel, .pacman, .ghost => obj.anim.running != 0,
        // scene_object_is_running_default (absorbed)
        .dot => false,
    };
}

/// AnimationVtbl / ControlPanelVtbl slot 00 setAvi.
// @orig 10a0:714e animation_set_avi
pub fn setAvi(g: *Game, obj: *Object) void {
    _ = g;
    obj.anim.isAvi = 1;
}

/// AnimationVtbl / ControlPanelVtbl slot 01 isAvi.
// @orig 10a0:716e animation_is_avi
pub fn isAvi(g: *Game, obj: *Object) bool {
    _ = g;
    return obj.anim.isAvi != 0;
}

/// AnimationVtbl / ControlPanelVtbl slot 02 aviSlot2: calls isAvi, returns 0.
// @orig 1020:23c6 animation_avi_slot2
pub fn aviSlot2(g: *Game, obj: *Object) i16 {
    _ = isAvi(g, obj);
    return 0;
}

/// AnimationVtbl / ControlPanelVtbl slot 03 aviSlot3: calls isAvi, returns 0.
// @orig 1020:23f6 animation_avi_slot3
pub fn aviSlot3(g: *Game, obj: *Object) i16 {
    _ = isAvi(g, obj);
    return 0;
}

/// AnimationVtbl / ControlPanelVtbl slot 04 aviSlot4: calls isAvi, returns 0.
// @orig 1020:2426 animation_avi_slot4
pub fn aviSlot4(g: *Game, obj: *Object) i16 {
    _ = isAvi(g, obj);
    return 0;
}

/// AnimationVtbl / ControlPanelVtbl slot 05 playOnce. `running` is not set
/// (unlike TIRO's): the frame count is reduced by one when it is 0, and
/// `object_create` seeds it from `play_once_rewinds`.
// @orig 1020:24b7 animation_play_once
pub fn playOnce(g: *Game, obj: *Object, bd: *Backdrop) void {
    _ = bd;
    if (isAvi(g, obj)) return;
    obj.anim.unk12 = 1;
    obj.anim.framesLeft = position.frameCount(obj) -% @as(i16, if (obj.anim.running == 0) 1 else 0);
    obj.anim.playOnce = 1;
    g.setSystemTimer(@bitCast(obj.anim.timerId), @bitCast(obj.anim.timerPeriod));
}

/// PacmanVtbl slot 01 refreshPowerStrip (hwnd dropped; BUGS.md P4: every caller passes 2).
// @orig 1080:05ef pacman_refresh_power_strip
pub fn refreshPowerStrip(g: *Game, obj: *Object, bd: *Backdrop, dir: i16) void {
    _ = setStrip(g, obj, g.powerStrip +% (if (dir == 2) @as(i16, 1) else 2), bd);
    animationPlay(g, obj, bd);
}

/// Animation::set_strip: when strip `strip` has another frame size than the
/// current one the object is hidden, switched and shown again (each with an
/// invalidate). Returns the (new) current strip's Frame.
// @orig 10a0:3fbe animation_set_strip
fn setStrip(g: *Game, obj: *Object, strip: i16, bd: *Backdrop) *Frame {
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
