//! Port unit `scene` (module) of JARDIM.EXE. Scene methods (SceneVtbl 01-04 06 08-0F), ctor, scene_create, the destructor, exits and their links.
//!
//! Virtual-slot dispatchers owned by this unit are declared below with
//! their final signatures; their bodies panic until the unit is ported
//! (docs/jardim/DESIGN.md "Virtual slots"). Replace each body, keep the
//! signature (other units already call it). Each implementation function
//! carries `// @orig <seg:xxxx> <name>` with the JARDIM address.

const std = @import("std");
const cstr = @import("../core/cstr.zig");
const lists = @import("lists.zig");
const backdrop = @import("backdrop.zig");
const labyrinth = @import("labyrinth.zig");
const object_create = @import("object_create.zig");
const position = @import("behaviour/position.zig");
const msg = @import("../core/msg.zig");
const Msg = msg.Msg;
const Game = @import("core/game.zig").Game;
const object = @import("core/object.zig");
const Object = object.Object;
const ObjectList = object.ObjectList;
const Frame = object.Frame;
const FrameCell = object.FrameCell;
const BitmapInfoHeader = object.BitmapInfoHeader;
const world = @import("core/world.zig");
const Backdrop = world.Backdrop;
const Scene = world.Scene;
const Condition = world.Condition;

/// The scene's backdrop (+4; the original dereferences it unchecked).
fn bdOf(scene: *Scene) *Backdrop {
    return scene.screen orelse @panic("jardim.scene: no backdrop");
}

/// `_fstrncpy(dst, src, 0x13)`: at most 19 chars, NUL-padded (strncpy).
fn copyName(dst: []u8, src: []const u8) void {
    var n: usize = 0;
    while (n < 19 and n < src.len and src[n] != 0) : (n += 1) dst[n] = src[n];
    @memset(dst[n..19], 0);
}

/// Scene base constructor: the 30-entry object list, the name (19 chars at
/// most), the counters and flags, the handler off. Parameters 2-5 of the
/// original (view size, two unused) are dropped; the vtable (10c0:6c64) is
/// the phase's (`Scene.vtbl`, set by `labyrinth_scene.ctor`).
// @orig 10c0:7a30 scene_ctor
pub fn ctor(scene: *Scene, has_status_bar: i16, has_control_panel: i16, has_player: i16, name: []const u8) *Scene {
    _ = lists.ctor(&scene.objects, 0x1e);
    copyName(&scene.name, name);
    scene.name[0x13] = 0;
    scene.exitCount = 0;
    scene.hasPlayer = has_player;
    scene.hasStatusBar = has_status_bar;
    scene.hasControlPanel = has_control_panel;
    scene.is1Animation = 0;
    scene.isClickExit = 0;
    scene.mayDropObject = 1;
    scene.animation = null;
    scene.handlerEnabled = 0;
    return scene;
}

/// SceneVtbl slot 01 getHasPlayer.
// @orig 10c0:6a78 scene_get_has_player
pub fn getHasPlayer(g: *Game, scene: *Scene) bool {
    _ = g;
    return scene.hasPlayer != 0;
}

/// SceneVtbl slot 02 getHasControlPanel.
// @orig 10c0:6a96 scene_get_has_control_panel
pub fn getHasControlPanel(g: *Game, scene: *Scene) bool {
    _ = g;
    return scene.hasControlPanel != 0;
}

/// SceneVtbl slot 03 getHasStatusBar.
// @orig 10c0:6ab4 scene_get_has_status_bar
pub fn getHasStatusBar(g: *Game, scene: *Scene) bool {
    _ = g;
    return scene.hasStatusBar != 0;
}

/// SceneVtbl slot 04 addObject: links the object into the scene's list and
/// inserts its Object3D part into the draw list.
// @orig 1070:014d scene_add_object
pub fn addObject(g: *Game, scene: *Scene, obj: *Object) void {
    _ = lists.add(&scene.objects, obj);
    _ = lists.drawInsert(g, bdOf(scene), obj.as(.object3d));
}

