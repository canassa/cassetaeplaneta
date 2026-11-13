//! Port unit `game_scenes` (module). scene switching: take exit, switch scene, first/start scene, IniGame init.
//!
//! The Game slots that build scenes. `takeExit` and `switchScene` replace
//! the current scene and re-attach the persistent objects (global
//! objects, player, status bar, control panel); `init` is the start-up of
//! the INI game (CASSETUP.INI, `<name>.ini`, first scene, player, panels
//! and the `Portable=`/`ZoomPort=` items); `createFirstScene` and
//! `createStartScene` read the FirstScene/StartScene line and construct
//! the scene object.
//!
//! Scenes are allocated with `g.gpa.create(Scene)` and built with
//! `scene.iniSceneCtor`; the scene's destructor frees its backdrop with
//! `g.gpa.destroy`. DC handling (GetDC/ReleaseDC, the PatBlt that blanks
//! the window) has no counterpart; InvalidateRect(NULL) is
//! `queue.paint_pending`.

const std = @import("std");
const cstr = @import("core/cstr.zig");
const Game = @import("core/game.zig").Game;
const object = @import("core/object.zig");
const Object = object.Object;
const world = @import("core/world.zig");
const Backdrop = world.Backdrop;
const Scene = world.Scene;
const Msg = @import("core/msg.zig").Msg;
const noite = @import("core/msg.zig").noite;
const wm = @import("core/msg.zig").wm;
const File = @import("platform/platform.zig").File;
const ini = @import("ini.zig");
const ini_readers = @import("ini_readers.zig");
const game = @import("game.zig");
const scene_mod = @import("scene.zig");
const scene_loader = @import("scene_loader.zig");
const object_create = @import("object_create.zig");
const object_list = @import("object_list.zig");
const panels = @import("panels.zig");
const portable = @import("portable.zig");
const sound = @import("sound.zig");
const update_list = @import("update_list.zig");
const animation = @import("behaviour/animation.zig");
const occupancy = @import("behaviour/occupancy.zig");
const render = @import("behaviour/render.zig");
const space3d = @import("behaviour/space3d.zig");
const visibility = @import("behaviour/visibility.zig");

/// The original's unchecked pointers: a missing one is a crash there.
fn must(comptime T: type, p: ?*T) *T {
    return p orelse @panic("game_scenes: null pointer");
}

/// Errors that end the original program (a `Fixes` flag) or corrupt its
/// memory: nothing in the shipped data reaches them.
fn die(e: anyerror) noreturn {
    @panic(@errorName(e));
}

/// The open game INI (`g_iniFile`); handle 0 when it is not open.
fn iniFd(g: *Game) File {
    return g.ini.file orelse 0;
}

fn bdOf(scene: *Scene) *Backdrop {
    return must(Backdrop, scene.backdrop);
}

/// What `takeExit` and `switchScene` share once `g.scene` is the new,
/// created scene: attach the global objects, reset the panel, re-attach
/// and show the persistent objects the scene has, put the player at
/// (`x`, `y`), draw the bars, start the idle pose and announce the scene
/// (0x401, sent). The `hdc` of the original is dropped.
fn enterScene(g: *Game, x: i16, y: i16) void {
    const scene = must(Scene, g.scene);
    const bd = bdOf(scene);
    object_list.attachToScene(g, &g.globalObjects, scene);
    g.itemSelected = 0;
    g.exitPending = 0;
    panels.reset(g, must(Object, g.controlPanel));
    const player = g.player;
    const status_bar = g.statusBar;
    const control_panel = g.controlPanel;
    if (scene_mod.getHasPlayer(g, scene)) {
        must(Object, player).linked = null;
        _ = occupancy.reattach(g, must(Object, player), bd);
    }
    if (scene_mod.getHasStatusBar(g, scene)) {
        _ = occupancy.reattach(g, must(Object, status_bar), bd);
        visibility.show(g, must(Object, status_bar), bd);
    }
    if (scene_mod.getHasControlPanel(g, scene)) {
        _ = occupancy.reattach(g, must(Object, control_panel), bd);
        visibility.show(g, must(Object, control_panel), bd);
    }
    if (scene_mod.getHasPlayer(g, scene)) {
        space3d.moveToAndDrop(g, must(Object, player), x, y, bd);
        visibility.show(g, must(Object, player), bd);
    }
    if (scene_mod.getHasStatusBar(g, scene)) render.draw(g, must(Object, status_bar), bd);
    if (scene_mod.getHasControlPanel(g, scene)) render.draw(g, must(Object, control_panel), bd);
    if (scene_mod.getHasPlayer(g, scene)) animation.playIdle(g, must(Object, player), bd);
    g.queue.paint_pending = true; // InvalidateRect(hwnd, NULL, ...)
    _ = g.send(Msg.make(noite.scene_started, 0, 0, 0));
}

