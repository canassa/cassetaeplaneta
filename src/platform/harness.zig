//! The test harness around the main loop (debug code, not a port unit):
//! scripted input (`--input`), frame dumps (`--dump DIR`, `--dump-every`),
//! jumping into a scene (`--scene`), a log of scene changes, and the panic
//! report with the last messages (`report`).

const std = @import("std");
const Game = @import("../core/game.zig").Game;
const cstr = @import("../core/cstr.zig");
const msg = @import("../core/msg.zig");
const p = @import("platform.zig");
const png = @import("png.zig");
const script = @import("script.zig");
const game_scenes = @import("../game_scenes.zig");
const avi = @import("../avi.zig");
const sound = @import("../sound.zig");
const portable = @import("../portable.zig");

pub const Options = struct {
    input: ?[]const u8 = null,
    dump_dir: ?[]const u8 = null,
    /// Dump a frame every this many ms (0 = only `dump` commands).
    dump_every: u32 = 0,
    dump_bmp: bool = false,
    /// Start in this INI scene instead of the opening.
    scene: ?[]const u8 = null,
    /// Comma-separated portables (INI Numbers) to carry into `scene`.
    take: ?[]const u8 = null,
    /// Print scene changes and message boxes.
    verbose: bool = true,
};

pub const Harness = struct {
    gpa: std.mem.Allocator,
    io: std.Io,
    opts: Options,
    assets_dir: []const u8,
    script: script.Script = .{},
    next_dump: u32 = 0,
    dumps: u32 = 0,
    last_scene: [20]u8 = @splat(0),
    /// An `expect` failed.
    failed: bool = false,
    /// The time of the last `step`.
    now: u32 = 0,
    /// The SDL backend: each dump also writes what the window shows, read
    /// back from the renderer (`<name>-window.png`).
    sdl: ?*@import("sdl.zig").Sdl = null,

    pub fn init(gpa: std.mem.Allocator, io: std.Io, opts: Options, assets_dir: []const u8) !Harness {
        var h: Harness = .{ .gpa = gpa, .io = io, .opts = opts, .assets_dir = assets_dir };
        if (opts.input) |path| {
            const text = std.Io.Dir.cwd().readFileAlloc(io, path, gpa, .limited(1 << 20)) catch |e| {
                std.log.err("cannot read input script {s}: {t}", .{ path, e });
                return e;
            };
            h.script = try script.parse(gpa, text);
        }
        if (opts.dump_dir) |dir| std.Io.Dir.cwd().createDirPath(io, dir) catch |e| {
            std.log.err("cannot create dump directory {s}: {t}", .{ dir, e });
            return e;
        };
        return h;
    }

    pub fn deinit(h: *Harness) void {
        h.script.deinit(h.gpa);
    }

    /// After start-up: `--scene` replaces the opening scene before its
    /// 0x401 (posted, still queued) is dispatched.
    pub fn afterStart(h: *Harness, g: *Game) void {
        const name = h.opts.scene orelse return;
        g.queue.posted = .{};
        if (h.opts.take) |list| {
            var it = std.mem.tokenizeScalar(u8, list, ',');
            while (it.next()) |w| take(g, std.fmt.parseInt(i16, w, 10) catch continue);
        }
        h.jump(g, .{ .name = name });
    }

    /// The earliest time the harness needs the loop to wake up.
    pub fn nextDue(h: *const Harness) ?u32 {
        var t = h.script.nextAt(h.now);
        if (h.opts.dump_dir != null and h.opts.dump_every != 0) {
            t = if (t) |x| @min(x, h.next_dump) else h.next_dump;
        }
        return t;
    }

    /// Runs what is due at `now` once the queue is idle. True if it did
    /// anything (the caller dispatches again before waiting).
    pub fn step(h: *Harness, g: *Game) bool {
        h.noteScene(g);
        const now = g.plat.ticks();
        var did = false;
        if (h.opts.dump_dir != null and h.opts.dump_every != 0 and now >= h.next_dump) {
            h.dump(g, "");
            while (h.next_dump <= now) h.next_dump += h.opts.dump_every;
        }
        h.now = now;
        const scene_name = if (g.scene) |sc| cstr.slice(&sc.name) else "";
        while (h.script.due(now, scene_name)) |a| {
            did = true;
            switch (a) {
                .input => |m| g.queue.postInput(m),
                .dump => |name| h.dump(g, name),
                .scene => |j| h.jump(g, j),
                .log => |text| std.debug.print("[{d}] log: {s}\n", .{ now, text }),
                .state => printState(g),
                .expect => |name| {
                    const cur = if (g.scene) |sc| cstr.slice(&sc.name) else "";
                    if (std.ascii.eqlIgnoreCase(std.mem.trim(u8, cur, " "), name)) {
                        if (h.opts.verbose) std.debug.print("[{d}] expect {s}: ok\n", .{ now, name });
                    } else {
                        std.debug.print("[{d}] expect {s}: FAILED, the scene is {s}\n", .{ now, name, cur });
                        h.failed = true;
                    }
                },
                .wait => {},
                .take => |id| take(g, id),
                .quit => {
                    g.quit = true;
                    return true;
                },
            }
            // Input goes through the queue one message at a time, like
            // Windows: dispatch what this produced before the next step.
            if (a == .input) break;
        }
        return did;
    }

    pub fn noteScene(h: *Harness, g: *Game) void {
        const s = g.scene orelse return;
        if (std.mem.eql(u8, &s.name, &h.last_scene)) return;
        h.last_scene = s.name;
        if (h.opts.verbose) std.debug.print("[{d}] scene {s} (#{d}) lives {d} score {d}\n", .{
            g.plat.ticks(), cstr.slice(&s.name), s.sceneNumber, g.lives, g.score,
        });
    }

    /// Writes the screen to `<dir>/<n>-<ticks>[-name].png`.
    pub fn dump(h: *Harness, g: *Game, name: []const u8) void {
        const dir = h.opts.dump_dir orelse return;
        g.plat.present();
        var path_buf: [512]u8 = undefined;
        const ext = if (h.opts.dump_bmp) "bmp" else "png";
        const path = (if (name.len > 0)
            std.fmt.bufPrint(&path_buf, "{s}/{d:0>4}-{d:0>7}-{s}.{s}", .{ dir, h.dumps, g.plat.ticks(), name, ext })
        else
            std.fmt.bufPrint(&path_buf, "{s}/{d:0>4}-{d:0>7}.{s}", .{ dir, h.dumps, g.plat.ticks(), ext })) catch return;
        h.dumps += 1;
        writeScreen(h.gpa, h.io, g.plat.screen(), path, h.opts.dump_bmp) catch |e| {
            std.log.err("dump {s}: {t}", .{ path, e });
        };
        if (h.sdl) |s| {
            const px = h.gpa.create([p.screen_width * p.screen_height]u32) catch return;
            defer h.gpa.destroy(px);
            if (!s.readBack(px)) {
                std.log.err("dump: SDL read-back failed", .{});
                return;
            }
            var out: std.ArrayList(u8) = .empty;
            defer out.deinit(h.gpa);
            png.encodeRgbPng(h.gpa, px, &out) catch return;
            var wbuf: [520]u8 = undefined;
            const wpath = std.fmt.bufPrint(&wbuf, "{s}-window.png", .{path[0 .. path.len - 4]}) catch return;
            std.Io.Dir.cwd().writeFile(h.io, .{ .sub_path = wpath, .data = out.items }) catch |e| std.log.err("dump {s}: {t}", .{ wpath, e });
        }
    }

    /// Switches to an INI scene. Without flags: those of the first exit
    /// (or handler switch) that leads there, else no player/panel/bar.
    pub fn jump(h: *Harness, g: *Game, j: script.SceneJump) void {
        const f = j.flags orelse h.flagsFor(j.name);
        // An AVI still playing belongs to the old scene: close it as its
        // end would (MM_MCINOTIFY handling in the scene unit).
        if (g.aviPlaying) |playing| {
            avi.closeAvi(g, playing, playing.anim.aviDevice);
            g.aviPlaying = null;
            _ = sound.mixInit(g);
        }
        // The options/slot screens return to the saved position, which the
        // panel records on the way in: give a direct jump one to return to.
        if (g.savedPosition.scene[0] == 0) {
            cstr.copy(&g.savedPosition.scene, "1fquarbo");
            g.savedPosition.playerX = 240;
            g.savedPosition.playerY = 250;
            g.savedPosition.hasPlayer = 1;
            g.savedPosition.hasControlPanel = 1;
        }
        if (h.opts.verbose) std.debug.print("[{d}] jump to {s} at ({d},{d}) player {d} panel {d} bar {d}\n", .{
            g.plat.ticks(), j.name, f.x, f.y, f.player, f.panel, f.status,
        });
        _ = game_scenes.switchScene(g, j.name, f.x, f.y, f.player, f.panel, f.status, f.anim, f.click);
    }

    /// Flags for entering `name`: an INI `Exit=`/`2Exit=` line that leads
    /// there, else a `switchScene(g, "name", …)` call in a handler source.
    pub fn flagsFor(h: *Harness, name: []const u8) script.SceneJump.Flags {
        if (h.iniFlags(name)) |f| return f;
        if (h.handlerFlags(name)) |f| return f;
        return .{};
    }

    fn iniFlags(h: *Harness, name: []const u8) ?script.SceneJump.Flags {
        var path_buf: [512]u8 = undefined;
        const path = std.fmt.bufPrint(&path_buf, "{s}/CASSETA.INI", .{h.assets_dir}) catch return null;
        const text = std.Io.Dir.cwd().readFileAlloc(h.io, path, h.gpa, .limited(1 << 20)) catch return null;
        defer h.gpa.free(text);
        var lines = std.mem.splitScalar(u8, text, '\n');
        while (lines.next()) |raw| {
            const line = std.mem.trim(u8, raw, " \t\r");
            const two = std.mem.startsWith(u8, line, "2Exit=");
            if (!two and !std.mem.startsWith(u8, line, "Exit=")) continue;
            var fields: [32][]const u8 = undefined;
            var n: usize = 0;
            var it = std.mem.splitScalar(u8, line[std.mem.indexOfScalar(u8, line, '=').? + 1 ..], ',');
            while (it.next()) |fld| : (n += 1) {
                if (n == fields.len) break;
                fields[n] = std.mem.trim(u8, fld, " \t");
            }
            if (n < 23) continue;
            const hits_main = std.ascii.eqlIgnoreCase(fields[17], name);
            const hits_alt = two and n >= 28 and std.ascii.eqlIgnoreCase(fields[25], name);
            if (!hits_main and !hits_alt) continue;
            const xi: usize = if (hits_main) 18 else 26;
            return .{
                .x = std.fmt.parseInt(i16, fields[xi], 10) catch 0,
                .y = std.fmt.parseInt(i16, fields[xi + 1], 10) catch 0,
                .player = boolField(fields[20]),
                .panel = boolField(fields[21]),
                .status = boolField(fields[22]),
            };
        }
        return null;
    }

    fn boolField(s: []const u8) i16 {
        const v = std.fmt.parseInt(i16, s, 10) catch return 0;
        return @intFromBool(v != 0);
    }

    fn handlerFlags(h: *Harness, name: []const u8) ?script.SceneJump.Flags {
        var dir = std.Io.Dir.cwd().openDir(h.io, "src/handlers", .{ .iterate = true }) catch return null;
        defer dir.close(h.io);
        var it = dir.iterate();
        var needle_buf: [64]u8 = undefined;
        const needle = std.fmt.bufPrint(&needle_buf, "switchScene(g, \"{s}\", ", .{name}) catch return null;
        while (it.next(h.io) catch null) |e| {
            if (!std.mem.endsWith(u8, e.name, ".zig")) continue;
            const text = dir.readFileAlloc(h.io, e.name, h.gpa, .limited(1 << 20)) catch continue;
            defer h.gpa.free(text);
            const at = std.mem.indexOf(u8, text, needle) orelse continue;
            const rest = text[at + needle.len ..];
            const end = std.mem.indexOfScalar(u8, rest, ')') orelse continue;
            var nums: [7]i16 = @splat(0);
            var k: usize = 0;
            var words = std.mem.tokenizeAny(u8, rest[0..end], ", ");
            while (words.next()) |w| : (k += 1) {
                if (k == nums.len) break;
                nums[k] = std.fmt.parseInt(i16, w, 0) catch return null;
            }
            if (k < 5) continue;
            return .{ .x = nums[0], .y = nums[1], .player = nums[2], .panel = nums[3], .status = nums[4] };
        }
        return null;
    }
};

