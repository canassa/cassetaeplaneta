//! Port unit `object_create` (module) of JARDIM.EXE. constructors and destructors of the objects (SceneObject, WallStrip, Portable, Exit, Player, ControlPanel and their bases), object_list_delete_all, frames.
//!
//! Each constructor chain is flattened onto one `Object` as in TIRO's unit:
//! the most-derived constructor of a complete object (`init_vbases`) resets
//! it to the field defaults (the original's uninitialised heap bytes) with
//! the `kind` set, then `scene_object_ctor_default` takes the SceneObject's
//! serial number; the base-part constructors run with `init_vbases = false`.
//! Parameters follow DESIGN.md: `(g, obj, <source order>, init_vbases)`, the
//! Ghidra list reversed. Unlike TIRO's, JARDIM's `scene_object_init_strips`
//! and `scene_object_init_state` each take a serial number too (so a strip
//! constructor consumes three), and the Animation takes `play_once_rewinds`
//! (+0x10). Everything the original `new`s lives in the task's local heap
//! (`g.local()`); the destructors free no strips.

const std = @import("std");
const Game = @import("core/game.zig").Game;
const object = @import("core/object.zig");
const Object = object.Object;
const ObjectList = object.ObjectList;
const Frame = object.Frame;
const FrameCell = object.FrameCell;
const Dib = object.Dib;
const dib_mod = @import("dib.zig");
const lists = @import("lists.zig");
const position = @import("behaviour/position.zig");

pub const Error = error{ OutOfMemory, LimitExceeded };

const open_failed = "N\xe3o foi poss\xedvel abrir o arquivo: %s";

/// What a constructor with `init_vbases` starts with: a fresh object of the
/// kind and the SceneObject's base constructor.
fn begin(g: *Game, obj: *Object, init_vbases: bool) void {
    if (!init_vbases) return;
    obj.* = .{ .kind = obj.kind };
    sceneObjectCtorDefault(g, obj);
}

/// The virtual bases of a class with an Object3D: SceneObject, then Object3D.
fn begin3d(g: *Game, obj: *Object, init_vbases: bool) void {
    begin(g, obj, init_vbases);
    if (init_vbases) object3dCtorDefault(g, obj, false);
}

/// The 3D size and support the Moveable / Animated3D strip constructors clear.
fn clearObject3d(obj: *Object) void {
    obj.o3d.sizeW = 0;
    obj.o3d.sizeH = 0;
    obj.o3d.sizeD = 0;
    obj.o3d.support = null;
}

/// `operator_new(n * 8)` + `crt_array_construct(frame_cell_ctor, n, 8)`; a
/// failed allocation gives no cells (the original stores NULL).
fn newCells(g: *Game, n: i16) []FrameCell {
    const cells = g.local().alloc(FrameCell, @as(u16, @bitCast(n))) catch return &.{};
    for (cells) |*c| c.* = frameCellCtor();
    return cells;
}

/// `operator_new(count * 0x1a + 2)` + `crt_array_construct(frame_ctor)`.
fn newFrames(g: *Game, obj: *Object, count: i16) Error!void {
    const frames = g.local().alloc(Frame, @as(u16, @bitCast(count))) catch return error.OutOfMemory;
    for (frames) |*f| f.* = frameCtor();
    obj.frames = frames;
}

/// `_fstrncpy(dst, src, 0x13)` then `dst[0x13] = 0`.
fn copyName19(dst: []u8, src: []const u8) void {
    var i: usize = 0;
    const n = std.mem.indexOfScalar(u8, src, 0) orelse src.len;
    while (i < 0x13) : (i += 1) dst[i] = if (i < n) src[i] else 0;
    dst[0x13] = 0;
}

fn missingFile(g: *Game, path: []const u8) void {
    position.messageBoxPrintf(g, "Erro Fatal!!", open_failed, path);
}

