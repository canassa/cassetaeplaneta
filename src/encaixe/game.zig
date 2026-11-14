//! Port unit `game` (module) of ENCAIXE.EXE. TetrisGame: ctor/dtor, GameVtbl 01-06 (creators, init, onCreate), game_take_exit, the conditions.
//!
//! TetrisGame is the only Game instantiated, so its GameVtbl overrides are
//! plain functions (docs/encaixe/DESIGN.md "Virtual slots"): `createPlayer`
//! … `onCreate` are slots 01-06 and the `game_create_*` defaults are never
//! reached. hwnd and hdc parameters are dropped: GetDC / ReleaseDC have no
//! counterpart, the window DC's PatBlt(BLACKNESS) is over a clearWidth x
//! clearHeight that is never set (0 x 0: it blanks nothing), and every
//! PostMessage keeps its place.

const std = @import("std");
const msg = @import("../core/msg.zig");
const Msg = msg.Msg;
const cstr = @import("../core/cstr.zig");
const dib = @import("dib.zig");
const lists = @import("lists.zig");
const scene_unit = @import("scene.zig");
const tetris = @import("tetris.zig");
const piece = @import("piece.zig");
const object_create = @import("object_create.zig");
const position = @import("behaviour/position.zig");
const occupancy = @import("behaviour/occupancy.zig");
const visibility = @import("behaviour/visibility.zig");
const render = @import("behaviour/render.zig");
const animation = @import("behaviour/animation.zig");
const space3d = @import("behaviour/space3d.zig");
const movement = @import("behaviour/movement.zig");
const Game = @import("core/game.zig").Game;
const object = @import("core/object.zig");
const Object = object.Object;
const Frame = object.Frame;
const world = @import("core/world.zig");
const Backdrop = world.Backdrop;
const Scene = world.Scene;
const Condition = world.Condition;

/// The current scene's backdrop (the original dereferences it unchecked).
fn bdOf(g: *Game) *Backdrop {
    return g.scene.?.backdrop.?;
}

/// `operator delete` of a persistent object: its strips (cells, picture)
/// go with it. The original leaks them; they have no other owner.
fn destroyObject(g: *Game, obj: *Object) void {
    for (obj.frames) |*f| {
        if (f.cells.len != 0) g.gpa.free(f.cells);
        if (f.dib) |d| {
            g.gpa.free(d.bits);
            g.gpa.destroy(d);
        }
    }
    if (obj.frames.len != 0) g.gpa.free(obj.frames);
    g.gpa.destroy(obj);
}

/// `scene_dtor` + `operator delete` (the base destructor body b5dc).
fn destroyScene(g: *Game, s: *Scene) void {
    scene_unit.dtor(g, s);
    g.gpa.destroy(s);
}

// @orig 1008:9e28 te_game_ctor
/// TetrisGame constructor with the base Game's inlined: empty global
/// object list (capacity 30), empty update list, the draw list's nodes
/// chained, no scene / old scene / status bar / control panel. (`g_game`
/// and `g_tetrisGame` are `g` itself.)
pub fn ctor(g: *Game) *Game {
    g.globalObjects = .{ .head = null, .count = 0, .capacity = 30 };
    g.updateList.count = 0;
    _ = lists.drawCtor(&g.drawList);
    g.unk2AE = 2;
    g.scene = null;
    g.oldScene = null;
    g.statusBar = null;
    g.controlPanel = null;
    return g;
}

// @orig 1008:8caa game_dtor
/// Deletes the scene (its destructor body, then the block), the old scene
/// if set, the player, the control panel, the status bar, then every
/// global object.
pub fn dtor(g: *Game) void {
    if (g.scene) |s| destroyScene(g, s);
    if (g.oldScene) |s| destroyScene(g, s);
    if (g.player) |p| destroyObject(g, p);
    if (g.controlPanel) |p| destroyObject(g, p);
    if (g.statusBar) |s| destroyObject(g, s);
    g.scene = null;
    g.oldScene = null;
    g.player = null;
    g.controlPanel = null;
    g.statusBar = null;
    lists.deleteAll(g, &g.globalObjects);
}

