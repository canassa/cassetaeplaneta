//! Not in the original (`Fixes.sauna_arcade_rules`): the arcade game inside SAUNA.
//!
//! `maze.handleMessage` hands the keys, the mouse, the timers and the scene start to `handle`
//! first when the flag is on. The game then runs from one timer (id 0x12, 16 ms) that steps
//! `sim.Sim` at 60 frames a second by the clock (`frames due = elapsed * 60 / 1000`), so the
//! speeds hold whatever the timer's jitter, and turns what happens into SAUNA's own events:
//! the peanut and cork pictures and the score, the waves, the lives and the end (WM_DESTROY, the
//! 0x40a result), all through the original's functions (`score.zig`).
//!
//! What the original's Pacman and Ghost objects do (the 16-px steps, the random turns, the timers
//! 0x10 and 0x11, drawing into the backdrop) does not run: the objects only carry the pictures
//! (their strips and frames), and `view.zig` draws them onto the presented picture each frame,
//! between the game's frames. Nothing but the dots is ever drawn into the backdrop or the screen.
//!
//! Decisions (docs/sauna/DESIGN.md "Arcade rules (Corrigida)"): SAUNA's scoring, lives and the won
//! flag stay; the corks are the energizers (6 s, flashes, SAUNA's picture swap); an eaten ghost
//! goes back to its place in the house at once (no eyes picture); a short READY beat starts the
//! game and follows a death; the click walks by its direction.

const std = @import("std");
const builtin = @import("builtin");
const msg = @import("../../core/msg.zig");
const Msg = msg.Msg;
const wm = msg.wm;
const Game = @import("../core/game.zig").Game;
const object = @import("../core/object.zig");
const Object = object.Object;
const world = @import("../core/world.zig");
const Backdrop = world.Backdrop;
const Scene = world.Scene;
const lists = @import("../lists.zig");
const score = @import("../score.zig");
const render = @import("../behaviour/render.zig");
const visibility = @import("../behaviour/visibility.zig");
const maze = @import("maze.zig");
const sim = @import("sim.zig");
const driver = @import("driver.zig");
const Phase = driver.Phase;
const Dir = sim.Dir;

/// The game's timer and its period (a little under the 16.67 ms of a frame: a tick runs the frames
/// that are due, one or two).
pub const timer_id: u16 = 0x12;
const timer_ms: u16 = 16;
/// The sprites' time: see `State.frame_ms`.
/// What `view.zig` draws for one actor: the picture and the screen position (top left of the
/// 40 x 40 frame) at the previous and the current frame.
pub const Sprite = struct {
    visible: bool = false,
    strip: i16 = 0,
    frame: i16 = 0,
    x0: i32 = 0,
    y0: i32 = 0,
    x1: i32 = 0,
    y1: i32 = 0,
};

pub const State = struct {
    /// The controls screen (`controls.zig`).
    ctl: Controls = .{},

    tiles: maze.Tiles = .{},
    drv: driver.Driver = undefined,
    has_sim: bool = false,
    /// The game time of the frame the sprites' current positions are (for the view).
    frame_ms: u32 = 0,

    sprites: [5]Sprite = @splat(.{}),

    /// F9 in a Debug build: the tiles and the ghosts' targets over the picture.
    debug: bool = false,

    /// The presentation buffers (`view.zig`).
    shown: ?*@import("../../platform/platform.zig").Screen = null,
    scratch: []u8 = &.{},

    pub fn deinit(s: *State, gpa: std.mem.Allocator) void {
        if (s.shown) |scr| gpa.destroy(scr);
        gpa.free(s.scratch);
        s.shown = null;
        s.scratch = &.{};
    }
};

/// The controls screen's state (`controls.zig`).
pub const Controls = struct {
    up: bool = false,
    /// The key that took the screen down, until it is released.
    held_key: ?u16 = null,
};

fn sceneBackdrop(scene: *Scene) *Backdrop {
    return scene.backdrop orelse @panic("sauna.arcade: no backdrop");
}

// ---- keys ----

const vk_escape: u16 = 0x1b;
const vk_f9: u16 = 0x78;

/// The direction a key stands for: the arrows and WASD.
pub fn keyDir(vk: u16) ?Dir {
    return switch (vk) {
        msg.vk.up, 'W' => .up,
        msg.vk.left, 'A' => .left,
        msg.vk.down, 'S' => .down,
        msg.vk.right, 'D' => .right,
        else => null,
    };
}

/// The click wants the direction of its larger leg from Pacman (touch screens: the taps of the
/// pad are arrows, a tap on the maze steers).
fn clickDir(g: *Game, x: i32, y: i32) ?Dir {
    const st = &g.arcade;
    if (!st.has_sim) return null;
    const p = st.sprites[0];
    const cx = p.x1 + 20;
    const cy = p.y1 + 20;
    const dx = x - cx;
    const dy = y - cy;
    if (dx == 0 and dy == 0) return null;
    if (@abs(dx) >= @abs(dy)) return if (dx < 0) .left else .right;
    return if (dy < 0) .up else .down;
}

