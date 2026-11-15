//! Port unit `animation` (behaviour) of JARDIM.EXE. SceneObject slots 2C-33 3A 3C (frames, play, stopAndRedraw(Dc), tick incl. the Exit's, stop, getTimerId, isRunning), AnimationVtbl 00-05, animation_set_strip, exit_has_key_object.
//!
//! GetDC/ReleaseDC pairs (and the `hdc == 0` fatal boxes of the two 3D
//! ticks) are gone: the DC is the platform screen. hwnd and hdc parameters
//! are dropped. Unlike TIRO's, the stop-and-redraw pair ends in the virtual
//! `invalidate` (slot 23) where TIRO blits; there is no AVI (slots 02-04
//! are stubs) and `playOnce` honours `locked`. The Animation fields are
//! +0xc framesLeft, +0xe playOnce, +0x12 running.

const msg = @import("../../core/msg.zig");
const Game = @import("../core/game.zig").Game;
const object = @import("../core/object.zig");
const Object = object.Object;
const Frame = object.Frame;
const world = @import("../core/world.zig");
const Backdrop = world.Backdrop;
const position = @import("position.zig");
const render = @import("render.zig");
const space3d = @import("space3d.zig");
const visibility = @import("visibility.zig");
const scene = @import("../scene.zig");

/// SceneObject slot 2C nextFrame: animated3d_next_frame (exit, player, control_panel) / default.
pub fn nextFrame(g: *Game, obj: *Object) i16 {
    _ = g;
    return switch (obj.kind) {
        // @orig 10c0:23ae animated3d_next_frame
        .exit, .player, .control_panel => animationNextFrame(obj),
        // scene_object_next_frame_default (absorbed)
        .scene_object, .wall_strip, .portable => 0,
    };
}

// @orig 10c0:1884 animation_next_frame
fn animationNextFrame(obj: *Object) i16 {
    if (position.curStrip(obj).count -% obj.curFrame == 1) {
        obj.curFrame = 0;
    } else {
        obj.curFrame +%= 1;
    }
    return obj.curFrame;
}

/// SceneObject slot 2D prevFrame: animated3d_prev_frame (exit, player, control_panel) / default.
pub fn prevFrame(g: *Game, obj: *Object) i16 {
    _ = g;
    return switch (obj.kind) {
        // @orig 10c0:23d0 animated3d_prev_frame
        .exit, .player, .control_panel => animationPrevFrame(obj),
        // scene_object_prev_frame_default (absorbed)
        .scene_object, .wall_strip, .portable => 0,
    };
}

// @orig 10c0:1914 animation_prev_frame
fn animationPrevFrame(obj: *Object) i16 {
    if (obj.curFrame == 0) {
        obj.curFrame = position.curStrip(obj).count -% 1;
    } else {
        obj.curFrame -%= 1;
    }
    return obj.curFrame;
}

/// SceneObject slot 2E play (hwnd dropped): exit_play (exit), animated3d_play (player, control_panel) / default.
pub fn play(g: *Game, obj: *Object, bd: *Backdrop) void {
    switch (obj.kind) {
        // @orig 1048:25c1 exit_play
        .exit => exitPlay(g, obj, bd),
        // @orig 10c0:22a8 animated3d_play
        .player, .control_panel => animationPlay(g, obj, bd),
        // scene_object_play_default (absorbed)
        .scene_object, .wall_strip, .portable => {},
    }
}

// @orig 1038:23f2 animation_play
fn animationPlay(g: *Game, obj: *Object, bd: *Backdrop) void {
    _ = bd;
    if (!isLocked(g, obj)) {
        obj.anim.running = 1;
        obj.anim.playOnce = 0;
        g.setSystemTimer(@bitCast(obj.anim.timerId), @bitCast(obj.anim.timerPeriod));
    }
}

/// SceneObject slot 2F playIdle (default only).
pub fn playIdle(g: *Game, obj: *Object, bd: *Backdrop) void {
    // scene_object_play_idle_default (absorbed)
    _ = g;
    _ = obj;
    _ = bd;
}

