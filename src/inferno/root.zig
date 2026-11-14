//! INFERNO.EXE ("Inferno", the platformer in hell of the pope's
//! punishment), native port: the program root (docs/inferno/DESIGN.md).
//! NOITE's `3fpapmal` starts it with WinExec (`platform/host.zig` runs it
//! as a second task); `noite --minigame inferno` runs it alone.

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
const Game = core.game.Game;

/// Every unit ported and the game checked (the last step of the port,
/// docs/inferno/DESIGN.md "Finishing"): only then does NOITE's WinExec run
/// it instead of the stub, and `--minigame inferno` play it.
pub const ready = false;

/// The window class and caption FindWindow looks for (DGROUP 1090:0084).
pub const title = "Inferno";

/// What the host needs to run INFERNO as a task.
pub const program: host.Program = .{
    .name = "inferno",
    .title = title,
    .dir = "\\INFERNO",
    .ready = ready,
    .start = start,
    .deliver = deliver,
    .step = step,
    .nextDue = nextDue,
    .quit = quit,
    .exit = exit,
};

fn of(ctx: *anyopaque) *Game {
    return @ptrCast(@alignCast(ctx));
}

/// WinMain up to the message loop: the game object and `app.start`
/// (app_init, CreateWindow → WM_CREATE, the activation).
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

test {
    _ = units;
    std.testing.refAllDecls(core);
}
