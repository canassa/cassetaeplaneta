//! Port unit `object_create` (module) of SAUNA.EXE. constructors and destructors of the objects (Pacman, Ghost, Player2D/Actor2D/Mover/Animation, ControlPanel/Animated3D/Object3D, the SceneObject dots) and frames.
//!
//! Each constructor chain is flattened onto one `Object` as in TIRO: the
//! most-derived constructor of a complete object (`init_vbases`) resets it
//! to the field defaults (the original's uninitialised heap bytes) with the
//! `kind` set and takes the SceneObject's serial number (the original builds
//! the vbtables and vtables here); the base-part constructors then run with
//! `init_vbases = false`. Parameters follow TIRO's: `(g, obj, <source
//! order>, init_vbases)`, the Ghidra list reversed; SAUNA's (NOITE-shaped)
//! constructors take a `play_once_rewinds` word after `step_y` / `timer_period`
//! that lands in `anim.running`. Differences from TIRO's build: SAUNA's
//! `scene_object_init_strips` and `scene_object_init_state` each repeat the
//! SceneObject initialiser (name "", `id = g_nextId++`, wave NULL, and
//! `playOnceRewinds = 0` in the state), so a Ghost burns three serial numbers
//! and keeps the last. Everything the original `new`s lives in the task's
//! local heap (`g.local()`), and no destructor frees the strips.

const std = @import("std");
const Game = @import("core/game.zig").Game;
const object = @import("core/object.zig");
const Object = object.Object;
const Frame = object.Frame;
const FrameCell = object.FrameCell;
const Dib = object.Dib;
const dib_mod = @import("dib.zig");
const position = @import("behaviour/position.zig");
const render = @import("behaviour/render.zig");

pub const Error = error{ OutOfMemory, LimitExceeded };

/// What a constructor with `init_vbases` starts with: a fresh object of the
/// kind and the SceneObject's new serial number (`scene_object_ctor`).
fn begin(g: *Game, obj: *Object, init_vbases: bool) void {
    if (!init_vbases) return;
    obj.* = .{ .kind = obj.kind };
    sceneObjectCtor(g, obj);
}

/// `operator_new(n * 8)` + `crt_array_construct(frame_cell_ctor, n, 8)`; a
/// failed allocation gives no cells (the original stores NULL).
fn newCells(g: *Game, n: i16) []FrameCell {
    const cells = g.local().alloc(FrameCell, @as(u16, @bitCast(n))) catch return &.{};
    for (cells) |*c| c.* = frameCellCtor();
    return cells;
}

/// `operator_new(count * 0x1a + 2)` + `crt_array_construct(frame_ctor)`:
/// the strip array (its length is the stripCount).
fn newFrames(g: *Game, obj: *Object, count: i16) Error!void {
    const frames = g.local().alloc(Frame, @as(u16, @bitCast(count))) catch return error.OutOfMemory;
    for (frames) |*f| f.* = frameCtor();
    obj.frames = frames;
}

/// FrameVtbl slot 00 getCell: `cells + index * 8`. The original does not
/// check the index; one outside the array has no cell to name.
// @orig 10a0:1ee8 frame_get_cell
pub fn getCell(frame: *Frame, index: i16) ?*FrameCell {
    const i: usize = @as(u16, @bitCast(index));
    if (i >= frame.cells.len) return null;
    return &frame.cells[i];
}

// @orig 10a0:51b2 frame_ctor
/// vtbl = FrameVtbl, count = 0, dib = NULL (the other fields are
/// uninitialised in the original; the port zeroes them).
pub fn frameCtor() Frame {
    return .{};
}

/// A cell: the array constructor's element callback, nothing to set.
pub fn frameCellCtor() FrameCell {
    return .{ .raw = @splat(0) };
}

// @orig 10a0:51f2 frame_init
/// Fills a strip record (a zero hit width/height defaults to the frame's)
/// and allocates `count` cells.
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

// @orig 10a0:45c2 scene_object_ctor
/// SceneObject base: vtbl, name "", `id = g_nextId++`, wave NULL.
pub fn sceneObjectCtor(g: *Game, obj: *Object) void {
    obj.sceneName[0] = 0;
    obj.id = position.nextObjectId(g);
    obj.wave = null;
}

// @orig 10a0:219e scene_object_dtor
/// Stores the base vtable and frees the RLE buffer when `isRle`; the RLE
/// path is dead in SAUNA (`enableRle` is never called), so nothing is freed.
pub fn sceneObjectDtor(g: *Game, obj: *Object) void {
    _ = render.isRle(g, obj);
}

// @orig 10a0:008e scene_object_scalar_dtor
/// Scalar deleting destructor: the destructor, then `operator delete` of the
/// object when bit 0 of `flags` is set (the object must come from
/// `g.local()`). Returns `obj`.
pub fn sceneObjectScalarDtor(g: *Game, obj: *Object, flags: u16) *Object {
    sceneObjectDtor(g, obj);
    if (flags & 1 != 0) g.local().destroy(obj);
    return obj;
}

