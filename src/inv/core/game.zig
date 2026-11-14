//! INV's state: the InvGame object (Game + InvGame flattened; `g_game`
//! and `g_invGame` are both this) plus every DGROUP global of INV.EXE.
//! One heap instance per running INV (a host task), passed as `*Game` to
//! the units (docs/inv/DESIGN.md "State").
//!
//! The Win16 replacements (message queue and timers, `send`/`post`,
//! SetSystemTimer) are the same as NOITE's `Game`, over the shared
//! `core/queue.zig`; this game's platform is its task's (`host.zig`).

const std = @import("std");
const msg = @import("../../core/msg.zig");
const Msg = msg.Msg;
const Queue = @import("../../core/queue.zig").Queue;
const Fixes = @import("../../core/fixes.zig").Fixes;
const platform = @import("../../platform/platform.zig");
const Platform = platform.Platform;
const object = @import("object.zig");
const Object = object.Object;
const ObjectList = object.ObjectList;
const world = @import("world.zig");

/// The window procedure (`AppWndProc`, unit `app`); returns the LRESULT.
pub const WndProc = *const fn (g: *Game, m: Msg) i32;

pub const max_waves = 20;
/// The invader columns (`g_invaderColumns`) and their invaders.
pub const columns = 4;
pub const invaders_per_column = 5;