// @orig 10c0:183e frame_get_cell
/// FrameVtbl slot 00 getCell: `cells + index * 8`. The original does not
/// check the index; one outside the array has no cell to name.
pub fn getCell(frame: *Frame, index: i16) ?*FrameCell {
    const i: usize = @as(u16, @bitCast(index));
    if (i >= frame.cells.len) return null;
    return &frame.cells[i];
}

// @orig 10c0:5994 frame_cell_ctor
/// Four words zeroed.
pub fn frameCellCtor() FrameCell {
    return .{ .raw = @splat(0) };
}

// @orig 10c0:5860 frame_ctor
/// vtbl = FrameVtbl, count = 0, dib = NULL (the rest is uninitialised in the
/// original; the port zeroes it).
pub fn frameCtor() Frame {
    return .{};
}

// @orig 10c0:58a0 frame_init
/// Fills a strip record (a zero hit width/height defaults to the frame's) and
/// allocates `count` cells.
pub fn frameInit(
    g: *Game,
    f: *Frame,
    dib: ?*Dib,
    count: i16,
    width: i16,
    height: i16,
    hit_x: i16,
    hit_y: i16,
    hit_w: i16,
    hit_h: i16,
) void {
    f.dib = dib;
    f.count = count;
    f.width = width;
    f.height = height;
    f.hitX = hit_x;
    f.hitY = hit_y;
    f.hitW = if (hit_w == 0) width else hit_w;
    f.hitH = if (hit_h == 0) height else hit_h;
    f.cells = newCells(g, f.count);
}

// @orig 10c0:4c70 scene_object_ctor_default
/// SceneObject base: name "", `id = g_nextId++`, slot00 flag and RLE off.
pub fn sceneObjectCtorDefault(g: *Game, obj: *Object) void {
    obj.sceneName[0] = 0;
    obj.id = position.nextObjectId(g);
    obj.slot00Flag = 0;
    obj.rleFlag = 0;
}

// @orig 10c0:305c scene_object_dtor
/// With RLE on, the original unlocks and frees the global block of the strip
/// bitmap (`rleBits`' segment); the port's `rleBits` only aliases the DIB
/// bits, so it is dropped.
pub fn sceneObjectDtor(g: *Game, obj: *Object) void {
    if (position.isRle(g, obj)) obj.rleBits = null;
}

// @orig 10c0:2ddc scene_object_scalar_dtor
/// Scalar deleting destructor: the destructor, then `operator delete` of the
/// object when bit 0 of `flags` is set (the object must come from
/// `g.local()`). Returns `obj`.
pub fn sceneObjectScalarDtor(g: *Game, obj: *Object, flags: u16) *Object {
    sceneObjectDtor(g, obj);
    if (flags & 1 != 0) g.local().destroy(obj);
    return obj;
}

// @orig 10c0:2f1c object3d_dtor
/// Empty.
pub fn object3dDtor(obj: *Object) void {
    _ = obj;
}

// @orig 10c0:337e animation_dtor
/// Empty.
pub fn animationDtor(obj: *Object) void {
    _ = obj;
}

// @orig 10c0:335c animated3d_dtor
/// Nothing of its own: chains to `animation_dtor`.
pub fn animated3dDtor(obj: *Object) void {
    animationDtor(obj);
}

// @orig 10c0:2efa control_panel_dtor
/// Nothing of its own: chains to `animated3d_dtor`.
pub fn controlPanelDtor(obj: *Object) void {
    animated3dDtor(obj);
}

// @orig 10c0:2e96 control_panel_vbase_dtor
/// Complete-object destructor: the class, then the Object3D and SceneObject
/// virtual bases.
pub fn controlPanelVbaseDtor(g: *Game, obj: *Object) void {
    controlPanelDtor(obj);
    object3dDtor(obj);
    sceneObjectDtor(g, obj);
}

// @orig 10c0:2e1a control_panel_scalar_dtor
pub fn controlPanelScalarDtor(g: *Game, obj: *Object, flags: u16) *Object {
    controlPanelVbaseDtor(g, obj);
    if (flags & 1 != 0) g.local().destroy(obj);
    return obj;
}

