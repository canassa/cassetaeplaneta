//! Port unit `object_create` (module) of INV.EXE. constructors and destructors of the objects (Cannon, Saucer, Missile/Bomb/Shot, InvaderColumn and its cells, InvaderExplosion, Player2D/Actor2D/Mover/Animation, InvPanel/ControlPanel/Animated3D/Object3D, StatusBar, SceneObject) and frames.
//!
//! Each constructor chain is flattened onto one `Object` as in ENCAIXE: the
//! most-derived constructor of a complete object (`init_vbases`) resets it
//! to the field defaults (the original's uninitialised heap bytes) with the
//! `kind` set and takes the SceneObject's serial number (the original builds
//! the vbtables and vtables here); the base-part constructors then run with
//! `init_vbases = false`. Parameters follow DESIGN.md: `(g, obj, <source
//! order>, init_vbases)`, the Ghidra list reversed. INV's `/Od` build (like TIRO's) keeps
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

// @orig 1088:14a6 frame_get_cell
/// FrameVtbl slot 00 getCell: `cells + index * 8`. The original does not
/// check the index; one outside the array has no cell to name.
pub fn getCell(frame: *Frame, index: i16) ?*FrameCell {
    const i: usize = @as(u16, @bitCast(index));
    if (i >= frame.cells.len) return null;
    return &frame.cells[i];
}

// @orig 1088:361a frame_cell_ctor
/// Four words zeroed.
pub fn frameCellCtor() FrameCell {
    return .{ .raw = @splat(0) };
}

// @orig 1088:353c frame_ctor
/// vtbl = FrameVtbl, count = 0, dib = NULL (the other fields are
/// uninitialised in the original; the port zeroes them).
pub fn frameCtor() Frame {
    return .{};
}

// @orig 1088:3568 frame_init
/// Fills a strip record (a zero hit width/height defaults to the frame's)
/// and allocates `count` cells. Unlike ENCAIXE's (E4) INV reads the cell
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

// @orig 1088:17d4 scene_object_ctor
/// SceneObject base: vtbl and `id = g_nextId++`.
pub fn sceneObjectCtor(g: *Game, obj: *Object) void {
    obj.id = position.nextObjectId(g);
}

// @orig 1088:3c82 scene_object_dtor
/// Only stores the base vtable: TIRO's frees nothing (NOITE's frees the
/// strips).
pub fn sceneObjectDtor(obj: *Object) void {
    _ = obj;
}

// @orig 1088:3be0 scene_object_scalar_dtor
/// Scalar deleting destructor: the destructor, then `operator delete` of the
/// object when bit 0 of `flags` is set (the object must come from
/// `g.local()`). Returns `obj`.
pub fn sceneObjectScalarDtor(g: *Game, obj: *Object, flags: u16) *Object {
    sceneObjectDtor(obj);
    if (flags & 1 != 0) g.local().destroy(obj);
    return obj;
}

// @orig 1088:41a8 object3d_dtor
/// Empty.
pub fn object3dDtor(obj: *Object) void {
    _ = obj;
}

// @orig 1088:4292 animation_dtor
/// Empty.
pub fn animationDtor(obj: *Object) void {
    _ = obj;
}

// @orig 1088:4272 animated3d_dtor
/// Nothing of its own: chains to `animation_dtor`.
pub fn animated3dDtor(obj: *Object) void {
    animationDtor(obj);
}

// @orig 1088:266c object3d_ctor
/// Object3D (out of line here; ENCAIXE inlines it): with `init_vbases` the
/// SceneObject's constructor, then the Object3D vtables.
pub fn object3dCtor(g: *Game, obj: *Object, init_vbases: bool) void {
    begin(g, obj, init_vbases);
}

// @orig 1088:33be scene_object_init_strips
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

// @orig 1088:34fa scene_object_init_state
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

// @orig 1088:6300 animation_ctor
/// Animation base part (Actor2D's): only the vtables.
pub fn animationCtor(g: *Game, obj: *Object, init_vbases: bool) void {
    begin(g, obj, init_vbases);
}

// @orig 1088:6354 animation_ctor_strips_no_hitbox
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

// @orig 1088:605c animated3d_ctor_strips_no_hitbox
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

// @orig 1088:598c control_panel_ctor
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

