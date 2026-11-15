//! Port unit `game` (module) of INFERNO.EXE. Game + InfernoGame: ctor/dtor,
//! GameVtbl 01-06 (createPlayer: the hero, createInitScene, onCreate: the
//! world builders), game_init, game_take_exit, the conditions.
//!
//! InfernoGame is the only Game instantiated, so its GameVtbl overrides are
//! plain functions: `createPlayer` ... `onCreate` are slots 01-06, `init` is
//! the base `game_init` (slot 05); the `game_create_*` defaults are never
//! reached. hwnd and hdc parameters are dropped. Everything the original
//! `new`s comes from `g.local()`.

const std = @import("std");
const lists = @import("lists.zig");
const object_create = @import("object_create.zig");
const scene_unit = @import("scene.zig");
const hell = @import("hell.zig");
const ledge = @import("ledge.zig");
const prop = @import("prop.zig");
const hazard = @import("hazard.zig");
const occupancy = @import("behaviour/occupancy.zig");
const visibility = @import("behaviour/visibility.zig");
const render = @import("behaviour/render.zig");
const animation = @import("behaviour/animation.zig");
const position = @import("behaviour/position.zig");
const Game = @import("core/game.zig").Game;
const object = @import("core/object.zig");
const Object = object.Object;
const world = @import("core/world.zig");
const Backdrop = world.Backdrop;
const Scene = world.Scene;
const Condition = world.Condition;

/// The current scene's backdrop (the original dereferences it unchecked).
fn bdOf(g: *Game) *Backdrop {
    return g.scene.?.backdrop.?;
}

// @orig 1080:7060 game_ctor
// @orig 1048:0000 inferno_game_ctor
/// InfernoGame constructor with the base `game_ctor` out of line: empty
/// global object list, empty update list, no scene / old scene / status bar
/// / control panel, `unk9A` = 2; then INFERNO's vtable (`g_game`,
/// `g_infernoGame` are `g`).
pub fn ctor(g: *Game) *Game {
    _ = lists.ctor(&g.globalObjects, null);
    _ = lists.updateCtor(&g.updateList);
    g.scene = null;
    g.oldScene = null;
    g.unk9A = 2;
    g.statusBar = null;
    g.controlPanel = null;
    return g;
}

// @orig 1080:5a5e game_dtor
/// Deletes the scene, the old scene if set (`scene_scalar_dtor(s, 1)`), the
/// player (`scene_object_scalar_dtor`), the control panel, the status bar,
/// then every global object.
pub fn dtor(g: *Game) void {
    if (g.scene) |s| _ = scene_unit.scalarDtor(g, s, 1);
    if (g.oldScene) |s| _ = scene_unit.scalarDtor(g, s, 1);
    if (g.player) |p| _ = object_create.sceneObjectScalarDtor(g, p, 1);
    // 1080:5b0f-5b69: control_panel_scalar_dtor / status_bar_scalar_dtor.
    if (g.controlPanel != null) @panic("INFERNO builds no ControlPanel");
    if (g.statusBar != null) @panic("INFERNO builds no StatusBar");
    lists.deleteAll(g, &g.globalObjects);
}

// @orig 1080:5a20 game_scalar_dtor
/// Scalar deleting destructor: `dtor`, then `operator delete` of the Game
/// when bit 0 of `flags` is set (the Game's block is the host's: it is
/// freed by `Game.destroy`, so the flag has no effect here).
pub fn scalarDtor(g: *Game, flags: u16) *Game {
    dtor(g);
    _ = flags;
    return g;
}