/// SceneVtbl slot 06 createNewScene's default ("Faltou redefinir...",
/// caption: the scene name). Returns the scene.
// @orig 10c0:6b10 scene_create_new_scene_default (absorbed)
pub fn createNewSceneDefault(g: *Game, scene: *Scene, exit_index: i16) ?*Scene {
    _ = exit_index;
    position.messageBoxPrintf(g, cstr.slice(&scene.name), "Faltou redefinir o m\xe9todo CreateNewScene", 0);
    return scene;
}

/// SceneVtbl slot 07 create (the base): builds the backdrop through slot 05
/// (`createScreen`), creates it (slot 00, hwnd dropped), points it at the
/// scene's object list and enables the handler.
// @orig 1070:0000 scene_create
pub fn create(g: *Game, scene: *Scene) *Scene {
    scene.screen = scene.createScreen(g);
    _ = labyrinth.create(g, bdOf(scene));
    bdOf(scene).sceneList = &scene.objects;
    scene.handlerEnabled = 1;
    return scene;
}

/// The base destructor: removes each object from the game's draw list and
/// deletes it (`scene_object_scalar_dtor(obj, 1)`), then deletes the
/// backdrop (no draw_list_reset, unlike NOITE's).
// @orig 1070:0075 scene_dtor
pub fn dtor(g: *Game, scene: *Scene) void {
    var cur = scene.objects.head;
    while (cur) |o| {
        lists.drawRemove(&g.drawList, o.as(.object3d));
        cur = o.next;
        _ = object_create.sceneObjectScalarDtor(g, o, 1);
    }
    if (scene.screen) |bd| {
        _ = backdrop.scalarDtor(g, bd, 1);
        g.local().destroy(bd);
    }
}

/// Scalar deleting destructor: `dtor`, then `operator delete` of the scene
/// when bit 0 of `flags` is set. Returns the scene.
// @orig 10c0:2d9e scene_scalar_dtor
pub fn scalarDtor(g: *Game, scene: *Scene, flags: u16) *Scene {
    dtor(g, scene);
    if (flags & 1 != 0) g.local().destroy(scene);
    return scene;
}

/// SceneVtbl slot 08 blitToDc (hdc dropped): the backdrop's blit.
// @orig 10c0:6b4a scene_blit_to_dc
pub fn blitToDc(g: *Game, scene: *Scene) *Scene {
    backdrop.blitToDc(g, bdOf(scene));
    return scene;
}

/// SceneVtbl slot 09 clearView.
// @orig 10c0:6b7a scene_clear_view
pub fn clearView(g: *Game, scene: *Scene) *Scene {
    _ = g;
    backdrop.clear(bdOf(scene));
    return scene;
}

/// SceneVtbl slot 0A drawBackground. The original ignores the copy's
/// result; its errors (memory corruption there) panic.
// @orig 10c0:6ba6 scene_draw_background
pub fn drawBackground(g: *Game, scene: *Scene) *Scene {
    backdrop.drawBackground(g, bdOf(scene)) catch |e| @panic(@errorName(e));
    return scene;
}

/// Exit +0x2a/+0x2c player position, +0x38 condition, +0x3c exit index,
/// +0x40 cleared.
// @orig 10c0:6928 exit_set_link
pub fn exitSetLink(ex: *Object, condition: ?*Condition, exit_index: i16, player_y: i16, player_x: i16) *Object {
    ex.exit.playerX = player_x;
    ex.exit.playerY = player_y;
    ex.exit.condition = condition;
    ex.exit.exitIndex = exit_index;
    ex.exit.playing = 0;
    return ex;
}

