//! Port unit `frames` (module). bitmap strips (Frame) and the non-virtual SceneObject strip/frame accessors.
//!
//! An object owns `frames: []Frame` (the original's counted array behind
//! `SceneObject+0x1c`, `stripCount` = `frames.len`). The strip's DIB is
//! owned by its `Frame` (the original's GlobalAlloc block); it is allocated
//! by `dib.loadDib` from `g.gpa` and released by `frameDtor`.
//!
//! The accessors index `frames[curStrip]` without a range check, like the
//! original; an object with no strips has nothing to read (the original
//! reads garbage), so there it is a panic.

const std = @import("std");
const dib_mod = @import("dib.zig");
const Game = @import("core/game.zig").Game;
const object = @import("core/object.zig");
const Object = object.Object;
const Frame = object.Frame;
const Dib = object.Dib;
const world = @import("core/world.zig");
const Backdrop = world.Backdrop;
const platform = @import("platform/platform.zig");
const cstr = @import("core/cstr.zig");

pub const Error = dib_mod.Error;

// @orig 1010:11b8 frame_ctor
/// Default constructor: no frames, no bitmap. (The other fields are
/// uninitialised in the original; the port zeroes them.)
pub fn frameCtor() Frame {
    return .{};
}

// @orig 1010:11e0 frame_init
/// Fills a strip record; a zero hit width/height defaults to the frame's.
pub fn frameInit(f: *Frame, d: ?*Dib, count: i16, w: i16, h: i16, hit_x: i16, hit_y: i16, hit_w: i16, hit_h: i16) void {
    f.dib = d;
    f.count = count;
    f.width = w;
    f.height = h;
    f.hitX = hit_x;
    f.hitY = hit_y;
    f.hitW = if (hit_w == 0) w else hit_w;
    f.hitH = if (hit_h == 0) h else hit_h;
}

// @orig 1010:1258 frame_dtor
/// Releases the strip's DIB (GlobalUnlock + GlobalFree). The original leaves
/// `dib` dangling; the port clears it so a second call is harmless.
pub fn frameDtor(g: *Game, f: *Frame) void {
    if (f.dib) |d| {
        g.gpa.free(d.bits);
        g.gpa.destroy(d);
        f.dib = null;
    }
}

// @orig 1010:1298 frame_cell_x
/// x of frame `index` inside the strip bitmap: frames are stacked vertically.
pub fn frameCellX(f: *const Frame, index: i16) i16 {
    _ = f;
    _ = index;
    return 0;
}

// @orig 1010:12a4 frame_cell_y
/// y of frame `index` inside the strip bitmap (16-bit product).
pub fn frameCellY(f: *const Frame, index: i16) i16 {
    return f.height *% index;
}

// @orig 1010:7668 frame_vector_dtor
/// The vector deleting destructor as `scene_object_dtor` uses it (flags 3):
/// destroys every strip and frees the array.
pub fn frameVectorDtor(g: *Game, obj: *Object) void {
    for (obj.frames) |*f| frameDtor(g, f);
    if (obj.frames.len != 0) g.gpa.free(obj.frames);
    obj.frames = &.{};
}

// @orig 1010:7710 frame_vector_dtor_huge (absorbed)
// Only reached with flags bit 4, which no caller sets.

// @orig 1010:1456 scene_object_cur_strip
/// The object's current frame strip.
pub fn curStrip(obj: *const Object) *Frame {
    return &obj.frames[@as(u16, @bitCast(obj.curStrip))];
}

// @orig 1010:1474 scene_object_dib
/// The DIB of the current strip.
pub fn dib(obj: *const Object) ?*Dib {
    return curStrip(obj).dib;
}

// @orig 1010:1498 scene_object_width
pub fn width(obj: *const Object) i16 {
    return curStrip(obj).width;
}

// @orig 1010:14b6 scene_object_height
pub fn height(obj: *const Object) i16 {
    return curStrip(obj).height;
}

// @orig 1010:14d6 scene_object_hit_w
pub fn hitW(obj: *const Object) i16 {
    return curStrip(obj).hitW;
}

// @orig 1010:14f6 scene_object_hit_h
pub fn hitH(obj: *const Object) i16 {
    return curStrip(obj).hitH;
}

// @orig 1010:1516 scene_object_hit_x
pub fn hitX(obj: *const Object) i16 {
    return curStrip(obj).hitX;
}

// @orig 1010:1536 scene_object_hit_y
pub fn hitY(obj: *const Object) i16 {
    return curStrip(obj).hitY;
}

// @orig 1010:1556 scene_object_frame_count
pub fn frameCount(obj: *const Object) i16 {
    return curStrip(obj).count;
}

// @orig 1010:1576 scene_object_reset_rects
/// Dirty and clip rectangles := the whole frame of the current strip.
pub fn resetRects(obj: *Object) void {
    obj.dirty.left = 0;
    obj.clip.left = 0;
    obj.dirty.top = 0;
    obj.clip.top = 0;
    const w = width(obj);
    obj.dirty.right = w;
    obj.clip.right = w;
    const h = height(obj);
    obj.dirty.bottom = h;
    obj.clip.bottom = h;
}