/// GameVtbl slot 01 createPlayer: a Hero (`new` 0x4e2) at x 153, y 306 from
/// the 12 strip tables (hit box 0, 0, 32 x 62, move timer 10 / 55 ms,
/// animation timer 15 / 180 ms, steps 5, visible). It becomes `g_hero` and
/// the player; nothing is set afterwards (TIRO sets strip, frame, lives).
// @orig 1048:0042 inferno_game_create_player
pub fn createPlayer(g: *Game) ?*Object {
    const obj = g.local().create(Object) catch {
        // The original stores NULL in g_hero and the player.
        g.hero = null;
        g.player = null;
        return null;
    };
    obj.* = .{ .kind = .hero };
    object_create.heroCtor(
        g,
        obj,
        0x99,
        0x132,
        0xc,
        &g.heroStripFiles,
        &g.heroStripFrames,
        &g.heroStripWidths,
        &g.heroStripHeights,
        0,
        0,
        0x20,
        0x3e,
        10,
        0x37,
        0xf,
        0xb4,
        5,
        5,
        1,
        0,
        true,
    ) catch |e| @panic(@errorName(e));
    g.hero = obj;
    g.player = obj;
    return obj;
}

/// GameVtbl slot 02 createInitScene: a Scene (`new` 0x50) through
/// `inferno_scene_ctor` (the clear size it is passed is unused).
// @orig 1048:0123 inferno_game_create_init_scene
pub fn createInitScene(g: *Game, name: []const u8) ?*Scene {
    const s = g.local().create(Scene) catch return null;
    s.* = .{};
    return scene_unit.infernoSceneCtor(s, name);
}

/// GameVtbl slot 03 createControlPanel (default only, never called).
// @orig 1080:600c game_create_control_panel_default (absorbed)
pub fn createControlPanel(g: *Game) ?*Object {
    _ = g;
    @panic("Faltou redefinir createControlPanel");
}

/// GameVtbl slot 04 createStatusBar (default only, never called).
// @orig 1080:6048 game_create_status_bar_default (absorbed)
pub fn createStatusBar(g: *Game) ?*Object {
    _ = g;
    @panic("Faltou redefinir createStatusBar");
}

/// GameVtbl slot 05 init (`game_init`, the base start-up, called by
/// `onCreate` with the scene name; hwnd dropped, and the window DC's
/// PatBlt(BLACKNESS) is over a clear size never set): the scene
/// (createInitScene, then its `create` builds the backdrop), the global
/// objects, the status bar and control panel (never: the scene's flags are
/// 0), the player, attached to the backdrop when the scene has one. No
/// `show`, no idle animation, nothing posted (TIRO's differ).
// @orig 1080:5b82 game_init
pub fn init(g: *Game, name: []const u8) *Game {
    g.scene = createInitScene(g, name);
    const s = g.scene.?;
    _ = hell.create(g, s);
    lists.attachToScene(g, &g.globalObjects, s);
    // 1080:5c3d-5ca9 / 5cc9-5d31 / 5d51-5d79: the status bar (create,
    // attach, erase / draw) and the control panel (create, attach).
    if (scene_unit.getHasStatusBar(g, s)) @panic("INFERNO builds no StatusBar");
    if (scene_unit.getHasControlPanel(g, s)) @panic("INFERNO builds no ControlPanel");
    g.player = createPlayer(g);
    if (scene_unit.getHasPlayer(g, s)) _ = occupancy.attach(g, g.player.?, s.backdrop.?);
    return g;
}

