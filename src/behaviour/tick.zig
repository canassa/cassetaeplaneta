//! Port unit `tick` (behaviour). SceneObject slots 30 play and 34 tick (animation, 3D, exit, control panel, player).
//!
//! The GetDC/ReleaseDC pairs of the originals are gone (the DC is the
//! platform screen); so is the "Estouro no número de HDCs" box on a failed
//! GetDC, which cannot fail here.

const Game = @import("../core/game.zig").Game;
const msg = @import("../core/msg.zig");
const object = @import("../core/object.zig");
const Object = object.Object;
const world = @import("../core/world.zig");
const Backdrop = world.Backdrop;
const animation = @import("animation.zig");
const space3d = @import("space3d.zig");
const visibility = @import("visibility.zig");
const render = @import("render.zig");
const avi = @import("../avi.zig");
const exit = @import("../exit.zig");
const frames = @import("../frames.zig");
const scene = @import("../scene.zig");

/// SceneObject slot 30: start playing.
pub fn play(g: *Game, obj: *Object, bd: *Backdrop) void {
    switch (obj.kind) {
        // @orig 1010:1ad4 scene_object_play_default (absorbed)
        .local, .moveable, .portable, .status_bar => {},
        .animated, .actor, .player, .control_panel => animated3dPlay(g, obj, bd),
        .exit => exitPlay(g, obj, bd),
    }
}

/// SceneObject slot 34: one animation timer tick.
pub fn tick(g: *Game, obj: *Object, bd: *Backdrop) void {
    switch (obj.kind) {
        // @orig 1010:1afc scene_object_tick_default (absorbed)
        .local, .moveable, .portable, .status_bar => {},
        .animated, .actor => animated3dTick(g, obj, bd),
        .player => playerTick(g, obj, bd),
        .exit => exitTick(g, obj, bd),
        .control_panel => controlPanelTick(g, obj, bd),
    }
}

// @orig 1010:354c animated3d_play
fn animated3dPlay(g: *Game, obj: *Object, bd: *Backdrop) void {
    animationPlay(g, obj, bd);
}

// @orig 1010:ce60 animation_play
/// Starts the animation looping: an AVI clip is opened and played; a sprite
/// is marked running and its system timer started.
fn animationPlay(g: *Game, obj: *Object, bd: *Backdrop) void {
    _ = bd;
    if (!animation.isAvi(g, obj)) {
        obj.anim.running = 1;
        obj.anim.playOnce = 0;
        g.setSystemTimer(@bitCast(obj.anim.timerId), @bitCast(obj.anim.timerPeriod));
    } else {
        const dev = avi.openAvi(g, obj, avi.getAviName(g, obj));
        if (dev != 0) avi.playAvi(g, obj, dev);
    }
}

// @orig 1010:d170 animation_tick
/// Timer tick of a bare Animation (no kind uses it: the class is never
/// instantiated alone).
pub fn animationTick(g: *Game, obj: *Object, bd: *Backdrop) void {
    _ = animation.nextFrame(g, obj);
    frames.resetRects(obj);
    visibility.redraw(g, obj, bd);
    _ = visibility.invalidate(g, obj);
    if (obj.anim.playOnce != 0) {
        obj.framesLeft -%= 1;
        if (obj.framesLeft == 0) animation.stop(g, obj);
    }
}

/// Redraws `obj` and the player with their overlapping objects, the one in
/// front last (the shared tail of animated3d_tick and exit_tick).
fn redrawWithPlayer(g: *Game, obj: *Object, player: *Object, bd: *Backdrop) void {
    if (space3d.isInFrontOf(g, player, obj, bd)) {
        visibility.redrawOverlapping(g, obj, bd, 1);
        frames.resetRects(player);
        visibility.redrawOverlapping(g, player, bd, 1);
        frames.resetRects(obj);
    } else {
        visibility.redrawOverlapping(g, player, bd, 1);
        frames.resetRects(obj);
        visibility.redrawOverlapping(g, obj, bd, 1);
    }
}

// @orig 1010:631e animated3d_tick
/// Advances one frame and redraws the object; when the scene has a player
/// (other than this object) redraws both in depth order. In play-once mode
/// counts the frame down and stops the animation when done.
fn animated3dTick(g: *Game, obj: *Object, bd: *Backdrop) void {
    _ = animation.nextFrame(g, obj);
    frames.resetRects(obj);
    visibility.redraw(g, obj, bd);
    // The original dereferences g_game->scene and ->player unchecked.
    const player = g.player.?;
    if (scene.getHasPlayer(g, g.scene.?) and player.is(.player) and obj.id != player.id) {
        redrawWithPlayer(g, obj, player.as(.player).?, bd);
    } else {
        visibility.redrawOverlapping(g, obj, bd, 1);
    }
    if (obj.anim.playOnce != 0) {
        obj.framesLeft -%= 1;
        if (obj.framesLeft < 1) animation.stop(g, obj);
    }
}

