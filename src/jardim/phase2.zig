//! Port unit `phase2` (module) of JARDIM.EXE. Phase2Scene (raymap2): as phase1; createNewScene builds Phase3Scene; BUGS.md J3, J6.
//!
//! The phase's slots of the LabyrinthSceneVtbl (`vtbl`): its handler, the level (create, place
//! objects), a shot's hit, a step's touch and the sounds. J3 (a weapon touched while a shot
//! flies is lost) is ported as the code does it, the fix behind
//! `fixes.jardim_weapon_waits_for_shot`. J6 (a step into an enemy repeats while the key is
//! held) is `labyrinth_input`'s; the touch here only deals the damage.

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
const scene = @import("scene.zig");
const labyrinth = @import("labyrinth.zig");
const labmap = @import("labmap.zig");
const labyrinth_scene = @import("labyrinth_scene.zig");
const object_create = @import("object_create.zig");
const occupancy = @import("behaviour/occupancy.zig");
const position = @import("behaviour/position.zig");
const sound = @import("sound.zig");
const weapons = @import("weapons.zig");

/// Phase2Scene's LabyrinthSceneVtbl (91aa): set by `labyrinth_scene.ctor(.two)`.
pub const vtbl: world.SceneVtbl = .{
    .handleMessage = handleMessage,
    .createScreen = labyrinth_scene.createScreen2,
    .createNewScene = createNewScene,
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

/// `wave_play(0, g_phase2Waves[i])`.
fn playWave(g: *Game, i: usize) void {
    _ = sound.play(g, 0, g.phase2Waves[i]);
}

fn oom() noreturn {
    std.debug.panic("jardim phase2: out of memory", .{});
}

/// `new Object` (the original's `operator new` of that class, on the task's heap).
fn newObject(g: *Game, kind: object.Kind) *Object {
    const o = g.local().create(Object) catch oom();
    o.* = .{ .kind = kind };
    return o;
}

/// The cell of a 1/32-cell coordinate (`>> 5`); the original indexes the row table
/// unchecked, a coordinate outside the map is a panic.
fn cellOf(v: i32, limit: usize) usize {
    const c = v >> 5;
    if (c < 0 or c >= limit) @panic("BUGS.md latent (JARDIM): unchecked cells, table entries and divisors (phase2: the player outside the map)");
    return @intCast(c);
}

/// LabyrinthSceneVtbl slot 00 handleMessage (phase2_scene_handle_message; hwnd dropped): WM_DESTROY, activation, the exit doors on SPACE, MM_WOM_DONE (the respawn), then `labyrinth_scene.handleMessage`.
// @orig 10a8:3c60 phase2_scene_handle_message
pub fn handleMessage(g: *Game, s: *Scene, m: Msg) u16 {
    const bd = s.backdrop.?;
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
            // The probe one 1/32-cell step ahead: 0x200000 / (1/cos) and / (1/sin) added to
            // the position (16.16 tables: a 32-unit step).
            const dx = @divTrunc(@as(i32, 0x200000), g.tables.trig[5][bd.secAt]);
            const x = bd.playerX +% dx;
            const dy = @divTrunc(@as(i32, 0x200000), g.tables.trig[6][bd.cscAt]);
            const y = bd.playerY +% dy;
            const col = cellOf(x, world.map_cols + 1);
            const row = cellOf(y, world.map_rows);
            const wall = bd.wallRows[row][col];
            // Doors 7 and 8, and (the "row > 1" guard) not the entry next to the start.
            if (wall > 6 and wall <= 8 and (y >> 5) > 1) {
                g.startX = 0x30;
                g.startY = 0x70;
                _ = g.post(Msg.make(msg.noite.exit_finished, @bitCast(s.exit.?.exit.exitIndex), 0, 0));
                return 1;
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

/// LabyrinthSceneVtbl slot 06 createNewScene (phase2_scene_create_new_scene): the Phase3Scene.
// @orig 10a8:0000 phase2_scene_create_new_scene
pub fn createNewScene(g: *Game, s: *Scene, exit_index: i16) ?*Scene {
    if (s.exitIndex == exit_index) {
        return labyrinth_scene.ctor(g, .three, "Labirinto") catch oom();
    }
    return scene.createNewSceneDefault(g, s, exit_index);
}

/// One Portable of the level: `portable_ctor_zoom(1, 0, 0, 10, 10, 0x37, 0xf, h, w, count, bmp, y, x, "Labirinto")`.
fn portable(g: *Game, bmp: []const u8, count: i16, w: i16, h: i16, x: i16, y: i16) *Object {
    const o = newObject(g, .portable);
    object_create.portableCtorZoom(g, o, "Labirinto", x, y, bmp, count, w, h, 0xf, 0x37, 10, 10, 0, 0, true) catch oom();
    return o;
}

/// `attach(backdrop)` (SceneObject slot 0x29) of an object the level just built.
fn attach(g: *Game, bd: *Backdrop, o: *Object) *Object {
    return occupancy.attach(g, o, bd) orelse o;
}

/// LabyrinthSceneVtbl slot 07 create (phase2_scene_create; hwnd dropped).
// @orig 10a8:0078 phase2_scene_create
pub fn create(g: *Game, s: *Scene) *Scene {
    s.mapFile = "raymap2.dat";
    _ = labyrinth_scene.create(g, s);
    // setVanishPoint(0x66, 0x202), setView(0, 0x1c7, 0, 300, 0xa0), setAxis(0x159, 0): the
    // Backdrop defaults, which return `this` (as in `labyrinth_scene.create`).
    const bd = s.backdrop.?;

    // The exit door (portainv.bmp), attached and added as exit `exitIndex`.
    const door = newObject(g, .exit);
    object_create.exitCtor(g, door, 0, 0, "portainv.bmp", 1, 0x20, 300, 0, 0, 0x20, 300, 0xf, 0x37, 0, 1, 0, true) catch oom();
    s.exit = door;
    _ = attach(g, bd, door);
    s.exitIndex = scene.addExitAt(g, s, door, @truncate(bd.startX), @truncate(bd.startY), null);

    const face = newObject(g, .scene_object);
    object_create.sceneObjectCtor(g, face, 0x21, 0x17e, "rosto2.bmp", 5, 0x2c, 0x42, 0, 0) catch oom();
    bd.face = face;
    const shot = newObject(g, .portable);
    object_create.portableCtorZoom(g, shot, "Labirinto", 0, 0, "shot2.bmp", 2, 0x40, 0x87, 0xf, 0x37, 10, 10, 0, 0, true) catch oom();
    bd.shot = shot;
    const hands = newObject(g, .scene_object);
    object_create.sceneObjectCtorStrips(g, hands, 0x91, 0x105, 3, &g.hands2Strips.files, &g.hands2Strips.frames, &g.hands2Strips.widths, &g.hands2Strips.heights, 0, 0) catch oom();
    bd.hands = hands;
    const wall = newObject(g, .wall_strip);
    object_create.wallStripCtor(g, wall, "paredes2.bmp", 0x20, bd.viewH *% 6, 6) catch oom();
    bd.wallStrip = wall;
    _ = attach(g, bd, face);
    _ = attach(g, bd, shot);
    _ = attach(g, bd, hands);
    _ = attach(g, bd, wall);
    hands.curStrip = g.curWeapon;

    s.enemyA = portable(g, "alemao.bmp", 2, 0x80, 0xe8, 0x1d0, 0x110);
    s.enemyB = portable(g, "siri.bmp", 4, 0x152, 0xd9, 0x1b0, 0x670);
    s.crossbow = portable(g, "besta2.bmp", 1, 0x80, 0x67, 0xb0, 0xd0);
    s.secondWeapon = portable(g, "bazuka2.bmp", 1, 0xa4, 0x35, 0xf0, 0x770);
    s.medkit = portable(g, "medkit2.bmp", 1, 0x40, 0x30, 0x170, 0x410);
    s.beer = portable(g, "chopp2.bmp", 1, 0x20, 0x4d, 0xf0, 0x90);
    s.snack = portable(g, "Camarao2.bmp", 1, 0x40, 0x26, 0x290, 0x3d0);
    s.arrows = portable(g, "setas2.bmp", 1, 0x20, 0x45, 0x70, 0x130);
    s.bombs = portable(g, "bomba2.bmp", 1, 0x18, 0x34, 0x50, 0x9b0);

    // The enemies get play-once-rewinds, all nine are attached.
    position.setPlayOnceRewinds(attach(g, bd, s.enemyA.?));
    position.setPlayOnceRewinds(attach(g, bd, s.enemyB.?));
    _ = attach(g, bd, s.crossbow.?);
    _ = attach(g, bd, s.secondWeapon.?);
    _ = attach(g, bd, s.medkit.?);
    _ = attach(g, bd, s.beer.?);
    _ = attach(g, bd, s.snack.?);
    _ = attach(g, bd, s.arrows.?);
    _ = attach(g, bd, s.bombs.?);

    // Each placed once at its own cell, then every copy (slot 0x12).
    labmap.placeObject(g, bd, -1, -1, s.crossbow.?);
    labmap.placeObject(g, bd, -1, -1, s.enemyA.?);
    labmap.placeObject(g, bd, -1, -1, s.enemyB.?);
    labmap.placeObject(g, bd, -1, -1, s.secondWeapon.?);
    labmap.placeObject(g, bd, -1, -1, s.medkit.?);
    labmap.placeObject(g, bd, -1, -1, s.beer.?);
    labmap.placeObject(g, bd, -1, -1, s.snack.?);
    labmap.placeObject(g, bd, -1, -1, s.arrows.?);
    labmap.placeObject(g, bd, -1, -1, s.bombs.?);
    _ = s.placeObjects(g);

    // No MCI open and no WaveMix session: phase 1's carry over. 16 waves (the table's
    // [7] is opened after [8] and [9]: the order of `g.waves`).
    const w = &g.phase2Waves;
    w[0] = sound.open(g, "assass.wav");
    w[1] = sound.open(g, "tiros.wav");
    w[2] = sound.open(g, "siri2.wav");
    w[3] = sound.open(g, "siri3.wav");
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

/// LabyrinthSceneVtbl slot 10 hit (phase2_scene_hit): a Siri dies only to the bazooka
/// (+100), an Alemao to any weapon (+200); the cell is cleared and the waves stop.
// @orig 10a8:38c5 phase2_scene_hit
pub fn hit(g: *Game, s: *Scene, obj: ?*Object, col: i16, row: i16) void {
    const bd = s.backdrop.?;
    if (obj == s.enemyB) {
        if (bd.hands.?.curStrip == 2) {
            bd.objectRows[@intCast(row)][@intCast(col)] = null;
            bd.score +%= 100;
            sound.stopAll(g);
        }
    } else if (obj == s.enemyA) {
        bd.objectRows[@intCast(row)][@intCast(col)] = null;
        bd.score +%= 200;
        sound.stopAll(g);
    }
}

/// LabyrinthSceneVtbl slot 11 touch (phase2_scene_touch): a pickup is taken (the cell keeps
/// `left`, the other weapon or a refused pickup) and the step goes on (0); an enemy hurts
/// and blocks (1).
// @orig 10a8:3227 phase2_scene_touch
pub fn touch(g: *Game, s: *Scene, obj: *Object) i16 {
    const bd = s.backdrop.?;
    var left: ?*Object = null;
    // Not in the original: with the weapon inventory a weapon is taken whatever the shot does.
    const inv = weapons.active(g);
    if (obj.isEnemy == 0) {
        if (obj == s.secondWeapon) {
            if (inv) {
                weapons.pickWeapon(g, bd, weapons.heavy, 3);
                playWave(g, 10);
            } else if (bd.shotInFlight == 0) {
                if (bd.hands.?.curStrip == 2) {
                    bd.ammo +%= 3;
                } else {
                    if (bd.hands.?.curStrip == 1) left = s.crossbow;
                    bd.hands.?.curStrip = 2;
                    bd.hands.?.curFrame = 0;
                    bd.shot.?.curFrame = 1;
                    bd.ammo = 3;
                }
                playWave(g, 10);
            } else if (g.fixes.jardim_weapon_waits_for_shot) {
                // J3 fixed: the bazooka waits in its cell.
                left = obj;
            }
        } else if (obj == s.crossbow) {
            if (inv) {
                weapons.pickWeapon(g, bd, weapons.crossbow, 6);
                playWave(g, 7);
            } else if (bd.shotInFlight == 0) {
                if (bd.hands.?.curStrip == 1) {
                    bd.ammo +%= 6;
                } else {
                    if (bd.hands.?.curStrip == 2) left = s.secondWeapon;
                    bd.hands.?.curStrip = 1;
                    bd.hands.?.curFrame = 0;
                    bd.shot.?.curFrame = 0;
                    bd.ammo = 6;
                }
                playWave(g, 7);
            } else if (g.fixes.jardim_weapon_waits_for_shot) {
                // J3 fixed: the crossbow waits in its cell, silently.
                left = obj;
            } else {
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
            if (inv) {
                if (weapons.pickAmmo(g, bd, weapons.crossbow, 3)) playWave(g, 13) else left = s.arrows;
            } else if (bd.hands.?.curStrip == 1) {
                playWave(g, 13);
                bd.ammo +%= 3;
            } else {
                left = s.arrows;
            }
        } else if (obj == s.bombs) {
            if (inv) {
                if (weapons.pickAmmo(g, bd, weapons.heavy, 1)) playWave(g, 13) else left = s.bombs;
            } else if (bd.hands.?.curStrip == 2) {
                playWave(g, 13);
                bd.ammo +%= 1;
            } else {
                left = s.bombs;
            }
        }
        bd.objectRows[cellOf(bd.playerY, world.map_rows)][cellOf(bd.playerX, world.map_cols)] = left;
        return 0;
    }
    if (obj == s.enemyB) {
        bd.lives -%= 1;
    } else if (obj == s.enemyA) {
        bd.health -%= 5;
    }
    return 1;
}

/// One object's copies: (row, col) 1-based, as `labmap.placeObject`.
fn place(g: *Game, bd: *Backdrop, obj: ?*Object, cells: []const [2]i16) void {
    for (cells) |c| labmap.placeObject(g, bd, c[0], c[1], obj.?);
}

/// LabyrinthSceneVtbl slot 12 placeObjects (phase2_scene_place_objects): the 97 copies, in
/// the original's order (a beer at (24,30) overwrites a shrimp placed there before it).
// @orig 10a8:1103 phase2_scene_place_objects
pub fn placeObjects(g: *Game, s: *Scene) *Scene {
    const bd = s.backdrop.?;
    place(g, bd, s.enemyB, &.{ .{ 51, 13 }, .{ 74, 42 }, .{ 74, 35 }, .{ 78, 3 } });
    place(g, bd, s.enemyA, &.{ .{ 8, 14 }, .{ 12, 2 }, .{ 33, 2 }, .{ 17, 9 }, .{ 12, 30 }, .{ 7, 49 }, .{ 12, 47 }, .{ 12, 48 }, .{ 12, 54 }, .{ 25, 45 }, .{ 32, 45 }, .{ 37, 45 }, .{ 46, 45 }, .{ 68, 51 }, .{ 46, 16 }, .{ 68, 51 }, .{ 46, 16 }, .{ 46, 12 }, .{ 26, 7 }, .{ 45, 33 }, .{ 43, 32 }, .{ 12, 54 }, .{ 45, 38 }, .{ 45, 36 }, .{ 53, 37 }, .{ 57, 37 }, .{ 64, 41 }, .{ 55, 33 }, .{ 60, 47 }, .{ 33, 32 }, .{ 28, 32 } });
    place(g, bd, s.secondWeapon, &.{ .{ 12, 51 }, .{ 59, 7 } });
    place(g, bd, s.arrows, &.{ .{ 9, 3 }, .{ 10, 3 }, .{ 9, 12 }, .{ 12, 25 }, .{ 12, 26 }, .{ 9, 47 }, .{ 6, 46 }, .{ 18, 45 }, .{ 38, 51 }, .{ 42, 51 }, .{ 46, 51 }, .{ 55, 51 }, .{ 55, 52 }, .{ 69, 36 }, .{ 69, 37 }, .{ 69, 38 }, .{ 39, 32 }, .{ 41, 32 }, .{ 38, 18 }, .{ 42, 12 }, .{ 26, 36 }, .{ 21, 36 }, .{ 22, 34 }, .{ 15, 54 }, .{ 14, 54 } });
    place(g, bd, s.medkit, &.{ .{ 12, 52 }, .{ 12, 28 }, .{ 24, 31 }, .{ 32, 11 }, .{ 35, 8 }, .{ 39, 3 }, .{ 48, 51 }, .{ 48, 52 }, .{ 55, 47 }, .{ 57, 36 }, .{ 13, 54 } });
    place(g, bd, s.snack, &.{ .{ 35, 49 }, .{ 31, 49 }, .{ 26, 49 }, .{ 21, 49 }, .{ 12, 37 }, .{ 24, 30 }, .{ 31, 20 } });
    place(g, bd, s.beer, &.{ .{ 4, 7 }, .{ 16, 17 }, .{ 16, 21 }, .{ 28, 16 }, .{ 24, 30 }, .{ 75, 54 }, .{ 76, 54 }, .{ 77, 54 } });
    place(g, bd, s.crossbow, &.{ .{ 77, 52 }, .{ 6, 5 } });
    place(g, bd, s.bombs, &.{ .{ 77, 2 }, .{ 77, 3 }, .{ 42, 3 }, .{ 46, 10 }, .{ 46, 17 }, .{ 34, 18 }, .{ 77, 51 } });
    return s;
}

/// LabyrinthSceneVtbl slot 13 playEnemyAttackSound (phase2_scene_play_enemy_attack_sound): Siri's siri2, Alemao's assass.
// @orig 10a8:3a19 phase2_scene_play_enemy_attack_sound
pub fn playEnemyAttackSound(g: *Game, s: *Scene, obj: *Object) void {
    if (obj == s.enemyB) {
        playWave(g, 2);
    } else if (obj == s.enemyA) {
        playWave(g, 0);
    }
}

/// LabyrinthSceneVtbl slot 14 playEnemyStepSound (phase2_scene_play_enemy_step_sound): pump, then Siri's siri3, Alemao's tiros.
// @orig 10a8:3ae8 phase2_scene_play_enemy_step_sound
pub fn playEnemyStepSound(g: *Game, s: *Scene, obj: *Object) void {
    sound.pump(g);
    if (obj == s.enemyB) {
        playWave(g, 3);
    } else if (obj == s.enemyA) {
        playWave(g, 1);
    }
}

/// LabyrinthSceneVtbl slot 15 playFireSound (phase2_scene_play_fire_sound): crossbow arcfle02, bazooka bazzo, else the punch.
// @orig 10a8:3bbc phase2_scene_play_fire_sound
pub fn playFireSound(g: *Game, s: *Scene) void {
    switch (s.backdrop.?.hands.?.curStrip) {
        1 => playWave(g, 8),
        2 => playWave(g, 9),
        else => playWave(g, 14),
    }
}

/// LabyrinthSceneVtbl slot 16 playDoorSound (phase2_scene_play_door_sound): abrport2.
// @orig 10a8:3c38 phase2_scene_play_door_sound
pub fn playDoorSound(g: *Game, s: *Scene) void {
    _ = s;
    playWave(g, 11);
}

/// LabyrinthSceneVtbl slot 17 onLifeLost (phase2_scene_on_life_lost; hwnd dropped): `berro` with a notify window (MM_WOM_DONE respawns).
// @orig 10a8:39f0 phase2_scene_on_life_lost
pub fn onLifeLost(g: *Game, s: *Scene) void {
    _ = s;
    _ = sound.play(g, g.plat.windowHandle(), g.phase2Waves[15]);
}
