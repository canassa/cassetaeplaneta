//! Port unit `object_init` (module). base-part constructors (SceneObject, Animation, Mover, Object3D, Animated3D, Moveable, Actor, Player) and all destructors.
//!
//! The original's constructors build one class part each and chain to their
//! bases; the most-derived constructor (unit `object_create`) calls them with
//! `init_vbases = true`, the middle ones with `false` (so the virtual bases —
//! SceneObject, Object3D — are built once). The port keeps that shape: every
//! part constructor takes the whole flat `Object` and `init_vbases`, and only
//! writes the fields its class owns. Vtable, vbtable and vtordisp stores have
//! no counterpart (`Object.kind` is set by the creator).
//!
//! Parameters follow DESIGN.md: `(g, obj, <source order>)`, i.e. the Ghidra
//! list reversed, with the hidden `init_vbases` last. Strip arrays are slices
//! (`count` entries each). Bytes the original leaves uninitialised (heap
//! garbage) are the `Object` field defaults.
//!
//! Destructors: the `…Dtor` functions release what the original releases
//! (strips, RLE block); the `…ScalarDtor` ones also free the object when bit 0
//! of `flags` is set (`g.gpa.destroy`, the object having been `create`d there).

const std = @import("std");
const Game = @import("core/game.zig").Game;
const object = @import("core/object.zig");
const Object = object.Object;
const Frame = object.Frame;
const ObjectList = object.ObjectList;
const errors = @import("core/errors.zig");
const dib_mod = @import("dib.zig");
const frames = @import("frames.zig");
const ini = @import("ini.zig");
const object_list = @import("object_list.zig");
const misc = @import("behaviour/misc.zig");

const Error = errors.Error;

// ---- SceneObject ----

// @orig 1010:1886 scene_object_ctor_default
/// Base constructor: a serial number, no strips, RLE off.
pub fn sceneObjectCtorDefault(g: *Game, obj: *Object) void {
    obj.sceneName[0] = 0;
    obj.id = frames.nextObjectId(g);
    obj.unk492 = 0;
    obj.rleMode = 0;
}

// @orig 1010:18cc scene_object_ctor
/// Base constructor with one strip loaded from the bitmap `path` (count
/// frames of `frame_w` x `frame_h`, no hit box). A missing file shows the
/// "Erro Fatal!!" box and leaves the strip's `dib` null. (Unlike
/// `frames.initStrip` it takes only one serial number.)
pub fn sceneObjectCtor(
    g: *Game,
    obj: *Object,
    x: i16,
    y: i16,
    path: []const u8,
    frame_count: i16,
    frame_w: i16,
    frame_h: i16,
    visible: i16,
    unk10: u16,
) Error!void {
    sceneObjectCtorDefault(g, obj);
    obj.x = x;
    obj.y = y;
    obj.unk10 = unk10;
    obj.visible = visible;
    obj.attached = 0;
    obj.curStrip = 0;
    obj.curFrame = 0;
    const strips = g.gpa.alloc(Frame, 1) catch return error.LimitExceeded;
    strips[0] = frames.frameCtor();
    obj.frames = strips;
    const d = try dib_mod.loadDib(g.gpa, g.plat, g.fixes, &g.dibPathBuf, &g.driveCD, path);
    if (d == null) {
        ini.messageBoxPrintf(g.plat, &g.messageBuf, "Erro Fatal!!", "N\xe3o foi poss\xedvel abrir o arquivo: %s", path);
    }
    frames.frameInit(&obj.frames[0], d, frame_count, frame_w, frame_h, 0, 0, 0, 0);
}

// @orig 1010:b002 scene_object_dtor
/// Frees the strips (and their bitmaps). With RLE on, the original then
/// frees `rleBits`' global block — the very block of the strip's DIB that
/// the strip destructor just freed (a double free there). The port's
/// `rleBits` only aliases the DIB bits, so it is just dropped.
pub fn sceneObjectDtor(g: *Game, obj: *Object) void {
    if (obj.frames.len != 0) frames.frameVectorDtor(g, obj);
    if (misc.isRle(g, obj)) obj.rleBits = null;
}

