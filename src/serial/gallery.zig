//! Port unit `gallery` (module) of SERIAL.EXE. SerialScene: its handler (12.9 KB: keys, the seven timer tests, the spawns, the second hit stage, the clock, WM_DESTROY and 0x40a; BUGS.md K1-K6), create (MCI, WaveMix, the score), createScreen.
//!
//! The handler sees every window message first (non-zero = handled) and
//! answers every key, timer and mouse message itself. hwnd parameters are
//! dropped; the GetDC/ReleaseDC pairs have no counterpart (the DC is the
//! platform screen). Where the original reads an object through the virtual
//! base, the flattened `Object` is the SceneObject view. BUGS.md K1-K6 are
//! reproduced as the code does them; each fix is behind its
//! `g.fixes.serial_*` flag (docs/serial/DESIGN.md "Fixes").

const msg = @import("../core/msg.zig");
const Msg = msg.Msg;
const platform = @import("../platform/platform.zig");
const Game = @import("core/game.zig").Game;
const Object = @import("core/object.zig").Object;
const world = @import("core/world.zig");
const Backdrop = world.Backdrop;
const Scene = world.Scene;
const backdrop = @import("backdrop.zig");
const bullet = @import("bullet.zig");
const lists = @import("lists.zig");
const scene_unit = @import("scene.zig");
const sound = @import("sound.zig");
const target = @import("target.zig");
const animation = @import("behaviour/animation.zig");
const movement = @import("behaviour/movement.zig");
const render = @import("behaviour/render.zig");
const visibility = @import("behaviour/visibility.zig");

const VK_SPACE: u16 = 0x20;
const VK_LEFT: u16 = 0x25;
const VK_RIGHT: u16 = 0x27;

/// The scene's backdrop (the original dereferences it unchecked).
fn bdOf(scene: *Scene) *Backdrop {
    return scene.backdrop orelse @panic("serial.gallery: no backdrop");
}

fn targetAt(g: *Game, i: usize) *Object {
    return g.targets[i].?;
}

/// SceneVtbl slot 00 handleMessage (serial_scene_handle_message): non-zero = handled.
// @orig 1068:1529 serial_scene_handle_message
pub fn handleMessage(g: *Game, scene: *Scene, m: Msg) i16 {
    switch (m.id) {
        // The end: the waves and the music go, then the result goes to NOITE:
        // wParam = SERIAL's own window (never 0: K1), lParam = MAKELONG(lives,
        // lives > 0 ? 500 : score) (K2). Returns 0, so the window procedure
        // goes on (kills timer 1, posts WM_QUIT).
        msg.wm.destroy => {
            sound.stopAll(g);
            sound.freeAll(g);
            sound.mixClose(g);
            _ = g.plat.mciString("close musica");
            // K6: a close is a game survived while a life is left.
            const hi: i16 = if (g.lives < 1 or g.closing) g.score else 500;
            var wparam: u16 = g.mainWindow;
            if (g.fixes.serial_result_won_by_lives) wparam = @intFromBool(g.lives > 0);
            if (g.closing) wparam = 0;
            var out = Msg.make(msg.noite.minigame_result, wparam, @bitCast(g.lives), @bitCast(hi));
            if (g.fixes.serial_score_in_low_word) out.lparam = hi;
            _ = g.plat.postTo(g.noiteWnd, out);
            return 0;
        },
        // Not a case of the original (it returns 0, then DefWindowProc
        // destroys the window): K6's fix notes the close for WM_DESTROY.
        msg.wm.close => {
            if (g.fixes.serial_close_forfeits) g.closing = true;
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
                    aimKey(g, scene, 'E');
                },
                VK_RIGHT => if (g.keyRightHeld == 0) {
                    g.keyRightHeld = 1;
                    aimKey(g, scene, 'D');
                },
                else => {},
            }
            return 1;
        },
        msg.wm.keyup => {
            switch (m.wparam) {
                VK_SPACE => g.keySpaceHeld = 0,
                VK_LEFT => g.keyLeftHeld = 0,
                VK_RIGHT => g.keyRightHeld = 0,
                else => {},
            }
            return 1;
        },
        msg.wm.systimer => return sysTimer(g, scene, m.wparam),
        // The music loops (every MM_MCINOTIFY is handled).
        msg.wm.mm_mcinotify => {
            if (m.wparam == 1) _ = g.plat.mciString("play musica from 0 notify");
            return 1;
        },
        // 0x3bd (wave done): handled, nothing else (TIRO stops the waves).
        msg.wm.mm_wom_done => return 1,
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

