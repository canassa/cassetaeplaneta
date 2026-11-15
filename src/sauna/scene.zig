//! Port unit `scene` (module) of SAUNA.EXE. Scene methods (SceneVtbl 01-04 06
//! 08-0F: the four add-exit variants), ctors (SaunaScene's: the four ghosts
//! and the two dots), scene_create and the destructors, exits.
//!
//! The same source as TIRO's `scene` unit (draw list included), except: the
//! base ctor sets `mayDropObject` and `handlerEnabled` (and leaves
//! `sceneNumber`), `scene_create` enables the handler, SAUNA has three more
//! add-exit variants (NOITE's shape: the exit's link is set by the
//! `exit_set_*` functions, then it is appended to the exit table; no Exit
//! object is ever built, so the link is kept in the bitmap-header area as in
//! TIRO), and the SaunaScene ctor builds the four ghosts and the two dots.
//! Objects and the scene come from `g.local()` (the original's
//! `operator new`).

const std = @import("std");
const cstr = @import("../core/cstr.zig");
const lists = @import("lists.zig");
const backdrop = @import("backdrop.zig");
const object_create = @import("object_create.zig");
const maze = @import("maze.zig");
const position = @import("behaviour/position.zig");
const Game = @import("core/game.zig").Game;
const object = @import("core/object.zig");
const Object = object.Object;
const world = @import("core/world.zig");
const Backdrop = world.Backdrop;
const Scene = world.Scene;
const Condition = world.Condition;

/// The scene's backdrop (the original dereferences it unchecked).
fn bdOf(scene: *Scene) *Backdrop {
    return scene.backdrop orelse @panic("sauna.scene: no backdrop");
}

/// Scene base constructor: the 30-entry object list, the name (19 chars
/// at most, strncpy pads with NULs), the counters and flags. Parameters 2-5
/// of the original are unused and dropped. `mayDropObject` is 1,
/// `handlerEnabled` 0 (`scene_create` sets it); `sceneNumber` is not
/// written. (The vtable store has no counterpart.)
// @orig 10a0:934e scene_ctor
pub fn ctor(scene: *Scene, has_status_bar: i16, has_control_panel: i16, has_player: i16, name: []const u8) *Scene {
    _ = lists.ctor(&scene.objects, 0x1e);
    @memset(scene.name[0..0x13], 0);
    cstr.copy(&scene.name, name);
    scene.name[0x13] = 0;
    scene.exitCount = 0;
    scene.hasPlayer = has_player;
    scene.hasStatusBar = has_status_bar;
    scene.hasControlPanel = has_control_panel;
    scene.is1Animation = 0;
    scene.isClickExit = 0;
    scene.animation = null;
    scene.mayDropObject = 1;
    scene.handlerEnabled = 0;
    return scene;
}

/// SaunaScene constructor: the base one (no status bar, a control panel, a
/// player), then the four ghosts (all with the same arguments: home (300,
/// 230), 16 x 16 steps, timer 0x11 every 55 ms, hit box 24 x 24 at (8, 8),
/// the first 8 ghost strips) and the peanut and cork dots (also `g_peanut`
/// and `g_cork`). The original's other parameters are unused.
// @orig 1080:2aca sauna_scene_ctor
pub fn saunaSceneCtor(g: *Game, scene: *Scene, name: []const u8) object_create.Error!*Scene {
    _ = ctor(scene, 0, 1, 1, name);
    for (&scene.ghosts) |*slot| {
        const ghost = try g.local().create(Object);
        ghost.* = .{ .kind = .ghost };
        try object_create.ghostCtor(
            g,
            ghost,
            300,
            230,
            8,
            g.ghostStripFiles[0..8],
            g.ghostStripFrames[0..8],
            g.ghostStripWidths[0..8],
            g.ghostStripHeights[0..8],
            8,
            8,
            0x18,
            0x18,
            0x11,
            0x37,
            0x10,
            0x10,
            1,
            0,
            true,
        );
        slot.* = ghost;
    }
    const peanut = try g.local().create(Object);
    peanut.* = .{ .kind = .dot };
    try object_create.sceneObjectCtorBmp(g, peanut, 0x14, 0x14, "3o1amend.bmp", 1, 0x14, 0xc, 0, 0);
    scene.peanut = peanut;
    g.peanut = peanut;
    const cork = try g.local().create(Object);
    cork.* = .{ .kind = .dot };
    try object_create.sceneObjectCtorBmp(g, cork, 0x14, 0x14, "3o1rolha.bmp", 1, 0x14, 0x19, 0, 0);
    scene.cork = cork;
    g.cork = cork;
    return scene;
}

/// SceneVtbl slot 01 getHasPlayer.
// @orig 10a0:8db0 scene_get_has_player
pub fn getHasPlayer(g: *Game, scene: *Scene) bool {
    _ = g;
    return scene.hasPlayer != 0;
}

/// SceneVtbl slot 02 getHasControlPanel.
// @orig 10a0:8dce scene_get_has_control_panel
pub fn getHasControlPanel(g: *Game, scene: *Scene) bool {
    _ = g;
    return scene.hasControlPanel != 0;
}

