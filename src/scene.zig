//! Port unit `scene` (module). the INI scene: lifetime, objects, exits, view forwarders, message dispatch to handlers and WM_SYSTIMER.
//!
//! Virtual-slot dispatchers owned by this unit are declared below with
//! their final signatures; their bodies panic until the unit is ported
//! (docs/DESIGN.md "Virtual slots → dispatchers"). Replace each body, keep
//! the signature (other units already call it).

const stub = @import("core/stub.zig");
const ini = @import("ini.zig");
const cstr = @import("core/cstr.zig");
const Game = @import("core/game.zig").Game;
const object = @import("core/object.zig");
const Object = object.Object;
const world = @import("core/world.zig");
const Backdrop = world.Backdrop;
const Scene = world.Scene;
const Condition = world.Condition;
const Msg = @import("core/msg.zig").Msg;

/// Scene slot 00 (skeleton stub: unported until this unit is).
pub fn handleMessage(g: *Game, scene: *Scene, m: Msg) i16 {
    _ = .{ g, scene, m };
    stub.unported("scene.handleMessage");
}

/// Scene slot 01 (skeleton stub: unported until this unit is).
pub fn getHasPlayer(g: *Game, scene: *Scene) bool {
    _ = .{ g, scene };
    stub.unported("scene.getHasPlayer");
}

/// Scene slot 02 (skeleton stub: unported until this unit is).
pub fn getHasControlPanel(g: *Game, scene: *Scene) bool {
    _ = .{ g, scene };
    stub.unported("scene.getHasControlPanel");
}

/// Scene slot 03 (skeleton stub: unported until this unit is).
pub fn getHasStatusBar(g: *Game, scene: *Scene) bool {
    _ = .{ g, scene };
    stub.unported("scene.getHasStatusBar");
}

/// Scene slot 04 (skeleton stub: unported until this unit is).
pub fn addObject(g: *Game, scene: *Scene, obj: *Object) void {
    _ = .{ g, scene, obj };
    stub.unported("scene.addObject");
}

/// Scene slot 05: the INI scene does not override the base stub, which
/// only warns (caption: the scene name) and returns the scene's backdrop.
// @orig 1010:43dc scene_create_screen_default (absorbed)
pub fn createScreen(g: *Game, scene: *Scene) ?*Backdrop {
    ini.messageBoxPrintf(g.plat, &g.messageBuf, cstr.slice(&scene.name), "Faltou redefinir o m\xe9todo CreateScreen", 0);
    return scene.backdrop;
}

/// Scene slot 06 (skeleton stub: unported until this unit is).
pub fn createNewScene(g: *Game, scene: *Scene, exit_index: i16) ?*Scene {
    _ = .{ g, scene, exit_index };
    stub.unported("scene.createNewScene");
}

/// Scene slot 08 (skeleton stub: unported until this unit is).
pub fn blitToDc(g: *Game, scene: *Scene) *Scene {
    _ = .{ g, scene };
    stub.unported("scene.blitToDc");
}

/// Scene slot 09 (skeleton stub: unported until this unit is).
pub fn clearView(g: *Game, scene: *Scene) *Scene {
    _ = .{ g, scene };
    stub.unported("scene.clearView");
}

/// Scene slot 0A (skeleton stub: unported until this unit is).
pub fn drawBackground(g: *Game, scene: *Scene) *Scene {
    _ = .{ g, scene };
    stub.unported("scene.drawBackground");
}

/// Scene slot 0B (skeleton stub: unported until this unit is).
pub fn addExit(g: *Game, scene: *Scene, exit: *Object) i16 {
    _ = .{ g, scene, exit };
    stub.unported("scene.addExit");
}

/// Scene slot 0C (skeleton stub: unported until this unit is).
pub fn addExitToScene(g: *Game, scene: *Scene, exit: *Object, scene_name: []const u8, player_x: i16, player_y: i16, condition: ?*Condition) i16 {
    _ = .{ g, scene, exit, scene_name, player_x, player_y, condition };
    stub.unported("scene.addExitToScene");
}

/// Scene slot 0D (skeleton stub: unported until this unit is).
pub fn addExitAt(g: *Game, scene: *Scene, exit: *Object, player_x: i16, player_y: i16, condition: ?*Condition) i16 {
    _ = .{ g, scene, exit, player_x, player_y, condition };
    stub.unported("scene.addExitAt");
}

/// Scene slot 0E (skeleton stub: unported until this unit is).
pub fn addExitAlt(g: *Game, scene: *Scene, exit: *Object, alt_scene_name: []const u8, alt_x: i16, alt_y: i16) i16 {
    _ = .{ g, scene, exit, alt_scene_name, alt_x, alt_y };
    stub.unported("scene.addExitAlt");
}

/// Scene slot 0F (skeleton stub: unported until this unit is).
pub fn getExit(g: *Game, scene: *Scene, index: i16) ?*Object {
    _ = .{ g, scene, index };
    stub.unported("scene.getExit");
}