// @orig 1018:12c6 game_take_exit
/// Scene switch through exit `exit_index` of the current scene: the player
/// arrives at the exit's target position (the alternative one when the
/// exit's alternative index is this index). Game slot 06 builds the new
/// scene (`createExitScene`), slot 07 of the scene creates it. Returns
/// the game.
pub fn takeExit(g: *Game, exit_index: i16) *Game {
    const old = must(Scene, g.scene);
    const ex = &must(Object, old.exits[@intCast(exit_index)]).exit;
    var x: i16 = undefined;
    var y: i16 = undefined;
    if (ex.altExitIndex == exit_index) {
        x = ex.altPlayerX;
        y = ex.altPlayerY;
    } else {
        x = ex.playerX;
        y = ex.playerY;
    }
    g.oldScene = g.scene;
    g.prevSceneNumber = old.sceneNumber;
    g.scene = game.createExitScene(g, exit_index);
    g.oldScene = null;
    _ = scene_loader.create(g, must(Scene, g.scene));
    enterScene(g, x, y);
    return g;
}

// @orig 1018:15ea ini_game_switch_scene
/// Replaces the current scene with the INI scene `name`: discards the
/// update list, stops and frees the waves, deletes the old scene, builds
/// the new one with the given flags, positions the file in its section,
/// creates it and re-attaches everything (the player at `x`, `y`). Returns
/// the game.
pub fn switchScene(g: *Game, name: []const u8, x: i16, y: i16, has_player: i16, has_control_panel: i16, has_status_bar: i16, is_1animation: i16, is_click_exit: i16) *Game {
    update_list.discard(&g.updateList);
    sound.stopAll(&g.sound, g.plat);
    sound.freeAll(&g.sound, g.plat);
    g.oldScene = g.scene;
    g.prevSceneNumber = must(Scene, g.scene).sceneNumber;
    if (g.oldScene) |old| _ = scene_mod.scalarDtor(g, old, 1);
    if (g.gpa.create(Scene)) |new| {
        new.* = .{};
        g.scene = scene_mod.iniSceneCtor(new, g.iniFile, name, has_player, has_control_panel, has_status_bar, is_1animation, is_click_exit);
    } else |_| {
        g.scene = null;
    }
    g.oldScene = null;
    _ = ini.seekSection(&g.ini, g.plat, g.fixes, iniFd(g), name, true) catch |e| die(e);
    _ = scene_loader.create(g, must(Scene, g.scene));
    enterScene(g, x, y);
    return g;
}

/// The scene the `FirstScene=`/`StartScene=` line (already parsed into
/// `g.ini.rec`) names, with that line's flags; null when out of memory.
fn buildRecordScene(g: *Game, fd: File) ?*Scene {
    const r = &g.ini.rec;
    const new = g.gpa.create(Scene) catch return null;
    new.* = .{};
    return scene_mod.iniSceneCtor(new, @bitCast(fd), cstr.slice(&r.firstScene), r.hasPlayer, r.hasControlPanel, r.hasStatusBar, r.is1Animation, r.isClickExit);
}