// ---- the message hook ----

/// `maze.handleMessage`'s first look when the flag is on: the answer, or null for the original's
/// own code (WM_DESTROY, the music, the waves, activation).
pub fn handle(g: *Game, scene: *Scene, m: Msg) ?i16 {
    const st = &g.arcade;
    switch (m.id) {
        wm.keydown => {
            if (m.wparam == vk_escape) {
                // Leaving forfeits, as closing the window (BUGS.md, "Left out as design").
                _ = g.send(.{ .id = wm.close });
                return 1;
            }
            if (builtin.mode == .debug and m.wparam == vk_f9) {
                st.debug = !st.debug;
                return 1;
            }
            if (keyDir(m.wparam)) |d| st.drv.press(d);
            return 1;
        },
        wm.keyup => {
            if (keyDir(m.wparam)) |d| st.drv.release(d, g.plat.ticks());
            return 1;
        },
        wm.lbuttondown => {
            if (clickDir(g, @as(i16, @bitCast(m.lo())), @as(i16, @bitCast(m.hi())))) |d| st.drv.press(d);
            return 1;
        },
        wm.systimer => {
            if (m.wparam == timer_id) {
                tick(g, scene);
                return 1;
            }
            // The original's timers: Pacman's idle chomp and the ghosts' walk (killed at the
            // start), and the 5-s power.
            if (m.wparam == 0x10 or m.wparam == 0x11 or m.wparam == 10) return 1;
            return null;
        },
        msg.noite.scene_started => {
            begin(g, scene);
            return 1;
        },
        else => return null,
    }
}

// ---- the start ----

/// The scene has started: the original's actors leave the backdrop, the grid is built from the
/// maze as it is, the sprites are set, and the game starts unless the controls screen is up.
fn begin(g: *Game, scene: *Scene) void {
    const st = &g.arcade;
    const bd = sceneBackdrop(scene);
    g.killSystemTimer(0x10);
    g.killSystemTimer(0x11);
    // Pacman and the ghosts were drawn into the backdrop by the original's start-up.
    const pac = g.pacman.?;
    visibility.hide(g, pac, bd);
    visibility.blitToDc(g, pac, bd);
    pac.visible = 0;
    for (scene.ghosts) |gh| {
        const o = gh.?;
        visibility.hide(g, o, bd);
        visibility.blitToDc(g, o, bd);
        o.visible = 0;
    }
    st.tiles = maze.Tiles.build(&g.maze);
    st.drv = driver.Driver.init(&st.tiles, st.tiles.dot_count);
    st.has_sim = true;
    syncSprites(g);
    if (!st.ctl.up) go(g);
}

/// The game starts now (the controls screen went down, or there is none).
pub fn go(g: *Game) void {
    const st = &g.arcade;
    if (!st.has_sim or st.drv.phase != .waiting) return;
    st.drv.start(g.plat.ticks());
    st.frame_ms = st.drv.t0;
    g.setSystemTimer(timer_id, timer_ms);
}

// ---- the clock ----

fn tick(g: *Game, scene: *Scene) void {
    const st = &g.arcade;
    if (!st.has_sim) return;
    const bd = sceneBackdrop(scene);
    var fx: Fx = .{ .g = g, .bd = bd };
    st.drv.tick(g.plat.ticks(), &fx);
    if (st.drv.ran) {
        st.frame_ms = st.drv.frameMs();
        syncSprites(g);
    }
    if (!lists.updateIsEmpty(&g.updateList)) lists.updateFlush(g, &g.updateList, bd);
}

