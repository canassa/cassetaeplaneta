//! Port unit `invasion` (module) of INV.EXE. InvScene: its handler (keys, every WM_SYSTIMER, the hit tests, the speed-up, the end, WM_DESTROY and 0x40a; BUGS.md I1, I2), create (MCI, WaveMix, the 8 waves, the score), createScreen, cannon_lose_life.
//!
//! The handler sees every window message first (non-zero = handled) and
//! answers every key, timer and mouse message itself. hwnd parameters are
//! dropped; the GetDC/ReleaseDC pairs have no counterpart (the DC is the
//! platform screen). The flattened `Object` is the SceneObject view
//! (`obj.x`, `obj.curStrip`, ...). BUGS.md I1 and I2 are reproduced as the
//! code does them; each fix is behind its `g.fixes.inv_*` flag
//! (docs/inv/DESIGN.md "Fixes").

const msg = @import("../core/msg.zig");
const Msg = msg.Msg;
const platform = @import("../platform/platform.zig");
const Game = @import("core/game.zig").Game;
const Object = @import("core/object.zig").Object;
const world = @import("core/world.zig");
const Backdrop = world.Backdrop;
const Scene = world.Scene;
const backdrop = @import("backdrop.zig");
const invaders = @import("invaders.zig");
const missiles = @import("missiles.zig");
const saucer_unit = @import("saucer.zig");
const scene_unit = @import("scene.zig");
const score = @import("score.zig");
const sound = @import("sound.zig");
const animation = @import("behaviour/animation.zig");
const movement = @import("behaviour/movement.zig");
const occupancy = @import("behaviour/occupancy.zig");
const position = @import("behaviour/position.zig");
const visibility = @import("behaviour/visibility.zig");

const VK_SPACE: u16 = 0x20;
const VK_LEFT: u16 = 0x25;
const VK_RIGHT: u16 = 0x27;

/// The scene's backdrop (the original dereferences it unchecked).
fn bdOf(scene: *Scene) *Backdrop {
    return scene.backdrop orelse @panic("inv.invasion: no backdrop");
}

/// CRT `abs` on an int (`abs(-32768)` stays -32768).
fn absInt(v: i16) i16 {
    return if (v < 0) 0 -% v else v;
}

/// `getTimerId` (slot 0xd4) compared with the message's wParam as unsigned.
fn timerIs(g: *Game, obj: *Object, timer: u16) bool {
    return @as(u16, @bitCast(animation.getTimerId(g, obj))) == timer;
}

