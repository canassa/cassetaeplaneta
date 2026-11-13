//! Port unit `object_create` (module). most-derived constructors: one per kind (INI objects, player, panels, portables).
//!
//! Each constructor builds a whole `Object` of one kind: it resets the object
//! to the field defaults (the original's uninitialised heap bytes) with the
//! `kind` set (the original installs the class vtables and vbtables here),
//! builds the virtual bases when `init_vbases` (SceneObject, then Object3D),
//! chains to the base-part constructors of `object_init` with `init_vbases =
//! false`, and sets the fields of its own class. Allocate the object with
//! `g.gpa.create(Object)`; the scalar destructors in `object_init` free it.
//!
//! Parameters follow DESIGN.md: `(g, obj, <source order>, init_vbases)`, the
//! Ghidra list reversed.

const std = @import("std");
const Game = @import("core/game.zig").Game;
const object = @import("core/object.zig");
const Object = object.Object;
const Kind = object.Kind;
const Frame = object.Frame;
const cstr = @import("core/cstr.zig");
const errors = @import("core/errors.zig");
const dib_mod = @import("dib.zig");
const frames = @import("frames.zig");
const ini = @import("ini.zig");
const object_list = @import("object_list.zig");
const oi = @import("object_init.zig");

const Error = errors.Error;

/// What every most-derived constructor starts with: fresh object of `kind`,
/// then (complete object only) the SceneObject and Object3D virtual bases.
fn begin(g: *Game, obj: *Object, kind: Kind, init_vbases: bool, has_object3d: bool) void {
    obj.* = .{ .kind = kind };
    if (init_vbases) {
        oi.sceneObjectCtorDefault(g, obj);
        if (has_object3d) oi.object3dCtorDefault(g, obj, false);
    }
}

/// The 3D size and support words the INI-object constructors clear.
fn clearSizes(obj: *Object) void {
    obj.o3d.sizeW = 0;
    obj.o3d.sizeH = 0;
    obj.o3d.sizeD = 0;
}

/// `_fstrncpy(dst, src, 0x13)` then `dst[0x13] = 0`.
fn copyName19(dst: []u8, src: []const u8) void {
    const s = cstr.slice(src);
    var i: usize = 0;
    while (i < 0x13) : (i += 1) dst[i] = if (i < s.len) s[i] else 0;
    dst[0x13] = 0;
}

// @orig 1018:633e object3d_ctor
/// INI `Local=` object: one-strip bitmap with hit box, position, visibility,
/// the INI number as id, no 3D size and no support.
pub fn object3dCtor(
    g: *Game,
    obj: *Object,
    id: i16,
    x: i16,
    y: i16,
    bmp_path: []const u8,
    width: i16,
    height: i16,
    hit_x: i16,
    hit_y: i16,
    hit_w: i16,
    hit_h: i16,
    visible: i16,
    unk10: u16,
    init_vbases: bool,
) Error!void {
    begin(g, obj, .local, init_vbases, false);
    try frames.initStrip(g, obj, bmp_path, 1, width, height, hit_x, hit_y, hit_w, hit_h);
    frames.initState(g, obj, x, y, visible, unk10);
    obj.id = id;
    clearSizes(obj);
    obj.o3d.support = null;
}

// @orig 1018:6400 animated3d_ctor
/// INI `Animated=` / `Static=` object: one-bitmap Animation, id, no 3D size
/// and no support.
pub fn animated3dCtor(
    g: *Game,
    obj: *Object,
    id: i16,
    x: i16,
    y: i16,
    bmp_path: []const u8,
    count: i16,
    width: i16,
    height: i16,
    hit_x: i16,
    hit_y: i16,
    hit_w: i16,
    hit_h: i16,
    timer_id: i16,
    timer_period: i16,
    play_once_rewinds: i16,
    visible: i16,
    unk10: u16,
    init_vbases: bool,
) Error!void {
    begin(g, obj, .animated, init_vbases, true);
    try oi.animationCtor(g, obj, x, y, bmp_path, count, width, height, hit_x, hit_y, hit_w, hit_h, timer_id, timer_period, play_once_rewinds, visible, unk10, false);
    obj.id = id;
    clearSizes(obj);
    obj.o3d.support = null;
}

// @orig 1018:64fc moveable_ctor
/// INI `Moveable=` object: one-bitmap Mover (step = DeltaX/DeltaY, timer =
/// NumTimer/PerTimer), id, no 3D size and no support.
pub fn moveableCtor(
    g: *Game,
    obj: *Object,
    id: i16,
    x: i16,
    y: i16,
    bmp_path: []const u8,
    count: i16,
    width: i16,
    height: i16,
    hit_x: i16,
    hit_y: i16,
    hit_w: i16,
    hit_h: i16,
    timer_id: i16,
    timer_period: i16,
    step_x: i16,
    step_y: i16,
    visible: i16,
    unk10: u16,
    init_vbases: bool,
) Error!void {
    begin(g, obj, .moveable, init_vbases, true);
    try oi.moverCtorStrips(g, obj, x, y, 1, &.{bmp_path}, &.{count}, &.{width}, &.{height}, hit_x, hit_y, hit_w, hit_h, timer_id, timer_period, step_x, step_y, visible, unk10, false);
    obj.id = id;
    clearSizes(obj);
    obj.o3d.support = null;
}

