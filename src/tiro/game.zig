//! Port unit `game` (module) of TIRO.EXE. TiroGame: ctor/dtor, GameVtbl 01-06 (createPlayer: the crossbow and its 16 arrows, panel, status bar, init scene, onCreate), game_init, game_take_exit, the conditions.
//!
//! TiroGame is the only Game instantiated, so its GameVtbl overrides are
//! plain functions (docs/tiro/DESIGN.md "Virtual slots"): `createPlayer`
//! … `onCreate` are slots 01-06, `init` is the base `game_init` (slot 05)
//! and the `game_create_*` defaults are never reached. hwnd and hdc
//! parameters are dropped: GetDC / ReleaseDC have no counterpart, the
//! window DC's PatBlt(BLACKNESS) is over a clearWidth x clearHeight that is
//! never set (0 x 0: it blanks nothing), and every PostMessage keeps its
//! place. Everything the original `new`s comes from `g.local()`: the
//! destructors of the object, scene and panel units free it there.

const std = @import("std");
const msg = @import("../core/msg.zig");
const Msg = msg.Msg;
const object_create = @import("object_create.zig");
const scene_unit = @import("scene.zig");
const gallery = @import("gallery.zig");
const panels = @import("panels.zig");
const lists = @import("lists.zig");
const target = @import("target.zig");
const arrow = @import("arrow.zig");
const position = @import("behaviour/position.zig");
const occupancy = @import("behaviour/occupancy.zig");
const visibility = @import("behaviour/visibility.zig");
const render = @import("behaviour/render.zig");
const animation = @import("behaviour/animation.zig");
const space3d = @import("behaviour/space3d.zig");
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

// @orig 1088:4ef6 game_ctor
// @orig 1048:0000 tiro_game_ctor
/// TiroGame constructor with the base `game_ctor` out of line in the
/// original: empty global object list (capacity 30), empty update list,
/// the draw list's nodes chained, no scene / old scene / status bar /
/// control panel; then the TiroGame vtable (`g_tiroGame`, `g_game` are `g`).
pub fn ctor(g: *Game) *Game {
    _ = lists.ctor(&g.globalObjects, 0x1e);
    _ = lists.updateCtor(&g.updateList);
    _ = lists.drawCtor(&g.drawList);
    g.scene = null;
    g.oldScene = null;
    g.unk2AE = 2;
    g.statusBar = null;
    g.controlPanel = null;
    return g;
}

// @orig 1088:3d06 game_dtor
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

// @orig 1088:3cd4 game_scalar_dtor
/// Scalar deleting destructor: `dtor`, then `operator delete` of the Game
/// when bit 0 of `flags` is set (the Game's block is the host's: it is
/// freed by `Game.destroy`, so the flag has no effect here).
pub fn scalarDtor(g: *Game, flags: u16) *Game {
    dtor(g);
    _ = flags;
    return g;
}

/// GameVtbl slot 01 createPlayer: the Crossbow (kind `crossbow`) at x 200,
/// y 0x17c from the two strip tables (besta.bmp, bestse.bmp, 285 x 127),
/// hit box 0,0 285 x 127, timer
/// 10 / 60 ms, steps 20, visible. It becomes `g_crossbow` and the player;
/// then `unk46` = -1, strip 0, frame 1 (the aim: straight) and 16 arrows.
// @orig 1048:0029 tiro_game_create_player
pub fn createPlayer(g: *Game) ?*Object {
    const obj = g.local().create(Object) catch {
        // The original stores NULL in g_crossbow and writes through it next.
        g.crossbow = null;
        @panic("tiro.game.createPlayer: OutOfMemory");
    };
    obj.* = .{ .kind = .crossbow };
    object_create.crossbowCtor(
        g,
        obj,
        200,
        0x17c,
        2,
        &g.crossbowStripFiles,
        &g.crossbowStripFrames,
        &g.crossbowStripWidths,
        &g.crossbowStripHeights,
        0,
        0,
        0x11d,
        0x7f,
        10,
        0x3c,
        0x14,
        0x14,
        1,
        0,
        true,
    ) catch |e| @panic(@errorName(e));
    g.crossbow = obj;
    g.player = obj;
    obj.crossbow.unk46 = -1;
    obj.curStrip = 0;
    obj.curFrame = 1;
    obj.player2d.lives = 0x10;
    return obj;
}