// @orig 10c0:2ed8 status_bar_dtor
/// The StatusBar is never built in JARDIM; chains to `scene_object_dtor`.
pub fn statusBarDtor(g: *Game, obj: *Object) void {
    sceneObjectDtor(g, obj);
}

// @orig 10c0:2e58 status_bar_scalar_dtor
pub fn statusBarScalarDtor(g: *Game, obj: *Object, flags: u16) *Object {
    statusBarDtor(g, obj);
    if (flags & 1 != 0) g.local().destroy(obj);
    return obj;
}

// @orig 1038:2a48 object_list_delete_all
/// Deletes every object of the list (`scene_object_scalar_dtor(obj, 1)`, the
/// base destructor whatever the kind) when it is not empty and zeroes the
/// count; the next link is read one object ahead.
pub fn objectListDeleteAll(g: *Game, list: *ObjectList) void {
    if (lists.isEmpty(list)) return;
    var next = list.head.?.next;
    while (list.head) |cur| {
        _ = sceneObjectScalarDtor(g, cur, 1);
        list.head = next;
        if (next) |n| next = n.next;
    }
    list.count = 0;
}

// @orig 10c0:4cde object3d_ctor_default
/// With `init_vbases` the SceneObject base; otherwise only vtables.
pub fn object3dCtorDefault(g: *Game, obj: *Object, init_vbases: bool) void {
    if (init_vbases) sceneObjectCtorDefault(g, obj);
}

// @orig 10c0:7ae8 animation_ctor_default
pub fn animationCtorDefault(g: *Game, obj: *Object, init_vbases: bool) void {
    if (init_vbases) sceneObjectCtorDefault(g, obj);
}

// @orig 10c0:77d0 animated3d_ctor_default
pub fn animated3dCtorDefault(g: *Game, obj: *Object, init_vbases: bool) void {
    begin3d(g, obj, init_vbases);
    animationCtorDefault(g, obj, false);
}

// @orig 10c0:57c2 scene_object_init_state
/// Name "", a serial number (another one), position (also the world
/// position), unk10, visibility; not attached, strip 0, frame 0.
pub fn sceneObjectInitState(g: *Game, obj: *Object, x: i16, y: i16, visible: i16, unk10: u16) void {
    obj.sceneName[0] = 0;
    obj.id = position.nextObjectId(g);
    obj.slot00Flag = 0;
    obj.rleFlag = 0;
    obj.x = x;
    obj.worldX = x;
    obj.y = y;
    obj.worldY = y;
    obj.isEnemy = 0;
    obj.unk10 = unk10;
    obj.visible = visible;
    obj.attached = 0;
    obj.curStrip = 0;
    obj.curFrame = 0;
}

// @orig 10c0:55de scene_object_init_strips
/// Name "", a serial number, then `count` Frames and per strip
/// `load_dib(paths[i])` (no message for a missing file) and `frame_init`.
pub fn sceneObjectInitStrips(
    g: *Game,
    obj: *Object,
    count: i16,
    paths: []const []const u8,
    counts: []const i16,
    widths: []const i16,
    heights: []const i16,
    hit_x: i16,
    hit_y: i16,
    hit_w: i16,
    hit_h: i16,
) Error!void {
    obj.sceneName[0] = 0;
    obj.id = position.nextObjectId(g);
    obj.slot00Flag = 0;
    obj.rleFlag = 0;
    try newFrames(g, obj, count);
    const n = obj.frames.len;
    if (paths.len < n or counts.len < n or widths.len < n or heights.len < n) return error.LimitExceeded;
    for (obj.frames, 0..) |*f, i| {
        const d = dib_mod.loadDib(g.local(), g.plat, g.fixes, paths[i]);
        frameInit(g, f, d, counts[i], widths[i], heights[i], hit_x, hit_y, hit_w, hit_h);
    }
}

