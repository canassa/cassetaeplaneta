//! Port unit `object_create` (module) of ENCAIXE.EXE. constructors (Piece/Player2D/Actor2D, TetrisPanel/ControlPanel/Animated3D/Animation) and frames.
//!
//! Each constructor chain is flattened onto one `Object`: the most-derived
//! constructor of a complete object (`init_vbases`) resets it to the field
//! defaults (the original's uninitialised heap bytes) with the `kind` set and
//! takes the SceneObject's serial number (the original builds the vbtables
//! and vtables here); the base-part constructors then run with
//! `init_vbases = false`. Parameters follow DESIGN.md: `(g, obj, <source
//! order>, init_vbases)`, the Ghidra list reversed. SceneObject offsets in
//! the decompile are 2 above `Object`'s `@orig` ones (the vtordisp word).

const std = @import("std");
const Game = @import("core/game.zig").Game;
const object = @import("core/object.zig");
const Object = object.Object;
const Kind = object.Kind;
const Frame = object.Frame;
const FrameCell = object.FrameCell;
const Dib = object.Dib;
const dib_mod = @import("dib.zig");
const position = @import("behaviour/position.zig");

pub const Error = error{ OutOfMemory, LimitExceeded };

/// What a constructor with `init_vbases` starts with: a fresh object of the
/// kind and the SceneObject's new serial number.
fn begin(g: *Game, obj: *Object, init_vbases: bool) void {
    if (!init_vbases) return;
    obj.* = .{ .kind = obj.kind };
    obj.id = position.nextObjectId(g);
}

/// `operator_new(n * 8)` + `crt_array_construct(frame_cell_ctor, n, 8)`; a
/// failed allocation gives no cells (the original stores NULL).
fn newCells(g: *Game, n: i16) []FrameCell {
    const cells = g.gpa.alloc(FrameCell, @as(u16, @bitCast(n))) catch return &.{};
    for (cells) |*c| c.* = frameCellCtor();
    return cells;
}

/// `operator_new(count * 0x16 + 2)` + `crt_array_construct(frame_ctor)`:
/// the strip array (its length is the stripCount).
fn newFrames(g: *Game, obj: *Object, count: i16) Error!void {
    const frames = g.gpa.alloc(Frame, @as(u16, @bitCast(count))) catch return error.OutOfMemory;
    for (frames) |*f| f.* = frameCtor();
    obj.frames = frames;
}

// @orig 1008:522c frame_get_cell
/// FrameVtbl slot 00 getCell: `cells + index * 8`. The original does not
/// check the index; one outside the array has no cell to name.
pub fn getCell(frame: *Frame, index: i16) ?*FrameCell {
    const i: usize = @as(u16, @bitCast(index));
    if (i >= frame.cells.len) return null;
    return &frame.cells[i];
}

// @orig 1008:66fc frame_cell_ctor
/// Four words zeroed.
pub fn frameCellCtor() FrameCell {
    return .{ .raw = @splat(0) };
}

// @orig 1008:6716 frame_ctor
/// vtbl = FrameVtbl, count = 0, dib = NULL (the other fields are
/// uninitialised in the original; the port zeroes them).
pub fn frameCtor() Frame {
    return .{};
}

// @orig 1008:a49a frame_init
/// Fills a strip record (a zero hit width/height defaults to the frame's)
/// and allocates its cells. E4 (original): the cell count is read from an
/// uninitialised local, never from `count`; taken as 0 (no cells), and
/// `fixes.encaixe_status_frame_cells` sizes it by `count`.
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
    f.cells = newCells(g, if (g.fixes.encaixe_status_frame_cells) count else 0);
}

/// The strip loop shared by the constructors below: one DIB per strip.
/// `hit` null is the whole frame; `cells_by_width` is E8's quirk.
fn loadStrips(
    g: *Game,
    obj: *Object,
    paths: []const []const u8,
    counts: []const i16,
    widths: []const i16,
    heights: []const i16,
    hit: ?[4]i16,
    cells_by_width: bool,
) Error!void {
    const n = obj.frames.len;
    if (paths.len < n or counts.len < n or widths.len < n or heights.len < n) return error.LimitExceeded;
    for (obj.frames, 0..) |*f, i| {
        const height = heights[i];
        const width = widths[i];
        const frame_count = counts[i];
        const d = dib_mod.loadDib(g.gpa, g.plat, g.fixes, paths[i]);
        f.dib = d;
        f.count = frame_count;
        f.width = width;
        f.height = height;
        if (hit) |h| {
            f.hitX = h[0];
            f.hitY = h[1];
            f.hitW = if (h[2] == 0) width else h[2];
            f.hitH = if (h[3] == 0) height else h[3];
        } else {
            f.hitX = 0;
            f.hitY = 0;
            f.hitW = width;
            f.hitH = height;
        }
        const by_width = cells_by_width and !g.fixes.encaixe_strip_cells_by_count;
        f.cells = newCells(g, if (by_width) width else frame_count);
    }
}

