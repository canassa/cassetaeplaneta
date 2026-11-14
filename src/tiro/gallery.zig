//! Port unit `gallery` (module) of TIRO.EXE. TiroScene: its handler (keys, the target and arrow timers, the second hit stage, the end test, WM_DESTROY and 0x40a; BUGS.md T1-T5), create (MCI, WaveMix, the score), createScreen.
//!
//! The handler sees every window message first (non-zero = handled) and
//! answers every key, timer and mouse message itself, so the engine's
//! input paths never run. hwnd parameters are dropped; the GetDC/ReleaseDC
//! pairs have no counterpart (the DC is the platform screen). Where the
//! original reads an object through the virtual base, the flattened
//! `Object` is the SceneObject view (`obj.x`, `obj.curStrip`, ...).
//! BUGS.md T1-T5 are reproduced as the code does them; each fix is behind
//! its `g.fixes.tiro_*` flag (docs/tiro/DESIGN.md "Fixes").

const msg = @import("../core/msg.zig");
const Msg = msg.Msg;
const platform = @import("../platform/platform.zig");
const Game = @import("core/game.zig").Game;
const object = @import("core/object.zig");
const Object = object.Object;
const world = @import("core/world.zig");
const Backdrop = world.Backdrop;
const Scene = world.Scene;
const arrow_unit = @import("arrow.zig");
const backdrop = @import("backdrop.zig");
const scene_unit = @import("scene.zig");
const sound = @import("sound.zig");
const target = @import("target.zig");
const animation = @import("behaviour/animation.zig");
const movement = @import("behaviour/movement.zig");
const position = @import("behaviour/position.zig");
const visibility = @import("behaviour/visibility.zig");

const VK_SPACE: u16 = 0x20;
const VK_LEFT: u16 = 0x25;
const VK_RIGHT: u16 = 0x27;

/// The scene's backdrop (the original dereferences it unchecked).
fn bdOf(scene: *Scene) *Backdrop {
    return scene.backdrop orelse @panic("tiro.gallery: no backdrop");
}

/// CRT `abs` on an int (`abs(-32768)` stays -32768).
fn absInt(v: i16) i16 {
    return if (v < 0) 0 -% v else v;
}

/// SceneVtbl slot 00 handleMessage (tiro_scene_handle_message): non-zero = handled.
// @orig 1068:1790 tiro_scene_handle_message
pub fn handleMessage(g: *Game, scene: *Scene, m: Msg) i16 {
    switch (m.id) {
        // The end: the waves and the music go, then the result goes to NOITE
        // (won = score > 0; no bonus or penalty added). Returns 0, so the
        // window procedure goes on (kills timer 1, posts WM_QUIT).
        msg.wm.destroy => {
            sound.stopAll(g);
            sound.freeAll(g);
            sound.mixClose(g);
            _ = g.plat.mciString("close musica");
            _ = g.plat.postTo(g.noiteWnd, .{
                .id = msg.noite.minigame_result,
                .wparam = @intFromBool(g.score > 0),
                .lparam = g.score,
            });
            return 0;
        },
        msg.wm.activate => {
            if (m.wparam != 0 and m.hi() == 0) {
                _ = g.plat.mciString("play musica notify");
                if (sound.mixActivate(g) == 0) {
                    _ = g.plat.messageBox("Erro Wave Mix", "N\xe3o consegue ativar", platform.mb.iconexclamation);
                }
            } else {
                _ = g.plat.mciString("pause musica");
                if (sound.mixDeactivate(g) == 0) {
                    _ = g.plat.messageBox("Erro Wave Mix", "N\xe3o consegue desativar", platform.mb.iconexclamation);
                }
            }
            return 0;
        },
        msg.wm.keydown => {
            switch (m.wparam) {
                VK_SPACE => keySpace(g, scene),
                VK_LEFT => if (g.keyLeftHeld == 0) {
                    g.keyLeftHeld = 1;
                    aimKey(g, scene, 'E');
                },
                VK_RIGHT => if (g.keyRightHeld == 0) {
                    g.keyRightHeld = 1;
                    aimKey(g, scene, 'D');
                },
                else => {},
            }
            return 1;
        },
        msg.wm.keyup => {
            switch (m.wparam) {
                VK_SPACE => g.keySpaceHeld = 0,
                VK_LEFT => g.keyLeftHeld = 0,
                VK_RIGHT => g.keyRightHeld = 0,
                else => {},
            }
            return 1;
        },
        msg.wm.systimer => return sysTimer(g, scene, m.wparam),
        // The music loops (every MM_MCINOTIFY is handled).
        msg.wm.mm_mcinotify => {
            if (m.wparam == 1) _ = g.plat.mciString("play musica from 0 notify");
            return 1;
        },
        msg.wm.mm_wom_done => {
            sound.stopAll(g);
            return 1;
        },
        // The mouse is swallowed (0x203 is not).
        msg.wm.mousemove,
        msg.wm.lbuttondown,
        msg.wm.lbuttonup,
        msg.wm.rbuttondown,
        msg.wm.rbuttonup,
        => return 1,
        else => return 0,
    }
}