/// SceneObject slot 30 stopAndRedrawDc (hdc, hwnd dropped): animated3d_stop_and_redraw_dc (exit, control_panel), actor_stop_and_redraw_dc (player) / default.
pub fn stopAndRedrawDc(g: *Game, obj: *Object, bd: *Backdrop) void {
    switch (obj.kind) {
        // @orig 10c0:26bc actor_stop_and_redraw_dc
        .player => {
            _ = setStrip(g, obj, 0, bd);
            animationStopAndRedrawDc(g, obj, bd);
        },
        // @orig 10c0:22fc animated3d_stop_and_redraw_dc
        .exit, .control_panel => animationStopAndRedrawDc(g, obj, bd),
        // scene_object_stop_and_redraw_dc_default (absorbed)
        .scene_object, .wall_strip, .portable => {},
    }
}

// @orig 1038:2543 animation_stop_and_redraw_dc
fn animationStopAndRedrawDc(g: *Game, obj: *Object, bd: *Backdrop) void {
    stop(g, obj);
    visibility.redraw(g, obj, bd);
    visibility.invalidate(g, obj);
}

/// SceneObject slot 31 stopAndRedraw: animated3d_stop_and_redraw (exit, control_panel), actor_stop_and_redraw (player) / default.
pub fn stopAndRedraw(g: *Game, obj: *Object, bd: *Backdrop) void {
    switch (obj.kind) {
        // @orig 10c0:2672 actor_stop_and_redraw
        .player => {
            _ = setStrip(g, obj, 0, bd);
            animationStopAndRedraw(g, obj, bd);
        },
        // @orig 10c0:22d2 animated3d_stop_and_redraw
        .exit, .control_panel => animationStopAndRedraw(g, obj, bd),
        // scene_object_stop_and_redraw_default (absorbed)
        .scene_object, .wall_strip, .portable => {},
    }
}

// @orig 1038:24de animation_stop_and_redraw
/// GetDC/ReleaseDC dropped around the (virtual) stopAndRedrawDc.
fn animationStopAndRedraw(g: *Game, obj: *Object, bd: *Backdrop) void {
    stopAndRedrawDc(g, obj, bd);
}

/// SceneObject slot 32 tick: exit_tick (exit), player_tick (player), control_panel_tick (control_panel) / default.
pub fn tick(g: *Game, obj: *Object, bd: *Backdrop) void {
    switch (obj.kind) {
        // @orig 1048:2785 exit_tick
        .exit => exitTick(g, obj, bd),
        // @orig 1048:246b player_tick
        .player => animated3dTick(g, obj, bd),
        // @orig 1078:069d control_panel_tick
        .control_panel => controlPanelTick(g, obj, bd),
        // scene_object_tick_default (absorbed)
        .scene_object, .wall_strip, .portable => {},
    }
}

/// Redraws `obj` and the player with their overlapping objects, the one in
/// front last (the shared tail of animated3d_tick and exit_tick).
fn redrawWithPlayer(g: *Game, obj: *Object, player: *Object, bd: *Backdrop) void {
    if (space3d.isInFrontOf(g, player, obj, bd)) {
        visibility.redrawOverlapping(g, obj, bd, 1);
        render.resetRects(player);
        visibility.redrawOverlapping(g, player, bd, 1);
        render.resetRects(obj);
    } else {
        visibility.redrawOverlapping(g, player, bd, 1);
        render.resetRects(obj);
        visibility.redrawOverlapping(g, obj, bd, 1);
    }
}

// @orig 1048:20ec animated3d_tick
/// Next frame, redraw; when the scene has a player other than this object
/// redraws both in depth order. In play-once mode counts down and stops.
fn animated3dTick(g: *Game, obj: *Object, bd: *Backdrop) void {
    _ = nextFrame(g, obj);
    render.resetRects(obj);
    visibility.redraw(g, obj, bd);
    // The original dereferences g_game->scene and ->player unchecked.
    const player = g.player.?;
    if (scene.getHasPlayer(g, g.scene.?) and player.is(.player) and obj.id != player.id) {
        redrawWithPlayer(g, obj, player.as(.player).?, bd);
    } else {
        visibility.redrawOverlapping(g, obj, bd, 1);
    }
    if (obj.anim.playOnce != 0) {
        obj.anim.framesLeft -%= 1;
        if (obj.anim.framesLeft < 1) stop(g, obj);
    }
}

