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
const tall = @import("tall.zig");
const piece_vertical = @import("piece_vertical.zig");
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

/// Lock delay (`Fixes.encaixe_lock_delay`, docs/encaixe/GAME.md): how long a
/// resting piece may still move, and how many moves or rotations restart it.
const lock_ms: u32 = 500;
const lock_max_resets: u8 = 15;

/// The rotation whose cells the board holds now: a rotation reaches `curFrame`
/// one tick later, when the sprite animation advances.
fn boardRotation(g: *Game, p: *Object) i16 {
    return if (animation.isRunning(g, p)) @rem(p.curFrame + 1, 4) else p.curFrame;
}

fn resting(g: *Game, p: *Object) bool {
    if (g.fixes.encaixe_tall_board) return tall.resting(&g.tall, p);
    return piece_vertical.restsOn(p, p.curStrip, boardRotation(g, p));
}

/// The delay has not run out: `now` is before the deadline (wrapping ticks).
fn lockPending(g: *Game) bool {
    return @as(i32, @bitCast(g.lockDeadline -% g.plat.ticks())) > 0;
}

/// Arms the piece's timer for the delay left, so the tick that lands the
/// piece comes when the delay is over and not up to one gravity period later.
fn lockArmTimer(g: *Game, p: *Object) void {
    const left: i32 = @bitCast(g.lockDeadline -% g.plat.ticks());
    g.setSystemTimer(@bitCast(p.anim.timerId), @intCast(std.math.clamp(left, 1, lock_ms)));
}

/// After a gravity tick that left the piece falling (or after the rotation
/// animation): a piece that came to rest starts the delay, one that does not
/// rest anymore ends it.
fn lockSettle(g: *Game, p: *Object) void {
    if (!g.fixes.encaixe_lock_delay) return;
    if (!resting(g, p)) {
        g.lockActive = false;
        return;
    }
    if (!g.lockActive) {
        g.lockActive = true;
        g.lockDeadline = g.plat.ticks() +% lock_ms;
    }
    lockArmTimer(g, p);
}

/// After a successful sideways step or rotation: while the delay runs, the
/// move restarts it (at most `lock_max_resets` times a piece); if the piece
/// can fall again the delay ends (the resets are not given back).
fn lockMoved(g: *Game, p: *Object) void {
    if (!g.fixes.encaixe_lock_delay or !g.lockActive) return;
    if (!resting(g, p)) {
        g.lockActive = false;
        return;
    }
    if (g.lockResets < lock_max_resets) {
        g.lockResets += 1;
        g.lockDeadline = g.plat.ticks() +% lock_ms;
    }
}

/// A gravity tick found the down step blocked: true when the piece waits
/// (the delay starts here if no earlier tick or move started it).
fn lockDefers(g: *Game) bool {
    if (!g.fixes.encaixe_lock_delay or g.lockResets >= lock_max_resets) return false;
    if (!g.lockActive) {
        g.lockActive = true;
        g.lockDeadline = g.plat.ticks() +% lock_ms;
        return true;
    }
    return lockPending(g);
}

