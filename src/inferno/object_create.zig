//! Port unit `object_create` (module) of INFERNO.EXE. Constructors and
//! destructors of the objects (Hero, Platform, Prop, Hazard;
//! Player2D/Actor2D/Mover/Animation, SceneObject) and the frames (FrameVtbl
//! getCell).
//!
//! Each constructor chain is flattened onto one `Object` as in TIRO: the
//! most-derived constructor of a complete object (`init_vbases`) resets it to
//! the field defaults (the original's uninitialised heap bytes) with the
//! `kind` set; the base-part constructors then run with `init_vbases =
//! false`. Parameters: `(g, obj, <source order>, init_vbases)`, the Ghidra
//! list reversed (the far strip arrays are slices). INFERNO's SceneObject
//! constructor only stores the vtable: it takes no serial number (TIRO's
//! `id = g_nextId++`), so `id` stays 0. Everything the original `new`s lives
//! in the task's local heap (`g.local()`), and no destructor frees the strips.

const std = @import("std");
const Game = @import("core/game.zig").Game;
const object = @import("core/object.zig");
const Object = object.Object;
const Frame = object.Frame;
const FrameCell = object.FrameCell;
const Dib = object.Dib;
const dib_mod = @import("dib.zig");

pub const Error = error{ OutOfMemory, LimitExceeded };

/// What a constructor with `init_vbases` starts with: a fresh object of the
/// kind (the original builds the vbtables and vtables here).
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

/// `operator_new(count * 0x12 + 2)` + `crt_array_construct(frame_ctor)`: the
/// strip array (its length is the stripCount).
fn newFrames(g: *Game, obj: *Object, count: i16) Error!void {
    const frames = g.local().alloc(Frame, @as(u16, @bitCast(count))) catch return error.OutOfMemory;
    for (frames) |*f| f.* = frameCtor();
    obj.frames = frames;
}

// @orig 1080:2094 frame_get_cell
/// FrameVtbl slot 00 getCell: `cells + index * 8`. The original does not
/// check the index; one outside the array has no cell to name.
pub fn getCell(frame: *Frame, index: i16) ?*FrameCell {
    const i: usize = @as(u16, @bitCast(index));
    if (i >= frame.cells.len) return null;
    return &frame.cells[i];
}

// @orig 1080:46d0 frame_cell_ctor
/// Four words zeroed.
pub fn frameCellCtor() FrameCell {
    return .{ .raw = @splat(0) };
}

// @orig 1080:45ee frame_ctor
/// vtbl = FrameVtbl, count = 0, dib = NULL (the other fields are
/// uninitialised in the original; the port zeroes them).
pub fn frameCtor() Frame {
    return .{};
}

// @orig 1080:462e frame_init
/// Stores dib, count, width and height and allocates `count` cells. No hit
/// box arguments (INFERNO's is in the SceneObject).
pub fn frameInit(g: *Game, f: *Frame, dib: ?*Dib, count: i16, width: i16, height: i16) void {
    f.dib = dib;
    f.count = count;
    f.width = width;
    f.height = height;
    f.cells = newCells(g, f.count);
}

// @orig 1080:2316 scene_object_ctor
/// SceneObject base: only stores the vtable (no id, unlike TIRO's).
pub fn sceneObjectCtor(g: *Game, obj: *Object) void {
    _ = g;
    _ = obj;
}

// @orig 1080:5820 scene_object_dtor
/// Only stores the base vtable: frees nothing.
pub fn sceneObjectDtor(obj: *Object) void {
    _ = obj;
}

// @orig 1080:56d2 scene_object_scalar_dtor
/// Scalar deleting destructor: the destructor, then `operator delete` of the
/// object when bit 0 of `flags` is set (the object must come from
/// `g.local()`). Returns `obj`.
pub fn sceneObjectScalarDtor(g: *Game, obj: *Object, flags: u16) *Object {
    sceneObjectDtor(obj);
    if (flags & 1 != 0) g.local().destroy(obj);
    return obj;
}