/// SceneVtbl slot 03 getHasStatusBar.
// @orig 10a0:8dec scene_get_has_status_bar
pub fn getHasStatusBar(g: *Game, scene: *Scene) bool {
    _ = g;
    return scene.hasStatusBar != 0;
}

/// SceneVtbl slot 04 addObject: links the object into the scene's list and
/// inserts its Object3D part (null for a non-3D object) into the draw list.
// @orig 1060:014d scene_add_object
pub fn addObject(g: *Game, scene: *Scene, obj: *Object) void {
    _ = lists.add(&scene.objects, obj);
    _ = lists.drawInsert(g, bdOf(scene), obj.as(.object3d));
}

/// SceneVtbl slot 06 createNewScene (default only: "Faltou redefinir…",
/// caption: the scene name). Returns the scene.
// @orig 10a0:8e48 scene_create_new_scene_default (absorbed)
pub fn createNewScene(g: *Game, scene: *Scene, exit_index: i16) ?*Scene {
    _ = exit_index;
    position.messageBoxPrintf(g, cstr.slice(&scene.name), "Faltou redefinir o m\xe9todo CreateNewScene", 0);
    return scene;
}

/// SceneVtbl slot 08 blitToDc (hdc dropped): the backdrop's blit.
// @orig 10a0:8e82 scene_blit_to_dc
pub fn blitToDc(g: *Game, scene: *Scene) *Scene {
    backdrop.blitToDc(g, bdOf(scene));
    return scene;
}

/// SceneVtbl slot 09 clearView.
// @orig 10a0:8eb2 scene_clear_view
pub fn clearView(g: *Game, scene: *Scene) *Scene {
    _ = g;
    backdrop.clear(bdOf(scene));
    return scene;
}

/// SceneVtbl slot 0A drawBackground. The original ignores the copy's
/// result; its errors (memory corruption there) panic.
// @orig 10a0:8ede scene_draw_background
pub fn drawBackground(g: *Game, scene: *Scene) *Scene {
    backdrop.drawBackground(g, bdOf(scene)) catch |e| @panic(@errorName(e));
    return scene;
}

fn setLo(v: *i32, w: i16) void {
    v.* = (v.* & ~@as(i32, 0xffff)) | @as(i32, @as(u16, @bitCast(w)));
}

fn setHi(v: *i32, w: i16) void {
    v.* = (v.* & 0xffff) | (@as(i32, w) << 16);
}

fn setHiU(v: *u32, w: u16) void {
    v.* = (v.* & 0xffff) | (@as(u32, w) << 16);
}

/// The exit's link. The Exit class has its own layout in the original (no
/// SAUNA struct, never instantiated); it is kept in the object's
/// bitmap-header area: playerX (+0x2a) in the low word of biWidth, playerY
/// (+0x2c) in its high word, the exit index (+0x3c) in the high word of
/// biSizeImage, the condition (+0x38) as whether it is set in the high word
/// of biCompression, 0 (+0x40) in the high word of biXPelsPerMeter.
// @orig 10a0:8c60 exit_set_link
pub fn exitSetLink(ex: *Object, condition: ?*Condition, exit_index: i16, player_y: i16, player_x: i16) *Object {
    const h = &ex.bmiHeader;
    setLo(&h.biWidth, player_x);
    setHi(&h.biWidth, player_y);
    setHiU(&h.biCompression, @intFromBool(condition != null));
    setHiU(&h.biSizeImage, @bitCast(exit_index));
    setHi(&h.biXPelsPerMeter, 0);
    return ex;
}

/// `exitSetLink` plus the target scene name (19 chars at +0x16, a NUL at
/// +0x29): the name overlaps other fields of the object and has no
/// representation, so it is dropped.
// @orig 10a0:8cb4 exit_set_link_to_scene
pub fn exitSetLinkToScene(ex: *Object, condition: ?*Condition, exit_index: i16, player_y: i16, player_x: i16, scene_name: []const u8) *Object {
    _ = scene_name;
    return exitSetLink(ex, condition, exit_index, player_y, player_x);
}

/// The alternative target: the name (dropped as above), the position (over
/// playerX/playerY: +0x2a, +0x2c) and the alternative exit index (+0x44, the
/// high word of biYPelsPerMeter).
// @orig 10a0:8d2c exit_set_alt_link
pub fn exitSetAltLink(ex: *Object, alt_exit_index: i16, alt_y: i16, alt_x: i16, alt_scene_name: []const u8) *Object {
    _ = alt_scene_name;
    const h = &ex.bmiHeader;
    setLo(&h.biWidth, alt_x);
    setHi(&h.biWidth, alt_y);
    setHi(&h.biYPelsPerMeter, alt_exit_index);
    return ex;
}

/// Stores the exit index (+0x3c, the high word of biSizeImage).
// @orig 10a0:8d8a exit_set_exit_index
pub fn exitSetExitIndex(ex: *Object, exit_index: i16) *Object {
    setHiU(&ex.bmiHeader.biSizeImage, @bitCast(exit_index));
    return ex;
}

