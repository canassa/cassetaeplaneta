//! Port unit `maze` (module) of SAUNA.EXE. SaunaScene: its handler (power start/end, keys, the three timers, the death, 0x401 srand + ghost start, WM_DESTROY and 0x40a; BUGS.md P6, P7), create (the dots, MCI, WaveMix, the score box), createScreen.
//!
//! The handler sees every window message first (non-zero = handled): once
//! the scene is built (`handlerEnabled`) it answers the keys, the timers,
//! the music and the end itself; everything else (the mouse included) it
//! declines, so the engine's default runs. hwnd parameters are dropped and
//! the GetDC/ReleaseDC pairs have no counterpart (the DC is the platform
//! screen). Where the original reaches an object through the virtual base,
//! the flattened `Object` is the SceneObject view.
//! BUGS.md P6 and P7 are reproduced as the code does them; their fixes are
//! behind `g.fixes.sauna_ghosts_wait_while_dying` (the ghosts' arm skips
//! them while Pacman dies) and `g.fixes.sauna_no_arrows_while_dying`
//! (docs/sauna/DESIGN.md "Fixes"); P4 lives in `animation` (every caller
//! passes dir 2).

const msg = @import("../core/msg.zig");
const Msg = msg.Msg;
const platform = @import("../platform/platform.zig");
const Game = @import("core/game.zig").Game;
const object = @import("core/object.zig");
const Object = object.Object;
const world = @import("core/world.zig");
const Backdrop = world.Backdrop;
const Scene = world.Scene;
const backdrop = @import("backdrop.zig");
const ghost = @import("ghost.zig");
const lists = @import("lists.zig");
const scene_unit = @import("scene.zig");
const score = @import("score.zig");
const sound = @import("sound.zig");
const animation = @import("behaviour/animation.zig");
const movement = @import("behaviour/movement.zig");
const occupancy = @import("behaviour/occupancy.zig");
const render = @import("behaviour/render.zig");
const visibility = @import("behaviour/visibility.zig");

/// The power mode lasts 5 s (timer 10).
const POWER_TIMER: u16 = 10;
const POWER_MS: u16 = 5000;
/// Pacman's death strip.
const DEATH_STRIP: i16 = 8;

/// The scene's backdrop (the original dereferences it unchecked).
fn bdOf(scene: *Scene) *Backdrop {
    return scene.backdrop orelse @panic("sauna.maze: no backdrop");
}

