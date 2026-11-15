//! Port unit `game` (module) of JARDIM.EXE. JardimGame + Game: ctor/dtor, GameVtbl 01-06 (createPlayer: the hidden Player; the panel; no status bar; Phase1Scene), game_init, game_take_exit, the conditions.
//!
//! JardimGame is the only Game instantiated, so its GameVtbl overrides are
//! plain functions: `createPlayer` ... `onCreate` are slots 01-06, `init` is
//! the base `game_init` (slot 05). hwnd and hdc parameters are dropped
//! (GetDC / ReleaseDC have no counterpart; the window DC's PatBlt(BLACKNESS)
//! is over a clear size never set). Everything the original `new`s comes from
//! `g.local()`.

const std = @import("std");
const msg = @import("../core/msg.zig");
const Msg = msg.Msg;
const lists = @import("lists.zig");
const object_create = @import("object_create.zig");
const scene_unit = @import("scene.zig");
const labyrinth_scene = @import("labyrinth_scene.zig");
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

// @orig 10c0:6fc2 game_ctor
// @orig 1090:0000 jardim_game_ctor
/// JardimGame constructor with the base `game_ctor` out of line: empty global
/// object list (capacity 30), empty update list, the draw list, no scene /
/// old scene / status bar / control panel (+0x24 is a word nothing reads);
/// then JardimGame's vtable (`g_jardimGame`, `g_game` are `g`). The base
/// leaves `player` (+0x18) alone, as here.
pub fn ctor(g: *Game) *Game {
    _ = lists.ctor(&g.globalObjects, 0x1e);
    _ = lists.updateCtor(&g.updateList);
    _ = lists.drawCtor(&g.drawList);
    g.scene = null;
    g.oldScene = null;
    g.statusBar = null;
    g.controlPanel = null;
    return g;
}

// @orig 10c0:2956 game_dtor
/// Deletes the scene, the old scene if set, the player, the control panel,
/// the status bar, then every global object.
pub fn dtor(g: *Game) void {
    if (g.scene) |s| _ = scene_unit.scalarDtor(g, s, 1);
    if (g.oldScene) |s| _ = scene_unit.scalarDtor(g, s, 1);
    if (g.player) |p| _ = object_create.sceneObjectScalarDtor(g, p, 1);
    if (g.controlPanel) |p| _ = object_create.controlPanelScalarDtor(g, p, 1);
    if (g.statusBar) |s| _ = object_create.statusBarScalarDtor(g, s, 1);
    object_create.objectListDeleteAll(g, &g.globalObjects);
}

// @orig 10c0:0000 game_scalar_dtor
/// Scalar deleting destructor: `dtor`, then `operator delete` of the Game when
/// bit 0 of `flags` is set (the Game's block is the host's: freed by
/// `Game.destroy`, so the flag has no effect here).
pub fn scalarDtor(g: *Game, flags: u16) *Game {
    dtor(g);
    _ = flags;
    return g;
}

/// GameVtbl slot 01 createPlayer: a Player (`new` 0x516), the first-person
/// dummy: x 0, y 0, `passo1.bmp` (166 x 265, one frame), hit box 0x21, 0,
/// 100 x 265, timer 0xd / 100 ms, steps 0x19 / 10, NOT visible. Nothing is
/// set afterwards.
// @orig 1090:0042 jardim_game_create_player
pub fn createPlayer(g: *Game) ?*Object {
    const obj = g.local().create(Object) catch return null;
    obj.* = .{ .kind = .player };
    object_create.playerCtor(g, obj, 0, 0, "passo1.bmp", 1, 0xa6, 0x109, 0x21, 0, 100, 0x109, 0xd, 100, 0x19, 10, 0, 0, true) catch |e| @panic(@errorName(e));
    return obj;
}

/// GameVtbl slot 02 createInitScene: a Phase1Scene (`new` 0x90) through
/// `phase1_scene_ctor` (480 x 640, flags 0 1 0).
// @orig 1090:014d jardim_game_create_init_scene
pub fn createInitScene(g: *Game, name: []const u8) ?*Scene {
    return labyrinth_scene.ctor(g, .one, name) catch null;
}