/// Body of `scene_object_ctor` for any kind (`wall_strip_ctor` builds a
/// WallStrip through it).
fn sceneObjectCtorAs(
    g: *Game,
    obj: *Object,
    kind: object.Kind,
    x: i16,
    y: i16,
    bmp_path: []const u8,
    frame_count: i16,
    frame_w: i16,
    frame_h: i16,
    visible: i16,
    unk10: u16,
) Error!void {
    obj.kind = kind;
    begin(g, obj, true);
    obj.x = x;
    obj.worldX = x;
    obj.y = y;
    obj.worldY = y;
    obj.isEnemy = 0;
    obj.unk10 = unk10;
    obj.visible = visible;
    obj.attached = 0;
    obj.curStrip = 0;
    obj.curFrame = 0;
    try newFrames(g, obj, 1);
    const d = dib_mod.loadDib(g.local(), g.plat, g.fixes, bmp_path);
    if (d == null) missingFile(g, bmp_path);
    frameInit(g, &obj.frames[0], d, frame_count, frame_w, frame_h, 0, 0, 0, 0);
}

// @orig 10c0:856c scene_object_ctor
/// A plain SceneObject (kind `scene_object`) with one strip: the default
/// constructor and the state inlined (one serial number), one Frame, a
/// zero hit box; a missing file shows "Erro Fatal!!" and carries on.
pub fn sceneObjectCtor(
    g: *Game,
    obj: *Object,
    x: i16,
    y: i16,
    bmp_path: []const u8,
    frame_count: i16,
    frame_w: i16,
    frame_h: i16,
    visible: i16,
    unk10: u16,
) Error!void {
    try sceneObjectCtorAs(g, obj, .scene_object, x, y, bmp_path, frame_count, frame_w, frame_h, visible, unk10);
}

// @orig 10c0:86bc scene_object_ctor_strips
/// A plain SceneObject (kind `scene_object`) with `count` strips (the
/// hands), a zero hit box; a missing file shows "Erro Fatal!!".
pub fn sceneObjectCtorStrips(
    g: *Game,
    obj: *Object,
    x: i16,
    y: i16,
    count: i16,
    paths: []const []const u8,
    counts: []const i16,
    widths: []const i16,
    heights: []const i16,
    visible: i16,
    unk10: u16,
) Error!void {
    obj.kind = .scene_object;
    begin(g, obj, true);
    obj.x = x;
    obj.worldX = x;
    obj.y = y;
    obj.worldY = y;
    obj.isEnemy = 0;
    obj.unk10 = unk10;
    obj.visible = visible;
    obj.attached = 0;
    obj.curStrip = 0;
    obj.curFrame = 0;
    try newFrames(g, obj, count);
    const n = obj.frames.len;
    if (paths.len < n or counts.len < n or widths.len < n or heights.len < n) return error.LimitExceeded;
    for (obj.frames, 0..) |*f, i| {
        const d = dib_mod.loadDib(g.local(), g.plat, g.fixes, paths[i]);
        if (d == null) missingFile(g, paths[i]);
        frameInit(g, f, d, counts[i], widths[i], heights[i], 0, 0, 0, 0);
    }
}

// @orig 10c0:8a76 wall_strip_ctor
/// WallStrip (kind `wall_strip`): the one-strip SceneObject (hidden, at 0,0),
/// then the texture count (+0x49e).
pub fn wallStripCtor(
    g: *Game,
    obj: *Object,
    bmp_path: []const u8,
    bmp_w: i16,
    bmp_h: i16,
    texture_count: i16,
) Error!void {
    try sceneObjectCtorAs(g, obj, .wall_strip, 0, 0, bmp_path, 1, bmp_w, bmp_h, 0, 0);
    obj.textureCount = texture_count;
}

/// The Animation fields every strip constructor ends with.
fn animationTail(obj: *Object, play_once_rewinds: i16) void {
    obj.anim.running = 0;
    obj.anim.playOnce = 0;
    obj.anim.framesLeft = 0;
    obj.anim.rewinds = play_once_rewinds;
}

