//! ENCAIXE's state: the TetrisGame object (Game + TetrisGame flattened;
//! `g_game` and `g_tetrisGame` are both this) plus every DGROUP global of
//! ENCAIXE.EXE. One heap instance per running ENCAIXE (a host task), passed
//! as `*Game` to the units (docs/encaixe/DESIGN.md "State").
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
pub const piece_kinds = 6;

pub const Game = struct {
    gpa: std.mem.Allocator,
    plat: Platform,
    fixes: Fixes = .{},
    queue: Queue = .{},
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
    // @orig g_unk0012 (read by the draw code; the sprites' transparent index)
    unk0012: u8 = 0x0b,
    // @orig g_noiteWnd (NOITE's window, from 0x40b; 0 when run alone)
    noiteWnd: msg.Hwnd = 0,
    // @orig g_score
    score: i16 = 0,
    // @orig g_started
    started: u16 = 0,
    // @orig g_handshakePending (DGROUP data 1: 0x40c is still to be posted)
    handshakePending: u16 = 1,
    // @orig g_keyLeft / g_keyRight / g_keyUp / g_keyDown
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
    // @orig g_pieceStripFiles initdata=skip (near pointers to the DGROUP
    // file names)
    pieceStripFiles: [piece_kinds][]const u8 = .{ "peca.bmp", "pecaa.bmp", "pecab.bmp", "pecac.bmp", "pecad.bmp", "pecae.bmp" },
    // @orig g_pieceStripFrames
    pieceStripFrames: [piece_kinds]i16 = @splat(4),
    // @orig g_pieceStripWidths
    pieceStripWidths: [piece_kinds]i16 = @splat(128),
    // @orig g_pieceStripHeights
    pieceStripHeights: [piece_kinds]i16 = @splat(128),
    // @orig g_pieceKeyRight / g_pieceKeyLeft / g_pieceKeyUp / g_pieceKeyDown
    pieceKeyRight: u16 = 0,
    pieceKeyLeft: u16 = 0,
    pieceKeyUp: u16 = 0,
    pieceKeyDown: u16 = 0,
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
    // @orig g_piece
    piece: ?*Object = null,
    // @orig g_conditionTrue / g_conditionFalse initdata=skip (built by the
    // static initialiser 1010:002e before WinMain)
    conditionTrue: world.Condition = .{ .kind = .flag, .value = 1 },
    conditionFalse: world.Condition = .{ .kind = .flag, .value = 0 },
    // @orig g_tetrisWave
    tetrisWave: ?platform.Wave = null,
    // @orig g_crtHoldRand
    rand: Rand = .{},
    // No counterpart: g_setSystemTimer / g_killSystemTimer (`setSystemTimer`),
    // g_instance, g_moduleHandle, g_modulePath(Buf) (the EXE's directory is
    // the host's `Program.dir`).

    pub fn create(gpa: std.mem.Allocator, plat: Platform) !*Game {
        const g = try gpa.create(Game);
        g.* = .{ .gpa = gpa, .plat = plat };
        return g;
    }

    pub fn destroy(g: *Game) void {
        g.gpa.destroy(g);
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
            .message => |m| if (!g.post(m)) std.log.warn("encaixe: posted queue full: message {x} lost", .{m.id}),
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
        h.sim.task_dirs[0] = "\\ENCAIXE";
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

test "ENCAIXE's Game builds with a headless platform" {
    var t = try TestGame.init(std.testing.allocator);
    defer t.deinit();
    const g = t.game;
    g.setSystemTimer(1, 50);
    t.headless.now = 50;
    try std.testing.expect(g.dispatchPending());
    try std.testing.expect(!g.dispatchPending());
}