/// LEFT / RIGHT: `gun_aim` ('E' / 'D'), then the gun's play slot (re-arms its
/// 60 ms timer; the redraw comes from that timer).
fn aimKey(g: *Game, scene: *Scene, key: i16) void {
    bullet.aim(g, key);
    animation.play(g, g.gun.?, bdOf(scene));
}

/// The gun's picture is redrawn where it stands: `mover_place_at` at its own
/// x, y, then `blitToDc`.
fn redrawGun(g: *Game, bd: *Backdrop) void {
    const gun = g.gun.?;
    movement.placeAt(g, gun, gun.x, gun.y, bd);
    visibility.blitToDc(g, gun, bd);
}

/// The bullet is placed at (x, y) with picture `aim` (curStrip is not reset)
/// and sent to (dest_x, 10).
fn launch(g: *Game, bd: *Backdrop, x: i16, y: i16, aim: i16, dest_x: i16) void {
    const b = g.bullets[0].?;
    b.x = x;
    b.y = y;
    b.curFrame = aim;
    movement.moveTo(g, b, dest_x, 10, bd);
}

/// WM_KEYDOWN VK_SPACE.
///
/// The original: when `g_keySpaceHeld` is 0 (it always is: nothing sets it,
/// K4) the gun's `lives` counter drops by one FIRST (nothing reads it), and
/// only then, if the one bullet is not flying, does the shot happen.
fn keySpace(g: *Game, scene: *Scene) void {
    if (g.keySpaceHeld != 0) return;
    // K4: the latch is set (as LEFT/RIGHT's); WM_KEYUP clears it.
    if (g.fixes.serial_space_latch) g.keySpaceHeld = 1;
    const gun = g.gun.?;
    gun.player2d.lives -%= 1;
    if (g.bullets[0].?.mover.moving != 0) return;
    const bd = bdOf(scene);
    bullet.playShotWave(g);
    switch (gun.curFrame) {
        2 => launch(g, bd, gun.x +% 0xa2, gun.y -% 0x14, 2, 0x280),
        1 => launch(g, bd, gun.x +% 0x61, gun.y -% 0x1e, 1, 0x145),
        0 => launch(g, bd, gun.x +% 0x2a, gun.y -% 0x1e, 0, 0),
        else => {},
    }
    redrawGun(g, bd);
}

/// WM_SYSTIMER: `wParam` is the timer id, tried against the gun, the walk
/// timers of figures 0 and 13, the spawn timer, the (dead, K5) lane 2 timer,
/// the bullet and the clock in that order; then the common tail. Always
/// handled.
fn sysTimer(g: *Game, scene: *Scene, timer: u16) i16 {
    const bd = bdOf(scene);
    const gun = g.gun.?;
    if (@as(u16, @bitCast(animation.getTimerId(g, gun))) == timer) {
        animation.tick(g, gun, bd);
    } else if (@as(u16, @bitCast(animation.getTimerId(g, targetAt(g, 0)))) == timer) {
        for (0..13) |i| walk(g, bd, i);
    } else if (@as(u16, @bitCast(animation.getTimerId(g, targetAt(g, 13)))) == timer) {
        walk(g, bd, 13);
        walk(g, bd, 14);
    } else if (@as(u16, @bitCast(targetAt(g, 0).target.timerId2)) == timer) {
        spawnTick(g, bd);
    } else if (@as(u16, @bitCast(targetAt(g, 13).target.timerId13)) == timer) {
        // K5: dead while the gun shares this id.
        spawnLane2(g, bd);
    } else if (@as(u16, @bitCast(animation.getTimerId(g, g.bullets[0].?))) == timer) {
        bulletTick(g, bd);
    } else if (@as(u16, @truncate(@as(u32, @bitCast(targetAt(g, 0).target.clockTimerId)))) == timer) {
        // The clock: the first tick counts, the second (120 s) ends the game.
        const t0 = targetAt(g, 0);
        if (t0.target.clockTicks < 1) {
            t0.target.clockTicks +%= 1;
        } else {
            _ = g.send(.{ .id = msg.wm.destroy });
        }
    } else {
        if (scene_unit.getHasControlPanel(g, g.scene.?)) {
            render.draw(g, g.controlPanel.?, bdOf(g.scene.?));
        }
    }
    // The common tail.
    if (scene_unit.getHasStatusBar(g, g.scene.?)) {
        render.draw(g, g.statusBar.?, bdOf(g.scene.?));
    }
    if (!lists.updateIsEmpty(&g.updateList)) {
        lists.updateFlush(g, &g.updateList, bdOf(g.scene.?));
    }
    return 1;
}