// @orig 1018:6614 actor_ctor
/// INI `C_Actor=` object: a one-bitmap Moveable plus a default Animated3D
/// sharing its timer, an empty inventory (capacity 8) and the INI id.
pub fn actorCtor(
    g: *Game,
    obj: *Object,
    id: i16,
    x: i16,
    y: i16,
    bmp_path: []const u8,
    count: i16,
    width: i16,
    height: i16,
    hit_x: i16,
    hit_y: i16,
    hit_w: i16,
    hit_h: i16,
    timer_id: i16,
    timer_period: i16,
    step_x: i16,
    step_y: i16,
    play_once_rewinds: i16,
    visible: i16,
    unk10: u16,
    init_vbases: bool,
) Error!void {
    begin(g, obj, .actor, init_vbases, true);
    try oi.moveableCtorStrips(g, obj, x, y, 1, &.{bmp_path}, &.{count}, &.{width}, &.{height}, hit_x, hit_y, hit_w, hit_h, timer_id, timer_period, step_x, step_y, visible, unk10, false);
    oi.animated3dCtorDefault(g, obj, false);
    _ = object_list.ctor(&obj.actor.inventory, 8);
    obj.id = id;
    obj.anim.timerId = timer_id;
    obj.mover.timerId = timer_id;
    obj.anim.timerPeriod = timer_period;
    obj.mover.timerPeriod = timer_period;
    obj.playOnceRewinds = @bitCast(play_once_rewinds);
}

// @orig 1018:37ba directional_player_ctor
/// The player (INI `Player=`): the Player base with the same arguments.
pub fn directionalPlayerCtor(
    g: *Game,
    obj: *Object,
    id: i16,
    x: i16,
    y: i16,
    count: i16,
    timer_id: i16,
    timer_period: i16,
    step_x: i16,
    step_y: i16,
    visible: i16,
    unk10: u16,
    init_vbases: bool,
) Error!void {
    begin(g, obj, .player, init_vbases, true);
    try oi.playerCtor(g, obj, id, x, y, count, timer_id, timer_period, step_x, step_y, visible, unk10, false);
}

// @orig 1018:6778 exit_ctor
/// INI `Exit=` / `2Exit=` object (also an Is_1Animation scene's animation):
/// one-bitmap Animated3D, id, link to no scene (player at 200,100), the
/// always-true condition, no exit index, key or alternative, all scene flags
/// set.
pub fn exitCtor(
    g: *Game,
    obj: *Object,
    id: i16,
    x: i16,
    y: i16,
    bmp_path: []const u8,
    count: i16,
    width: i16,
    height: i16,
    hit_x: i16,
    hit_y: i16,
    hit_w: i16,
    hit_h: i16,
    timer_id: i16,
    timer_period: i16,
    play_once_rewinds: i16,
    visible: i16,
    unk10: u16,
    init_vbases: bool,
) Error!void {
    begin(g, obj, .exit, init_vbases, true);
    try oi.animated3dCtorStrips(g, obj, x, y, 1, &.{bmp_path}, &.{count}, &.{width}, &.{height}, hit_x, hit_y, hit_w, hit_h, timer_id, timer_period, play_once_rewinds, visible, unk10, false);
    obj.id = id;
    obj.exit.condition = &g.conditionTrue;
    obj.exit.sceneName[0] = 0;
    obj.exit.playerX = 200;
    obj.exit.playerY = 100;
    obj.exit.exitIndex = -1;
    obj.exit.framesLeft = 0;
    obj.exit.playing = 0;
    clearSizes(obj);
    obj.exit.keyObject = 0;
    obj.exit.altExitIndex = -1;
    obj.exit.altSceneName[0] = 0;
    obj.exit.altPlayerX = 200;
    obj.exit.altPlayerY = 100;
    obj.exit.hasPlayer = 1;
    obj.exit.hasControlPanel = 1;
    obj.exit.hasStatusBar = 1;
}

// @orig 1010:4504 control_panel_ctor
/// INI `Control=` panel: one-bitmap Animated3D without hit box, closed.
pub fn controlPanelCtor(
    g: *Game,
    obj: *Object,
    x: i16,
    y: i16,
    bmp_path: []const u8,
    count: i16,
    width: i16,
    height: i16,
    timer_id: i16,
    timer_period: i16,
    play_once_rewinds: i16,
    visible: i16,
    unk10: u16,
    init_vbases: bool,
) Error!void {
    begin(g, obj, .control_panel, init_vbases, true);
    try oi.animated3dCtorStripsNoHitbox(g, obj, x, y, 1, &.{bmp_path}, &.{count}, &.{width}, &.{height}, timer_id, timer_period, play_once_rewinds, visible, unk10, false);
    obj.panel.slideStepsLeft = 0;
    obj.panel.isOpen = 0;
}