// @orig 1018:3d18 ini_game_create_start_scene
/// Game slot 0D: reads the `StartScene=` line of the save file `fd`
/// (JOGO*.INI) and constructs that INI scene. The reader's result is
/// ignored (a missing line leaves the previous record).
pub fn createStartScene(g: *Game, fd: File) ?*Scene {
    const r = &g.ini.rec;
    _ = ini_readers.readStartScene(&g.ini, g.plat, g.fixes, fd, .{
        &r.firstScene, &r.hasPlayer, &r.hasControlPanel, &r.hasStatusBar, &r.is1Animation, &r.isClickExit,
    }) catch |e| die(e);
    return buildRecordScene(g, fd);
}

// @orig 1018:3db0 ini_game_create_first_scene
/// Game slot 0C: reads the `FirstScene=` line of the game INI and
/// constructs that INI scene (the original allocates 0x9e bytes).
pub fn createFirstScene(g: *Game) ?*Scene {
    const r = &g.ini.rec;
    const fd = iniFd(g);
    _ = ini_readers.readFirstScene(&g.ini, g.plat, g.fixes, fd, .{
        &r.firstScene, &r.hasPlayer, &r.hasControlPanel, &r.hasStatusBar, &r.is1Animation, &r.isClickExit,
    }) catch |e| die(e);
    return buildRecordScene(g, fd);
}

/// GetPrivateProfileString(`section`, `key`, "", out, 256, file): the
/// value of `key=` in `[section]` of the INI text `text` (names compare
/// without case, the value loses surrounding blanks), or "" when absent.
fn profileString(text: []const u8, section: []const u8, key: []const u8, out: []u8) void {
    var in_section = false;
    var lines = std.mem.splitScalar(u8, text, '\n');
    while (lines.next()) |raw| {
        const line = std.mem.trim(u8, raw, " \t\r");
        if (line.len == 0 or line[0] == ';') continue;
        if (line[0] == '[') {
            const end = std.mem.indexOfScalar(u8, line, ']') orelse line.len;
            in_section = std.ascii.eqlIgnoreCase(line[1..end], section);
            continue;
        }
        if (!in_section) continue;
        const eq = std.mem.indexOfScalar(u8, line, '=') orelse continue;
        if (!std.ascii.eqlIgnoreCase(std.mem.trim(u8, line[0..eq], " \t"), key)) continue;
        cstr.copy(out, std.mem.trim(u8, line[eq + 1 ..], " \t"));
        return;
    }
    out[0] = 0;
}

/// `_fstrlwr` in place.
fn lowerInPlace(s: []u8) void {
    for (s) |*c| {
        if (c.* == 0) break;
        c.* = std.ascii.toLower(c.*);
    }
}

/// One `Portable=` / `ZoomPort=` item of the game INI (the record is
/// already parsed): constructs the portable (added to the global objects
/// by its constructor), sets its scores, 3D box and elevation, and its
/// 40x40 inventory icon (`<name>2.bmp`).
fn createPortable(g: *Game, zoom: bool) void {
    const r = &g.ini.rec;
    var small_path: [256]u8 = @splat(0);
    if (zoom) cstr.copy(&small_path, ini.assetPath(&g.ini, &g.driveCD, &g.driveHD, &r.smallBmpName, 2));
    const bmp = ini.assetPath(&g.ini, &g.driveCD, &g.driveHD, &r.bmpName, 0);
    const obj = g.gpa.create(Object) catch @panic("game_scenes: out of memory");
    lowerInPlace(&r.portScene);
    if (zoom) {
        object_create.portableCtorZoom(g, obj, r.number, cstr.slice(&r.portScene), r.x, r.y, bmp, r.numFrames, r.frameW, r.frameH, cstr.slice(&small_path), r.smallNumFrames, r.smallFrameW, r.smallFrameH, r.numTimer, r.perTimer, 1, 0, true) catch |e| die(e);
    } else {
        object_create.portableCtor(g, obj, r.number, cstr.slice(&r.portScene), r.x, r.y, bmp, r.frameW, r.frameH, r.boundX, r.boundY, r.boundW, r.boundH, r.numTimer, r.perTimer, 1, 0, true) catch |e| die(e);
    }
    obj.portable.scoreTake = r.scoreTake;
    obj.portable.scoreUse = r.scoreUse;
    obj.portable.scoreMisuse = r.scoreMisuse;
    const icon = ini.assetPath(&g.ini, &g.driveCD, &g.driveHD, &r.bmpName, 2);
    _ = space3d.setAnchor(g, obj, r.originX3d, r.originY3d);
    _ = space3d.setSize(g, obj, r.w3d, r.h3d, r.d3d);
    _ = space3d.setWorldElev(g, obj, r.elevation);
    _ = portable.setIcon(g, obj, icon, 40, 40) catch |e| die(e);
}