pub fn writeScreen(gpa: std.mem.Allocator, io: std.Io, scr: *const p.Screen, path: []const u8, bmp: bool) !void {
    var out: std.ArrayList(u8) = .empty;
    defer out.deinit(gpa);
    if (bmp) try png.encodeBmp(gpa, scr, &out) else try png.encodePng(gpa, scr, &out);
    try std.Io.Dir.cwd().writeFile(io, .{ .sub_path = path, .data = out.items });
}

/// Test helper: portable `id` goes into the player's inventory, as a pick
/// up would put it (only from another scene's global objects).
fn take(g: *Game, id: i16) void {
    const player = g.player orelse return;
    var it = g.globalObjects.head;
    while (it) |o| : (it = o.next) {
        if (o.id != id or !o.is(.portable)) continue;
        if (g.scene) |s| if (std.ascii.eqlIgnoreCase(std.mem.trim(u8, cstr.slice(&o.sceneName), " "), std.mem.trim(u8, cstr.slice(&s.name), " "))) {
            std.debug.print("take {d}: it is in the current scene, pick it up instead\n", .{id});
            return;
        };
        _ = portable.pickUp(g, o, player);
        return;
    }
    std.debug.print("take {d}: no such portable in the global objects\n", .{id});
}

/// One line: scene, player position, inventory ids, held item, lives, score.
pub fn printState(g: *const Game) void {
    var buf: [256]u8 = undefined;
    var w: std.Io.Writer = .fixed(&buf);
    if (g.player) |pl| {
        w.print("player ({d},{d}) inv [", .{ pl.x, pl.y }) catch {};
        var it = pl.actor.inventory.head;
        while (it) |o| : (it = o.next) w.print(" {d}", .{o.id}) catch {};
        w.writeAll(" ]") catch {};
    }
    if (g.selectedItem) |sel| w.print(" held {d}", .{sel.id}) catch {};
    const name = if (g.scene) |s| cstr.slice(&s.name) else "-";
    std.debug.print("[{d}] state: scene {s} {s} lives {d} score {d}\n", .{ g.plat.ticks(), name, w.buffered(), g.lives, g.score });
}