/// The exit-finished post: the exit index when the player holds the key
/// object, else the alternative index unless it is -1.
fn postExitFinished(g: *Game, obj: *Object) void {
    if (hasKeyObject(g, obj, null)) {
        _ = g.post(.{ .id = msg.noite.exit_finished, .wparam = @bitCast(obj.exit.exitIndex) });
    } else if (obj.exit.altExitIndex != -1) {
        _ = g.post(.{ .id = msg.noite.exit_finished, .wparam = @bitCast(obj.exit.altExitIndex) });
    }
}

// @orig 1048:25c1 exit_play
/// No AVI path; a multi-frame exit plays its frames once, a one-frame (or
/// locked) one posts 0x402 at once.
fn exitPlay(g: *Game, obj: *Object, bd: *Backdrop) void {
    obj.exit.framesLeft = position.frameCount(obj) -% 1;
    obj.curFrame = 0;
    obj.exit.playing = 1;
    if (isLocked(g, obj)) {
        obj.exit.playing = 0;
        postExitFinished(g, obj);
        return;
    }
    if (obj.exit.framesLeft == 0) {
        obj.exit.playing = 0;
        postExitFinished(g, obj);
        return;
    }
    if (hasKeyObject(g, obj, null) or obj.exit.altExitIndex != -1) {
        if (scene.getHasPlayer(g, g.scene.?)) stop(g, g.player.?);
        animationPlay(g, obj, bd);
    }
}

// @orig 1048:2785 exit_tick
fn exitTick(g: *Game, obj: *Object, bd: *Backdrop) void {
    if (obj.exit.framesLeft == 0) {
        obj.exit.playing = 0;
        stop(g, obj);
        postExitFinished(g, obj);
        return;
    }
    obj.exit.framesLeft -%= 1;
    _ = nextFrame(g, obj);
    render.resetRects(obj);
    visibility.redraw(g, obj, bd);
    // No scene/id check; g_game->player is dereferenced unchecked.
    const player = g.player.?;
    if (player.is(.player)) {
        redrawWithPlayer(g, obj, player.as(.player).?, bd);
    } else {
        visibility.redrawOverlapping(g, obj, bd, 1);
    }
}

// @orig 1078:069d control_panel_tick
fn controlPanelTick(g: *Game, obj: *Object, bd: *Backdrop) void {
    const p = &obj.panel;
    if (p.slideStepsLeft == 0) {
        obj.anim.running = 0;
        obj.anim.playOnce = 0;
        return;
    }
    p.slideStepsLeft -%= 1;
    if (p.slideDir == 4) {
        _ = nextFrame(g, obj);
    } else {
        _ = prevFrame(g, obj);
    }
    if (p.slideStepsLeft == 0) {
        stop(g, obj);
        p.isOpen = if (p.slideDir == 8) 0 else 1;
    }
    render.erase(g, obj, bd);
    render.draw(g, obj, bd);
    visibility.redrawOverlapping(g, obj, bd, 1);
}

/// True when the exit needs no key object or `player` (the game's player
/// when null) carries the object whose id is the exit's key. The key is
/// never consumed in JARDIM.
// @orig 1048:2510 exit_has_key_object
pub fn hasKeyObject(g: *Game, obj: *Object, player: ?*Object) bool {
    const key = obj.exit.keyObject;
    if (key == 0) return true;
    const p = player orelse (g.player orelse @panic("exit.hasKeyObject: no player")).as(.player) orelse
        @panic("exit.hasKeyObject: asPlayer returned NULL"); // the original dereferences NULL
    var cur = p.actor.inventory.head;
    while (cur) |item| : (cur = item.next) {
        if (item.id == key) return true;
    }
    return false;
}

/// SceneObject slot 33 stop: animated3d_stop (exit, player, control_panel) / default.
pub fn stop(g: *Game, obj: *Object) void {
    switch (obj.kind) {
        // @orig 10c0:23f2 animated3d_stop
        .exit, .player, .control_panel => animationStop(g, obj),
        // scene_object_stop_default (absorbed)
        .scene_object, .wall_strip, .portable => {},
    }
}

