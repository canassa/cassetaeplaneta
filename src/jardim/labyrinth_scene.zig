//! Port unit `labyrinth_scene` (module) of JARDIM.EXE. LabyrinthScene: ctor, create, its handler (the 0x402 carry to the next phase), the respawn (slot 17); the three phase ctors (each sets its phase's vtable) and createScreen (the LabyrinthBackdrop on opcaoN.bmp).
//!
//! The phase units import this one (their vtables name `createScreenN`) and
//! `ctor` imports theirs for the vtable constants: a Zig import cycle, not a
//! call cycle (nothing here runs a phase function at compile time).

const std = @import("std");
const msg = @import("../core/msg.zig");
const Msg = msg.Msg;
const Game = @import("core/game.zig").Game;
const world = @import("core/world.zig");
const Backdrop = world.Backdrop;
const Scene = world.Scene;
const scene = @import("scene.zig");
const labyrinth = @import("labyrinth.zig");
const labyrinth_input = @import("labyrinth_input.zig");
const sound = @import("sound.zig");
const phase1 = @import("phase1.zig");
const phase2 = @import("phase2.zig");
const phase3 = @import("phase3.zig");
const enemies = @import("enemies.zig");

/// The three phase ctors in one: `phaseN_scene_ctor` = `labyrinth_scene_ctor`
/// (`scene_ctor`, backdrop null, map file the empty string at 10c0:7b76) and the
/// phase's vtable (834c, 91aa, 92da). The original's callers pass 480 x 640 and
/// flags 0 1 0 (status bar, control panel, player); `new` is `g.local()`.
// @orig 10c0:7076 phase1_scene_ctor
// @orig 10c0:8afc phase2_scene_ctor
// @orig 10c0:920a phase3_scene_ctor
// @orig 10c0:7462 labyrinth_scene_ctor
pub fn ctor(g: *Game, phase: world.Phase, name: []const u8) !*Scene {
    const vt: *const world.SceneVtbl = switch (phase) {
        .one => &phase1.vtbl,
        .two => &phase2.vtbl,
        .three => &phase3.vtbl,
    };
    const s = try g.local().create(Scene);
    s.* = .{ .phase = phase, .vtbl = vt };
    _ = scene.ctor(s, 0, 1, 0, name);
    s.backdrop = null;
    s.mapFile = "";
    return s;
}

/// LabyrinthScene slot 00 handleMessage (hwnd dropped): forwards to the backdrop
/// (result ignored); 0x402 carries the state to the next phase. Returns 0 (the
/// engine default runs) for 1, 2, 0xf, 0x10, 0x1c, 0x111, 0x30f, 0x311, 0x402;
/// 1 for the rest.
// @orig 1028:5dba labyrinth_scene_handle_message
pub fn handleMessage(g: *Game, s: *Scene, m: Msg) u16 {
    const bd = s.backdrop.?;
    _ = labyrinth_input.handleMessage(g, bd, m);
    switch (m.id) {
        0x111, 0x30f, 0x311 => return 0,
        0x402 => {
            g.carryHealth = bd.health;
            g.carryLives = bd.lives;
            g.carryAmmo = bd.ammo;
            g.carryScore = bd.score +% 500;
            g.carryLevel = bd.level +% 1;
            g.handsBobPos = 0;
            g.handsBobStep = 2;
            sound.stopAll(g);
            sound.freeAll(g);
            if (g.carryLevel == 2 and bd.hands.?.curStrip == 2) {
                g.curWeapon = 0;
            } else {
                g.curWeapon = bd.hands.?.curStrip;
            }
            return 0;
        },
        else => {},
    }
    if (m.id == 0) return 1;
    if (m.id < 0x112) {
        if (m.id == 1 or m.id == 2) return 0;
        if (m.id -% 2 < 0xd) return 1;
        if (m.id == 0xf or m.id == 0x10 or m.id == 0x1c) return 0;
    }
    return 1;
}

/// LabyrinthScene slot 07 create (hwnd dropped): `scene_create`, then the
/// backdrop's setVanishPoint(0x66, 0x202), setView(0, 0x1c7, 0, 300, 0xa0) and
/// setAxis(0x159, 0), which are the Backdrop defaults (they return `this`).
// @orig 10c0:74ea labyrinth_scene_create
pub fn create(g: *Game, s: *Scene) *Scene {
    _ = scene.create(g, s);
    return s;
}

/// LabyrinthScene slot 17 (hwnd dropped; the platform's DC): every object back
/// (slot 12), the fists, the start position, score -500 (undoing the carry's
/// +500), repaint and blit. Health and lives are not touched.
// @orig 1028:5ef1 labyrinth_scene_respawn
pub fn respawn(g: *Game, s: *Scene) void {
    // Not in the original: the fair enemies are rebuilt (all of them, the killed too).
    enemies.beforeRespawn(g, s.backdrop.?);
    _ = s.placeObjects(g);
    const bd = s.backdrop.?;
    enemies.afterRespawn(g, bd);
    bd.hands.?.curStrip = 0;
    bd.hands.?.curFrame = 0;
    bd.ammo = 0;
    bd.playerX = bd.startX;
    bd.playerY = bd.startY;
    bd.score -%= 500;
    labyrinth.paint(g, bd);
    labyrinth.blitToDc(g, bd);
}

/// The phases' createScreen: `new LabyrinthBackdrop` (0x73c) on `bmp`, stored at
/// scene +0x62 with its scene back-pointer.
fn createScreen(g: *Game, s: *Scene, bmp: []const u8) ?*Backdrop {
    const bd = g.local().create(Backdrop) catch std.debug.panic("jardim labyrinth_scene: out of memory for the backdrop", .{});
    bd.* = .{};
    _ = labyrinth.ctor(g, bd, bmp);
    s.backdrop = bd;
    bd.scene = s;
    return s.backdrop;
}

/// LabyrinthSceneVtbl slot 05 createScreen of Phase1Scene (opcao1.bmp).
// @orig 10c0:7630 phase1_scene_create_screen
pub fn createScreen1(g: *Game, s: *Scene) ?*Backdrop {
    return createScreen(g, s, "opcao1.bmp");
}

/// LabyrinthSceneVtbl slot 05 createScreen of Phase2Scene (opcao2.bmp).
// @orig 10c0:8cb0 phase2_scene_create_screen
pub fn createScreen2(g: *Game, s: *Scene) ?*Backdrop {
    return createScreen(g, s, "opcao2.bmp");
}

/// LabyrinthSceneVtbl slot 05 createScreen of Phase3Scene (opcao3.bmp).
// @orig 10c0:925a phase3_scene_create_screen
pub fn createScreen3(g: *Game, s: *Scene) ?*Backdrop {
    return createScreen(g, s, "opcao3.bmp");
}