// @orig 1088:545c inv_panel_ctor
/// InvPanel (kind `control_panel`; no own fields): the ControlPanel part
/// with the InvPanel tables installed over it. Unlike ENCAIXE's TetrisPanel
/// (E11) the arguments agree with the callee.
pub fn invPanelCtor(
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

// @orig 1088:6408 mover_ctor
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

// @orig 1088:5f92 actor2d_ctor_strips
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

// @orig 1088:58c6 player2d_ctor
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

// @orig 1088:562e cannon_ctor
/// Cannon (the player): the Player2D part with the Cannon tables (kind
/// `cannon`; `hitFrame` is left to the creator).
pub fn cannonCtor(
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
    obj.kind = .cannon;
    begin(g, obj, init_vbases);
    try player2dCtor(g, obj, x, y, count, paths, counts, widths, heights, hit_x, hit_y, hit_w, hit_h, timer_id, timer_period, step_x, step_y, visible, unk10, false);
}

// @orig 1088:6750 saucer_ctor
/// Saucer (kind `saucer`): the Actor2D part with the Saucer tables (a four-slot
/// Mover table), then `unk40 = 1`.
pub fn saucerCtor(
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
    obj.kind = .saucer;
    begin(g, obj, init_vbases);
    try actor2dCtorStrips(g, obj, x, y, count, paths, counts, widths, heights, hit_x, hit_y, hit_w, hit_h, timer_id, timer_period, step_x, step_y, visible, unk10, false);
    obj.saucer.unk40 = 1;
}

// @orig 1088:6abe missile_ctor
/// Missile (never built alone; the base of Bomb and Shot): the Actor2D part
/// with the Missile tables; its own fields are left to the creators.
pub fn missileCtor(
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

// @orig 1088:67ee bomb_ctor
/// Bomb (kind `bomb`): the Missile part with the Bomb tables.
pub fn bombCtor(
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
    obj.kind = .bomb;
    begin(g, obj, init_vbases);
    try missileCtor(g, obj, x, y, count, paths, counts, widths, heights, hit_x, hit_y, hit_w, hit_h, timer_id, timer_period, step_x, step_y, visible, unk10, false);
}

// @orig 1088:6886 shot_ctor
/// Shot (kind `shot`): the Missile part with the Shot tables.
pub fn shotCtor(
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
    obj.kind = .shot;
    begin(g, obj, init_vbases);
    try missileCtor(g, obj, x, y, count, paths, counts, widths, heights, hit_x, hit_y, hit_w, hit_h, timer_id, timer_period, step_x, step_y, visible, unk10, false);
}

// @orig 1068:122f invader_column_init_cells
/// Marks the five cells live: cell `i` gets x = the column's x and y =
/// `i * 44 + 60`. Original bug, kept (harmless): `set_cell` adds `44 * i`
/// again, so the initial cell y is `88 * i + 60`; the first formation step
/// (500 ms later) rewrites the cells.
pub fn invaderColumnInitCells(obj: *Object) void {
    var i: i16 = 0;
    while (i < 5) : (i += 1) {
        invaderColumnSetCell(obj, obj.x, i *% 0x2c +% 0x3c, i, 1);
    }
}

// @orig 1088:69d6 invader_column_set_cell
/// Writes cell `i` (6 bytes at +0x52 + 6i): x, `y + 44 * i`, alive. The
/// original does not check `i` (its callers pass 0..4); one outside the
/// array writes nothing here.
pub fn invaderColumnSetCell(obj: *Object, x: i16, y: i16, i: i16, alive: i16) void {
    const idx: usize = @as(u16, @bitCast(i));
    if (idx >= obj.invader.cells.len) return;
    const c = &obj.invader.cells[idx];
    c.x = x;
    c.y = i *% 0x2c +% y;
    c.alive = alive;
}

// @orig 1088:691e invader_column_ctor
/// InvaderColumn (kind `invader_column`): the Actor2D part with the
/// InvaderColumn tables, the five cells, then firstPass 1, landed 0,
/// lowestAlive -1, atEdge 0, direction 2 (right).
pub fn invaderColumnCtor(
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
    if (init_vbases) obj.kind = .invader_column;
    begin(g, obj, init_vbases);
    try actor2dCtorStrips(g, obj, x, y, count, paths, counts, widths, heights, hit_x, hit_y, hit_w, hit_h, timer_id, timer_period, step_x, step_y, visible, unk10, false);
    invaderColumnInitCells(obj);
    obj.invader.firstPass = 1;
    obj.invader.landed = 0;
    obj.invader.lowestAlive = -1;
    obj.invader.atEdge = 0;
    obj.invader.direction = 2;
}

// @orig 1088:6a26 invader_explosion_ctor
/// InvaderExplosion (kind `invader_explosion`): the InvaderColumn part (cells
/// and fields included, unused) with the explosion's tables.
pub fn invaderExplosionCtor(
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
    obj.kind = .invader_explosion;
    begin(g, obj, init_vbases);
    try invaderColumnCtor(g, obj, x, y, count, paths, counts, widths, heights, hit_x, hit_y, hit_w, hit_h, timer_id, timer_period, step_x, step_y, visible, unk10, false);
}

// @orig 1088:5800 scene_object_ctor_bmp
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

// @orig 1088:551c status_bar_ctor
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

// @orig 1088:3568 frame_init oracle=documented
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

// @orig 1068:122f invader_column_init_cells oracle=documented
test "init cells keeps the doubled 44 px offset" {
    var o: Object = .{ .kind = .invader_column };
    o.x = 40;
    invaderColumnInitCells(&o);
    try testing.expectEqual(@as(i16, 60), o.invader.cells[0].y);
    try testing.expectEqual(@as(i16, 60 + 88 * 4), o.invader.cells[4].y);
    try testing.expectEqual(@as(i16, 40), o.invader.cells[2].x);
    try testing.expectEqual(@as(i16, 1), o.invader.cells[3].alive);
}

// @orig 1088:6a26 invader_explosion_ctor oracle=documented
test "explosion ctor keeps its kind and the column's fields" {
    var tg = try TestGame.init(testing.allocator);
    defer tg.deinit();
    const g = tg.game;
    var o: Object = .{ .kind = .invader_explosion };
    const paths = [_][]const u8{"none.bmp"};
    const c = [_]i16{8};
    const w = [_]i16{88};
    const h = [_]i16{44};
    try invaderExplosionCtor(g, &o, 640, 480, 1, &paths, &c, &w, &h, 0, 0, 0, 0, 16, 55, 0, 0, 0, 0, true);
    try testing.expect(o.kind == .invader_explosion);
    try testing.expectEqual(@as(i16, 2), o.invader.direction);
    try testing.expectEqual(@as(i16, -1), o.invader.lowestAlive);
}