// @orig 1010:d762 scene_object_scalar_dtor
/// Scalar deleting destructor of the base class.
pub fn sceneObjectScalarDtor(g: *Game, obj: *Object, flags: u16) void {
    sceneObjectDtor(g, obj);
    if (flags & 1 != 0) g.gpa.destroy(obj);
}

// @orig 1010:d474 object_list_delete_all
/// Deletes every object of the list with the *base* scalar destructor
/// (whatever its kind) and empties the list; the next link is read before
/// each deletion.
pub fn objectListDeleteAll(g: *Game, list: *ObjectList) void {
    if (object_list.isEmpty(list)) return;
    var next = list.head.?.next;
    if (list.head != null) {
        while (true) {
            if (list.head) |h| sceneObjectScalarDtor(g, h, 1);
            list.head = next;
            if (next) |n| next = n.next;
            if (list.head == null) break;
        }
    }
    list.count = 0;
}

// ---- Object3D ----

// @orig 1010:321a object3d_ctor_default
/// Builds the SceneObject base when `init_vbases`; leaves the 3D fields alone.
pub fn object3dCtorDefault(g: *Game, obj: *Object, init_vbases: bool) void {
    if (init_vbases) sceneObjectCtorDefault(g, obj);
}

// @orig 1018:1a58 object3d_dtor
/// Empty (compiler-generated copy for the virtual base).
pub fn object3dDtor(g: *Game, obj: *Object) void {
    _ = g;
    _ = obj;
}

/// The 3D size and support the Animated3D/Moveable strip constructors clear.
fn clearObject3d(obj: *Object) void {
    obj.o3d.sizeW = 0;
    obj.o3d.sizeH = 0;
    obj.o3d.sizeD = 0;
    obj.o3d.support = null;
}

// ---- Animation ----

// @orig 1010:2114 animation_ctor_default
pub fn animationCtorDefault(g: *Game, obj: *Object, init_vbases: bool) void {
    if (init_vbases) sceneObjectCtorDefault(g, obj);
    obj.anim.isAvi = 0;
}

/// The fields every Animation strip constructor ends with.
fn animationTail(obj: *Object, play_once_rewinds: i16) void {
    obj.anim.playOnce = 0;
    obj.anim.running = 0;
    obj.framesLeft = 0;
    obj.anim.isAvi = 0;
    obj.playOnceRewinds = @bitCast(play_once_rewinds);
}

// @orig 1010:217e animation_ctor_strips
pub fn animationCtorStrips(
    g: *Game,
    obj: *Object,
    x: i16,
    y: i16,
    count: i16,
    paths: []const []const u8,
    counts: []const i16,
    widths: []const i16,
    heights: []const i16,
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
    if (init_vbases) sceneObjectCtorDefault(g, obj);
    obj.anim.timerId = timer_id;
    obj.anim.timerPeriod = timer_period;
    try frames.initStrips(g, obj, count, paths, counts, widths, heights, hit_x, hit_y, hit_w, hit_h);
    frames.initState(g, obj, x, y, visible, unk10);
    animationTail(obj, play_once_rewinds);
}

// @orig 1010:2260 animation_ctor
/// One strip from a bitmap (an unreadable file shows the "Erro Fatal!!" box).
pub fn animationCtor(
    g: *Game,
    obj: *Object,
    x: i16,
    y: i16,
    path: []const u8,
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
    if (init_vbases) sceneObjectCtorDefault(g, obj);
    obj.anim.timerId = timer_id;
    obj.anim.timerPeriod = timer_period;
    try frames.initStrip(g, obj, path, count, width, height, hit_x, hit_y, hit_w, hit_h);
    frames.initState(g, obj, x, y, visible, unk10);
    animationTail(obj, play_once_rewinds);
}