/// What happens to SAUNA when the game does something (`driver.Driver.tick`'s `fx`): its own
/// bookkeeping, through the original's functions.
const Fx = struct {
    g: *Game,
    bd: *Backdrop,

    /// The peanut or cork on tile (a, b) is eaten: SAUNA's own bookkeeping
    /// (`pacman_restore_background`'s dot branch): the maze cell, the count, the score and the wave,
    /// the picture erased from the dotted background and the view; the win at the last one.
    pub fn dot(f: *Fx, d: sim.DotEvent) bool {
        const g = f.g;
        const bd = f.bd;
        const col: usize = @intCast(d.a - 1);
        const row: usize = @intCast(d.b - 1);
        g.maze[row][col] = ' ';
        g.dotsLeft -%= 1;
        const dot_obj = if (d.cork) g.cork.? else g.peanut.?;
        dot_obj.x = @intCast(col * 16 + 8);
        dot_obj.y = @intCast(row * 16 + 10);
        if (d.cork) score.powerWaves(g) else score.eatPeanut(g, bd);
        render.eraseDot(g, bd, dot_obj);
        const fr = dot_obj.frames[@intCast(dot_obj.curStrip)];
        render.bitBlt(bd, dot_obj.x, dot_obj.y, fr.width, fr.height);
        render.resetRects(dot_obj);
        visibility.invalidate(g, dot_obj);
        lists.updateFlush(g, &g.updateList, bd);
        if (g.dotsLeft == 0) {
            g.arcade.drv.phase = .over;
            _ = g.send(.{ .id = wm.destroy, .wparam = 0xffff });
            return false;
        }
        return true;
    }

    /// The corks' time ran out.
    pub fn frightEnded(f: *Fx) void {
        score.powerStopWave(f.g);
    }

    /// Pacman was caught: false when it was the last life (the loss has been sent).
    pub fn caught(f: *Fx) bool {
        score.loseLife(f.g, f.bd);
        if (f.g.lives == 0) return false;
        score.powerStopWave(f.g);
        return true;
    }

    /// A ghost was eaten.
    pub fn ghostEaten(f: *Fx) void {
        score.eatGhost(f.g, f.bd);
    }
};

// ---- the pictures ----

/// A strip number for a heading: SAUNA's order, left 0, right 1, up 2, down 3.
fn stripOf(d: Dir) i16 {
    return switch (d) {
        .left => 0,
        .right => 1,
        .up => 2,
        .down => 3,
    };
}

/// Screen top left of the 40 x 40 frame of an actor at arcade pixel (x, y).
fn screenX(x: i32) i32 {
    return 2 * x - 20;
}
fn screenY(y: i32) i32 {
    return 2 * y - 20;
}

/// The sprites for the sim's state now; `snap` puts the previous position at the current one.
fn syncSprites(g: *Game) void {
    const st = &g.arcade;
    const s = &st.drv.sim;
    const snap = st.drv.snap;
    st.drv.snap = false;
    const dying = st.drv.phase == .dying;
    // Pacman.
    {
        const sp = &st.sprites[0];
        sp.x0 = if (snap) screenX(s.pac.x) else screenX(s.pac.px);
        sp.y0 = if (snap) screenY(s.pac.y) else screenY(s.pac.py);
        sp.x1 = screenX(s.pac.x);
        sp.y1 = screenY(s.pac.y);
        sp.visible = true;
        if (dying) {
            sp.strip = 8;
            sp.frame = @intCast(@min(st.drv.death_at / driver.death_frame_len, driver.death_pictures - 1));
            if (st.drv.death_at >= driver.death_frame_len * driver.death_pictures) sp.visible = false;
        } else {
            sp.strip = stripOf(s.pac.dir) + (if (s.fright_on) @as(i16, 4) else 0);
            sp.frame = s.pacFrame();
        }
        const o = g.pacman.?;
        o.x = @intCast(sp.x1);
        o.y = @intCast(sp.y1);
        o.curStrip = sp.strip;
        o.curFrame = sp.frame;
    }
    // The ghosts: hidden while Pacman dies.
    const scene = g.scene.?;
    for (&s.ghosts, 0..) |*gh, i| {
        const sp = &st.sprites[1 + i];
        sp.x0 = if (snap) screenX(gh.x) else screenX(gh.px);
        sp.y0 = if (snap) screenY(gh.y) else screenY(gh.py);
        sp.x1 = screenX(gh.x);
        sp.y1 = screenY(gh.y);
        sp.visible = !(dying or st.drv.phase == .over);
        const heading = if (gh.mode == .outside) gh.face else gh.dir;
        const frightened = gh.scared and !s.flashOn();
        sp.strip = stripOf(heading) + (if (frightened) @as(i16, 4) else 0);
        sp.frame = @intCast((gh.frames / 8) % 2);
        const o = scene.ghosts[i].?;
        o.x = @intCast(sp.x1);
        o.y = @intCast(sp.y1);
        o.curStrip = sp.strip;
        o.curFrame = sp.frame;
    }
    // Between two frames nothing moves while the game stands.
    if (st.drv.phase != .play and st.drv.phase != .ready) {
        for (&st.sprites) |*sp| {
            sp.x0 = sp.x1;
            sp.y0 = sp.y1;
        }
    }
}

test "keys: the arrows and WASD" {
    try std.testing.expectEqual(Dir.up, keyDir(msg.vk.up).?);
    try std.testing.expectEqual(Dir.left, keyDir('A').?);
    try std.testing.expectEqual(Dir.down, keyDir('S').?);
    try std.testing.expectEqual(Dir.right, keyDir(msg.vk.right).?);
    try std.testing.expect(keyDir('Q') == null);
}
