//! Port unit `scene_loader` (module). ini_scene_create: builds a scene and its objects from its INI section.
//!
//! Scene slot 07 of the INI scene class: reads `Screen=` (builds the
//! perspective backdrop), `Limits=` (blocks occupancy cells) and then one
//! line per object (`Exit=`, `2Exit=`, `C_Actor=`, `Animated=`, `Local=`,
//! `Static=`, `Moveable=`) until the next section header, which enables
//! the scene handler. Each object is allocated with `g.gpa.create(Object)`
//! (the scene's destructor frees it), attached to the backdrop and
//! announced with 0x406 (sent, with `Game.newObject` set).
//!
//! The original's fatal paths that end the program (an unknown INI line:
//! `exit(1)`, a failing constructor) are `die`: the callers cannot take an
//! error (their `_ = scene_loader.create(..)` discards it).

const std = @import("std");
const Game = @import("core/game.zig").Game;
const world = @import("core/world.zig");
const Scene = world.Scene;
const Backdrop = world.Backdrop;
const object = @import("core/object.zig");
const Object = object.Object;
const cstr = @import("core/cstr.zig");
const msg_mod = @import("core/msg.zig");
const Msg = msg_mod.Msg;
const noite = msg_mod.noite;
const File = @import("platform/platform.zig").File;
const ini = @import("ini.zig");
const ini_readers = @import("ini_readers.zig");
const scene_mod = @import("scene.zig");
const backdrop = @import("backdrop.zig");
const exit = @import("exit.zig");
const object_create = @import("object_create.zig");
const object_list = @import("object_list.zig");
const draw_list = @import("draw_list.zig");
const frames = @import("frames.zig");
const sound = @import("sound.zig");
const avi = @import("avi.zig");
const game = @import("game.zig");
const grid_unit = @import("grid.zig");
const occupancy = @import("behaviour/occupancy.zig");
const render = @import("behaviour/render.zig");
const space3d = @import("behaviour/space3d.zig");
const visibility = @import("behaviour/visibility.zig");

/// Errors that end the original program or corrupt its memory: nothing in
/// the shipped data reaches them, except `error.Fatal` (the original's
/// `exit(1)` after its "Erro Fatal" box), which ends the run the same way.
fn die(e: anyerror) noreturn {
    if (e == error.Fatal) {
        @import("std").log.err("the original exits here: exit(1) after its \"Erro Fatal\" box", .{});
        @import("std").process.exit(1);
    }
    @panic(@errorName(e));
}

/// What the loader keeps between lines: the game, the scene, its backdrop
/// and the original's 256-byte local that holds the WAVE path.
const Loader = struct {
    g: *Game,
    scene: *Scene,
    bd: *Backdrop,
    /// `local_21a`: filled by every wave open, read (stale) by the
    /// Moveable case (see `moveableWave`). Zero here; stack junk there.
    wave_path: [256]u8 = @splat(0),

    fn fd(ld: *Loader) File {
        return ld.g.ini.file orelse 0;
    }
};

/// `_fstrlwr` in place.
fn lowerInPlace(s: []u8) void {
    for (s) |*c| {
        if (c.* == 0) break;
        c.* = std.ascii.toLower(c.*);
    }
}

fn newObject(g: *Game) *Object {
    return g.gpa.create(Object) catch @panic("scene_loader: out of memory");
}

/// The line's bitmap path (`<NomeBMP>.bmp`), copied into the loader's
/// 256-byte local.
fn bmpPath(g: *Game, buf: *[256]u8) []const u8 {
    cstr.copy(buf, ini.assetPath(&g.ini, &g.driveCD, &g.driveHD, &g.ini.rec.bmpName, -1));
    return cstr.slice(buf);
}

/// Opens `<NomeWAVE>.wav` into `obj.wave`.
fn openWave(ld: *Loader, obj: *Object) void {
    const g = ld.g;
    cstr.copy(&ld.wave_path, ini.assetPath(&g.ini, &g.driveCD, &g.driveHD, &g.ini.rec.nomeWave, -3));
    obj.wave = sound.open(g, cstr.slice(&ld.wave_path)) catch |e| die(e);
}

