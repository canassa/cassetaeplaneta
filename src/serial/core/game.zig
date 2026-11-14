//! SERIAL's state: the SerialGame object (Game + SerialGame flattened; `g_game`
//! and `g_serialGame` are both this) plus every DGROUP global of SERIAL.EXE.
//! One heap instance per running SERIAL (a host task), passed as `*Game` to
//! the units (docs/serial/DESIGN.md "State").
//!
//! The Win16 replacements (message queue and timers, `send`/`post`,
//! SetSystemTimer) are the same as NOITE's `Game`, over the shared
//! `core/queue.zig`; this game's platform is its task's (`host.zig`).

const std = @import("std");
const msg = @import("../../core/msg.zig");
const Msg = msg.Msg;
const Queue = @import("../../core/queue.zig").Queue;
const Fixes = @import("../../core/fixes.zig").Fixes;
const Rand = @import("../../core/crt.zig").Rand;
const platform = @import("../../platform/platform.zig");
const Platform = platform.Platform;
const object = @import("object.zig");
const Object = object.Object;
const ObjectList = object.ObjectList;
const world = @import("world.zig");

/// The window procedure (`AppWndProc`, unit `app`); returns the LRESULT.
pub const WndProc = *const fn (g: *Game, m: Msg) i32;

pub const max_waves = 20;
/// The figures (`g_targets`), one per strip: 0-6 lane 0, 7-12 lane 1,
/// 13-14 lane 2.
pub const figures = 15;
/// `g_timerIds` / `g_timerPeriods`.
pub const timer_slots = 8;

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
    // @orig g_gunStripFiles initdata=skip (near pointers to the DGROUP
    // file names)
    gunStripFiles: [1][]const u8 = .{"trabu.bmp"},
    // @orig g_gunStripFrames (the aims: left, straight, right)
    gunStripFrames: [1]i16 = .{3},
    // @orig g_gunStripWidths
    gunStripWidths: [1]i16 = .{238},
    // @orig g_gunStripHeights
    gunStripHeights: [1]i16 = .{105},
    // @orig g_targetStripFiles initdata=skip (the 15 figures, one strip each)
    targetStripFiles: [figures][]const u8 = .{ "3sarab.bmp", "3sbaba.bmp", "3sbabt.bmp", "3sclu.bmp", "3sfada.bmp", "3shitl.bmp", "3slenn.bmp", "3smafi.bmp", "3snoel.bmp", "3snoem.bmp", "3svelh.bmp", "3sesco.bmp", "3spira.bmp", "3skenn.bmp", "3scoel.bmp" },
    // @orig g_targetKinds (0: -100 when hit, 1: +100, 2: +200 and shoots)
    targetKinds: [figures]i16 = .{ 0, 0, 2, 0, 1, 0, 1, 0, 0, 2, 1, 1, 0, 1, 1 },
    // @orig g_targetStripFrames
    targetStripFrames: [figures]i16 = .{ 6, 10, 12, 13, 12, 10, 11, 9, 4, 16, 10, 12, 12, 2, 6 },
    // @orig g_targetStripWidths
    targetStripWidths: [figures]i16 = .{ 80, 88, 88, 92, 88, 52, 40, 88, 48, 124, 74, 128, 52, 200, 188 },
    // @orig g_targetStripHeights
    targetStripHeights: [figures]i16 = .{ 177, 100, 99, 127, 121, 111, 136, 105, 95, 105, 102, 147, 120, 67, 60 },
    // @orig g_bulletStripFiles initdata=skip (one frame per aim)
    bulletStripFiles: [1][]const u8 = .{"bala.bmp"},
    // @orig g_bulletStripFrames
    bulletStripFrames: [1]i16 = .{3},
    // @orig g_bulletStripWidths
    bulletStripWidths: [1]i16 = .{47},
    // @orig g_bulletStripHeights
    bulletStripHeights: [1]i16 = .{31},
    // @orig g_timerIds (read: [0] 3 walk, [3] 6 lane-2 walk, [4] 7 spawn,
    // [5] 8 clock, [7] 10 lane-2 spawn: BUGS.md K5)
    timerIds: [timer_slots]i16 = .{ 3, 4, 5, 6, 7, 8, 9, 10 },
    // @orig g_timerPeriods (read: [0], [3], [4])
    timerPeriods: [timer_slots]i16 = .{ 200, 200, 200, 100, 5000, 5000, 10000, 10000 },
    // @orig g_lives (the killers' shots take one each; reported in 0x40a)
    lives: i16 = 5,
    // @orig g_keyRightHeld
    keyRightHeld: u16 = 0,
    // @orig g_keyLeftHeld
    keyLeftHeld: u16 = 0,
    // @orig g_keySpaceHeld (never set: BUGS.md K4)
    keySpaceHeld: u16 = 0,
    // @orig g_spawnToggle (lane 2 is tried on every second spawn tick)
    spawnToggle: u16 = 0,
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
    // @orig g_score (BSS: starts at 0)
    score: i16 = 0,
    // @orig g_windowWidth / g_windowHeight
    windowWidth: i16 = 0,
    windowHeight: i16 = 0,
    // @orig g_messageText (message_box_printf's buffer)
    messageText: [100]u8 = @splat(0),
    // @orig g_gun
    gun: ?*Object = null,
    // @orig g_targets (the figures)
    targets: [figures]?*Object = @splat(null),
    // @orig g_bullets (the creator's loop runs i < 1)
    bullets: [1]?*Object = @splat(null),
    // @orig g_conditionTrue / g_conditionFalse initdata=skip (built by the
    // static initialiser init_static_conditions before WinMain)
    conditionTrue: world.Condition = .{ .kind = .flag, .value = 1 },
    conditionFalse: world.Condition = .{ .kind = .flag, .value = 0 },
    // @orig g_shotWave (tiros1.WAV: the gun's shot and a killer's)
    shotWave: ?platform.Wave = null,
    // @orig g_hitWave (morte2.wav: every hit)
    hitWave: ?platform.Wave = null,
    // @orig g_pracas01Wave (PRACAS01.WAV, played on every WM_PAINT)
    pracas01Wave: ?platform.Wave = null,
    // @orig g_crtHoldRand (srand(time(NULL)) in serial_create_targets:
    // `plat.unixTime()`)
    rand: Rand = .{},
    // No counterpart: g_setSystemTimer / g_killSystemTimer (`setSystemTimer`),
    // g_instance, g_moduleHandle, g_modulePath(Buf) (the EXE's directory is
    // the host's `Program.dir`), g_game / g_serialGame (this Game).

    pub fn create(gpa: std.mem.Allocator, plat: Platform) !*Game {
        const g = try gpa.create(Game);
        g.* = .{ .gpa = gpa, .plat = plat, .heap = .init(gpa) };
        return g;
    }

    /// The task ends: its local heap goes with it (what SERIAL never frees,
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
            .message => |m| if (!g.post(m)) std.log.warn("serial: posted queue full: message {x} lost", .{m.id}),
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
        h.sim.task_dirs[0] = "\\SERIAL";
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

test "SERIAL's Game builds with a headless platform" {
    var t = try TestGame.init(std.testing.allocator);
    defer t.deinit();
    const g = t.game;
    g.setSystemTimer(1, 50);
    t.headless.now = 50;
    try std.testing.expect(g.dispatchPending());
    try std.testing.expect(!g.dispatchPending());
}
