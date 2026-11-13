//! Port unit `save` (module). save games (JOGO*.INI): save, load, load objects, file_create.
//!
//! A save slot is an INI file `<DriveHD><name>.ini` (`jogo0`, the new-game
//! slot, is read from `<DriveCD>`): `StartScene=`, `PlayerX=`, `PlayerY=`,
//! `Score=`, `Lives=`, one `Stat=` / `Portab=` line per global object, one
//! `Invent=` line per carried object, `[fim]`. Writes go to the platform's
//! `save/` directory, which is read before `assets/`.
//!
//! Original bugs reproduced:
//! - B4 (BUGS.md): `loadGame` never closes the save file (every load, new
//!   game included, leaks a handle). `Fixes.close_loaded_save` closes it
//!   after the objects are read.
//! - `Score=` is written through `%d` with a 32-bit argument, so only the
//!   low 16 bits are saved (a score above 32767 reloads wrapped/negative);
//!   the load sign-extends the 16-bit value. (No flag: not in BUGS.md.)
//! - `loadObjects` keeps its `x`/`y` locals across lines: an `Invent=` line
//!   for an item already carried places it at the position of the previous
//!   `Stat=`/`Portab=` line (uninitialised stack bytes before the first one;
//!   0 here).
//! - A `Portab=` line for an item that is in the global list or the
//!   inventory only copies the scene name; one for a consumed item
//!   (`usedObjects`) sends it back to its home position and scene.
//!
//! Where the original dereferences NULL (`asPortable` of a non-portable
//! object named by a save line) the port panics. `exit(1)` after an invalid
//! line, and the `ini` readers' `error.Fatal`, set `g.quit`: the dispatchers
//! cannot return errors (their callers are other units).
//!
//! No counterpart: GetDC/ReleaseDC, the `PatBlt(BLACKNESS)` of
//! `clearWidth` x `clearHeight` (both zero: BUGS.md U3) and the final
//! InvalidateRect (the screen is the platform's).

const std = @import("std");
const Game = @import("core/game.zig").Game;
const platform = @import("platform/platform.zig");
const File = platform.File;
const object = @import("core/object.zig");
const Object = object.Object;
const world = @import("core/world.zig");
const Scene = world.Scene;
const cstr = @import("core/cstr.zig");
const msg = @import("core/msg.zig");
const errors = @import("core/errors.zig");
const ini = @import("ini.zig");
const readers = @import("ini_readers.zig");
const object_list = @import("object_list.zig");
const portable = @import("portable.zig");
const panels = @import("panels.zig");
const sound = @import("sound.zig");
const update_list = @import("update_list.zig");
const scene_unit = @import("scene.zig");
const scene_loader = @import("scene_loader.zig");
const game_scenes = @import("game_scenes.zig");
const animation = @import("behaviour/animation.zig");
const occupancy = @import("behaviour/occupancy.zig");
const render = @import("behaviour/render.zig");
const space3d = @import("behaviour/space3d.zig");
const visibility = @import("behaviour/visibility.zig");

const Error = errors.Error;

/// Latin-1, as in the original's code segment.
const msg_cannot_write = "N\xe3o foi poss\xedvel gravar o estado atual do jogo.";
const msg_cannot_open = "N\xe3o foi poss\xedvel abrir o arquivo com o estado do jogo desejado.";
const msg_bad_line = "Linha [%s] inv\xe1lida";

/// A reader/loader error the dispatchers cannot return: `Fatal` quits.
fn die(g: *Game, e: Error) void {
    switch (e) {
        error.Fatal => g.quit = true,
        error.LimitExceeded => @panic("save: an unchecked original limit would be exceeded"),
    }
}

fn playerOf(g: *Game) *Object {
    const p = g.player orelse @panic("save: no player");
    return p.as(.player) orelse @panic("save: asPlayer returned NULL"); // the original dereferences NULL
}

fn portableOf(obj: *Object) *Object {
    return obj.as(.portable) orelse @panic("save: asPortable returned NULL"); // the original dereferences NULL
}