// @orig 1080:446c scene_object_init_strips
/// Loads the strips: `count` Frames, then per strip `load_dib(paths[i])` and
/// `frame_init`. A missing file leaves a null dib (no check here).
pub fn sceneObjectInitStrips(
    g: *Game,
    obj: *Object,
    count: i16,
    paths: []const []const u8,
    counts: []const i16,
    widths: []const i16,
    heights: []const i16,
) Error!void {
    try newFrames(g, obj, count);
    const n = obj.frames.len;
    if (paths.len < n or counts.len < n or widths.len < n or heights.len < n) return error.LimitExceeded;
    for (obj.frames, 0..) |*f, i| {
        const d = dib_mod.loadDib(g.local(), g.plat, g.fixes, paths[i]);
        frameInit(g, f, d, counts[i], widths[i], heights[i]);
    }
}

// @orig 1080:4566 scene_object_init_state
/// Position, unknown word, visibility and the hit box; not attached, strip 0,
/// frame 0.
pub fn sceneObjectInitState(
    obj: *Object,
    x: i16,
    y: i16,
    hit_x: i16,
    hit_y: i16,
    hit_w: i16,
    hit_h: i16,
    visible: i16,
    unk10: u16,
) void {
    obj.x = x;
    obj.y = y;
    obj.unk10 = unk10;
    obj.visible = visible;
    obj.attached = 0;
    obj.curStrip = 0;
    obj.curFrame = 0;
    obj.hitX = hit_x;
    obj.hitY = hit_y;
    obj.hitW = hit_w;
    obj.hitH = hit_h;
}

// @orig 1080:7aec animation_ctor
/// Animation base part (Actor2D's): only the vtables.
pub fn animationCtor(g: *Game, obj: *Object, init_vbases: bool) void {
    begin(g, obj, init_vbases);
}

// @orig 1080:7b7a mover_ctor
/// Mover part: position, hit box and state, previous and target position =
/// the position, the timer and the steps; not moving.
pub fn moverCtor(
    g: *Game,
    obj: *Object,
    x: i16,
    y: i16,
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
) void {
    begin(g, obj, init_vbases);
    sceneObjectInitState(obj, x, y, hit_x, hit_y, hit_w, hit_h, visible, unk10);
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

// @orig 1080:77da actor2d_ctor_strips
/// Actor2D (Mover + Animation): the Mover part, the Animation part, the
/// strips, then the Animation timer (the Mover's values) and not running.
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
    moverCtor(g, obj, x, y, hit_x, hit_y, hit_w, hit_h, timer_id, timer_period, step_x, step_y, visible, unk10, false);
    animationCtor(g, obj, false);
    try sceneObjectInitStrips(g, obj, count, paths, counts, widths, heights);
    obj.anim.timerId = timer_id;
    obj.anim.timerPeriod = timer_period;
    obj.anim.running = 0;
    obj.anim.framesLeft = 0;
}

// @orig 1080:739a player2d_ctor
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

// @orig 1080:86c0 platform_ctor
/// Platform (kind `platform`): the Actor2D part, then `presentReady = 0`.
pub fn platformCtor(
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
    if (init_vbases) obj.kind = .platform;
    begin(g, obj, init_vbases);
    try actor2dCtorStrips(g, obj, x, y, count, paths, counts, widths, heights, hit_x, hit_y, hit_w, hit_h, timer_id, timer_period, step_x, step_y, visible, unk10, false);
    obj.platform.presentReady = 0;
}

// @orig 1080:87c0 prop_ctor
/// Prop (kind `prop`; a Hazard keeps its own kind): the Actor2D part, then `active` and `powerUp` cleared.
pub fn propCtor(
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
    if (init_vbases) obj.kind = .prop;
    begin(g, obj, init_vbases);
    try actor2dCtorStrips(g, obj, x, y, count, paths, counts, widths, heights, hit_x, hit_y, hit_w, hit_h, timer_id, timer_period, step_x, step_y, visible, unk10, false);
    obj.prop.active = 0;
    obj.prop.powerUp = 0;
}