/// SceneVtbl slot 00 handleMessage (inv_scene_handle_message): non-zero = handled.
// @orig 1068:1c9c inv_scene_handle_message
pub fn handleMessage(g: *Game, scene: *Scene, m: Msg) i16 {
    switch (m.id) {
        // The end: the waves and the music go, then the result goes to NOITE
        // (wParam is WM_DESTROY's own: 0xffff from the win, 0 from every loss;
        // no re-entry guard, every WM_DESTROY posts one). Returns 0.
        msg.wm.destroy => {
            sound.stopAll(g);
            sound.freeAll(g);
            sound.mixClose(g);
            _ = g.plat.mciString("close musica");
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
            return 0;
        },
        msg.wm.keydown => {
            switch (m.wparam) {
                VK_SPACE => keySpace(g, scene),
                VK_LEFT => if (g.keyLeftHeld == 0) {
                    g.keyLeftHeld = 1;
                    if (!holdsCannon(g)) startCannon(g, scene, 1);
                },
                VK_RIGHT => if (g.keyRightHeld == 0) {
                    g.keyRightHeld = 1;
                    if (!holdsCannon(g)) startCannon(g, scene, 2);
                },
                else => {},
            }
            return 1;
        },
        msg.wm.keyup => {
            switch (m.wparam) {
                VK_SPACE => g.keySpaceHeld = 0,
                VK_LEFT => {
                    g.keyLeftHeld = 0;
                    if (!holdsCannon(g)) releaseKey(g, scene, g.keyRightHeld != 0, 2);
                },
                VK_RIGHT => {
                    g.keyRightHeld = 0;
                    if (!holdsCannon(g)) releaseKey(g, scene, g.keyLeftHeld != 0, 1);
                },
                else => {},
            }
            return 1;
        },
        msg.wm.systimer => {
            sysTimer(g, scene, m.wparam);
            return 1;
        },
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

/// BUGS.md I2: with the fix, a direction key does not touch the cannon while
/// its explosion runs; only the latch changes. The explosion is strip 1,
/// from `cannon_lose_life` to the strip's end: `hitFrame` is still -1 until
/// the cannon's first tick, so it cannot tell.
fn holdsCannon(g: *Game) bool {
    return g.fixes.inv_explosion_holds_cannon and g.cannon.?.curStrip == 1;
}

/// LEFT / RIGHT down: `moveToEdgeH(dir)` (arms the 60 ms timer), then one
/// move tick now.
fn startCannon(g: *Game, scene: *Scene, dir: i16) void {
    const bd = bdOf(scene);
    const c = g.cannon.?;
    movement.moveToEdgeH(g, c, bd, dir);
    movement.moveTick(g, c, bd);
}

/// LEFT / RIGHT up: the other key still held resumes its direction (no step
/// now), else the cannon stops.
fn releaseKey(g: *Game, scene: *Scene, other_held: bool, other_dir: i16) void {
    const bd = bdOf(scene);
    const c = g.cannon.?;
    if (other_held) {
        movement.moveToEdgeH(g, c, bd, other_dir);
    } else {
        movement.stopMoving(g, c, bd);
    }
}

/// WM_KEYDOWN VK_SPACE: the fire gate (latch clear, the cannon not exploding,
/// the shot not flying), then the shot goes up. BUGS.md I1: nothing sets
/// `g_keySpaceHeld`, so key repeats refire; the fix sets it. BUGS.md I2:
/// the gate's `hitFrame` is -1 in the explosion's first tick too; the fix
/// also refuses while the explosion strip is on.
fn keySpace(g: *Game, scene: *Scene) void {
    if (g.keySpaceHeld != 0) return;
    if (g.fixes.inv_space_latch) g.keySpaceHeld = 1;
    const c = g.cannon.?;
    const shot = g.shots[0].?;
    if (c.cannon.hitFrame != -1 or shot.mover.moving != 0) return;
    if (holdsCannon(g)) return;
    const bd = bdOf(scene);
    shot.x = c.x +% 0x1b;
    shot.y = c.y -% 0x1e;
    score.playShotWave(g);
    movement.moveToEdgeV(g, shot, bd, 4);
    shot.curFrame = 0;
}

/// WM_SYSTIMER: the win test, then `wParam` is tried against the explosion,
/// the cannon, the saucer, the saucer's launch timer, the two bomb drop
/// timers, the two bombs, the shot and the columns, in that order.
fn sysTimer(g: *Game, scene: *Scene, timer: u16) void {
    const bd = bdOf(scene);
    // THE WIN: on any tick once the last invader is gone.
    if (g.invadersLeft == 0) {
        _ = g.send(.{ .id = msg.wm.destroy, .wparam = 0xffff });
        g.invadersLeft = -1;
    }
    const ex = g.invaderExplosion.?;
    if (timerIs(g, ex, timer)) {
        explosionTick(g, bd, ex);
        return;
    }
    const cannon = g.cannon.?;
    if (timerIs(g, cannon, timer)) {
        cannonTick(g, bd, cannon);
        return;
    }
    const sau = g.saucer.?;
    if (timerIs(g, sau, timer)) {
        saucerTick(g, bd, sau);
        return;
    }
    if (@as(u16, @bitCast(sau.saucer.timer2Id)) == timer) {
        // The launch: no check that the last saucer is gone.
        occupancy.placeAt(g, sau, 50, 10, bd);
        visibility.blitToDc(g, sau, bd);
        score.playSaucerWave(g);
        movement.moveToEdgeH(g, sau, bd, 2);
        return;
    }
    if (@as(u16, @bitCast(g.bombs[0].?.missile.timer2Id)) == timer) {
        bombDrop(g, bd, 0);
        return;
    }
    if (@as(u16, @bitCast(g.bombs[1].?.missile.timer2IdB)) == timer) {
        bombDrop(g, bd, 1);
        return;
    }
    for (0..2) |i| {
        if (timerIs(g, g.bombs[i].?, timer)) {
            bombTick(g, bd, i);
            return;
        }
    }
    const shot = g.shots[0].?;
    if (timerIs(g, shot, timer)) {
        shotTick(g, bd, shot);
        return;
    }
    if (timerIs(g, g.invaderColumns[0].?, timer)) {
        formationTick(g, bd);
    }
}

/// The explosion's own timer (0x10): frames 1.., then it stops.
fn explosionTick(g: *Game, bd: *Backdrop, ex: *Object) void {
    if (!animation.isRunning(g, ex)) return;
    if (ex.invader.frameCounter < position.frameCount(ex) -% 1) {
        animation.tick(g, ex, bd);
        ex.invader.frameCounter +%= 1;
    } else {
        animation.stop(g, ex);
        ex.invader.frameCounter = 0;
    }
}

/// The cannon's timer (0xa): walking, or the steps of its explosion strip.
fn cannonTick(g: *Game, bd: *Backdrop, c: *Object) void {
    if (!animation.isRunning(g, c) or movement.isMoving(g, c)) {
        // BUGS.md I2: a direction key during the explosion makes the cannon
        // move, which lands here and ends the explosion.
        movement.moveTick(g, c, bd);
        c.cannon.hitFrame = -1;
        return;
    }
    c.cannon.hitFrame +%= 1;
    if (c.cannon.hitFrame < c.anim.framesLeft) {
        animation.tick(g, c, bd);
        return;
    }
    animation.stopAndRedraw(g, c, bd);
    c.cannon.hitFrame = -1;
    c.curStrip = 0;
    visibility.blitToDc(g, c, bd);
    // The held key resumes (right first).
    if (g.keyRightHeld != 0) {
        movement.moveToEdgeH(g, c, bd, 2);
        movement.moveTick(g, c, bd);
    } else if (g.keyLeftHeld != 0) {
        movement.moveToEdgeH(g, c, bd, 1);
        movement.moveTick(g, c, bd);
    }
}

/// The saucer's timer (0xc): a step, or the steps of its explosion strip.
fn saucerTick(g: *Game, bd: *Backdrop, s: *Object) void {
    if (!animation.isRunning(g, s)) {
        saucer_unit.checkEdge(g, s, bd);
        return;
    }
    s.saucer.hitFrame +%= 1;
    if (s.saucer.hitFrame < s.anim.framesLeft) {
        animation.tick(g, s, bd);
        return;
    }
    animation.stopAndRedraw(g, s, bd);
    s.saucer.hitFrame = -1;
    visibility.hideAndInvalidate(g, s, 0, bd);
    visibility.blitToDc(g, s, bd);
    s.curFrame = 0;
}

/// A bomb drop timer (bomb `i`: 8 or 9): the bomb leaves the lowest invader
/// of each column within the cannon's reach (no break, but the bomb is
/// moving after the first).
fn bombDrop(g: *Game, bd: *Backdrop, i: usize) void {
    const bomb = g.bombs[i].?;
    const cannon = g.cannon.?;
    for (g.invaderColumns) |col_opt| {
        const col = col_opt.?;
        if (col.invader.lowestAlive == -1) continue;
        const w = position.width(col);
        if (absInt(0 -% (cannon.x -% col.x)) <= w and bomb.mover.moving == 0) {
            bomb.x = col.x +% 0x2c;
            bomb.y = (col.invader.lowestAlive +% 1) *% 0x2c +% col.y;
            bomb.curStrip = 0;
            bomb.curFrame = 0;
            movement.moveToEdgeV(g, bomb, bd, 8);
            g.bombHitCannon[i] = 0;
        }
    }
}

/// A bomb's timer (6 / 7): a step and the hit tests, or its impact strip.
fn bombTick(g: *Game, bd: *Backdrop, i: usize) void {
    const bomb = g.bombs[i].?;
    if (!animation.isRunning(g, bomb)) {
        missiles.moveTick(g, bomb, bd);
        const c = g.cannon.?;
        if (c.x < bomb.x and bomb.x < c.x +% 0x41 and 0x19a < bomb.y) bomb.missile.hitState = '4';
        switch (bomb.missile.hitState) {
            '1' => {
                score.playExplo5Wave(g);
                missiles.shotVanish(g, g.shots[0].?, bd);
                missiles.bombShotDown(g, bomb, bd);
            },
            '4' => if (g.bombHitCannon[i] == 0) {
                g.bombHitCannon[i] = 1;
                score.cannonHit(g, bd);
                cannonLoseLife(g, bd);
            },
            else => {},
        }
        bomb.missile.hitState = 0;
        return;
    }
    bomb.missile.hitFrame +%= 1;
    if (bomb.missile.hitFrame < bomb.anim.framesLeft) {
        animation.tick(g, bomb, bd);
        return;
    }
    animation.stopAndRedraw(g, bomb, bd);
    bomb.missile.hitFrame = -1;
    visibility.hideAndInvalidate(g, bomb, 0, bd);
    visibility.blitToDc(g, bomb, bd);
}

/// The shot's timer (0xd): a step, then what it met (`hitState`).
fn shotTick(g: *Game, bd: *Backdrop, shot: *Object) void {
    missiles.moveTick(g, shot, bd);
    switch (shot.missile.hitState) {
        '2' => invaderHit(g, bd, shot),
        '3' => {
            score.saucerHit(g, bd);
            saucer_unit.explode(g, g.saucer.?, bd);
            g.cannon.?.player2d.score +%= 50;
        },
        else => {},
    }
    shot.missile.hitState = 0;
}

/// The second hit stage: the columns whose x range holds the shot and whose
/// lowest live invader is on the shot's row lose it. No break (the live
/// columns stay 108 px apart, so at most one holds the shot).
fn invaderHit(g: *Game, bd: *Backdrop, shot: *Object) void {
    const ex = g.invaderExplosion.?;
    for (g.invaderColumns) |col_opt| {
        const col = col_opt.?;
        if (!(col.x < shot.x and shot.x < col.x +% 0x58)) continue;
        // (shot.y - col.y) / 44, signed IDIV truncating toward 0.
        const row = @divTrunc(0 -% (col.y -% shot.y), 0x2c);
        if (col.invader.lowestAlive != row) continue;
        // Row -1 matches only an emptied column (lowestAlive -1), with the
        // shot 44 px or more above its top: the original then takes
        // cells[-1] (the column's +0x4c..+0x51) as a kill (BUGS.md, INV
        // Harmless). An emptied column stops stepping, so the live ones
        // pass under it, and shots are flagged up to 36 px above its top,
        // but never 44 in thousands of games; the port skips it, having no
        // such memory to read.
        if (row < 0) continue;
        const cell = &col.invader.cells[@intCast(row)];
        cell.alive = 0;
        ex.x = cell.x;
        ex.y = cell.y;
        _ = invaders.updateLowestAlive(col);
        score.invaderHit(g, bd);
        missiles.shotVanish(g, shot, bd);
        invaders.explosionStart(g, bd);
        g.cannon.?.player2d.score +%= 10;
        speedUp(g);
    }
}

/// --g_invadersLeft and the formation's speed-up: every fifth kill (15, 10,
/// 5 and 0) 100 ms faster, the second to last at 55; the last kill leaves
/// -45 (65491 ms as UINT). The `< 1` branch is dead (0 % 5 == 0 comes first).
fn speedUp(g: *Game) void {
    g.invadersLeft -%= 1;
    if (@rem(g.invadersLeft, 5) == 0) {
        g.invaderPeriod -%= 100;
        rearmColumns(g);
    } else if (g.invadersLeft == 1) {
        g.invaderPeriod = 0x37;
        rearmColumns(g);
    } else if (g.invadersLeft < 1) {
        _ = g.send(.{ .id = msg.wm.destroy });
    }
}

/// SetSystemTimer(columns[0]'s timer, g_invaderPeriod); every column's
/// mover and animation period follow (3..0).
fn rearmColumns(g: *Game) void {
    const id: u16 = @bitCast(animation.getTimerId(g, g.invaderColumns[0].?));
    g.setSystemTimer(id, @bitCast(g.invaderPeriod));
    var i: usize = g.invaderColumns.len;
    while (i > 0) {
        i -= 1;
        const col = g.invaderColumns[i].?;
        col.mover.timerPeriod = g.invaderPeriod;
        col.anim.timerPeriod = g.invaderPeriod;
    }
}

/// The columns' timer (0xf): lost once nothing is left (no step), else the
/// march wave and the formation step: the leader at the moving side steps
/// first; at an edge the direction flips and the columns not stepped yet turn.
fn formationTick(g: *Game, bd: *Backdrop) void {
    if (g.invadersLeft < 1) {
        _ = g.send(.{ .id = msg.wm.destroy });
        return;
    }
    score.playMarchWave(g);
    const cols = &g.invaderColumns;
    if (g.formationDir == 2) {
        var col: i16 = 3;
        while (col >= 0) : (col -= 1) {
            const c = cols[@intCast(col)].?;
            if (c.invader.lowestAlive == -1) continue;
            invaders.step(g, c, bd);
            if (c.invader.atEdge == 0) continue;
            g.formationDir = 1;
            c.invader.atEdge = 0;
            var t: i16 = 0;
            while (t < col) : (t += 1) {
                const tc = cols[@intCast(t)].?;
                if (tc.invader.lowestAlive != -1) invaders.turn(g, tc, bd);
            }
            break;
        }
    } else {
        var col: i16 = 0;
        while (col < 4) : (col += 1) {
            const c = cols[@intCast(col)].?;
            if (c.invader.lowestAlive == -1) continue;
            invaders.step(g, c, bd);
            if (c.invader.atEdge == 0) continue;
            g.formationDir = 2;
            c.invader.atEdge = 0;
            var t: i16 = col + 1;
            while (t < 4) : (t += 1) {
                const tc = cols[@intCast(t)].?;
                if (tc.invader.lowestAlive != -1) invaders.turn(g, tc, bd);
            }
            break;
        }
    }
}

/// A bomb hit the cannon: one life less; at 0 the game is lost (WM_DESTROY,
/// wParam 0), else the cannon explodes (strip 1, `hitFrame` -1, 7 frames,
/// not moving, one animation play-once and a first tick).
// @orig 1068:07a6 cannon_lose_life
fn cannonLoseLife(g: *Game, bd: *Backdrop) void {
    const c = g.cannon.?;
    c.player2d.lives -%= 1;
    if (c.player2d.lives < 1) {
        _ = g.send(.{ .id = msg.wm.destroy });
    } else {
        c.curStrip = 1;
        c.cannon.hitFrame = -1;
        c.anim.framesLeft = 7;
        c.mover.moving = 0;
        animation.playOnce(g, c, bd);
        animation.tick(g, c, bd);
    }
}

/// SceneVtbl slot 05 createScreen (inv_scene_create_screen: `Espaco.bmp`).
// @orig 1088:571c inv_scene_create_screen
pub fn createScreen(g: *Game, scene: *Scene) ?*Backdrop {
    _ = scene;
    const bd = g.local().create(Backdrop) catch return null;
    bd.* = .{};
    return backdrop.ctor(g, bd, "Espaco.bmp", 0, 0, 0x280, 0x1e0);
}

/// SceneVtbl slot 07 create (inv_scene_create; hwnd dropped): MCI `doom1.mid`,
/// WaveMix, the eight waves, the score box.
// @orig 1068:0026 inv_scene_create
pub fn create(g: *Game, scene: *Scene) ?*Scene {
    _ = scene_unit.create(g, scene);
    _ = g.plat.mciString("open doom1.mid type sequencer alias musica");
    _ = g.plat.mciString("play musica notify");
    _ = sound.mixInit(g);
    g.shotWave = sound.open(g, "tiroes2.wav");
    g.explosWave = sound.open(g, "explos.wav");
    g.saucerWave = sound.open(g, "nave.wav");
    g.explo1Wave = sound.open(g, "explo1.wav");
    g.cannonHitWave = sound.open(g, "brocha3.wav");
    g.explo5Wave = sound.open(g, "explo5.WAV");
    g.marchWave = sound.open(g, "marcha.wav");
    g.descendWave = sound.open(g, "desceniv.wav");
    const bd = bdOf(scene);
    score.drawScore(g, bd);
    score.blitScoreBox(g, bd);
    return scene;
}