// @orig 10a0:8922 object3d_dtor
/// Empty.
pub fn object3dDtor(obj: *Object) void {
    _ = obj;
}

// @orig 10a0:895a animation_dtor
/// Empty.
pub fn animationDtor(obj: *Object) void {
    _ = obj;
}

// @orig 10a0:8938 animated3d_dtor
/// Nothing of its own: chains to `animation_dtor`.
pub fn animated3dDtor(obj: *Object) void {
    animationDtor(obj);
}

// @orig 10a0:4630 object3d_ctor
/// Object3D: with `init_vbases` the SceneObject's constructor, then the
/// Object3D vtables.
pub fn object3dCtor(g: *Game, obj: *Object, init_vbases: bool) void {
    begin(g, obj, init_vbases);
}

// @orig 10a0:4f30 scene_object_init_strips
/// Repeats the SceneObject initialiser (name "", a new id, wave NULL), then
/// loads the strips: `count` Frames, then per strip `load_dib(paths[i])` and
/// `frame_init`. A missing file leaves a null dib (no check here). A zero hit
/// dimension means the whole frame.
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
    sceneObjectCtor(g, obj);
    try newFrames(g, obj, count);
    const n = obj.frames.len;
    if (paths.len < n or counts.len < n or widths.len < n or heights.len < n) return error.LimitExceeded;
    for (obj.frames, 0..) |*f, i| {
        const d = dib_mod.loadDib(g.local(), g.plat, g.fixes, paths[i]);
        frameInit(g, f, d, counts[i], widths[i], heights[i], hit_x, hit_y, hit_w, hit_h);
    }
}

// @orig 10a0:5114 scene_object_init_state
/// Repeats the SceneObject initialiser (name "", a new id, wave NULL), then
/// position, visibility and the unknown word; not attached, strip 0, frame 0,
/// `playOnceRewinds = 0`.
pub fn sceneObjectInitState(g: *Game, obj: *Object, x: i16, y: i16, visible: i16, unk10: u16) void {
    sceneObjectCtor(g, obj);
    obj.x = x;
    obj.y = y;
    obj.playOnceRewinds = 0;
    obj.unk10 = unk10;
    obj.visible = visible;
    obj.attached = 0;
    obj.curStrip = 0;
    obj.curFrame = 0;
}

// @orig 10a0:7782 animation_ctor
/// Animation base part (Actor2D's): only the vtables.
pub fn animationCtor(g: *Game, obj: *Object, init_vbases: bool) void {
    begin(g, obj, init_vbases);
}

// @orig 10a0:7502 animation_ctor_strips_no_hitbox
/// Animation, multi-strip, hit box = the whole frame; the strip arrays hold
/// `count` entries each. `running` takes `play_once_rewinds`.
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
    obj.anim.unk12 = 0;
    obj.anim.playOnce = 0;
    obj.anim.framesLeft = 0;
    obj.anim.running = play_once_rewinds;
}

// @orig 10a0:72c2 animated3d_ctor_strips_no_hitbox
/// Animated3D: the Object3D part (with `init_vbases`), the Animation part,
/// then the Object3D size and support cleared.
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
    begin(g, obj, init_vbases);
    if (init_vbases) object3dCtor(g, obj, false);
    try animationCtorStripsNoHitbox(g, obj, x, y, count, paths, counts, widths, heights, timer_id, timer_period, play_once_rewinds, visible, unk10, false);
    obj.o3d.sizeD = 0;
    obj.o3d.sizeH = 0;
    obj.o3d.sizeW = 0;
    obj.o3d.support = null;
}

// @orig 10a0:6aac control_panel_ctor
/// ControlPanel: one strip (the scalar arguments as one-element tables).
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
    begin(g, obj, init_vbases);
    if (init_vbases) object3dCtor(g, obj, false);
    try animated3dCtorStripsNoHitbox(g, obj, x, y, 1, &.{bmp_path}, &.{count}, &.{width}, &.{height}, timer_id, timer_period, play_once_rewinds, visible, unk10, false);
    obj.panel.slideStepsLeft = 0;
    obj.panel.isOpen = 0;
}