fn backdropOf(g: *Game) *world.Backdrop {
    const sc = g.scene orelse @panic("save: no current scene");
    return sc.backdrop orelse @panic("save: scene without backdrop");
}

/// Creates (truncates) `path` for writing; null on failure (the original
/// returns 0 after `_lclose(-1)`). The platform makes the path absolute.
// @orig 1018:489a file_create
pub fn fileCreate(plat: platform.Platform, path: []const u8) ?File {
    return plat.open(cstr.slice(path), .create);
}

/// sprintf into the shared `g_iniPath` buffer, then (while no earlier write
/// failed) `_lwrite` of the result; a write of 0 bytes is a failure.
fn put(g: *Game, fd: File, ok: *bool, comptime fmt: []const u8, args: anytype) void {
    const s = cstr.print(&g.ini.path, fmt, args);
    if (!ok.*) return;
    ok.* = g.plat.write(fd, s) != 0;
}

/// Game slot 0A: writes `<DriveHD><name>.ini` with the scene recorded when
/// the options screen opened, the player position, score, lives, every
/// global object and the carried items. Warns when a write fails.
// @orig 1018:48e2 ini_game_save_game
pub fn saveGame(g: *Game, name: []const u8) void {
    _ = cstr.print(&g.ini.path, "{s}{s}.ini", .{ cstr.slice(&g.driveHD), cstr.slice(name) });
    const fd = fileCreate(g.plat, cstr.slice(&g.ini.path)) orelse {
        ini.messageBoxPrintf(g.plat, &g.messageBuf, "Aviso!", msg_cannot_write, 0);
        return;
    };
    var ok = true;
    const sp = &g.savedPosition;
    put(g, fd, &ok, "StartScene={s} ,{d},{d},{d},{d},{d}\r\n\r\n", .{ cstr.slice(&sp.scene), sp.hasPlayer, sp.hasControlPanel, sp.hasStatusBar, sp.is1Animation, sp.isClickExit });
    const player = g.player orelse @panic("save: no player");
    put(g, fd, &ok, "PlayerX={d}\r\n", .{player.x});
    put(g, fd, &ok, "PlayerY={d}\r\n\r\n", .{player.y});
    // `%d` with a 32-bit argument: the low word only.
    put(g, fd, &ok, "Score={d}\r\n", .{@as(i16, @truncate(g.score))});
    put(g, fd, &ok, "Lives={d}\r\n\r\n", .{g.lives});
    var cur = g.globalObjects.head;
    while (cur) |o| : (cur = o.next) {
        if (!o.is(.portable)) {
            put(g, fd, &ok, "Stat={d},{d},{d}\r\n", .{ o.id, o.x, o.y });
        } else {
            put(g, fd, &ok, "Portab={d},{s} ,{d},{d}\r\n", .{ o.id, cstr.slice(&o.sceneName), o.x, o.y });
        }
    }
    if (ok) ok = g.plat.write(fd, "\r\n") != 0;
    var inv = playerOf(g).actor.inventory.head;
    while (inv) |o| : (inv = o.next) {
        put(g, fd, &ok, "Invent={d}\r\n", .{o.id});
    }
    put(g, fd, &ok, "\r\n\r\n[fim]\r\n\r\n", .{});
    if (!ok) ini.messageBoxPrintf(g.plat, &g.messageBuf, "Aviso!", msg_cannot_write, 0);
    ini.close(g.plat, fd);
}

/// Game slot 0B: reads the `Stat=` / `Invent=` / `Portab=` lines up to the
/// next section. `Stat` moves a global object; `Invent` puts the item in
/// the player's inventory (from the global list, the used items, or where
/// it is); `Portab` puts it on a scene (global list: only the scene name;
/// inventory: back to the global list; used items: home position and
/// scene). Any other line is fatal.
// @orig 1018:4c8e ini_game_load_objects
pub fn loadObjects(g: *Game, fd: File) void {
    loadObjectsImpl(g, fd) catch |e| die(g, e);
}

