//! Not in the original (`Fixes.inv_arcade_rules`): the arcade game inside INV.
//!
//! `invasion.handleMessage` hands the keys, the mouse, the timers and the scene start to `handle`
//! first when the flag is on. The game then runs from one timer (id 0x12, 16 ms) that steps
//! `sim.Sim` at 60 frames a second by the clock (`driver.zig`) and turns what happens into INV's own
//! events: the score, the waves, the end (WM_DESTROY with the won flag, as the original's), all
//! through the original's own functions where there are some.
//!
//! What the original's objects do (the 20-px steps, the timers, drawing into the backdrop) does not
//! run: the objects only carry the pictures (their frames' bitmaps), and `view.zig` draws them onto
//! the presented picture, every frame, between the game's frames. Nothing is ever drawn into the
//! backdrop or the screen.
//!
//! Decisions (docs/inv/ARCADE.md): INV's scoring (+100 an invader, doubled and tripled up the rows;
//! the saucer's 50..300 times ten; -500 a bomb that hits), the won flag and the result are INV's.

const std = @import("std");
const msg = @import("../../core/msg.zig");
const Msg = msg.Msg;
const wm = msg.wm;
const platform = @import("../../platform/platform.zig");
const Game = @import("../core/game.zig").Game;
const object = @import("../core/object.zig");
const world = @import("../core/world.zig");
const Scene = world.Scene;
const sound = @import("../sound.zig");
const sim = @import("sim.zig");
const driver = @import("driver.zig");

/// The game's timer and its period (a little under the 16.67 ms of a frame: a tick runs the frames
/// that are due, none, one or two).
pub const timer_id: u16 = 0x12;
const timer_ms: u16 = 16;

/// The pictures the objects carry (set by `begin`): the sheets the view cuts its sprites from.
pub const Art = struct {
    cannon: ?*object.Dib = null,
    brocha: ?*object.Dib = null,
    invaders: ?*object.Dib = null,
    boom: ?*object.Dib = null,
    saucer: ?*object.Dib = null,
    saucer_boom: ?*object.Dib = null,
    shot: ?*object.Dib = null,
    bomb: ?*object.Dib = null,
    impact: ?*object.Dib = null,
};

/// The controls screen's state (`controls.zig`).
pub const Controls = struct {
    up: bool = false,
    /// The key that took the screen down, until it is released.
    held_key: ?u16 = null,
};

pub const State = struct {
    ctl: Controls = .{},
    drv: driver.Driver = undefined,
    has_sim: bool = false,
    art: Art = .{},
    /// The game time of the frame the sprites' positions are of (for the view).
    frame_ms: u32 = 0,
    /// The last frame the march sounded in (the arcade's fleet beat is slower than its steps).
    last_march: u32 = 0,

    /// The presentation buffers (`view.zig`): the picture shown, the background top down.
    shown: ?*platform.Screen = null,
    background: []u8 = &.{},

    pub fn deinit(s: *State, gpa: std.mem.Allocator) void {
        if (s.shown) |scr| gpa.destroy(scr);
        gpa.free(s.background);
        s.shown = null;
        s.background = &.{};
    }
};

fn sceneBackdrop(scene: *Scene) *world.Backdrop {
    return scene.backdrop orelse @panic("inv.arcade: no backdrop");
}

// ---- keys ----

const vk_escape: u16 = 0x1b;
const vk_space: u16 = 0x20;
const vk_left: u16 = 0x25;
const vk_right: u16 = 0x27;

/// What a key does: the arrows and A, D move, SPACE fires.
pub fn keyOf(vk: u16) ?driver.Key {
    return switch (vk) {
        vk_left, 'A' => .left,
        vk_right, 'D' => .right,
        vk_space => .fire,
        else => null,
    };
}

// ---- the message hook ----

/// `invasion.handleMessage`'s first look when the flag is on: the answer, or null for the original's
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
            if (keyOf(m.wparam)) |k| if (st.has_sim) st.drv.key(k, true);
            return 1;
        },
        wm.keyup => {
            if (keyOf(m.wparam)) |k| if (st.has_sim) st.drv.key(k, false);
            return 1;
        },
        wm.systimer => {
            if (m.wparam == timer_id) {
                tick(g, scene);
                return 1;
            }
            // The original's timers (the formation, the cannon, the bombs ...) do not run.
            return 1;
        },
        wm.mousemove, wm.lbuttondown, wm.lbuttonup, wm.rbuttondown, wm.rbuttonup => return 1,
        msg.noite.scene_started => {
            begin(g, scene);
            return 1;
        },
        else => return null,
    }
}

