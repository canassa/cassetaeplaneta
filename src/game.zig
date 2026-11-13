//! Port unit `game` (module). game lifetime, creation slots (player, panels, exit scene), global objects, handler table.
//!
//! The Game object: constructor chain (Game, IniGame, NoiteGame, flattened
//! into one `Game`), destructor, the creation slots (player, control
//! panel, status bar, exit scene), `onCreate` and the scene handler table.
//!
//! Slots owned elsewhere: 07 `init` is `game_scenes.init`, which returns
//! `*Game` where the original returns NULL when the game name or
//! CASSETUP.INI is missing; `onCreate` discards that result in the
//! original too (the concrete class returns `this`), so nothing diverges.

const std = @import("std");
const cstr = @import("core/cstr.zig");
const Game = @import("core/game.zig").Game;
const handler = @import("core/handler.zig");
const object = @import("core/object.zig");
const Object = object.Object;
const world = @import("core/world.zig");
const Scene = world.Scene;
const File = @import("platform/platform.zig").File;
const platform = @import("platform/platform.zig");
const dib_mod = @import("dib.zig");
const frames = @import("frames.zig");
const game_scenes = @import("game_scenes.zig");
const ini = @import("ini.zig");
const ini_readers = @import("ini_readers.zig");
const object_create = @import("object_create.zig");
const object_init = @import("object_init.zig");
const object_list = @import("object_list.zig");
const scene_mod = @import("scene.zig");
const space3d = @import("behaviour/space3d.zig");
const units = @import("units.zig");
const update_list = @import("update_list.zig");
const draw_list = @import("draw_list.zig");

/// Errors that end the original program (a `Fixes` flag) or corrupt its
/// memory: nothing in the shipped data reaches them.
fn die(e: anyerror) noreturn {
    @panic(@errorName(e));
}

/// The open game INI (`g_iniFile`); handle 0 when it is not open.
fn iniFd(g: *Game) File {
    return g.ini.file orelse 0;
}

// ---- construction and destruction ----

// @orig 1010:ec4e game_ctor
/// Constructor of the base game object: the global-object and used-object
/// lists (capacity 100), the update list and the draw list, and the state
/// cleared. (`g_game` is the `*Game` itself; the vtable has no counterpart.)
pub fn gameCtor(g: *Game) *Game {
    _ = object_list.ctor(&g.globalObjects, 100);
    _ = update_list.ctor(&g.updateList);
    _ = draw_list.ctor(&g.drawList);
    _ = object_list.ctor(&g.usedObjects, 100);
    g.scene = null;
    g.oldScene = null;
    g.prevSceneNumber = 0;
    g.unk674 = 2;
    g.statusBar = null;
    g.controlPanel = null;
    g.lastGlobalObject = null;
    g.selectedItem = null;
    g.itemSelected = 0;
    g.iniFile = 0;
    g.curSceneName = @splat(0);
    g.exitPending = 0;
    g.pickActive = 0;
    g.pickArmed = 0;
    g.pickRetry = 0;
    g.pickAdded = 0;
    g.pickedCount = 0;
    for (&g.pickedItems) |*p| p.* = .{};
    g.minigameWon = @splat(0);
    return g;
}

// @orig 1018:3904 ini_game_ctor (absorbed)
// @orig 1018:c02e noite_game_ctor (absorbed)
/// The constructors of the INI game and of the concrete game only chain
/// to `game_ctor` and install their vtable (and `g_applic`).
pub fn ctor(g: *Game) *Game {
    return gameCtor(g);
}

// @orig 1010:ed74 game_dtor
/// Deletes the used objects, the scene, the player, the control panel and
/// the status bar, then the global objects. The player goes through the
/// base scalar destructor, as in the original.
pub fn dtor(g: *Game) void {
    object_init.objectListDeleteAll(g, &g.usedObjects);
    if (g.scene) |s| _ = scene_mod.scalarDtor(g, s, 1);
    if (g.player) |p| object_init.sceneObjectScalarDtor(g, p, 1);
    if (g.controlPanel) |c| object_init.controlPanelScalarDtor(g, c, 1);
    if (g.statusBar) |b| object_init.statusBarScalarDtor(g, b, 1);
    object_init.objectListDeleteAll(g, &g.globalObjects);
}

