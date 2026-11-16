//! The fights' Mortal Kombat 3 engine (`fight_mk3`, a Corrigida prototype
//! not in `--fix all`; docs/fights/MK3.md): a fixed-step simulation with
//! MK3's mechanics (`sim`, numbers in `tables`), a character data format
//! that knows no sprite (`character`), the CPU drone at its easiest rung
//! (`cpu`), test bots (`bot`), drawing (`render`) and the `Match` that runs
//! a round at the display rate. Shared by the fights; XILINDRO's glue is
//! `fight_mk3/xilindro.zig`.

pub const character = @import("fight_mk3/character.zig");
pub const tables = @import("fight_mk3/tables.zig");
pub const sim = @import("fight_mk3/sim.zig");
pub const cpu = @import("fight_mk3/cpu.zig");
pub const bot = @import("fight_mk3/bot.zig");
pub const render = @import("fight_mk3/render.zig");
pub const strips = @import("fight_mk3/strips.zig");
pub const match = @import("fight_mk3/match.zig");
pub const testing = @import("fight_mk3/testing.zig");
pub const Match = match.Match;

test {
    _ = character;
    _ = sim;
    _ = cpu;
    _ = bot;
    _ = match;
    _ = strips;
    _ = @import("fight_mk3/tests.zig");
}
