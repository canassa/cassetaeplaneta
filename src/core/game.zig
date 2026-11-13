//! The game state: the original's Game object (struct `Game`, classes
//! Game/IniGame/NoiteGame flattened) plus every engine DGROUP global. One
//! `Game` exists, heap-allocated (stable address), passed as `*Game` to
//! engine, behaviour and handler code (docs/DESIGN.md "State").

const std = @import("std");
const msg = @import("msg.zig");
const Msg = msg.Msg;
const Queue = @import("queue.zig").Queue;
const TimerKind = @import("queue.zig").TimerKind;
const Fixes = @import("fixes.zig").Fixes;
const object = @import("object.zig");
const Object = object.Object;
const ObjectList = object.ObjectList;
const world = @import("world.zig");
const modstate = @import("modstate.zig");
const handler = @import("handler.zig");
const Rand = @import("crt.zig").Rand;
const platform = @import("../platform/platform.zig");
const Platform = platform.Platform;

pub const max_minigames = 5;
pub const max_picked = 3;

/// The window procedure (`AppWndProc`, unit `app`); returns the LRESULT.
pub const WndProc = *const fn (g: *Game, m: Msg) i32;

pub const Game = struct {
    gpa: std.mem.Allocator,
    /// Per-scene scratch (backdrop pixels, loader temporaries); reset by
    /// the scene switch.
    scene_arena: std.heap.ArenaAllocator,
    plat: Platform,
    fixes: Fixes = .{},
    queue: Queue = .{},
    wndProc: WndProc = noWndProc,
    /// Message log for trace diffing (null = off).
    trace: ?*std.ArrayList(u8) = null,
    quit: bool = false,

    // ---- struct Game ----
    // @orig Game+0x4
    scene: ?*world.Scene = null,
    // @orig Game+0x8 (held while the old scene is deleted)
    oldScene: ?*world.Scene = null,
    // @orig Game+0xc
    prevSceneNumber: i16 = 0,
    // @orig Game+0xe
    statusBar: ?*Object = null,
    // @orig Game+0x12
    controlPanel: ?*Object = null,
    // @orig Game+0x1a
    player: ?*Object = null,
    // @orig Game+0x1e (portable/static objects of the whole game)
    globalObjects: ObjectList = .{},
    // @orig Game+0x26
    lastGlobalObject: ?*Object = null,
    // @orig Game+0x2a
    updateList: world.UpdateList = .{},
    // @orig Game+0x1bc
    drawList: world.DrawList = .{},
    // @orig Game+0x674 (ctor writes 2, never read)
    unk674: u16 = 0,
    // @orig Game+0x676 (never written; BUGS.md U3)
    clearWidth: i16 = 0,
    // @orig Game+0x678
    clearHeight: i16 = 0,
    // @orig Game+0x67a
    itemSelected: i16 = 0,
    // @orig Game+0x67c
    selectedItem: ?*Object = null,
    // @orig Game+0x680
    iniFile: platform.File = 0,
    // @orig Game+0x682 (points at the current scene's INI section name)
    curSceneName: [20]u8 = @splat(0),
    // @orig Game+0x686
    exitPending: i16 = 0,
    // @orig Game+0x688 ([0] ENCAIXE, [1] TIRO, [2] SERIAL, [3] XILINDRO, [4] SAUNA)
    minigameWon: [max_minigames]i16 = @splat(0),
    // @orig Game+0x692 (items consumed by exits or correct use)
    usedObjects: ObjectList = .{},
    // @orig Game+0x69a
    pickedItems: [max_picked]world.PickedItem = @splat(.{}),
    // @orig Game+0x6be
    pickActive: u16 = 0,
    // @orig Game+0x6c0
    pickArmed: u16 = 0,
    // @orig Game+0x6c2
    pickRetry: u16 = 0,
    // @orig Game+0x6c4
    pickAdded: u16 = 0,
    // @orig Game+0x6c6
    pickedCount: u8 = 0,

    // ---- DGROUP globals ----
    // @orig g_nextId
    nextId: i16 = 0,
    // @orig g_keyLeft / g_keyRight / g_keyUp / g_keyDown
    keyLeft: u16 = 0,
    keyRight: u16 = 0,
    keyUp: u16 = 0,
    keyDown: u16 = 0,
    // @orig g_unk001A
    unk001A: u16 = 0,
    // @orig g_unk001C (the transparent colour index of the sprite blits;
    // DGROUP data 0x0b, never written)
    unk001C: u8 = 0x0b,
    // @orig g_newObject (the object just created; read on 0x406)
    newObject: ?*Object = null,
    // @orig g_aviPlaying
    aviPlaying: ?*Object = null,
    // @orig g_lives
    lives: i16 = 0,
    // @orig g_score
    score: i32 = 0,
    // @orig g_driveCD (CASSETUP.INI DriveCD)
    driveCD: [256]u8 = @splat(0),
    // @orig g_driveHD
    driveHD: [256]u8 = @splat(0),
    // @orig g_baseDir
    baseDir: [256]u8 = @splat(0),
    // g_assetRoot (1050:0330) is a far pointer initialised to &g_driveCD and
    // never written (wave_open is its only reader): code uses `driveCD`.
    // @orig g_appInitialized
    appInitialized: u16 = 0,
    // @orig g_skipMusicReplay
    skipMusicReplay: u16 = 0,
    // @orig g_registeredHandlers initdata=skip (entry 0 starts as the stub
    // 1018:6aca; register_scene_handlers clears the table before filling it)
    handlers: [handler.max_handlers]?handler.Handler = @splat(null),
    // @orig g_hitObject
    hitObject: ?*Object = null,
    // @orig g_unk097C
    unk097C: ?*Object = null,
    // @orig g_inputLocked
    inputLocked: u16 = 0,
    // @orig g_gameName initdata=skip (a far pointer to the code-segment
    // literal 1018:c568: the INI the game object loads)
    gameName: [:0]const u8 = "Casseta",
    // @orig g_windowTitle (DGROUP data, no terminating NUL; also the window
    // class and caption)
    windowTitle: [12]u8 = "Noite Animal".*,
    // @orig g_savedPosition
    savedPosition: world.SavedPosition = .{},
    // @orig g_slotScreenSaves (1 = salvar2 saves, 0 = loads)
    slotScreenSaves: i16 = 0,
    // @orig g_appActive
    appActive: u16 = 0,
    // @orig g_musicMciResult
    musicMciResult: u32 = 0,
    // @orig g_mciErrorText
    mciErrorText: [200]u8 = @splat(0),
    // @orig g_windowWidth / g_windowHeight
    windowWidth: i16 = 0,
    windowHeight: i16 = 0,
    // @orig g_conditionTrue / g_conditionFalse (BSS 1030) initdata=skip
    // (built by the C++ static initialisers before WinMain)
    conditionTrue: world.Condition = .{ .kind = .flag, .value = 1 },
    conditionFalse: world.Condition = .{ .kind = .flag, .value = 0 },
    // @orig g_crtHoldRand
    rand: Rand = .{},
    // Shared sprintf buffers (unnamed DGROUP areas; sizes up to the next
    // global). Whoever formats into one owns it until the next call, as in
    // the original.
    // @orig DGROUP 9d26 (concat_strings)
    concatBuf: [256]u8 = @splat(0),
    // @orig DGROUP 7cd6 (message_box_printf)
    messageBuf: [100]u8 = @splat(0),
    // @orig DGROUP 9e28 (wave_open's PAN\WAV fallback path)
    wavePathBuf: [50]u8 = @splat(0),
    // @orig DGROUP 13d8 (load_dib's PAN\BMP fallback path)
    dibPathBuf: [50]u8 = @splat(0),
    ini: modstate.Ini = .{},
    sound: modstate.Sound = .{},
    // Memory the original never frees (not a global of the original). Win16
    // frees a task's global memory when it ends, so these blocks stay
    // allocated for the rest of the run, as in the original, and `main`
    // releases them after app_exit (`reclaimLeaks`).
    leakedObjects: std.ArrayList(*Object) = .empty,
    leakedDibs: std.ArrayList(*object.Dib) = .empty,
    /// The scene handlers' globals (`handler.SceneStates`).
    scenes: handler.SceneStates = .{},

    pub fn create(gpa: std.mem.Allocator, plat: Platform) !*Game {
        const g = try gpa.create(Game);
        g.* = .{ .gpa = gpa, .scene_arena = .init(gpa), .plat = plat };
        return g;
    }

    pub fn destroy(g: *Game) void {
        g.leakedObjects.deinit(g.gpa);
        g.leakedDibs.deinit(g.gpa);
        g.scene_arena.deinit();
        g.gpa.destroy(g);
    }

    /// Parks an object the original leaks (see `leakedObjects`). Out of
    /// memory for the list: the object is simply lost, as in the original.
    pub fn leakObject(g: *Game, obj: *Object) void {
        g.leakedObjects.append(g.gpa, obj) catch {};
    }

    /// Parks a DIB the original leaks (see `leakedObjects`).
    pub fn leakDib(g: *Game, d: *object.Dib) void {
        g.leakedDibs.append(g.gpa, d) catch {};
    }

    /// Frees the parked DIBs (the parked objects need the units' destructors:
    /// `main` deletes them first). What Windows does when the task ends.
    pub fn reclaimLeakedDibs(g: *Game) void {
        for (g.leakedDibs.items) |d| {
            g.gpa.free(d.bits);
            g.gpa.destroy(d);
        }
        g.leakedDibs.clearRetainingCapacity();
    }

    /// A handler's globals: `const s = g.sceneState(State);`.
    pub fn sceneState(g: *Game, comptime T: type) *T {
        return handler.stateOf(&g.scenes, T);
    }

    // ---- USER replacements (message queue and timers) ----

    /// SendMessage(main window): dispatched at once, nested.
    pub fn send(g: *Game, m: Msg) i32 {
        g.log('S', m);
        return g.wndProc(g, m);
    }

    /// PostMessage(main window); false when the queue is full.
    pub fn post(g: *Game, m: Msg) bool {
        return g.queue.post(m);
    }

    /// SetTimer(main window, id, ms) → WM_TIMER.
    pub fn setTimer(g: *Game, id: u16, ms: u16) void {
        _ = g.queue.setTimer(.normal, id, ms, g.plat.ticks());
    }
    pub fn killTimer(g: *Game, id: u16) void {
        _ = g.queue.killTimer(.normal, id);
    }
    /// PostQuitMessage: sets the queue's quit flag (it cannot fail); WM_QUIT
    /// comes once the posted messages are drained.
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

    /// Main loop step: dispatch every message due now. Returns false when
    /// the queue is empty.
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

    fn log(g: *Game, how: u8, m: Msg) void {
        const t = g.trace orelse return;
        var buf: [64]u8 = undefined;
        const line = std.fmt.bufPrint(&buf, "{d} {c} {x:0>4} {x:0>4} {x:0>8}\n", .{
            g.plat.ticks(), how, m.id, m.wparam, @as(u32, @bitCast(m.lparam)),
        }) catch return;
        t.appendSlice(g.gpa, line) catch {};
    }
};

/// A `Game` over a headless platform, for unit tests:
///
///     var t = try TestGame.init(std.testing.allocator);
///     defer t.deinit();
///     const g = t.game;
///
/// No window procedure is installed (set `g.wndProc` to dispatch).
pub const TestGame = struct {
    headless: *Headless,
    game: *Game,

    pub fn init(gpa: std.mem.Allocator) !TestGame {
        const h = try gpa.create(Headless);
        errdefer gpa.destroy(h);
        h.* = Headless.init(gpa, std.testing.io, .{});
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
const Headless = @import("../platform/headless.zig").Headless;

/// Until the `app` unit is ported there is no window procedure.
fn noWndProc(_: *Game, _: Msg) i32 {
    return 0;
}

test "Game builds with a headless platform" {
    var t = try TestGame.init(std.testing.allocator);
    defer t.deinit();
    const g = t.game;
    g.setSystemTimer(1, 50);
    t.headless.now = 50;
    try std.testing.expect(g.dispatchPending());
    try std.testing.expect(!g.dispatchPending());
}
