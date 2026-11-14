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
const game_input = @import("../game_input.zig");
const Object = @import("../core/object.zig").Object;
const frames = @import("../frames.zig");
const dib = @import("../dib.zig");
const occupancy = @import("../behaviour/occupancy.zig");
const movement = @import("../behaviour/movement.zig");
const object = @import("../core/object.zig");
const report_json = @import("report.zig");

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
    /// The offer check (`watchOffers`).
    offer: OfferWatch = .{},

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
        h.watchOffers(g, now);
        const scene_name = if (g.scene) |sc| cstr.slice(&sc.name) else "";
        while (h.script.due(now, scene_name)) |a| {
            did = true;
            switch (a) {
                .input => |m| {
                    if (m.id == msg.wm.rbuttondown or m.id == msg.wm.lbuttondown) h.offer.clicked = true;
                    if (g.plat.filterInput(m)) |in| g.queue.postInput(in);
                },
                .dump => |name| h.dump(g, name),
                .scene => |j| h.jump(g, j),
                .log => |text| std.debug.print("[{d}] log: {s}\n", .{ now, text }),
                .state => printState(g),
                .report => |path| writeReportFile(h, g, path),
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
                .drawn => |d| h.checkDrawn(g, d),
                .where => |id| printWhere(g, id),
                .focus => |on| _ = g.send(.{ .id = msg.wm.activate, .wparam = @intFromBool(on) }),
                .freeze => |ms| {
                    std.debug.print("[{d}] freeze {d} ms\n", .{ now, ms });
                    g.plat.freeze(ms);
                    // Back to the loop: what fell due is polled at once.
                    return true;
                },
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
        game_input.showDrag(g);
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
            const px = h.gpa.create([p.client_width * p.client_height]u32) catch return;
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
            if (tableFlags(text, name)) |f| return f;
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

    /// Watches each dropped item until a handler takes it back (to the
    /// inventory, or consumed): with B30's fix it must not have moved from
    /// where it was released (an offer stays in the character's hands), and
    /// with B25's its image must be gone from the screen a second later. A
    /// drop picked up again by a click is not checked. Either failure fails
    /// the run.
    fn watchOffers(h: *Harness, g: *Game, now: u32) void {
        const w = &h.offer;
        const scene = g.scene orelse {
            w.item = null;
            return;
        };
        if (w.item) |it| watch: {
            if (!std.mem.eql(u8, &scene.name, &w.scene)) {
                w.item = null;
                break :watch;
            }
            const bd = scene.backdrop orelse break :watch;
            if (w.back_at == null) {
                if (isOut(g, it)) {
                    if (it.visible != 0) {
                        if (it.x != w.x0 or it.y != w.y0) w.moved = true;
                        w.last = .of(it, bd);
                    }
                    break :watch;
                }
                w.back_at = now;
                if (h.opts.verbose) std.debug.print("[{d}] offer check: item {d} taken back{s}\n", .{ now, it.id, if (w.clicked) " after a click" else if (w.moved) "" else " where it was released" });
                // Without B30's fix the original's drop may walk it to a
                // support's top (or the floor) while the reply plays.
                if (w.moved and !w.clicked and g.fixes.drop_falls_onto_support) {
                    std.debug.print("[{d}] offer check: item {d} moved from ({d},{d}) to ({d},{d}) before it was taken back\n", .{ now, it.id, w.x0, w.y0, it.x, it.y });
                    h.failed = true;
                }
            } else if (now -% w.back_at.? >= 1000) {
                // Without B25's fix the take-back misses an image the drop
                // left where it was released, as in the original.
                if (!w.clicked and g.fixes.drop_syncs_previous_position) h.checkLeftover(g, it);
                w.item = null;
            }
        }
        if (w.held) |held| if (g.itemSelected == 0 and isOut(g, held) and held.visible != 0 and w.item != held) {
            w.* = .{ .item = held, .x0 = held.x, .y0 = held.y, .scene = scene.name };
            if (scene.backdrop) |bd| w.last = .of(held, bd);
        };
        w.held = if (g.itemSelected != 0) g.selectedItem else null;
    }

    /// An item lying in the scene (not in an inventory or consumed).
    fn isOut(g: *const Game, it: *const Object) bool {
        return it.is(.portable) and it.portable.owner == null and it.ownerList == &g.globalObjects;
    }

    /// Fails the run when most of the taken-back item's last image is still
    /// on the screen.
    fn checkLeftover(h: *Harness, g: *Game, it: *Object) void {
        const last = h.offer.last;
        const s = h.onScreen(g, last) orelse return;
        if (s.shown()) {
            std.debug.print("[{d}] offer check: item {d} taken back but {d} of its {d} pixels are still on the screen at ({d},{d})\n", .{ g.plat.ticks(), it.id, s.same, s.total, last.x, last.y });
            h.failed = true;
        }
    }

    /// `drawn ID 0|1`: fails the run unless portable `id` is (or is not) on
    /// the screen: visible, with most of its frame showing where it stands.
    fn checkDrawn(h: *Harness, g: *Game, d: script.Drawn) void {
        const bd = (g.scene orelse return).backdrop orelse return;
        var it = g.globalObjects.head;
        const o = while (it) |o| : (it = o.next) {
            if (o.id == d.id and o.is(.portable)) break o;
        } else null;
        const drawn = if (o) |obj| obj.visible != 0 and if (h.onScreen(g, .of(obj, bd))) |s| s.shown() else false else false;
        if (drawn == d.on) return;
        std.debug.print("[{d}] drawn {d}: FAILED, it is {s}on the screen\n", .{ g.plat.ticks(), d.id, if (drawn) "" else "not " });
        h.failed = true;
    }

    const Match = struct {
        same: u32,
        total: u32,
        fn shown(m: Match) bool {
            return m.total >= 20 and m.same * 10 >= m.total * 6;
        }
    };

    /// How many of `img`'s opaque pixels the screen shows.
    fn onScreen(h: *Harness, g: *Game, img: OfferWatch.Image) ?Match {
        const d = img.dib orelse return null;
        const buf = h.gpa.alloc(u8, p.screen_width * p.screen_height) catch return null;
        defer h.gpa.free(buf);
        const key = g.unk001C;
        @memset(buf, key);
        const hdr: dib.BitmapInfoHeader = .{ .biWidth = p.screen_width, .biHeight = -p.screen_height };
        _ = dib.copyTransparent(&hdr, buf, img.x, img.y, d.bits, &d.header, img.src_x, img.src_y, img.w, img.orient *% img.h, key) catch return null;
        const scr = g.plat.screen();
        var m: Match = .{ .same = 0, .total = 0 };
        for (0..p.client_height) |y| for (0..p.client_width) |x| {
            const c = buf[y * p.screen_width + x];
            if (c == key) continue;
            m.total += 1;
            if (scr.pixels[y * p.screen_width + x] == c) m.same += 1;
        };
        return m;
    }

    /// 2fpontoc's destination table, `N => .{ "name", panel, anim },`
    /// (the switch after it enters at (0,0) without the player).
    fn tableFlags(text: []const u8, name: []const u8) ?script.SceneJump.Flags {
        var needle_buf: [64]u8 = undefined;
        const needle = std.fmt.bufPrint(&needle_buf, "=> .{{ \"{s}\", ", .{name}) catch return null;
        const at = std.mem.indexOf(u8, text, needle) orelse return null;
        const rest = text[at + needle.len ..];
        const end = std.mem.indexOfScalar(u8, rest, '}') orelse return null;
        var words = std.mem.tokenizeAny(u8, rest[0..end], ", ");
        const panel = std.fmt.parseInt(i16, words.next() orelse return null, 0) catch return null;
        const anim = std.fmt.parseInt(i16, words.next() orelse return null, 0) catch return null;
        return .{ .panel = panel, .anim = anim };
    }
};

/// `Harness.watchOffers`' state.
const OfferWatch = struct {
    /// The item selected at the last step.
    held: ?*Object = null,
    /// The dropped item being watched, where it was released and the
    /// scene it was dropped in.
    item: ?*Object = null,
    x0: i16 = 0,
    y0: i16 = 0,
    scene: [20]u8 = @splat(0),
    /// Its last image seen.
    last: Image = .{},
    moved: bool = false,
    /// A click came after the drop (the player may have picked it up).
    clicked: bool = false,
    /// When a handler took it back.
    back_at: ?u32 = null,

    /// Where and what an object's frame was on the screen (its pick-up
    /// changes its strip and clears its DIB orientation).
    const Image = struct {
        dib: ?*const dib.Dib = null,
        x: i16 = 0,
        y: i16 = 0,
        src_x: i16 = 0,
        src_y: i16 = 0,
        w: i16 = 0,
        h: i16 = 0,
        orient: i16 = 0,

        fn of(o: *const Object, bd: *const @import("../core/world.zig").Backdrop) Image {
            return .{
                .dib = frames.dib(o),
                .x = o.x -% bd.originX,
                .y = o.y -% bd.originY,
                .src_x = frames.frameSrcX(o),
                .src_y = frames.frameSrcY(o),
                .w = frames.width(o),
                .h = frames.height(o),
                .orient = @truncate(o.dibFormatOk),
            };
        }
    };
};

/// `report FILE`: the state report as JSON (src/platform/report.zig).
fn writeReportFile(h: *Harness, g: *Game, path: []const u8) void {
    const text = report_json.alloc(g, h.gpa) catch return;
    defer h.gpa.free(text);
    std.Io.Dir.cwd().writeFile(h.io, .{ .sub_path = path, .data = text }) catch |e| {
        std.debug.print("report {s}: {t}\n", .{ path, e });
        return;
    };
    if (h.opts.verbose) std.debug.print("[{d}] report {s}\n", .{ h.now, path });
}

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
        // Its scene's attach (on a visit) binds it to the backdrop format;
        // without it the item is drawn 0 rows high wherever it is dropped.
        if (o.attached == 0) if (g.scene) |s| if (s.backdrop) |bd| {
            o.attached = 1;
            occupancy.bindToBackdrop(o, bd);
        };
        return;
    }
    std.debug.print("take {d}: no such portable in the global objects\n", .{id});
}