/// GameVtbl slot 02 createInitScene: a Scene (`new` 0x44) through
/// `tiro_scene_ctor` (base constructor: list capacity 30, the name cut to
/// 19 characters, only `hasPlayer` set). The clear size it is passed is
/// unused.
// @orig 1048:01ca tiro_game_create_init_scene
pub fn createInitScene(g: *Game, name: []const u8) ?*Scene {
    const s = g.local().create(Scene) catch return null;
    s.* = .{};
    return scene_unit.tiroSceneCtor(s, name);
}

/// GameVtbl slot 03 createControlPanel: a TiroPanel (`panel.bmp`, 120 x 245,
/// one picture, timer 10 / 55 ms, at x 4, y 0x20), visible as the scene
/// says. Unlike ENCAIXE's E11 the 11 pushed words match `tiro_panel_ctor`.
// @orig 1048:0110 tiro_game_create_control_panel
pub fn createControlPanel(g: *Game) ?*Object {
    const obj = g.local().create(Object) catch return null;
    obj.* = .{ .kind = .control_panel };
    const visible: i16 = @intFromBool(scene_unit.getHasControlPanel(g, g.scene.?));
    object_create.tiroPanelCtor(g, obj, 4, 0x20, "panel.bmp", 1, 0x78, 0xf5, 10, 0x37, visible, 0, true) catch |e| @panic(@errorName(e));
    return obj;
}

/// GameVtbl slot 04 createStatusBar: `status_bar_ctor` (out of line here,
/// ENCAIXE inlines it) at (4, 0x20), colour 0x0000FFFF, one 120 x 245 picture
/// from `panel.bmp`, visible as the scene says.
// @orig 1048:016e tiro_game_create_status_bar
pub fn createStatusBar(g: *Game) ?*Object {
    const obj = g.local().create(Object) catch return null;
    obj.* = .{ .kind = .status_bar };
    const visible: i16 = @intFromBool(scene_unit.getHasStatusBar(g, g.scene.?));
    object_create.statusBarCtor(g, obj, 4, 0x20, 0xffff, "panel.bmp", 1, 0x78, 0xf5, visible, 0) catch |e| @panic(@errorName(e));
    return obj;
}

/// GameVtbl slot 05 init (`game_init`, the base start-up, called by
/// `onCreate` with the scene name): the scene (createInitScene, then the
/// TiroScene's create builds the backdrop), the global objects, the status
/// bar, control panel and player (attached to the backdrop, shown as the
/// scene wants), the player's idle animation, and `scene_started` posted.
// @orig 1088:3dc6 game_init
pub fn init(g: *Game, name: []const u8) *Game {
    g.scene = createInitScene(g, name);
    const s = g.scene.?;
    _ = gallery.create(g, s);
    lists.attachToScene(g, &g.globalObjects, s);
    g.statusBar = createStatusBar(g);
    _ = occupancy.attach(g, g.statusBar.?, s.backdrop.?);
    g.controlPanel = createControlPanel(g);
    _ = occupancy.attach(g, g.controlPanel.?, s.backdrop.?);
    g.player = createPlayer(g);
    _ = occupancy.attach(g, g.player.?, s.backdrop.?);
    if (scene_unit.getHasPlayer(g, s)) visibility.show(g, g.player.?, s.backdrop.?);
    if (scene_unit.getHasStatusBar(g, s)) visibility.show(g, g.statusBar.?, s.backdrop.?);
    if (scene_unit.getHasControlPanel(g, s)) visibility.show(g, g.controlPanel.?, s.backdrop.?);
    if (scene_unit.getHasPlayer(g, s)) animation.playIdle(g, g.player.?, s.backdrop.?);
    _ = g.post(Msg.make(msg.noite.scene_started, 0, 0, 0));
    return g;
}

