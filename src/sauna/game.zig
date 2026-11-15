//! Port unit `game` (module) of SAUNA.EXE. SaunaGame: ctor/dtor, GameVtbl 01-06 (createPlayer: Pacman; createInitScene, createControlPanel, createStatusBar NULL, onCreate), game_init (posts 0x401), game_take_exit, the conditions.
//!
//! SaunaGame is the only Game instantiated, so its GameVtbl overrides are
//! plain functions: `createPlayer` ... `onCreate` are slots 01-06, `init` is
//! the base `game_init` (slot 05). hwnd and hdc parameters are dropped
//! (GetDC / ReleaseDC have no counterpart; the window DC's PatBlt(BLACKNESS)
//! is over a clear size never set). Everything the original `new`s comes
//! from `g.local()`.

const std = @import("std");
const msg = @import("../core/msg.zig");
const Msg = msg.Msg;
const lists = @import("lists.zig");
const object_create = @import("object_create.zig");
const scene_unit = @import("scene.zig");
const maze = @import("maze.zig");
const panels = @import("panels.zig");
const occupancy = @import("behaviour/occupancy.zig");
const visibility = @import("behaviour/visibility.zig");
const render = @import("behaviour/render.zig");
const animation = @import("behaviour/animation.zig");
const space3d = @import("behaviour/space3d.zig");
const Game = @import("core/game.zig").Game;
const object = @import("core/object.zig");
const Object = object.Object;
const world = @import("core/world.zig");
const Scene = world.Scene;
const Condition = world.Condition;

// @orig 10a0:6c40 game_ctor
// @orig 1048:0000 sauna_game_ctor
/// SaunaGame constructor with the base `game_ctor` out of line: empty global
/// object list (capacity 30), empty update list, the draw list, no scene /
/// old scene / status bar / control panel / last global object, `unk55A` =
/// 2; then SaunaGame's vtable (`g_saunaGame`, `g_game` are `g`).
pub fn ctor(g: *Game) *Game {
    _ = lists.ctor(&g.globalObjects, 0x1e);
    _ = lists.updateCtor(&g.updateList);
    _ = lists.drawCtor(&g.drawList);
    g.scene = null;
    g.oldScene = null;
    g.unk55A = 2;
    g.statusBar = null;
    g.controlPanel = null;
    g.lastGlobalObject = null;
    return g;
}

// @orig 10a0:86fc game_dtor
/// Deletes the scene, the old scene if set (`scene_scalar_dtor(s, 1)`), the
/// player (`scene_object_scalar_dtor`), the control panel, the status bar,
/// then every global object.
pub fn dtor(g: *Game) void {
    if (g.scene) |s| _ = scene_unit.scalarDtor(g, s, 1);
    if (g.oldScene) |s| _ = scene_unit.scalarDtor(g, s, 1);
    if (g.player) |p| _ = object_create.sceneObjectScalarDtor(g, p, 1);
    if (g.controlPanel) |p| _ = panels.scalarDtor(g, p, 1);
    if (g.statusBar) |s| _ = panels.statusBarScalarDtor(g, s, 1);
    g.scene = null;
    g.oldScene = null;
    g.player = null;
    g.controlPanel = null;
    g.statusBar = null;
    lists.deleteAll(g, &g.globalObjects);
}

// @orig 10a0:86be game_scalar_dtor
/// Scalar deleting destructor: `dtor`, then `operator delete` of the Game
/// when bit 0 of `flags` is set (the Game's block is the host's: it is
/// freed by `Game.destroy`, so the flag has no effect here).
pub fn scalarDtor(g: *Game, flags: u16) *Game {
    dtor(g);
    _ = flags;
    return g;
}

/// GameVtbl slot 01 createPlayer: a Pacman (`new` 0x4f0) at x 300, y 304
/// from the nine strip tables, hit box 8, 8, 24 x 24, timer 0x10 / 55 ms,
/// steps 16, visible. It becomes `g_pacman`; nothing is set afterwards.
// @orig 1048:0042 sauna_game_create_player
pub fn createPlayer(g: *Game) ?*Object {
    const obj = g.local().create(Object) catch {
        // The original stores NULL in g_pacman and returns NULL.
        g.pacman = null;
        return null;
    };
    obj.* = .{ .kind = .pacman };
    object_create.pacmanCtor(
        g,
        obj,
        0x12c,
        0x130,
        9,
        &g.pacmanStripFiles,
        &g.pacmanStripFrames,
        &g.pacmanStripWidths,
        &g.pacmanStripHeights,
        8,
        8,
        0x18,
        0x18,
        0x10,
        0x37,
        0x10,
        0x10,
        1,
        0,
        true,
    ) catch |e| @panic(@errorName(e));
    g.pacman = obj;
    return obj;
}

