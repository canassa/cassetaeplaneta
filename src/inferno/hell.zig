//! Port unit `hell` (module) of INFERNO.EXE. InfernoScene: its handler (the
//! 3-minute clock, keys, the 5 timer tests, WM_DESTROY, WM_CLOSE and the
//! 0x40a reports: BUGS.md H2, H4), create (MCI, WaveMix, the score box),
//! createScreen.
//!
//! The handler sees every window message first (non-zero = handled). hwnd
//! parameters are dropped; the GetDC/ReleaseDC pairs have no counterpart.
//! Where the original reaches an object through the virtual base, the
//! flattened `Object` is the SceneObject view (`obj.x`, `obj.curStrip`, ...).
//! BUGS.md H2 and H4 are reproduced as the code does them; each fix is
//! behind its `g.fixes.inferno_*` flag (docs/inferno/DESIGN.md).

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
const hazard = @import("hazard.zig");
const hero = @import("hero.zig");
const ledge = @import("ledge.zig");
const prop = @import("prop.zig");
const scene_unit = @import("scene.zig");
const score = @import("score.zig");
const sound = @import("sound.zig");
const animation = @import("behaviour/animation.zig");
const movement = @import("behaviour/movement.zig");
const visibility = @import("behaviour/visibility.zig");

const VK_LEFT: u16 = 0x25;
const VK_UP: u16 = 0x26;
const VK_RIGHT: u16 = 0x27;
const VK_DOWN: u16 = 0x28;
const VK_ADD: u16 = 0x6b;
const VK_SUBTRACT: u16 = 0x6d;

/// The scene's backdrop (the original dereferences it unchecked).
fn bdOf(scene: *Scene) *Backdrop {
    return scene.backdrop orelse @panic("inferno.hell: no backdrop");
}

/// The hero (`g_hero`, dereferenced unchecked).
fn heroOf(g: *Game) *Object {
    return g.hero orelse @panic("inferno.hell: no hero");
}

/// The original indexes the global arrays unchecked.
fn idx(i: i16) usize {
    return @as(u16, @bitCast(i));
}

/// The time-out result `0x40a (g_lives, g_lives ? 500 : g_score - 1000)`
/// (the lParam is the 16-bit value sign-extended).
fn postReport(g: *Game) void {
    const v: i16 = if (g.lives == 0) g.score -% 1000 else 500;
    _ = g.plat.postTo(g.noiteWnd, .{
        .id = msg.noite.minigame_result,
        .wparam = @bitCast(g.lives),
        .lparam = v,
    });
}

/// The clock, run first on every message: the 3-minute time-out posts the
/// result and restarts `startTick` as the grace period's start; during the
/// grace second the result is reposted every 100 ms (H2) and WM_DESTROY is
/// posted by every message once it has lasted a second.
fn clock(g: *Game) void {
    const now = g.plat.ticks();
    const elapsed: i32 = @bitCast(now -% g.startTick);
    if (elapsed < 180000 or g.timeUp != 0) {
        if (g.timeUp != 0) {
            const since: i32 = @bitCast(now -% g.lastReportTick);
            // H2: the reposts of the grace second.
            if (since >= 100 and !g.fixes.inferno_report_once) {
                g.lastReportTick = now;
                postReport(g);
            }
            const grace: i32 = @bitCast(now -% g.startTick);
            if (grace >= 1000) _ = g.post(.{ .id = msg.wm.destroy });
        }
    } else {
        g.timeUp = 1;
        postReport(g);
        g.startTick = now;
        g.lastReportTick = now;
        g.setSystemTimer(1, 55);
    }
}