// @orig 1038:25e9 animation_stop
fn animationStop(g: *Game, obj: *Object) void {
    obj.anim.running = 0;
    obj.anim.playOnce = 0;
    _ = g.post(.{ .id = msg.noite.animation_finished, .wparam = @bitCast(obj.id) });
    g.killSystemTimer(@bitCast(obj.anim.timerId));
}

/// SceneObject slot 3A getTimerId: moveable_get_timer_id (portable), animated3d_get_timer_id (exit, control_panel), actor_get_timer_id (player) / default.
pub fn getTimerId(g: *Game, obj: *Object) i16 {
    _ = g;
    return switch (obj.kind) {
        // @orig 10c0:250e moveable_get_timer_id
        .portable => moverGetTimerId(obj),
        // @orig 10c0:2416 animated3d_get_timer_id
        .exit, .control_panel => animationGetTimerId(obj),
        // @orig 10c0:2530 actor_get_timer_id
        .player => obj.mover.timerId,
        // scene_object_get_timer_id_default (absorbed)
        .scene_object, .wall_strip => -1,
    };
}

// @orig 10c0:1c4a mover_get_timer_id
fn moverGetTimerId(obj: *Object) i16 {
    return obj.mover.timerId;
}

// @orig 10c0:199e animation_get_timer_id
fn animationGetTimerId(obj: *Object) i16 {
    return obj.anim.timerId;
}

/// SceneObject slot 3C isRunning: animation_is_running (exit, player, control_panel) / default.
pub fn isRunning(g: *Game, obj: *Object) bool {
    _ = g;
    return switch (obj.kind) {
        // @orig 10c0:1866 animation_is_running
        .exit, .player, .control_panel => obj.anim.running != 0,
        // scene_object_is_running_default (absorbed)
        .scene_object, .wall_strip, .portable => false,
    };
}

/// AnimationVtbl / ControlPanelVtbl slot 00 lock (animation_lock).
// @orig 10c0:7102 animation_lock
pub fn lock(g: *Game, obj: *Object) void {
    _ = g;
    obj.anim.locked = 1;
}

/// AnimationVtbl / ControlPanelVtbl slot 01 isLocked (animation_is_locked).
// @orig 10c0:7122 animation_is_locked
pub fn isLocked(g: *Game, obj: *Object) bool {
    _ = g;
    return obj.anim.locked != 0;
}

/// AnimationVtbl / ControlPanelVtbl slot 02 (isLocked, then 0).
// @orig 1038:2362 animation_slot02_stub
pub fn slot02(g: *Game, obj: *Object) i16 {
    _ = isLocked(g, obj);
    return 0;
}

/// AnimationVtbl / ControlPanelVtbl slot 03 (isLocked, then 0).
// @orig 1038:2392 animation_slot03_stub
pub fn slot03(g: *Game, obj: *Object) i16 {
    _ = isLocked(g, obj);
    return 0;
}

/// AnimationVtbl / ControlPanelVtbl slot 04 (isLocked, then 0).
// @orig 1038:23c2 animation_slot04_stub
pub fn slot04(g: *Game, obj: *Object) i16 {
    _ = isLocked(g, obj);
    return 0;
}

/// AnimationVtbl / ControlPanelVtbl slot 05 playOnce (hwnd dropped). Does
/// nothing while locked; else counts the frames down from the strip's count
/// (minus one unless the rewind flag +0x10 is set).
// @orig 1038:2453 animation_play_once
pub fn playOnce(g: *Game, obj: *Object, bd: *Backdrop) void {
    _ = bd;
    if (isLocked(g, obj)) return;
    obj.anim.running = 1;
    obj.anim.framesLeft = position.frameCount(obj) -% @as(i16, if (obj.anim.rewinds == 0) 1 else 0);
    obj.anim.playOnce = 1;
    g.setSystemTimer(@bitCast(obj.anim.timerId), @bitCast(obj.anim.timerPeriod));
}

/// Animation::set_strip. When strip `strip` has another frame size than
/// the current one the object is hidden, switched and shown again (each
/// with an invalidate). Returns the (new) current strip's Frame.
// @orig 10c0:30b8 animation_set_strip
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
