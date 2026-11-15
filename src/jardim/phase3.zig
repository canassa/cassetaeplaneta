//! Port unit `phase3` (module) of JARDIM.EXE. Phase3Scene (raymap3): as phase1 without an exit door; the final enemy (the variant's picture) and the win; BUGS.md J2, J3, J6.
//!
//! The ten LabyrinthSceneVtbl overrides of the third phase (vtable 92da).
//! Each carries `// @orig <seg:off> <name>` with the JARDIM address; the
//! hwnd parameters are dropped (the platform's single window). The
//! original's "vbase pointer + 4 + offset" casts from a Portable to its
//! SceneObject are the flattened `*Object` here, so `obj == this.enemyChato`
//! is a plain pointer comparison.

const std = @import("std");
const msg = @import("../core/msg.zig");
const Msg = msg.Msg;
const platform = @import("../platform/platform.zig");
const Game = @import("core/game.zig").Game;
const object = @import("core/object.zig");
const Object = object.Object;
const world = @import("core/world.zig");
const Scene = world.Scene;
const scene = @import("scene.zig");
const labyrinth_scene = @import("labyrinth_scene.zig");
const labyrinth = @import("labyrinth.zig");
const labmap = @import("labmap.zig");
const object_create = @import("object_create.zig");
const sound = @import("sound.zig");
const occupancy = @import("behaviour/occupancy.zig");
const position = @import("behaviour/position.zig");

/// Phase3Scene's LabyrinthSceneVtbl (92da): set by `labyrinth_scene.ctor(.three)`.
pub const vtbl: world.SceneVtbl = .{
    .handleMessage = handleMessage,
    .createScreen = labyrinth_scene.createScreen3,
    .createNewScene = scene.createNewSceneDefault,
    .create = create,
    .hit = hit,
    .touch = touch,
    .placeObjects = placeObjects,
    .playEnemyAttackSound = playEnemyAttackSound,
    .playEnemyStepSound = playEnemyStepSound,
    .playFireSound = playFireSound,
    .playDoorSound = playDoorSound,
    .onLifeLost = onLifeLost,
};

/// `g_phase3Waves[i]`, the wave `wave_play(0, ...)` is handed (null: never opened).
fn wave(g: *Game, i: usize) ?platform.Wave {
    return g.phase3Waves[i];
}

fn playWave(g: *Game, i: usize) void {
    _ = sound.play(g, 0, wave(g, i));
}

fn newObject(g: *Game, kind: object.Kind) *Object {
    const o = g.local().create(Object) catch @panic("jardim phase3: out of memory");
    o.* = .{ .kind = kind };
    return o;
}

/// `operator_new(0x502)` + `portable_ctor_zoom(... 1, 0, 0, 10, 10, 0x37, 0xf ...)`:
/// a one-strip Portable named "Labirinto" at pixel position (x, y), `count`
/// frames of w x h, timer 0xf / 0x37 ms, steps 10 x 10, hidden.
fn newPortable(g: *Game, x: i16, y: i16, bmp: []const u8, count: i16, w: i16, h: i16) *Object {
    const o = newObject(g, .portable);
    object_create.portableCtorZoom(g, o, "Labirinto", x, y, bmp, count, w, h, 0xf, 0x37, 10, 10, 0, 0, true) catch
        @panic("jardim phase3: portable_ctor_zoom failed");
    return o;
}

/// The map cell of a coordinate: the original's `(v >> 5)` as a 16-bit index.
fn cellOf(v: i32) u16 {
    return @truncate(@as(u32, @bitCast(v >> 5)));
}

fn cellIndex(v: u16, limit: usize) usize {
    if (v >= limit) @panic("jardim phase3: cell outside the map (latent in the original)");
    return v;
}