// ---- the start ----

fn dibOf(o: ?*object.Object, strip: usize) ?*object.Dib {
    const obj = o orelse return null;
    if (strip >= obj.frames.len) return null;
    return obj.frames[strip].dib;
}

/// The scene has started: the pictures are taken from the objects, the game is made, and it starts
/// unless the controls screen is up.
fn begin(g: *Game, scene: *Scene) void {
    const st = &g.arcade;
    _ = sceneBackdrop(scene);
    st.art = .{
        .cannon = dibOf(g.cannon, 0),
        .brocha = dibOf(g.cannon, 1),
        .invaders = dibOf(g.invaderColumns[0], 0),
        .boom = dibOf(g.invaderExplosion, 0),
        .saucer = dibOf(g.saucer, 0),
        .saucer_boom = dibOf(g.saucer, 1),
        .shot = dibOf(g.shots[0], 0),
        .bomb = dibOf(g.bombs[0], 0),
        .impact = dibOf(g.bombs[0], 1),
    };
    st.drv = driver.Driver.init();
    st.has_sim = true;
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
    _ = scene;
    const st = &g.arcade;
    if (!st.has_sim) return;
    var fx: Fx = .{ .g = g };
    st.drv.tick(g.plat.ticks(), &fx);
    if (st.drv.ran) st.frame_ms = st.drv.frame_ms;
}

fn play(g: *Game, wave: ?platform.Wave) void {
    _ = sound.play(g, 0, wave);
}

/// What happens to INV when the game does something (`driver.Driver.tick`'s `fx`): its score, its
/// sounds and its end, through the original's functions.
const Fx = struct {
    g: *Game,

    pub fn frame(f: *Fx, s: *const sim.Sim, ev: sim.Events) void {
        const g = f.g;
        const st = &g.arcade;
        if (ev.fired) play(g, g.shotWave);
        if (ev.invader_hit) play(g, g.explosWave);
        if (ev.saucer_launch) play(g, g.saucerWave);
        if (ev.saucer_hit) play(g, g.explo1Wave);
        if (ev.cannon_hit or ev.landed) play(g, g.cannonHitWave);
        if (ev.bomb_shot) play(g, g.explo5Wave);
        if (ev.descend) play(g, g.descendWave);
        // The beat of the march: each step, but no faster than 7 a second.
        if (ev.march and s.t -% st.last_march >= 8) {
            st.last_march = s.t;
            play(g, g.marchWave);
        }
        if (ev.score != 0) g.score +%= @truncate(ev.score);
        if (ev.won) _ = g.send(.{ .id = wm.destroy, .wparam = 0xffff });
        if (ev.lost) _ = g.send(.{ .id = wm.destroy });
    }
};

test "keys: the arrows and A, D move; SPACE fires" {
    try std.testing.expectEqual(driver.Key.left, keyOf(vk_left).?);
    try std.testing.expectEqual(driver.Key.left, keyOf('A').?);
    try std.testing.expectEqual(driver.Key.right, keyOf('D').?);
    try std.testing.expectEqual(driver.Key.fire, keyOf(vk_space).?);
    try std.testing.expect(keyOf('Q') == null);
}

test "the cannon's rows in the sim are CANHAO.BMP's" {
    const file = try std.Io.Dir.cwd().readFileAlloc(std.testing.io, "assets/INV/CANHAO.BMP", std.testing.allocator, .limited(1 << 20));
    defer std.testing.allocator.free(file);
    const off = std.mem.readInt(u32, file[10..14], .little);
    const w: usize = @intCast(std.mem.readInt(i32, file[18..22], .little));
    const h: usize = @intCast(@abs(std.mem.readInt(i32, file[22..26], .little)));
    try std.testing.expectEqual(@as(usize, sim.cannon_w), w);
    try std.testing.expectEqual(@as(usize, sim.cannon_h), h);
    const stride = (w + 3) & ~@as(usize, 3);
    const s = sim.Sim.init();
    for (0..h) |y| {
        // A bottom-up picture: its last row in the file is the top.
        const row = file[off + (h - 1 - y) * stride ..][0..w];
        var lo: i16 = 0;
        var hi: i16 = -1;
        var seen = false;
        for (row, 0..) |c, x| {
            if (c == 11) continue;
            if (!seen) lo = @intCast(x);
            seen = true;
            hi = @intCast(x);
        }
        try std.testing.expectEqual(lo, s.cannon_rows[y].lo);
        try std.testing.expectEqual(hi, s.cannon_rows[y].hi);
    }
}