// @orig 1008:ae7a animation_ctor_strips_no_hitbox
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
    try newFrames(g, obj, count);
    try loadStrips(g, obj, paths, counts, widths, heights, null, false);
    obj.x = x;
    obj.y = y;
    obj.unk08 = unk10;
    obj.visible = visible;
    obj.attached = 0;
    obj.curStrip = 0;
    obj.curFrame = 0;
    obj.anim.playOnce = 0;
    obj.anim.running = 0;
    obj.anim.framesLeft = 0;
}

// @orig 1008:ade4 animated3d_ctor_strips_no_hitbox
/// Animated3D: the Animation part, then the Object3D size and support
/// cleared.
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
    try animationCtorStripsNoHitbox(g, obj, x, y, count, paths, counts, widths, heights, timer_id, timer_period, visible, unk10, false);
    obj.o3d.sizeW = 0;
    obj.o3d.sizeH = 0;
    obj.o3d.sizeD = 0;
    obj.o3d.support = null;
}

// @orig 1008:acfe control_panel_ctor
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
    try animated3dCtorStripsNoHitbox(g, obj, x, y, 1, &.{bmp_path}, &.{count}, &.{width}, &.{height}, timer_id, timer_period, visible, unk10, false);
    obj.panel.slideStepsLeft = 0;
    obj.panel.isOpen = 0;
}

// @orig 1008:a59e te_panel_ctor
/// TetrisPanel (kind `control_panel`), the TetrisPanel and ControlPanel
/// vtables installed over the Animated3D ones.
pub fn tePanelCtor(
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
    try controlPanelCtor(g, obj, x, y, bmp_path, count, width, height, timer_id, timer_period, visible, unk10, false);
}

// @orig 1008:aa92 actor2d_ctor_strips
/// Actor2D (Mover + Animation): position and steps, the Mover and Animation
/// timers, and the strips with a hit box. E8 (original): each strip's cell
/// array is sized by the frame width, not the count
/// (`fixes.encaixe_strip_cells_by_count` uses the count).
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
    obj.x = x;
    obj.y = y;
    obj.unk08 = unk10;
    obj.visible = visible;
    obj.attached = 0;
    obj.curStrip = 0;
    obj.curFrame = 0;
    obj.mover.prevX = x;
    obj.mover.targetX = x;
    obj.mover.prevY = y;
    obj.mover.targetY = y;
    obj.mover.timerId = timer_id;
    obj.mover.timerPeriod = timer_period;
    obj.mover.stepX = step_x;
    obj.mover.stepY = step_y;
    obj.mover.moving = 0;
    try newFrames(g, obj, count);
    try loadStrips(g, obj, paths, counts, widths, heights, .{ hit_x, hit_y, hit_w, hit_h }, true);
    obj.anim.timerId = timer_id;
    obj.anim.timerPeriod = timer_period;
    obj.anim.running = 0;
    obj.anim.framesLeft = 0;
}

// @orig 1008:a520 player2d_ctor
/// Player2D (kind `piece`): the Actor2D part, then lives and score zeroed.
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
    obj.kind = .piece;
    begin(g, obj, init_vbases);
    try actor2dCtorStrips(g, obj, x, y, count, paths, counts, widths, heights, hit_x, hit_y, hit_w, hit_h, timer_id, timer_period, step_x, step_y, visible, unk10, false);
    obj.player2d.lives = 0;
    obj.player2d.score = 0;
}

const testing = std.testing;
const TestGame = @import("core/game.zig").TestGame;

// @orig 1008:a49a frame_init oracle=documented
test "frame init defaults the hit box; E4 gives no cells unless fixed" {
    var tg = try TestGame.init(testing.allocator);
    defer tg.deinit();
    const g = tg.game;
    var f = frameCtor();
    frameInit(g, &f, null, 4, 100, 50, 1, 2, 0, 0);
    try testing.expectEqual(@as(i16, 100), f.hitW);
    try testing.expectEqual(@as(i16, 50), f.hitH);
    try testing.expectEqual(@as(usize, 0), f.cells.len);
    try testing.expect(getCell(&f, 0) == null);
    g.fixes.encaixe_status_frame_cells = true;
    frameInit(g, &f, null, 4, 100, 50, 1, 2, 0, 0);
    defer g.gpa.free(f.cells);
    try testing.expectEqual(@as(usize, 4), f.cells.len);
    try testing.expect(getCell(&f, 3) != null);
}
