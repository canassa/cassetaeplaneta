//! Port unit `tetris` (module) of ENCAIXE.EXE. TetrisScene: its handler (keys, gravity, landing, music, WM_DESTROY and 0x40a), create (MCI, WaveMix, the score), createScreen.
//!
//! The handler sees every window message first (non-zero = handled).
//! hwnd parameters are dropped; the GetDC/ReleaseDC pairs have no
//! counterpart. kind/rotation passed to the piece code are the piece's
//! curStrip/curFrame.

const std = @import("std");
const msg = @import("../core/msg.zig");
const Msg = msg.Msg;
const Game = @import("core/game.zig").Game;
const object = @import("core/object.zig");
const Object = object.Object;
const world = @import("core/world.zig");
const Backdrop = world.Backdrop;
const Scene = world.Scene;
const platform = @import("../platform/platform.zig");
const dib = @import("dib.zig");
const lists = @import("lists.zig");
const piece = @import("piece.zig");
const scene_unit = @import("scene.zig");
const sound = @import("sound.zig");
const animation = @import("behaviour/animation.zig");
const movement = @import("behaviour/movement.zig");
const render = @import("behaviour/render.zig");

const VK_LEFT: u16 = 0x25;
const VK_UP: u16 = 0x26;
const VK_RIGHT: u16 = 0x27;
const VK_DOWN: u16 = 0x28;

/// The scene's backdrop (the original dereferences it unchecked).
fn bdOf(scene: *Scene) *Backdrop {
    return scene.backdrop orelse @panic("encaixe.tetris: no backdrop");
}

/// The piece starts falling again: direction 8, move to the bottom edge,
/// `moving` = 1 (the tail shared by the key-up and the gravity tick).
fn resumeFall(g: *Game, p: *Object, bd: *Backdrop) void {
    p.mover.direction = 8;
    movement.moveToEdgeV(g, p, bd, 8);
    p.mover.moving = 1;
}

/// The step after a sideways key: te_piece_step_move with the piece's
/// current strip (kind) and frame (rotation).
fn stepMove(g: *Game, p: *Object, bd: *Backdrop) void {
    piece.moveTick(g, p, bd, p.curStrip, p.curFrame);
}