/// Appends `ex` to the exit table and returns its index. No bounds check in
/// the original; the table has 10 entries, an overflow panics.
fn append(scene: *Scene, ex: *Object) i16 {
    const idx = scene.exitCount;
    if (idx < 0 or idx >= world.max_exits) @panic("sauna.scene: exit table overflow");
    scene.exits[@intCast(idx)] = ex;
    scene.exitCount +%= 1;
    return idx;
}

/// SceneVtbl slot 0B addExit (scene_add_exit): the exit's index is set to
/// the next one, then it is appended.
// @orig 1060:026a scene_add_exit
pub fn addExit(g: *Game, scene: *Scene, ex: *Object) i16 {
    _ = g;
    _ = exitSetExitIndex(ex, scene.exitCount);
    return append(scene, ex);
}

/// SceneVtbl slot 0C addExitToScene (scene_add_exit_to_scene).
// @orig 1060:0206 scene_add_exit_to_scene
pub fn addExitToScene(g: *Game, scene: *Scene, ex: *Object, scene_name: []const u8, player_x: i16, player_y: i16, condition: ?*Condition) i16 {
    _ = g;
    _ = exitSetLinkToScene(ex, condition, scene.exitCount, player_y, player_x, scene_name);
    return append(scene, ex);
}

/// SceneVtbl slot 0D addExitAt (scene_add_exit_at).
// @orig 1060:01a8 scene_add_exit_at
pub fn addExitAt(g: *Game, scene: *Scene, ex: *Object, player_x: i16, player_y: i16, condition: ?*Condition) i16 {
    _ = g;
    _ = exitSetLink(ex, condition, scene.exitCount, player_y, player_x);
    return append(scene, ex);
}

/// SceneVtbl slot 0E addExitAlt (scene_add_exit_alt).
// @orig 1060:02b6 scene_add_exit_alt
pub fn addExitAlt(g: *Game, scene: *Scene, ex: *Object, alt_scene_name: []const u8, alt_x: i16, alt_y: i16) i16 {
    _ = g;
    _ = exitSetAltLink(ex, scene.exitCount, alt_y, alt_x, alt_scene_name);
    return append(scene, ex);
}

/// SceneVtbl slot 0F getExit: `exits[index]` when `index < exitCount`.
// @orig 10a0:8f0a scene_get_exit
pub fn getExit(g: *Game, scene: *Scene, index: i16) ?*Object {
    _ = g;
    if (index < scene.exitCount) {
        if (index < 0) @panic("sauna.scene.getExit: negative index");
        return scene.exits[@intCast(index)];
    }
    return null;
}

/// The base Scene's slot 07 `create` (SaunaScene's runs it after its own
/// work): builds the backdrop through slot 05 (`maze.createScreen`), creates
/// it (hwnd dropped), points it at the scene's object list and enables the
/// per-scene handler.
// @orig 1060:0000 scene_create
pub fn create(g: *Game, scene: *Scene) *Scene {
    scene.backdrop = maze.createScreen(g, scene);
    _ = backdrop.create(g, bdOf(scene));
    bdOf(scene).sceneList = &scene.objects;
    scene.handlerEnabled = 1;
    return scene;
}

/// The base Scene's destructor: removes each object from the game's draw
/// list and deletes it (`scene_object_scalar_dtor(obj, 1)`), then deletes
/// the backdrop (`backdrop_scalar_dtor(bd, 1)`: its destructor, then the
/// memory).
// @orig 1060:0075 scene_dtor
pub fn dtor(g: *Game, scene: *Scene) void {
    var cur = scene.objects.head;
    while (cur) |o| {
        lists.drawRemove(&g.drawList, o.as(.object3d));
        cur = o.next;
        _ = object_create.sceneObjectScalarDtor(g, o, 1);
    }
    if (scene.backdrop) |bd| {
        _ = backdrop.delete(g, bd, 1);
        g.local().destroy(bd);
    }
}

/// Scalar deleting destructor: `dtor`, then `operator delete` of the scene
/// when bit 0 of `flags` is set. Returns the scene.
// @orig 10a0:6198 scene_scalar_dtor
pub fn scalarDtor(g: *Game, scene: *Scene, flags: u16) *Scene {
    dtor(g, scene);
    if (flags & 1 != 0) g.local().destroy(scene);
    return scene;
}

test "scene ctor and exits" {
    var s: Scene = .{};
    _ = ctor(&s, 0, 1, 1, "a-very-long-scene-name-over-19");
    try std.testing.expectEqualStrings("a-very-long-scene-n", cstr.slice(&s.name));
    try std.testing.expect(s.hasPlayer == 1 and s.objects.capacity == 30 and s.mayDropObject == 1);
    var g: Game = undefined;
    var o: Object = .{ .kind = .ghost };
    try std.testing.expectEqual(@as(i16, 0), addExitAt(&g, &s, &o, 3, 4, null));
    try std.testing.expect(getExit(&g, &s, 0) == &o);
    try std.testing.expect(getExit(&g, &s, 1) == null);
    try std.testing.expectEqual(@as(i32, 3 | (4 << 16)), o.bmiHeader.biWidth);
}
