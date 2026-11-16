//! Port unit `arena` (module) of SALGIN.EXE. SalginScene: its handler (the GetTickCount beat, clock and end ticks; the keys and latches; the fighter's blows, the opponent's approach and attack, the KO and the clock end, WM_DESTROY and 0x40a), create (MCI, WaveMix, the waves), createScreen.
//!
//! The handler sees every message first (non-zero = handled). hwnd/hdc
//! parameters are dropped (the DC is the platform screen), so the stale
//! `ReleaseDC(clockDc)` of the Left/Right key-up has no counterpart. The
//! original reads the two fighters through their virtual base; the flattened
//! `Object` is that view (`o.curStrip`, `o.x`, ...). BUGS.md S1-S4, S7 and S8
//! are ported as the code does them; each fix is behind its
//! `g.fixes.salgin_*` flag (docs/salgin/DESIGN.md "Fixes").
//!
//! The Corrigida's fair fight (`fight_fair`, `core/fight_fair.zig`, not in
//! the original) takes the opponent's part of the beat (`fairBeat`) and
//! the blows' hit (`fairLandHit`), after the handler.

const std = @import("std");
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
const fight_fair = @import("../core/fight_fair.zig");
const fight_easy = @import("../core/fight_easy.zig");
const fight_bot = @import("../core/fight_bot.zig");
const fight_mk3 = @import("../core/fight_mk3/glue.zig");

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
    var dmg = table[idx(o.curStrip)];
    if (easyOn(g)) dmg = fight_easy.scaleDamage(easy_style, dmg);
    bar.playerEnergy -%= dmg;
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
            strikeKey(g, bd, .punch);
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
            strikeKey(g, bd, .kick);
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
            // The opponent walks to meet it when more than 80 px away (not
            // in the fair fight: its AI walks it).
            if (!g.fixes.fight_fair and f.x < o.x and 0x50 < absInt(0 -% (o.x -% f.x))) {
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
            strikeKey(g, bd, .kick);
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
            strikeKey(g, bd, .sweep);
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
    const handled = handleOne(g, scene, m);
    // The test tool's player bot sends its keys after the timer's own turn.
    botTick(g, scene, m);
    return handled;
}

