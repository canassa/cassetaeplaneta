//! Noite Animal in a browser: the wasm32-wasi root (`zig build web`). The
//! page (`web/noite.js`) downloads the disc's files, then calls
//! `noite_start` once and `noite_frame` on every animation frame; input
//! and audio go through the other exports.
//!
//! `noite_frame` is one turn of `main.zig`'s message loop without the
//! wait: deliver the platform's events, dispatch every message that is
//! due, present. The browser's frame callback replaces WaitMessage, so the
//! game logic and the message order are the native ones.

const std = @import("std");
const Game = @import("core/game.zig").Game;
const wm = @import("core/msg.zig").wm;
const api = @import("platform/platform.zig");
const web = @import("platform/web.zig");
const mixer = @import("platform/mixer.zig");
const harness = @import("platform/harness.zig");
const report = @import("platform/report.zig");
const units = @import("units.zig");
const one_button = @import("one_button.zig");

pub const std_options: std.Options = .{ .logFn = log };

fn log(comptime level: std.log.Level, comptime scope: @EnumLiteral(), comptime format: []const u8, args: anytype) void {
    _ = scope;
    var buf: [1024]u8 = undefined;
    const text = std.fmt.bufPrint(&buf, format, args) catch buf[0..];
    web.js.js_log(@backingInt(level), text.ptr, text.len);
}

pub const panic = std.debug.FullPanic(panicWithReport);

fn panicWithReport(text: []const u8, first_trace_addr: ?usize) noreturn {
    if (game) |g| {
        game = null; // a panic inside the report must not recurse
        harness.report(g);
    }
    std.debug.defaultPanic(text, first_trace_addr orelse @returnAddress());
}

const gpa = std.heap.c_allocator;
var backend: web.Web = undefined;
var game: ?*Game = null;
var audio_buf: [8192 * 2]i16 = undefined;

/// wasi-libc's start code references `main`; a reactor never calls it.
export fn __main_argc_argv(argc: c_int, argv: ?*anyopaque) c_int {
    _ = argc;
    _ = argv;
    return 0;
}

/// WinMain up to the message loop. 0 on success. The page's options:
/// `fixes` turns every BUGS.md fix on (`--fix all`, the "Corrigida"
/// version), `skip_videos` lets a click or Esc/Enter/Space end a video
/// (`--skip-videos`), `one_button` plays with the left button or touch
/// alone (`--one-button`).
export fn noite_start(fixes: bool, skip_videos: bool, one_button_mode: bool) i32 {
    backend.init(gpa, skip_videos);
    const g = Game.create(gpa, backend.platform()) catch return 1;
    game = g;
    if (fixes) g.fixes = .all();
    if (one_button_mode) one_button.enable(g);
    g.wndProc = units.app.wndProc;
    units.app.start(g) catch |e| {
        std.log.err("app start: {t}", .{e});
        return 2;
    };
    return 0;
}

/// One turn of the message loop. Returns 1 once the game has quit (after
/// app_exit), 0 otherwise.
export fn noite_frame() i32 {
    const g = game orelse return 1;
    // Like main.zig: the clock stands still while messages are dispatched,
    // so a message that keeps re-posting itself would never let go; give
    // the page its frame back after a while instead.
    var budget: u32 = 50_000;
    while (!g.quit and budget > 0) : (budget -= 1) {
        while (g.plat.poll()) |ev| deliver(g, ev);
        if (!g.dispatchPending()) break;
    }
    if (budget == 0) std.log.warn("message storm: 50000 messages in one frame", .{});
    if (g.quit) {
        game = null;
        units.app.exit(g);
        units.app.reclaimLeaks(g);
        backend.show();
        return 1;
    }
    units.game_input.showDrag(g);
    g.plat.present();
    backend.show();
    return 0;
}

/// A platform event, as Windows would hand it to the game (main.zig).
fn deliver(g: *Game, ev: api.Event) void {
    switch (ev) {
        .quit => _ = g.send(.{ .id = wm.close }),
        .activate => |on| _ = g.send(.{ .id = wm.activate, .wparam = @intFromBool(on) }),
        .input => |m| if (g.plat.filterInput(m)) |in| g.queue.postInput(in),
        .message => |m| _ = g.post(m),
    }
}