/// NomeWAVE `0` means no wave, anything else is opened.
fn waveFromName(ld: *Loader, obj: *Object) void {
    if (cstr.eqlIgnoreCase(&ld.g.ini.rec.nomeWave, "0")) {
        obj.wave = null;
    } else {
        openWave(ld, obj);
    }
}

/// The Moveable case: the original compares its wave-path local, not
/// NomeWAVE, with "0" (a copy-paste slip: the local still holds stack junk,
/// or the path of an earlier line). Only `Moveable=` lines are affected
/// and every one has a name, so the result is the normal open.
fn moveableWave(ld: *Loader, obj: *Object) void {
    if (cstr.eqlIgnoreCase(&ld.wave_path, "0")) {
        obj.wave = null;
    } else {
        openWave(ld, obj);
    }
}

/// Animation clip: no wave, mark as AVI, name = NomeBMP as written.
fn aviSetup(g: *Game, obj: *Object) void {
    obj.wave = null;
    avi.setAvi(g, obj);
    avi.setAviName(g, obj, cstr.slice(&g.ini.rec.bmpName));
}

/// Attach to the backdrop, 3D anchor and size, elevation 0 (slots 2A, 13,
/// 14, 12).
fn place(ld: *Loader, obj: *Object) void {
    const g = ld.g;
    const r = &g.ini.rec;
    _ = occupancy.attach(g, obj, ld.bd);
    _ = space3d.setAnchor(g, obj, r.originX3d, r.originY3d);
    _ = space3d.setSize(g, obj, r.w3d, r.h3d, r.d3d);
    _ = space3d.setElevation(g, obj, ld.bd, 0);
}

/// `exit_set_target` from the line's scene name (lower-cased in place) and
/// flags.
fn exitTarget(g: *Game, obj: *Object) void {
    const r = &g.ini.rec;
    lowerInPlace(&r.sceneInName);
    _ = exit.setTarget(g, obj, cstr.slice(&r.sceneInName), r.exitPlayerX, r.exitPlayerY, r.hasPlayer, r.hasControlPanel, r.hasStatusBar);
}

/// The common ending of a line that made `obj`: redraw what it overlaps,
/// refresh an object that already existed, announce it with 0x406.
fn announce(ld: *Loader, obj: *Object, existing: bool) void {
    const g = ld.g;
    visibility.redrawOverlapping(g, obj, ld.bd, 0);
    if (existing) {
        frames.resetRects(obj);
        _ = visibility.invalidate(g, obj);
    }
    g.newObject = obj;
    _ = g.send(Msg.make(noite.object_created, @bitCast(obj.id), 0, 0));
}

/// `Exit=` / `2Exit=` / 1Animation: the Exit object of the current line
/// (visible unless it is an AVI), wave or clip set up.
fn exitObject(ld: *Loader, visible: i16) *Object {
    const g = ld.g;
    const r = &g.ini.rec;
    var path: [256]u8 = undefined;
    const p = bmpPath(g, &path);
    const obj = newObject(g);
    object_create.exitCtor(g, obj, r.number, r.x, r.y, p, r.numFrames, r.frameW, r.frameH, r.boundX, r.boundY, r.boundW, r.boundH, r.numTimer, r.perTimer, 0, visible, 0, true) catch |e| die(e);
    return obj;
}