// @orig 1010:65ee player_tick
fn playerTick(g: *Game, obj: *Object, bd: *Backdrop) void {
    animated3dTick(g, obj, bd);
}

/// The exit-finished post: the exit index when the player holds the key
/// object (consuming it), else the alternative index unless it is -1.
fn postExitFinished(g: *Game, obj: *Object) void {
    if (exit.hasKeyObject(g, obj, true, null)) {
        _ = g.post(.{ .id = msg.noite.exit_finished, .wparam = @bitCast(obj.exit.exitIndex) });
    } else if (obj.exit.altExitIndex != -1) {
        _ = g.post(.{ .id = msg.noite.exit_finished, .wparam = @bitCast(obj.exit.altExitIndex) });
    }
}

// @orig 1010:6742 exit_play
/// Activates the exit: an AVI exit opens and plays its clip, a multi-frame
/// sprite exit plays its frames once, a one-frame exit posts 0x402 at once.
fn exitPlay(g: *Game, obj: *Object, bd: *Backdrop) void {
    obj.exit.framesLeft = frames.frameCount(obj) -% 1;
    obj.curFrame = 0;
    obj.exit.playing = 1;
    if (animation.isAvi(g, obj) and exit.hasKeyObject(g, obj, false, null)) {
        const dev = avi.openAvi(g, obj, avi.getAviName(g, obj));
        if (dev == 0) return;
        if (obj.anim.aviDevice != 0) {
            avi.playAvi(g, obj, obj.anim.aviDevice);
        } else {
            // No device to wait for: fake the MCI completion.
            _ = g.post(.{ .id = msg.wm.mm_mcinotify, .wparam = msg.mci_notify_successful });
        }
        return;
    }
    if (obj.exit.framesLeft != 0) {
        if (obj.exit.altExitIndex == -1 and !exit.hasKeyObject(g, obj, false, null)) return;
        if (scene.getHasPlayer(g, g.scene.?)) animation.stop(g, g.player.?);
        animated3dPlay(g, obj, bd);
        return;
    }
    obj.exit.playing = 0;
    postExitFinished(g, obj);
}

// @orig 1010:68d4 exit_tick
/// Advances the exit animation one frame and redraws it and the player in
/// depth order; after the last frame stops it and posts 0x402.
fn exitTick(g: *Game, obj: *Object, bd: *Backdrop) void {
    if (obj.exit.framesLeft == 0) {
        obj.exit.playing = 0;
        animation.stop(g, obj);
        postExitFinished(g, obj);
        return;
    }
    obj.exit.framesLeft -%= 1;
    _ = animation.nextFrame(g, obj);
    frames.resetRects(obj);
    visibility.redraw(g, obj, bd);
    // Unlike animated3d_tick there is no scene/id check, and the original
    // dereferences g_game->player unchecked.
    const player = g.player.?;
    if (player.is(.player)) {
        redrawWithPlayer(g, obj, player.as(.player).?, bd);
    } else {
        visibility.redrawOverlapping(g, obj, bd, 1);
    }
}

// @orig 1018:22cc control_panel_tick
/// Advances the slide one frame (next frame going up, previous going
/// down); after the last step stops the animation and marks the panel open
/// (up) or closed (down); then erases, redraws and repaints it.
fn controlPanelTick(g: *Game, obj: *Object, bd: *Backdrop) void {
    const p = &obj.panel;
    if (p.slideStepsLeft == 0) {
        obj.anim.playOnce = 0;
        obj.anim.running = 0;
        return;
    }
    // B48: the slide down already shows the frame its first step goes to.
    const first = p.slideStepsLeft == frames.frameCount(obj);
    p.slideStepsLeft -%= 1;
    if (p.slideDir == 4) {
        _ = animation.nextFrame(g, obj);
    } else if (g.fixes.panel_close_keeps_open_frame and first) {
        // stays on the open frame
    } else {
        _ = animation.prevFrame(g, obj);
    }
    if (p.slideStepsLeft == 0) {
        animation.stop(g, obj);
        p.isOpen = if (p.slideDir == 8) 0 else 1;
    }
    render.erase(g, obj, bd);
    render.draw(g, obj, bd);
    visibility.redrawOverlapping(g, obj, bd, 1);
}

test "animationTick is analysed" {
    _ = &animationTick;
}
