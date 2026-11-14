//! Noite Animal, native port: entry point and main loop.
//!
//!     noite [--headless] [--ms N] [--assets DIR] [--save DIR] [--trace FILE]
//!           [--input FILE] [--dump DIR] [--dump-every MS] [--bmp]
//!           [--scene NAME [--take ID,ID…]] [--minigame win|lose]
//!           [--minigame-startup MS] [--minigame-reply MS] [--quiet]
//!           [--fix NAME,…|all[,-NAME…]] [--skip-videos] [--one-button]
//!
//! The test harness (`platform/harness.zig`): `--input` plays a script of
//! timed mouse/keyboard input (`platform/script.zig`), `--dump` writes
//! frames of the screen (PNG, or BMP with `--bmp`) every `--dump-every` ms
//! and on `dump` commands, `--scene` starts in an INI scene instead of the
//! opening. A panic prints the scene and the last messages first.
//!
//! The loop is the original's `app_message_loop` (PeekMessage/WaitMessage)
//! around the emulated Win16 queue: platform events become queued input or
//! posted messages, then every due message is dispatched to the window
//! procedure (unit `app`), and the screen is presented when the queue is
//! empty (docs/DESIGN.md "Events and timing").

const std = @import("std");
pub const core = struct {
    pub const game = @import("core/game.zig");
    pub const object = @import("core/object.zig");
    pub const world = @import("core/world.zig");
    pub const msg = @import("core/msg.zig");
    pub const queue = @import("core/queue.zig");
    pub const fixes = @import("core/fixes.zig");
    pub const cstr = @import("core/cstr.zig");
    pub const crt = @import("core/crt.zig");
    pub const handler = @import("core/handler.zig");
    pub const modstate = @import("core/modstate.zig");
    pub const errors = @import("core/errors.zig");
    pub const stub = @import("core/stub.zig");
};
pub const platform = struct {
    pub const api = @import("platform/platform.zig");
    pub const sim = @import("platform/sim.zig");
    pub const headless = @import("platform/headless.zig");
    pub const sdl = @import("platform/sdl.zig");
    pub const font = @import("platform/font.zig");
    pub const flic = @import("platform/flic.zig");
    pub const midi = @import("platform/midi.zig");
    pub const mixer = @import("platform/mixer.zig");
    pub const png = @import("platform/png.zig");
    pub const script = @import("platform/script.zig");
    pub const harness = @import("platform/harness.zig");
};
pub const units = @import("units.zig");
const one_button = @import("one_button.zig");
const Game = core.game.Game;
const wm = core.msg.wm;

const Args = struct {
    headless: bool = false,
    /// Headless: stop after this many virtual milliseconds.
    ms: u32 = 60_000,
    opts: platform.sim.Options = .{},
    trace: ?[]const u8 = null,
    harness: platform.harness.Options = .{},
    /// `--fix a,b` / `--fix all[,-a]`: BUGS.md fixes (src/core/fixes.zig).
    fixes: core.fixes.Fixes = .{},
    /// `--one-button`: the left button does what the right one did
    /// (`src/one_button.zig`).
    one_button: bool = false,
};

/// The running game, for the panic report.
var current_game: ?*Game = null;

pub const panic = std.debug.FullPanic(panicWithReport);

/// Segfaults (a use after free in the port) get the same report. A hung
/// run can be stopped the same way: `timeout -s SEGV 60 noite …` prints
/// the report and the stack of the hung code.
pub const debug = struct {
    pub fn handleSegfault(addr: ?usize, name: []const u8, ctx: ?std.debug.CpuContextPtr) noreturn {
        if (current_game) |g| {
            current_game = null;
            platform.harness.report(g);
        }
        std.debug.defaultHandleSegfault(addr, name, ctx);
    }
};

fn panicWithReport(text: []const u8, first_trace_addr: ?usize) noreturn {
    if (current_game) |g| {
        current_game = null; // a panic inside the report must not recurse
        platform.harness.report(g);
    }
    std.debug.defaultPanic(text, first_trace_addr orelse @returnAddress());
}