// @orig 1018:3e46 ini_game_init
/// Game slot 07: start-up of the INI game `name` (empty: no game).
/// Reads DriveCD/DriveHD from CASSETUP.INI, opens `<baseDir><name>.ini`
/// (else `<driveHD><name>.ini`), indexes its sections, creates the first
/// scene, the player, the control panel and the status bar, attaches
/// them, loads every `Portable=`/`ZoomPort=` item into the global
/// objects, shows what the scene has and posts 0x401.
///
/// Failures: no name or no CASSETUP.INI show the "Erro Fatal!" box and
/// post WM_DESTROY; the original returns NULL there, this returns `g`
/// (the declared signature has no null). A game INI that cannot be opened
/// shows its box and returns `g` without posting anything.
///
/// The CRT/USER parts have no counterpart: `_fullpath("")` (the current
/// directory) is the root `\` of the platform's file namespace, so
/// `baseDir` is `\`; `_access` is an open; GetPrivateProfileString is
/// `profileString`.
pub fn init(g: *Game, name: []const u8) *Game {
    const nm = cstr.slice(name);
    if (nm.len == 0) {
        // Nome do jogo indefinido
        ini.messageBoxPrintf(g.plat, &g.messageBuf, "Erro Fatal!", "Nome do jogo indefinido em gen_applic::Init", 0);
        _ = g.post(Msg.make(wm.destroy, 0, 0, 0));
        return g;
    }
    _ = cstr.print(&g.baseDir, "{s}\\", .{""});
    const setup = g.plat.open("\\cassetup.ini", .read) orelse {
        // Path do setup.ini nao existe
        ini.messageBoxPrintf(g.plat, &g.messageBuf, "Erro Fatal!", "Path do setup.ini nao existe em gen_applic::Init", 0);
        _ = g.post(Msg.make(wm.destroy, 0, 0, 0));
        return g;
    };
    var text: [4096]u8 = undefined;
    var len: usize = 0;
    while (len < text.len) {
        const n = g.plat.read(setup, text[len..]);
        if (n == 0) break;
        len += n;
    }
    g.plat.close(setup);
    profileString(text[0..len], "Diretorios", "DriveCD", &g.driveCD);
    profileString(text[0..len], "Diretorios", "DriveHD", &g.driveHD);

    var path: [256]u8 = undefined;
    g.ini.file = ini.open(g.plat, cstr.print(&path, "{s}{s}.ini", .{ cstr.slice(&g.baseDir), nm }));
    if (g.ini.file == null) {
        g.ini.file = ini.open(g.plat, cstr.print(&path, "{s}{s}.ini", .{ cstr.slice(&g.driveHD), nm }));
    }
    g.iniFile = if (g.ini.file) |f| @bitCast(f) else 0;
    if (g.ini.file == null) {
        _ = ini.fatalError(g.plat, g.fixes, "N\xe3o consegui abrir o .ini do jogo") catch |e| die(e);
        return g;
    }
    const fd = iniFd(g);
    _ = ini.buildSectionIndex(&g.ini, g.plat, g.fixes, fd) catch |e| die(e);
    _ = ini.seekSection(&g.ini, g.plat, g.fixes, fd, nm, true) catch |e| die(e);

    g.scene = createFirstScene(g);
    // PatBlt(hdc, 0, 0, clearWidth, clearHeight, BLACKNESS): both are 0
    // (BUGS.md U3), nothing is blanked.
    const scene = must(Scene, g.scene);
    const pos: i32 = g.plat.seek(fd, 0, .cur); // ini_tell: the full position (DX:AX)
    _ = scene_loader.create(g, scene);
    _ = ini.seek(g.plat, fd, pos);
    g.player = game.createPlayer(g);
    g.controlPanel = game.createControlPanel(g);
    g.statusBar = game.createStatusBar(g);
    g.itemSelected = 0;
    g.exitPending = 0;
    panels.reset(g, must(Object, g.controlPanel));
    const bd = bdOf(scene);
    if (!scene_mod.getHasPlayer(g, scene)) must(Object, g.player).visible = 0;
    if (!scene_mod.getHasStatusBar(g, scene)) must(Object, g.statusBar).visible = 0;
    if (!scene_mod.getHasControlPanel(g, scene)) must(Object, g.controlPanel).visible = 0;
    _ = occupancy.attach(g, must(Object, g.player), bd);
    _ = occupancy.attach(g, must(Object, g.controlPanel), bd);
    _ = occupancy.attach(g, must(Object, g.statusBar), bd);

    while (true) {
        const c = std.ascii.toUpper(ini.peekChar(&g.ini, g.plat, g.fixes, fd) catch |e| die(e));
        if (c != 'P' and c != 'Z') break;
        const r = &g.ini.rec;
        if (c == 'P') {
            _ = ini_readers.readPortable(&g.ini, g.plat, g.fixes, fd, .{
                &r.number,      &r.portScene, &r.x,         &r.y,        &r.bmpName,   &r.frameW,    &r.frameH,
                &r.boundX,      &r.boundY,    &r.boundW,    &r.boundH,   &r.originX3d, &r.originY3d, &r.w3d,
                &r.h3d,         &r.d3d,       &r.elevation, &r.numTimer, &r.perTimer,  &r.scoreTake, &r.scoreUse,
                &r.scoreMisuse,
            }) catch |e| die(e);
        } else {
            _ = ini_readers.readZoomPort(&g.ini, g.plat, g.fixes, fd, .{
                &r.number,   &r.portScene,    &r.x,              &r.y,           &r.bmpName,     &r.numFrames, &r.frameW,
                &r.frameH,   &r.smallBmpName, &r.smallNumFrames, &r.smallFrameW, &r.smallFrameH, &r.originX3d, &r.originY3d,
                &r.w3d,      &r.h3d,          &r.d3d,            &r.elevation,   &r.numTimer,    &r.perTimer,  &r.scoreTake,
                &r.scoreUse, &r.scoreMisuse,
            }) catch |e| die(e);
        }
        createPortable(g, c == 'Z');
    }

    object_list.attachToScene(g, &g.globalObjects, scene);
    if (scene_mod.getHasPlayer(g, scene)) visibility.show(g, must(Object, g.player), bd);
    if (scene_mod.getHasStatusBar(g, scene)) visibility.show(g, must(Object, g.statusBar), bd);
    if (scene_mod.getHasControlPanel(g, scene)) visibility.show(g, must(Object, g.controlPanel), bd);
    if (scene_mod.getHasPlayer(g, scene)) {
        _ = space3d.setElevation(g, must(Object, g.player), bd, 0);
        animation.playIdle(g, must(Object, g.player), bd);
    }
    _ = g.post(Msg.make(noite.scene_started, 0, 0, 0));
    return g;
}

test "every function compiles" {
    std.testing.refAllDecls(@This());
    _ = &init;
    _ = &takeExit;
    _ = &switchScene;
    _ = &createFirstScene;
    _ = &createStartScene;
}