/// LEFT / RIGHT: `crossbow_aim` ('E' / 'D'), then the crossbow's play slot
/// (re-arms its 60 ms timer).
fn aimKey(g: *Game, scene: *Scene, key: i16) void {
    arrow_unit.aim(g, key);
    animation.play(g, g.crossbow.?, bdOf(scene));
}

/// The crossbow's picture is redrawn where it stands: `mover_place_at` at its
/// own x, y, then `blitToDc`.
fn redrawCrossbow(g: *Game, bd: *Backdrop) void {
    const cb = g.crossbow.?;
    movement.placeAt(g, cb, cb.x, cb.y, bd);
    visibility.blitToDc(g, cb, bd);
}

/// The arrow is placed at (x, y) with picture `strip`, frame 0, and sent to
/// (dest_x, 10); the crossbow turns to its unloaded picture.
fn launch(g: *Game, bd: *Backdrop, x: i16, y: i16, strip: i16, dest_x: i16) void {
    const arrow = g.arrows[0].?;
    arrow.x = x;
    arrow.y = y;
    arrow.curStrip = strip;
    arrow.curFrame = 0;
    movement.moveTo(g, arrow, dest_x, 10, bd);
    g.crossbow.?.curStrip = 1;
}

/// WM_KEYDOWN VK_SPACE.
///
/// The original: when `g_keySpaceHeld` is 0 (it always is: nothing sets it,
/// BUGS.md T1) the arrow counter `lives` drops by one FIRST (T2), and only
/// then, if the one arrow is not flying, does the shot happen.
fn keySpace(g: *Game, scene: *Scene) void {
    if (g.keySpaceHeld != 0) return;
    // T1: the latch is set (as LEFT/RIGHT's); WM_KEYUP clears it.
    if (g.fixes.tiro_space_latch) g.keySpaceHeld = 1;
    const cb = g.crossbow.?;
    // T4: with every arrow gone SPACE does nothing.
    if (g.fixes.tiro_last_arrow_lands and cb.player2d.lives <= 0) return;
    // T2: the original spends the arrow before it looks whether it can fly.
    if (!g.fixes.tiro_arrow_spent_on_shot) cb.player2d.lives -%= 1;
    if (g.arrows[0].?.mover.moving != 0) return;
    if (g.fixes.tiro_arrow_spent_on_shot) cb.player2d.lives -%= 1;
    const bd = bdOf(scene);
    arrow_unit.playShotWave(g);
    switch (cb.curFrame) {
        2 => launch(g, bd, cb.x +% 0xa2, cb.y -% 0x14, 2, 0x280),
        1 => launch(g, bd, cb.x +% 0x75, cb.y -% 0x1e, 1, 0x14f),
        0 => launch(g, bd, cb.x +% 0x48, cb.y -% 0x1e, 0, 0),
        else => {},
    }
    redrawCrossbow(g, bd);
}