// @orig 1010:233a animation_ctor_strips_no_hitbox
pub fn animationCtorStripsNoHitbox(
    g: *Game,
    obj: *Object,
    x: i16,
    y: i16,
    count: i16,
    paths: []const []const u8,
    counts: []const i16,
    widths: []const i16,
    heights: []const i16,
    timer_id: i16,
    timer_period: i16,
    play_once_rewinds: i16,
    visible: i16,
    unk10: u16,
    init_vbases: bool,
) Error!void {
    if (init_vbases) sceneObjectCtorDefault(g, obj);
    obj.anim.timerId = timer_id;
    obj.anim.timerPeriod = timer_period;
    try frames.initStrips(g, obj, count, paths, counts, widths, heights, 0, 0, 0, 0);
    frames.initState(g, obj, x, y, visible, unk10);
    animationTail(obj, play_once_rewinds);
}

// @orig 1010:77ac animation_dtor
/// Empty.
pub fn animationDtor(g: *Game, obj: *Object) void {
    _ = g;
    _ = obj;
}

// ---- Animated3D ----

// @orig 1010:327c animated3d_ctor_default
pub fn animated3dCtorDefault(g: *Game, obj: *Object, init_vbases: bool) void {
    if (init_vbases) {
        sceneObjectCtorDefault(g, obj);
        object3dCtorDefault(g, obj, false);
    }
    animationCtorDefault(g, obj, false);
}

// @orig 1010:3336 animated3d_ctor_strips
pub fn animated3dCtorStrips(
    g: *Game,
    obj: *Object,
    x: i16,
    y: i16,
    count: i16,
    paths: []const []const u8,
    counts: []const i16,
    widths: []const i16,
    heights: []const i16,
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
    if (init_vbases) {
        sceneObjectCtorDefault(g, obj);
        object3dCtorDefault(g, obj, false);
    }
    try animationCtorStrips(g, obj, x, y, count, paths, counts, widths, heights, hit_x, hit_y, hit_w, hit_h, timer_id, timer_period, play_once_rewinds, visible, unk10, false);
    clearObject3d(obj);
}

// @orig 1010:3432 animated3d_ctor_strips_no_hitbox
pub fn animated3dCtorStripsNoHitbox(
    g: *Game,
    obj: *Object,
    x: i16,
    y: i16,
    count: i16,
    paths: []const []const u8,
    counts: []const i16,
    widths: []const i16,
    heights: []const i16,
    timer_id: i16,
    timer_period: i16,
    play_once_rewinds: i16,
    visible: i16,
    unk10: u16,
    init_vbases: bool,
) Error!void {
    if (init_vbases) {
        sceneObjectCtorDefault(g, obj);
        object3dCtorDefault(g, obj, false);
    }
    try animationCtorStripsNoHitbox(g, obj, x, y, count, paths, counts, widths, heights, timer_id, timer_period, play_once_rewinds, visible, unk10, false);
    clearObject3d(obj);
}

// @orig 1010:76f8 animated3d_dtor
/// Nothing of its own; chains to the Animation destructor.
pub fn animated3dDtor(g: *Game, obj: *Object) void {
    animationDtor(g, obj);
}

// ---- Mover ----

// @orig 1010:27ce mover_ctor_default
pub fn moverCtorDefault(g: *Game, obj: *Object, init_vbases: bool) void {
    if (init_vbases) sceneObjectCtorDefault(g, obj);
    obj.mover.allowOffscreen = 0;
}

/// The Mover fields every strip constructor ends with: previous and target
/// position = the position `initState` just set.
fn moverTail(obj: *Object, timer_id: i16, timer_period: i16, step_x: i16, step_y: i16) void {
    obj.mover.prevX = obj.x;
    obj.mover.targetX = obj.x;
    obj.mover.prevY = obj.y;
    obj.mover.targetY = obj.y;
    obj.mover.timerId = timer_id;
    obj.mover.timerPeriod = timer_period;
    obj.mover.stepX = step_x;
    obj.mover.stepY = step_y;
    obj.mover.moving = 0;
    obj.mover.allowOffscreen = 0;
}

