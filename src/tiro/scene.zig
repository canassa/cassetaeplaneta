//! Port unit `scene` (module) of TIRO.EXE. Scene methods (SceneVtbl 01-04 06 08-0C), ctors, scene_create and the destructor, exits.
//!
//! The same source as ENCAIXE's `scene` unit, except: one backdrop bitmap
//! (blitToDc/clearView/drawBackground call the backdrop unit's out-of-line
//! functions), out-of-line ctors, the scalar deleting destructor, and
//! `exit_set_link` as its own function. Objects and the scene come from
//! `g.local()` (the original's `operator new`).

const std = @import("std");
const cstr = @import("../core/cstr.zig");
const lists = @import("lists.zig");
const backdrop = @import("backdrop.zig");
const object_create = @import("object_create.zig");
const gallery = @import("gallery.zig");
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
    return scene.backdrop orelse @panic("tiro.scene: no backdrop");
}

/// Scene base constructor: the 30-entry object list, the name (19 chars
/// at most, strncpy pads with NULs), the counters and flags. Parameters 2-5
/// of the original are unused and dropped. (Slot 0 is `_purecall`; the
/// vtable has no counterpart.)
// @orig 1088:5390 scene_ctor
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
    scene.mayDropObject = 0;
    scene.sceneNumber = 0;
    return scene;
}

/// TiroScene constructor: the base one with no status bar, no control
/// panel, a player. The original's other parameters are unused.
// @orig 1088:5004 tiro_scene_ctor
pub fn tiroSceneCtor(scene: *Scene, name: []const u8) *Scene {
    _ = ctor(scene, 0, 0, 1, name);
    return scene;
}

/// SceneVtbl slot 01 getHasPlayer.
// @orig 1088:5400 scene_get_has_player
pub fn getHasPlayer(g: *Game, scene: *Scene) bool {
    _ = g;
    return scene.hasPlayer != 0;
}

/// SceneVtbl slot 02 getHasControlPanel.
// @orig 1088:541c scene_get_has_control_panel
pub fn getHasControlPanel(g: *Game, scene: *Scene) bool {
    _ = g;
    return scene.hasControlPanel != 0;
}

/// SceneVtbl slot 03 getHasStatusBar.
// @orig 1088:5438 scene_get_has_status_bar
pub fn getHasStatusBar(g: *Game, scene: *Scene) bool {
    _ = g;
    return scene.hasStatusBar != 0;
}

/// SceneVtbl slot 04 addObject: links the object into the scene's list and
/// inserts its Object3D part (null for a non-3D object) into the draw list.
// @orig 1060:00b9 scene_add_object
pub fn addObject(g: *Game, scene: *Scene, obj: *Object) void {
    _ = lists.add(&scene.objects, obj);
    _ = lists.drawInsert(g, bdOf(scene), obj.as(.object3d));
}

/// SceneVtbl slot 06 createNewScene (default only: "Faltou redefinir…",
/// caption: the scene name). Returns the scene.
// @orig 1088:5482 scene_create_new_scene_default (absorbed)
pub fn createNewScene(g: *Game, scene: *Scene, exit_index: i16) ?*Scene {
    _ = exit_index;
    position.messageBoxPrintf(g, cstr.slice(&scene.name), "Faltou redefinir o m\xe9todo CreateNewScene", 0);
    return scene;
}

/// SceneVtbl slot 08 blitToDc (hdc dropped): the backdrop's blit.
// @orig 1088:54ae scene_blit_to_dc
pub fn blitToDc(g: *Game, scene: *Scene) *Scene {
    backdrop.blitToDc(g, bdOf(scene));
    return scene;
}

/// SceneVtbl slot 09 clearView.
// @orig 1088:54d4 scene_clear_view
pub fn clearView(g: *Game, scene: *Scene) *Scene {
    _ = g;
    backdrop.clear(bdOf(scene));
    return scene;
}

/// SceneVtbl slot 0A drawBackground. The original ignores the copy's
/// result; its errors (memory corruption there) panic.
// @orig 1088:54f8 scene_draw_background
pub fn drawBackground(g: *Game, scene: *Scene) *Scene {
    backdrop.drawBackground(g, bdOf(scene)) catch |e| @panic(@errorName(e));
    return scene;
}