pub fn main(init: std.process.Init) !void {
    const gpa = init.gpa;
    const io = init.io;
    var args: Args = .{};
    var it = init.minimal.args.iterate();
    _ = it.next();
    while (it.next()) |a| {
        if (std.mem.eql(u8, a, "--headless")) {
            args.headless = true;
        } else if (std.mem.eql(u8, a, "--ms")) {
            args.ms = try std.fmt.parseInt(u32, it.next() orelse return error.MissingValue, 10);
        } else if (std.mem.eql(u8, a, "--assets")) {
            args.opts.assets_dir = it.next() orelse return error.MissingValue;
        } else if (std.mem.eql(u8, a, "--save")) {
            args.opts.save_dir = it.next() orelse return error.MissingValue;
        } else if (std.mem.eql(u8, a, "--trace")) {
            args.trace = it.next() orelse return error.MissingValue;
        } else if (std.mem.eql(u8, a, "--input")) {
            args.harness.input = it.next() orelse return error.MissingValue;
        } else if (std.mem.eql(u8, a, "--dump")) {
            args.harness.dump_dir = it.next() orelse return error.MissingValue;
        } else if (std.mem.eql(u8, a, "--dump-every")) {
            args.harness.dump_every = try std.fmt.parseInt(u32, it.next() orelse return error.MissingValue, 10);
        } else if (std.mem.eql(u8, a, "--bmp")) {
            args.harness.dump_bmp = true;
        } else if (std.mem.eql(u8, a, "--scene")) {
            args.harness.scene = it.next() orelse return error.MissingValue;
        } else if (std.mem.eql(u8, a, "--fix")) {
            const list = it.next() orelse return error.MissingValue;
            var names = std.mem.tokenizeScalar(u8, list, ',');
            while (names.next()) |name| {
                if (!args.fixes.set(name)) {
                    std.log.err("unknown fix {s} (see src/core/fixes.zig)", .{name});
                    return error.BadArgument;
                }
            }
        } else if (std.mem.eql(u8, a, "--skip-videos")) {
            args.opts.skip_videos = true;
        } else if (std.mem.eql(u8, a, "--one-button")) {
            args.one_button = true;
        } else if (std.mem.eql(u8, a, "--take")) {
            args.harness.take = it.next() orelse return error.MissingValue;
        } else if (std.mem.eql(u8, a, "--quiet")) {
            args.harness.verbose = false;
        } else if (std.mem.eql(u8, a, "--minigame")) {
            const v = it.next() orelse return error.MissingValue;
            args.opts.minigame.won = !std.mem.eql(u8, v, "lose");
        } else if (std.mem.eql(u8, a, "--minigame-startup")) {
            args.opts.minigame.startup_ms = try std.fmt.parseInt(u32, it.next() orelse return error.MissingValue, 10);
        } else if (std.mem.eql(u8, a, "--minigame-reply")) {
            args.opts.minigame.reply_ms = try std.fmt.parseInt(u32, it.next() orelse return error.MissingValue, 10);
        } else {
            std.log.err("unknown argument {s}", .{a});
            return error.BadArgument;
        }
    }

    var trace: std.ArrayList(u8) = .empty;
    defer trace.deinit(gpa);

    var hn = try platform.harness.Harness.init(gpa, io, args.harness, args.opts.assets_dir);
    defer hn.deinit();

    if (args.headless) {
        // Frame dumps need the AVI frames on the screen.
        if (args.harness.dump_dir != null) args.opts.decode_video = true;
        var h = platform.headless.Headless.init(gpa, io, args.opts);
        defer h.deinit();
        const g = try Game.create(gpa, h.platform());
        g.fixes = args.fixes;
        if (args.one_button) one_button.enable(g);
        defer g.destroy();
        if (args.trace != null) g.trace = &trace;
        try run(g, &hn, args.ms);
    } else {
        var s: platform.sdl.Sdl = undefined;
        try s.init(gpa, io, args.opts);
        defer s.deinit();
        hn.sdl = &s;
        const g = try Game.create(gpa, s.platform());
        g.fixes = args.fixes;
        if (args.one_button) one_button.enable(g);
        defer g.destroy();
        if (args.trace != null) g.trace = &trace;
        try run(g, &hn, null);
    }

    if (args.trace) |path| {
        try std.Io.Dir.cwd().writeFile(io, .{ .sub_path = path, .data = trace.items });
    }
    if (hn.failed or hn.script.timed_out) {
        std.log.err("an expect of the input script failed", .{});
        std.process.exit(1);
    }
}