/// `stepMove` for a sideways key or tick: a step that moved the piece is a
/// move for the lock delay.
fn stepMoveLocked(g: *Game, p: *Object, bd: *Backdrop) void {
    const column = p.piece.column;
    stepMove(g, p, bd);
    if (p.piece.column != column) lockMoved(g, p);
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
            movement.moverStopMoving(g, p, bd);
            p.mover.direction = 1;
            if (p.piece.column >= 0) p.mover.targetX +%= piece.cellPx(g);
            movement.moveToEdgeH(g, p, bd, 1);
            stepMoveLocked(g, p, bd);
            return 1;
        },
        VK_UP => {
            if (animation.isRunning(g, p)) return 1;
            g.pieceKeyUp = 1;
            p.mover.direction = 4;
            const column = p.piece.column;
            const row = p.piece.row;
            if (piece.tryStep(g, p, bd, p.curStrip, p.curFrame) == 0) return 1;
            // A kicked rotation: the sprite follows the new cell.
            if (g.fixes.encaixe_tall_board and (p.piece.column != column or p.piece.row != row)) {
                movement.placeAt(g, p, tall.pixelX(p.piece.column), tall.pixelY(p.piece.row), bd);
            }
            animation.play(g, p, bd);
            lockMoved(g, p);
            return 1;
        },
        VK_RIGHT => {
            g.pieceKeyRight = 1;
            piece.calcRightCol(g, p, p.curStrip, p.curFrame);
            movement.moverStopMoving(g, p, bd);
            p.mover.direction = 2;
            if (!g.fixes.encaixe_tall_board and p.piece.rightCol > 10) return 1;
            p.mover.targetX -%= piece.cellPx(g);
            movement.moveToEdgeH(g, p, bd, 2);
            stepMoveLocked(g, p, bd);
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
        stepMoveLocked(g, p, bd);
        if (p.mover.moving != 0) {
            // Fell one row (a sideways step was a move above).
            if (p.mover.direction == 8) lockSettle(g, p);
            return 1;
        }
        if (p.piece.canFall == 0) {
            if (lockDefers(g)) {
                // Still resting: the piece may move. `canFall` is only the
                // blocked step's result; a blocked sideways step needs 1.
                p.piece.canFall = 1;
                resumeFall(g, p, bd);
                lockArmTimer(g, p);
                return 1;
            }
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
    lockSettle(g, p);
    return 1;
}

/// SceneVtbl slot 05 createScreen (te_scene_create_screen).
// @orig 1008:a7d4 te_scene_create_screen
pub fn createScreen(g: *Game, scene: *Scene) ?*Backdrop {
    _ = scene;
    const bd = g.gpa.create(Backdrop) catch return null;
    bd.* = .{};
    bd.background = dib.loadDib(g.gpa, g.plat, g.fixes, "tetrfun.bmp");
    if (g.fixes.encaixe_tall_board) {
        if (bd.background) |bg| tall.paintBackground(&g.tall, bg);
    }
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
    piece.drawNext(g, bd);
    return scene;
}

test "tetris unit compiles" {
    std.testing.refAllDecls(@This());
}

const TestGame = @import("core/game.zig").TestGame;

/// An O piece (2 x 2) at `column`, top row `row`, with the cell below its
/// left column full when `ledge` (so it rests there, else it falls).
fn lockPiece(obj: *Object, column: i16, row: i16, ledge: bool) void {
    obj.piece.board = @splat(@splat('0'));
    obj.curStrip = 5;
    obj.curFrame = 0;
    obj.piece.column = column;
    obj.piece.row = row;
    if (ledge) obj.piece.cell(column, row + 2).* = '1';
}

test "lock delay: a resting piece waits 500 ms, then is landed" {
    var t = try TestGame.init(std.testing.allocator);
    defer t.deinit();
    const g = t.game;
    g.fixes.encaixe_lock_delay = true;
    var obj: Object = .{ .kind = .piece };
    lockPiece(&obj, 4, 10, true);
    t.headless.now = 1000;
    // It touched down: the delay starts and the timer is armed for 500 ms.
    lockSettle(g, &obj);
    try std.testing.expect(g.lockActive);
    try std.testing.expectEqual(@as(u32, 1500), g.lockDeadline);
    // The gravity ticks before the end wait, the one at 500 ms lands it.
    t.headless.now = 1200;
    try std.testing.expect(lockDefers(g));
    t.headless.now = 1499;
    try std.testing.expect(lockDefers(g));
    t.headless.now = 1500;
    try std.testing.expect(!lockDefers(g));
    // Without the fix the first blocked tick lands.
    g.fixes.encaixe_lock_delay = false;
    try std.testing.expect(!lockDefers(g));
}

test "lock delay: a move or rotation while resting restarts the 500 ms" {
    var t = try TestGame.init(std.testing.allocator);
    defer t.deinit();
    const g = t.game;
    g.fixes.encaixe_lock_delay = true;
    var obj: Object = .{ .kind = .piece };
    lockPiece(&obj, 4, 12, false);
    t.headless.now = 0;
    lockSettle(g, &obj);
    t.headless.now = 400;
    lockMoved(g, &obj);
    try std.testing.expectEqual(@as(u32, 900), g.lockDeadline);
    try std.testing.expectEqual(@as(u8, 1), g.lockResets);
    t.headless.now = 899;
    try std.testing.expect(lockDefers(g));
    t.headless.now = 900;
    try std.testing.expect(!lockDefers(g));
}

test "lock delay: 15 resets a piece, then the next blocked step lands it" {
    var t = try TestGame.init(std.testing.allocator);
    defer t.deinit();
    const g = t.game;
    g.fixes.encaixe_lock_delay = true;
    var obj: Object = .{ .kind = .piece };
    lockPiece(&obj, 4, 12, false);
    t.headless.now = 0;
    lockSettle(g, &obj);
    for (0..20) |_| {
        t.headless.now += 100;
        lockMoved(g, &obj);
    }
    try std.testing.expectEqual(@as(u8, 15), g.lockResets);
    // The 16th..20th moves restarted nothing: the deadline is the 15th's.
    try std.testing.expectEqual(@as(u32, 1500 + 500), g.lockDeadline);
    t.headless.now = 1600;
    try std.testing.expect(!lockDefers(g));
    // A new piece starts again from 0 (te_piece_on_landed).
}

test "lock delay: moved off a ledge the piece falls and the delay stops" {
    var t = try TestGame.init(std.testing.allocator);
    defer t.deinit();
    const g = t.game;
    g.fixes.encaixe_lock_delay = true;
    var obj: Object = .{ .kind = .piece };
    lockPiece(&obj, 4, 10, true);
    t.headless.now = 0;
    lockSettle(g, &obj);
    lockMoved(g, &obj);
    try std.testing.expectEqual(@as(u8, 1), g.lockResets);
    // One column right: nothing under it.
    obj.piece.column = 6;
    lockMoved(g, &obj);
    try std.testing.expect(!g.lockActive);
    // The resets are kept; touching down again starts a fresh 500 ms.
    try std.testing.expectEqual(@as(u8, 1), g.lockResets);
    obj.piece.column = 4;
    obj.piece.row = 10;
    t.headless.now = 700;
    try std.testing.expect(lockDefers(g));
    try std.testing.expectEqual(@as(u32, 1200), g.lockDeadline);
}