// @orig 1018:38b4 status_bar_ctor
/// INI `StatusBar=`: a plain SceneObject with one bitmap strip plus the text
/// colour (COLORREF).
pub fn statusBarCtor(
    g: *Game,
    obj: *Object,
    x: i16,
    y: i16,
    text_color: u32,
    bmp_path: []const u8,
    frame_count: i16,
    frame_w: i16,
    frame_h: i16,
    visible: i16,
    unk10: u16,
) Error!void {
    obj.* = .{ .kind = .status_bar };
    try oi.sceneObjectCtor(g, obj, x, y, bmp_path, frame_count, frame_w, frame_h, visible, unk10);
    obj.status.textColor = text_color;
}

/// The Portable fields both constructors end with (the scene name is also the
/// previous and home scene), then the object joins the game's global list.
fn portableTail(g: *Game, obj: *Object, id: i16, scene_name: []const u8, x: i16, y: i16) void {
    obj.id = id;
    obj.portable.scoreTake = 0;
    obj.portable.scoreUse = 0;
    obj.portable.scoreMisuse = 0;
    obj.portable.owner = null;
    copyName19(&obj.sceneName, scene_name);
    copyName19(&obj.portable.prevSceneName, scene_name);
    copyName19(&obj.portable.homeSceneName, scene_name);
    obj.portable.homeX = x;
    obj.portable.homeY = y;
    obj.o3d.worldElev = 0;
    _ = object_list.add(g, &g.globalObjects, obj);
}

// @orig 1010:6e2c portable_ctor
/// INI `Portable=` item: a one-bitmap Moveable that falls 10 px per tick,
/// with id, scene (also previous and home scene) and home position, no owner,
/// icon or scores; added to the global object list.
pub fn portableCtor(
    g: *Game,
    obj: *Object,
    id: i16,
    scene_name: []const u8,
    x: i16,
    y: i16,
    bmp_path: []const u8,
    width: i16,
    height: i16,
    hit_x: i16,
    hit_y: i16,
    hit_w: i16,
    hit_h: i16,
    timer_id: i16,
    timer_period: i16,
    visible: i16,
    unk10: u16,
    init_vbases: bool,
) Error!void {
    begin(g, obj, .portable, init_vbases, true);
    try oi.moveableCtorBitmap(g, obj, x, y, bmp_path, 1, width, height, hit_x, hit_y, hit_w, hit_h, timer_id, timer_period, 0, 10, visible, unk10, false);
    portableTail(g, obj, id, scene_name, x, y);
}

// @orig 1010:6b6e portable_ctor_zoom
/// INI `ZoomPort=` item: like `portableCtor` but with two strips and no hit
/// box: strip 0 the enlarged image, strip 1 the icon-sized one. A missing
/// file shows the "Erro Fatal!!" box and leaves that strip's `dib` null.
pub fn portableCtorZoom(
    g: *Game,
    obj: *Object,
    id: i16,
    scene_name: []const u8,
    x: i16,
    y: i16,
    bmp_path: []const u8,
    count: i16,
    width: i16,
    height: i16,
    small_path: []const u8,
    small_count: i16,
    small_width: i16,
    small_height: i16,
    timer_id: i16,
    timer_period: i16,
    visible: i16,
    unk10: u16,
    init_vbases: bool,
) Error!void {
    begin(g, obj, .portable, init_vbases, true);
    try oi.moveableCtorStripsNoHitbox(g, obj, x, y, 0, &.{}, &.{}, &.{}, &.{}, timer_id, timer_period, 0, 10, visible, unk10, false);
    const big = try dib_mod.loadDib(g.gpa, g.plat, g.fixes, &g.dibPathBuf, &g.driveCD, bmp_path);
    if (big == null) {
        ini.messageBoxPrintf(g.plat, &g.messageBuf, "Erro Fatal!!", "N\xe3o foi poss\xedvel abrir o arquivo: %s", bmp_path);
    }
    const small = try dib_mod.loadDib(g.gpa, g.plat, g.fixes, &g.dibPathBuf, &g.driveCD, small_path);
    if (small == null) {
        ini.messageBoxPrintf(g.plat, &g.messageBuf, "Erro Fatal!!", "N\xe3o foi poss\xedvel abrir o arquivo: %s", small_path);
    }
    const strips = g.gpa.alloc(Frame, 2) catch return error.LimitExceeded;
    strips[0] = frames.frameCtor();
    strips[1] = frames.frameCtor();
    obj.frames = strips;
    frames.frameInit(&obj.frames[0], big, count, width, height, 0, 0, 0, 0);
    frames.frameInit(&obj.frames[1], small, small_count, small_width, small_height, 0, 0, 0, 0);
    portableTail(g, obj, id, scene_name, x, y);
}

test "every constructor compiles" {
    std.testing.refAllDecls(@This());
}
