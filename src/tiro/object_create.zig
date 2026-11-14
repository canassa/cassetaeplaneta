//! Port unit `object_create` (module) of TIRO.EXE. constructors and destructors of the objects (Crossbow/Target/Arrow/Projectile, Player2D/Actor2D/Mover/Animation, TiroPanel/ControlPanel/Animated3D/Object3D, StatusBar, SceneObject) and frames.
//!
//! Each constructor chain is flattened onto one `Object` as in ENCAIXE: the
//! most-derived constructor of a complete object (`init_vbases`) resets it
//! to the field defaults (the original's uninitialised heap bytes) with the
//! `kind` set and takes the SceneObject's serial number (the original builds
//! the vbtables and vtables here); the base-part constructors then run with
//! `init_vbases = false`. Parameters follow DESIGN.md: `(g, obj, <source
//! order>, init_vbases)`, the Ghidra list reversed. TIRO's `/Od` build keeps
//! out of line what ENCAIXE inlines (`scene_object_ctor`, `object3d_ctor`,
//! `scene_object_init_strips`, `scene_object_init_state`, `animation_ctor`,
//! `mover_ctor`, `projectile_ctor`, the destructors). SceneObject offsets in
//! the decompile are 2 above `Object`'s `@orig` ones (the vtordisp word).
//! Everything the original `new`s lives in the task's local heap
//! (`g.local()`), and no destructor frees the strips.

const std = @import("std");
const Game = @import("core/game.zig").Game;
const object = @import("core/object.zig");
const Object = object.Object;
const Frame = object.Frame;
const FrameCell = object.FrameCell;
const Dib = object.Dib;
const dib_mod = @import("dib.zig");
const position = @import("behaviour/position.zig");

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

/// `operator_new(count * 0x16 + 2)` + `crt_array_construct(frame_ctor)`:
/// the strip array (its length is the stripCount).
fn newFrames(g: *Game, obj: *Object, count: i16) Error!void {
    const frames = g.local().alloc(Frame, @as(u16, @bitCast(count))) catch return error.OutOfMemory;
    for (frames) |*f| f.* = frameCtor();
    obj.frames = frames;
}

// @orig 1088:137a frame_get_cell
/// FrameVtbl slot 00 getCell: `cells + index * 8`. The original does not
/// check the index; one outside the array has no cell to name.
pub fn getCell(frame: *Frame, index: i16) ?*FrameCell {
    const i: usize = @as(u16, @bitCast(index));
    if (i >= frame.cells.len) return null;
    return &frame.cells[i];
}

// @orig 1088:34d4 frame_cell_ctor
/// Four words zeroed.
pub fn frameCellCtor() FrameCell {
    return .{ .raw = @splat(0) };
}

// @orig 1088:33f6 frame_ctor
/// vtbl = FrameVtbl, count = 0, dib = NULL (the other fields are
/// uninitialised in the original; the port zeroes them).
pub fn frameCtor() Frame {
    return .{};
}

// @orig 1088:3422 frame_init
/// Fills a strip record (a zero hit width/height defaults to the frame's)
/// and allocates `count` cells. Unlike ENCAIXE's (E4) TIRO reads the cell
/// count from the argument: no flag.
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

// @orig 1088:16a2 scene_object_ctor
/// SceneObject base: vtbl and `id = g_nextId++`.
pub fn sceneObjectCtor(g: *Game, obj: *Object) void {
    obj.id = position.nextObjectId(g);
}

// @orig 1088:3b3c scene_object_dtor
/// Only stores the base vtable: TIRO's frees nothing (NOITE's frees the
/// strips).
pub fn sceneObjectDtor(obj: *Object) void {
    _ = obj;
}

// @orig 1088:3a9a scene_object_scalar_dtor
/// Scalar deleting destructor: the destructor, then `operator delete` of the
/// object when bit 0 of `flags` is set (the object must come from
/// `g.local()`). Returns `obj`.
pub fn sceneObjectScalarDtor(g: *Game, obj: *Object, flags: u16) *Object {
    sceneObjectDtor(obj);
    if (flags & 1 != 0) g.local().destroy(obj);
    return obj;
}

// @orig 1088:4062 object3d_dtor
/// Empty.
pub fn object3dDtor(obj: *Object) void {
    _ = obj;
}

// @orig 1088:414c animation_dtor
/// Empty.
pub fn animationDtor(obj: *Object) void {
    _ = obj;
}

// @orig 1088:412c animated3d_dtor
/// Nothing of its own: chains to `animation_dtor`.
pub fn animated3dDtor(obj: *Object) void {
    animationDtor(obj);
}

