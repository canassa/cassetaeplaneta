//! Port unit `arena` (module) of SALGIN.EXE. SalginScene: its handler (the GetTickCount beat, clock and end ticks; the keys and latches; the fighter's blows, the opponent's approach and attack, the KO and the clock end, WM_DESTROY and 0x40a), create (MCI, WaveMix, the waves), createScreen.
//!
//! The handler sees every message first (non-zero = handled). hwnd/hdc
//! parameters are dropped (the DC is the platform screen), so the stale
//! `ReleaseDC(clockDc)` of the Left/Right key-up has no counterpart. The
//! original reads the two fighters through their virtual base; the flattened
//! `Object` is that view (`o.curStrip`, `o.x`, ...). BUGS.md S1-S4, S7 and S8
//! are ported as the code does them; each fix is behind its
//! `g.fixes.salgin_*` flag (docs/salgin/DESIGN.md "Fixes").

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
const fighters = @import("fighters.zig");
const hud = @import("hud.zig");
const scene_unit = @import("scene.zig");
const sound = @import("sound.zig");
const animation = @import("behaviour/animation.zig");
const movement = @import("behaviour/movement.zig");
const render = @import("behaviour/render.zig");
const fight_controls = @import("../core/fight_controls.zig");

const VK_PGUP: u16 = 0x21;
const VK_END: u16 = 0x23;
const VK_HOME: u16 = 0x24;
const VK_LEFT: u16 = 0x25;
const VK_UP: u16 = 0x26;
const VK_RIGHT: u16 = 0x27;
const VK_DOWN: u16 = 0x28;
const VK_INSERT: u16 = 0x2d;

/// The scene's backdrop (the original dereferences it unchecked).
fn bdOf(scene: *Scene) *Backdrop {
    return scene.backdrop orelse @panic("salgin.arena: no backdrop");
}

/// CRT `abs` on an int (`abs(-32768)` stays -32768).
fn absInt(v: i16) i16 {
    return if (v < 0) 0 -% v else v;
}

/// A strip number as a table index (the original indexes unchecked).
fn idx(strip: i16) usize {
    return @as(u16, @bitCast(strip));
}

fn lockSeven(g: *Game) void {
    g.keyRightHeld = 1;
    g.keyLeftHeld = 1;
    g.keyDownHeld = 1;
    g.keyUpHeld = 1;
    g.keyPgUpHeld = 1;
    g.keyHomeHeld = 1;
    g.keyEndHeld = 1;
}

/// The latch stores of an attack or the block: seven of the eight (S4:
/// Insert too, behind its flag).
fn lockMove(g: *Game) void {
    lockSeven(g);
    if (g.fixes.salgin_insert_locked) g.keyInsertHeld = 1;
}

fn lockAll(g: *Game) void {
    lockSeven(g);
    g.keyInsertHeld = 1;
}

fn clearAll(g: *Game) void {
    g.keyRightHeld = 0;
    g.keyLeftHeld = 0;
    g.keyUpHeld = 0;
    g.keyDownHeld = 0;
    g.keyPgUpHeld = 0;
    g.keyHomeHeld = 0;
    g.keyEndHeld = 0;
    g.keyInsertHeld = 0;
}

/// A move key's start: strip, frame 0, framesLeft from the player's table,
/// frameCount 0, drawn.
fn startMove(g: *Game, bd: *Backdrop, strip: i16) void {
    const f = g.fighter.?;
    f.curStrip = strip;
    f.curFrame = 0;
    f.anim.framesLeft = g.fighterStripFrames[idx(strip)];
    f.fighter.frameCount = 0;
    render.draw(g, f, bd);
}

fn inRange(g: *Game) bool {
    return absInt(0 -% (g.opponent.?.x -% g.fighter.?.x)) < 0x79;
}