// @orig 1018:6bee ini_scene_create
/// Scene slot 07 (INI scene): loads the scene from its section; see the
/// module notes. Returns `scene`.
pub fn create(g: *Game, scene: *Scene) ?*Scene {
    const r = &g.ini.rec;
    const fd: File = g.ini.file orelse 0;
    g.curSceneName = scene.name;
    _ = ini.seekSection(&g.ini, g.plat, g.fixes, fd, cstr.slice(&g.curSceneName), true) catch |e| die(e);
    _ = ini_readers.readScreen(&g.ini, g.plat, g.fixes, fd, .{
        &r.number,        &r.screenBmp,    &r.screenX,     &r.screenY, &r.screenW,
        &r.screenH,       &r.vanishX,      &r.vanishY,     &r.viewX,   &r.viewY,
        &r.view3dX,       &r.view3dY,      &r.view3dZ,     &r.axisX,   &r.axisY,
        &r.mayDropObject, &r.is1Animation, &r.isClickExit,
    }) catch |e| die(e);
    if (r.mayDropObject == 0) _ = scene_mod.clearMayDropObject(scene);
    scene.sceneNumber = r.number;

    var screen_path: [256]u8 = undefined;
    cstr.copy(&screen_path, ini.assetPath(&g.ini, &g.driveCD, &g.driveHD, &r.screenBmp, -1));
    const new_bd = g.gpa.create(Backdrop) catch @panic("scene_loader: out of memory");
    new_bd.* = .{};
    scene.backdrop = backdrop.ctor(g, new_bd, cstr.slice(&screen_path), r.screenX, r.screenY, r.screenW, r.screenH) catch |e| die(e);
    // Backdrop slot 00 (create), then slot 15 (the type test that returns
    // the PerspectiveBackdrop: the same object).
    const bd = backdrop.create(g, new_bd) orelse @panic("scene_loader: backdrop create failed");
    bd.sceneList = &scene.objects;
    _ = backdrop.setVanishPoint(g, bd, r.vanishX, r.vanishY);
    _ = backdrop.setView(g, bd, r.viewX, r.viewY, r.view3dX, r.view3dY, r.view3dZ);
    _ = backdrop.setAxis(g, bd, r.axisX, r.axisY);

    _ = ini_readers.readLimits(&g.ini, g.plat, g.fixes, fd, .{
        &r.limits[0], &r.limits[1], &r.limits[2], &r.limits[3],
        &r.limits[4], &r.limits[5], &r.limits[6], &r.limits[7],
    }) catch |e| die(e);
    const grid = bd.grid orelse @panic("scene_loader: backdrop has no grid");
    const lim = &r.limits;
    var row: i16 = 0;
    while (row < lim[0]) : (row += 1) {
        var col: i16 = 0;
        while (col < lim[1]) : (col += 1) grid_unit.setCell(grid, null, -1, col, row);
    }
    var width: i16 = lim[3];
    row = lim[0];
    while (row < lim[2]) : (row += 1) {
        var col: i16 = 0;
        while (col < width) : (col += 1) grid_unit.setCell(grid, null, -1, col, row);
        width -%= lim[4];
    }
    var shift: i16 = 0;
    row = lim[0];
    while (row < lim[5]) : (row += 1) {
        var col: i16 = shift +% lim[6];
        while (col < 0x28) : (col += 1) grid_unit.setCell(grid, null, -1, col, row);
        shift +%= lim[7];
    }

    var ld: Loader = .{ .g = g, .scene = scene, .bd = bd };
    if (r.isClickExit != 0) scene_mod.setIsClickExit(scene);
    if (r.is1Animation != 0) {
        scene_mod.setIs1Animation(scene);
        loadOneAnimation(&ld);
    }

    while (true) {
        const c = std.ascii.toUpper(ini.peekChar(&g.ini, g.plat, g.fixes, fd) catch |e| die(e));
        var made: ?*Object = null;
        var existing = false;
        switch (c) {
            'W' => _ = ini.readLine(g.plat, g.fixes, fd, null) catch |e| die(e),
            '[' => {
                scene.handlerEnabled = 1;
                return scene;
            },
            'E' => made = loadExit(&ld),
            '2' => made = loadExit2(&ld),
            'C' => made = loadActor(&ld),
            'A' => made = loadAnimated(&ld),
            'L' => made = loadLocal(&ld),
            'M' => made = loadMoveable(&ld),
            'S' => made = loadStatic(&ld, &existing),
            else => {
                var line: [256]u8 = @splat(0);
                _ = ini.readLine(g.plat, g.fixes, fd, &line) catch |e| die(e);
                ini.messageBoxPrintf(g.plat, &g.messageBuf, "Erro Fatal !!", "Linha [%s] inv\xe1lida", cstr.slice(&line));
                die(error.Fatal); // exit(1)
            },
        }
        if (made) |obj| announce(&ld, obj, existing);
    }
}