// @orig 1088:253a object3d_ctor
/// Object3D (out of line here; ENCAIXE inlines it): with `init_vbases` the
/// SceneObject's constructor, then the Object3D vtables.
pub fn object3dCtor(g: *Game, obj: *Object, init_vbases: bool) void {
    begin(g, obj, init_vbases);
}

// @orig 1088:3278 scene_object_init_strips
/// Loads the strips: `count` Frames, then per strip `load_dib(paths[i])` and
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
    try newFrames(g, obj, count);
    const n = obj.frames.len;
    if (paths.len < n or counts.len < n or widths.len < n or heights.len < n) return error.LimitExceeded;
    for (obj.frames, 0..) |*f, i| {
        const d = dib_mod.loadDib(g.local(), g.plat, g.fixes, paths[i]);
        frameInit(g, f, d, counts[i], widths[i], heights[i], hit_x, hit_y, hit_w, hit_h);
    }
}

// @orig 1088:33b4 scene_object_init_state
/// Position, visibility and the unknown word; not attached, strip 0, frame 0.
pub fn sceneObjectInitState(obj: *Object, x: i16, y: i16, visible: i16, unk08: u16) void {
    obj.x = x;
    obj.y = y;
    obj.unk08 = unk08;
    obj.visible = visible;
    obj.attached = 0;
    obj.curStrip = 0;
    obj.curFrame = 0;
}

// @orig 1088:5bea animation_ctor
/// Animation base part (Actor2D's): only the vtables.
pub fn animationCtor(g: *Game, obj: *Object, init_vbases: bool) void {
    begin(g, obj, init_vbases);
}

// @orig 1088:5c3e animation_ctor_strips_no_hitbox
/// Animation, multi-strip, hit box = the whole frame; the strip arrays hold
/// `count` entries each.
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
    visible: i16,
    unk10: u16,
    init_vbases: bool,
) Error!void {
    begin(g, obj, init_vbases);
    obj.anim.timerId = timer_id;
    obj.anim.timerPeriod = timer_period;
    try sceneObjectInitStrips(g, obj, count, paths, counts, widths, heights, 0, 0, 0, 0);
    sceneObjectInitState(obj, x, y, visible, unk10);
    obj.anim.running = 0;
    obj.anim.playOnce = 0;
    obj.anim.framesLeft = 0;
}

// @orig 1088:5946 animated3d_ctor_strips_no_hitbox
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
    visible: i16,
    unk10: u16,
    init_vbases: bool,
) Error!void {
    begin(g, obj, init_vbases);
    if (init_vbases) object3dCtor(g, obj, false);
    try animationCtorStripsNoHitbox(g, obj, x, y, count, paths, counts, widths, heights, timer_id, timer_period, visible, unk10, false);
    obj.o3d.sizeD = 0;
    obj.o3d.sizeH = 0;
    obj.o3d.sizeW = 0;
    obj.o3d.support = null;
}

// @orig 1088:5276 control_panel_ctor
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
    visible: i16,
    unk10: u16,
    init_vbases: bool,
) Error!void {
    begin(g, obj, init_vbases);
    if (init_vbases) object3dCtor(g, obj, false);
    try animated3dCtorStripsNoHitbox(g, obj, x, y, 1, &.{bmp_path}, &.{count}, &.{width}, &.{height}, timer_id, timer_period, visible, unk10, false);
    obj.panel.slideStepsLeft = 0;
    obj.panel.isOpen = 0;
}

// @orig 1088:4d7e tiro_panel_ctor
/// TiroPanel (kind `control_panel`; no own fields): the ControlPanel part
/// with the TiroPanel tables installed over it. Unlike ENCAIXE's TetrisPanel
/// (E11) the arguments agree with the callee.
pub fn tiroPanelCtor(
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
    visible: i16,
    unk10: u16,
    init_vbases: bool,
) Error!void {
    obj.kind = .control_panel;
    begin(g, obj, init_vbases);
    if (init_vbases) object3dCtor(g, obj, false);
    try controlPanelCtor(g, obj, x, y, bmp_path, count, width, height, timer_id, timer_period, visible, unk10, false);
}

// @orig 1088:5cf2 mover_ctor
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
    sceneObjectInitState(obj, x, y, visible, unk10);
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

// @orig 1088:587c actor2d_ctor_strips
/// Actor2D (Mover + Animation): the Mover part, the Animation part, the
/// strips with a hit box, then the Animation timer (the Mover's values).
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
    obj.anim.running = 0;
    obj.anim.framesLeft = 0;
}

// @orig 1088:51b0 player2d_ctor
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
    visible: i16,
    unk10: u16,
    init_vbases: bool,
) Error!void {
    begin(g, obj, init_vbases);
    try actor2dCtorStrips(g, obj, x, y, count, paths, counts, widths, heights, hit_x, hit_y, hit_w, hit_h, timer_id, timer_period, step_x, step_y, visible, unk10, false);
    obj.player2d.lives = 0;
    obj.player2d.score = 0;
}

