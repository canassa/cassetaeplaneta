//! Port unit `scene` (module) of INFERNO.EXE. Scene methods (SceneVtbl 01-04
//! 06 08-0C), ctors (InfernoScene's too), scene_create and the destructors,
//! exits.
//!
//! The same source as TIRO's `scene` unit, except: no draw list (addObject
//! only links the object into the scene's list; the destructor does not
//! delete the objects), the scene base ctor has no extra fields, and
//! `exit_set_link` writes INFERNO's SceneObject fields. Objects and the
//! scene come from `g.local()` (the original's `operator new`).

const std = @import("std");
const cstr = @import("../core/cstr.zig");
const lists = @import("lists.zig");
const backdrop = @import("backdrop.zig");
const hell = @import("hell.zig");
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
    return scene.backdrop orelse @panic("inferno.scene: no backdrop");
}

/// Scene base constructor: the 30-entry object list, the name (19 chars
/// at most, strncpy pads with NULs), the counters and flags. Parameters 2-5
/// of the original are unused and dropped. (Slot 0 is `_purecall`; the
/// vtable has no counterpart.)
// @orig 1080:74ce scene_ctor
pub fn ctor(scene: *Scene, has_status_bar: i16, has_control_panel: i16, has_player: i16, name: []const u8) *Scene {
    _ = lists.ctor(&scene.objects, null);
    @memset(scene.name[0..0x13], 0);
    cstr.copy(&scene.name, name);
    scene.name[0x13] = 0;
    scene.exitCount = 0;
    scene.hasPlayer = has_player;
    scene.hasStatusBar = has_status_bar;
    scene.hasControlPanel = has_control_panel;
    return scene;
}

/// InfernoScene constructor: the base one with no status bar, no control
/// panel, a player. The original's other parameters are unused.
// @orig 1080:72ce inferno_scene_ctor
pub fn infernoSceneCtor(scene: *Scene, name: []const u8) *Scene {
    _ = ctor(scene, 0, 0, 1, name);
    return scene;
}

/// SceneVtbl slot 01 getHasPlayer.
// @orig 1080:6334 scene_get_has_player
pub fn getHasPlayer(g: *Game, scene: *Scene) bool {
    _ = g;
    return scene.hasPlayer != 0;
}

/// SceneVtbl slot 02 getHasControlPanel.
// @orig 1080:6352 scene_get_has_control_panel
pub fn getHasControlPanel(g: *Game, scene: *Scene) bool {
    _ = g;
    return scene.hasControlPanel != 0;
}

/// SceneVtbl slot 03 getHasStatusBar.
// @orig 1080:6370 scene_get_has_status_bar
pub fn getHasStatusBar(g: *Game, scene: *Scene) bool {
    _ = g;
    return scene.hasStatusBar != 0;
}

/// SceneVtbl slot 04 addObject: links the object into the scene's list.
// @orig 1080:638e scene_add_object
pub fn addObject(g: *Game, scene: *Scene, obj: *Object) void {
    _ = g;
    _ = lists.add(&scene.objects, obj);
}

/// SceneVtbl slot 06 createNewScene (default only: "Faltou redefinir…",
/// caption: the scene name). Returns the scene.
// @orig 1080:63f6 scene_create_new_scene_default (absorbed)
pub fn createNewScene(g: *Game, scene: *Scene, exit_index: i16) ?*Scene {
    _ = exit_index;
    position.messageBoxPrintf(g, cstr.slice(&scene.name), "Faltou redefinir o m\xe9todo CreateNewScene", 0);
    return scene;
}

/// SceneVtbl slot 08 blitToDc (hdc dropped): the backdrop's blit.
// @orig 1080:642c scene_blit_to_dc
pub fn blitToDc(g: *Game, scene: *Scene) *Scene {
    backdrop.blitToDc(g, bdOf(scene));
    return scene;
}

/// SceneVtbl slot 09 clearView.
// @orig 1080:645c scene_clear_view
pub fn clearView(g: *Game, scene: *Scene) *Scene {
    _ = g;
    backdrop.clear(bdOf(scene));
    return scene;
}

