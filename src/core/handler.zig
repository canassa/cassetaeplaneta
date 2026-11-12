//! Scene handlers (docs/DESIGN.md "Scene handlers").
//!
//! A handler unit (`src/handlers/<scene>.zig`) exports
//!
//!     pub fn handle(g: *Game, m: Msg) i16   // non-zero = handled
//!     pub const State = struct { ... };      // optional: its globals
//!
//! `register_scene_handlers` (unit `game`) fills `Game.handlers` with the
//! `handle` functions; `ini_scene_handle_message` (unit `scene`) calls
//! them. The scene's former DGROUP globals live in its `State`, which
//! `Game.scenes` holds (one field per handler unit, built here at compile
//! time from `units.zig`); a handler reaches it with `g.sceneState(State)`.

const std = @import("std");
const Game = @import("game.zig").Game;
const Msg = @import("msg.zig").Msg;
const units = @import("../units.zig");

/// `SceneHandlerFn` (far cdecl, hwnd dropped: there is one window).
pub const Handler = *const fn (g: *Game, m: Msg) i16;

/// Capacity of `g_registeredHandlers` (index = INI Screen= Number).
pub const max_handlers = 400;

/// One field per handler unit that declares `State`, named after the unit.
pub const SceneStates = blk: {
    const decls = std.meta.declarations(units);
    var names: [decls.len][]const u8 = undefined;
    var types: [decls.len]type = undefined;
    var attrs: [decls.len]std.lang.Type.Struct.FieldAttributes = undefined;
    var n: usize = 0;
    for (decls) |name| {
        const U = @field(units, name);
        if (@TypeOf(U) != type or !std.mem.startsWith(u8, name, "handler_")) continue;
        if (!@hasDecl(U, "State")) continue;
        names[n] = name;
        types[n] = U.State;
        const default: U.State = .{};
        attrs[n] = .{ .default_value_ptr = &default };
        n += 1;
    }
    break :blk @Struct(.auto, null, names[0..n], types[0..n], attrs[0..n]);
};

/// The `SceneStates` field whose type is `T`.
pub fn stateOf(states: *SceneStates, comptime T: type) *T {
    const info = @typeInfo(SceneStates).@"struct";
    inline for (info.field_names, info.field_types) |name, F| {
        if (F == T) return &@field(states, name);
    }
    @compileError("no handler unit declares this State type");
}