/// GameVtbl slot 03 createControlPanel: a ControlPanel (`new` 0x5a4,
/// `labinter.bmp`, 640 x 138, one picture, timer 0xc / 55 ms) at x 0, y 0x156,
/// visible.
// @orig 1090:00d3 jardim_game_create_control_panel
pub fn createControlPanel(g: *Game) ?*Object {
    const obj = g.local().create(Object) catch return null;
    obj.* = .{ .kind = .control_panel };
    object_create.controlPanelCtor(g, obj, 0, 0x156, "labinter.bmp", 1, 0x280, 0x8a, 0xc, 0x37, 0, 1, 0, true) catch |e| @panic(@errorName(e));
    return obj;
}

/// GameVtbl slot 04 createStatusBar: NULL (the HUD is the backdrop's).
// @orig 1090:0131 jardim_game_create_status_bar
pub fn createStatusBar(g: *Game) ?*Object {
    _ = g;
    return null;
}

/// GameVtbl slot 05 init (`game_init`, called by `onCreate` with the scene
/// name; GetDC / PatBlt / ReleaseDC dropped): the scene (createInitScene, then
/// its `create` builds the backdrop), the global objects, the status bar,
/// control panel and player (each attached to the backdrop when built), the
/// ones the scene wants shown, the player's idle animation, and
/// `scene_started` posted.
// @orig 10c0:2a7a game_init
pub fn init(g: *Game, name: []const u8) *Game {
    g.scene = createInitScene(g, name);
    const s = g.scene.?;
    _ = s.create(g);
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

/// Scene switch through an exit of the current scene (0x402): the new scene
/// (createNewScene), the old one deleted, the new one's `create`, the global
/// objects and the player / status bar / control panel re-attached by its
/// flags, the player moved to the exit's target, a repaint and
/// `scene_started` posted. Unlike TIRO's, `create` runs after the old scene's
/// deletion. Returns `g`.
// @orig 1058:16ff game_take_exit
pub fn takeExit(g: *Game, exit_index: i16) *Game {
    const cur = g.scene.?;
    const ex = cur.exits[@intCast(exit_index)].?;
    const target_x: i16 = ex.exit.playerX;
    const target_y: i16 = ex.exit.playerY;
    g.oldScene = cur;
    g.scene = cur.createNewScene(g, exit_index);
    if (g.oldScene) |old| _ = scene_unit.scalarDtor(g, old, 1);
    g.oldScene = null;
    const s = g.scene.?;
    _ = s.create(g);
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
/// "Labirinto". Returns `g`.
// @orig 1090:01a4 jardim_game_on_create
pub fn onCreate(g: *Game) *Game {
    _ = init(g, "Labirinto");
    return g;
}

// @orig 10c0:6226 condition_ctor
/// The Condition base constructor: only its vtable.
pub fn conditionCtor(cond: *Condition) *Condition {
    cond.kind = .base;
    return cond;
}

// @orig 10c0:606c flag_condition_ctor
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

/// ConditionVtbl slot 00 evaluate (FlagCondition): the flag.
// @orig 10c0:60f0 flag_condition_evaluate
pub fn evaluate(cond: *const Condition) i16 {
    return cond.value;
}

/// ConditionVtbl slot 01 set (FlagCondition): flag = 1, returns 1.
// @orig 10c0:60ac flag_condition_set
pub fn set(cond: *Condition) i16 {
    cond.value = 1;
    return 1;
}

/// ConditionVtbl slot 02 clear (FlagCondition): flag = 0, returns 1.
// @orig 10c0:60ce flag_condition_clear
pub fn clear(cond: *Condition) i16 {
    cond.value = 0;
    return 1;
}

const testing = std.testing;
const TestGame = @import("core/game.zig").TestGame;

// @orig 10c0:60f0 flag_condition_evaluate oracle=documented
test "flag conditions: set, clear, evaluate" {
    var tg = try TestGame.init(testing.allocator);
    defer tg.deinit();
    const g = tg.game;
    initStaticConditions(g);
    try testing.expectEqual(@as(i16, 1), evaluate(&g.conditionTrue));
    try testing.expectEqual(@as(i16, 0), evaluate(&g.conditionFalse));
    try testing.expectEqual(@as(i16, 1), set(&g.conditionFalse));
    try testing.expectEqual(@as(i16, 1), evaluate(&g.conditionFalse));
    try testing.expectEqual(@as(i16, 1), clear(&g.conditionFalse));
    try testing.expectEqual(@as(i16, 0), evaluate(&g.conditionFalse));
}