// @orig 1018:3676 game_scalar_dtor
/// Scalar deleting destructor: `dtor`, then frees the game when bit 0 of
/// `flags` is set.
pub fn scalarDtor(g: *Game, flags: u16) *Game {
    dtor(g);
    if (flags & 1 != 0) g.destroy();
    return g;
}

// ---- creation slots ----

/// Game slot 02 (INI game): the player from the `Player=` line (lives go
/// to `g.lives`) with one bitmap strip per `Sprite=` line (`<name><i>.bmp`),
/// then its 3D anchor and box.
// @orig 1018:393e game_create_player
pub fn createPlayer(g: *Game) ?*Object {
    const r = &g.ini.rec;
    const fd = iniFd(g);
    _ = ini_readers.readPlayer(&g.ini, g.plat, g.fixes, fd, .{
        &r.number, &r.x,   &r.y,   &r.numSprites, &r.bmpName,  &r.originX3d, &r.originY3d,
        &r.w3d,    &r.h3d, &r.d3d, &r.numTimer,   &r.perTimer, &r.deltaX,    &r.deltaY,
        &g.lives,
    }) catch |e| die(e);
    const obj = g.gpa.create(Object) catch @panic("game: out of memory");
    object_create.directionalPlayerCtor(g, obj, r.number, r.x, r.y, r.numSprites, r.numTimer, r.perTimer, r.deltaX, r.deltaY, 0, 0, true) catch |e| die(e);
    var i: i16 = 0;
    while (i < r.numSprites) : (i += 1) {
        _ = ini_readers.readSprite(&g.ini, g.plat, g.fixes, fd, .{
            &r.numFrames, &r.frameW, &r.frameH, &r.boundX, &r.boundY, &r.boundW, &r.boundH,
        }) catch |e| die(e);
        const name = ini.assetPath(&g.ini, &g.driveCD, &g.driveHD, &r.bmpName, i);
        const d = dib_mod.loadDib(g.gpa, g.plat, g.fixes, &g.dibPathBuf, &g.driveCD, name) catch |e| die(e);
        if (d == null) {
            ini.messageBoxPrintf(g.plat, &g.messageBuf, "Erro Fatal!!", "N\xe3o foi poss\xedvel abrir o arquivo: %s", name);
        }
        frames.frameInit(&obj.frames[@intCast(i)], d, r.numFrames, r.frameW, r.frameH, r.boundX, r.boundY, r.boundW, r.boundH);
    }
    _ = space3d.setAnchor(g, obj, r.originX3d, r.originY3d);
    _ = space3d.setSize(g, obj, r.w3d, r.h3d, r.d3d);
    return obj;
}

/// Game slot 03: no class of the game overrides the base stub, which only
/// warns and returns the current scene.
// @orig 1010:46f4 game_create_init_scene_default (absorbed)
pub fn createInitScene(g: *Game, name: []const u8) ?*Scene {
    _ = name;
    ini.messageBoxPrintf(g.plat, &g.messageBuf, "CUIDADO !", "Faltou redefinir o m\xe9todo CreateInitScene", 0);
    return g.scene;
}

/// Game slot 04 (INI game): the control panel from the `Control=` line
/// (visible, `<NomeBMP>.bmp` strip of NumFrames frames, timer
/// NumTimer/PerTimer).
// @orig 1018:3b8a game_create_control_panel
pub fn createControlPanel(g: *Game) ?*Object {
    const r = &g.ini.rec;
    _ = ini_readers.readControl(&g.ini, g.plat, g.fixes, iniFd(g), .{
        &r.x, &r.y, &r.bmpName, &r.numFrames, &r.frameW, &r.frameH, &r.numTimer, &r.perTimer,
    }) catch |e| die(e);
    const path = ini.assetPath(&g.ini, &g.driveCD, &g.driveHD, &r.bmpName, -1);
    const obj = g.gpa.create(Object) catch return null;
    object_create.controlPanelCtor(g, obj, r.x, r.y, path, r.numFrames, r.frameW, r.frameH, r.numTimer, r.perTimer, 0, 1, 0, true) catch |e| die(e);
    return obj;
}