/// SceneVtbl slot 0A drawBackground. The original ignores the copy's
/// result; its errors (memory corruption there) panic.
// @orig 1080:6488 scene_draw_background
pub fn drawBackground(g: *Game, scene: *Scene) *Scene {
    backdrop.drawBackground(g, bdOf(scene)) catch |e| @panic(@errorName(e));
    return scene;
}

/// The exit's link: playerX (+0x12), playerY (+0x14), the condition
/// (+0x16, far pointer to +0x18), the exit index (+0x1a), 0 at +0x1e. The
/// condition pointer has no representation in the object: `id` keeps only
/// whether it is set, `unk18[0]` (its segment word) is cleared.
// @orig 1080:866c exit_set_link
pub fn exitSetLink(ex: *Object, condition: ?*Condition, exit_index: i16, player_y: i16, player_x: i16) *Object {
    ex.x = player_x;
    ex.y = player_y;
    ex.id = @intFromBool(condition != null);
    ex.unk18[0] = 0;
    ex.unk18[1] = @bitCast(exit_index);
    return ex;
}

/// SceneVtbl slot 0B addExit (scene_add_exit_at): no bounds check in the
/// original; the table has 10 entries, an overflow panics.
// @orig 1060:006c scene_add_exit_at
pub fn addExit(g: *Game, scene: *Scene, ex: *Object, player_x: i16, player_y: i16, condition: ?*Condition) i16 {
    _ = g;
    const idx = scene.exitCount;
    _ = exitSetLink(ex, condition, idx, player_y, player_x);
    if (idx < 0 or idx >= world.max_exits) @panic("inferno.scene: exit table overflow");
    scene.exits[@intCast(idx)] = ex;
    scene.exitCount +%= 1;
    return idx;
}

/// SceneVtbl slot 0C getExit: `exits[index]` when `index < exitCount`.
// @orig 1080:64b4 scene_get_exit
pub fn getExit(g: *Game, scene: *Scene, index: i16) ?*Object {
    _ = g;
    if (index < scene.exitCount) {
        if (index < 0) @panic("inferno.scene.getExit: negative index");
        return scene.exits[@intCast(index)];
    }
    return null;
}

/// The base Scene's slot 07 `create` (InfernoScene's runs it after its own
/// work): builds the backdrop through slot 05 (`hell.createScreen`),
/// creates it (hwnd dropped) and points it at the scene's object list.
// @orig 1060:0000 scene_create
pub fn create(g: *Game, scene: *Scene) *Scene {
    scene.backdrop = hell.createScreen(g, scene);
    _ = backdrop.create(g, bdOf(scene));
    bdOf(scene).sceneList = &scene.objects;
    return scene;
}

/// The base Scene's destructor: deletes the backdrop when set
/// (`backdrop_scalar_dtor(bd, 1)`: its destructor, then the memory). The
/// objects are not touched (they are not in a draw list; the scene's owner
/// frees them).
// @orig 1080:5f42 scene_dtor
pub fn dtor(g: *Game, scene: *Scene) void {
    if (scene.backdrop) |bd| {
        _ = backdrop.delete(g, bd, 1);
        g.local().destroy(bd);
    }
}

/// Scalar deleting destructor: `dtor`, then `operator delete` of the scene
/// when bit 0 of `flags` is set. Returns the scene.
// @orig 1080:5dec scene_scalar_dtor
pub fn scalarDtor(g: *Game, scene: *Scene, flags: u16) *Scene {
    dtor(g, scene);
    if (flags & 1 != 0) g.local().destroy(scene);
    return scene;
}

test "scene ctor and exits" {
    var s: Scene = .{};
    _ = infernoSceneCtor(&s, "a-very-long-scene-name-over-19");
    try std.testing.expectEqualStrings("a-very-long-scene-n", cstr.slice(&s.name));
    try std.testing.expect(s.hasPlayer == 1);
    var g: Game = undefined;
    var o: Object = .{ .kind = .hero };
    try std.testing.expectEqual(@as(i16, 0), addExit(&g, &s, &o, 3, 4, null));
    try std.testing.expect(getExit(&g, &s, 0) == &o);
    try std.testing.expect(getExit(&g, &s, 1) == null);
    try std.testing.expectEqual(@as(i16, 3), o.x);
}
