//! Port unit `game` (module) of INV.EXE. InvGame: ctor/dtor, GameVtbl 01-06 (createPlayer: the cannon, 4 lives; panel, status bar, init scene, onCreate: the six creators), game_init, game_take_exit, the conditions.
//!
//! Virtual-slot dispatchers owned by this unit are declared below with
//! their final signatures; their bodies panic until the unit is ported
//! (docs/inv/DESIGN.md "Virtual slots"). Replace each body, keep the
//! signature (other units already call it). Each implementation function
//! carries `// @orig <seg:xxxx> <name>` with the INV address.

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

/// GameVtbl slot 01 createPlayer.
pub fn createPlayer(g: *Game) ?*Object {
    _ = g;
    stub.unported("inv.game.createPlayer");
}

/// GameVtbl slot 02 createInitScene.
pub fn createInitScene(g: *Game, name: []const u8) ?*Scene {
    _ = g;
    _ = name;
    stub.unported("inv.game.createInitScene");
}

/// GameVtbl slot 03 createControlPanel.
pub fn createControlPanel(g: *Game) ?*Object {
    _ = g;
    stub.unported("inv.game.createControlPanel");
}

/// GameVtbl slot 04 createStatusBar.
pub fn createStatusBar(g: *Game) ?*Object {
    _ = g;
    stub.unported("inv.game.createStatusBar");
}

/// GameVtbl slot 05 init (game_init, hwnd dropped).
pub fn init(g: *Game, name: []const u8) *Game {
    _ = g;
    _ = name;
    stub.unported("inv.game.init");
}

/// GameVtbl slot 06 onCreate (WM_CREATE; hwnd dropped).
pub fn onCreate(g: *Game) *Game {
    _ = g;
    stub.unported("inv.game.onCreate");
}

/// ConditionVtbl slot 00 evaluate.
pub fn evaluate(cond: *const Condition) i16 {
    _ = cond;
    stub.unported("inv.game.evaluate");
}

/// ConditionVtbl slot 01 set.
pub fn set(cond: *Condition) void {
    _ = cond;
    stub.unported("inv.game.set");
}

/// ConditionVtbl slot 02 clear.
pub fn clear(cond: *Condition) i16 {
    _ = cond;
    stub.unported("inv.game.clear");
}