// @orig 10a0:7810 mover_ctor
/// Mover part: position and state, previous and target position = the
/// position, the timer and the steps; not moving.
pub fn moverCtor(
    g: *Game,
    obj: *Object,
    x: i16,
    y: i16,
    timer_id: i16,
    timer_period: i16,
    step_x: i16,
    step_y: i16,
    visible: i16,
    unk10: u16,
    init_vbases: bool,
) void {
    begin(g, obj, init_vbases);
    sceneObjectInitState(g, obj, x, y, visible, unk10);
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

// @orig 10a0:762e actor2d_ctor_strips
/// Actor2D (Mover + Animation): the Mover part, the Animation part, the
/// strips with a hit box, then the Animation timer (the Mover's values) and
/// `running = play_once_rewinds`.
pub fn actor2dCtorStrips(
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
    begin(g, obj, init_vbases);
    moverCtor(g, obj, x, y, timer_id, timer_period, step_x, step_y, visible, unk10, false);
    animationCtor(g, obj, false);
    try sceneObjectInitStrips(g, obj, count, paths, counts, widths, heights, hit_x, hit_y, hit_w, hit_h);
    obj.anim.timerId = timer_id;
    obj.anim.timerPeriod = timer_period;
    obj.anim.unk12 = 0;
    obj.anim.framesLeft = 0;
    obj.anim.running = play_once_rewinds;
}

// @orig 10a0:718c player2d_ctor
/// Player2D: the Actor2D part, then lives and score zeroed.
pub fn player2dCtor(
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
    begin(g, obj, init_vbases);
    try actor2dCtorStrips(g, obj, x, y, count, paths, counts, widths, heights, hit_x, hit_y, hit_w, hit_h, timer_id, timer_period, step_x, step_y, play_once_rewinds, visible, unk10, false);
    obj.player2d.lives = 0;
    obj.player2d.score = 0;
}

// @orig 10a0:7018 pacman_ctor
/// Pacman (the player; kind `pacman`): the Player2D part with
/// `play_once_rewinds = 1` and the Pacman tables (no own fields).
pub fn pacmanCtor(
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
    obj.kind = .pacman;
    begin(g, obj, init_vbases);
    try player2dCtor(g, obj, x, y, count, paths, counts, widths, heights, hit_x, hit_y, hit_w, hit_h, timer_id, timer_period, step_x, step_y, 1, visible, unk10, false);
}

// @orig 10a0:9406 ghost_ctor
/// Ghost (kind `ghost`): the Actor2D part with `play_once_rewinds = 1` and
/// the Ghost tables (no own fields).
pub fn ghostCtor(
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
    obj.kind = .ghost;
    begin(g, obj, init_vbases);
    try actor2dCtorStrips(g, obj, x, y, count, paths, counts, widths, heights, hit_x, hit_y, hit_w, hit_h, timer_id, timer_period, step_x, step_y, 1, visible, unk10, false);
}

// @orig 10a0:91fe scene_object_ctor_bmp
/// SceneObject with one picture (the peanut and cork dots; kind `dot`): id,
/// position, one strip loaded from `bmp_path`. A missing file shows the
/// fatal box ("N\xe3o foi poss\xedvel abrir o arquivo: %s") and carries on
/// with a null dib, as the original.
pub fn sceneObjectCtorBmp(
    g: *Game,
    obj: *Object,
    x: i16,
    y: i16,
    bmp_path: []const u8,
    count: i16,
    width: i16,
    height: i16,
    visible: i16,
    unk10: u16,
) Error!void {
    obj.kind = .dot;
    begin(g, obj, true);
    obj.x = x;
    obj.y = y;
    obj.playOnceRewinds = 0;
    obj.unk10 = unk10;
    obj.visible = visible;
    obj.attached = 0;
    obj.curStrip = 0;
    obj.curFrame = 0;
    try newFrames(g, obj, 1);
    const d = dib_mod.loadDib(g.local(), g.plat, g.fixes, bmp_path);
    if (d == null) {
        position.messageBoxPrintf(g, "Erro Fatal!!", "N\xe3o foi poss\xedvel abrir o arquivo: %s", bmp_path);
    }
    frameInit(g, &obj.frames[0], d, count, width, height, 0, 0, 0, 0);
}

const testing = std.testing;
const TestGame = @import("core/game.zig").TestGame;

// @orig 10a0:51f2 frame_init oracle=documented
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

// @orig 10a0:9406 ghost_ctor oracle=documented
test "ghost ctor flattens Actor2D, sets running and takes three ids" {
    var tg = try TestGame.init(testing.allocator);
    defer tg.deinit();
    const g = tg.game;
    var o: Object = .{ .kind = .ghost };
    const paths = [_][]const u8{ "none1.bmp", "none2.bmp" };
    const counts = [_]i16{ 3, 3 };
    const w = [_]i16{ 24, 24 };
    const h = [_]i16{ 24, 24 };
    const start = g.nextId;
    try ghostCtor(g, &o, 300, 230, 2, &paths, &counts, &w, &h, 8, 8, 24, 24, 0x11, 0x37, 16, 16, 1, 0, true);
    try testing.expectEqual(@as(usize, 2), o.frames.len);
    try testing.expectEqual(@as(i16, 24), o.frames[0].hitW);
    try testing.expectEqual(@as(i16, 1), o.anim.running);
    try testing.expectEqual(@as(i16, 300), o.mover.prevX);
    try testing.expectEqual(@as(i16, 0x11), o.anim.timerId);
    try testing.expectEqual(start +% 3, g.nextId);
    try testing.expectEqual(start +% 2, o.id);
}