/// The `Is_1Animation` scene's own Exit line: not added to the object list;
/// it becomes `scene.animation`.
fn loadOneAnimation(ld: *Loader) void {
    const g = ld.g;
    const scene = ld.scene;
    const r = &g.ini.rec;
    readExitLine(ld);
    const obj = exitObject(ld, if (r.isAvi == 0) 1 else 0);
    scene.animation = obj;
    if (r.isAvi == 0) {
        waveFromName(ld, obj);
    } else {
        aviSetup(g, obj);
    }
    // Here the anchor and size come before the attach.
    _ = space3d.setAnchor(g, obj, r.originX3d, r.originY3d);
    _ = space3d.setSize(g, obj, r.w3d, r.h3d, r.d3d);
    _ = occupancy.attach(g, obj, ld.bd);
    _ = space3d.setElevation(g, obj, ld.bd, 0);
    exitTarget(g, obj);
    _ = scene_mod.addExit(g, scene, obj);
    _ = exit.setKeyObject(obj, r.keyObject);
    announce(ld, obj, false);
}

/// Reads the `Exit=` line into the record.
fn readExitLine(ld: *Loader) void {
    const g = ld.g;
    const r = &g.ini.rec;
    _ = ini_readers.readExit(&g.ini, g.plat, g.fixes, ld.fd(), .{
        &r.number,    &r.x,               &r.y,            &r.bmpName,
        &r.frameW,    &r.frameH,          &r.boundX,       &r.boundY,
        &r.boundW,    &r.boundH,          &r.originX3d,    &r.originY3d,
        &r.w3d,       &r.h3d,             &r.d3d,          &r.numTimer,
        &r.perTimer,  &r.sceneInName,     &r.exitPlayerX,  &r.exitPlayerY,
        &r.hasPlayer, &r.hasControlPanel, &r.hasStatusBar, &r.isAvi,
        &r.keyObject, &r.numFrames,       &r.nomeWave,
    }) catch |e| die(e);
}

/// `Exit=`: an Exit object in the scene's object list and exit table.
fn loadExit(ld: *Loader) *Object {
    const g = ld.g;
    const scene = ld.scene;
    const r = &g.ini.rec;
    readExitLine(ld);
    const obj = exitObject(ld, if (r.isAvi == 0) 1 else 0);
    if (r.isAvi == 0) {
        waveFromName(ld, obj);
    } else {
        aviSetup(g, obj);
    }
    place(ld, obj);
    exitTarget(g, obj);
    scene_mod.addObject(g, scene, obj);
    _ = scene_mod.addExit(g, scene, obj);
    _ = exit.setKeyObject(obj, r.keyObject);
    return obj;
}

/// `2Exit=`: an Exit with an alternative target.
fn loadExit2(ld: *Loader) *Object {
    const g = ld.g;
    const scene = ld.scene;
    const r = &g.ini.rec;
    _ = ini_readers.readExit2(&g.ini, g.plat, g.fixes, ld.fd(), .{
        &r.number,    &r.x,               &r.y,            &r.bmpName,
        &r.frameW,    &r.frameH,          &r.boundX,       &r.boundY,
        &r.boundW,    &r.boundH,          &r.originX3d,    &r.originY3d,
        &r.w3d,       &r.h3d,             &r.d3d,          &r.numTimer,
        &r.perTimer,  &r.sceneInName,     &r.exitPlayerX,  &r.exitPlayerY,
        &r.hasPlayer, &r.hasControlPanel, &r.hasStatusBar, &r.isAvi,
        &r.keyObject, &r.exit2Str,        &r.exit2F27,     &r.exit2F28,
        &r.numFrames, &r.nomeWave,
    }) catch |e| die(e);
    const obj = exitObject(ld, 1);
    place(ld, obj);
    exitTarget(g, obj);
    waveFromName(ld, obj);
    scene_mod.addObject(g, scene, obj);
    _ = scene_mod.addExit(g, scene, obj);
    lowerInPlace(&r.exit2Str);
    _ = scene_mod.addExitAlt(g, scene, obj, cstr.slice(&r.exit2Str), r.exit2F27, r.exit2F28);
    _ = exit.setKeyObject(obj, r.keyObject);
    return obj;
}