/// Scene switch through an exit of the current scene: the new scene
/// (createNewScene, create), the old one deleted, the global objects and
/// the player / status bar / control panel re-attached by the new scene's
/// flags, the player moved to the exit's target, a repaint and
/// `scene_started` posted. Dead in TIRO (its scene has no exits; the 0x402
/// case that calls it never runs). Returns `g`.
// @orig 1040:0e6b game_take_exit
pub fn takeExit(g: *Game, exit_index: i16) *Game {
    const cur = g.scene.?;
    // addExit's record: playerX in the high word of biWidth, playerY in the
    // low word of biHeight.
    const ex = cur.exits[@intCast(exit_index)].?;
    const target_x: i16 = @truncate(ex.bmiHeader.biWidth >> 16);
    const target_y: i16 = @truncate(ex.bmiHeader.biHeight);
    g.oldScene = cur;
    g.scene = scene_unit.createNewScene(g, cur, exit_index);
    const s = g.scene.?;
    _ = gallery.create(g, s);
    if (g.oldScene) |old| _ = scene_unit.scalarDtor(g, old, 1);
    g.oldScene = null;
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

/// GameVtbl slot 06 onCreate (WM_CREATE): the base init with the scene
/// name "Mech", then the four targets and the arrow on the new backdrop
/// (`tiro_create_targets`, `tiro_create_arrows`). Returns `g`.
// @orig 1048:021a tiro_game_on_create
pub fn onCreate(g: *Game) *Game {
    _ = init(g, "Mech");
    target.createTargets(g, bdOf(g)) catch |e| @panic(@errorName(e));
    arrow.createArrows(g, bdOf(g)) catch |e| @panic(@errorName(e));
    return g;
}

// @orig 1088:5f18 condition_ctor
/// The Condition base constructor: only its vtable (slot 0 `_purecall`).
pub fn conditionCtor(cond: *Condition) *Condition {
    cond.kind = .base;
    return cond;
}

// @orig 1088:5dd6 flag_condition_ctor
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

// @orig 1050:00a3 init_static_conditions_entry (absorbed)
// The far stub in the static-init table (CALLF 1050:0000; RETF): the
// program root runs `initStaticConditions` itself.

/// ConditionVtbl slot 00 evaluate (FlagCondition).
// @orig 1088:5e46 flag_condition_evaluate
pub fn evaluate(cond: *const Condition) i16 {
    return cond.value;
}

/// ConditionVtbl slot 01 set (FlagCondition).
// @orig 1088:5e02 flag_condition_set
pub fn set(cond: *Condition) void {
    cond.value = 1;
}

/// ConditionVtbl slot 02 clear (FlagCondition): returns 1.
// @orig 1088:5e24 flag_condition_clear
pub fn clear(cond: *Condition) i16 {
    cond.value = 0;
    return 1;
}

const testing = std.testing;
const TestGame = @import("core/game.zig").TestGame;

// @orig 1088:5e46 flag_condition_evaluate oracle=documented
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

// @orig 1048:01ca tiro_game_create_init_scene oracle=documented
test "game ctor and the scene from createInitScene" {
    var tg = try TestGame.init(testing.allocator);
    defer tg.deinit();
    const g = tg.game;
    _ = ctor(g);
    try testing.expectEqual(@as(i16, 30), g.globalObjects.capacity);
    try testing.expectEqual(@as(u16, 2), g.unk2AE);
    const s = createInitScene(g, "A name far longer than nineteen characters").?;
    try testing.expectEqualStrings("A name far longer t", std.mem.sliceTo(&s.name, 0));
    try testing.expectEqual(@as(i16, 1), s.hasPlayer);
    try testing.expectEqual(@as(i16, 0), s.hasStatusBar);
    try testing.expectEqual(@as(i16, 30), s.objects.capacity);
}