/// SceneVtbl slot 00 handleMessage (sauna_scene_handle_message): non-zero = handled.
// @orig 1080:32f7 sauna_scene_handle_message
pub fn handleMessage(g: *Game, scene: *Scene, m: Msg) i16 {
    if (scene.handlerEnabled == 0) return 0;
    const bd = bdOf(scene);
    // The deferred power start: a cork was eaten (`powerStartPending`), so
    // on the next message of any kind Pacman and the ghosts re-pick their
    // strips and the 5-s timer starts.
    if (g.powerStartPending != 0) {
        g.powerStartPending = 0;
        animation.refreshPowerStrip(g, g.pacman.?, bd, 2);
        for (scene.ghosts) |gh| ghost.chooseDirection(g, gh.?, bd);
        g.setSystemTimer(POWER_TIMER, POWER_MS);
    }
    switch (m.id) {
        msg.wm.keyup => {
            if (m.wparam >= msg.vk.left and m.wparam <= msg.vk.down) {
                g.keyLeftHeld = 0;
                g.keyRightHeld = 0;
                g.keyUpHeld = 0;
                g.keyDownHeld = 0;
            }
            return 1;
        },
        // The end: the waves and the music go, then +1000 (won: wParam
        // non-zero) or -1000 and the result goes to NOITE. Returns 0, so the
        // window procedure goes on (kills timer 1, posts WM_QUIT). There is
        // no guard against a second WM_DESTROY.
        msg.wm.destroy => {
            sound.stopAll(g);
            sound.freeAll(g);
            sound.mixClose(g);
            _ = g.plat.mciString("close musica");
            g.score +%= if (m.wparam == 0) -1000 else 1000;
            _ = g.plat.postTo(g.noiteWnd, .{
                .id = msg.noite.minigame_result,
                .wparam = m.wparam,
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
            return 1;
        },
        msg.wm.keydown => {
            keyDown(g, scene, m.wparam);
            return 1;
        },
        msg.wm.systimer => {
            sysTimer(g, scene, m.wparam);
            return 1;
        },
        // The music loops.
        msg.wm.mm_mcinotify => {
            if (m.wparam == msg.mci_notify_successful) _ = g.plat.mciString("play musica from 0 notify");
            return 1;
        },
        msg.wm.mm_wom_done => {
            sound.stopAll(g);
            return 1;
        },
        // The start: the ghosts begin to walk.
        msg.noite.scene_started => {
            g.rand.srand(@truncate(g.plat.ticks()));
            for (scene.ghosts) |gh| ghost.chooseDirection(g, gh.?, bd);
            return 1;
        },
        else => return 0,
    }
}

/// WM_KEYDOWN (every key answers 1): an arrow not already held stops Pacman
/// and sends him to the wall (1 left, 2 right, 4 up, 8 down). P7: the
/// original does this while he dies too; the fix ignores the arrows then.
fn keyDown(g: *Game, scene: *Scene, key: u16) void {
    if (g.fixes.sauna_no_arrows_while_dying and g.pacmanDying != 0) return;
    const bd = bdOf(scene);
    const pac = g.pacman.?;
    switch (key) {
        msg.vk.left => if (g.keyLeftHeld == 0) {
            g.keyLeftHeld = 1;
            movement.moveToEdgeH(g, pac, bd, 1);
        },
        msg.vk.up => if (g.keyUpHeld == 0) {
            g.keyUpHeld = 1;
            movement.moveToEdgeV(g, pac, bd, 4);
        },
        msg.vk.right => if (g.keyRightHeld == 0) {
            g.keyRightHeld = 1;
            movement.moveToEdgeH(g, pac, bd, 2);
        },
        msg.vk.down => if (g.keyDownHeld == 0) {
            g.keyDownHeld = 1;
            movement.moveToEdgeV(g, pac, bd, 8);
        },
        else => {},
    }
}

/// `isMoving ? moveTick : tick`.
fn actorTick(g: *Game, obj: *Object, bd: *Backdrop) void {
    if (movement.isMoving(g, obj)) {
        movement.moveTick(g, obj, bd);
    } else {
        animation.tick(g, obj, bd);
    }
}

/// WM_SYSTIMER: `wParam` is the timer id, tried against Pacman's (0x10),
/// the ghosts' (0x11, shared) and the power end (10, only while powered).
/// Any other id does nothing. The update list is flushed at the end.
fn sysTimer(g: *Game, scene: *Scene, timer: u16) void {
    const bd = bdOf(scene);
    const pac = g.pacman.?;
    if (@as(u16, @bitCast(animation.getTimerId(g, pac))) == timer) {
        if (g.pacmanDying == 0) {
            actorTick(g, pac, bd);
        } else {
            deathTick(g, bd, pac);
        }
    } else if (@as(u16, @bitCast(animation.getTimerId(g, scene.ghosts[0].?))) == timer) {
        // No `pacmanDying` test: the ghosts walk on during the death (P6).
        // The fix makes them wait until Pacman reappears.
        if (!(g.fixes.sauna_ghosts_wait_while_dying and g.pacmanDying != 0)) {
            for (scene.ghosts) |gh| actorTick(g, gh.?, bd);
        }
    } else if (timer == POWER_TIMER and g.powerStrip == 4) {
        g.powerStrip = 0;
        animation.refreshPowerStrip(g, pac, bd, 2);
        for (scene.ghosts) |gh| ghost.chooseDirection(g, gh.?, bd);
        score.powerStopWave(g);
        g.killSystemTimer(POWER_TIMER);
    }
    if (!lists.updateIsEmpty(&g.updateList)) lists.updateFlush(g, &g.updateList, bd);
}

/// Pacman's timer while he dies. The first tick (his strip is still a
/// walking one, < 8) slows the timer to 110 ms, switches to the 6-frame
/// death strip and counts 5 more frames; each tick shows the next; after
/// the last he reappears at (300, 304) facing left, standing at the
/// normal period. The keys are released. A walk started by an arrow
/// meanwhile (P7) is neither stopped nor cleared here.
fn deathTick(g: *Game, bd: *Backdrop, pac: *Object) void {
    if (@as(u16, @bitCast(pac.curStrip)) < 8) {
        g.setSystemTimer(@bitCast(animation.getTimerId(g, pac)), 0x6e);
        _ = animation.setStrip(g, pac, DEATH_STRIP, bd);
        g.deathFramesLeft = 5;
    }
    if (g.deathFramesLeft < 1) {
        g.pacmanDying = 0;
        visibility.hide(g, pac, bd);
        visibility.blitToDc(g, pac, bd);
        pac.x = 300;
        pac.nextX = pac.x;
        pac.y = 0x130;
        pac.nextY = pac.y;
        _ = animation.setStrip(g, pac, 0, bd);
        g.setSystemTimer(@bitCast(animation.getTimerId(g, pac)), @bitCast(pac.mover.timerPeriod));
        visibility.show(g, pac, bd);
        visibility.invalidate(g, pac);
        g.keyLeftHeld = 0;
        g.keyRightHeld = 0;
        g.keyUpHeld = 0;
        g.keyDownHeld = 0;
    } else {
        animation.tick(g, pac, bd);
        g.deathFramesLeft -%= 1;
    }
}

/// SceneVtbl slot 05 createScreen (sauna_scene_create_screen).
// @orig 1080:2d5b sauna_scene_create_screen
pub fn createScreen(g: *Game, scene: *Scene) ?*Backdrop {
    _ = scene;
    const bd = g.local().create(Backdrop) catch return null;
    bd.* = .{};
    return backdrop.ctor(g, bd, "3fpac2.bmp", 0, 0, 0x280, 0x1e0);
}

/// SceneVtbl slot 07 create (sauna_scene_create; hwnd dropped).
// @orig 1080:2f14 sauna_scene_create
pub fn create(g: *Game, scene: *Scene) ?*Scene {
    g.saunaScene = scene;
    _ = scene_unit.create(g, scene);
    const bd = bdOf(scene);
    for (scene.ghosts) |gh| _ = occupancy.attach(g, gh.?, bd);
    const peanut = scene.peanut.?;
    const cork = scene.cork.?;
    _ = occupancy.attach(g, peanut, bd);
    _ = occupancy.attach(g, cork, bd);
    // The dots: '2' a peanut, '3' a cork, drawn into the view and stamped
    // into the background.
    for (0..30) |row| {
        for (0..40) |col| {
            const dot: *Object = switch (g.maze[row][col]) {
                '2' => peanut,
                '3' => cork,
                else => continue,
            };
            dot.x = @intCast(col * 16 + 8);
            dot.y = @intCast(row * 16 + 10);
            render.draw(g, dot, bd);
            render.unk18(g, dot, bd);
        }
    }
    backdrop.blitToDc(g, bd);
    _ = g.plat.mciString("open pac.mid type sequencer alias musica");
    _ = g.plat.mciString("play musica notify");
    _ = sound.mixInit(g);
    g.powerWave = sound.open(g, "pacman2.wav");
    g.eatGhostWave = sound.open(g, "pacman4.wav");
    g.eatPeanutWave = sound.open(g, "pacman.wav");
    g.caughtWave = sound.open(g, "pacman3.wav");
    g.powerLoopWave = sound.open(g, "control.wav");
    g.paintWave = sound.open(g, "ROLHAS01.WAV");
    score.drawScore(g, bd);
    score.blitScoreBox(g, bd);
    return scene;
}