/// `C_Actor=`: an Actor (a Moveable with an inventory).
fn loadActor(ld: *Loader) *Object {
    const g = ld.g;
    const r = &g.ini.rec;
    _ = ini_readers.readCActor(&g.ini, g.plat, g.fixes, ld.fd(), .{
        &r.number,   &r.x,      &r.y,         &r.bmpName,
        &r.frameW,   &r.frameH, &r.boundX,    &r.boundY,
        &r.boundW,   &r.boundH, &r.originX3d, &r.originY3d,
        &r.w3d,      &r.h3d,    &r.d3d,       &r.numTimer,
        &r.perTimer, &r.deltaX, &r.deltaY,    &r.numFrames,
        &r.nomeWave,
    }) catch |e| die(e);
    var path: [256]u8 = undefined;
    const p = bmpPath(g, &path);
    const obj = newObject(g);
    object_create.actorCtor(g, obj, r.number, r.x, r.y, p, r.numFrames, r.frameW, r.frameH, r.boundX, r.boundY, r.boundW, r.boundH, r.numTimer, r.perTimer, r.deltaX, r.deltaY, 1, 1, 0, true) catch |e| die(e);
    place(ld, obj);
    waveFromName(ld, obj);
    scene_mod.addObject(g, ld.scene, obj);
    return obj;
}

/// `Animated=`: an Animated3D (an AVI clip when the line says so).
fn loadAnimated(ld: *Loader) *Object {
    const g = ld.g;
    const r = &g.ini.rec;
    _ = ini_readers.readAnimated(&g.ini, g.plat, g.fixes, ld.fd(), .{
        &r.number,   &r.x,      &r.y,         &r.bmpName,
        &r.frameW,   &r.frameH, &r.boundX,    &r.boundY,
        &r.boundW,   &r.boundH, &r.originX3d, &r.originY3d,
        &r.w3d,      &r.h3d,    &r.d3d,       &r.numTimer,
        &r.perTimer, &r.isAvi,  &r.numFrames, &r.nomeWave,
    }) catch |e| die(e);
    var path: [256]u8 = undefined;
    const p = bmpPath(g, &path);
    const obj = newObject(g);
    const visible: i16 = if (r.isAvi == 0) 1 else 0;
    object_create.animated3dCtor(g, obj, r.number, r.x, r.y, p, r.numFrames, r.frameW, r.frameH, r.boundX, r.boundY, r.boundW, r.boundH, r.numTimer, r.perTimer, 0, visible, 0, true) catch |e| die(e);
    if (r.isAvi == 0) {
        waveFromName(ld, obj);
    } else {
        aviSetup(g, obj);
    }
    place(ld, obj);
    scene_mod.addObject(g, ld.scene, obj);
    return obj;
}

/// `Local=`: a plain Object3D (no wave).
fn loadLocal(ld: *Loader) *Object {
    const g = ld.g;
    const r = &g.ini.rec;
    _ = ini_readers.readLocal(&g.ini, g.plat, g.fixes, ld.fd(), .{
        &r.number, &r.x,      &r.y,         &r.bmpName,
        &r.frameW, &r.frameH, &r.boundX,    &r.boundY,
        &r.boundW, &r.boundH, &r.originX3d, &r.originY3d,
        &r.w3d,    &r.h3d,    &r.d3d,
    }) catch |e| die(e);
    var path: [256]u8 = undefined;
    const p = bmpPath(g, &path);
    const obj = newObject(g);
    object_create.object3dCtor(g, obj, r.number, r.x, r.y, p, r.frameW, r.frameH, r.boundX, r.boundY, r.boundW, r.boundH, 1, 0, true) catch |e| die(e);
    place(ld, obj);
    obj.wave = null;
    scene_mod.addObject(g, ld.scene, obj);
    return obj;
}