/// GameVtbl slot 02 createInitScene: a SaunaScene (`new` 0x7a) through
/// `sauna_scene_ctor` (the clear size and flags it is passed are unused:
/// the base gets no status bar, a control panel, a player).
// @orig 1048:015c sauna_game_create_init_scene
pub fn createInitScene(g: *Game, name: []const u8) ?*Scene {
    const s = g.local().create(Scene) catch return null;
    s.* = .{};
    return scene_unit.saunaSceneCtor(g, s, name) catch |e| @panic(@errorName(e));
}

/// GameVtbl slot 03 createControlPanel: a ControlPanel (`new` 0x5a4,
/// `pacinter.bmp`, 640 x 48, one picture, timer 0xc / 55 ms) at x 0, y 0x250
/// (592: below the 480-pixel window), visible.
// @orig 1048:00e3 sauna_game_create_control_panel
pub fn createControlPanel(g: *Game) ?*Object {
    const obj = g.local().create(Object) catch return null;
    obj.* = .{ .kind = .control_panel };
    object_create.controlPanelCtor(g, obj, 0, 0x250, "pacinter.bmp", 1, 0x280, 0x30, 0xc, 0x37, 0, 1, 0, true) catch |e| @panic(@errorName(e));
    return obj;
}

/// GameVtbl slot 04 createStatusBar: NULL (SAUNA has no status bar).
// @orig 1048:0140 sauna_game_create_status_bar
pub fn createStatusBar(g: *Game) ?*Object {
    _ = g;
    return null;
}

/// GameVtbl slot 05 init (`game_init`, the base start-up, called by
/// `onCreate` with the scene name): the scene (createInitScene, then its
/// `create` builds the backdrop and the dots), the global objects, the
/// status bar (never), control panel and player (attached to the backdrop,
/// shown as the scene wants), the player's idle animation, and
/// `scene_started` posted.
// @orig 10a0:6cf4 game_init
pub fn init(g: *Game, name: []const u8) *Game {
    g.scene = createInitScene(g, name);
    const s = g.scene.?;
    _ = maze.create(g, s);
    lists.attachToScene(g, &g.globalObjects, s);
    g.statusBar = createStatusBar(g);
    if (g.statusBar) |sb| _ = occupancy.attach(g, sb, s.backdrop.?);
    g.controlPanel = createControlPanel(g);
    if (g.controlPanel) |cp| _ = occupancy.attach(g, cp, s.backdrop.?);
    g.player = createPlayer(g);
    if (g.player) |p| _ = occupancy.attach(g, p, s.backdrop.?);
    if (scene_unit.getHasPlayer(g, s)) visibility.show(g, g.player.?, s.backdrop.?);
    if (scene_unit.getHasStatusBar(g, s)) visibility.show(g, g.statusBar.?, s.backdrop.?);
    if (scene_unit.getHasControlPanel(g, s)) visibility.show(g, g.controlPanel.?, s.backdrop.?);
    if (scene_unit.getHasPlayer(g, s)) animation.playIdle(g, g.player.?, s.backdrop.?);
    _ = g.post(Msg.make(msg.noite.scene_started, 0, 0, 0));
    return g;
}