/// A blow in range: the opponent's health (not for the sweep) and energy
/// drop by `g_fighterDamage[fighter strip]`, a tile per 7 points, the
/// opponent stops walking; then its reaction (strips 4..`react_max`), or,
/// any other strip, a trade (`Fighter.health` by `g_opponentDamage`; S8).
fn landHit(g: *Game, bd: *Backdrop, lowers_health: bool, react_max: u16) void {
    const f = g.fighter.?;
    const o = g.opponent.?;
    const bar = &g.energyBar.?.energyBar;
    const dmg = g.fighterDamage[idx(f.curStrip)];
    if (lowers_health) o.opponent.health -%= dmg;
    bar.opponentEnergy -%= dmg;
    if (6 < g.opponentMarkLevel -% bar.opponentEnergy) {
        hud.addMark(g, 0, bd);
        g.opponentMarkLevel -%= 7;
    }
    movement.stopMoving(g, o, bd);
    const os: u16 = @bitCast(o.curStrip);
    if (os < 4 or os > react_max) {
        f.fighter.health -%= g.opponentDamage[os];
    } else {
        g.reactionRow = o.curStrip -% 4;
        g.reactionCol = f.curStrip;
        const row = idx(g.reactionRow *% 4 +% g.reactionCol);
        const weak = if (g.fixes.salgin_weak_reaction_by_energy) bar.opponentEnergy < 6 else o.opponent.health < 6;
        o.curStrip = g.reactionStrips[row][@intFromBool(weak)];
        o.curFrame = 0;
        o.anim.framesLeft = g.opponentStripFrames[idx(o.curStrip)];
        o.opponent.frameCount = 0;
        o.opponent.hitLock = 1;
    }
}

/// Round over by a player win: the end strip (10) plays, its wave.
fn playerWins(g: *Game, bd: *Backdrop) void {
    const f = g.fighter.?;
    hud.addMark(g, 0, bd);
    f.curStrip = 10;
    f.curFrame = 0;
    animation.play(g, f, bd);
    f.anim.framesLeft = g.fighterStripFrames[idx(f.curStrip)];
    g.roundOver = 1;
    fighters.playBoos(g);
}

/// Round over by an opponent win (mane.WAV notifies the window at its end).
fn opponentWins(g: *Game, bd: *Backdrop) void {
    const o = g.opponent.?;
    hud.addMark(g, 1, bd);
    o.curStrip = 10;
    o.curFrame = 0;
    animation.play(g, o, bd);
    o.anim.framesLeft = g.opponentStripFrames[idx(o.curStrip)];
    g.roundOver = 1;
    fighters.playMane(g, g.mainWindow);
}

/// The player's energy drops by `g_fighterDamage[opponent strip]` (S1: the
/// opponent's own table behind its flag), a tile per 7 points.
fn playerHurt(g: *Game, bd: *Backdrop) void {
    const o = g.opponent.?;
    const bar = &g.energyBar.?.energyBar;
    const table = if (g.fixes.salgin_opponent_damage_table) &g.opponentDamage else &g.fighterDamage;
    bar.playerEnergy -%= table[idx(o.curStrip)];
    if (6 < g.playerMarkLevel -% bar.playerEnergy) {
        hud.addMark(g, 1, bd);
        g.playerMarkLevel -%= 7;
    }
}

/// WM_KEYDOWN's per-key work (the round is not over); returns handled.
fn keyDown(g: *Game, scene: *Scene, key: u16) i16 {
    const bd = bdOf(scene);
    const f = g.fighter.?;
    const o = g.opponent.?;
    switch (key) {
        VK_PGUP => if (g.keyPgUpHeld == 0) {
            g.keyPgUpHeld = 1;
            startMove(g, bd, 0);
            lockMove(g);
            if (inRange(g)) {
                fighters.playPunchPain2(g);
                landHit(g, bd, true, 6);
            }
        },
        VK_END => if (g.keyEndHeld == 0) {
            g.keyEndHeld = 1;
            startMove(g, bd, 7);
            lockMove(g);
        },
        VK_HOME => if (g.keyHomeHeld == 0) {
            g.keyHomeHeld = 1;
            startMove(g, bd, 3);
            lockMove(g);
            if (inRange(g)) {
                fighters.playKickPain2(g);
                landHit(g, bd, true, 6);
            }
        },
        VK_LEFT => if (g.keyLeftHeld == 0) {
            g.keyLeftHeld = 1;
            g.keyLeftUp = 0;
            f.mover.direction = 1;
            f.curStrip = 4;
            f.curFrame = 0;
            f.anim.framesLeft = g.fighterStripFrames[4];
            f.mover.moving = 1;
            render.draw(g, f, bd);
            // The opponent walks to meet it when more than 80 px away.
            if (f.x < o.x and 0x50 < absInt(0 -% (o.x -% f.x))) {
                if (!movement.isMoving(g, o)) o.mover.moving = 1;
                o.mover.direction = 1;
                o.curStrip = 4;
                o.curFrame = 0;
            }
            fighters.walk(g, f, bd);
        },
        VK_UP => if (g.keyUpHeld == 0) {
            g.keyUpHeld = 1;
            startMove(g, bd, 1);
            lockMove(g);
            if (inRange(g)) {
                fighters.playKickPain2(g);
                landHit(g, bd, true, 6);
            }
        },
        VK_RIGHT => if (g.keyRightHeld == 0) {
            g.keyRightHeld = 1;
            f.mover.direction = 2;
            f.curStrip = 4;
            f.curFrame = 0;
            f.anim.framesLeft = g.fighterStripFrames[4];
            render.draw(g, f, bd);
            if (!movement.isMoving(g, f)) f.mover.moving = 1;
            fighters.walk(g, f, bd);
        },
        VK_DOWN => if (g.keyDownHeld == 0) {
            g.keyDownHeld = 1;
            startMove(g, bd, 2);
            lockMove(g);
            if (inRange(g)) {
                fighters.playPunch2(g);
                landHit(g, bd, false, 7);
            }
        },
        VK_INSERT => if (g.keyInsertHeld == 0) {
            fighters.playKickPain2(g);
            g.keyInsertHeld = 1;
            startMove(g, bd, 5);
            lockSeven(g);
        },
        else => return 0,
    }
    return 1;
}