/// SceneVtbl slot 00 handleMessage (te_scene_handle_message): non-zero = handled.
// @orig 1008:f2a2 te_scene_handle_message
pub fn handleMessage(g: *Game, scene: *Scene, m: Msg) i16 {
    switch (m.id) {
        msg.wm.destroy => {
            sound.stopAll(g);
            sound.freeAll(g);
            sound.mixClose(g);
            _ = g.plat.mciString("close musica");
            // -1000 for a loss (wParam 0), +500 always.
            const loss: i16 = if (m.wparam == 0) -1000 else 0;
            g.score +%= loss +% 500;
            _ = g.plat.postTo(g.noiteWnd, .{ .id = msg.noite.minigame_result, .wparam = m.wparam, .lparam = g.score });
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
        msg.wm.keydown => return keyDown(g, scene, m.wparam),
        msg.wm.keyup => {
            const p = g.piece.?;
            switch (m.wparam) {
                VK_LEFT => g.pieceKeyLeft = 0,
                VK_UP => return 1,
                VK_RIGHT => g.pieceKeyRight = 0,
                VK_DOWN => {
                    g.pieceKeyDown = 0;
                    return 1;
                },
                else => return 1,
            }
            resumeFall(g, p, bdOf(scene));
            return 1;
        },
        msg.wm.systimer => return gravity(g, scene, m.wparam),
        msg.wm.mm_mcinotify => {
            if (m.wparam == 1) {
                _ = g.plat.mciString("play musica from 0 notify");
                return 0;
            }
            return 1;
        },
        // Mouse and the WaveMix end are swallowed (0x203 is not).
        msg.wm.mousemove,
        msg.wm.lbuttondown,
        msg.wm.lbuttonup,
        msg.wm.rbuttondown,
        msg.wm.rbuttonup,
        msg.wm.mm_wom_done,
        => return 1,
        else => return 0,
    }
}

fn keyDown(g: *Game, scene: *Scene, key: u16) i16 {
    const p = g.piece.?;
    const bd = bdOf(scene);
    switch (key) {
        VK_LEFT => {
            g.pieceKeyLeft = 1;
            movement.stopMovingDc(g, p, bd);
            p.mover.direction = 1;
            if (p.piece.column >= 0) p.mover.targetX +%= 0x20;
            movement.moveToEdgeH(g, p, bd, 1);
            stepMove(g, p, bd);
            return 1;
        },
        VK_UP => {
            if (animation.isRunning(g, p)) return 1;
            g.pieceKeyUp = 1;
            p.mover.direction = 4;
            if (piece.tryStep(g, p, bd, p.curStrip, p.curFrame) == 0) return 1;
            animation.play(g, p, bd);
            return 1;
        },
        VK_RIGHT => {
            g.pieceKeyRight = 1;
            piece.calcRightCol(g, p, p.curStrip, p.curFrame);
            movement.stopMovingDc(g, p, bd);
            p.mover.direction = 2;
            if (p.piece.rightCol > 10) return 1;
            p.mover.targetX -%= 0x20;
            movement.moveToEdgeH(g, p, bd, 2);
            stepMove(g, p, bd);
            return 1;
        },
        VK_DOWN => {
            if (g.pieceKeyDown == 0) {
                // E5: the original sets the left-key flag, so the guard
                // never closes (a key repeat restarts the 55 ms timer).
                if (g.fixes.encaixe_down_key_guard) g.pieceKeyDown = 1 else g.pieceKeyLeft = 1;
                g.setSystemTimer(@bitCast(p.anim.timerId), 0x37);
            }
            return 1;
        },
        else => return 0,
    }
}

/// WM_SYSTIMER: the gravity tick for the piece's timer.
fn gravity(g: *Game, scene: *Scene, timer: u16) i16 {
    const p = g.piece.?;
    const bd = bdOf(scene);
    const id: u16 = @bitCast(animation.getTimerId(g, p));
    if (id != timer) return 1;
    if (!animation.isRunning(g, p)) {
        stepMove(g, p, bd);
        if (p.mover.moving != 0) return 1;
        if (p.piece.canFall == 0) {
            render.unk18(g, p, bd);
            piece.onLanded(g, p, bd, p.curStrip, p.curFrame);
            return 1;
        }
    } else {
        // A rotation animation was running: finish it.
        animation.tick(g, p, bd);
        animation.stop(g, p);
    }
    resumeFall(g, p, bd);
    return 1;
}

/// SceneVtbl slot 05 createScreen (te_scene_create_screen).
// @orig 1008:a7d4 te_scene_create_screen
pub fn createScreen(g: *Game, scene: *Scene) ?*Backdrop {
    _ = scene;
    const bd = g.gpa.create(Backdrop) catch return null;
    bd.* = .{};
    bd.background = dib.loadDib(g.gpa, g.plat, g.fixes, "tetrfun.bmp");
    if (bd.background == null) {
        // The caption and format are swapped in the original: the box shows
        // the file name. It then reads the missing header (taken as 0).
        lists.messageBoxPrintf(g, "N\xe3o foi poss\xedvel abrir o arquivo: %s", "tetrfun.bmp", 0x23c);
    }
    if (bd.background) |bg| {
        bd.bgWidth = @truncate(bg.header.biWidth);
        bd.bgHeight = @truncate(bg.header.biHeight);
    }
    bd.originX = 0;
    bd.originY = 0;
    bd.viewWidth = 0x280;
    bd.viewHeight = 0x1e0;
    bd.sceneList = null;
    return bd;
}

/// SceneVtbl slot 07 create (te_scene_create; hwnd dropped).
// @orig 1008:b6f6 te_scene_create
pub fn create(g: *Game, scene: *Scene) ?*Scene {
    _ = scene_unit.create(g, scene);
    _ = g.plat.mciString("open doom2.mid type sequencer alias musica");
    _ = g.plat.mciString("play musica notify");
    _ = sound.mixInit(g);
    g.tetrisWave = sound.open(g, "tetris2.wav");
    const bd = bdOf(scene);
    piece.drawScore(g, bd);
    piece.blitScoreBox(g, bd);
    return scene;
}

test "tetris unit compiles" {
    std.testing.refAllDecls(@This());
}