fn loadObjectsImpl(g: *Game, fd: File) Error!void {
    // The original's stack locals (id, x, y): not reset between lines.
    var id: i16 = 0;
    var x: i16 = 0;
    var y: i16 = 0;
    while (true) {
        const c = std.ascii.toUpper(try ini.peekChar(&g.ini, g.plat, g.fixes, fd));
        switch (c) {
            'S' => {
                _ = try readers.readStat(&g.ini, g.plat, g.fixes, fd, .{ &id, &x, &y });
                if (object_list.findById(&g.globalObjects, id)) |o| {
                    o.x = x;
                    o.y = y;
                }
            },
            'I' => {
                _ = try readers.readInvent(&g.ini, g.plat, g.fixes, fd, .{&id});
                loadInvent(g, id, x, y);
            },
            'P' => {
                _ = try readers.readPortab(&g.ini, g.plat, g.fixes, fd, .{ &id, &g.ini.rec.portScene, &x, &y });
                loadPortab(g, id, x, y);
            },
            '[' => {},
            else => {
                _ = try ini.readLine(g.plat, g.fixes, fd, &g.ini.path);
                ini.messageBoxPrintf(g.plat, &g.messageBuf, "Erro Fatal !!", msg_bad_line, &g.ini.path);
                return error.Fatal; // exit(1)
            },
        }
        if (c == '[') return;
    }
}

/// attach + setElevation(0) against the current scene's backdrop.
fn placeInScene(g: *Game, obj: *Object) void {
    const bd = backdropOf(g);
    _ = occupancy.attach(g, obj, bd);
    _ = space3d.setElevation(g, obj, bd, 0);
}

/// `Invent=` line (x, y: the stale locals of the loop).
fn loadInvent(g: *Game, id: i16, x: i16, y: i16) void {
    const player = playerOf(g);
    if (object_list.findById(&g.globalObjects, id)) |obj| {
        const p = portableOf(obj);
        placeInScene(g, obj);
        _ = object_list.remove(&g.globalObjects, p);
        _ = object_list.add(g, &player.actor.inventory, p);
    } else if (object_list.findById(&player.actor.inventory, id)) |obj| {
        obj.x = x;
        obj.y = y;
        placeInScene(g, obj);
    } else if (object_list.findById(&g.usedObjects, id)) |obj| {
        const p = portableOf(obj);
        _ = object_list.remove(&g.usedObjects, p);
        placeInScene(g, obj);
        _ = portable.pickUp(g, p, playerOf(g));
    }
}

/// `Portab=` line: the scene name just read is `g.ini.rec.portScene`.
fn loadPortab(g: *Game, id: i16, x: i16, y: i16) void {
    const player = playerOf(g);
    if (object_list.findById(&g.globalObjects, id)) |obj| {
        obj.x = x;
        obj.y = y;
        _ = portableOf(obj);
        cstr.copy(&obj.sceneName, &g.ini.rec.portScene);
    } else if (object_list.findById(&player.actor.inventory, id)) |obj| {
        obj.x = x;
        obj.y = y;
        const p = portableOf(obj);
        p.portable.owner = null;
        cstr.copy(&obj.sceneName, &g.ini.rec.portScene);
        _ = object_list.remove(&playerOf(g).actor.inventory, p);
        _ = object_list.add(g, &g.globalObjects, p);
    } else if (object_list.findById(&g.usedObjects, id)) |obj| {
        const p = portableOf(obj);
        obj.x = p.portable.homeX;
        obj.y = p.portable.homeY;
        p.portable.owner = null;
        cstr.copy(&obj.sceneName, &p.portable.homeSceneName);
        _ = object_list.remove(&g.usedObjects, p);
        _ = object_list.add(g, &g.globalObjects, p);
    }
}

