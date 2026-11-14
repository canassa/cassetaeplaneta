//! Port unit `game` (module) of JARDIM.EXE. JardimGame + Game: ctor/dtor, GameVtbl 01-06 (createPlayer: the hidden Player; the panel; no status bar; Phase1Scene), game_init, game_take_exit, the conditions.
//!
//! Virtual-slot dispatchers owned by this unit are declared below with
//! their final signatures; their bodies panic until the unit is ported
//! (docs/jardim/DESIGN.md "Virtual slots"). Replace each body, keep the
//! signature (other units already call it). Each implementation function
//! carries `// @orig <seg:xxxx> <name>` with the JARDIM address.

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

/// GameVtbl slot 01 createPlayer (jardim_game_create_player: the hidden Player).
pub fn createPlayer(g: *Game) ?*Object {
    _ = g;
    stub.unported("jardim.game.createPlayer");
}

/// GameVtbl slot 02 createInitScene (jardim_game_create_init_scene: Phase1Scene).
pub fn createInitScene(g: *Game, name: []const u8) ?*Scene {
    _ = g;
    _ = name;
    stub.unported("jardim.game.createInitScene");
}

/// GameVtbl slot 03 createControlPanel.
pub fn createControlPanel(g: *Game) ?*Object {
    _ = g;
    stub.unported("jardim.game.createControlPanel");
}

/// GameVtbl slot 04 createStatusBar (NULL).
pub fn createStatusBar(g: *Game) ?*Object {
    _ = g;
    stub.unported("jardim.game.createStatusBar");
}

/// GameVtbl slot 05 init (game_init, hwnd dropped).
pub fn init(g: *Game, name: []const u8) *Game {
    _ = g;
    _ = name;
    stub.unported("jardim.game.init");
}

/// GameVtbl slot 06 onCreate (jardim_game_on_create, WM_CREATE; hwnd dropped).
pub fn onCreate(g: *Game) *Game {
    _ = g;
    stub.unported("jardim.game.onCreate");
}

/// game_take_exit: 0x402 (from game_handle_message): the next phase.
pub fn takeExit(g: *Game, exit_index: i16) *Game {
    _ = g;
    _ = exit_index;
    stub.unported("jardim.game.takeExit");
}

/// ConditionVtbl slot 00 evaluate.
pub fn evaluate(cond: *const Condition) i16 {
    _ = cond;
    stub.unported("jardim.game.evaluate");
}

/// ConditionVtbl slot 01 set.
pub fn set(cond: *Condition) i16 {
    _ = cond;
    stub.unported("jardim.game.set");
}

/// ConditionVtbl slot 02 clear.
pub fn clear(cond: *Condition) i16 {
    _ = cond;
    stub.unported("jardim.game.clear");
}