/// The end test of the four target branches: the original tests
/// `lives == 1`.
fn gameOver(g: *Game) bool {
    const lives = g.crossbow.?.player2d.lives;
    // T4: all 16 arrows fly; the game ends once the last one has stopped
    // (its hit, if any, is already scored). Implies T3.
    if (g.fixes.tiro_last_arrow_lands) return lives <= 0 and g.arrows[0].?.mover.moving == 0;
    // T3: `lives` may have jumped past 1.
    if (g.fixes.tiro_end_test_at_most_one) return lives <= 1;
    return lives == 1;
}

/// If the end test holds the handler sends itself WM_DESTROY (nested, as
/// SendMessage) and goes on with the tick.
fn endTest(g: *Game) void {
    if (gameOver(g)) _ = g.send(.{ .id = msg.wm.destroy });
}

/// WM_SYSTIMER: `wParam` is the timer id, tried against the crossbow, the
/// four targets and the arrow in that order. Always handled.
fn sysTimer(g: *Game, scene: *Scene, timer: u16) i16 {
    const bd = bdOf(scene);
    const cb = g.crossbow.?;
    if (@as(u16, @bitCast(animation.getTimerId(g, cb))) == timer) {
        animation.tick(g, cb, bd);
        return 1;
    }
    for (0..4) |i| {
        if (@as(u16, @bitCast(animation.getTimerId(g, g.targets[i].?))) == timer) {
            targetTick(g, bd, @intCast(i));
            return 1;
        }
    }
    const arrow = g.arrows[0].?;
    if (@as(u16, @bitCast(animation.getTimerId(g, arrow))) != timer) return 1;
    arrowTick(g, bd, arrow);
    return 1;
}

/// The pair guard of targets 0 and 3: `d = -(a.x - b.x)`; the edge test is
/// skipped while 0 <= d < `limit` (`b` is `limit` px or less ahead of it).
fn pairGuardHolds(a: *Object, b: *Object, limit: i16) bool {
    const d = 0 -% (a.x -% b.x);
    if (absInt(d) >= limit) return false;
    if (d < 0 and absInt(d) <= limit) return false;
    return true;
}

/// A target that is not moving (it just wrapped, or `target_respawn` left it
/// waiting) is re-armed at once on its own row: a new identity, the far
/// side. Rows 0 and 1 move right from x 0x18, rows 2 and 3 left from the
/// right edge.
fn rearm(g: *Game, bd: *Backdrop, t: *Object, index: usize) void {
    if (index < 2) {
        t.mover.direction = 2;
        t.y = 0x55;
        t.curStrip = @rem(g.rand.rand(), 10);
        movement.moveToEdgeH(g, t, bd, 2);
        t.mover.targetX = bd.bgWidth;
        t.x = 0x18;
    } else {
        t.mover.direction = 1;
        t.y = 0x82;
        t.curStrip = @rem(g.rand.rand(), 10);
        movement.moveToEdgeH(g, t, bd, 1);
        t.mover.targetX = 0;
        t.x = 0 -% (position.width(t) -% bd.bgWidth);
    }
    t.target.hitFrame = -1;
}

/// One tick of target `index`'s timer. Not in its hit animation: the edge
/// test (targets 0 and 3 wait while their pair is ahead of them), then the
/// re-arm if it is not moving; in it: the next hit frame, and the respawn
/// after the last. The end test runs first, except for target 2, where it
/// is inside the not-hit branch.
fn targetTick(g: *Game, bd: *Backdrop, index: usize) void {
    const t = g.targets[index].?;
    const idx: i16 = @intCast(index);
    if (index != 2) endTest(g);
    if (!animation.isRunning(g, t)) {
        if (index == 2) endTest(g);
        const waits = switch (index) {
            0 => pairGuardHolds(t, g.targets[1].?, 0x58),
            3 => pairGuardHolds(g.targets[2].?, t, 0xb0),
            else => false,
        };
        if (!waits) target.checkEdge(g, t, bd, idx);
        if (!movement.isMoving(g, t)) rearm(g, bd, t, index);
    } else {
        t.target.hitFrame +%= 1;
        if (t.target.hitFrame < t.anim.framesLeft) {
            animation.tick(g, t, bd);
        } else {
            target.respawn(g, t, bd, idx);
        }
    }
}