// @orig 1080:88ca hazard_ctor
/// Hazard (kind `hazard`): the Prop part with the Hazard tables; no fields of its own.
pub fn hazardCtor(
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
    if (init_vbases) obj.kind = .hazard;
    begin(g, obj, init_vbases);
    try propCtor(g, obj, x, y, count, paths, counts, widths, heights, hit_x, hit_y, hit_w, hit_h, timer_id, timer_period, step_x, step_y, visible, unk10, false);
}

// @orig 1080:70fa hero_ctor
/// Hero (kind `hero`, the player): the Player2D part with the move timer,
/// then busy/walking/altStrips/jumpTicks/powerTimer cleared, `jumpPhase = 4`,
/// `facing = 2` and the Animation timer set to the anim arguments.
pub fn heroCtor(
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
    move_timer_id: i16,
    move_timer_period: i16,
    anim_timer_id: i16,
    anim_timer_period: i16,
    step_x: i16,
    step_y: i16,
    visible: i16,
    unk10: u16,
    init_vbases: bool,
) Error!void {
    if (init_vbases) obj.kind = .hero;
    begin(g, obj, init_vbases);
    try player2dCtor(g, obj, x, y, count, paths, counts, widths, heights, hit_x, hit_y, hit_w, hit_h, move_timer_id, move_timer_period, step_x, step_y, visible, unk10, false);
    obj.hero.busy = 0;
    obj.hero.walking = 0;
    obj.hero.altStrips = 0;
    obj.hero.jumpTicks = 0;
    obj.hero.jumpPhase = 4;
    obj.hero.facing = 2;
    obj.hero.powerTimer = 0;
    obj.anim.timerId = anim_timer_id;
    obj.anim.timerPeriod = anim_timer_period;
}

const testing = std.testing;
const TestGame = @import("core/game.zig").TestGame;

// @orig 1080:462e frame_init oracle=documented
test "frame init sizes the cells by count" {
    var tg = try TestGame.init(testing.allocator);
    defer tg.deinit();
    const g = tg.game;
    var f = frameCtor();
    frameInit(g, &f, null, 4, 100, 50);
    try testing.expectEqual(@as(i16, 50), f.height);
    try testing.expectEqual(@as(usize, 4), f.cells.len);
    try testing.expect(getCell(&f, 3) != null);
    try testing.expect(getCell(&f, 4) == null);
}

// @orig 1080:70fa hero_ctor oracle=documented
test "hero ctor flattens Actor2D and sets its state" {
    var tg = try TestGame.init(testing.allocator);
    defer tg.deinit();
    const g = tg.game;
    var o: Object = .{ .kind = .hero };
    const paths = [_][]const u8{ "none1.bmp", "none2.bmp" };
    const counts = [_]i16{ 3, 3 };
    const w = [_]i16{ 38, 38 };
    const h = [_]i16{ 65, 65 };
    try heroCtor(g, &o, 153, 306, 2, &paths, &counts, &w, &h, 0, 0, 62, 32, 10, 55, 15, 180, 4, 4, 1, 0, true);
    try testing.expectEqual(@as(i16, 2), o.hero.facing);
    try testing.expectEqual(@as(u16, 4), o.hero.jumpPhase);
    try testing.expectEqual(@as(usize, 2), o.frames.len);
    try testing.expectEqual(@as(i16, 62), o.hitW);
    try testing.expectEqual(@as(i16, 153), o.mover.prevX);
    try testing.expectEqual(@as(i16, 10), o.mover.timerId);
    try testing.expectEqual(@as(i16, 15), o.anim.timerId);
    try testing.expectEqual(@as(i16, 180), o.anim.timerPeriod);
}