/// WM_KEYUP of Left / Right: the latch off, the walk stops, the fighter
/// ticks and is drawn, then the guard strip (6). S3: with the flag only a
/// walk (strip 4) is cut.
fn keyUpWalk(g: *Game, bd: *Backdrop, key: u16) void {
    const f = g.fighter.?;
    if (g.fixes.salgin_keyup_stops_walk_only and f.curStrip != 4) return;
    if (key == VK_LEFT) {
        g.keyLeftHeld = 0;
        g.keyLeftUp = 1;
    } else {
        g.keyRightHeld = 0;
    }
    if (movement.isMoving(g, f)) movement.stopMoving(g, f, bd);
    animation.tick(g, f, bd);
    render.draw(g, f, bd);
    f.curStrip = 6;
    f.curFrame = 0;
    f.anim.framesLeft = g.fighterStripFrames[6];
}

/// The beat's attack branch: the opponent stops, picks its attack and the
/// wave, the player's energy drops, and a player in strip 4..7 reacts (S2,
/// S8).
fn counterAttack(g: *Game, bd: *Backdrop) void {
    const f = g.fighter.?;
    const o = g.opponent.?;
    const bar = &g.energyBar.?.energyBar;
    movement.stopMoving(g, o, bd);
    fighters.chooseAttack(g, o, f.curStrip);
    fighters.playCounterWave(g, o.curStrip);
    if (movement.isMoving(g, f)) movement.stopMoving(g, f, bd);
    const fs: u16 = @bitCast(f.curStrip);
    if (fs < 4 or fs > 7) {
        playerHurt(g, bd);
    } else {
        g.reactionRow = f.curStrip -% 4;
        g.reactionCol = o.curStrip;
        const row = idx(g.reactionRow *% 4 +% g.reactionCol);
        const weak = if (g.fixes.salgin_weak_reaction_by_energy) bar.playerEnergy < 10 else f.fighter.health < 10;
        f.curStrip = g.reactionStrips[row][@intFromBool(weak)];
        lockAll(g);
        f.fighter.hitLock = 1;
        f.curFrame = 0;
        f.anim.framesLeft = g.opponentStripFrames[idx(f.curStrip)];
        f.fighter.frameCount = 0;
        // S2: a block that holds (the reaction is the block pose) takes nothing.
        if (!(g.fixes.salgin_block_holds and f.curStrip == 7)) playerHurt(g, bd);
    }
}

/// The opponent's animation step of the beat (gap <= 100, not walking, not
/// idle): the frame count, the jump back after the move, the latches, its tick.
fn opponentStep(g: *Game, bd: *Backdrop) void {
    const f = g.fighter.?;
    const o = g.opponent.?;
    const bar = &g.energyBar.?.energyBar;
    if (animation.isRunning(g, o) and o.opponent.hitLock == 0) {
        o.opponent.frameCount +%= 1;
        if (o.anim.framesLeft == o.opponent.frameCount) {
            if (o.nextX +% 100 < 500) {
                o.nextX +%= 100;
            } else {
                o.nextX = 500;
            }
            o.mover.targetX = o.nextX;
            o.x = o.mover.targetX;
            o.curStrip = 6;
            o.curFrame = 0;
            if (0 < bar.opponentEnergy and 0 < bar.playerEnergy) clearAll(g);
        }
        animation.tick(g, o, bd);
        f.fighter.hitLock = 0;
    }
}