// @orig 1010:2836 mover_ctor_strips
pub fn moverCtorStrips(
    g: *Game,
    obj: *Object,
    x: i16,
    y: i16,
    count: i16,
    paths: []const []const u8,
    counts: []const i16,
    widths: []const i16,
    heights: []const i16,
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
    if (init_vbases) sceneObjectCtorDefault(g, obj);
    try frames.initStrips(g, obj, count, paths, counts, widths, heights, hit_x, hit_y, hit_w, hit_h);
    frames.initState(g, obj, x, y, visible, unk10);
    moverTail(obj, timer_id, timer_period, step_x, step_y);
}

// @orig 1010:292c mover_ctor_strips_no_hitbox
pub fn moverCtorStripsNoHitbox(
    g: *Game,
    obj: *Object,
    x: i16,
    y: i16,
    count: i16,
    paths: []const []const u8,
    counts: []const i16,
    widths: []const i16,
    heights: []const i16,
    timer_id: i16,
    timer_period: i16,
    step_x: i16,
    step_y: i16,
    visible: i16,
    unk10: u16,
    init_vbases: bool,
) Error!void {
    if (init_vbases) sceneObjectCtorDefault(g, obj);
    try frames.initStrips(g, obj, count, paths, counts, widths, heights, 0, 0, 0, 0);
    frames.initState(g, obj, x, y, visible, unk10);
    moverTail(obj, timer_id, timer_period, step_x, step_y);
}

// @orig 1010:2a20 mover_ctor_alloc_strips
/// `count` empty strips (the caller fills them).
pub fn moverCtorAllocStrips(
    g: *Game,
    obj: *Object,
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
    if (init_vbases) sceneObjectCtorDefault(g, obj);
    try frames.allocStrips(g, obj, count);
    frames.initState(g, obj, x, y, visible, unk10);
    moverTail(obj, timer_id, timer_period, step_x, step_y);
}

// ---- Moveable ----

/// The virtual bases a Moveable builds first when it is the complete object.
fn moveableBases(g: *Game, obj: *Object, init_vbases: bool) void {
    if (init_vbases) {
        sceneObjectCtorDefault(g, obj);
        object3dCtorDefault(g, obj, false);
    }
}

// @orig 1010:3676 moveable_ctor_default
pub fn moveableCtorDefault(g: *Game, obj: *Object, init_vbases: bool) void {
    moveableBases(g, obj, init_vbases);
    moverCtorDefault(g, obj, false);
}

// @orig 1010:3742 moveable_ctor_strips
pub fn moveableCtorStrips(
    g: *Game,
    obj: *Object,
    x: i16,
    y: i16,
    count: i16,
    paths: []const []const u8,
    counts: []const i16,
    widths: []const i16,
    heights: []const i16,
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
    moveableBases(g, obj, init_vbases);
    try moverCtorStrips(g, obj, x, y, count, paths, counts, widths, heights, hit_x, hit_y, hit_w, hit_h, timer_id, timer_period, step_x, step_y, visible, unk10, false);
    clearObject3d(obj);
}

// @orig 1010:384a moveable_ctor_bitmap
/// One strip from a bitmap, through the strips constructor with
/// one-element arrays (so, like it, no message box for a missing file).
pub fn moveableCtorBitmap(
    g: *Game,
    obj: *Object,
    x: i16,
    y: i16,
    path: []const u8,
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
    moveableBases(g, obj, init_vbases);
    try moverCtorStrips(g, obj, x, y, 1, &.{path}, &.{count}, &.{width}, &.{height}, hit_x, hit_y, hit_w, hit_h, timer_id, timer_period, step_x, step_y, visible, unk10, false);
    clearObject3d(obj);
}

