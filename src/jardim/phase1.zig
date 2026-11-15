//! Port unit `phase1` (module) of JARDIM.EXE. Phase1Scene (raymap1): create (objects, MCI music, WaveMix), placeObjects, touch, hit, the sounds, onLifeLost, its handler (exit doors, the scream's end), createNewScene (Phase2Scene); BUGS.md J3, J6.
//!
//! Every object of the level is one `Object` allocated from the task's heap
//! (`g.local()`, the original's `operator new`); the scene's fields name the
//! Portables, and a pickup or enemy is ONE object stored in every one of its
//! cells. The original compares a SceneObject pointer (the Portable's virtual
//! base, +4) with each field; here the object is the same pointer.

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
const scene_mod = @import("scene.zig");
const labyrinth_scene = @import("labyrinth_scene.zig");
const labyrinth = @import("labyrinth.zig");
const labmap = @import("labmap.zig");
const object_create = @import("object_create.zig");
const occupancy = @import("behaviour/occupancy.zig");
const position = @import("behaviour/position.zig");
const sound = @import("sound.zig");

/// Phase1Scene's LabyrinthSceneVtbl (834c): set by `labyrinth_scene.ctor(.one)`.
pub const vtbl: world.SceneVtbl = .{
    .handleMessage = handleMessage,
    .createScreen = labyrinth_scene.createScreen1,
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

const scene_name = "Labirinto";

fn newObject(g: *Game) *Object {
    return g.local().create(Object) catch std.debug.panic("jardim phase1: out of memory", .{});
}

fn built(r: object_create.Error!void) void {
    r catch |e| std.debug.panic("jardim phase1: object constructor failed: {s}", .{@errorName(e)});
}

fn bdOf(s: *Scene) *Backdrop {
    return s.backdrop.?;
}

/// objectRows[row][col] = obj for the cell index of a long position (>> 5).
fn cellSlot(bd: *Backdrop, row: i32, col: i32) *?*Object {
    if (row < 0 or row >= world.map_rows or col < 0 or col >= world.map_cols)
        @panic("jardim phase1: cell outside the map (latent in the original)");
    return &bd.objectRows[@intCast(row)][@intCast(col)];
}

/// One Portable of the level: `portable_ctor_zoom` with the timer 0xf / 0x37 ms
/// and the step 10 / 10 every one of them has; `x`, `y` its constructor position.
fn newPortable(g: *Game, file: []const u8, count: i16, w: i16, h: i16, x: i16, y: i16) *Object {
    const o = newObject(g);
    built(object_create.portableCtorZoom(g, o, scene_name, x, y, file, count, w, h, 0xf, 0x37, 10, 10, 0, 0, true));
    return o;
}

/// LabyrinthSceneVtbl slot 00 handleMessage (phase1_scene_handle_message; hwnd dropped): WM_DESTROY, activation, the exit doors on SPACE, MM_WOM_DONE (the respawn), then `labyrinth_scene.handleMessage`.
// @orig 1098:3159 phase1_scene_handle_message
pub fn handleMessage(g: *Game, s: *Scene, m: Msg) u16 {
    switch (m.id) {
        msg.wm.destroy => {
            sound.stopAll(g);
            sound.freeAll(g);
            sound.mixClose(g);
            _ = g.plat.mciString("close musica");
        },
        msg.wm.activate => {
            // Active unless deactivated or minimised.
            const active = m.wparam != 0 and m.hi() == 0;
            if (active) {
                _ = g.plat.mciString("play musica notify");
                if (sound.mixActivate(g) == 0)
                    _ = g.plat.messageBox("Erro Wave Mix", "N\xe3o consegue ativar", platform.mb.iconexclamation);
            } else {
                _ = g.plat.mciString("pause musica");
                if (sound.mixDeactivate(g) == 0)
                    _ = g.plat.messageBox("Erro Wave Mix", "N\xe3o consegue desativar", platform.mb.iconexclamation);
            }
        },
        msg.wm.keydown => {
            if (m.wparam == 0x20) {
                // The cell one step ahead (the backdrop's door probe).
                const bd = bdOf(s);
                const dx = @divTrunc(@as(i32, 0x200000), g.tables.trig[5][bd.secAt]);
                const dy = @divTrunc(@as(i32, 0x200000), g.tables.trig[6][bd.cscAt]);
                const col32 = (bd.playerX +% dx) >> 5;
                const row32 = (bd.playerY +% dy) >> 5;
                const col: u16 = @truncate(@as(u32, @bitCast(col32)));
                const row: u16 = @truncate(@as(u32, @bitCast(row32)));
                if (row >= world.map_rows or col >= world.map_cols + 1)
                    @panic("jardim phase1: door probe outside the map (latent in the original)");
                const wall = bd.wallRows[row][col];
                // 7 or 8, and the row (a long) above 1: not the 7 beside the start.
                if (wall > 6 and wall <= 8 and row32 > 1) {
                    g.startX = 0x6d0;
                    g.startY = 0x30;
                    _ = g.post(Msg.make(0x402, @bitCast(s.exit.?.exit.exitIndex), 0, 0));
                    return 1;
                }
            }
        },
        0x3b9 => {
            // MM_MCINOTIFY: the song ended (MCI_NOTIFY_SUCCESSFUL): again.
            if (m.wparam == 1) {
                _ = g.plat.mciString("play musica from 0 notify");
                return 1;
            }
        },
        0x3bd => {
            // MM_WOM_DONE: the `berro` wave ended.
            sound.stopAll(g);
            labyrinth_scene.respawn(g, s);
        },
        else => {},
    }
    return labyrinth_scene.handleMessage(g, s, m);
}

/// LabyrinthSceneVtbl slot 06 createNewScene (phase1_scene_create_new_scene): the Phase2Scene.
// @orig 1098:0000 phase1_scene_create_new_scene
pub fn createNewScene(g: *Game, s: *Scene, exit_index: i16) ?*Scene {
    if (s.exitIndex == exit_index) {
        return labyrinth_scene.ctor(g, .two, scene_name) catch null;
    }
    return scene_mod.createNewSceneDefault(g, s, exit_index);
}

/// LabyrinthSceneVtbl slot 07 create (phase1_scene_create; hwnd dropped).
// @orig 1098:0078 phase1_scene_create
pub fn create(g: *Game, s: *Scene) *Scene {
    s.mapFile = "raymap1.dat";
    _ = labyrinth_scene.create(g, s);
    // The three setVanishPoint / setView / setAxis calls on the screen repeat
    // the Backdrop defaults `labyrinth_scene.create` already sets.
    const bd = bdOf(s);

    // The door: an Exit (portainv.bmp) whose only use is its exit index.
    const door = newObject(g);
    built(object_create.exitCtor(g, door, 0, 0, "portainv.bmp", 1, 0x20, 300, 0, 0, 0x20, 300, 0xf, 0x37, 0, 1, 0, true));
    s.exit = door;
    _ = occupancy.attach(g, door, bd);
    s.exitIndex = scene_mod.addExitAt(g, s, door, @truncate(bd.startX), @truncate(bd.startY), &g.conditionTrue);

    // The backdrop's objects: the face, the shot, the hands, the wall strip.
    const face = newObject(g);
    built(object_create.sceneObjectCtor(g, face, 0x21, 0x17e, "rosto1.bmp", 5, 0x2c, 0x42, 0, 0));
    bd.face = face;
    const shot = newPortable(g, "shot1.bmp", 2, 0x40, 0x87, 0, 0);
    bd.shot = shot;
    const hands = newObject(g);
    built(object_create.sceneObjectCtorStrips(g, hands, 0x91, 0x105, 3, &g.hands1Strips.files, &g.hands1Strips.frames, &g.hands1Strips.widths, &g.hands1Strips.heights, 0, 0));
    bd.hands = hands;
    const wall = newObject(g);
    built(object_create.wallStripCtor(g, wall, "paredes1.bmp", 0x20, bd.viewH *% 6, 6));
    bd.wallStrip = wall;
    _ = occupancy.attach(g, face, bd);
    _ = occupancy.attach(g, shot, bd);
    _ = occupancy.attach(g, hands, bd);
    _ = occupancy.attach(g, wall, bd);
    hands.curStrip = g.curWeapon;

    // The eight Portables, at their constructor cells (y, x in 1/32 cell).
    s.enemyA = newPortable(g, "bussuf.bmp", 4, 0x80, 0xe3, 0x410, 0x510);
    s.enemyB = newPortable(g, "seios.bmp", 5, 0x80, 200, 0x90, 0x510);
    s.crossbow = newPortable(g, "besta.bmp", 1, 0x80, 0x67, 0x390, 0x210);
    s.secondWeapon = newPortable(g, "sutien1.bmp", 1, 0x80, 0x55, 0x390, 0x410);
    s.medkit = newPortable(g, "medkit.bmp", 1, 0x40, 0x30, 0x6d0, 0xf0);
    s.beer = newPortable(g, "chopp.bmp", 1, 0x20, 0x4d, 0x350, 0x550);
    s.snack = newPortable(g, "acai.bmp", 1, 0x40, 0x26, 0x1d0, 0x170);
    s.arrows = newPortable(g, "setas.bmp", 1, 0x20, 0x45, 0x3f0, 0x150);
    if (occupancy.attach(g, s.enemyA.?, bd)) |o| position.setPlayOnceRewinds(o);
    if (occupancy.attach(g, s.enemyB.?, bd)) |o| position.setPlayOnceRewinds(o);
    _ = occupancy.attach(g, s.crossbow.?, bd);
    _ = occupancy.attach(g, s.secondWeapon.?, bd);
    _ = occupancy.attach(g, s.medkit.?, bd);
    _ = occupancy.attach(g, s.beer.?, bd);
    _ = occupancy.attach(g, s.snack.?, bd);
    _ = occupancy.attach(g, s.arrows.?, bd);
    labmap.placeObject(g, bd, -1, -1, s.crossbow.?);
    labmap.placeObject(g, bd, -1, -1, s.enemyA.?);
    labmap.placeObject(g, bd, -1, -1, s.enemyB.?);
    labmap.placeObject(g, bd, -1, -1, s.secondWeapon.?);
    labmap.placeObject(g, bd, -1, -1, s.medkit.?);
    labmap.placeObject(g, bd, -1, -1, s.beer.?);
    labmap.placeObject(g, bd, -1, -1, s.snack.?);
    labmap.placeObject(g, bd, -1, -1, s.arrows.?);
    _ = s.placeObjects(g);

    // The song (phase 1 only), the WaveMix session and the waves.
    _ = g.plat.mciString("open doom.mid type sequencer alias musica");
    _ = g.plat.mciString("play musica notify");
    _ = sound.mixInit(g);
    const w = &g.phase1Waves;
    w[0] = sound.open(g, "busrang2.wav");
    w[1] = sound.open(g, "barang.wav");
    w[2] = sound.open(g, "seio.wav");
    w[3] = sound.open(g, "seio2.wav");
    w[4] = sound.open(g, "esmagar.wav");
    w[5] = sound.open(g, "acai.wav");
    w[6] = sound.open(g, "ARROTO.WAV");
    w[8] = sound.open(g, "arcfle02.wav");
    w[7] = sound.open(g, "barul1.wav");
    w[9] = sound.open(g, "yeeha.wav");
    w[10] = sound.open(g, "abrport2.wav");
    w[11] = sound.open(g, "alivio.wav");
    w[12] = sound.open(g, "barul2.wav");
    w[13] = sound.open(g, "soco.wav");
    w[14] = sound.open(g, "berro.wav");
    s.handlerEnabled = 1;
    bd.active = 1;
    labyrinth.paint(g, bd);
    return s;
}

/// LabyrinthSceneVtbl slot 10 hit (phase1_scene_hit): a shot that stops on an enemy with the right weapon (the bra on Seios, the crossbow on Bussuf) clears that cell and scores.
// @orig 1098:2dd3 phase1_scene_hit
pub fn hit(g: *Game, s: *Scene, obj: ?*Object, col: i16, row: i16) void {
    const bd = bdOf(s);
    if (obj == s.enemyB) {
        if (bd.hands.?.curStrip == 2) {
            cellSlot(bd, row, col).* = null;
            bd.score +%= 100;
            sound.stopAll(g);
        }
    } else if (obj == s.enemyA and bd.hands.?.curStrip == 1) {
        cellSlot(bd, row, col).* = null;
        bd.score +%= 200;
        sound.stopAll(g);
    }
}

fn play(g: *Game, index: usize) void {
    _ = sound.play(g, 0, g.phase1Waves[index]);
}

/// LabyrinthSceneVtbl slot 11 touch (phase1_scene_touch): a pickup is consumed (1 = blocked is only for enemies), an enemy blocks the step and hurts.
// @orig 1098:2823 phase1_scene_touch
pub fn touch(g: *Game, s: *Scene, obj: *Object) i16 {
    const bd = bdOf(s);
    if (obj.isEnemy != 0) {
        if (obj == s.enemyB) {
            bd.lives -%= 1;
        } else if (obj == s.enemyA) {
            bd.health -%= 5;
        }
        return 1;
    }
    // What stays in the player's cell: nothing, unless the pickup is swapped or refused.
    var left: ?*Object = null;
    const waits = g.fixes.jardim_weapon_waits_for_shot and bd.shotInFlight != 0;
    if (obj == s.secondWeapon) {
        if (bd.shotInFlight == 0) {
            if (bd.hands.?.curStrip == 2) {
                bd.ammo +%= 1;
            } else {
                if (bd.hands.?.curStrip == 1) left = s.crossbow;
                bd.hands.?.curStrip = 2;
                bd.hands.?.curFrame = 0;
                bd.shot.?.curFrame = 1;
                bd.ammo = 1;
            }
            play(g, 9);
        } else if (waits) {
            left = obj;
        }
    } else if (obj == s.crossbow) {
        if (bd.shotInFlight == 0) {
            if (bd.hands.?.curStrip == 2) left = s.secondWeapon;
            bd.hands.?.curStrip = 1;
            bd.hands.?.curFrame = 0;
            bd.shot.?.curFrame = 0;
            bd.ammo +%= 6;
        } else if (waits) {
            left = obj;
        }
        // The sound plays even with a shot in flight (J3).
        if (!waits) play(g, 7);
    } else if (obj == s.beer) {
        bd.health -%= 15;
        bd.score +%= 100;
        play(g, 6);
    } else if (obj == s.snack) {
        bd.health +%= 5;
        play(g, 5);
    } else if (obj == s.medkit) {
        bd.health +%= 20;
        play(g, 11);
    } else if (obj == s.arrows) {
        if (bd.hands.?.curStrip == 1) {
            play(g, 12);
            bd.ammo +%= 3;
        } else {
            left = s.arrows;
        }
    }
    cellSlot(bd, bd.playerY >> 5, bd.playerX >> 5).* = left;
    return 0;
}

fn place(g: *Game, bd: *Backdrop, row: i16, col: i16, obj: ?*Object) void {
    labmap.placeObject(g, bd, row, col, obj.?);
}

/// LabyrinthSceneVtbl slot 12 placeObjects (phase1_scene_place_objects): the 72 map copies, 1-based (row, col).
// @orig 1098:0f6e phase1_scene_place_objects
pub fn placeObjects(g: *Game, s: *Scene) *Scene {
    const bd = bdOf(s);
    place(g, bd, 10, 28, s.crossbow);
    place(g, bd, 7, 54, s.crossbow);
    place(g, bd, 10, 33, s.crossbow);
    place(g, bd, 21, 23, s.crossbow);
    place(g, bd, 6, 5, s.crossbow);
    place(g, bd, 12, 50, s.medkit);
    place(g, bd, 38, 50, s.medkit);
    place(g, bd, 54, 13, s.medkit);
    place(g, bd, 72, 33, s.medkit);
    place(g, bd, 14, 54, s.enemyA);
    place(g, bd, 22, 15, s.enemyA);
    place(g, bd, 27, 23, s.enemyA);
    place(g, bd, 29, 26, s.enemyA);
    place(g, bd, 38, 25, s.enemyA);
    place(g, bd, 60, 21, s.enemyA);
    place(g, bd, 67, 2, s.enemyA);
    place(g, bd, 78, 6, s.enemyA);
    place(g, bd, 70, 50, s.enemyA);
    place(g, bd, 72, 30, s.enemyA);
    place(g, bd, 72, 27, s.enemyA);
    place(g, bd, 65, 39, s.enemyA);
    place(g, bd, 65, 28, s.enemyA);
    place(g, bd, 52, 21, s.secondWeapon);
    place(g, bd, 42, 17, s.secondWeapon);
    place(g, bd, 42, 28, s.secondWeapon);
    place(g, bd, 44, 39, s.secondWeapon);
    place(g, bd, 30, 30, s.secondWeapon);
    place(g, bd, 29, 39, s.secondWeapon);
    place(g, bd, 76, 51, s.arrows);
    place(g, bd, 76, 52, s.arrows);
    place(g, bd, 76, 53, s.arrows);
    place(g, bd, 63, 14, s.arrows);
    place(g, bd, 61, 14, s.arrows);
    place(g, bd, 61, 32, s.arrows);
    place(g, bd, 48, 38, s.arrows);
    place(g, bd, 39, 50, s.arrows);
    place(g, bd, 38, 14, s.arrows);
    place(g, bd, 38, 15, s.arrows);
    place(g, bd, 38, 16, s.arrows);
    place(g, bd, 10, 35, s.arrows);
    place(g, bd, 6, 7, s.arrows);
    place(g, bd, 6, 9, s.arrows);
    place(g, bd, 6, 11, s.arrows);
    place(g, bd, 6, 35, s.arrows);
    place(g, bd, 7, 54, s.arrows);
    place(g, bd, 29, 11, s.arrows);
    place(g, bd, 74, 45, s.beer);
    place(g, bd, 72, 39, s.beer);
    place(g, bd, 57, 48, s.beer);
    place(g, bd, 42, 25, s.beer);
    place(g, bd, 29, 50, s.beer);
    place(g, bd, 27, 21, s.beer);
    place(g, bd, 37, 2, s.enemyB);
    place(g, bd, 32, 2, s.enemyB);
    place(g, bd, 37, 30, s.enemyB);
    place(g, bd, 37, 39, s.enemyB);
    place(g, bd, 51, 34, s.enemyB);
    place(g, bd, 11, 13, s.snack);
    place(g, bd, 22, 4, s.snack);
    place(g, bd, 33, 19, s.snack);
    place(g, bd, 33, 20, s.snack);
    place(g, bd, 42, 20, s.snack);
    place(g, bd, 57, 4, s.snack);
    place(g, bd, 55, 9, s.snack);
    place(g, bd, 68, 13, s.snack);
    place(g, bd, 72, 36, s.snack);
    place(g, bd, 67, 25, s.snack);
    place(g, bd, 74, 54, s.snack);
    place(g, bd, 68, 42, s.snack);
    place(g, bd, 23, 50, s.snack);
    place(g, bd, 8, 34, s.snack);
    place(g, bd, 6, 15, s.snack);
    return s;
}

/// LabyrinthSceneVtbl slot 13 playEnemyAttackSound (phase1_scene_play_enemy_attack_sound).
// @orig 1098:2f3c phase1_scene_play_enemy_attack_sound
pub fn playEnemyAttackSound(g: *Game, s: *Scene, obj: *Object) void {
    if (obj == s.enemyB) {
        play(g, 2);
    } else if (obj == s.enemyA) {
        play(g, 0);
    }
}

/// LabyrinthSceneVtbl slot 14 playEnemyStepSound (phase1_scene_play_enemy_step_sound): WaveMixPump first.
// @orig 1098:300b phase1_scene_play_enemy_step_sound
pub fn playEnemyStepSound(g: *Game, s: *Scene, obj: *Object) void {
    sound.pump(g);
    if (obj == s.enemyB) {
        play(g, 3);
    } else if (obj == s.enemyA) {
        play(g, 1);
    }
}

/// LabyrinthSceneVtbl slot 15 playFireSound (phase1_scene_play_fire_sound): the fists punch, the other weapons shoot.
// @orig 1098:30df phase1_scene_play_fire_sound
pub fn playFireSound(g: *Game, s: *Scene) void {
    if (bdOf(s).hands.?.curStrip == 0) {
        play(g, 13);
    } else {
        play(g, 8);
    }
}

/// LabyrinthSceneVtbl slot 16 playDoorSound (phase1_scene_play_door_sound).
// @orig 1098:3131 phase1_scene_play_door_sound
pub fn playDoorSound(g: *Game, s: *Scene) void {
    _ = s;
    play(g, 10);
}

/// LabyrinthSceneVtbl slot 17 onLifeLost (phase1_scene_on_life_lost; hwnd dropped): `berro` with a notify window.
// @orig 1098:2f13 phase1_scene_on_life_lost
pub fn onLifeLost(g: *Game, s: *Scene) void {
    _ = s;
    _ = sound.play(g, g.mainWindow, g.phase1Waves[14]);
}