/// SceneVtbl slot 00 handleMessage (salgin_scene_handle_message): non-zero = handled.
/// The Corrigida's fight keys and controls screen go first
/// (`core/fight_controls.zig`): the keys are translated, and while the
/// screen and then the PORRADA intro are up the input and the timers are
/// kept from the fight and the rest runs without the clock block and the
/// beat. When the intro ends the clock stamps move on by the time since
/// WM_CREATE and that message runs with the clock block and the beat, as
/// the original's first message after WM_CREATE does.
pub fn handleMessage(g: *Game, scene: *Scene, m: Msg) i16 {
    switch (fight_controls.gate(&g.controls, g.fixes, m, g.plat.ticks())) {
        .swallow => return 1,
        .dismissed => {
            hud.hideControls(g, scene);
            return 1;
        },
        .started => |ms| {
            g.lastPumpTick +%= @bitCast(ms);
            g.lastClockTick +%= @bitCast(ms);
            _ = run(g, scene, .{ .id = 0 }, false);
            return handleMessage(g, scene, m);
        },
        .pass => |p| return run(g, scene, p.m, p.frozen),
    }
}

// @orig 1068:0d73 salgin_scene_handle_message
fn run(g: *Game, scene: *Scene, m: Msg, frozen: bool) i16 {
    const bar = &g.energyBar.?.energyBar;
    var beat = false;
    var handled: i16 = 1;
    const now = g.plat.ticks();

    // PART 1, before the switch: the clock and the pump, or the end animation.
    // (Not while the controls screen is up: the round has not started.)
    if (frozen) {} else if (g.roundOver == 0) {
        if (scene.clock < 1) {
            // The clock ended: the lower energy loses (a tie is a player win).
            if (bar.playerEnergy < bar.opponentEnergy) {
                opponentWins(g, bdOf(scene));
            } else {
                playerWins(g, bdOf(scene));
            }
            g.setSystemTimer(0x14, 100);
        } else {
            beat = @as(i32, @bitCast(now -% g.lastPumpTick)) > 199;
            if (beat) {
                g.lastPumpTick = now;
                sound.pump(g);
            }
            if (@as(i32, @bitCast(now -% g.lastClockTick)) > 1000) {
                g.lastClockTick = now;
                scene.clock -%= 1;
                hud.drawClock(g, scene);
                hud.blitClock(g, scene);
            }
        }
    } else if (@as(i32, @bitCast(now -% g.lastAnimTick)) > 100) {
        g.lastAnimTick = now;
        const bd = bdOf(scene);
        if (bar.playerEnergy < bar.opponentEnergy) {
            animation.tick(g, g.opponent.?, bd);
        } else {
            animation.tick(g, g.fighter.?, bd);
            g.endReady = 1;
        }
        hud.redrawArena(g, scene);
        const ticks = g.endTicks;
        g.endTicks +%= 1;
        if (ticks < 0x1e) {
            // The first 30 end ticks swallow the timer and the keys.
            if (m.id == msg.wm.systimer or m.id == msg.wm.keydown or m.id == msg.wm.keyup) return 1;
        } else if (g.endReady != 0 and g.resultSent == 0) {
            _ = g.post(.{ .id = msg.wm.destroy });
        }
    }

    // PART 2: the switch on the message.
    switch (m.id) {
        msg.wm.keydown => {
            if (g.roundOver != 0) return 1;
            handled = keyDown(g, scene, m.wparam);
        },
        msg.wm.keyup => {
            if (g.roundOver != 0) return 1;
            handled = 1;
            switch (m.wparam) {
                VK_LEFT, VK_RIGHT => keyUpWalk(g, bdOf(scene), m.wparam),
                VK_PGUP, VK_END, VK_HOME, VK_UP, VK_DOWN, VK_INSERT => {},
                else => handled = 0,
            }
            hud.redrawArena(g, scene);
        },
        msg.wm.destroy => {
            if (g.resultSent == 0) {
                g.resultSent = 1;
                sound.stopAll(g);
                sound.freeAll(g);
                sound.mixClose(g);
                _ = g.plat.mciString("close musica");
                var lost = bar.playerEnergy < bar.opponentEnergy;
                // S7: closing before the round is over loses.
                if (g.fixes.salgin_close_mid_fight_loses and g.roundOver == 0) lost = true;
                const score: i16 = if (lost) -1000 else bar.playerEnergy *% 100;
                _ = g.plat.postTo(g.noiteWnd, .{
                    .id = msg.noite.minigame_result,
                    .wparam = @intFromBool(!lost),
                    .lparam = score,
                });
            }
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
        },
        // Swallowed (0x203 and 0x206 are not).
        msg.wm.systimer,
        msg.wm.mousemove,
        msg.wm.lbuttondown,
        msg.wm.lbuttonup,
        msg.wm.rbuttondown,
        msg.wm.rbuttonup,
        => handled = 1,
        // The music loops.
        msg.wm.mm_mcinotify => {
            if (m.wparam == 1) _ = g.plat.mciString("play musica from 0 notify");
            handled = 1;
        },
        // mane.WAV ended: the loss closes here.
        msg.wm.mm_wom_done => {
            _ = g.post(.{ .id = msg.wm.destroy });
            g.endReady = 1;
        },
        // game_init's: the clock starts from now.
        msg.noite.scene_started => {
            g.lastClockTick = g.plat.ticks();
            hud.drawClock(g, scene);
            hud.blitClock(g, scene);
            handled = 1;
        },
        else => handled = 0,
    }

    // PART 3: the beat (never while frozen: `beat` is false).
    if (!beat) return handled;
    const bd = bdOf(scene);
    const f = g.fighter.?;
    const o = g.opponent.?;
    if (bar.opponentEnergy < 1 or bar.playerEnergy < 1) {
        lockAll(g);
        if (g.roundOver == 0) {
            if (bar.opponentEnergy < 1) playerWins(g, bd) else opponentWins(g, bd);
            g.setSystemTimer(0x14, 100);
            return handled;
        }
    }
    if (animation.isRunning(g, f) and f.fighter.hitLock == 0) {
        f.fighter.frameCount +%= 1;
        if (f.anim.framesLeft == f.fighter.frameCount) {
            f.curStrip = 6;
            f.curFrame = 0;
            if (0 < bar.opponentEnergy or 0 < bar.playerEnergy) clearAll(g);
        }
        animation.tick(g, f, bd);
        o.opponent.hitLock = 0;
    }
    if (absInt(0 -% (o.x -% f.x)) < 0x65) {
        if (!movement.isMoving(g, o) and animation.isRunning(g, o) and o.curStrip != 6) {
            opponentStep(g, bd);
        } else {
            counterAttack(g, bd);
        }
    } else {
        if (!movement.isMoving(g, o)) {
            o.mover.direction = 1;
            o.curStrip = 4;
            o.curFrame = 0;
            o.mover.moving = 1;
        }
        fighters.walk(g, o, bd);
    }
    hud.redrawArena(g, scene);
    return handled;
}