// @orig 1010:3954 moveable_ctor_strips_no_hitbox
pub fn moveableCtorStripsNoHitbox(
    g: *Game,
    obj: *Object,
    x: i16,
    y: i16,
    count: i16,
    paths: []const []const u8,
    counts: []const i16,
    widths: []const i16,
    heights: []const i16,
    timer_id: i16,
    timer_period: i16,
    step_x: i16,
    step_y: i16,
    visible: i16,
    unk10: u16,
    init_vbases: bool,
) Error!void {
    moveableBases(g, obj, init_vbases);
    try moverCtorStripsNoHitbox(g, obj, x, y, count, paths, counts, widths, heights, timer_id, timer_period, step_x, step_y, visible, unk10, false);
    clearObject3d(obj);
}

// @orig 1010:3a54 moveable_ctor_alloc_strips
pub fn moveableCtorAllocStrips(
    g: *Game,
    obj: *Object,
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
    moveableBases(g, obj, init_vbases);
    try moverCtorAllocStrips(g, obj, x, y, count, timer_id, timer_period, step_x, step_y, visible, unk10, false);
    clearObject3d(obj);
}

// ---- Actor and Player ----

// @orig 1010:3e50 actor_ctor_alloc_strips
/// A Moveable with `count` empty strips plus a default Animated3D and an
/// empty inventory (capacity 8); the animation shares the movement timer.
pub fn actorCtorAllocStrips(
    g: *Game,
    obj: *Object,
    x: i16,
    y: i16,
    count: i16,
    timer_id: i16,
    timer_period: i16,
    step_x: i16,
    step_y: i16,
    play_once_rewinds: i16,
    visible: i16,
    unk10: u16,
    init_vbases: bool,
) Error!void {
    if (init_vbases) {
        sceneObjectCtorDefault(g, obj);
        object3dCtorDefault(g, obj, false);
    }
    try moveableCtorAllocStrips(g, obj, x, y, count, timer_id, timer_period, step_x, step_y, visible, unk10, false);
    animated3dCtorDefault(g, obj, false);
    _ = object_list.ctor(&obj.actor.inventory, 8);
    obj.anim.timerId = timer_id;
    obj.mover.timerId = timer_id;
    obj.anim.timerPeriod = timer_period;
    obj.mover.timerPeriod = timer_period;
    obj.playOnceRewinds = @bitCast(play_once_rewinds);
}

// @orig 1010:e44e player_ctor
/// An Actor with `count` empty strips (play-once-rewinds 1), then the
/// object id set by the caller.
pub fn playerCtor(
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
    if (init_vbases) {
        sceneObjectCtorDefault(g, obj);
        object3dCtorDefault(g, obj, false);
    }
    try actorCtorAllocStrips(g, obj, x, y, count, timer_id, timer_period, step_x, step_y, 1, visible, unk10, false);
    obj.id = id;
}

// ---- ControlPanel and StatusBar ----

// @orig 1018:1a40 control_panel_dtor
/// Nothing of its own; chains to the Animated3D destructor.
pub fn controlPanelDtor(g: *Game, obj: *Object) void {
    animated3dDtor(g, obj);
}

// @orig 1018:19f0 control_panel_vbase_dtor
/// Complete-object destructor: the class, then the Object3D and SceneObject
/// virtual bases.
pub fn controlPanelVbaseDtor(g: *Game, obj: *Object) void {
    controlPanelDtor(g, obj);
    object3dDtor(g, obj);
    sceneObjectDtor(g, obj);
}

// @orig 1018:1988 control_panel_scalar_dtor
pub fn controlPanelScalarDtor(g: *Game, obj: *Object, flags: u16) void {
    controlPanelVbaseDtor(g, obj);
    if (flags & 1 != 0) g.gpa.destroy(obj);
}

// @orig 1018:1a28 status_bar_dtor
pub fn statusBarDtor(g: *Game, obj: *Object) void {
    sceneObjectDtor(g, obj);
}

// @orig 1018:19bc status_bar_scalar_dtor
pub fn statusBarScalarDtor(g: *Game, obj: *Object, flags: u16) void {
    statusBarDtor(g, obj);
    if (flags & 1 != 0) g.gpa.destroy(obj);
}