pub const Game = struct {
    gpa: std.mem.Allocator,
    plat: Platform,
    fixes: Fixes = .{},
    queue: Queue = .{},
    /// The task's local heap (`local()`); freed with the Game.
    heap: std.heap.ArenaAllocator,
    wndProc: WndProc = noWndProc,
    /// Message log for trace diffing (null = off).
    trace: ?*std.ArrayList(u8) = null,
    /// WM_QUIT came: the message loop ends.
    quit: bool = false,

    // ---- struct Game ----
    // @orig Game+0x2
    scene: ?*world.Scene = null,
    // @orig Game+0x4 (held while the old scene is deleted)
    oldScene: ?*world.Scene = null,
    // @orig Game+0x6
    statusBar: ?*Object = null,
    // @orig Game+0x8
    controlPanel: ?*Object = null,
    // @orig Game+0xa (unknown)
    unk0A: u16 = 0,
    // @orig Game+0xc
    player: ?*Object = null,
    // @orig Game+0xe
    globalObjects: ObjectList = .{},
    // @orig Game+0x14
    updateList: world.UpdateList = .{},
    // @orig Game+0x52
    drawList: world.DrawList = .{},
    // @orig Game+0x2ae (the ctor writes 2)
    unk2AE: u16 = 0,
    // @orig Game+0x2b0
    clearWidth: i16 = 0,
    // @orig Game+0x2b2
    clearHeight: i16 = 0,

    // ---- DGROUP globals ----
    // @orig g_nextId
    nextId: i16 = 0,
    // @orig g_unk00A8 (read by the draw code; the sprites' transparent index)
    unk00A8: u8 = 0x0b,
    // @orig g_noiteWnd (NOITE's window, from 0x40b; 0 when run alone)
    noiteWnd: msg.Hwnd = 0,
    // @orig g_started
    started: u16 = 0,
    // @orig g_handshakePending (DGROUP data 1: 0x40c is still to be posted)
    handshakePending: u16 = 1,
    // @orig g_keyLeft / g_keyRight / g_keyUp / g_keyDown (game_handle_message's)
    keyLeft: u16 = 0,
    keyRight: u16 = 0,
    keyUp: u16 = 0,
    keyDown: u16 = 0,
    // @orig g_itemSelected
    itemSelected: u16 = 0,
    // @orig g_exitPending
    exitPending: u16 = 0,
    // @orig g_selectedItem
    selectedItem: ?*Object = null,
    // @orig g_dropElevation
    dropElevation: u16 = 0,
    // @orig g_cannonStripFiles initdata=skip (near pointers to the DGROUP
    // file names: the cannon, its destruction)
    cannonStripFiles: [2][]const u8 = .{ "Canhao.bmp", "Brocha.bmp" },
    // @orig g_cannonStripFrames
    cannonStripFrames: [2]i16 = .{ 1, 7 },
    // @orig g_cannonStripWidths
    cannonStripWidths: [2]i16 = @splat(65),
    // @orig g_cannonStripHeights
    cannonStripHeights: [2]i16 = @splat(67),
    // @orig g_saucerStripFiles initdata=skip (the saucer, its explosion)
    saucerStripFiles: [2][]const u8 = .{ "Disco.bmp", "Explod.bmp" },
    // @orig g_saucerStripFrames
    saucerStripFrames: [2]i16 = .{ 3, 8 },
    // @orig g_saucerStripWidths
    saucerStripWidths: [2]i16 = .{ 61, 111 },
    // @orig g_saucerStripHeights
    saucerStripHeights: [2]i16 = .{ 32, 103 },
    // @orig g_shotStripFiles initdata=skip (frame 1 is blank)
    shotStripFiles: [1][]const u8 = .{"Tiro.bmp"},
    // @orig g_shotStripFrames
    shotStripFrames: [1]i16 = .{2},
    // @orig g_shotStripWidths
    shotStripWidths: [1]i16 = .{12},
    // @orig g_shotStripHeights
    shotStripHeights: [1]i16 = .{22},
    // @orig g_bombStripFiles initdata=skip (the bomb, its impact)
    bombStripFiles: [2][]const u8 = .{ "Bomba.bmp", "Bomtir.bmp" },
    // @orig g_bombStripFrames
    bombStripFrames: [2]i16 = .{ 1, 3 },
    // @orig g_bombStripWidths
    bombStripWidths: [2]i16 = .{ 12, 25 },
    // @orig g_bombStripHeights
    bombStripHeights: [2]i16 = .{ 22, 28 },
    // @orig g_columnStripFiles initdata=skip (a column of five invaders)
    columnStripFiles: [1][]const u8 = .{"Movein.bmp"},
    // @orig g_columnStripFrames
    columnStripFrames: [1]i16 = .{2},
    // @orig g_columnStripWidths
    columnStripWidths: [1]i16 = .{88},
    // @orig g_columnStripHeights
    columnStripHeights: [1]i16 = .{217},
    // @orig g_explosionStripFiles initdata=skip (one invader exploding)
    explosionStripFiles: [1][]const u8 = .{"Naboom1.bmp"},
    // @orig g_explosionStripFrames
    explosionStripFrames: [1]i16 = .{8},
    // @orig g_explosionStripWidths
    explosionStripWidths: [1]i16 = .{88},
    // @orig g_explosionStripHeights
    explosionStripHeights: [1]i16 = .{44},
    // @orig g_bombTimerIds
    bombTimerIds: [2]i16 = .{ 6, 7 },
    // @orig g_bombDropTimerIds
    bombDropTimerIds: [2]i16 = .{ 8, 9 },
    // @orig g_bombDropPeriods
    bombDropPeriods: [2]i16 = .{ 2000, 5000 },
    // @orig g_formationDir (2 right, 1 left)
    formationDir: i16 = 2,
    // @orig g_invadersLanded (the loss by landing)
    invadersLanded: i16 = 0,
    // @orig g_invaderPeriod (timer 0xf's period, ms)
    invaderPeriod: i16 = 500,
    // @orig g_formationMaxY (a descent below it plays desceniv.wav)
    formationMaxY: i16 = 60,
    // @orig g_keyRightHeld
    keyRightHeld: u16 = 0,
    // @orig g_keyLeftHeld
    keyLeftHeld: u16 = 0,
    // @orig g_keySpaceHeld (never set: BUGS.md I1)
    keySpaceHeld: u16 = 0,
    // @orig g_unk0284 (data 1; no access found)
    unk0284: u16 = 1,
    // @orig g_invadersLeft
    invadersLeft: i16 = 20,
    // @orig g_bombHitCannon (once per drop)
    bombHitCannon: [2]u16 = @splat(0),
    // @orig g_waveMixOpenResult
    waveMixOpenResult: u32 = 0,
    // @orig g_waveMixSession
    waveMixSession: platform.MixSession = 0,
    // @orig g_waves
    waves: [max_waves]?platform.Wave = @splat(null),
    // @orig g_waveCount
    waveCount: i16 = 0,
    // @orig g_occupancyCount / g_occupancyObject
    occupancy: world.Occupancy = .{},
    // @orig g_mainWindow initdata=skip (CreateWindow's result: plat.windowHandle())
    mainWindow: msg.Hwnd = 0,
    // @orig g_appActive
    appActive: u16 = 0,
    // @orig g_score (BSS: starts at 0; NOITE adds it, won or lost)
    score: i16 = 0,
    // @orig g_windowWidth / g_windowHeight
    windowWidth: i16 = 0,
    windowHeight: i16 = 0,
    // @orig g_messageText (message_box_printf's buffer)
    messageText: [100]u8 = @splat(0),
    // @orig g_cannon
    cannon: ?*Object = null,
    // @orig g_saucer
    saucer: ?*Object = null,
    // @orig g_shots (the creator's loop runs i < 1)
    shots: [1]?*Object = @splat(null),
    // @orig g_bombs
    bombs: [2]?*Object = @splat(null),
    // @orig g_invaderColumns
    invaderColumns: [columns]?*Object = @splat(null),
    // @orig g_invaderExplosion
    invaderExplosion: ?*Object = null,
    // @orig g_conditionTrue / g_conditionFalse initdata=skip (built by the
    // static initialiser init_static_conditions before WinMain)
    conditionTrue: world.Condition = .{ .kind = .flag, .value = 1 },
    conditionFalse: world.Condition = .{ .kind = .flag, .value = 0 },
    // @orig g_shotWave (tiroes2.wav)
    shotWave: ?platform.Wave = null,
    // @orig g_explosWave (explos.wav)
    explosWave: ?platform.Wave = null,
    // @orig g_saucerWave (nave.wav)
    saucerWave: ?platform.Wave = null,
    // @orig g_explo1Wave (explo1.wav)
    explo1Wave: ?platform.Wave = null,
    // @orig g_cannonHitWave (brocha3.wav)
    cannonHitWave: ?platform.Wave = null,
    // @orig g_explo5Wave (explo5.WAV)
    explo5Wave: ?platform.Wave = null,
    // @orig g_marchWave (marcha.wav)
    marchWave: ?platform.Wave = null,
    // @orig g_descendWave (desceniv.wav)
    descendWave: ?platform.Wave = null,
    // No counterpart: g_setSystemTimer / g_killSystemTimer (`setSystemTimer`),
    // g_instance, g_moduleHandle, g_modulePath(Buf) (the EXE's directory is
    // the host's `Program.dir`), g_game / g_invGame (this Game). INV has no
    // `srand`/`rand` (TIRO's g_crtHoldRand): nothing in it is random.

    pub fn create(gpa: std.mem.Allocator, plat: Platform) !*Game {
        const g = try gpa.create(Game);
        g.* = .{ .gpa = gpa, .plat = plat, .heap = .init(gpa) };
        return g;
    }

    /// The task ends: its local heap goes with it (what INV never frees,
    /// e.g. the strips `scene_object_dtor` leaves, is not a leak here).
    pub fn destroy(g: *Game) void {
        g.heap.deinit();
        g.gpa.destroy(g);
    }

    /// The task's local heap (`_nmalloc` / `operator new` over LocalAlloc).
    /// Objects and strips the original never frees are allocated here.
    pub fn local(g: *Game) std.mem.Allocator {
        return g.heap.allocator();
    }

    // ---- USER replacements (as NOITE's Game) ----

    /// SendMessage(own window): dispatched at once, nested.
    pub fn send(g: *Game, m: Msg) i32 {
        g.log('S', m);
        return g.wndProc(g, m);
    }

    /// PostMessage(own window); false when the queue is full.
    pub fn post(g: *Game, m: Msg) bool {
        return g.queue.post(m);
    }

    pub fn setTimer(g: *Game, id: u16, ms: u16) void {
        _ = g.queue.setTimer(.normal, id, ms, g.plat.ticks());
    }
    pub fn killTimer(g: *Game, id: u16) void {
        _ = g.queue.killTimer(.normal, id);
    }
    pub fn postQuitMessage(g: *Game) void {
        g.queue.quit_pending = true;
    }
    /// SetSystemTimer (USER ordinal 11, g_setSystemTimer) → WM_SYSTIMER.
    pub fn setSystemTimer(g: *Game, id: u16, ms: u16) void {
        _ = g.queue.setTimer(.system, id, ms, g.plat.ticks());
    }
    /// KillSystemTimer (USER ordinal 182, g_killSystemTimer).
    pub fn killSystemTimer(g: *Game, id: u16) void {
        _ = g.queue.killTimer(.system, id);
    }

    /// One turn of app_message_loop: dispatches the next due message;
    /// false when the queue is empty.
    pub fn dispatchPending(g: *Game) bool {
        const m = g.queue.next(g.plat.ticks()) orelse return false;
        if (m.id == msg.wm.quit) {
            g.quit = true;
            return true;
        }
        g.log('Q', m);
        _ = g.wndProc(g, m);
        return true;
    }

    /// A platform event, as Windows hands it to the program (`main.zig`'s
    /// `deliver` for NOITE).
    pub fn deliver(g: *Game, ev: platform.Event) void {
        switch (ev) {
            .quit => _ = g.send(.{ .id = msg.wm.close }),
            .activate => |on| _ = g.send(.{ .id = msg.wm.activate, .wparam = @intFromBool(on) }),
            .input => |m| if (g.plat.filterInput(m)) |in| g.queue.postInput(in),
            .message => |m| if (!g.post(m)) std.log.warn("inv: posted queue full: message {x} lost", .{m.id}),
        }
    }

    fn log(g: *Game, how: u8, m: Msg) void {
        const t = g.trace orelse return;
        var buf: [64]u8 = undefined;
        const line = std.fmt.bufPrint(&buf, "{d} {c} {x:0>4} {x:0>4} {x:0>8}\n", .{
            g.plat.ticks(), how, m.id, m.wparam, @as(u32, @bitCast(m.lparam)),
        }) catch return;
        t.appendSlice(g.gpa, line) catch {};
    }
};

/// A `Game` over a headless platform, for unit tests (as NOITE's).
pub const TestGame = struct {
    headless: *Headless,
    game: *Game,

    pub fn init(gpa: std.mem.Allocator) !TestGame {
        const h = try gpa.create(Headless);
        errdefer gpa.destroy(h);
        h.* = Headless.init(gpa, std.testing.io, .{});
        h.sim.task_dirs[0] = "\\INV";
        errdefer h.deinit();
        return .{ .headless = h, .game = try Game.create(gpa, h.platform()) };
    }

    pub fn deinit(t: TestGame) void {
        const gpa = t.game.gpa;
        t.game.destroy();
        t.headless.deinit();
        gpa.destroy(t.headless);
    }
};
const Headless = @import("../../platform/headless.zig").Headless;

fn noWndProc(_: *Game, _: Msg) i32 {
    return 0;
}

test "INV's Game builds with a headless platform" {
    var t = try TestGame.init(std.testing.allocator);
    defer t.deinit();
    const g = t.game;
    g.setSystemTimer(1, 50);
    t.headless.now = 50;
    try std.testing.expect(g.dispatchPending());
    try std.testing.expect(!g.dispatchPending());
}