/// The exit's link, stored in the object's bitmap-header area (the Exit
/// class has its own layout in the original): playerX in the high word of
/// biWidth, playerY in the low word of biHeight, the condition in the low
/// word of biCompression, the exit index in its high word, 0 in the high
/// word of biSizeImage. The condition pointer has no representation there:
/// only whether it is set is kept.
// @orig 1088:6002 exit_set_link
pub fn exitSetLink(ex: *Object, condition: ?*Condition, exit_index: i16, player_y: i16, player_x: i16) *Object {
    const h = &ex.bmiHeader;
    h.biWidth = (h.biWidth & 0xffff) | (@as(i32, player_x) << 16);
    h.biHeight = (h.biHeight & ~@as(i32, 0xffff)) | @as(i32, @as(u16, @bitCast(player_y)));
    h.biCompression = (@as(u32, @as(u16, @bitCast(exit_index))) << 16) | @intFromBool(condition != null);
    h.biSizeImage &= 0xffff;
    return ex;
}

/// SceneVtbl slot 0B addExit (scene_add_exit_at): no bounds check in the
/// original; the table has 10 entries, an overflow panics.
// @orig 1060:00fa scene_add_exit_at
pub fn addExit(g: *Game, scene: *Scene, ex: *Object, player_x: i16, player_y: i16, condition: ?*Condition) i16 {
    _ = g;
    const idx = scene.exitCount;
    _ = exitSetLink(ex, condition, idx, player_y, player_x);
    if (idx < 0 or idx >= world.max_exits) @panic("tiro.scene: exit table overflow");
    scene.exits[@intCast(idx)] = ex;
    scene.exitCount +%= 1;
    return idx;
}

/// SceneVtbl slot 0C getExit: `exits[index]` when `index < exitCount`.
// @orig 1088:551c scene_get_exit
pub fn getExit(g: *Game, scene: *Scene, index: i16) ?*Object {
    _ = g;
    if (index < scene.exitCount) {
        if (index < 0) @panic("tiro.scene.getExit: negative index");
        return scene.exits[@intCast(index)];
    }
    return null;
}

/// The base Scene's slot 07 `create` (TiroScene's runs it after its own
/// work): builds the backdrop through slot 05 (`gallery.createScreen`),
/// creates it (hwnd dropped) and points it at the scene's object list.
// @orig 1060:0000 scene_create
pub fn create(g: *Game, scene: *Scene) *Scene {
    scene.backdrop = gallery.createScreen(g, scene);
    _ = backdrop.create(g, bdOf(scene));
    bdOf(scene).sceneList = &scene.objects;
    return scene;
}

/// The base Scene's destructor: removes each object from the game's draw
/// list and deletes it (`scene_object_scalar_dtor(obj, 1)`), then deletes
/// the backdrop (`backdrop_delete(bd, 1)`: its destructor, then the memory).
// @orig 1060:003b scene_dtor
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
// @orig 1088:3f58 scene_scalar_dtor
pub fn scalarDtor(g: *Game, scene: *Scene, flags: u16) *Scene {
    dtor(g, scene);
    if (flags & 1 != 0) g.local().destroy(scene);
    return scene;
}

test "scene ctor and exits" {
    var s: Scene = .{};
    _ = tiroSceneCtor(&s, "a-very-long-scene-name-over-19");
    try std.testing.expectEqualStrings("a-very-long-scene-n", cstr.slice(&s.name));
    try std.testing.expect(s.hasPlayer == 1 and s.objects.capacity == 30);
    var g: Game = undefined;
    var o: Object = .{ .kind = .crossbow };
    try std.testing.expectEqual(@as(i16, 0), addExit(&g, &s, &o, 3, 4, null));
    try std.testing.expect(getExit(&g, &s, 0) == &o);
    try std.testing.expect(getExit(&g, &s, 1) == null);
    try std.testing.expectEqual(@as(i32, 3 << 16), o.bmiHeader.biWidth);
}