// @orig 1010:afa2 scene_object_frame_src_x
/// x of the current frame inside the current strip's bitmap.
pub fn frameSrcX(obj: *const Object) i16 {
    return frameCellX(curStrip(obj), obj.curFrame);
}

// @orig 1010:afca scene_object_frame_src_y
/// y of the current frame inside the current strip's bitmap.
pub fn frameSrcY(obj: *const Object) i16 {
    return frameCellY(curStrip(obj), obj.curFrame);
}

// @orig 1010:aff2 next_object_id
/// The next serial number for a new object (`g_nextId`, wrapping).
pub fn nextObjectId(g: *Game) i16 {
    const id = g.nextId;
    g.nextId +%= 1;
    return id;
}

/// The prologue shared by the four init functions below.
fn initCommon(g: *Game, obj: *Object) void {
    obj.sceneName[0] = 0;
    obj.id = nextObjectId(g);
    obj.unk492 = 0;
    obj.rleMode = 0;
}

fn allocFrames(g: *Game, obj: *Object, count: i16) Error!void {
    if (count == 0) return;
    const frames = g.gpa.alloc(Frame, @as(u16, @bitCast(count))) catch return error.LimitExceeded;
    for (frames) |*f| f.* = frameCtor();
    obj.frames = frames;
}

// @orig 1010:1d4e scene_object_init_strips
/// Constructor helper: new serial number, then `count` strips, strip `i`
/// loaded from the bitmap `paths[i]` with `counts[i]`, `widths[i]`,
/// `heights[i]` and one shared hit box. A bitmap that is not found leaves
/// that strip's `dib` null (no message, unlike `initStrip`). The arrays
/// must hold `count` entries (the original reads past them unchecked).
pub fn initStrips(
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
    initCommon(g, obj);
    const n: u16 = @bitCast(count);
    if (paths.len < n or counts.len < n or widths.len < n or heights.len < n) return error.LimitExceeded;
    try allocFrames(g, obj, count);
    var i: u16 = 0;
    while (i < n) : (i += 1) {
        const d = try dib_mod.loadDib(g.gpa, g.plat, g.fixes, &g.dibPathBuf, &g.driveCD, paths[i]);
        frameInit(&obj.frames[i], d, counts[i], widths[i], heights[i], hit_x, hit_y, hit_w, hit_h);
    }
}

// @orig 1010:1eb2 scene_object_init_strip
/// Constructor helper: new serial number and one strip loaded from the
/// bitmap `path`. If it cannot be opened the original shows an "Erro
/// Fatal!!" box and carries on with a null `dib`.
pub fn initStrip(
    g: *Game,
    obj: *Object,
    path: []const u8,
    count: i16,
    w: i16,
    h: i16,
    hit_x: i16,
    hit_y: i16,
    hit_w: i16,
    hit_h: i16,
) Error!void {
    initCommon(g, obj);
    try allocFrames(g, obj, 1);
    const d = try dib_mod.loadDib(g.gpa, g.plat, g.fixes, &g.dibPathBuf, &g.driveCD, path);
    if (d == null) {
        // message_box_printf("Erro Fatal!!", "N\xe3o foi poss\xedvel abrir o arquivo: %s", path);
        // The shared 100-byte buffer is unchecked in the original.
        const text = "N\xe3o foi poss\xedvel abrir o arquivo: ";
        const p = cstr.slice(path);
        if (text.len + p.len >= g.messageBuf.len) return error.LimitExceeded;
        const msg = cstr.print(&g.messageBuf, "{s}{s}", .{ text, p });
        _ = g.plat.messageBox("Erro Fatal!!", msg, platform.mb.iconexclamation);
    }
    frameInit(&obj.frames[0], d, count, w, h, hit_x, hit_y, hit_w, hit_h);
}

// @orig 1010:1f8a scene_object_alloc_strips
/// Constructor helper: new serial number and `count` empty strips.
pub fn allocStrips(g: *Game, obj: *Object, count: i16) Error!void {
    initCommon(g, obj);
    try allocFrames(g, obj, count);
}

// @orig 1010:202e scene_object_init_state
/// Constructor helper: new serial number, position, initial visibility,
/// first strip and frame, not attached.
pub fn initState(g: *Game, obj: *Object, x: i16, y: i16, visible: i16, unk10: u16) void {
    initCommon(g, obj);
    obj.x = x;
    obj.y = y;
    obj.unk10 = unk10;
    obj.visible = visible;
    obj.attached = 0;
    obj.curStrip = 0;
    obj.curFrame = 0;
}

// @orig 1010:e2a2 scene_object_set_strip
/// Switches to strip `strip` (if it exists) at its first frame, without
/// redrawing; returns the current strip. `bd` is never read.
pub fn setStrip(obj: *Object, strip: i16, bd: *Backdrop) *Frame {
    _ = bd;
    if (@as(u16, @bitCast(strip)) < obj.frames.len) {
        obj.curStrip = strip;
        obj.curFrame = 0;
    }
    return curStrip(obj);
}

// @orig 1018:c5f4 scene_object_set_cur_frame
/// Sets the current frame of the current strip if in range (no redraw);
/// returns the requested frame.
pub fn setCurFrame(obj: *Object, frame: u16) u16 {
    if (frame < @as(u16, @bitCast(curStrip(obj).count))) obj.curFrame = @bitCast(frame);
    return frame;
}