/// Game slot 05 (INI game): the status bar from the `StatusBar=` line
/// (the value is the text colour, sign-extended).
// @orig 1018:3c5a game_create_status_bar
pub fn createStatusBar(g: *Game) ?*Object {
    const r = &g.ini.rec;
    _ = ini_readers.readStatusBar(&g.ini, g.plat, g.fixes, iniFd(g), .{
        &r.x, &r.y, &r.arg816C, &r.bmpName, &r.frameW, &r.frameH,
    }) catch |e| die(e);
    const path = ini.assetPath(&g.ini, &g.driveCD, &g.driveHD, &r.bmpName, -1);
    const obj = g.gpa.create(Object) catch return null;
    const color: u32 = @bitCast(@as(i32, r.arg816C));
    object_create.statusBarCtor(g, obj, r.x, r.y, color, path, 1, r.frameW, r.frameH, 1, 0) catch |e| die(e);
    return obj;
}

/// Game slot 06 (INI game): deletes the current scene and constructs the
/// INI scene exit `exit_index` of it leads to (target name, the
/// alternative one when the exit's alternative index is this index; the
/// exit's HasPlayer/HasControlPanel/HasStatusBar flags). Past the exit
/// table it warns and returns the current scene. The original tests
/// `exitCount < exitIndex`, so index == exitCount reads an unset exit (a
/// NULL dereference there). Null when out of memory.
// @orig 1018:11cc game_create_exit_scene
pub fn createExitScene(g: *Game, exit_index: i16) ?*Scene {
    const cur = g.scene orelse @panic("game.createExitScene: no scene");
    if (cur.exitCount < exit_index) {
        // scene_create_new_scene_default
        ini.messageBoxPrintf(g.plat, &g.messageBuf, cstr.slice(&cur.name), scene_mod.create_new_scene_missing, 0);
        return cur;
    }
    const ex = &(cur.exits[@intCast(exit_index)] orelse @panic("game.createExitScene: no exit")).exit;
    const has_player = ex.hasPlayer;
    const has_control_panel = ex.hasControlPanel;
    const has_status_bar = ex.hasStatusBar;
    var name: [20]u8 = @splat(0);
    cstr.copy(&name, cstr.slice(if (ex.altExitIndex == exit_index) &ex.altSceneName else &ex.sceneName));
    _ = scene_mod.scalarDtor(g, cur, 1);
    const new = g.gpa.create(Scene) catch return null;
    new.* = .{};
    return scene_mod.iniSceneCtor(new, g.iniFile, cstr.slice(&name), has_player, has_control_panel, has_status_bar, 0, 0);
}

// @orig 1018:6a6c game_add_global_object
/// Records the scene name an object belongs to in the object (unbounded
/// `strcpy` there; truncated here), links it into the global object list
/// and remembers it as the last one added.
pub fn addGlobalObject(g: *Game, scene_name: []const u8, obj: *Object) void {
    cstr.copy(&obj.sceneName, scene_name);
    _ = object_list.add(g, &g.globalObjects, obj);
    g.lastGlobalObject = obj;
}

// ---- onCreate ----

// @orig 1010:4724 ini_game_on_create (absorbed)
// @orig 1010:e9e2 game_init (absorbed)
// The IniGame's onCreate and the base Game's init are overridden by the
// concrete class (NoiteGame, `onCreate`; IniGame, `game_scenes.init`);
// nothing reaches them.

/// Game slot 08 (concrete game): runs the init (slot 07) with the game
/// name, then opens VELHA.MID as the MCI sequencer alias `musica` (a
/// message box on MCI error). Returns `g`; init's result is dropped.
// @orig 1018:c060 noite_game_on_create
pub fn onCreate(g: *Game) *Game {
    _ = game_scenes.init(g, g.gameName);
    var cmd: [256]u8 = undefined;
    const text = cstr.print(&cmd, "{s}{s}{s}{s}", .{ "open ", cstr.slice(&g.driveCD), "velha.mid", " type sequencer alias musica" });
    const err = g.plat.mciString(text);
    if (err != 0) {
        // Caption string at 1010:d796.
        _ = g.plat.messageBox("MCI Erro", platform.mciGetErrorString(err), platform.mb.iconexclamation);
    }
    return g;
}

// ---- scene handler table ----

// @orig 1018:6aca FUN_1018_6aca (absorbed)
// Static initial value of entry 0 (returns 0); the table is cleared at
// startup, so an empty entry is the same.

