//! JARDIM's state: the JardimGame object (Game + JardimGame flattened;
//! `g_game` and `g_jardimGame` are both this) plus every DGROUP global of
//! JARDIM.EXE. One heap instance per running JARDIM (a host task), passed
//! as `*Game` to the units (docs/jardim/DESIGN.md "State").
//!
//! The Win16 replacements (message queue and timers, `send`/`post`,
//! SetSystemTimer) are the same as NOITE's and TIRO's `Game`, over the
//! shared `core/queue.zig`; this game's platform is its task's (`host.zig`).

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
const crt = @import("../../core/crt.zig");
const enemies = @import("../enemies.zig");

/// The window procedure (`AppWndProc`, unit `app`); returns the LRESULT.
pub const WndProc = *const fn (g: *Game, m: Msg) i32;

pub const max_waves = 20;

/// One strip table (`g_playerStrip*`, `g_handsNStrip*`): file, frames,
/// frame width and height per strip.
pub fn StripTable(comptime n: usize) type {
    return struct {
        files: [n][]const u8,
        frames: [n]i16,
        widths: [n]i16,
        heights: [n]i16,
    };
}

/// Platform emulation, not a fix (both versions): what one game tick's frame cost a period
/// PC (a 486DX2-66 drawing the 480×300 raycast view, ~10 frames a second). Windows 3.1
/// makes a timer's message only when the queue is empty and never queues missed periods, so
/// a frame slower than the timer lowers the tick rate; the port draws at once. After a tick
/// the game's timers (1 and 10) give no message for this long (`labyrinth_input`,
/// `Queue.postpone`). One place to tune it (docs/jardim/DESIGN.md "Platform: frame cost").
pub const render_cost_ms: u32 = 100;

/// `fixes.jardim_smooth_movement`'s state (`wolf.zig`).
pub const WolfState = struct {
    /// The clock at the last motion step (ms).
    lastMs: u32 = 0,
    /// Thousandths of a 70-Hz tic not yet run.
    ticAcc: u32 = 0,
    /// The player's position below the unit (1/65536 unit).
    fracX: i32 = 0,
    fracY: i32 = 0,
    /// Scroll remainders: angle units for the sky (6 a pixel) and the floor
    /// (3 a pixel), 1/65536 units for the floor's forward scroll.
    skyAcc: i32 = 0,
    floorXAcc: i32 = 0,
    floorYAcc: i32 = 0,
    /// Game ticks (timer 1) so far, and the one of the last repeated touch
    /// (an enemy pressed into without J6's fix: once a game tick).
    gameTick: u32 = 0,
    touchedTick: u32 = 0xffff_ffff,
};

/// J6's fix: an enemy in contact (`labyrinth_input.touchObject`).
pub const Contact = struct { obj: ?*Object = null };

/// `fixes.jardim_controls_screen`'s state (`controls.zig`).
pub const ControlsState = struct {
    /// The screen is up: the game gets no input and no timer.
    up: bool = false,
    /// When it went up.
    shownAt: u32 = 0,
    /// The key that took it down: its repeats and release stay out.
    heldKey: ?u16 = null,
};