/// One line: scene, player position, inventory ids, held item, lives, score.
/// `where ID`: which list holds portable `id`, its scene names, position,
/// visibility and whether it is moving.
fn printWhere(g: *Game, id: i16) void {
    const now = g.plat.ticks();
    const lists = [_]struct { []const u8, ?*const object.ObjectList }{
        .{ "scene", &g.globalObjects },
        .{ "carried", if (g.player) |pl| &pl.actor.inventory else null },
        .{ "used", &g.usedObjects },
    };
    for (lists) |entry| {
        const list = entry[1] orelse continue;
        var it = list.head;
        while (it) |o| : (it = o.next) {
            if (o.id != id or !o.is(.portable)) continue;
            std.debug.print("[{d}] where {d}: {s} scene '{s}' prev '{s}' at ({d},{d}) visible {d} moving {}\n", .{
                now, id, entry[0], cstr.slice(&o.sceneName), cstr.slice(&o.portable.prevSceneName), o.x, o.y, o.visible, movement.isMoving(g, o),
            });
            return;
        }
    }
    std.debug.print("[{d}] where {d}: in no list\n", .{ now, id });
}

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
    std.debug.print("\n=== noite panic report ===\nticks {d}; last messages (S sent, Q queued; indent = SendMessage depth):\n", .{g.plat.ticks()});
    for (0..g.trail.size()) |i| {
        const e = g.trail.get(i);
        var pad: [16]u8 = @splat(' ');
        std.debug.print("  {d:>8} {c} {s}{s} {x:0>4} {x:0>8}\n", .{
            e.at, e.how, pad[0..@min(@as(usize, e.depth) * 2, pad.len)], msgName(e.m.id), e.m.wparam, @as(u32, @bitCast(e.m.lparam)),
        });
    }
    // Last: the scene pointer may be the dangling one that crashed.
    if (g.scene) |s| std.debug.print("scene {s} (#{d})\n", .{ cstr.slice(&s.name), s.sceneNumber }) else std.debug.print("no scene\n", .{});
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