/// `g_registeredHandlers` assignments in the original's order: the INI
/// `Screen=` Number and the handler unit of that scene.
const handler_table = [_]struct { u16, []const u8 }{
    .{ 113, "handler_abert" }, // 1018:c628
    .{ 110, "handler_fundinic" }, // 1018:c688
    .{ 114, "handler_salvar2" }, // 1018:de58
    .{ 115, "handler_fundini1" }, // 1018:d31e
    .{ 45, "handler_1fquarbo" }, // 1018:e806
    .{ 46, "handler_1fquarpa" }, // 1018:ea72
    .{ 47, "handler_1fsala" }, // 1018:ebf0
    .{ 31, "handler_1fcozin0" }, // 1018:ecde
    .{ 49, "handler_1furso" }, // 1018:eee0
    .{ 100, "handler_1fcarnbo" }, // 1018:f038
    .{ 50, "handler_baracut1" }, // 1018:f09e
    .{ 1, "handler_2fpontoc" }, // 1018:f182
    .{ 14, "handler_2bfedriv" }, // 1018:f7d4
    .{ 5, "handler_2fsuabig" }, // 1020:0000
    .{ 2, "handler_2floucos" }, // 1020:0744
    .{ 7, "handler_2fasspap" }, // 1020:07aa
    .{ 16, "handler_2fblitg" }, // 1020:1004
    .{ 18, "handler_2fcopmau" }, // 1020:1a5a
    .{ 21, "handler_2fcopmu" }, // 1020:2576
    .{ 11, "handler_2fshardi" }, // 1020:32b2
    .{ 12, "handler_2fportdi" }, // 1020:4306
    .{ 23, "handler_2fportd2" }, // 1020:505c
    .{ 13, "handler_2fgaydir" }, // 1020:5a90
    .{ 10, "handler_2ffesta3" }, // 1020:7452
    .{ 8, "handler_2ffesta" }, // 1020:771a
    .{ 9, "handler_2ffesta2" }, // 1020:71fa
    .{ 27, "handler_2ffesta4" }, // 1020:7328
    .{ 85, "handler_3fsegura" }, // 1020:79d4
    .{ 58, "handler_3fhall" }, // 1020:7b06
    .{ 59, "handler_3fpapclo" }, // 1020:8db8
    .{ 84, "handler_3fsauna" }, // 1020:7f58
    .{ 57, "handler_3ffarao" }, // 1020:81f0
    .{ 53, "handler_3farmcai" }, // 1020:8458
    .{ 105, "handler_3fstreet" }, // 1020:8750
    .{ 109, "handler_3fstree2" }, // 1020:897c
    .{ 108, "handler_3fstree1" }, // 1020:8a64
    .{ 60, "handler_3fpapmal" }, // 1020:8b40
    .{ 103, "handler_2ftaxi" }, // 1020:9a3a
    .{ 92, "handler_4finifes" }, // 1020:9dc6
    .{ 89, "handler_4fbarboy" }, // 1020:a050
    .{ 91, "handler_4fdj" }, // 1020:b7ac
    .{ 95, "handler_4fpistav" }, // 1020:c3a4
    .{ 88, "handler_4fbarbo2" }, // 1020:c632
    .{ 90, "handler_4fboydj" }, // 1020:cd36
    .{ 87, "handler_4fbar" }, // 1020:d5ee
    .{ 96, "handler_4fsacaet" }, // 1028:0000
    .{ 94, "handler_4fmarte2" }, // 1028:04e6
    .{ 93, "handler_4fmarte" }, // 1028:0308
    .{ 97, "handler_4fsalgin" }, // 1028:0678
    .{ 112, "handler_6fsaida" }, // 1028:1018
    .{ 99, "handler_espquete" }, // 1028:0a88
    .{ 200, "handler_4fjarvamp" }, // 1028:0d80
    .{ 130, "handler_creditos" }, // 1028:10da
};

/// A handler unit's `handle`, or null while that unit is not ported.
fn handlerOf(comptime unit: []const u8) ?handler.Handler {
    const U = @field(units, unit);
    return if (@hasDecl(U, "handle")) U.handle else null;
}

// @orig 1018:570e register_scene_handlers
/// Clears the 400-entry handler table and fills the entries of the scenes
/// that have a hand-written handler (indexed by scene number).
pub fn registerSceneHandlers(g: *Game) void {
    g.handlers = @splat(null);
    inline for (handler_table) |e| g.handlers[e[0]] = handlerOf(e[1]);
}

test "every function compiles" {
    std.testing.refAllDecls(@This());
}