// @orig 10c0:76a4 animation_ctor_strips_no_hitbox
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
    begin(g, obj, init_vbases);
    obj.anim.timerId = timer_id;
    obj.anim.timerPeriod = timer_period;
    try sceneObjectInitStrips(g, obj, count, paths, counts, widths, heights, 0, 0, 0, 0);
    sceneObjectInitState(g, obj, x, y, visible, unk10);
    animationTail(obj, play_once_rewinds);
}

// @orig 10c0:8d24 animation_ctor_strips
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
    begin(g, obj, init_vbases);
    obj.anim.timerId = timer_id;
    obj.anim.timerPeriod = timer_period;
    try sceneObjectInitStrips(g, obj, count, paths, counts, widths, heights, hit_x, hit_y, hit_w, hit_h);
    sceneObjectInitState(g, obj, x, y, visible, unk10);
    animationTail(obj, play_once_rewinds);
}

// @orig 10c0:7166 animated3d_ctor_strips_no_hitbox
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
    begin3d(g, obj, init_vbases);
    try animationCtorStripsNoHitbox(g, obj, x, y, count, paths, counts, widths, heights, timer_id, timer_period, play_once_rewinds, visible, unk10, false);
    clearObject3d(obj);
}

// @orig 10c0:8b4c animated3d_ctor_strips
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
    begin3d(g, obj, init_vbases);
    try animationCtorStrips(g, obj, x, y, count, paths, counts, widths, heights, hit_x, hit_y, hit_w, hit_h, timer_id, timer_period, play_once_rewinds, visible, unk10, false);
    clearObject3d(obj);
}

// @orig 10c0:6e2e control_panel_ctor
/// ControlPanel (kind `control_panel`): one strip (the scalar arguments as
/// one-element tables), closed.
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
    obj.kind = .control_panel;
    begin3d(g, obj, init_vbases);
    try animated3dCtorStripsNoHitbox(g, obj, x, y, 1, &.{bmp_path}, &.{count}, &.{width}, &.{height}, timer_id, timer_period, play_once_rewinds, visible, unk10, false);
    obj.panel.slideStepsLeft = 0;
    obj.panel.isOpen = 0;
}

/// The Mover fields every strip constructor ends with (no `allowOffscreen`).
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
}

// @orig 10c0:51ce mover_ctor_strips
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
    begin(g, obj, init_vbases);
    try sceneObjectInitStrips(g, obj, count, paths, counts, widths, heights, hit_x, hit_y, hit_w, hit_h);
    sceneObjectInitState(g, obj, x, y, visible, unk10);
    moverTail(obj, timer_id, timer_period, step_x, step_y);
}

// @orig 10c0:5336 mover_ctor_strips_no_hitbox
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
    begin(g, obj, init_vbases);
    try sceneObjectInitStrips(g, obj, count, paths, counts, widths, heights, 0, 0, 0, 0);
    sceneObjectInitState(g, obj, x, y, visible, unk10);
    moverTail(obj, timer_id, timer_period, step_x, step_y);
}

// @orig 10c0:78a8 moveable_ctor_strips
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
    begin3d(g, obj, init_vbases);
    try moverCtorStrips(g, obj, x, y, count, paths, counts, widths, heights, hit_x, hit_y, hit_w, hit_h, timer_id, timer_period, step_x, step_y, visible, unk10, false);
    clearObject3d(obj);
}

// @orig 10c0:4eee moveable_ctor_strips_no_hitbox
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
    begin3d(g, obj, init_vbases);
    try moverCtorStripsNoHitbox(g, obj, x, y, count, paths, counts, widths, heights, timer_id, timer_period, step_x, step_y, visible, unk10, false);
    clearObject3d(obj);
}