/// The panic report: the current scene and the last messages, oldest first.
pub fn report(g: *const Game) void {
    std.debug.print("\n=== noite panic report ===\n", .{});
    if (g.scene) |s| std.debug.print("scene {s} (#{d}), ticks {d}\n", .{ cstr.slice(&s.name), s.sceneNumber, g.plat.ticks() }) else std.debug.print("no scene\n", .{});
    std.debug.print("last messages (S sent, Q queued; indent = SendMessage depth):\n", .{});
    for (0..g.trail.size()) |i| {
        const e = g.trail.get(i);
        var pad: [16]u8 = @splat(' ');
        std.debug.print("  {d:>8} {c} {s}{s} {x:0>4} {x:0>8}\n", .{
            e.at, e.how, pad[0..@min(@as(usize, e.depth) * 2, pad.len)], msgName(e.m.id), e.m.wparam, @as(u32, @bitCast(e.m.lparam)),
        });
    }
    std.debug.print("=== end of report ===\n", .{});
}

pub fn msgName(id: u16) []const u8 {
    const wm = msg.wm;
    const nt = msg.noite;
    return switch (id) {
        wm.create => "WM_CREATE     ",
        wm.destroy => "WM_DESTROY    ",
        wm.activate => "WM_ACTIVATE   ",
        wm.paint => "WM_PAINT      ",
        wm.close => "WM_CLOSE      ",
        wm.activateapp => "WM_ACTIVATEAPP",
        wm.keydown => "WM_KEYDOWN    ",
        wm.keyup => "WM_KEYUP      ",
        wm.timer => "WM_TIMER      ",
        wm.systimer => "WM_SYSTIMER   ",
        wm.mousemove => "WM_MOUSEMOVE  ",
        wm.lbuttondown => "WM_LBUTTONDOWN",
        wm.lbuttonup => "WM_LBUTTONUP  ",
        wm.rbuttondown => "WM_RBUTTONDOWN",
        wm.rbuttonup => "WM_RBUTTONUP  ",
        wm.querynewpalette => "WM_QUERYNEWPAL",
        wm.mm_mcinotify => "MM_MCINOTIFY  ",
        wm.mm_wom_done => "MM_WOM_DONE   ",
        nt.scene_started => "scene_started ",
        nt.exit_finished => "exit_finished ",
        nt.animation_finished => "anim_finished ",
        nt.movement_finished => "move_finished ",
        nt.player_stepped => "player_stepped",
        nt.object_created => "object_created",
        nt.minigame_result => "minigame_resul",
        nt.minigame_hello => "minigame_hello",
        nt.minigame_ready => "minigame_ready",
        nt.unlock_input => "unlock_input  ",
        else => "?             ",
    };
}