/// Scene switch through an exit of the current scene. Dead in INFERNO (its
/// scene has no exits; the 0x401 case that calls it never runs). The old
/// scene still held is deleted first, then the scene left becomes
/// `oldScene` (it is kept: TIRO deletes it after the new one is made), the
/// new scene is created, the global objects and the player are re-attached
/// by its flags and the player is moved to the exit's target; a repaint,
/// nothing posted. Returns `g`.
// @orig 1040:1335 game_take_exit
pub fn takeExit(g: *Game, exit_index: i16) *Game {
    const cur = g.scene.?;
    // The exit's link: playerX (+0x12), playerY (+0x14).
    const ex = cur.exits[@intCast(exit_index)].?;
    const target_x: i16 = ex.x;
    const target_y: i16 = ex.y;
    if (g.oldScene) |old| _ = scene_unit.scalarDtor(g, old, 1);
    g.oldScene = g.scene;
    g.scene = scene_unit.createNewScene(g, g.oldScene.?, exit_index);
    const s = g.scene.?;
    _ = hell.create(g, s);
    lists.attachToScene(g, &g.globalObjects, s);
    const bd = s.backdrop.?;
    if (scene_unit.getHasPlayer(g, s)) {
        g.player.?.linked = null;
        _ = occupancy.reattach(g, g.player.?, bd);
    }
    if (scene_unit.getHasStatusBar(g, s)) @panic("INFERNO builds no StatusBar");
    if (scene_unit.getHasControlPanel(g, s)) @panic("INFERNO builds no ControlPanel");
    if (scene_unit.getHasPlayer(g, s)) {
        position.moveToAndDrop(g, g.player.?, target_x, target_y, bd);
        visibility.show(g, g.player.?, bd);
    }
    if (scene_unit.getHasPlayer(g, s)) animation.playIdle(g, g.player.?, bd);
    // InvalidateRect(hwnd, NULL, TRUE)
    g.queue.paint_pending = true;
    return g;
}

/// The far cdecl stub `inferno_start_nop(hwnd, backdrop)`: empty (the
/// start-up work is in the scene's `create`).
// @orig 1068:0158 inferno_start_nop
fn startNop(g: *Game, bd: *Backdrop) void {
    _ = g;
    _ = bd;
}

/// GameVtbl slot 06 onCreate (WM_CREATE): the base init with the scene
/// name "Mario", then the empty start stub and the platforms (with their
/// drinks), rocks and cross, and hazards on the new backdrop. Returns `g`.
// @orig 1048:0183 inferno_game_on_create
pub fn onCreate(g: *Game) *Game {
    _ = init(g, "Mario");
    startNop(g, bdOf(g));
    ledge.createPlatforms(g, bdOf(g)) catch |e| @panic(@errorName(e));
    prop.createRocksAndCross(g, bdOf(g)) catch |e| @panic(@errorName(e));
    hazard.createHazards(g, bdOf(g)) catch |e| @panic(@errorName(e));
    return g;
}

// @orig 1080:85ea condition_ctor
/// The Condition base constructor: only its vtable.
pub fn conditionCtor(cond: *Condition) *Condition {
    cond.kind = .base;
    return cond;
}

// @orig 1080:8430 flag_condition_ctor
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
// @orig 1080:84b4 flag_condition_evaluate
pub fn evaluate(cond: *const Condition) i16 {
    return cond.value;
}

/// ConditionVtbl slot 01 set (FlagCondition).
// @orig 1080:8470 flag_condition_set
pub fn set(cond: *Condition) void {
    cond.value = 1;
}

/// ConditionVtbl slot 02 clear (FlagCondition): returns 1.
// @orig 1080:8492 flag_condition_clear
pub fn clear(cond: *Condition) i16 {
    cond.value = 0;
    return 1;
}

const testing = std.testing;
const TestGame = @import("core/game.zig").TestGame;

// @orig 1080:84b4 flag_condition_evaluate oracle=documented
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

// @orig 1048:0123 inferno_game_create_init_scene oracle=documented
test "game ctor and the scene from createInitScene" {
    var tg = try TestGame.init(testing.allocator);
    defer tg.deinit();
    const g = tg.game;
    _ = ctor(g);
    try testing.expectEqual(@as(u16, 2), g.unk9A);
    const s = createInitScene(g, "A name far longer than nineteen characters").?;
    try testing.expectEqualStrings("A name far longer t", std.mem.sliceTo(&s.name, 0));
    try testing.expectEqual(@as(i16, 1), s.hasPlayer);
    try testing.expectEqual(@as(i16, 0), s.hasStatusBar);
}