fn handleOne(g: *Game, scene: *Scene, m: Msg) i16 {
    if (fight_fair.isToggle(g.fixes, m)) {
        // The MK3 fight's F9 draws the boxes (no fair-fight overlay).
        if (g.mk3 != null) g.fair.overlay = !g.fair.overlay else toggleOverlay(g, scene);
        return 1;
    }
    // The MK3 fight takes the raw keys (A S D F, Space, the arrows).
    var fixes = g.fixes;
    if (g.mk3 != null) fixes.fight_keys_asdf = false;
    switch (fight_controls.gate(&g.controls, fixes, m, g.plat.ticks())) {
        .swallow => return 1,
        .dismissed => {
            hud.hideControls(g, scene);
            return 1;
        },
        .started => |ms| {
            g.lastPumpTick +%= @bitCast(ms);
            g.lastClockTick +%= @bitCast(ms);
            _ = run(g, scene, .{ .id = 0 }, false);
            return handleOne(g, scene, m);
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
            if (g.mk3) |mk| {
                mk.key(m.wparam, true);
                handled = 1;
            } else handled = keyDown(g, scene, m.wparam);
        },
        msg.wm.keyup => {
            if (g.roundOver != 0) return 1;
            if (g.mk3) |mk| {
                mk.key(m.wparam, false);
                return 1;
            }
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

    // The MK3 fight has no beat: its own clock runs the round.
    if (g.mk3) |mk| {
        if (!frozen) mk3Update(g, scene, mk);
        return handled;
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
    if (g.fixes.fight_fair) {
        fairBeat(g, scene, bd);
    } else if (absInt(0 -% (o.x -% f.x)) < 0x65) {
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
    if (g.fair.overlay) showOverlay(g, scene);
    return handled;
}

// ---- the MK3 fight (Corrigida, `fight_mk3`; core/fight_mk3/) ----------------

/// Runs the match up to now on every message (the 50-ms timer at the
/// least; the picture advances it too, at the display rate): its sounds,
/// the energies the clock's tie-break and the score read, the KO.
fn mk3Update(g: *Game, scene: *Scene, mk: *fight_mk3.Match) void {
    const now = g.plat.ticks();
    if (!mk.started) mk.begin(now);
    mk.advance(now);
    const bar = &g.energyBar.?.energyBar;
    const bd = bdOf(scene);
    var evs: [16]@TypeOf(mk.sim.events[0]) = undefined;
    const n = mk.sim.takeEvents(&evs);
    // The Original's pairs: a blow and a pain wave (the player's pain is
    // `dor4`, the opponent's `dor2`), the sweep's `soco2`.
    for (evs[0..n]) |ev| switch (ev.kind) {
        .hit_light => if (ev.who == 1) fighters.playPunchPain2(g) else fighters.playPunchPain4(g),
        .hit_heavy => if (ev.who == 1) fighters.playKickPain2(g) else fighters.playKickPain4(g),
        .block => _ = sound.play(g, 0, g.punchWave),
        .knockdown, .ko => fighters.playPunch2(g),
        else => {},
    };
    if (g.roundOver == 0) {
        bar.playerEnergy = fight_mk3.energyOf(mk.sim.f[0].health);
        bar.opponentEnergy = fight_mk3.energyOf(mk.sim.f[1].health);
        // A KO: the fall plays, then the old end of the round.
        if (mk.sim.over and mk.sim.since_over >= 40) {
            if (mk.sim.ko_winner == 0) playerWins(g, bd) else opponentWins(g, bd);
            g.setSystemTimer(0x14, 100);
        }
    } else if (!mk.sim.over) {
        // The clock ended it (PART 1): the better energy wins.
        mk.sim.finishOnTime(if (bar.playerEnergy < bar.opponentEnergy) 1 else 0);
    }
    if (g.roundOver != 0 and fight_bot.config != null and !g.bot.ended) {
        g.bot.ended = true;
        var landed: u32 = 0;
        var taken: u32 = 0;
        for (mk.sim.landed[0]) |v| landed += v;
        for (mk.sim.landed[1]) |v| taken += v;
        std.debug.print("[{d}] fightbot: end profile={t} seed={d} clock={d} fighter={d} opponent={d} landed={d} taken={d}\n", .{
            now, fight_bot.config.?.profile, fight_bot.config.?.seed, scene.clock, bar.playerEnergy, bar.opponentEnergy, landed, taken,
        });
        std.debug.print("[{d}] mk3: landed by move (lp hp lk hk roundhouse c_lp uppercut c_lk sweep j_lp j_hp j_lk j_hk throw) player={any} cpu={any} blocked player={any} cpu={any}\n", .{ now, mk.sim.landed[0], mk.sim.landed[1], mk.sim.blocked[0], mk.sim.blocked[1] });
    }
}

// ---- the fair fight (Corrigida, `fight_fair`; core/fight_fair.zig) ----------

const tuning = &fight_fair.salgin;
const easy_style = &fight_easy.salgin;

/// The easy opponent (`fight_easy_ai`, `core/fight_easy.zig`) is on.
fn easyOn(g: *Game) bool {
    return g.fixes.fight_fair and g.fixes.fight_easy_ai;
}

fn gapOf(g: *Game) i16 {
    return absInt(0 -% (g.opponent.?.x -% g.fighter.?.x));
}

const Blow = enum { punch, kick, sweep };

/// A blow's key: the fair fight's hit, or the Original's when in range
/// (its waves, then `landHit`: the sweep lowers no health and makes an
/// opponent in strips 4-7 react, the others 4-6).
fn strikeKey(g: *Game, bd: *Backdrop, b: Blow) void {
    if (g.fixes.fight_fair) {
        if (gapOf(g) <= tuning.fighter_reach) fairLandHit(g, bd, b);
    } else if (inRange(g)) {
        playBlowWaves(g, b);
        if (b == .sweep) landHit(g, bd, false, 7) else landHit(g, bd, true, 6);
    }
}

fn playBlowWaves(g: *Game, b: Blow) void {
    switch (b) {
        .punch => fighters.playPunchPain2(g),
        .kick => fighters.playKickPain2(g),
        .sweep => fighters.playPunch2(g),
    }
}

fn checkOpponentMark(g: *Game, bd: *Backdrop) void {
    const bar = &g.energyBar.?.energyBar;
    if (6 < g.opponentMarkLevel -% bar.opponentEnergy) {
        hud.addMark(g, 0, bd);
        g.opponentMarkLevel -%= 7;
    }
}

/// The fair fight's blow in range: a reeling opponent cannot be hit (the
/// blow whiffs); otherwise the Original's waves, the doubled
/// damage, no trade, and the opponent reacts by the table (as a walking
/// one: the reel, the fall when weak) whatever it was doing, which cuts a
/// wind-up short.
fn fairLandHit(g: *Game, bd: *Backdrop, b: Blow) void {
    const f = g.fighter.?;
    const o = g.opponent.?;
    const bar = &g.energyBar.?.energyBar;
    const ai = &g.fair;
    if (ai.phase == .reel) return;
    if (easyOn(g) and ai.phase == .guard and b != .sweep) {
        // The guard holds the punch and the kicks: nothing lands (the sweep
        // goes under it). Sometimes it counters at once.
        _ = sound.play(g, 0, g.punchWave);
        ai.guards +%= 1;
        if (fight_easy.counters(easy_style, &g.rand)) {
            ai.counter = true;
            ai.left = 1;
        }
        return;
    }
    playBlowWaves(g, b);
    var dmg = tuning.fighter_damage[idx(f.curStrip) & 3];
    if (easyOn(g)) dmg = fight_easy.scaleFighterDamage(easy_style, dmg);
    if (b != .sweep) o.opponent.health -%= dmg;
    bar.opponentEnergy -%= dmg;
    checkOpponentMark(g, bd);
    if (easyOn(g) and bar.opponentEnergy >= 6 and fight_easy.shrugsOff(easy_style, switch (ai.phase) {
        .windup, .strike, .guard => true,
        else => false,
    }, &g.rand)) {
        // It takes the hit without reeling and goes on with what it was doing.
        ai.shrugs +%= 1;
        return;
    }
    movement.stopMoving(g, o, bd);
    if (ai.phase == .windup) ai.interrupts +%= 1;
    // The row of an opponent walking (strip 4) for this blow.
    const weak = if (g.fixes.salgin_weak_reaction_by_energy) bar.opponentEnergy < 6 else o.opponent.health < 6;
    var r = g.reactionStrips[idx(f.curStrip) & 3][@intFromBool(weak)];
    if (r == 7) r = 9;
    o.curStrip = r;
    o.curFrame = 0;
    o.anim.framesLeft = g.opponentStripFrames[idx(r)];
    o.opponent.frameCount = 0;
    ai.phase = .reel;
}

/// The opponent stands in `strip` (4, its stance), frame 0.
fn oppPose(g: *Game, strip: i16) void {
    const o = g.opponent.?;
    o.curStrip = strip;
    o.curFrame = 0;
    o.anim.framesLeft = g.opponentStripFrames[idx(strip)];
    o.opponent.frameCount = 0;
}

/// The jump back (as the Original's after a move: +100, x at most 500),
/// then the pause.
fn fairRetreat(g: *Game) void {
    const o = g.opponent.?;
    const bar = &g.energyBar.?.energyBar;
    o.nextX = @min(o.nextX +% tuning.retreat_px, 500);
    o.mover.targetX = o.nextX;
    o.x = o.mover.targetX;
    oppPose(g, 6);
    // As the Original's end of a move: the latches clear.
    if (0 < bar.opponentEnergy and 0 < bar.playerEnergy) clearAll(g);
    g.fair.phase = .pause;
    g.fair.left = fight_fair.pauseBeats(tuning, g.rand.rand());
    if (easyOn(g) and g.fair.mercy) g.fair.left += easy_style.mercy_beats;
    g.fair.mercy = false;
}

/// The attack's own wave (no pain): the tell's sound.
fn cueWave(g: *Game, attack: i16) void {
    _ = sound.play(g, 0, switch (attack) {
        0 => g.punchWave,
        2 => g.punch2Wave,
        else => g.kickWave,
    });
}

/// The wind-up (the attack chosen now, frame 0 shown and its wave played).
/// A counter's is `counter_windup_beats` long.
fn fairWindup(g: *Game, scene: *Scene, bd: *Backdrop) void {
    const f = g.fighter.?;
    const o = g.opponent.?;
    const ai = &g.fair;
    movement.stopMoving(g, o, bd);
    fighters.chooseAttack(g, o, f.curStrip);
    o.curFrame = 0;
    ai.attack = o.curStrip;
    ai.phase = .windup;
    ai.left = if (!easyOn(g)) fight_fair.windupBeats(tuning, scene.clock) else if (ai.countering) easy_style.counter_windup_beats else fight_easy.windupBeats(easy_style, &g.rand);
    ai.countering = false;
    ai.windups +%= 1;
    cueWave(g, ai.attack);
}

/// It comes in, stands `feint_beats` beats in its guard and backs off.
fn fairFeint(g: *Game, bd: *Backdrop) void {
    const o = g.opponent.?;
    const ai = &g.fair;
    movement.stopMoving(g, o, bd);
    oppPose(g, 6);
    ai.phase = .feint;
    ai.left = tuning.feint_beats;
}

/// In range: a feint, or the wind-up. The easy opponent rolls on its table.
fn fairArrive(g: *Game, scene: *Scene, bd: *Backdrop, punish: bool) void {
    const o = g.opponent.?;
    if (easyOn(g)) {
        easyDecide(g, scene, bd, punish);
        return;
    }
    if (!punish and fight_fair.isFeint(tuning, g.rand.rand())) {
        fairFeint(g, bd);
        return;
    }
    movement.stopMoving(g, o, bd);
    fairWindup(g, scene, bd);
}

/// The easy opponent is free (arrived, or a pause, a wait or a guard is
/// over): it rolls on its personality table (`fight_easy.zig`). `punish`:
/// the fighter whiffed a blow it can see.
fn easyDecide(g: *Game, scene: *Scene, bd: *Backdrop, punish: bool) void {
    const f = g.fighter.?;
    const o = g.opponent.?;
    const bar = &g.energyBar.?.energyBar;
    const ai = &g.fair;
    const gap = gapOf(g);
    if (gap > tuning.approach_stop and !punish) {
        // Not in reach: it walks in (the approach has its own dithering).
        ai.phase = .approach;
        ai.left = fight_fair.edgeBeats(tuning, g.rand.rand());
        return;
    }
    const fs: u16 = @bitCast(f.curStrip);
    const ctx: fight_easy.Context = .{
        .zone = .reach,
        .fighter_busy = fs < 4,
        .fighter_energy = bar.playerEnergy,
        .opponent_energy = bar.opponentEnergy,
    };
    const c: fight_easy.Choice = if (punish) .attack else fight_easy.choose(easy_style, ctx, &g.rand);
    ai.choices[@backingInt(c)] +%= 1;
    switch (c) {
        .advance => {
            ai.phase = .approach;
            ai.left = 0;
        },
        .wait => {
            movement.stopMoving(g, o, bd);
            oppPose(g, 6);
            ai.phase = .wait;
            ai.left = fight_easy.waitBeats(easy_style, &g.rand);
        },
        .guard => {
            movement.stopMoving(g, o, bd);
            oppPose(g, 7);
            ai.phase = .guard;
            ai.left = fight_easy.guardBeats(easy_style, &g.rand);
        },
        .retreat => hopBack(g, easy_style.retreat_px),
        .attack => fairWindup(g, scene, bd),
        .feint => fairFeint(g, bd),
    }
}

/// A hop back of `px` (x at most 500), then a pause.
fn hopBack(g: *Game, px: i16) void {
    const o = g.opponent.?;
    const bar = &g.energyBar.?.energyBar;
    o.nextX = @min(o.nextX +% px, 500);
    o.mover.targetX = o.nextX;
    o.x = o.mover.targetX;
    oppPose(g, 6);
    if (0 < bar.opponentEnergy and 0 < bar.playerEnergy) clearAll(g);
    g.fair.phase = .pause;
    g.fair.left = fight_fair.pauseBeats(tuning, g.rand.rand());
}

/// The fighter has just started a blow (its first frame went by on this
/// beat): a whiff the opponent can see.
fn whiffed(g: *Game) bool {
    const f = g.fighter.?;
    const fs: u16 = @bitCast(f.curStrip);
    return tuning.whiff_punish and fs < 4 and f.fighter.frameCount == 1 and gapOf(g) <= tuning.approach_stop + 32;
}

/// Walks in; one step out of reach (the edge) it stands `Ai.left` beats,
/// or steps in at once on a whiff; in range, the wind-up (or a feint).
fn fairApproach(g: *Game, scene: *Scene, bd: *Backdrop, punish: bool) void {
    const o = g.opponent.?;
    const ai = &g.fair;
    ai.phase = .approach;
    const gap = gapOf(g);
    if (gap > tuning.approach_stop) {
        if (gap <= tuning.approach_stop + 32 and !punish and ai.left > 0) {
            // The edge: it stands.
            ai.left -= 1;
            if (movement.isMoving(g, o)) movement.stopMoving(g, o, bd);
            return;
        }
        if (easyOn(g) and !punish) {
            // Dithering on the way in; at the edge, now and then a blow from
            // too far (it whiffs unless the fighter walks in).
            if (gap <= tuning.approach_stop + 32) {
                if (fight_easy.whiffs(easy_style, &g.rand)) {
                    ai.choices[@backingInt(fight_easy.Choice.attack)] +%= 1;
                    ai.whiffs +%= 1;
                    fairWindup(g, scene, bd);
                    return;
                }
            } else {
                const h = fight_easy.hesitation(easy_style, &g.rand);
                if (h > 0) {
                    movement.stopMoving(g, o, bd);
                    oppPose(g, 6);
                    ai.phase = .wait;
                    ai.left = h;
                    return;
                }
            }
        }
        if (!movement.isMoving(g, o)) {
            o.mover.direction = 1;
            o.curStrip = 4;
            o.curFrame = 0;
            o.mover.moving = 1;
        }
        fighters.walk(g, o, bd);
    }
    if (gapOf(g) <= tuning.approach_stop) fairArrive(g, scene, bd, punish);
}

/// The strike: the outcome by the gap and the fighter's pose now.
fn fairStrike(g: *Game, bd: *Backdrop) void {
    const f = g.fighter.?;
    const o = g.opponent.?;
    const bar = &g.energyBar.?.energyBar;
    const ai = &g.fair;
    const out = fight_fair.strikeOutcome(tuning, ai.attack, f.curStrip, gapOf(g));
    ai.last = out;
    ai.outcomes[@backingInt(out)] +%= 1;
    switch (out) {
        .hit => {
            ai.mercy = true;
            fighters.playCounterWave(g, ai.attack);
            if (movement.isMoving(g, f)) movement.stopMoving(g, f, bd);
            const fs: u16 = @bitCast(f.curStrip);
            const target: i16 = if (fs >= 4 and fs <= 7) f.curStrip else 6;
            const weak = if (g.fixes.salgin_weak_reaction_by_energy) bar.playerEnergy < 10 else f.fighter.health < 10;
            var r = g.reactionStrips[idx((target -% 4) *% 4 +% ai.attack)][@intFromBool(weak)];
            if (r == 7) r = 9;
            f.curStrip = r;
            lockAll(g);
            f.fighter.hitLock = 1;
            f.curFrame = 0;
            // The opponent's frame table, as the Original's reaction.
            f.anim.framesLeft = g.opponentStripFrames[idx(r)];
            f.fighter.frameCount = 0;
            playerHurt(g, bd);
        },
        .blocked => {
            _ = sound.play(g, 0, g.punchWave);
            if (tuning.block_chip != 0) {
                bar.playerEnergy -%= tuning.block_chip;
                if (6 < g.playerMarkLevel -% bar.playerEnergy) {
                    hud.addMark(g, 1, bd);
                    g.playerMarkLevel -%= 7;
                }
            }
        },
        else => {},
    }
    animation.tick(g, o, bd);
    o.opponent.frameCount = 1;
    ai.phase = .strike;
    if (o.anim.framesLeft <= 1) {
        ai.phase = .recovery;
        ai.left = tuning.recovery_beats;
    }
}

/// The fighter whiffed a blow the opponent can see (the easy one sees it
/// only sometimes).
fn beatPunish(g: *Game) bool {
    if (!whiffed(g)) return false;
    return !easyOn(g) or fight_easy.punishes(easy_style, &g.rand);
}

/// The fair fight's opponent on a beat (in place of the Original's
/// approach / attack / step).
fn fairBeat(g: *Game, scene: *Scene, bd: *Backdrop) void {
    const f = g.fighter.?;
    const o = g.opponent.?;
    const ai = &g.fair;
    ai.beat +%= 1;
    ai.phase_beats[@backingInt(ai.phase)] +%= 1;
    // The Original's opponent step lets the fighter's reaction run.
    f.fighter.hitLock = 0;
    if (ai.beat == 1 and !g.fixes.fight_controls_screen) {
        ai.phase = .start;
        ai.left = tuning.start_delay_beats;
    }
    if (ai.beat == 1 and g.fixes.fight_controls_screen) ai.left = fight_fair.edgeBeats(tuning, g.rand.rand());
    switch (ai.phase) {
        .start => {
            if (movement.isMoving(g, o)) movement.stopMoving(g, o, bd);
            if (ai.left > 0) ai.left -= 1 else {
                ai.phase = .approach;
                ai.left = fight_fair.edgeBeats(tuning, g.rand.rand());
            }
        },
        .approach => fairApproach(g, scene, bd, beatPunish(g)),
        .windup => {
            if (ai.left > 1) ai.left -= 1 else fairStrike(g, bd);
        },
        .strike => {
            o.opponent.frameCount +%= 1;
            if (o.anim.framesLeft <= o.opponent.frameCount) {
                ai.phase = .recovery;
                ai.left = tuning.recovery_beats;
                if (ai.left == 0) fairRetreat(g);
            } else animation.tick(g, o, bd);
        },
        .recovery, .feint => {
            if (ai.left > 1) ai.left -= 1 else fairRetreat(g);
        },
        .pause => {
            const punish = beatPunish(g);
            if (punish) {
                fairApproach(g, scene, bd, true);
            } else if (ai.left > 1) {
                ai.left -= 1;
            } else if (easyOn(g)) {
                easyDecide(g, scene, bd, false);
            } else {
                ai.phase = .approach;
                ai.left = fight_fair.edgeBeats(tuning, g.rand.rand());
            }
        },
        .wait => {
            if (beatPunish(g)) {
                easyDecide(g, scene, bd, true);
            } else if (ai.left > 1) {
                ai.left -= 1;
            } else easyDecide(g, scene, bd, false);
        },
        .guard => {
            if (ai.left > 1) {
                ai.left -= 1;
            } else if (ai.counter) {
                // It blocked a blow and answers it (slower than a wind-up).
                ai.counter = false;
                ai.countering = true;
                ai.choices[@backingInt(fight_easy.Choice.attack)] +%= 1;
                fairWindup(g, scene, bd);
            } else easyDecide(g, scene, bd, false);
        },
        .reel => {
            o.opponent.frameCount +%= 1;
            if (o.anim.framesLeft <= o.opponent.frameCount) {
                if (easyOn(g)) switch (fight_easy.afterHurt(easy_style, &g.rand)) {
                    .guard => {
                        oppPose(g, 7);
                        ai.phase = .guard;
                        ai.left = fight_easy.guardBeats(easy_style, &g.rand);
                        return;
                    },
                    .back_off => {
                        hopBack(g, easy_style.back_off_px);
                        ai.left += easy_style.mercy_beats;
                        return;
                    },
                    .usual => {},
                };
                if (gapOf(g) <= tuning.approach_stop) {
                    fairRetreat(g);
                } else {
                    oppPose(g, 6);
                    ai.phase = .pause;
                    ai.left = fight_fair.pauseBeats(tuning, g.rand.rand());
                }
            } else animation.tick(g, o, bd);
        },
    }
}

// ---- the test tool's player bot (`--fight-bot`, core/fight_bot.zig) ----------

fn botView(g: *Game, scene: *Scene) fight_bot.View {
    const f = g.fighter.?;
    const o = g.opponent.?;
    const bar = &g.energyBar.?.energyBar;
    return .{
        .t = g.plat.ticks(),
        .screen = g.controls.phase == .screen,
        .intro = g.controls.phase == .intro,
        .over = g.roundOver != 0,
        .gap = gapOf(g),
        .fighter_x = f.x,
        .fighter_strip = f.curStrip,
        .opponent_strip = o.curStrip,
        .opponent_frame = o.curFrame,
        .fighter_energy = bar.playerEnergy,
        .opponent_energy = bar.opponentEnergy,
        .seconds_left = scene.clock,
    };
}

/// On each timer message the bot sends the keys a player would (the 1995
/// codes, through the gate like a keyboard's).
fn botTick(g: *Game, scene: *Scene, m: Msg) void {
    // The MK3 fight's bot is its own (`fight_mk3/bot.zig`).
    if (g.mk3 != null) {
        // Only the controls screen: a key takes it down.
        const c = fight_bot.config orelse return;
        if (m.id == msg.wm.systimer and g.controls.phase == .screen and g.plat.ticks() >= c.after +| 400) {
            _ = handleMessage(g, scene, .{ .id = msg.wm.keydown, .wparam = 0x0d });
        }
        return;
    }
    const cfg = fight_bot.config orelse return;
    if (m.id != msg.wm.systimer or g.energyBar == null or g.fighter == null or g.opponent == null) return;
    if (g.plat.ticks() < cfg.after) return;
    const b = &g.bot;
    if (!b.started) b.start(cfg);
    if (b.ended) return;
    const v = botView(g, scene);
    const out = b.step(v);
    for (out.slice()) |c| {
        if (cfg.log_keys) std.debug.print("[{d}] fightbot-key {d} {s}\n", .{ v.t, c.vk, if (c.down) "down" else "up" });
        const key = if (g.fixes.fight_keys_asdf) fight_controls.untranslate(c.vk) else c.vk;
        _ = handleMessage(g, scene, .{ .id = if (c.down) msg.wm.keydown else msg.wm.keyup, .wparam = key });
    }
    if (v.over) {
        b.ended = true;
        fight_bot.report(b, v, &g.fair);
    }
}

fn fairView(g: *Game, scene: *Scene) fight_fair.View {
    const f = g.fighter.?;
    const o = g.opponent.?;
    const bar = &g.energyBar.?.energyBar;
    return .{
        .gap = gapOf(g),
        .fighter_x = f.x,
        .opponent_x = o.x,
        .fighter_strip = f.curStrip,
        .opponent_strip = o.curStrip,
        .fighter_energy = bar.playerEnergy,
        .opponent_energy = bar.opponentEnergy,
        .seconds_left = scene.clock,
    };
}

/// The debug overlay (F9): drawn and logged after each beat.
fn showOverlay(g: *Game, scene: *Scene) void {
    const v = fairView(g, scene);
    hud.drawOverlay(g, scene, &g.fair, v);
    fight_fair.log(g.plat.ticks(), &g.fair, v);
}

fn toggleOverlay(g: *Game, scene: *Scene) void {
    g.fair.overlay = !g.fair.overlay;
    if (g.fair.overlay) {
        if (g.energyBar != null and g.fighter != null) showOverlay(g, scene);
    } else hud.clearOverlay(g, scene);
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