/// SceneVtbl slot 05 createScreen (salgin_scene_create_screen).
// @orig 1088:5794 salgin_scene_create_screen
pub fn createScreen(g: *Game, scene: *Scene) ?*Backdrop {
    _ = scene;
    const bd = g.local().create(Backdrop) catch return null;
    bd.* = .{};
    return backdrop.ctor(g, bd, "fundluta.bmp", 0, 0, 0x280, 0x1e0);
}

/// SceneVtbl slot 07 create (salgin_scene_create; hwnd dropped).
// @orig 1068:29e2 salgin_scene_create
pub fn create(g: *Game, scene: *Scene) ?*Scene {
    _ = scene_unit.create(g, scene);
    _ = g.plat.mciString("open porrada.mid type sequencer alias musica");
    _ = g.plat.mciString("play musica notify");
    _ = sound.mixInit(g);
    g.punch2Wave = sound.open(g, "soco2.wav");
    g.punchWave = sound.open(g, "soco.wav");
    g.pain4Wave = sound.open(g, "dor4.wav");
    g.pain2Wave = sound.open(g, "dor2.wav");
    g.kickWave = sound.open(g, "chute3.wav");
    g.boosWave = sound.open(g, "vaias.wav");
    g.maneWave = sound.open(g, "mane.WAV");
    return scene;
}