/// Game slot 09: loads `<dir><name>.ini` (`jogo0` from the CD directory,
/// the others from the HD one): builds the start scene, restores player
/// position, score, lives and objects, re-attaches everything, redraws and
/// sends 0x401. Returns `g`. A missing file only shows a warning.
// @orig 1018:5274 ini_game_load_game
pub fn loadGame(g: *Game, name: []const u8) *Game {
    loadGameImpl(g, name) catch |e| die(g, e);
    return g;
}

fn loadGameImpl(g: *Game, name: []const u8) Error!void {
    update_list.discard(&g.updateList);
    sound.freeAll(&g.sound, g.plat);
    g.oldScene = g.scene;
    g.prevSceneNumber = (g.scene orelse @panic("save: no current scene")).sceneNumber;
    const dir = if (cstr.eqlIgnoreCase(name, "jogo0")) &g.driveCD else &g.driveHD;
    _ = cstr.print(&g.ini.path, "{s}{s}.ini", .{ cstr.slice(dir), cstr.slice(name) });
    const fd = ini.open(g.plat, cstr.slice(&g.ini.path)) orelse {
        ini.messageBoxPrintf(g.plat, &g.messageBuf, "Aviso!", msg_cannot_open, 0);
        return;
    };
    if (g.oldScene) |old| _ = scene_unit.scalarDtor(g, old, 1);
    g.oldScene = null;
    g.scene = game_scenes.createStartScene(g, fd);
    var px: i16 = 0;
    var py: i16 = 0;
    var score: i16 = 0;
    var lives: i16 = 0;
    _ = try readers.readPlayerX(&g.ini, g.plat, g.fixes, fd, .{&px});
    _ = try readers.readPlayerY(&g.ini, g.plat, g.fixes, fd, .{&py});
    _ = try readers.readScore(&g.ini, g.plat, g.fixes, fd, .{&score});
    _ = try readers.readLives(&g.ini, g.plat, g.fixes, fd, .{&lives});
    // GetDC + PatBlt(BLACKNESS, clearWidth x clearHeight): nothing to clear.
    const scene = g.scene orelse @panic("save: createStartScene returned NULL");
    _ = try ini.seekSection(&g.ini, g.plat, g.fixes, g.ini.file orelse 0, cstr.slice(&scene.name), true);
    _ = scene_loader.create(g, scene);
    const player = g.player orelse @panic("save: no player");
    player.x = px;
    player.y = py;
    const pl = playerOf(g);
    pl.actor.score = score; // sign-extended
    g.score = score;
    playerOf(g).actor.lives = lives;
    g.lives = lives;
    loadObjects(g, fd);
    if (g.fixes.close_loaded_save) ini.close(g.plat, fd); // B4
    object_list.attachToScene(g, &g.globalObjects, scene);
    g.itemSelected = 0;
    g.exitPending = 0;
    const cp = g.controlPanel orelse @panic("save: no control panel");
    panels.reset(g, cp);
    const bd = backdropOf(g);
    if (scene_unit.getHasPlayer(g, scene)) {
        player.linked = null;
        _ = occupancy.reattach(g, player, bd);
    }
    if (scene_unit.getHasStatusBar(g, scene)) {
        const sb = g.statusBar orelse @panic("save: no status bar");
        _ = occupancy.reattach(g, sb, bd);
        visibility.show(g, sb, bd);
    }
    if (scene_unit.getHasControlPanel(g, scene)) {
        _ = occupancy.reattach(g, cp, bd);
        visibility.show(g, cp, bd);
    }
    if (scene_unit.getHasPlayer(g, scene)) {
        space3d.moveToAndDrop(g, player, px, py, bd);
        visibility.show(g, player, bd);
    }
    if (scene_unit.getHasStatusBar(g, scene)) render.draw(g, g.statusBar.?, bd);
    if (scene_unit.getHasControlPanel(g, scene)) render.draw(g, cp, bd);
    if (scene_unit.getHasPlayer(g, scene)) animation.playIdle(g, player, bd);
    // ReleaseDC, InvalidateRect(window): the platform's screen needs neither.
    _ = g.send(.{ .id = msg.noite.scene_started });
}
