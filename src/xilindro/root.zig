//! XILINDRO.EXE ("Xilindro", the street fight after the prison escape),
//! native port: the program root (docs/xilindro/DESIGN.md). NOITE's
//! `3fstreet` starts it with WinExec (`platform/host.zig` runs it as a
//! second task); `noite --minigame xilindro` runs it alone.

const std = @import("std");
const host = @import("../platform/host.zig");
const platform = @import("../platform/platform.zig");
const Fixes = @import("../core/fixes.zig").Fixes;
const fight_smooth = @import("../core/fight_smooth.zig");

pub const core = struct {
    pub const game = @import("core/game.zig");
    pub const object = @import("core/object.zig");
    pub const world = @import("core/world.zig");
};
pub const units = @import("units.zig");
const Game = core.game.Game;

/// Every unit ported and the game checked (the last step of the port,
/// docs/salgin/DESIGN.md "Finishing"): only then does NOITE's WinExec run
/// it instead of the stub, and `--minigame xilindro` play it.
pub const ready = true;

/// The window class and caption FindWindow looks for (DGROUP 1090:00aa).
pub const title = "Xilindro";

/// What the host needs to run XILINDRO as a task.
pub const program: host.Program = .{
    .name = "xilindro",
    .title = title,
    .dir = "\\XILINDRO",
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

/// The picture to present (`Fixes.fight_smooth_motion`), or null for the
/// screen.
fn view(ctx: *anyopaque, now: u32) ?*const platform.Screen {
    if (of(ctx).mk3 != null) return @import("../core/fight_mk3/glue.zig").view(of(ctx), now);
    return fight_smooth.view(struct {
        pub const render = units.render;
        pub const dib = units.dib;
        pub const hud = units.hud;
    }, of(ctx), now);
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
    _ = @import("../core/fight_mk3.zig");
    _ = units;
    std.testing.refAllDecls(core);
}
