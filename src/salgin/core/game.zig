//! SALGIN's state: the SalginGame object (Game + SalginGame flattened;
//! `g_game` and `g_salginGame` are both this) plus every DGROUP global of
//! SALGIN.EXE. One heap instance per running SALGIN (a host task), passed
//! as `*Game` to the units (docs/salgin/DESIGN.md "State").
//!
//! The Win16 replacements (message queue and timers, `send`/`post`,
//! SetSystemTimer) are the same as NOITE's `Game`, over the shared
//! `core/queue.zig`; this game's platform is its task's (`host.zig`).

const std = @import("std");
const msg = @import("../../core/msg.zig");
const Msg = msg.Msg;
const Queue = @import("../../core/queue.zig").Queue;
const Fixes = @import("../../core/fixes.zig").Fixes;
const fight_controls = @import("../../core/fight_controls.zig");
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
/// The fighters' strips (the moves: docs/salgin/GAME.md "The fight").
pub const strips = 11;

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
    /// The Corrigida's controls screen (`fight_controls_screen`; not in the
    /// original).
    controls: fight_controls.State = .{},

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
    // @orig g_fighterStripFiles initdata=skip (near pointers to the DGROUP
    // file names; strip = the move, docs/salgin/GAME.md "The fight")
    fighterStripFiles: [strips][]const u8 = .{ "vbbsoc.bmp", "vbbvoo.bmp", "vbras.bmp", "vbbsal.bmp", "vbbgan.bmp", "vbbsat.bmp", "vbgin.bmp", "vbbdef.bmp", "vbtomb.bmp", "vbbmup.bmp", "vbbmen.bmp" },
    // @orig g_fighterStripFrames
    fighterStripFrames: [strips]i16 = .{ 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 11 },
    // @orig g_fighterStripWidths
    fighterStripWidths: [strips]i16 = @splat(173),
    // @orig g_fighterStripHeights
    fighterStripHeights: [strips]i16 = @splat(279),
    // @orig g_fighterDamage (the player's blows by its strip; the opponent's
    // attacks read it too: BUGS.md S1)
    fighterDamage: [strips]i16 = .{ 1, 2, 1, 2, 0, 0, 0, 0, 0, 0, 0 },
    // @orig g_opponentStripFiles initdata=skip
    opponentStripFiles: [strips][]const u8 = .{ "magaso.bmp", "machvi.bmp", "maband.bmp", "machsa.bmp", "magaan.bmp", "magasa.bmp", "maging.bmp", "magade.bmp", "matomb.bmp", "matoup.bmp", "macofi.bmp" },
    // @orig g_opponentStripFrames
    opponentStripFrames: [strips]i16 = .{ 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 22 },
    // @orig g_opponentStripWidths
    opponentStripWidths: [strips]i16 = @splat(216),
    // @orig g_opponentStripHeights
    opponentStripHeights: [strips]i16 = @splat(295),
    // @orig g_opponentDamage (read only in a trade, on Fighter.health: S1, S8)
    opponentDamage: [strips]i16 = .{ 2, 1, 1, 3, 0, 0, 0, 0, 0, 0, 0 },
    // @orig g_bannerStripFrames
    bannerStripFrames: [1]i16 = .{1},
    // @orig g_bannerStripWidths
    bannerStripWidths: [1]i16 = .{232},
    // @orig g_bannerStripHeights
    bannerStripHeights: [1]i16 = .{42},
    // @orig g_bannerStripFiles initdata=skip
    bannerStripFiles: [1][]const u8 = .{"porrada.bmp"},
    // @orig g_energyStripFrames
    energyStripFrames: [1]i16 = .{1},
    // @orig g_energyStripWidths
    energyStripWidths: [1]i16 = .{16},
    // @orig g_energyStripHeights
    energyStripHeights: [1]i16 = .{19},
    // @orig g_energyStripFiles initdata=skip
    energyStripFiles: [1][]const u8 = .{"energia.bmp"},
    // @orig g_reactionStrips ([(target strip - 4) * 4 + attack][weak]: the
    // reel 9, the fall 8, the block 7)
    reactionStrips: [16][2]i16 = .{
        .{ 9, 8 }, .{ 9, 8 }, .{ 8, 8 }, .{ 9, 8 },
        .{ 9, 8 }, .{ 9, 8 }, .{ 8, 8 }, .{ 9, 8 },
        .{ 9, 8 }, .{ 9, 8 }, .{ 8, 8 }, .{ 9, 8 },
        .{ 7, 8 }, .{ 7, 8 }, .{ 8, 8 }, .{ 7, 8 },
    },
    // @orig g_keyRightHeld (the eight move latches: BUGS.md S3, S4)
    keyRightHeld: u16 = 0,
    // @orig g_keyLeftHeld
    keyLeftHeld: u16 = 0,
    // @orig g_keyUpHeld
    keyUpHeld: u16 = 0,
    // @orig g_keyDownHeld
    keyDownHeld: u16 = 0,
    // @orig g_keyPgUpHeld
    keyPgUpHeld: u16 = 0,
    // @orig g_keyHomeHeld
    keyHomeHeld: u16 = 0,
    // @orig g_keyEndHeld
    keyEndHeld: u16 = 0,
    // @orig g_keyInsertHeld
    keyInsertHeld: u16 = 0,
    // @orig g_keyLeftUp (write-only)
    keyLeftUp: u16 = 0,
    // @orig g_playerMarkLevel (the energy-bar tile levels)
    playerMarkLevel: i16 = 91,
    // @orig g_opponentMarkLevel
    opponentMarkLevel: i16 = 91,
    // @orig g_lastClockTick (GetTickCount stamps of the handler's clock block)
    lastClockTick: u32 = 0,
    // @orig g_lastAnimTick
    lastAnimTick: u32 = 0,
    // @orig g_lastPumpTick
    lastPumpTick: u32 = 0,
    // @orig g_roundOver
    roundOver: u16 = 0,
    // @orig g_endTicks
    endTicks: i16 = 0,
    // @orig g_endReady (set on a player win's first end tick, or by
    // mane.WAV's MM_WOM_DONE: BUGS.md S6)
    endReady: u16 = 0,
    // @orig g_resultSent
    resultSent: u16 = 0,
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
    // @orig g_windowWidth / g_windowHeight
    windowWidth: i16 = 0,
    windowHeight: i16 = 0,
    // @orig g_messageText (message_box_printf's buffer)
    messageText: [100]u8 = @splat(0),
    // @orig g_fighter (the player, also `player`)
    fighter: ?*Object = null,
    // @orig g_opponent
    opponent: ?*Object = null,
    // @orig g_banner
    banner: ?*Object = null,
    // @orig g_energyBar
    energyBar: ?*Object = null,
    // @orig g_conditionTrue / g_conditionFalse initdata=skip (built by the
    // static initialiser init_static_conditions before WinMain)
    conditionTrue: world.Condition = .{ .kind = .flag, .value = 1 },
    conditionFalse: world.Condition = .{ .kind = .flag, .value = 0 },
    // @orig g_punch2Wave (soco2.wav)
    punch2Wave: ?platform.Wave = null,
    // @orig g_punchWave (soco.wav)
    punchWave: ?platform.Wave = null,
    // @orig g_pain4Wave (dor4.wav)
    pain4Wave: ?platform.Wave = null,
    // @orig g_pain2Wave (dor2.wav)
    pain2Wave: ?platform.Wave = null,
    // @orig g_kickWave (chute3.wav)
    kickWave: ?platform.Wave = null,
    // @orig g_boosWave (vaias.wav)
    boosWave: ?platform.Wave = null,
    // @orig g_maneWave (mane.WAV, the one wave played with a notify window)
    maneWave: ?platform.Wave = null,
    // @orig g_reactionRow
    reactionRow: i16 = 0,
    // @orig g_reactionCol
    reactionCol: i16 = 0,
    // @orig g_crtHoldRand (srand(time(NULL)) before every attack choice:
    // BUGS.md S5)
    rand: Rand = .{},
    // No counterpart: set once `opponent_choose_attack` has seeded `rand`
    // (only `salgin_seed_once` reads it).
    randSeeded: bool = false,
    // No counterpart: g_setSystemTimer / g_killSystemTimer (`setSystemTimer`),
    // g_instance, g_moduleHandle, g_modulePath(Buf) (the EXE's directory is
    // the host's `Program.dir`), g_game / g_salginGame (this Game), the
    // CRT's time-zone state (`time()` is `plat.unixTime()`).

    pub fn create(gpa: std.mem.Allocator, plat: Platform) !*Game {
        const g = try gpa.create(Game);
        g.* = .{ .gpa = gpa, .plat = plat, .heap = .init(gpa) };
        return g;
    }

    /// The task ends: its local heap goes with it (what SALGIN never frees,
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
            .message => |m| if (!g.post(m)) std.log.warn("salgin: posted queue full: message {x} lost", .{m.id}),
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
        h.sim.task_dirs[0] = "\\SALGIN";
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

test "SALGIN's Game builds with a headless platform" {
    var t = try TestGame.init(std.testing.allocator);
    defer t.deinit();
    const g = t.game;
    g.setSystemTimer(1, 50);
    t.headless.now = 50;
    try std.testing.expect(g.dispatchPending());
    try std.testing.expect(!g.dispatchPending());
}