/// The link plus the target scene name (+0x16, 19 chars, +0x29 = 0).
// @orig 10c0:697c exit_set_link_to_scene
pub fn exitSetLinkToScene(ex: *Object, scene_name: []const u8, condition: ?*Condition, exit_index: i16, player_y: i16, player_x: i16) *Object {
    copyName(&ex.exit.sceneName, scene_name);
    ex.exit.sceneName[19] = 0;
    return exitSetLink(ex, condition, exit_index, player_y, player_x);
}

/// Unlike NOITE's, it overwrites the primary target: the name at +0x16 and
/// the position at +0x2a/+0x2c (the alternative's index at +0x44).
// @orig 10c0:69f4 exit_set_alt_link
pub fn exitSetAltLink(ex: *Object, alt_exit_index: i16, alt_y: i16, alt_x: i16, alt_scene_name: []const u8) *Object {
    copyName(&ex.exit.sceneName, alt_scene_name);
    ex.exit.sceneName[19] = 0;
    ex.exit.playerX = alt_x;
    ex.exit.playerY = alt_y;
    ex.exit.altExitIndex = alt_exit_index;
    return ex;
}

// @orig 10c0:6a52 exit_set_exit_index
pub fn exitSetExitIndex(ex: *Object, exit_index: i16) *Object {
    ex.exit.exitIndex = exit_index;
    return ex;
}

/// Appends `ex` to the exit table and returns its index (no bounds check in
/// the original: the table has 10 entries, an overflow panics).
fn appendExit(scene: *Scene, ex: *Object) i16 {
    const idx = scene.exitCount;
    if (idx < 0 or idx >= world.max_exits) @panic("jardim.scene: exit table overflow");
    scene.exits[@intCast(idx)] = ex;
    scene.exitCount +%= 1;
    return idx;
}

/// SceneVtbl slot 0B addExit: the exit's target is already set; stores its
/// index and appends it.
// @orig 1070:026a scene_add_exit
pub fn addExit(g: *Game, scene: *Scene, ex: *Object) i16 {
    _ = g;
    _ = exitSetExitIndex(ex, scene.exitCount);
    return appendExit(scene, ex);
}

/// SceneVtbl slot 0C addExitToScene: target scene, player position and
/// condition.
// @orig 1070:0206 scene_add_exit_to_scene
pub fn addExitToScene(g: *Game, scene: *Scene, ex: *Object, scene_name: []const u8, player_x: i16, player_y: i16, condition: ?*Condition) i16 {
    _ = g;
    _ = exitSetLinkToScene(ex, scene_name, condition, scene.exitCount, player_y, player_x);
    return appendExit(scene, ex);
}

/// SceneVtbl slot 0D addExitAt: the phases' Exit (player position and
/// condition).
// @orig 1070:01a8 scene_add_exit_at
pub fn addExitAt(g: *Game, scene: *Scene, ex: *Object, player_x: i16, player_y: i16, condition: ?*Condition) i16 {
    _ = g;
    _ = exitSetLink(ex, condition, scene.exitCount, player_y, player_x);
    return appendExit(scene, ex);
}

/// SceneVtbl slot 0E addExitAlt: the alternative target and its index.
// @orig 1070:02b6 scene_add_exit_alt
pub fn addExitAlt(g: *Game, scene: *Scene, ex: *Object, alt_scene_name: []const u8, alt_x: i16, alt_y: i16) i16 {
    _ = g;
    _ = exitSetAltLink(ex, scene.exitCount, alt_y, alt_x, alt_scene_name);
    return appendExit(scene, ex);
}

/// SceneVtbl slot 0F getExit: `exits[index]` when `index < exitCount`.
// @orig 10c0:6bd2 scene_get_exit
pub fn getExit(g: *Game, scene: *Scene, index: i16) ?*Object {
    _ = g;
    if (index < scene.exitCount) {
        if (index < 0) @panic("jardim.scene.getExit: negative index");
        return scene.exits[@intCast(index)];
    }
    return null;
}
