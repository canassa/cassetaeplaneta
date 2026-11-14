//! Port unit `game` (module) of INFERNO.EXE. Game + InfernoGame: ctor/dtor,
//! GameVtbl 01-06 (createPlayer: the hero, createInitScene, onCreate: the
//! world builders), game_init, game_take_exit, the conditions.
//!
//! Virtual-slot dispatchers owned by this unit are declared below with
//! their final signatures; their bodies panic until the unit is ported
//! (docs/inferno/DESIGN.md "Virtual slots"). Replace each body, keep the
//! signature (other units already call it). Each implementation function
//! carries `// @orig <seg:xxxx> <name>` with the INFERNO address.

const std = @import("std");
const stub = @import("../core/stub.zig");
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

/// GameVtbl slot 01 createPlayer (inferno_game_create_player: the hero).
pub fn createPlayer(g: *Game) ?*Object {
    _ = g;
    stub.unported("inferno.game.createPlayer");
}

/// GameVtbl slot 02 createInitScene (inferno_game_create_init_scene).
pub fn createInitScene(g: *Game, name: []const u8) ?*Scene {
    _ = g;
    _ = name;
    stub.unported("inferno.game.createInitScene");
}

/// GameVtbl slot 03 createControlPanel (default only).
pub fn createControlPanel(g: *Game) ?*Object {
    _ = g;
    stub.unported("inferno.game.createControlPanel");
}

/// GameVtbl slot 04 createStatusBar (default only).
pub fn createStatusBar(g: *Game) ?*Object {
    _ = g;
    stub.unported("inferno.game.createStatusBar");
}

/// GameVtbl slot 05 init (game_init, hwnd dropped).
pub fn init(g: *Game, name: []const u8) *Game {
    _ = g;
    _ = name;
    stub.unported("inferno.game.init");
}

/// GameVtbl slot 06 onCreate (inferno_game_on_create: WM_CREATE; hwnd
/// dropped).
pub fn onCreate(g: *Game) *Game {
    _ = g;
    stub.unported("inferno.game.onCreate");
}

/// ConditionVtbl slot 00 evaluate.
pub fn evaluate(cond: *const Condition) i16 {
    _ = cond;
    stub.unported("inferno.game.evaluate");
}

/// ConditionVtbl slot 01 set.
pub fn set(cond: *Condition) void {
    _ = cond;
    stub.unported("inferno.game.set");
}

/// ConditionVtbl slot 02 clear.
pub fn clear(cond: *Condition) i16 {
    _ = cond;
    stub.unported("inferno.game.clear");
}
