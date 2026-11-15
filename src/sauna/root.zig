//! SAUNA.EXE ("Sauna Mista", the sauna's Pac-Man minigame), native port:
//! the program root (docs/sauna/DESIGN.md). NOITE's `3fsauna` starts it
//! with WinExec (`platform/host.zig` runs it as a second task); `noite
//! --minigame sauna` runs it alone.

const std = @import("std");
const host = @import("../platform/host.zig");
const platform = @import("../platform/platform.zig");
const Fixes = @import("../core/fixes.zig").Fixes;

pub const core = struct {
    pub const game = @import("core/game.zig");
    pub const object = @import("core/object.zig");
    pub const world = @import("core/world.zig");
};
pub const units = @import("units.zig");
/// The Corrigida's arcade game (`Fixes.sauna_arcade_rules`, docs/sauna/PACMAN.md); not port units.
pub const arcade = struct {
    pub const maze = @import("arcade/maze.zig");
    pub const sim = @import("arcade/sim.zig");
    pub const driver = @import("arcade/driver.zig");
    pub const glue = @import("arcade/glue.zig");
    pub const view = @import("arcade/view.zig");
    pub const controls = @import("arcade/controls.zig");
};
const Game = core.game.Game;
const view_unit = @import("arcade/view.zig");

/// Every unit ported and the game checked (the last step of the port,
/// docs/sauna/DESIGN.md "Finishing"): only then does NOITE's WinExec run
/// it instead of the stub, and `--minigame sauna` play it.
pub const ready = true;

/// The window class and caption FindWindow looks for (DGROUP 10b0:0196).
pub const title = "Sauna Mista";

/// What the host needs to run SAUNA as a task.
pub const program: host.Program = .{
    .name = "sauna",
    .title = title,
    .dir = "\\SAUNA",
    .ready = ready,
    .start = start,
    .deliver = deliver,
    .step = step,
    .nextDue = nextDue,
    .quit = quit,
    .exit = exit,
    .view = view,
};

fn of(ctx: *anyopaque) *Game {
    return @ptrCast(@alignCast(ctx));
}

/// WinMain up to the message loop: the game object and `app.start`
/// (the static initialiser, app_init, CreateWindow → WM_CREATE, the
/// activation).
fn start(gpa: std.mem.Allocator, plat: platform.Platform, fixes: Fixes) anyerror!*anyopaque {
    const g = try Game.create(gpa, plat);
    errdefer g.destroy();
    g.fixes = fixes;
    g.mainWindow = plat.windowHandle();
    g.wndProc = units.app.wndProc;
    try units.app.start(g);
    return g;
}

fn deliver(ctx: *anyopaque, ev: platform.Event) void {
    of(ctx).deliver(ev);
}

fn step(ctx: *anyopaque) bool {
    return of(ctx).dispatchPending();
}

fn nextDue(ctx: *anyopaque) ?u32 {
    return of(ctx).queue.nextDue();
}

fn quit(ctx: *anyopaque) bool {
    return of(ctx).quit;
}

/// app_exit (deletes the game's objects), then the state goes.
fn exit(ctx: *anyopaque) void {
    const g = of(ctx);
    units.app.exit(g);
    g.destroy();
}

/// Not Windows: the Corrigida's picture (`arcade/view.zig`).
fn view(ctx: *anyopaque, now: u32) ?*const platform.Screen {
    return view_unit.view(of(ctx), now);
}

test {
    _ = units;
    _ = @import("arcade/sim.zig");
    _ = @import("arcade/maze.zig");
    _ = @import("arcade/glue.zig");
    _ = @import("arcade/driver.zig");
    _ = @import("arcade/controls.zig");
    std.testing.refAllDecls(core);
}