/// One walk tick of figure `i`: when it moves, its edge test (the Target
/// vtable's checkEdge; it ends in a `moveTick`).
fn walk(g: *Game, bd: *Backdrop, i: usize) void {
    const t = targetAt(g, i);
    if (movement.isMoving(g, t)) target.checkEdge(g, t, bd, @intCast(i));
}

/// `x`, `y` as the figure's position and as its `mover` target and `next`
/// position (the original stores them in this order).
fn setPos(t: *Object, x: i16, y: i16) void {
    t.x = x;
    t.mover.targetX = t.x;
    t.nextX = t.mover.targetX;
    t.y = y;
    t.mover.targetY = t.y;
    t.nextY = t.mover.targetY;
}

/// The shared tail of a spawn: the figure is placed at (x, y), drawn and
/// shown, set walking in `dir`, sent to the edge, and its position stored again.
fn place(g: *Game, bd: *Backdrop, t: *Object, x: i16, y: i16, dir: i16) void {
    movement.placeAt(g, t, x, y, bd);
    visibility.blitToDc(g, t, bd);
    visibility.show(g, t, bd);
    t.mover.direction = dir;
    t.mover.moving = 1;
    movement.moveToEdgeH(g, t, bd, dir);
}

/// The spawn timer (timer id 7, every 5 s): lane 0, lane 1, then lane 2 on
/// every second tick.
fn spawnTick(g: *Game, bd: *Backdrop) void {
    const t0 = targetAt(g, 0);
    // Lane 0: figure rand() % 7, from x 20, y 1, to the right. No edge test.
    if (t0.target.laneBusy[0] == 0) {
        const i: usize = @intCast(@rem(g.rand.rand(), 7));
        const t = targetAt(g, i);
        t.curStrip = 0;
        t.curFrame = 0;
        t0.target.laneBusy[0] = 1;
        setPos(t, 0x14, 1);
        place(g, bd, t, 0x14, 1, 2);
        setPos(t, 0x14, 1);
    }
    // Lane 1: figure 7 + rand() % 6, from the right edge, y 45, to the left,
    // then one edge test.
    if (t0.target.laneBusy[1] == 0) {
        const i: usize = @intCast(@rem(g.rand.rand(), 6) + 7);
        const t = targetAt(g, i);
        const x = bd.bgWidth -% g.targetStripWidths[i];
        t.curStrip = 0;
        t.curFrame = 0;
        t0.target.laneBusy[1] = 1;
        setPos(t, x, 0x2d);
        place(g, bd, t, t.nextX, 0x2d, 1);
        setPos(t, bd.bgWidth -% g.targetStripWidths[i], 0x2d);
        target.checkEdge(g, t, bd, @intCast(i));
    }
    // Lane 2: every second tick.
    if (g.spawnToggle == 0) {
        g.spawnToggle = 1;
    } else {
        g.spawnToggle = 0;
        spawnLane2(g, bd);
    }
}