/// GameVtbl slot 01 createPlayer. A Piece (kind `piece`) from the six strip
/// tables (peca*.bmp, 128 x 128, 4 frames), at x 160, timer 12 / 200 ms,
/// steps 32; it becomes `g_piece` and the player. Seeds `rand` with the
/// time and picks the first piece kind (rand() % 6), direction 8 (down),
/// no lines.
// @orig 1008:9e74 te_game_create_player
pub fn createPlayer(g: *Game) ?*Object {
    const obj = g.gpa.create(Object) catch {
        g.piece = null;
        g.player = null;
        return null;
    };
    obj.* = .{ .kind = .piece };
    object_create.player2dCtor(
        g,
        obj,
        0xa0,
        0,
        6,
        &g.pieceStripFiles,
        &g.pieceStripFrames,
        &g.pieceStripWidths,
        &g.pieceStripHeights,
        0,
        0,
        0x80,
        0x80,
        0xc,
        200,
        0x20,
        0x20,
        1,
        0,
        true,
    ) catch |e| @panic(@errorName(e));
    g.piece = obj;
    g.player = obj;
    g.rand.srand(@truncate(@as(u32, @bitCast(g.plat.unixTime()))));
    obj.curStrip = @rem(g.rand.rand(), 6);
    obj.mover.direction = 8;
    obj.piece.linesCleared = 0;
    return obj;
}

/// GameVtbl slot 02 createInitScene: a Scene with the base constructor
/// inlined (object list capacity 30, the name cut to 19 characters),
/// only `hasPlayer` set, then the TetrisScene's vtable (the flattened
/// `Scene` is the TetrisScene).
// @orig 1008:a08c te_game_create_init_scene
pub fn createInitScene(g: *Game, name: []const u8) ?*Scene {
    const s = g.gpa.create(Scene) catch return null;
    s.* = .{};
    s.objects = .{ .head = null, .count = 0, .capacity = 30 };
    // strncpy(name, sceneName, 19), name[19] = 0.
    const src = cstr.slice(name);
    const n = @min(src.len, 19);
    @memcpy(s.name[0..n], src[0..n]);
    @memset(s.name[n..], 0);
    s.hasPlayer = 1;
    s.exitCount = 0;
    s.hasStatusBar = 0;
    s.hasControlPanel = 0;
    s.is1Animation = 0;
    s.isClickExit = 0;
    s.animation = null;
    s.mayDropObject = 0;
    s.sceneNumber = 0;
    return s;
}

/// GameVtbl slot 03 createControlPanel: a TetrisPanel (`panel.bmp`).
///
/// ENCAIXE bug (not in BUGS.md): the call pushes 11 words but `te_panel_ctor`
/// (RET 0x18) takes 12; the missing one is `unk10`, so every later argument
/// is read one word off. As the callee sees them: unk10 = hasControlPanel,
/// visible = 0x37, timerPeriod = 10, timerId = 0xf5, height = 0x78,
/// width = 1, count = 0x940, bmpName = DGROUP:0x20 ("eito", the tail of
/// the window title: no such file, so no picture), y = 4, x = the caller's
/// saved SI (not reproducible: 0). The panel is never shown (the scene has
/// none), so none of it is visible; reproduced as the original runs it.
// @orig 1008:9f64 te_game_create_control_panel
pub fn createControlPanel(g: *Game) ?*Object {
    const obj = g.gpa.create(Object) catch return null;
    obj.* = .{ .kind = .control_panel };
    const has: u16 = @intFromBool(g.scene.?.hasControlPanel != 0);
    object_create.tePanelCtor(g, obj, 0, 4, "eito", 0x940, 1, 0x78, 0xf5, 0x0a, 0x37, has, true) catch |e| @panic(@errorName(e));
    return obj;
}

/// GameVtbl slot 04 createStatusBar: a StatusBar built inline at (4, 32),
/// visible as the scene says, one 120 x 245 strip from `panel.bmp` (a fatal
/// box when it is missing; the original goes on regardless).
// @orig 1008:9fb2 te_game_create_status_bar
pub fn createStatusBar(g: *Game) ?*Object {
    const obj = g.gpa.create(Object) catch return null;
    const visible: i16 = @intFromBool(g.scene.?.hasStatusBar != 0);
    obj.* = .{ .kind = .status_bar };
    obj.id = position.nextObjectId(g);
    obj.x = 4;
    obj.y = 0x20;
    obj.visible = visible;
    obj.unk08 = 0;
    obj.attached = 0;
    obj.curStrip = 0;
    obj.curFrame = 0;
    const frames = g.gpa.alloc(Frame, 1) catch @panic("OutOfMemory");
    frames[0] = object_create.frameCtor();
    obj.frames = frames;
    const d = dib.loadDib(g.gpa, g.plat, g.fixes, "panel.bmp");
    if (d == null) lists.messageBoxPrintf(g, "Erro Fatal!", "N\xe3o foi poss\xedvel abrir o arquivo: %s", "panel.bmp");
    object_create.frameInit(g, &obj.frames[0], d, 1, 0x78, 0xf5, 0, 0, 0, 0);
    obj.status.textColor = 0xffff;
    return obj;
}