// @orig 10c0:72be actor_ctor_strips
/// Moveable part, default Animated3D part, an empty inventory (capacity 8),
/// then the animation's and the mover's timers (the arguments) and
/// `play_once_rewinds` (Animation+0x10).
pub fn actorCtorStrips(
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
    play_once_rewinds: i16,
    visible: i16,
    unk10: u16,
    init_vbases: bool,
) Error!void {
    begin3d(g, obj, init_vbases);
    try moveableCtorStrips(g, obj, x, y, count, paths, counts, widths, heights, hit_x, hit_y, hit_w, hit_h, timer_id, timer_period, step_x, step_y, visible, unk10, false);
    animated3dCtorDefault(g, obj, false);
    _ = lists.ctor(&obj.actor.inventory, 8);
    obj.anim.timerId = timer_id;
    obj.mover.timerId = timer_id;
    obj.anim.timerPeriod = timer_period;
    obj.mover.timerPeriod = timer_period;
    obj.anim.rewinds = play_once_rewinds;
}

// @orig 10c0:6cdc player_ctor
/// Player (kind `player`, createPlayer's hidden dummy): an Actor with one
/// strip (one-element tables) and `play_once_rewinds = 1`. Sets no lives or
/// score.
pub fn playerCtor(
    g: *Game,
    obj: *Object,
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
    obj.kind = .player;
    begin3d(g, obj, init_vbases);
    try actorCtorStrips(g, obj, x, y, 1, &.{bmp_path}, &.{count}, &.{width}, &.{height}, hit_x, hit_y, hit_w, hit_h, timer_id, timer_period, step_x, step_y, 1, visible, unk10, false);
}

// @orig 10c0:8892 exit_ctor
/// Exit (kind `exit`; phases 1-2's portainv.bmp): one strip with a hit box,
/// then the defaults: no scene (player at 200,100), the always-true
/// condition, exit index -1, no key, no alternative (also -1, 200,100), all
/// scene flags set.
pub fn exitCtor(
    g: *Game,
    obj: *Object,
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
    obj.kind = .exit;
    begin3d(g, obj, init_vbases);
    try animated3dCtorStrips(g, obj, x, y, 1, &.{bmp_path}, &.{count}, &.{width}, &.{height}, hit_x, hit_y, hit_w, hit_h, timer_id, timer_period, play_once_rewinds, visible, unk10, false);
    obj.exit.condition = &g.conditionTrue;
    obj.exit.sceneName[0] = 0;
    obj.exit.playerX = 200;
    obj.exit.playerY = 100;
    obj.exit.exitIndex = -1;
    obj.exit.framesLeft = 0;
    obj.exit.playing = 0;
    obj.o3d.sizeD = 0;
    obj.o3d.sizeH = 0;
    obj.o3d.sizeW = 0;
    obj.exit.keyObject = 0;
    obj.exit.altExitIndex = -1;
    obj.exit.altSceneName[0] = 0;
    obj.exit.altPlayerX = 200;
    obj.exit.altPlayerY = 100;
    obj.exit.hasPlayer = 1;
    obj.exit.hasControlPanel = 1;
    obj.exit.hasStatusBar = 1;
    obj.exit.unk34 = .{ 0, 0 };
}

// @orig 1048:2cee portable_ctor_zoom
/// Portable (kind `portable`: every pickup and enemy of the phases): a
/// one-strip Moveable without hit box (a missing file shows no box), the
/// scene name (19 chars), no elevation, added to the game's global list, and
/// the icon = the current strip's DIB.
pub fn portableCtorZoom(
    g: *Game,
    obj: *Object,
    scene_name: []const u8,
    x: i16,
    y: i16,
    bmp_path: []const u8,
    count: i16,
    width: i16,
    height: i16,
    timer_id: i16,
    timer_period: i16,
    step_x: i16,
    step_y: i16,
    visible: i16,
    unk10: u16,
    init_vbases: bool,
) Error!void {
    obj.kind = .portable;
    begin3d(g, obj, init_vbases);
    try moveableCtorStripsNoHitbox(g, obj, x, y, 1, &.{bmp_path}, &.{count}, &.{width}, &.{height}, timer_id, timer_period, step_x, step_y, visible, unk10, false);
    obj.portable.unk38 = 0;
    obj.mover.unk36 = 0;
    copyName19(&obj.sceneName, scene_name);
    obj.o3d.worldElev = 0;
    _ = lists.add(&g.globalObjects, obj);
    obj.portable.icon = position.dib(obj);
}