// @orig 1088:4f50 crossbow_ctor
/// Crossbow (the player): the Player2D part with the Crossbow tables (kind
/// `crossbow`; no own fields set).
pub fn crossbowCtor(
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
    obj.kind = .crossbow;
    begin(g, obj, init_vbases);
    try player2dCtor(g, obj, x, y, count, paths, counts, widths, heights, hit_x, hit_y, hit_w, hit_h, timer_id, timer_period, step_x, step_y, visible, unk10, false);
}

// @orig 1088:6170 projectile_ctor
/// Projectile (never built alone): the Actor2D part with the Projectile
/// tables; `unk46` is left to the arrow's creator.
pub fn projectileCtor(
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
    try actor2dCtorStrips(g, obj, x, y, count, paths, counts, widths, heights, hit_x, hit_y, hit_w, hit_h, timer_id, timer_period, step_x, step_y, visible, unk10, false);
}

// @orig 1088:60d8 arrow_ctor
/// Arrow (kind `arrow`): the Projectile part with the Arrow tables.
pub fn arrowCtor(
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
    obj.kind = .arrow;
    begin(g, obj, init_vbases);
    try projectileCtor(g, obj, x, y, count, paths, counts, widths, heights, hit_x, hit_y, hit_w, hit_h, timer_id, timer_period, step_x, step_y, visible, unk10, false);
}

// @orig 1088:603a target_ctor
/// Target (kind `target`): the Actor2D part with the Target tables, then
/// `unk40 = 1`. The identity (`rand() % 10`) is drawn by the caller.
pub fn targetCtor(
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
    obj.kind = .target;
    begin(g, obj, init_vbases);
    try actor2dCtorStrips(g, obj, x, y, count, paths, counts, widths, heights, hit_x, hit_y, hit_w, hit_h, timer_id, timer_period, step_x, step_y, visible, unk10, false);
    obj.target.unk40 = 1;
}

// @orig 1088:50ea scene_object_ctor_bmp
/// SceneObject with one picture (the StatusBar base; ENCAIXE inlines it):
/// id, position, one strip loaded from `bmp_path`. A missing file shows the
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
    unk08: u16,
) Error!void {
    begin(g, obj, true);
    sceneObjectInitState(obj, x, y, visible, unk08);
    try newFrames(g, obj, 1);
    const d = dib_mod.loadDib(g.local(), g.plat, g.fixes, bmp_path);
    if (d == null) {
        position.messageBoxPrintf(g, "Erro Fatal!!", "N\xe3o foi poss\xedvel abrir o arquivo: %s", bmp_path);
    }
    frameInit(g, &obj.frames[0], d, count, width, height, 0, 0, 0, 0);
}

// @orig 1088:4e3e status_bar_ctor
/// StatusBar (kind `status_bar`): the one-picture SceneObject, then the
/// StatusBar table and the text colour (a COLORREF).
pub fn statusBarCtor(
    g: *Game,
    obj: *Object,
    x: i16,
    y: i16,
    text_color: u32,
    bmp_path: []const u8,
    count: i16,
    width: i16,
    height: i16,
    visible: i16,
    unk08: u16,
) Error!void {
    obj.kind = .status_bar;
    try sceneObjectCtorBmp(g, obj, x, y, bmp_path, count, width, height, visible, unk08);
    obj.status.textColor = text_color;
}

const testing = std.testing;
const TestGame = @import("core/game.zig").TestGame;

// @orig 1088:3422 frame_init oracle=documented
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

// @orig 1088:603a target_ctor oracle=documented
test "target ctor flattens Actor2D and sets unk40" {
    var tg = try TestGame.init(testing.allocator);
    defer tg.deinit();
    const g = tg.game;
    var o: Object = .{ .kind = .target };
    const paths = [_][]const u8{ "none1.bmp", "none2.bmp" };
    const counts = [_]i16{ 3, 3 };
    const w = [_]i16{ 75, 75 };
    const h = [_]i16{ 95, 95 };
    try targetCtor(g, &o, 44, 85, 2, &paths, &counts, &w, &h, 0, 0, 0, 0, 7, 100, 20, 20, 1, 0, true);
    try testing.expectEqual(@as(i16, 1), o.target.unk40);
    try testing.expectEqual(@as(usize, 2), o.frames.len);
    try testing.expectEqual(@as(i16, 75), o.frames[0].hitW);
    try testing.expectEqual(@as(usize, 3), o.frames[1].cells.len);
    try testing.expectEqual(@as(i16, 44), o.mover.prevX);
    try testing.expectEqual(@as(i16, 7), o.anim.timerId);
    try testing.expectEqual(@as(i16, 20), o.mover.stepY);
}
