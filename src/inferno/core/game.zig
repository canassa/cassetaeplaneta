//! INFERNO's state: the InfernoGame object (Game + InfernoGame flattened;
//! `g_game` and `g_infernoGame` are both this) plus every DGROUP global of
//! INFERNO.EXE (and the two static FlagConditions of the far BSS segment
//! 1088). One heap instance per running INFERNO (a host task), passed as
//! `*Game` to the units (docs/inferno/DESIGN.md "State").
//!
//! The Win16 replacements (message queue and timers, `send`/`post`,
//! SetSystemTimer) are the same as TIRO's `Game`, over the shared
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
/// The hero's twelve strips (DATA.md §5).
pub const hero_strips = 12;

pub const Game = struct {
    gpa: std.mem.Allocator,
    plat: Platform,
    fixes: Fixes = .{},
    queue: Queue = .{},
    /// The task's heap (`local()`); freed with the Game.
    heap: std.heap.ArenaAllocator,
    wndProc: WndProc = noWndProc,
    /// Message log for trace diffing (null = off).
    trace: ?*std.ArrayList(u8) = null,
    /// WM_QUIT came: the message loop ends.
    quit: bool = false,

    // ---- struct Game (0xac) ----
    // @orig Game+0x4
    scene: ?*world.Scene = null,
    // @orig Game+0x8 (held while the old scene is deleted)
    oldScene: ?*world.Scene = null,
    // @orig Game+0xc (never set: INFERNO builds no StatusBar)
    statusBar: ?*Object = null,
    // @orig Game+0x10 (never set: INFERNO builds no ControlPanel)
    controlPanel: ?*Object = null,
    // @orig Game+0x14..0x16 (not seen)
    unk14: [2]u16 = @splat(0),
    // @orig Game+0x18
    player: ?*Object = null,
    // @orig Game+0x1c
    globalObjects: ObjectList = .{},
    // @orig Game+0x20
    updateList: world.UpdateList = .{},
    // @orig Game+0x9a (the ctor writes 2; never read)
    unk9A: u16 = 0,
    // @orig Game+0x9c (never written)
    clearWidth: i16 = 0,
    // @orig Game+0x9e (never written)
    clearHeight: i16 = 0,

    // ---- DGROUP globals ----
    // @orig g_nextId
    nextId: i16 = 0,
    // @orig g_unk0082 (read by the draw code; the sprites' transparent index)
    unk0082: u8 = 0x0b,
    // @orig g_noiteWnd (NOITE's window, from 0x40b; 0 when run alone)
    noiteWnd: msg.Hwnd = 0,
    // @orig g_started (set by WM_CREATE: from then on 0x40c precedes every
    // message, BUGS.md H1)
    started: i16 = 0,
    // @orig g_keyLeft / g_keyRight / g_keyUp / g_keyDown (game_handle_message's)
    keyLeft: i16 = 0,
    keyRight: i16 = 0,
    keyUp: i16 = 0,
    keyDown: i16 = 0,
    // @orig g_itemSelected
    itemSelected: i16 = 0,
    // @orig g_exitPending
    exitPending: i16 = 0,
    // @orig g_selectedItem
    selectedItem: ?*Object = null,
    // @orig g_dropElevation
    dropElevation: i16 = 0,
    // @orig g_heroStripFiles initdata=skip (far pointers to the DGROUP names)
    heroStripFiles: [hero_strips][]const u8 = .{ "marppa.bmp", "marpa.bmp", "marppal.bmp", "marpal.bmp", "margpa.bmp", "marga.bmp", "margpal.bmp", "margal.bmp", "3smort.bmp", "3smortl.bmp", "3svito.bmp", "3svitol.bmp" },
    // @orig g_heroStripFrames
    heroStripFrames: [hero_strips]i16 = .{ 2, 8, 2, 8, 2, 8, 2, 8, 8, 8, 4, 4 },
    // @orig g_heroStripWidths
    heroStripWidths: [hero_strips]i16 = @splat(38),
    // @orig g_heroStripHeights
    heroStripHeights: [hero_strips]i16 = @splat(65),
    // @orig g_platformStripFiles initdata=skip
    platformStripFiles: [1][]const u8 = .{"Plataf.bmp"},
    // @orig g_platformStripFrames
    platformStripFrames: [1]i16 = .{1},
    // @orig g_platformStripWidths
    platformStripWidths: [1]i16 = .{84},
    // @orig g_platformStripHeights
    platformStripHeights: [1]i16 = .{12},
    // @orig g_rockStripFiles initdata=skip
    rockStripFiles: [3][]const u8 = .{ "rocha02.bmp", "rocha01.bmp", "rocha03.bmp" },
    // @orig g_rockStripFrames
    rockStripFrames: [3]i16 = .{ 1, 1, 1 },
    // @orig g_rockStripWidths
    rockStripWidths: [3]i16 = .{ 94, 171, 73 },
    // @orig g_rockStripHeights
    rockStripHeights: [3]i16 = .{ 99, 35, 86 },
    // @orig g_drinkStripFiles initdata=skip (3 the present)
    drinkStripFiles: [4][]const u8 = .{ "cerva.bmp", "chopp.bmp", "copo.bmp", "3spres.bmp" },
    // @orig g_drinkStripFrames
    drinkStripFrames: [4]i16 = .{ 2, 2, 2, 3 },
    // @orig g_drinkStripWidths
    drinkStripWidths: [4]i16 = .{ 11, 17, 16, 82 },
    // @orig g_drinkStripHeights
    drinkStripHeights: [4]i16 = .{ 24, 14, 15, 56 },
    // @orig g_crossStripFiles initdata=skip
    crossStripFiles: [1][]const u8 = .{"cruz.bmp"},
    // @orig g_crossStripFrames
    crossStripFrames: [1]i16 = .{1},
    // @orig g_crossStripWidths
    crossStripWidths: [1]i16 = .{21},
    // @orig g_crossStripHeights
    crossStripHeights: [1]i16 = .{38},
    // @orig g_hazardStripFiles initdata=skip (hazard_ctor is passed 4
    // strips: the fourth reads past the tables, BUGS.md "Harmless (INFERNO)")
    hazardStripFiles: [3][]const u8 = .{ "carvao.bmp", "diabo.bmp", "fogo.bmp" },
    // @orig g_hazardStripFrames
    hazardStripFrames: [3]i16 = .{ 2, 2, 2 },
    // @orig g_hazardStripWidths
    hazardStripWidths: [3]i16 = .{ 26, 71, 29 },
    // @orig g_hazardStripHeights
    hazardStripHeights: [3]i16 = .{ 26, 46, 37 },
    // @orig g_heroTimerPending (1 until the first walk or jump starts the
    // hero's move timer)
    heroTimerPending: i16 = 1,
    // @orig g_rockIndex (cycles 0-5)
    rockIndex: i16 = 3,
    // @orig g_hazardIndex (cycles 0-5)
    hazardIndex: i16 = 1,
    // @orig g_floorY (the floor line every landing puts the hero on)
    floorY: i16 = 308,
    // @orig g_scrolling (the world scrolls this move tick)
    scrolling: i16 = 0,
    // @orig g_stompScored (the stomp latch: BUGS.md H7)
    stompScored: i16 = 0,
    // @orig g_lives
    lives: i16 = 5,
    // @orig g_startTick (GetTickCount at scene create; the grace start
    // after the time-out)
    startTick: u32 = 0,
    // @orig g_keyRightHeld
    keyRightHeld: i16 = 0,
    // @orig g_keyLeftHeld
    keyLeftHeld: i16 = 0,
    // @orig g_keyDownHeld
    keyDownHeld: i16 = 0,
    // @orig g_keyUpHeld
    keyUpHeld: i16 = 0,
    // @orig g_timeUp (the 3 minutes are over: the grace second runs)
    timeUp: i16 = 0,
    // @orig g_lastReportTick (the grace second's reposts, BUGS.md H2)
    lastReportTick: u32 = 0,
    // @orig g_unk0412
    unk0412: u16 = 0,
    // @orig g_unk0414
    unk0414: u16 = 0,
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
    appActive: i16 = 0,
    // @orig g_score (BSS: starts at 0; 16-bit, no clamp)
    score: i16 = 0,
    // @orig g_windowWidth / g_windowHeight
    windowWidth: i16 = 0,
    windowHeight: i16 = 0,
    // @orig g_messageText (message_box_printf's buffer)
    messageText: [100]u8 = @splat(0),
    // @orig g_hero
    hero: ?*Object = null,
    // @orig g_rocks
    rocks: [6]?*Object = @splat(null),
    // @orig g_platforms
    platforms: [4]?*Object = @splat(null),
    // @orig g_cross
    cross: ?*Object = null,
    // @orig g_hazards
    hazards: [6]?*Object = @splat(null),
    // @orig g_rockOrder
    rockOrder: [6]i16 = @splat(0),
    // @orig g_hazardOrder
    hazardOrder: [6]i16 = @splat(0),
    // @orig g_deathWave (sonicmor.wav)
    deathWave: ?platform.Wave = null,
    // @orig g_pickupWave (sonicpul.wav: +150)
    pickupWave: ?platform.Wave = null,
    // @orig g_magWave (sonicmag.wav: +300)
    magWave: ?platform.Wave = null,
    // @orig g_pickupWave2 (sonicpul.wav opened again: +100)
    pickupWave2: ?platform.Wave = null,
    // @orig g_conditionTrue / g_conditionFalse initdata=skip (1088:0000 and
    // 1088:0006, built by the static initialiser init_static_conditions
    // before WinMain)
    conditionTrue: world.Condition = .{ .kind = .flag, .value = 1 },
    conditionFalse: world.Condition = .{ .kind = .flag, .value = 0 },

    // ---- Port state, no counterpart ----
    /// BUGS.md H1's fix (`Fixes.inferno_ready_once`): 0x40c was posted to
    /// a NOITE window once.
    readyPosted: bool = false,
    // No counterpart: g_setSystemTimer / g_killSystemTimer (`setSystemTimer`),
    // g_instance, g_moduleHandle, g_modulePath(Buf) (the EXE's directory is
    // the host's `Program.dir`), g_game / g_infernoGame (this Game); the
    // MCI device is the platform's (`mciString`, alias `musica`).

    pub fn create(gpa: std.mem.Allocator, plat: Platform) !*Game {
        const g = try gpa.create(Game);
        g.* = .{ .gpa = gpa, .plat = plat, .heap = .init(gpa) };
        return g;
    }

    /// The task ends: its heap goes with it (what INFERNO never frees is
    /// not a leak here).
    pub fn destroy(g: *Game) void {
        g.heap.deinit();
        g.gpa.destroy(g);
    }

    /// The task's heap (`_fmalloc` / `operator new` in the large model).
    /// Objects and strips the original never frees are allocated here.
    pub fn local(g: *Game) std.mem.Allocator {
        return g.heap.allocator();
    }

    // ---- USER replacements (as TIRO's Game) ----

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
            .message => |m| if (!g.post(m)) std.log.warn("inferno: posted queue full: message {x} lost", .{m.id}),
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

/// A `Game` over a headless platform, for unit tests (as TIRO's).
pub const TestGame = struct {
    headless: *Headless,
    game: *Game,

    pub fn init(gpa: std.mem.Allocator) !TestGame {
        const h = try gpa.create(Headless);
        errdefer gpa.destroy(h);
        h.* = Headless.init(gpa, std.testing.io, .{});
        h.sim.task_dirs[0] = "\\INFERNO";
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

test "INFERNO's Game builds with a headless platform" {
    var t = try TestGame.init(std.testing.allocator);
    defer t.deinit();
    const g = t.game;
    g.setSystemTimer(1, 55);
    t.headless.now = 55;
    try std.testing.expect(g.dispatchPending());
    try std.testing.expect(!g.dispatchPending());
}