/// GameVtbl slot 05 init (the base start-up, called by `onCreate`): the
/// scene, the global objects, the status bar, control panel and player
/// (attached to the backdrop, shown as the scene wants), the player's idle
/// animation, and `scene_started` posted. Returns `g`.
// @orig 1008:8d32 game_init
pub fn init(g: *Game, name: []const u8) *Game {
    g.scene = createInitScene(g, name);
    const s = g.scene.?;
    _ = tetris.create(g, s);
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
/// `scene_started` posted. Never reached by the Tetris (no exits). Returns `g`.
// @orig 1008:9c66 game_take_exit
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
    _ = tetris.create(g, s);
    if (g.oldScene) |old| destroyScene(g, old);
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
/// name "Tetris", the first piece on a clean board (the kind chosen in
/// createPlayer), then the fall started (moveToEdgeV, direction 8).
// @orig 1008:a0f4 te_game_on_create
pub fn onCreate(g: *Game) *Game {
    _ = init(g, "Tetris");
    piece.newGame(g, g.piece.?.curStrip);
    movement.moveToEdgeV(g, g.piece.?, bdOf(g), 8);
    return g;
}

// @orig 1008:b064 init_static_conditions
/// The static initialiser builds the two global FlagConditions (true = 1,
/// false = 0); they are the `Game` defaults, set again here.
pub fn initStaticConditions(g: *Game) void {
    g.conditionTrue = .{ .kind = .flag, .value = 1 };
    g.conditionFalse = .{ .kind = .flag, .value = 0 };
}

// @orig 1010:002e init_static_conditions_entry (absorbed)
// The far stub in the static-init table (CALLF 1008:b064; RETF): the
// program root runs `initStaticConditions` itself.

/// ConditionVtbl slot 00 evaluate (FlagCondition).
// @orig 1008:b0b8 flag_condition_evaluate
pub fn evaluate(cond: *const Condition) i16 {
    return cond.value;
}

/// ConditionVtbl slot 01 set (FlagCondition).
// @orig 1008:b096 flag_condition_set
pub fn set(cond: *Condition) void {
    cond.value = 1;
}

/// ConditionVtbl slot 02 clear (FlagCondition): returns 1.
// @orig 1008:b0a6 flag_condition_clear
pub fn clear(cond: *Condition) i16 {
    cond.value = 0;
    return 1;
}

const testing = std.testing;
const TestGame = @import("core/game.zig").TestGame;

// @orig 1008:b0b8 flag_condition_evaluate oracle=documented
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

// @orig 1008:9e28 te_game_ctor oracle=documented
test "game ctor and the Tetris scene from createInitScene" {
    var tg = try TestGame.init(testing.allocator);
    defer tg.deinit();
    const g = tg.game;
    _ = ctor(g);
    try testing.expectEqual(@as(i16, 30), g.globalObjects.capacity);
    try testing.expectEqual(@as(u16, 2), g.unk2AE);
    const s = createInitScene(g, "A name far longer than nineteen characters").?;
    defer g.gpa.destroy(s);
    try testing.expectEqualStrings("A name far longer t", cstr.slice(&s.name));
    try testing.expectEqual(@as(i16, 1), s.hasPlayer);
    try testing.expectEqual(@as(i16, 0), s.hasStatusBar);
    try testing.expectEqual(@as(i16, 30), s.objects.capacity);
}

// @orig 1008:9fb2 te_game_create_status_bar oracle=asset
test "createStatusBar and createPlayer load their pictures from the disc" {
    var tg = try TestGame.init(testing.allocator);
    defer tg.deinit();
    const g = tg.game;
    _ = ctor(g);
    g.scene = createInitScene(g, "Tetris");
    const sb = createStatusBar(g).?;
    try testing.expectEqual(@as(i16, 4), sb.x);
    try testing.expectEqual(@as(i16, 0x20), sb.y);
    try testing.expectEqual(@as(usize, 1), sb.frames.len);
    try testing.expect(sb.frames[0].dib != null);
    try testing.expectEqual(@as(u32, 0xffff), sb.status.textColor);
    g.statusBar = sb;
    const p = createPlayer(g).?;
    try testing.expect(g.piece == p and g.player == p);
    try testing.expect(p.curStrip >= 0 and p.curStrip < 6);
    try testing.expectEqual(@as(i16, 8), p.mover.direction);
    const cp = createControlPanel(g).?;
    try testing.expect(cp.frames[0].dib == null);
    g.controlPanel = cp;
    dtor(g);
}