pub const Game = struct {
    gpa: std.mem.Allocator,
    plat: Platform,
    fixes: Fixes = .{},
    queue: Queue = .{},
    /// The task's heap (`_fmalloc` / `operator new`); freed with the Game.
    heap: std.heap.ArenaAllocator,
    wndProc: WndProc = noWndProc,
    /// Message log for trace diffing (null = off).
    trace: ?*std.ArrayList(u8) = null,
    /// WM_QUIT came: the message loop ends.
    quit: bool = false,

    // ---- struct Game (0x560 with JardimGame) ----
    // @orig Game+0x4
    scene: ?*world.Scene = null,
    // @orig Game+0x8 (held while the old scene is deleted)
    oldScene: ?*world.Scene = null,
    // @orig Game+0xc (NULL: createStatusBar builds none)
    statusBar: ?*Object = null,
    // @orig Game+0x10
    controlPanel: ?*Object = null,
    // @orig Game+0x18 (the hidden Player)
    player: ?*Object = null,
    // @orig Game+0x1c
    globalObjects: ObjectList = .{},
    updateList: world.UpdateList = .{},
    drawList: world.DrawList = .{},

    // ---- DGROUP globals ----
    // @orig g_unk0010 (the sprites' transparent colour index)
    spriteKey: u8 = 0x0a,
    // @orig g_noiteWnd (FindWindow("Noite Animal") or 0x40b's lParam; 0 alone)
    noiteWnd: msg.Hwnd = 0,
    // @orig g_started
    started: i16 = 0,
    // @orig g_noiteAcked (NOITE's 0x40a seen: stop re-posting 0x40c)
    noiteAcked: i16 = 0,
    // @orig g_handsBobPos
    handsBobPos: i16 = 0,
    // @orig g_handsBobStep
    handsBobStep: i16 = 2,
    // @orig g_startX initdata=skip (Ghidra types it a byte: 912, col 28)
    startX: i16 = 912,
    // @orig g_startY (48, row 1)
    startY: i16 = 48,
    // @orig g_carryHealth
    carryHealth: i16 = 100,
    // @orig g_carryLives
    carryLives: i16 = 3,
    // @orig g_carryAmmo
    carryAmmo: i16 = 0,
    // @orig g_carryLevel
    carryLevel: i16 = 1,
    // @orig g_carryScore (+500 per finished phase)
    carryScore: i16 = 0,
    // @orig g_curWeapon (the hands' strip carried to the next phase)
    curWeapon: i16 = 0,
    // @orig g_startTick (GetTickCount of the first labyrinth; BUGS.md J1)
    startTick: u32 = 0,
    // @orig g_variant (0x40b's wParam: 1 espquete, 0 4fjarvamp; BUGS.md J7)
    variant: i16 = 0,
    // @orig g_startTickPending
    startTickPending: i16 = 1,
    // @orig g_keyRightDown
    keyRightDown: i16 = 0,
    // @orig g_keyLeftDown
    keyLeftDown: i16 = 0,
    // @orig g_keyUpDown
    keyUpDown: i16 = 0,
    // @orig g_keyDownDown
    keyDownDown: i16 = 0,
    // @orig g_keysDownCount
    keysDownCount: i16 = 0,
    // @orig g_lastMoveKey
    lastMoveKey: i16 = 0,
    // @orig g_keyAltContext (written only)
    keyAltContext: i16 = 0,
    // No counterpart: J6's fix (`fixes.jardim_enemy_once_per_contact`): the
    // enemies (each kind is one object) the player is in contact with.
    contacts: [4]Contact = @splat(.{}),
    // No counterpart: the Corrigida's Wolf3D movement (`wolf.zig`).
    wolf: WolfState = .{},
    // No counterpart: the Corrigida's controls screen (`controls.zig`).
    controls: ControlsState = .{},
    // No counterpart: a frame that only shows the view (`wolf.zig`'s motion
    // frames): the hands do not sway, the enemies neither act nor animate.
    viewOnly: bool = false,
    // No counterpart: the Corrigida's fair enemies (`enemies.zig`).
    fair: enemies.FairState = .{},
    // No counterpart: JARDIM has no rand(); the fair enemies' reaction times use the CRT's
    // generator, never seeded (so a run depends only on the input's times from WM_CREATE).
    rand: crt.Rand = .{},
    // @orig g_shotSecLo / g_shotSecHi (tables[5] at the firing angle)
    shotSec: i32 = 1,
    // @orig g_shotCscLo / g_shotCscHi (tables[6] at the firing angle)
    shotCsc: i32 = 1,
    // @orig g_shotCellObject (the object the shot displaced from its cell)
    shotCellObject: ?*Object = null,
    // @orig g_nextId
    nextId: i16 = 0,
    // @orig g_messageText (message_box_printf's buffer)
    messageText: [100]u8 = @splat(0),
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
    // @orig g_playerStripFiles initdata=skip (the five files are not on the disc)
    playerStrips: StripTable(5) = .{
        .files = .{ "passo1.bmp", "passladd.bmp", "passlade.bmp", "passolau.bmp", "passtras.bmp" },
        .frames = .{ 1, 8, 8, 8, 8 },
        .widths = @splat(166),
        .heights = @splat(265),
    },
    // @orig g_hands1StripFiles initdata=skip (fists, crossbow, bra)
    hands1Strips: StripTable(3) = .{
        .files = .{ "maos1.bmp", "maobest1.bmp", "maosuti.bmp" },
        .frames = @splat(2),
        .widths = @splat(230),
        .heights = @splat(85),
    },
    // @orig g_hands2StripFiles initdata=skip (fists, crossbow, bazooka)
    hands2Strips: StripTable(3) = .{
        .files = .{ "maos2.bmp", "maobest2.bmp", "maobazu2.bmp" },
        .frames = @splat(2),
        .widths = @splat(230),
        .heights = @splat(85),
    },
    // @orig g_hands3StripFiles initdata=skip
    hands3Strips: StripTable(3) = .{
        .files = .{ "maos3.bmp", "maobest3.bmp", "maobazu3.bmp" },
        .frames = @splat(2),
        .widths = @splat(230),
        .heights = @splat(85),
    },
    // @orig g_waveMixOpenResult
    waveMixOpenResult: i16 = 0,
    // @orig g_waveMixSession
    waveMixSession: platform.MixSession = 0,
    // The wave table at 10d0:0606 (unnamed in Ghidra).
    waves: [max_waves]?platform.Wave = @splat(null),
    // @orig g_waveCount
    waveCount: i16 = 0,
    // @orig g_labyrinthTables initdata=skip (far pointers; unit `tables`;
    // never freed in the original)
    tables: world.Tables = .{},
    // @orig g_columnDepth (each view column's wall distance: the sprites'
    // depth buffer)
    columnDepth: [world.view_columns]i32 = @splat(0),
    // @orig g_hudTextBuffer initdata=skip (the HUD's sprintf buffer, right
    // after g_columnDepth: the sprites' clip reads its first dword)
    hudTextBuffer: [16]u8 = @splat(0),
    // @orig g_appActive
    appActive: i16 = 0,
    // @orig g_phase1Waves (g_phase1Waves[7]/[8] are swapped against the
    // name order, docs/jardim/DATA.md)
    phase1Waves: [15]?platform.Wave = @splat(null),
    // @orig g_phase2Waves
    phase2Waves: [16]?platform.Wave = @splat(null),
    // @orig g_phase3Waves ([0] is never opened: Chato's attack is silent)
    phase3Waves: [16]?platform.Wave = @splat(null),
    // CreateWindow's result (an app_init word, 10d0:188a-1898): plat.windowHandle().
    mainWindow: msg.Hwnd = 0,
    // The two static FlagConditions init_static_conditions builds before
    // WinMain (unlabelled in Ghidra).
    conditionTrue: world.Condition = .{ .kind = .flag, .value = 1 },
    conditionFalse: world.Condition = .{ .kind = .flag, .value = 0 },
    // No counterpart: g_setSystemTimer / g_killSystemTimer (`setSystemTimer`),
    // g_moduleHandle, g_biosTickPtr (dead), g_angleRadians and the FP
    // constants (unit `tables`: precomputed), the minimap's pens and brushes (colours in unit `hud`),
    // g_occupancyCount/Object (the occupancy grid is dead in JARDIM),
    // g_game / g_jardimGame (this Game).

    pub fn create(gpa: std.mem.Allocator, plat: Platform) !*Game {
        const g = try gpa.create(Game);
        g.* = .{ .gpa = gpa, .plat = plat, .heap = .init(gpa) };
        return g;
    }

    /// The task ends: its heap goes with it (what JARDIM never frees: the
    /// tables, the backdrops, the phases' Portables, is not a leak here).
    pub fn destroy(g: *Game) void {
        g.heap.deinit();
        g.gpa.destroy(g);
    }

    /// The task's heap (`_fmalloc` / `operator new`). Objects the original
    /// never frees are allocated here.
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

    /// A platform event, as Windows hands it to the program.
    pub fn deliver(g: *Game, ev: platform.Event) void {
        switch (ev) {
            .quit => _ = g.send(.{ .id = msg.wm.close }),
            .activate => |on| _ = g.send(.{ .id = msg.wm.activate, .wparam = @intFromBool(on) }),
            .input => |m| if (g.plat.filterInput(m)) |in| g.queue.postInput(in),
            .message => |m| if (!g.post(m)) std.log.warn("jardim: posted queue full: message {x} lost", .{m.id}),
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
        h.sim.task_dirs[0] = "\\JARDIM";
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

test "JARDIM's Game builds with a headless platform" {
    var t = try TestGame.init(std.testing.allocator);
    defer t.deinit();
    const g = t.game;
    g.setSystemTimer(1, 55);
    t.headless.now = 55;
    try std.testing.expect(g.dispatchPending());
    try std.testing.expect(!g.dispatchPending());
}