const testing = std.testing;
const TestGame = @import("core/game.zig").TestGame;

// @orig 10c0:58a0 frame_init oracle=documented
test "frame init defaults the hit box and sizes the cells by count" {
    var tg = try TestGame.init(testing.allocator);
    defer tg.deinit();
    const g = tg.game;
    var f = frameCtor();
    frameInit(g, &f, null, 4, 100, 50, 1, 2, 0, 0);
    try testing.expectEqual(@as(i16, 100), f.hitW);
    try testing.expectEqual(@as(i16, 50), f.hitH);
    try testing.expectEqual(@as(usize, 4), f.cells.len);
    try testing.expect(getCell(&f, 3) != null);
    try testing.expect(getCell(&f, 4) == null);
}

// @orig 10c0:8a76 wall_strip_ctor oracle=documented
test "wall strip ctor: one id, hidden, texture count" {
    var tg = try TestGame.init(testing.allocator);
    defer tg.deinit();
    const g = tg.game;
    const o = try g.local().create(Object);
    try wallStripCtor(g, o, "none.bmp", 32, 300, 6);
    try testing.expectEqual(object.Kind.wall_strip, o.kind);
    try testing.expectEqual(@as(i16, 6), o.textureCount);
    try testing.expectEqual(@as(i16, 1), g.nextId);
    try testing.expectEqual(@as(i16, 0), o.visible);
    try testing.expectEqual(@as(usize, 1), o.frames.len);
}

// @orig 10c0:8892 exit_ctor oracle=documented
test "exit ctor takes three serial numbers and sets the defaults" {
    var tg = try TestGame.init(testing.allocator);
    defer tg.deinit();
    const g = tg.game;
    const o = try g.local().create(Object);
    try exitCtor(g, o, 10, 20, "none.bmp", 1, 30, 40, 0, 0, 0, 0, 1, 100, 0, 1, 0, true);
    try testing.expectEqual(@as(i16, 3), g.nextId);
    try testing.expectEqual(@as(i16, 2), o.id);
    try testing.expectEqual(@as(i16, -1), o.exit.exitIndex);
    try testing.expectEqual(@as(i16, 40), o.frames[0].hitH);
    try testing.expectEqual(@as(i16, 10), o.worldX);
}

// @orig 1048:2cee portable_ctor_zoom oracle=documented
test "portable ctor joins the global list with its scene name" {
    var tg = try TestGame.init(testing.allocator);
    defer tg.deinit();
    const g = tg.game;
    g.globalObjects.capacity = 8;
    const o = try g.local().create(Object);
    try portableCtorZoom(g, o, "a-very-long-scene-name-here", 5, 6, "none.bmp", 4, 10, 12, 1, 50, 0, 10, 1, 0, true);
    try testing.expectEqual(@as(i16, 1), g.globalObjects.count);
    try testing.expectEqualStrings("a-very-long-scene", std.mem.sliceTo(&o.sceneName, 0)[0..17]);
    try testing.expectEqual(@as(usize, 0x13 - 0), std.mem.sliceTo(&o.sceneName, 0).len);
    try testing.expectEqual(@as(i16, 10), o.mover.stepY);
}

// @orig 1038:2a48 object_list_delete_all oracle=documented
test "delete all empties the list" {
    var tg = try TestGame.init(testing.allocator);
    defer tg.deinit();
    const g = tg.game;
    var l = ObjectList{ .capacity = 4 };
    const a = try g.local().create(Object);
    const b = try g.local().create(Object);
    a.* = .{ .kind = .scene_object };
    b.* = .{ .kind = .scene_object };
    _ = lists.add(&l, a);
    _ = lists.add(&l, b);
    objectListDeleteAll(g, &l);
    try testing.expectEqual(@as(i16, 0), l.count);
}