/// `Moveable=`: a Moveable (one-frame strip).
fn loadMoveable(ld: *Loader) *Object {
    const g = ld.g;
    const r = &g.ini.rec;
    _ = ini_readers.readMoveable(&g.ini, g.plat, g.fixes, ld.fd(), .{
        &r.number,   &r.x,      &r.y,         &r.bmpName,
        &r.frameW,   &r.frameH, &r.boundX,    &r.boundY,
        &r.boundW,   &r.boundH, &r.originX3d, &r.originY3d,
        &r.w3d,      &r.h3d,    &r.d3d,       &r.numTimer,
        &r.perTimer, &r.deltaX, &r.deltaY,    &r.nomeWave,
    }) catch |e| die(e);
    var path: [256]u8 = undefined;
    const p = bmpPath(g, &path);
    const obj = newObject(g);
    object_create.moveableCtor(g, obj, r.number, r.x, r.y, p, 1, r.frameW, r.frameH, r.boundX, r.boundY, r.boundW, r.boundH, r.numTimer, r.perTimer, r.deltaX, r.deltaY, 1, 0, true) catch |e| die(e);
    place(ld, obj);
    moveableWave(ld, obj);
    scene_mod.addObject(g, ld.scene, obj);
    return obj;
}

/// `Static=`: a persistent object of the whole game. The first scene to
/// name it creates it (into the global list); later scenes re-draw the one
/// that exists. `existing` is set when it did.
fn loadStatic(ld: *Loader, existing: *bool) ?*Object {
    const g = ld.g;
    const scene = ld.scene;
    const r = &g.ini.rec;
    _ = ini_readers.readStatic(&g.ini, g.plat, g.fixes, ld.fd(), .{
        &r.number,   &r.x,         &r.y,         &r.bmpName,
        &r.frameW,   &r.frameH,    &r.boundX,    &r.boundY,
        &r.boundW,   &r.boundH,    &r.originX3d, &r.originY3d,
        &r.w3d,      &r.h3d,       &r.d3d,       &r.numTimer,
        &r.perTimer, &r.numFrames, &r.nomeWave,
    }) catch |e| die(e);
    var path: [256]u8 = undefined;
    const p = bmpPath(g, &path);
    const found = object_list.findById(&g.globalObjects, r.number);
    if (found) |f| {
        const o = f.as(.object3d);
        if (o) |obj| {
            existing.* = true;
            // B33: the draw uses the dirty rectangle the last overlap left
            // in the previous visit; the original resets it only after.
            if (g.fixes.static_redraw_whole_frame) frames.resetRects(obj);
            render.draw(g, obj, ld.bd);
            _ = occupancy.occupy(g, obj, ld.bd);
            obj.visible = 1;
            frames.resetRects(obj);
            obj.linked = null;
            cstr.copy(&obj.sceneName, &scene.name);
        }
        _ = draw_list.insert(g, ld.bd, o);
        return o;
    }
    const obj = newObject(g);
    object_create.animated3dCtor(g, obj, r.number, r.x, r.y, p, r.numFrames, r.frameW, r.frameH, r.boundX, r.boundY, r.boundW, r.boundH, r.numTimer, r.perTimer, 0, 1, 0, true) catch |e| die(e);
    place(ld, obj);
    waveFromName(ld, obj);
    game.addGlobalObject(g, cstr.slice(&scene.name), obj);
    _ = draw_list.insert(g, ld.bd, obj.as(.object3d));
    return obj;
}