/// Scene switch through an exit of the current scene: the new scene
/// (createNewScene), the old one deleted, the new one's `create`, the global
/// objects and the player / status bar / control panel re-attached by its
/// flags, the player moved to the exit's target, a repaint and
/// `scene_started` posted. Dead in SAUNA (no Exit objects; `g_exitPending`
/// is never set). Returns `g`.
// @orig 1040:1711 game_take_exit
pub fn takeExit(g: *Game, exit_index: i16) *Game {
    const cur = g.scene.?;
    // exitSetLink's record: playerX in the low word of biWidth, playerY in
    // the high word.
    const ex = cur.exits[@intCast(exit_index)].?;
    const target_x: i16 = @truncate(ex.bmiHeader.biWidth);
    const target_y: i16 = @truncate(ex.bmiHeader.biWidth >> 16);
    g.oldScene = cur;
    g.scene = scene_unit.createNewScene(g, cur, exit_index);
    const s = g.scene.?;
    if (g.oldScene) |old| _ = scene_unit.scalarDtor(g, old, 1);
    g.oldScene = null;
    _ = maze.create(g, s);
    lists.attachToScene(g, &g.globalObjects, s);
    const bd = s.backdrop.?;
    if (scene_unit.getHasPlayer(g, s)) {
        g.player.?.linked = null;
        _ = occupancy.reattach(g, g.player.?, bd);
    }
    if (scene_unit.getHasStatusBar(g, s)) {
        _ = occupancy.reattach(g, g.statusBar.?, bd);
        visibility.show(g, g.statusBar.?, bd);
    }
    if (scene_unit.getHasControlPanel(g, s)) {
        _ = occupancy.reattach(g, g.controlPanel.?, bd);
        visibility.show(g, g.controlPanel.?, bd);
    }
    if (scene_unit.getHasPlayer(g, s)) {
        space3d.moveToAndDrop(g, g.player.?, target_x, target_y, bd);
        visibility.show(g, g.player.?, bd);
    }
    if (scene_unit.getHasStatusBar(g, s)) render.draw(g, g.statusBar.?, bd);
    if (scene_unit.getHasControlPanel(g, s)) render.draw(g, g.controlPanel.?, bd);
    if (scene_unit.getHasPlayer(g, s)) animation.playIdle(g, g.player.?, bd);
    // InvalidateRect(hwnd, NULL, FALSE)
    g.queue.paint_pending = true;
    _ = g.post(Msg.make(msg.noite.scene_started, 0, 0, 0));
    return g;
}

/// GameVtbl slot 06 onCreate (WM_CREATE): the base init with the scene name
/// "Labirinto", nothing else. Returns `g`.
// @orig 1048:01ab sauna_game_on_create
pub fn onCreate(g: *Game) *Game {
    _ = init(g, "Labirinto");
    return g;
}

// @orig 10a0:863c condition_ctor
/// The Condition base constructor: only its vtable.
pub fn conditionCtor(cond: *Condition) *Condition {
    cond.kind = .base;
    return cond;
}

// @orig 10a0:8482 flag_condition_ctor
/// FlagCondition constructor: the base, the FlagCondition vtable, the value.
pub fn flagConditionCtor(cond: *Condition, value: i16) *Condition {
    _ = conditionCtor(cond);
    cond.kind = .flag;
    cond.value = value;
    return cond;
}

// @orig 1050:0000 init_static_conditions
/// The static initialiser builds the two global FlagConditions (true = 1,
/// false = 0).
pub fn initStaticConditions(g: *Game) void {
    _ = flagConditionCtor(&g.conditionTrue, 1);
    _ = flagConditionCtor(&g.conditionFalse, 0);
}

// @orig 1050:00c3 init_static_conditions_entry (absorbed)
// The far stub in the static-init table (CALLF 1050:0000; RETF): the
// program root runs `initStaticConditions` itself.

/// ConditionVtbl slot 00 evaluate (FlagCondition).
// @orig 10a0:8506 flag_condition_evaluate
pub fn evaluate(cond: *const Condition) i16 {
    return cond.value;
}

/// ConditionVtbl slot 01 set (FlagCondition).
// @orig 10a0:84c2 flag_condition_set
pub fn set(cond: *Condition) void {
    cond.value = 1;
}

/// ConditionVtbl slot 02 clear (FlagCondition): returns 1.
// @orig 10a0:84e4 flag_condition_clear
pub fn clear(cond: *Condition) i16 {
    cond.value = 0;
    return 1;
}

const testing = std.testing;
const TestGame = @import("core/game.zig").TestGame;

// @orig 10a0:8506 flag_condition_evaluate oracle=documented
test "flag conditions: set, clear, evaluate" {
    var tg = try TestGame.init(testing.allocator);
    defer tg.deinit();
    const g = tg.game;
    initStaticConditions(g);
    try testing.expectEqual(@as(i16, 1), evaluate(&g.conditionTrue));
    try testing.expectEqual(@as(i16, 0), evaluate(&g.conditionFalse));
    set(&g.conditionFalse);
    try testing.expectEqual(@as(i16, 1), evaluate(&g.conditionFalse));
    try testing.expectEqual(@as(i16, 1), clear(&g.conditionFalse));
    try testing.expectEqual(@as(i16, 0), evaluate(&g.conditionFalse));
}