/// Lane 2: figure 13 (from x 20, to the right) or 14 (from the right edge,
/// to the left), y 190, when the lane is free. The figure's picture is reset
/// before the lane is tested (the original does).
fn spawnLane2(g: *Game, bd: *Backdrop) void {
    var x: i16 = undefined;
    var dir: i16 = undefined;
    var i: usize = undefined;
    if (@rem(g.rand.rand(), 2) == 0) {
        x = 0x14;
        dir = 2;
        i = 13;
    } else {
        i = 14;
        x = bd.bgWidth -% g.targetStripWidths[14];
        dir = 1;
    }
    const t = targetAt(g, i);
    t.curStrip = 0;
    t.curFrame = 0;
    const t0 = targetAt(g, 0);
    if (t0.target.laneBusy[2] != 0) return;
    setPos(t, x, 0xbe);
    t0.target.laneBusy[2] = 1;
    place(g, bd, t, x, 0xbe, dir);
    setPos(t, x, 0xbe);
}

/// One tick of the bullet's timer: one step (`dir` comes back 3 when the
/// bullet stopped against a figure); a stopped bullet redraws the gun; on a
/// hit the bullet is stopped, the gun redrawn and the hit goes to the first
/// figure the second stage finds (K3).
fn bulletTick(g: *Game, bd: *Backdrop) void {
    const b = g.bullets[0].?;
    var dir: i16 = 0;
    bullet.stepMove(g, b, bd, &dir);
    if (!movement.isMoving(g, b)) redrawGun(g, bd);
    if (dir != 3) return;
    movement.stopMoving(g, b, bd);
    redrawGun(g, bd);
    const lanes = [_]struct { lane: usize, first: usize, last: usize }{
        .{ .lane = 2, .first = 13, .last = 14 },
        .{ .lane = 1, .first = 7, .last = 12 },
        .{ .lane = 0, .first = 0, .last = 6 },
    };
    const t0 = targetAt(g, 0);
    for (lanes) |l| {
        if (t0.target.laneBusy[l.lane] == 0) continue;
        for (l.first..l.last + 1) |i| {
            const t = targetAt(g, i);
            if (movement.isMoving(g, t) and bulletOverlaps(g, b, t, i)) {
                target.hit(g, t, bd, @intCast(i));
                return;
            }
        }
    }
}

/// The second hit stage: does the bullet (x..x+55) overlap figure `i`
/// (x..x+width) in x? Strict comparisons in the original's three cases
/// (bullet inside, the figure's left edge inside the bullet, its right edge
/// inside), so a == t matches none, and no y test (K3). With the fix: the
/// real bullet width, touching edges counted, and the y ranges overlap too.
fn bulletOverlaps(g: *Game, a: *Object, t: *Object, i: usize) bool {
    const w = g.targetStripWidths[i];
    if (g.fixes.serial_hit_needs_row) {
        return a.x <= t.x +% w and t.x <= a.x +% g.bulletStripWidths[0] and
            a.y <= t.y +% g.targetStripHeights[i] and t.y <= a.y +% g.bulletStripHeights[0];
    }
    if (t.x < a.x and a.x +% 0x37 < t.x +% w) return true;
    if (a.x < t.x and t.x < a.x +% 0x37) return true;
    return t.x < a.x and t.x +% w < a.x +% 0x37 and a.x < t.x +% w;
}

/// SceneVtbl slot 05 createScreen (serial_scene_create_screen).
// @orig 1088:5840 serial_scene_create_screen
pub fn createScreen(g: *Game, scene: *Scene) ?*Backdrop {
    _ = scene;
    const bd = g.local().create(Backdrop) catch return null;
    bd.* = .{};
    return backdrop.ctor(g, bd, "Fundo.bmp", 0, 0, 0x280, 0x1e0);
}

/// SceneVtbl slot 07 create (serial_scene_create; hwnd dropped).
// @orig 1068:008d serial_scene_create
pub fn create(g: *Game, scene: *Scene) ?*Scene {
    _ = scene_unit.create(g, scene);
    _ = g.plat.mciString("open doom2.mid type sequencer alias musica");
    _ = g.plat.mciString("play musica notify");
    _ = sound.mixInit(g);
    g.shotWave = sound.open(g, "tiros1.WAV");
    g.hitWave = sound.open(g, "morte2.wav");
    g.pracas01Wave = sound.open(g, "PRACAS01.WAV");
    const bd = bdOf(scene);
    target.drawScore(g, bd);
    target.blitScoreBox(g, bd);
    return scene;
}