/// The second hit stage: does the arrow (x..x+55) overlap target `t`
/// (x..x+75) in x? Strict comparisons in the original's three cases
/// (arrow inside, the target's left edge inside the arrow, its right edge
/// inside), so a == t and a == t + 20 match none (T5). With the fix: the x
/// ranges overlap with touching edges counted and the y ranges overlap
/// too (arrow y..y+27, target y..y+95).
fn arrowOverlaps(g: *Game, a: *Object, t: *Object) bool {
    if (g.fixes.tiro_hit_needs_row) {
        return a.x <= t.x +% 0x4b and t.x <= a.x +% 0x37 and
            a.y <= t.y +% 0x5f and t.y <= a.y +% 0x1b;
    }
    if (t.x < a.x and a.x +% 0x37 < t.x +% 0x4b) return true;
    if (a.x < t.x and t.x < a.x +% 0x37) return true;
    return t.x < a.x and t.x +% 0x4b < a.x +% 0x37 and a.x < t.x +% 0x4b;
}

/// One tick of the arrow's timer: next frame, one step (`dir` comes back 3
/// when the arrow stopped against a target); a stopped arrow reloads the
/// crossbow; on a hit the arrow is stopped, the crossbow reloaded and the
/// hit goes to the first of targets 2, 3, 1, 0 that overlaps it (T5).
fn arrowTick(g: *Game, bd: *Backdrop, arrow: *Object) void {
    var dir: i16 = 0;
    _ = animation.nextFrame(g, arrow);
    arrow_unit.stepMove(g, arrow, bd, &dir);
    if (!movement.isMoving(g, arrow)) {
        g.crossbow.?.curStrip = 0;
        redrawCrossbow(g, bd);
    }
    if (dir != 3) return;
    movement.stopMoving(g, arrow, bd);
    g.crossbow.?.curStrip = 0;
    redrawCrossbow(g, bd);
    for ([_]usize{ 2, 3, 1, 0 }) |i| {
        const t = g.targets[i].?;
        if (arrowOverlaps(g, arrow, t)) {
            target.hit(g, t, bd, @intCast(i));
            return;
        }
    }
}

/// SceneVtbl slot 05 createScreen (tiro_scene_create_screen).
// @orig 1088:503e tiro_scene_create_screen
pub fn createScreen(g: *Game, scene: *Scene) ?*Backdrop {
    _ = scene;
    const bd = g.local().create(Backdrop) catch return null;
    bd.* = .{};
    return backdrop.ctor(g, bd, "Fundtiro.bmp", 0, 0, 0x280, 0x1e0);
}

/// SceneVtbl slot 07 create (tiro_scene_create; hwnd dropped).
// @orig 1068:008d tiro_scene_create
pub fn create(g: *Game, scene: *Scene) ?*Scene {
    _ = scene_unit.create(g, scene);
    _ = g.plat.mciString("open pac.mid type sequencer alias musica");
    _ = g.plat.mciString("play musica notify");
    _ = sound.mixInit(g);
    g.shotWave = sound.open(g, "ARCFLE02.WAV");
    g.girlHitWave = sound.open(g, "uii.wav");
    g.travecoHitWave = sound.open(g, "nossa.wav");
    g.hitWave = sound.open(g, "tirojogo.wav");
    g.pasars01Wave = sound.open(g, "PASARS01.WAV");
    const bd = bdOf(scene);
    target.drawScore(g, bd);
    target.blitScoreBox(g, bd);
    return scene;
}
