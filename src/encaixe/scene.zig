//! Port unit `scene` (module) of ENCAIXE.EXE. Scene methods (SceneVtbl 01-04 06 08-0C), scene_create and the destructor.
//!
//! Virtual-slot dispatchers owned by this unit are declared below with
//! their final signatures; their bodies panic until the unit is ported
//! (docs/encaixe/DESIGN.md "Virtual slots"). Replace each body, keep the
//! signature (other units already call it). Each implementation function
//! carries `// @orig <1008:xxxx> <name>` with the ENCAIXE address.

const std = @import("std");
const cstr = @import("../core/cstr.zig");
const lists = @import("lists.zig");
const dib = @import("dib.zig");
const tetris = @import("tetris.zig");
const backdrop = @import("backdrop.zig");
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
const RectQuery = world.RectQuery;

/// The scene's backdrop (the original dereferences it unchecked).
fn bdOf(scene: *Scene) *Backdrop {
    return scene.backdrop orelse @panic("encaixe.scene: no backdrop");
}

/// SceneVtbl slot 01 getHasPlayer.
// @orig 1008:a65e scene_get_has_player
pub fn getHasPlayer(g: *Game, scene: *Scene) bool {
    _ = g;
    return scene.hasPlayer != 0;
}

/// SceneVtbl slot 02 getHasControlPanel.
// @orig 1008:a66c scene_get_has_control_panel
pub fn getHasControlPanel(g: *Game, scene: *Scene) bool {
    _ = g;
    return scene.hasControlPanel != 0;
}

/// SceneVtbl slot 03 getHasStatusBar.
// @orig 1008:a67a scene_get_has_status_bar
pub fn getHasStatusBar(g: *Game, scene: *Scene) bool {
    _ = g;
    return scene.hasStatusBar != 0;
}

/// SceneVtbl slot 04 addObject: links the object into the scene's list and
/// inserts its Object3D part (null for a non-3D object) into the draw list.
// @orig 1008:b68c scene_add_object
pub fn addObject(g: *Game, scene: *Scene, obj: *Object) void {
    _ = lists.add(&scene.objects, obj);
    _ = lists.drawInsert(g, bdOf(scene), obj.as(.object3d));
}

/// SceneVtbl slot 06 createNewScene (default only: "Faltou redefinir…",
/// caption: the scene name). Returns the scene.
// @orig 1008:a6a6 scene_create_new_scene_default (absorbed)
pub fn createNewScene(g: *Game, scene: *Scene, exit_index: i16) ?*Scene {
    _ = exit_index;
    lists.messageBoxPrintf(g, cstr.slice(&scene.name), "Faltou redefinir o m\xe9todo CreateNewScene", 0);
    return scene;
}

/// SceneVtbl slot 08 blitToDc (hdc dropped): the palette selection has no
/// counterpart; copies the backdrop's view to the window.
// @orig 1008:a6c4 scene_blit_to_dc
pub fn blitToDc(g: *Game, scene: *Scene) *Scene {
    const bd = bdOf(scene);
    g.plat.wingBitBlt(0, 0, bd.viewWidth, bd.viewHeight, bd.surface(), bd.originX, bd.originY);
    return scene;
}

/// SceneVtbl slot 09 clearView: PatBlt(BLACKNESS) over both bitmaps.
// @orig 1008:a706 scene_clear_view
pub fn clearView(g: *Game, scene: *Scene) *Scene {
    _ = g;
    const bd = bdOf(scene);
    @memset(bd.pixels, 0);
    @memset(bd.pixels2, 0);
    return scene;
}

/// SceneVtbl slot 0A drawBackground: copies the background picture into
/// both bitmaps. The original ignores the copy's result; the errors
/// (memory corruption or death there) panic.
// @orig 1008:a742 scene_draw_background
pub fn drawBackground(g: *Game, scene: *Scene) *Scene {
    const bd = bdOf(scene);
    const bg = bd.background orelse @panic("encaixe.scene.drawBackground: no background");
    _ = dib.copy(&bd.bmiHeader, bd.pixels, 0, 0, bg.bits, &bg.header, g.fixes) catch |e| @panic(@errorName(e));
    _ = dib.copy(&bd.bmiHeader, bd.pixels2, 0, 0, bg.bits, &bg.header, g.fixes) catch |e| @panic(@errorName(e));
    return scene;
}

/// SceneVtbl slot 0B addExit (scene_add_exit_at; no callers, no Exit class
/// in ENCAIXE's object model). The original stores the link into the
/// object's bitmap-header area: playerX in the high word of biWidth, playerY
/// in the low word of biHeight, the condition in the low word of
/// biCompression, the exit index in its high word, 0 in the high word of
/// biSizeImage. The condition pointer has no representation there: only
/// whether it is set is kept.
// @orig 1008:b6ba scene_add_exit_at
pub fn addExit(g: *Game, scene: *Scene, ex: *Object, player_x: i16, player_y: i16, condition: ?*Condition) i16 {
    _ = g;
    const idx = scene.exitCount;
    const h = &ex.bmiHeader;
    h.biWidth = (h.biWidth & 0xffff) | (@as(i32, player_x) << 16);
    h.biHeight = (h.biHeight & ~@as(i32, 0xffff)) | @as(i32, @as(u16, @bitCast(player_y)));
    h.biCompression = (@as(u32, @as(u16, @bitCast(idx))) << 16) | @intFromBool(condition != null);
    h.biSizeImage &= 0xffff;
    if (idx < 0 or idx >= world.max_exits) @panic("encaixe.scene: exit table overflow");
    scene.exits[@intCast(idx)] = ex;
    scene.exitCount += 1;
    return idx;
}

/// SceneVtbl slot 0C getExit: `exits[index]` when `index < exitCount`.
// @orig 1008:a7ac scene_get_exit
pub fn getExit(g: *Game, scene: *Scene, index: i16) ?*Object {
    _ = g;
    if (index < scene.exitCount) {
        if (index < 0) @panic("encaixe.scene.getExit: negative index");
        return scene.exits[@intCast(index)];
    }
    return null;
}

/// The base Scene's slot 07 `create` (TetrisScene's runs it first): builds
/// the backdrop through slot 05, creates its view (hwnd dropped) and points
/// it at the scene's object list.
// @orig 1008:b5b0 scene_create
pub fn create(g: *Game, scene: *Scene) *Scene {
    scene.backdrop = tetris.createScreen(g, scene);
    const bd = bdOf(scene);
    _ = backdrop.create(g, bd);
    bd.sceneList = &scene.objects;
    return scene;
}

/// The base Scene's destructor: removes each object from the game's draw
/// list and deletes it, then destroys the backdrop (its GDI objects have no
/// counterpart; both bitmaps and the background picture are freed). The
/// scene itself is freed by the caller.
// @orig 1008:b5dc scene_dtor
pub fn dtor(g: *Game, scene: *Scene) void {
    var cur = scene.objects.head;
    while (cur) |o| {
        lists.drawRemove(&g.drawList, o.as(.object3d));
        cur = o.next;
        g.gpa.destroy(o);
    }
    if (scene.backdrop) |bd| {
        if (bd.pixels.len != 0) g.gpa.free(bd.pixels);
        if (bd.pixels2.len != 0) g.gpa.free(bd.pixels2);
        if (bd.background) |bg| {
            g.gpa.free(bg.bits);
            g.gpa.destroy(bg);
        }
        g.gpa.destroy(bd);
    }
}

test "scene unit compiles" {
    std.testing.refAllDecls(@This());
}
