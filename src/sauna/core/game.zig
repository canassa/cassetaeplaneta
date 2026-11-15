//! SAUNA's state: the SaunaGame object (Game + SaunaGame flattened;
//! `g_game` and `g_saunaGame` are both this) plus every DGROUP global of
//! SAUNA.EXE, the maze among them. One heap instance per running SAUNA (a
//! host task), passed as `*Game` to the units (docs/sauna/DESIGN.md
//! "State").
//!
//! The Win16 replacements (message queue and timers, `send`/`post`,
//! SetSystemTimer) are the same as NOITE's and TIRO's `Game`, over the
//! shared `core/queue.zig`; this game's platform is its task's (`host.zig`).

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
/// Pacman's strips: left, right, up, down; the same + 4 under power (the
/// Ghosts' pictures); 8 the death (6 frames). The Ghosts use the first 8.
pub const strip_count = 9;
const maze_data = @import("maze_data.zig");
pub const maze_rows = maze_data.maze_rows;
pub const maze_cols = maze_data.maze_cols;
pub const Maze = maze_data.Maze;
pub const initial_maze = maze_data.initial_maze;

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
    // @orig Game+0x4
    scene: ?*world.Scene = null,
    // @orig Game+0x8 (held while the old scene is deleted)
    oldScene: ?*world.Scene = null,
    // @orig Game+0xc (createStatusBar returns NULL: always null)
    statusBar: ?*Object = null,
    // @orig Game+0x10
    controlPanel: ?*Object = null,
    // @orig Game+0x14..0x16 (unknown)
    unk14: [2]u16 = @splat(0),
    // @orig Game+0x18 (Pacman)
    player: ?*Object = null,
    // @orig Game+0x1c
    globalObjects: ObjectList = .{},
    // @orig Game+0x24
    lastGlobalObject: ?*Object = null,
    // @orig Game+0x28
    updateList: world.UpdateList = .{},
    // @orig Game+0xa2
    drawList: world.DrawList = .{},
    // @orig Game+0x55a (the ctor writes 2)
    unk55A: u16 = 0,
    // @orig Game+0x55c
    clearWidth: i16 = 0,
    // @orig Game+0x55e
    clearHeight: i16 = 0,

    // ---- DGROUP globals ----
    // @orig g_nextId
    nextId: i16 = 0,
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
    // @orig g_pacmanStripFiles initdata=skip (far pointers to the DGROUP
    // file names; under power the strip is the direction + 4: the Ghosts'
    // pictures)
    pacmanStripFiles: [strip_count][]const u8 = .{ "3SPEFB.bmp", "3SPRFB.bmp", "3SPCSB.bmp", "3SPDFB.bmp", "3SPCEP.bmp", "3SPCRP.bmp", "3SPCSP.bmp", "3SPCDP.bmp", "3SPCMB.bmp" },
    // @orig g_pacmanStripFrames
    pacmanStripFrames: [strip_count]i16 = .{ 2, 2, 2, 2, 2, 2, 2, 2, 6 },
    // @orig g_pacmanStripWidths
    pacmanStripWidths: [strip_count]i16 = @splat(40),
    // @orig g_pacmanStripHeights
    pacmanStripHeights: [strip_count]i16 = @splat(40),
    // @orig g_transparentColor (the colour key of every transparent copy)
    transparentColor: u16 = 0x0b,
    // @orig g_noiteWnd (NOITE's window, from 0x40b; 0 when run alone)
    noiteWnd: msg.Hwnd = 0,
    // @orig g_started
    started: u16 = 0,
    // @orig g_handshakePending (DGROUP data 1: 0x40c is still to be posted)
    handshakePending: u16 = 1,
    // @orig g_ghostStripFiles initdata=skip (the same files as Pacman's,
    // normal and powered sets swapped; ghost_ctor builds 8 strips)
    ghostStripFiles: [strip_count][]const u8 = .{ "3SPCEP.bmp", "3SPCRP.bmp", "3SPCSP.bmp", "3SPCDP.bmp", "3SPEFB.bmp", "3SPRFB.bmp", "3SPCSB.bmp", "3SPDFB.bmp", "3SPCMB.bmp" },
    // @orig g_ghostStripFrames
    ghostStripFrames: [strip_count]i16 = .{ 2, 2, 2, 2, 2, 2, 2, 2, 6 },
    // @orig g_ghostStripWidths
    ghostStripWidths: [strip_count]i16 = @splat(40),
    // @orig g_ghostStripHeights
    ghostStripHeights: [strip_count]i16 = @splat(40),
    // @orig g_maze (a dot eaten becomes ' ')
    maze: Maze = initial_maze,
    // @orig g_dotsLeft (the win at 0)
    dotsLeft: i16 = 100,
    // @orig g_powerStrip (0, or 4 while powered: added to every strip)
    powerStrip: i16 = 0,
    // @orig g_powerStartPending (a cork was eaten: the handler's preamble
    // starts the power on the next message)
    powerStartPending: u16 = 0,
    // @orig g_pacmanDying
    pacmanDying: u16 = 0,
    // @orig g_keyLeftHeld / g_keyRightHeld / g_keyUpHeld / g_keyDownHeld
    keyLeftHeld: u16 = 0,
    keyRightHeld: u16 = 0,
    keyUpHeld: u16 = 0,
    keyDownHeld: u16 = 0,
    // @orig g_deathFramesLeft
    deathFramesLeft: i16 = 0,
    // @orig g_lives (not shown anywhere; the third catch ends the game)
    lives: i16 = 3,
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
    // @orig g_pacman
    pacman: ?*Object = null,
    // @orig g_mainWindow initdata=skip (CreateWindow's result: plat.windowHandle())
    mainWindow: msg.Hwnd = 0,
    // @orig g_appActive
    appActive: u16 = 0,
    // @orig g_windowWidth / g_windowHeight
    windowWidth: i16 = 0,
    windowHeight: i16 = 0,
    // @orig g_score (starts at 0; ±1000 at the end; won = wParam, not the sign)
    score: i16 = 0,
    // @orig g_messageText (message_box_printf's buffer)
    messageText: [100]u8 = @splat(0),
    // @orig g_peanut
    peanut: ?*Object = null,
    // @orig g_cork
    cork: ?*Object = null,
    // @orig g_saunaScene
    saunaScene: ?*world.Scene = null,
    // @orig g_powerWave (pacman2.wav)
    powerWave: ?platform.Wave = null,
    // @orig g_eatGhostWave (pacman4.wav)
    eatGhostWave: ?platform.Wave = null,
    // @orig g_eatPeanutWave (pacman.wav)
    eatPeanutWave: ?platform.Wave = null,
    // @orig g_caughtWave (pacman3.wav)
    caughtWave: ?platform.Wave = null,
    // @orig g_powerLoopWave (control.wav, looped while powered)
    powerLoopWave: ?platform.Wave = null,
    // @orig g_paintWave (ROLHAS01.WAV, played on every WM_PAINT)
    paintWave: ?platform.Wave = null,
    // @orig g_conditionTrue / g_conditionFalse initdata=skip (far BSS
    // segment 10a8, built by the static initialiser init_static_conditions
    // before WinMain)
    conditionTrue: world.Condition = .{ .kind = .flag, .value = 1 },
    conditionFalse: world.Condition = .{ .kind = .flag, .value = 0 },
    // @orig g_crtHoldRand (srand(GetTickCount()) on message 0x401)
    rand: Rand = .{},
    // No counterpart: the Corrigida's arcade game and controls screen (`arcade/`).
    arcade: @import("../arcade/glue.zig").State = .{},
    // No counterpart: g_setSystemTimer / g_killSystemTimer (`setSystemTimer`),
    // g_instance, g_moduleHandle, g_modulePath(Buf) (the EXE's directory is
    // the host's `Program.dir`), g_game / g_saunaGame (this Game), g_unk0F94
    // (read only by the dead FUN_1010_0960).

    pub fn create(gpa: std.mem.Allocator, plat: Platform) !*Game {
        const g = try gpa.create(Game);
        g.* = .{ .gpa = gpa, .plat = plat, .heap = .init(gpa) };
        return g;
    }

    /// The task ends: its local heap goes with it (what SAUNA never frees,
    /// e.g. the scene `sauna_scene_dtor` would delete, is not a leak here).
    pub fn destroy(g: *Game) void {
        g.arcade.deinit(g.gpa);
        g.heap.deinit();
        g.gpa.destroy(g);
    }

    /// The task's heap (`operator new` / `_fmalloc` of the large model).
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
            .message => |m| if (!g.post(m)) std.log.warn("sauna: posted queue full: message {x} lost", .{m.id}),
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
        h.sim.task_dirs[0] = "\\SAUNA";
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

test "SAUNA's Game builds with a headless platform" {
    var t = try TestGame.init(std.testing.allocator);
    defer t.deinit();
    const g = t.game;
    g.setSystemTimer(1, 50);
    t.headless.now = 50;
    try std.testing.expect(g.dispatchPending());
    try std.testing.expect(!g.dispatchPending());
}

test "the initial maze holds 96 peanuts and 4 corks" {
    var peanuts: usize = 0;
    var corks: usize = 0;
    for (initial_maze) |row| {
        try std.testing.expectEqual(@as(u8, 0), row[maze_cols]);
        for (row[0..maze_cols]) |c| switch (c) {
            '2' => peanuts += 1,
            '3' => corks += 1,
            else => {},
        };
    }
    try std.testing.expectEqual(@as(usize, 96), peanuts);
    try std.testing.expectEqual(@as(usize, 4), corks);
}