/// WinMain + app_message_loop. `stop_at`: headless time limit.
fn run(g: *Game, hn: *platform.harness.Harness, stop_at: ?u32) !void {
    current_game = g;
    defer current_game = null;
    if (comptime @hasDecl(units.app, "wndProc")) {
        g.wndProc = units.app.wndProc;
    } else {
        std.log.warn("the app unit is not ported yet: nothing to run", .{});
        return;
    }
    // app_init/CreateWindow (sends WM_CREATE) once the app unit exists.
    if (comptime @hasDecl(units.app, "start")) try units.app.start(g);
    hn.afterStart(g);

    // The virtual clock stands still while messages are dispatched: a
    // message that keeps re-posting itself would spin here for ever.
    var storm_tick: u32 = 0;
    var storm_count: u32 = 0;
    while (!g.quit) {
        if (g.plat.ticks() != storm_tick) {
            storm_tick = g.plat.ticks();
            storm_count = 0;
        } else if (storm_count > 50_000) {
            @panic("message storm: 50000 messages without the clock moving (a hang)");
        }
        storm_count += 1;
        while (g.plat.poll()) |ev| deliver(g, ev);
        if (g.dispatchPending()) {
            hn.noteScene(g);
            continue;
        }
        units.game_input.showDrag(g);
        g.plat.present();
        if (hn.step(g)) continue;
        if (stop_at) |limit| if (g.plat.ticks() >= limit) break;
        var due = g.queue.nextDue();
        if (hn.nextDue()) |t| due = if (due) |d| @min(d, t) else t;
        if (stop_at) |limit| due = if (due) |d| @min(d, limit) else limit;
        g.plat.wait(due);
    }
    // WinMain calls app_exit after the message loop (also when the headless
    // time limit ends the run).
    if (comptime @hasDecl(units.app, "exit")) {
        current_game = null; // the scene goes away: no report from here on
        units.app.exit(g);
        units.app.reclaimLeaks(g);
    }
}

/// A platform event, as Windows would hand it to the game.
fn deliver(g: *Game, ev: platform.api.Event) void {
    switch (ev) {
        // Closing the window sends WM_CLOSE (through the game first, then
        // DefWindowProc → DestroyWindow → WM_DESTROY).
        .quit => _ = g.send(.{ .id = wm.close }),
        // WM_ACTIVATE is sent, not posted.
        .activate => |on| _ = g.send(.{ .id = wm.activate, .wparam = @intFromBool(on) }),
        .input => |m| if (g.plat.filterInput(m)) |in| g.queue.postInput(in),
        .message => |m| if (!g.post(m)) std.log.warn("posted queue full: message {x} lost", .{m.id}),
    }
}

test {
    // Pulls in every port unit's tests (the index is generated) and the core.
    _ = @import("units.zig");
    _ = one_button;
    std.testing.refAllDecls(core);
    std.testing.refAllDecls(platform.sim);
    std.testing.refAllDecls(platform.headless);
    std.testing.refAllDecls(platform.font);
    std.testing.refAllDecls(platform.flic);
    std.testing.refAllDecls(platform.midi);
    std.testing.refAllDecls(platform.mixer);
    std.testing.refAllDecls(platform.png);
    std.testing.refAllDecls(platform.script);
}