export fn noite_mouse(kind: u32, button: u32, x: u32, y: u32) void {
    backend.mouse(@truncate(kind), @truncate(button), @truncate(@min(x, 0xffff)), @truncate(@min(y, 0xffff)));
}

/// `code`: KeyboardEvent.keyCode; only `web.Key`s are passed on.
export fn noite_key(down: bool, code: u32) void {
    const k = std.enums.fromInt(web.Key, code) orelse return;
    backend.key(down, k);
}

export fn noite_focus(on: bool) void {
    backend.focus(on);
}

export fn noite_close() void {
    backend.close();
}

/// Mixes `frames` frames (≤ 8192) of 44.1 kHz stereo s16; returns where
/// they are in memory.
export fn noite_audio(frames: u32) [*]const i16 {
    const n = @as(usize, @min(frames, audio_buf.len / 2)) * 2;
    backend.sim.mix.render(audio_buf[0..n]);
    return &audio_buf;
}

export fn noite_audio_rate() u32 {
    return mixer.out_rate;
}

/// Test hook (tools/web/test.py): the options `noite_start` got, as bits
/// (1: every fix on, 2: skip videos, 4: one button); -1 before the start.
export fn noite_options() i32 {
    const g = game orelse return -1;
    const all = std.meta.eql(g.fixes, .all());
    return @as(i32, @intFromBool(all)) | @as(i32, @intFromBool(backend.sim.opts.skip_videos)) << 1 |
        @as(i32, @intFromBool(g.oneButton.filter != null)) << 2;
}

/// Test hook (tools/web/test.py): the number of items the player carries
/// (-1 before the start or without a player object).
export fn noite_inventory() i32 {
    const g = game orelse return -1;
    const p = g.player orelse return -1;
    return p.actor.inventory.count;
}

/// Test hook (tools/web/test.py): the current INI scene's name, NUL
/// terminated ("" before the first scene).
export fn noite_scene() [*]const u8 {
    const g = game orelse return "";
    const s = g.scene orelse return "";
    return &s.name;
}

var report_text: []u8 = &.{};

/// The state report (src/platform/report.zig) as JSON text; its length is
/// `noite_report_len`. Valid until the next call. "" before the start.
export fn noite_report() [*]const u8 {
    gpa.free(report_text);
    report_text = &.{};
    const g = game orelse return "";
    report_text = report.alloc(g, gpa) catch &.{};
    return report_text.ptr;
}

export fn noite_report_len() u32 {
    return @intCast(report_text.len);
}

/// The game clock (`ticks()`, ms since the start), for a snapshot.
export fn noite_ticks() u32 {
    const g = game orelse return 0;
    return g.plat.ticks();
}

/// What a snapshot may leave out (zeroed): the SoundFont's decoded
/// samples, two thirds of the memory, which `noite_resume` decodes again.
/// `noite_snapshot_skip_len` is 0 without a SoundFont.
export fn noite_snapshot_skip() usize {
    const syn = backend.synth orelse return 0;
    return @intFromPtr(syn.samples().ptr);
}

export fn noite_snapshot_skip_len() u32 {
    const syn = backend.synth orelse return 0;
    return @intCast(syn.samples().len);
}

/// After the page copied a snapshot of the whole memory over a fresh
/// instance (between frames, so no Zig frame was live): the clock goes on
/// from `ticks` (the page clock is a new one), the SoundFont's samples are
/// decoded again if the snapshot left them out (`refill`), and the next
/// frame shows the screen. Everything else is in the memory, the files the
/// game has open included (`Sim` holds their bytes). 0 on success.
export fn noite_resume(ticks: u32, refill: bool) i32 {
    backend.epoch_ms = web.js.js_now() - @as(f64, @floatFromInt(ticks));
    backend.dirty = true;
    if (refill) if (backend.synth) |*syn| {
        const sf2 = backend.sim.opts.host_files.?.read(&backend, gpa, "soundfont.sf2") orelse return 1;
        // Zeroed before it is freed: freed memory keeps its bytes, and the
        // next snapshot of this game would carry them.
        defer {
            @memset(sf2, 0);
            gpa.free(sf2);
        }
        syn.refill(sf2) catch return 2;
    };
    return 0;
}