/// LabyrinthSceneVtbl slot 00 handleMessage (phase3_scene_handle_message; hwnd dropped): WM_DESTROY, activation, the exit doors on SPACE, MM_WOM_DONE (the respawn), then `labyrinth_scene.handleMessage`.
// @orig 10b0:29af phase3_scene_handle_message
pub fn handleMessage(g: *Game, s: *Scene, m: Msg) u16 {
    switch (m.id) {
        msg.wm.destroy => {
            sound.stopAll(g);
            sound.freeAll(g);
            sound.mixClose(g);
            _ = g.plat.mciString("close musica");
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
        msg.wm.keydown => if (m.wparam == 0x20) {
            // SPACE: the cell one cell ahead (32 units along the view); an exit
            // door (7 or 8) below row 5 ends the game as a loss. Map 3 has none
            // there, so the branch is dead in the shipped game.
            const bd = s.backdrop.?;
            const t5 = g.tables.trig[5];
            const t6 = g.tables.trig[6];
            const nx: i32 = bd.playerX +% ldiv(0x200000, t5[bd.secAt]);
            const ny: i32 = bd.playerY +% ldiv(0x200000, t6[bd.cscAt]);
            const col = cellOf(nx);
            const row = cellOf(ny);
            // The original reads wallRows[row][col] unchecked; off the map is
            // never a door.
            if (row < world.map_rows and col < world.map_cols + 1) {
                const wall = bd.wallRows[row][col];
                const rowHi: i16 = @truncate((ny >> 5) >> 16);
                if (wall > 6 and wall <= 8 and rowHi >= 0 and (rowHi > 0 or row > 5)) {
                    _ = g.post(Msg.make(msg.wm.destroy, 0, 0, 0));
                    return 1;
                }
            }
        },
        msg.wm.mm_mcinotify => if (m.wparam == 1) {
            _ = g.plat.mciString("play musica from 0 notify");
            return 1;
        },
        msg.wm.mm_wom_done => {
            sound.stopAll(g);
            labyrinth_scene.respawn(g, s);
        },
        else => {},
    }
    return labyrinth_scene.handleMessage(g, s, m);
}

/// `_aFldiv`: the signed 32-bit quotient. A zero divisor is the original's divide fault.
fn ldiv(dividend: i32, divisor: i32) i32 {
    if (divisor == 0 or (dividend == std.math.minInt(i32) and divisor == -1))
        @panic("jardim phase3: divide fault in phase3_scene_handle_message (the original's #DE)");
    return @divTrunc(dividend, divisor);
}

/// LabyrinthSceneVtbl slot 07 create (phase3_scene_create; hwnd dropped).
// @orig 10b0:0000 phase3_scene_create
pub fn create(g: *Game, s: *Scene) *Scene {
    s.mapFile = "raymap3.dat";
    _ = labyrinth_scene.create(g, s);
    // The backdrop's setVanishPoint / setView / setAxis calls are its defaults
    // (they return `this`; see labyrinth_scene.create).
    const bd = s.backdrop.?;

    const face = newObject(g, .scene_object);
    object_create.sceneObjectCtor(g, face, 0x21, 0x17e, "rosto3.bmp", 5, 0x2c, 0x42, 0, 0) catch
        @panic("jardim phase3: scene_object_ctor failed");
    bd.face = face;

    bd.shot = newPortable(g, 0, 0, "shot3.bmp", 2, 0x40, 0x87);

    const hands = newObject(g, .scene_object);
    const hs = &g.hands3Strips;
    object_create.sceneObjectCtorStrips(g, hands, 0x91, 0x105, 3, &hs.files, &hs.frames, &hs.widths, &hs.heights, 0, 0) catch
        @panic("jardim phase3: scene_object_ctor_strips failed");
    bd.hands = hands;

    const strip = newObject(g, .wall_strip);
    object_create.wallStripCtor(g, strip, "paredes3.bmp", 0x20, bd.viewH *% 6, 6) catch
        @panic("jardim phase3: wall_strip_ctor failed");
    bd.wallStrip = strip;

    _ = occupancy.attach(g, bd.face.?, bd);
    _ = occupancy.attach(g, bd.shot.?, bd);
    _ = occupancy.attach(g, bd.hands.?, bd);
    _ = occupancy.attach(g, bd.wallStrip.?, bd);
    bd.hands.?.curStrip = g.curWeapon;

    s.enemyA = newPortable(g, 0x550, 0x230, "Chato.bmp", 2, 0x62, 0xe3);
    s.enemyB = newPortable(g, 0xf0, 0x990, "Bicho.bmp", 3, 0xea, 0xcd);
    // The variant (NOITE's 0x40b wParam; J7: always 0 from espquete) only
    // changes this picture.
    if (g.variant == 0) {
        s.finalEnemy = newPortable(g, 0x70, 0x9f0, "vamanf.bmp", 4, 0x52, 0xb6);
    } else {
        s.finalEnemy = newPortable(g, 0x70, 0x9f0, "espanf.bmp", 4, 0x4a, 0xad);
    }
    s.crossbow = newPortable(g, 0x3b0, 0x2b0, "besta3.bmp", 1, 0x80, 0x67);
    s.secondWeapon = newPortable(g, 0x1d0, 0x1f0, "bazuka3.bmp", 1, 0xa4, 0x35);
    s.medkit = newPortable(g, 0x6f0, 0x670, "medkit3.bmp", 1, 0x40, 0x30);
    s.beer = newPortable(g, 0x50, 0x990, "chopp3.bmp", 1, 0x20, 0x4d);
    s.snack = newPortable(g, 0x150, 0x350, "Camarao3.bmp", 1, 0x9c, 0x4e);
    s.arrows = newPortable(g, 0x5f0, 0x230, "setas3.bmp", 1, 0x20, 0x45);
    s.bombs = newPortable(g, 0x3f0, 0x230, "bomba3.bmp", 1, 0x18, 0x34);

    // All three enemies get the play-once-rewinds mark (isEnemy).
    position.setPlayOnceRewinds(occupancy.attach(g, s.enemyA.?, bd).?);
    position.setPlayOnceRewinds(occupancy.attach(g, s.enemyB.?, bd).?);
    position.setPlayOnceRewinds(occupancy.attach(g, s.finalEnemy.?, bd).?);
    _ = occupancy.attach(g, s.crossbow.?, bd);
    _ = occupancy.attach(g, s.secondWeapon.?, bd);
    _ = occupancy.attach(g, s.medkit.?, bd);
    _ = occupancy.attach(g, s.beer.?, bd);
    _ = occupancy.attach(g, s.snack.?, bd);
    _ = occupancy.attach(g, s.arrows.?, bd);
    _ = occupancy.attach(g, s.bombs.?, bd);

    // Each at its own constructor cell (Chato twice: the copy-paste of the
    // original; Bicho and the final enemy are not placed here).
    labmap.placeObject(g, bd, -1, -1, s.crossbow.?);
    labmap.placeObject(g, bd, -1, -1, s.enemyA.?);
    labmap.placeObject(g, bd, -1, -1, s.enemyA.?);
    labmap.placeObject(g, bd, -1, -1, s.secondWeapon.?);
    labmap.placeObject(g, bd, -1, -1, s.medkit.?);
    labmap.placeObject(g, bd, -1, -1, s.beer.?);
    labmap.placeObject(g, bd, -1, -1, s.snack.?);
    labmap.placeObject(g, bd, -1, -1, s.arrows.?);
    labmap.placeObject(g, bd, -1, -1, s.bombs.?);
    _ = s.placeObjects(g);

    const w = &g.phase3Waves;
    w[1] = sound.open(g, "chato.wav");
    w[2] = sound.open(g, "bibliaok.wav");
    w[3] = sound.open(g, "bicho.wav");
    w[4] = sound.open(g, "esmagar.wav");
    w[5] = sound.open(g, "acai.wav");
    w[6] = sound.open(g, "ARROTO.WAV");
    w[8] = sound.open(g, "arcfle02.wav");
    w[9] = sound.open(g, "bazzo.wav");
    w[7] = sound.open(g, "barul1.wav");
    w[10] = sound.open(g, "armad.wav");
    w[11] = sound.open(g, "abrport2.wav");
    w[12] = sound.open(g, "alivio.wav");
    w[13] = sound.open(g, "barul2.wav");
    w[14] = sound.open(g, "soco.wav");
    w[15] = sound.open(g, "berro.wav");

    s.handlerEnabled = 1;
    bd.active = 1;
    labyrinth.paint(g, bd);
    return s;
}

/// LabyrinthSceneVtbl slot 10 hit (phase3_scene_hit): a shot stopped in the cell (row, col).
// @orig 10b0:264c phase3_scene_hit
pub fn hit(g: *Game, s: *Scene, obj: ?*Object, col: i16, row: i16) void {
    const bd = s.backdrop.?;
    if (obj == s.enemyB) {
        // Bicho: any weapon removes it, +100.
        clearCell(bd, row, col);
        bd.score +%= 100;
        sound.stopAll(g);
    } else if (obj == s.enemyA) {
        // Chato: +200 per shot; the cell is not cleared (BUGS.md J2).
        if (g.fixes.jardim_chato_removed) clearCell(bd, row, col);
        bd.score +%= 200;
        sound.stopAll(g);
    }
}

fn clearCell(bd: *world.Backdrop, row: i16, col: i16) void {
    const r: u16 = @bitCast(row);
    const c: u16 = @bitCast(col);
    bd.objectRows[cellIndex(r, world.map_rows)][cellIndex(c, world.map_cols)] = null;
}

/// LabyrinthSceneVtbl slot 11 touch (phase3_scene_touch): a step into a cell holding `obj`; 1 = blocked.
// @orig 10b0:1f44 phase3_scene_touch
pub fn touch(g: *Game, s: *Scene, obj: *Object) i16 {
    const bd = s.backdrop.?;
    if (obj.isEnemy != 0) {
        if (obj == s.enemyB) {
            bd.lives -%= 1;
        } else if (obj == s.enemyA) {
            bd.health -%= 5;
        } else if (obj == s.finalEnemy) {
            // The only win: the backdrop's WM_DESTROY turns wParam 0xffff into one.
            _ = g.post(Msg.make(msg.wm.destroy, 0xffff, 0, 0));
        }
        return 1;
    }
    // What the pickup leaves in the cell: nothing (taken), or the other
    // weapon (a swap) or the refused object.
    var left: ?*Object = null;
    if (obj == s.secondWeapon) {
        if (bd.shotInFlight == 0) {
            const hands = bd.hands.?;
            if (hands.curStrip == 2) {
                bd.ammo +%= 3;
            } else {
                if (hands.curStrip == 1) left = s.crossbow;
                hands.curStrip = 2;
                hands.curFrame = 0;
                bd.shot.?.curFrame = 1;
                bd.ammo = 3;
            }
            playWave(g, 10);
        } else if (g.fixes.jardim_weapon_waits_for_shot) {
            left = obj;
        }
    } else if (obj == s.crossbow) {
        if (bd.shotInFlight == 0) {
            const hands = bd.hands.?;
            if (hands.curStrip == 1) {
                bd.ammo +%= 6;
            } else {
                if (hands.curStrip == 2) left = s.secondWeapon;
                hands.curStrip = 1;
                hands.curFrame = 0;
                bd.shot.?.curFrame = 0;
                bd.ammo = 6;
            }
            playWave(g, 7);
        } else if (g.fixes.jardim_weapon_waits_for_shot) {
            left = obj;
        } else {
            // J3: the pickup vanishes, but the crossbow's sound plays anyway.
            playWave(g, 7);
        }
    } else if (obj == s.beer) {
        bd.health -%= 15;
        bd.score +%= 100;
        playWave(g, 6);
    } else if (obj == s.snack) {
        bd.health +%= 5;
        playWave(g, 5);
    } else if (obj == s.medkit) {
        bd.health +%= 20;
        playWave(g, 12);
    } else if (obj == s.arrows) {
        if (bd.hands.?.curStrip == 1) {
            playWave(g, 13);
            bd.ammo +%= 3;
        } else {
            left = s.arrows;
        }
    } else if (obj == s.bombs) {
        if (bd.hands.?.curStrip == 2) {
            playWave(g, 13);
            bd.ammo +%= 1;
        } else {
            left = s.bombs;
        }
    }
    bd.objectRows[cellIndex(cellOf(bd.playerY), world.map_rows)][cellIndex(cellOf(bd.playerX), world.map_cols)] = left;
    return 0;
}

/// LabyrinthSceneVtbl slot 12 placeObjects (phase3_scene_place_objects): 42 placements, 1-based (row, col).
// @orig 10b0:10d0 phase3_scene_place_objects
pub fn placeObjects(g: *Game, s: *Scene) *Scene {
    const bd = s.backdrop.?;
    const Cell = struct { i16, i16 };
    const bicho = [_]Cell{ .{ 78, 6 }, .{ 76, 8 }, .{ 73, 27 } };
    const bombs = [_]Cell{ .{ 18, 31 }, .{ 18, 32 }, .{ 18, 33 }, .{ 18, 45 }, .{ 18, 48 }, .{ 18, 50 }, .{ 18, 52 } };
    const arrows = [_]Cell{ .{ 19, 47 }, .{ 18, 49 }, .{ 18, 51 }, .{ 18, 53 }, .{ 21, 28 }, .{ 21, 27 } };
    const bazooka = [_]Cell{ .{ 18, 43 }, .{ 15, 14 } };
    const crossbow = [_]Cell{ .{ 18, 54 }, .{ 21, 29 } };
    const chato = [_]Cell{ .{ 18, 42 }, .{ 33, 25 }, .{ 44, 28 }, .{ 50, 12 }, .{ 51, 29 }, .{ 49, 47 }, .{ 19, 50 }, .{ 29, 47 }, .{ 41, 39 } };
    const shrimp = [_]Cell{ .{ 27, 10 }, .{ 25, 10 }, .{ 59, 2 }, .{ 56, 2 }, .{ 55, 2 }, .{ 53, 2 } };
    const medkit = [_]Cell{ .{ 51, 55 }, .{ 51, 54 }, .{ 53, 4 }, .{ 53, 12 }, .{ 53, 13 } };
    for (bicho) |c| labmap.placeObject(g, bd, c[0], c[1], s.enemyB.?);
    for (bombs) |c| labmap.placeObject(g, bd, c[0], c[1], s.bombs.?);
    for (arrows) |c| labmap.placeObject(g, bd, c[0], c[1], s.arrows.?);
    for (bazooka) |c| labmap.placeObject(g, bd, c[0], c[1], s.secondWeapon.?);
    for (crossbow) |c| labmap.placeObject(g, bd, c[0], c[1], s.crossbow.?);
    for (chato) |c| labmap.placeObject(g, bd, c[0], c[1], s.enemyA.?);
    for (shrimp) |c| labmap.placeObject(g, bd, c[0], c[1], s.snack.?);
    for (medkit) |c| labmap.placeObject(g, bd, c[0], c[1], s.medkit.?);
    labmap.placeObject(g, bd, 76, 2, s.beer.?);
    labmap.placeObject(g, bd, 79, 3, s.finalEnemy.?);
    return s;
}

/// LabyrinthSceneVtbl slot 13 playEnemyAttackSound (phase3_scene_play_enemy_attack_sound).
// @orig 10b0:2768 phase3_scene_play_enemy_attack_sound
pub fn playEnemyAttackSound(g: *Game, s: *Scene, obj: *Object) void {
    if (obj == s.enemyB) {
        playWave(g, 2);
    } else if (obj == s.enemyA) {
        // g_phase3Waves[0] is never opened: Chato's attack is silent.
        playWave(g, 0);
    }
}

/// LabyrinthSceneVtbl slot 14 playEnemyStepSound (phase3_scene_play_enemy_step_sound).
// @orig 10b0:2837 phase3_scene_play_enemy_step_sound
pub fn playEnemyStepSound(g: *Game, s: *Scene, obj: *Object) void {
    sound.pump(g);
    if (obj == s.enemyB) {
        playWave(g, 3);
    } else if (obj == s.enemyA) {
        playWave(g, 1);
    }
}

/// LabyrinthSceneVtbl slot 15 playFireSound (phase3_scene_play_fire_sound).
// @orig 10b0:290b phase3_scene_play_fire_sound
pub fn playFireSound(g: *Game, s: *Scene) void {
    const strip = s.backdrop.?.hands.?.curStrip;
    if (strip == 1) {
        playWave(g, 8);
    } else if (strip == 2) {
        playWave(g, 9);
    } else {
        playWave(g, 14);
    }
}

/// LabyrinthSceneVtbl slot 16 playDoorSound (phase3_scene_play_door_sound).
// @orig 10b0:2987 phase3_scene_play_door_sound
pub fn playDoorSound(g: *Game, s: *Scene) void {
    _ = s;
    playWave(g, 11);
}

/// LabyrinthSceneVtbl slot 17 onLifeLost (phase3_scene_on_life_lost; hwnd dropped): `berro` with a notify window.
// @orig 10b0:273f phase3_scene_on_life_lost
pub fn onLifeLost(g: *Game, s: *Scene) void {
    _ = s;
    _ = sound.play(g, g.mainWindow, wave(g, 15));
}