/// SceneVtbl slot 00 handleMessage (inferno_scene_handle_message): non-zero =
/// handled.
// @orig 1068:4bdc inferno_scene_handle_message
pub fn handleMessage(g: *Game, scene: *Scene, m: Msg) i16 {
    clock(g);
    switch (m.id) {
        msg.wm.mousemove,
        msg.wm.lbuttondown,
        msg.wm.lbuttonup,
        msg.wm.rbuttondown,
        msg.wm.rbuttonup,
        => return 1,
        // WM_QUIT: never dispatched to a window procedure in practice.
        msg.wm.quit => {
            postReport(g);
            return 0;
        },
        msg.wm.destroy => {
            sound.stopAll(g);
            sound.freeAll(g);
            sound.mixClose(g);
            _ = g.plat.mciString("close musica");
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
        msg.wm.close => {
            if (g.fixes.inferno_close_forfeits) {
                // H4: closing the window forfeits.
                const v: i32 = if (g.fixes.inferno_loss_reports) @as(i32, g.score -% 1000) else 0;
                _ = g.plat.postTo(g.noiteWnd, .{ .id = msg.noite.minigame_result, .wparam = 0, .lparam = v });
            } else {
                postReport(g);
            }
            return 0;
        },
        msg.wm.keydown => {
            keyDown(g, scene, m.wparam);
            return 1;
        },
        msg.wm.keyup => {
            keyUp(g, scene, m.wparam);
            return 1;
        },
        msg.wm.systimer => return sysTimer(g, scene, m.wparam),
        msg.wm.mm_mcinotify => {
            if (m.wparam == msg.mci_notify_successful) _ = g.plat.mciString("play musica from 0 notify");
            return 1;
        },
        msg.wm.mm_wom_done => return 1,
        msg.noite.minigame_result => {
            _ = g.post(.{ .id = msg.wm.destroy });
            return 1;
        },
        else => return 0,
    }
}

/// The hero may take a key press: no latch, not in a jump, no animation.
fn heroFree(h: *Object, latch: i16) bool {
    return latch == 0 and h.hero.busy == 0 and h.anim.running == 0;
}

/// WM_KEYDOWN: LEFT / RIGHT walk, UP / numpad+ jump, DOWN / numpad- low jump.
fn keyDown(g: *Game, scene: *Scene, key: u16) void {
    const h = heroOf(g);
    const bd = bdOf(scene);
    switch (key) {
        VK_RIGHT => if (heroFree(h, g.keyRightHeld)) {
            g.heroTimerPending = 0;
            g.keyRightHeld = 1;
            h.hero.walking = 1;
            h.curStrip = if (h.hero.altStrips == 0) 1 else 5;
            h.curFrame = 0;
            h.hero.facing = 2;
            movement.moveToEdgeH(g, h, bd, 2);
        },
        VK_LEFT => if (heroFree(h, g.keyLeftHeld)) {
            g.keyLeftHeld = 1;
            g.heroTimerPending = 0;
            h.curStrip = if (h.hero.altStrips == 0) 3 else 7;
            h.curFrame = 0;
            h.hero.facing = 1;
            h.hero.walking = 1;
            movement.moveToEdgeH(g, h, bd, 1);
        },
        VK_UP, VK_ADD => if (heroFree(h, g.keyUpHeld)) {
            g.keyUpHeld = 1;
            jump(g, h, bd, 0);
        },
        VK_DOWN, VK_SUBTRACT => if (heroFree(h, g.keyDownHeld)) {
            g.keyDownHeld = 1;
            jump(g, h, bd, 2);
        },
        else => {},
    }
}

/// A jump of kind `kind` (0 / 2), or `kind + 1` after stopping a walk.
fn jump(g: *Game, h: *Object, bd: *Backdrop, kind: i16) void {
    if (h.hero.walking == 0) {
        h.hero.jumpKind = kind;
    } else {
        hero.stopMoving(g, h, bd);
        h.hero.jumpKind = kind + 1;
    }
    hero.startJump(g, h, bd);
}

/// The walk key's release: pose reset, re-placed where it stands, stopped.
fn walkKeyUp(g: *Game, h: *Object, bd: *Backdrop) void {
    h.hero.walking = 0;
    if (h.anim.running == 0) {
        hero.resetPose(g, h, bd);
        movement.placeAt(g, h, h.x, h.y, bd);
        visibility.invalidate(g, h);
        movement.stopMoving(g, h, bd);
    }
}

/// WM_KEYUP: a walk key's release is ignored while the hero is in a jump
/// (the latch stays until a tick sees it stopped).
fn keyUp(g: *Game, scene: *Scene, key: u16) void {
    const h = heroOf(g);
    switch (key) {
        VK_RIGHT => if (g.keyRightHeld != 0 and h.hero.busy == 0) {
            g.keyRightHeld = 0;
            walkKeyUp(g, h, bdOf(scene));
        },
        VK_LEFT => if (g.keyLeftHeld != 0 and h.hero.busy == 0) {
            g.keyLeftHeld = 0;
            walkKeyUp(g, h, bdOf(scene));
        },
        VK_UP, VK_ADD => g.keyUpHeld = 0,
        VK_DOWN, VK_SUBTRACT => g.keyDownHeld = 0,
        else => {},
    }
}

/// The hero's move tick: the walk latches clear once it stops moving.
fn heroMoveTick(g: *Game, h: *Object, bd: *Backdrop) void {
    movement.moveTick(g, h, bd);
    if (!movement.isMoving(g, h)) {
        g.keyLeftHeld = 0;
        g.keyRightHeld = 0;
    }
}

/// WM_SYSTIMER: the hero's move timer, the hero's animation timer, 0xc (the
/// drinks), the cross's timer, 0xe (the hazards); any other id (the keep-alive
/// 1 too) is not handled.
fn sysTimer(g: *Game, scene: *Scene, timer: u16) i16 {
    const bd = bdOf(scene);
    const h = heroOf(g);
    if (@as(u16, @bitCast(animation.getTimerId(g, h))) == timer) {
        // The power timer: big for 179 move ticks.
        if (h.hero.powerTimer < 2) {
            heroMoveTick(g, h, bd);
        } else {
            h.hero.powerTimer -%= 1;
            if (h.hero.powerTimer == 1) {
                hero.toggleSize(g, h, bd);
                g.keyLeftHeld = 0;
                g.keyRightHeld = 0;
            } else {
                heroMoveTick(g, h, bd);
            }
        }
    } else if (@as(u16, @bitCast(h.anim.timerId)) == timer) {
        animation.animationTick(g, h, bd);
        if (h.anim.running == 0 and h.curStrip >= 8 and h.curStrip <= 11) {
            hero.animDone(g, h, bd);
            g.keyLeftHeld = 0;
            g.keyRightHeld = 0;
        }
    } else if (timer == 0xc) {
        for (0..4) |i| {
            const plat = g.platforms[i] orelse @panic("inferno.hell: no platform");
            const drink = plat.platform.item orelse @panic("inferno.hell: no drink");
            if (drink.anim.running != 0) {
                animation.animationTick(g, drink, bd);
                if (drink.anim.running == 0) {
                    plat.platform.presentReady = 0;
                    ledge.dropCross(g, plat, bd);
                }
            }
        }
    } else {
        const cross = g.cross orelse @panic("inferno.hell: no cross");
        if (@as(u16, @bitCast(animation.getTimerId(g, cross))) == timer) {
            if (cross.mover.moving != 0) {
                prop.crossTick(g, cross, bd);
                if (cross.prop.state == 2) {
                    cross.prop.index -%= 1;
                    if (cross.prop.index == 0) {
                        movement.moverStopMoving(g, cross, bd);
                        cross.prop.state = 8;
                        movement.moverMoveToEdgeV(g, cross, bd, 8);
                        cross.prop.index = 0;
                    }
                }
            }
        } else {
            if (timer != 0xe) return 0;
            for (0..6) |i| {
                const hz = g.hazards[idx(g.hazardOrder[i])] orelse @panic("inferno.hell: no hazard");
                if (hz.prop.active != 0) hazard.tick(g, hz, bd);
            }
        }
    }
    return 1;
}

/// SceneVtbl slot 05 createScreen (inferno_scene_create_screen).
// @orig 1080:731c inferno_scene_create_screen
pub fn createScreen(g: *Game, scene: *Scene) ?*Backdrop {
    _ = scene;
    const bd = g.local().create(Backdrop) catch return null;
    bd.* = .{};
    return backdrop.ctor(g, bd, "Fundo.bmp", 0, 0, 0x280, 0x1e0);
}

/// SceneVtbl slot 07 create (inferno_scene_create; hwnd dropped).
// @orig 1068:0000 inferno_scene_create
pub fn create(g: *Game, scene: *Scene) ?*Scene {
    _ = scene_unit.create(g, scene);
    g.startTick = g.plat.ticks();
    _ = g.plat.mciString("open mario.mid type sequencer alias musica");
    _ = g.plat.mciString("play musica notify");
    _ = sound.mixInit(g);
    g.deathWave = sound.open(g, "sonicmor.wav");
    g.pickupWave = sound.open(g, "sonicpul.wav");
    g.magWave = sound.open(g, "sonicmag.wav");
    g.pickupWave2 = sound.open(g, "sonicpul.wav");
    _ = sound.playLoop(g, 0, sound.open(g, "sonicf.WAV"));
    const bd = bdOf(scene);
    score.drawScore(g, bd);
    score.blitScoreBox(g, bd);
    return scene;
}
