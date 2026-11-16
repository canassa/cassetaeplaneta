//! Not in the original: what the Corrigida adds to SERIAL, in front of the game
//! (docs/serial/GAME.md "The Corrigida"). Nothing here runs without its flag, and
//! none of it draws into the window's screen or the backdrop but the lives' box
//! (as the score is): the host asks for the picture to present
//! (`host.Program.view`), and `view` returns a copy of the screen with the screens
//! and signs over it.
//!
//! - `Fixes.serial_intro_screen`: from WM_CREATE a screen says who to shoot, who
//!   shoots back and the keys. The game gets no input and no timer until a key or
//!   a click takes it down (the spawns and the clock are stopped, and start then).
//!   `app.wndProc` hands every message to `gate` first.
//! - `Fixes.serial_killer_warning`: a killer (kind 2) telegraphs its shot for
//!   `warn_steps` walk steps before the step that fires it: `CARREGA.WAV` plays as
//!   the warning starts, and until the shot a blinking frame and a "!" show on it.
//!   A hit stops the figure, so the shot never comes; the sign is read off the
//!   figure's own frame, there is no state of its own.
//! - `Fixes.serial_shot_flash`: the screen's edge flashes red when a shot lands.
//! - `Fixes.serial_end_screen`: the lives running out or the clock ending (`finish`,
//!   in place of the original's WM_DESTROY) put a screen up for 3 s or until a key;
//!   WM_DESTROY, and with it the 0x40a result, goes then.
//! - `Fixes.serial_lives_display`: `target.drawLives`.

const std = @import("std");
const msg = @import("../core/msg.zig");
const Msg = msg.Msg;
const wm = msg.wm;
const platform = @import("../platform/platform.zig");
const Screen = platform.Screen;
const screen = @import("../core/controls_screen.zig");
const Game = @import("core/game.zig").Game;
const object = @import("core/object.zig");
const Object = object.Object;
const world = @import("core/world.zig");
const Backdrop = world.Backdrop;
const dib = @import("dib.zig");
const sound = @import("sound.zig");
const target = @import("target.zig");
const position = @import("behaviour/position.zig");

/// The end screen's timer (an id the game does not use) and its time.
pub const end_timer: u16 = 11;
pub const end_ms: u16 = 3000;

/// A killer's shot is announced this many walk steps (200 ms each) before.
pub const warn_steps: i16 = 3;
/// The strip frames from the end at which a killer's step fires the shot (the
/// original's test) and at which the warning starts.
const shot_left: i16 = 2;
const warn_left: i16 = shot_left + warn_steps;

/// The red flash after a shot: wide for `flash_wide_ms`, then thin, gone at `flash_ms`.
const flash_ms: u32 = 400;
const flash_wide_ms: u32 = 150;

/// The two killers' indices in `g.targets` (kind 2).
const killers = [_]usize{ 2, 9 };

// ---- opening, the gate, the end ----

/// WM_CREATE (after the scene is made): the intro screen goes up and the game's
/// timers stop until it goes.
pub fn open(g: *Game) void {
    if (!g.fixes.serial_intro_screen) return;
    g.corr.intro = true;
    target.disarmTimers(g);
}

fn isInput(id: u16) bool {
    return switch (id) {
        wm.keydown, wm.keyup, wm.mousemove, wm.lbuttondown, wm.lbuttonup, wm.rbuttondown, wm.rbuttonup, wm.systimer => true,
        else => false,
    };
}

/// The message the game gets instead of `m`, or null: kept from it.
pub fn gate(g: *Game, m: Msg) ?Msg {
    const c = &g.corr;
    if (c.end_up) {
        switch (m.id) {
            wm.keydown, wm.lbuttondown, wm.rbuttondown => {
                endNow(g);
                return null;
            },
            wm.systimer => {
                if (m.wparam == end_timer) endNow(g);
                return null;
            },
            else => return if (isInput(m.id)) null else m,
        }
    }
    if (c.intro) {
        switch (m.id) {
            wm.keydown => {
                dismiss(g, m.wparam);
                return null;
            },
            wm.lbuttondown, wm.rbuttondown => {
                dismiss(g, null);
                return null;
            },
            else => {},
        }
        return if (isInput(m.id)) null else m;
    }
    if (c.held_key) |k| if ((m.id == wm.keydown or m.id == wm.keyup) and m.wparam == k) {
        if (m.id == wm.keyup) c.held_key = null;
        return null;
    };
    return m;
}

/// The intro goes: the game's timers start now.
fn dismiss(g: *Game, key: ?u16) void {
    g.corr.intro = false;
    g.corr.held_key = key;
    target.armTimers(g);
}

/// The end of the game, where the original sends WM_DESTROY: with the end
/// screen, it goes up first.
pub fn finish(g: *Game) void {
    if (!g.fixes.serial_end_screen) {
        _ = g.send(.{ .id = wm.destroy });
        return;
    }
    if (g.corr.end_up) return;
    g.corr.end_up = true;
    g.setSystemTimer(end_timer, end_ms);
}

/// A key, a click or the time: the screen is done, the original's end runs.
fn endNow(g: *Game) void {
    if (g.corr.ended) return;
    g.corr.ended = true;
    g.killSystemTimer(end_timer);
    _ = g.send(.{ .id = wm.destroy });
}

/// The killers' shots stop once the game is over (two killers in the same tick
/// must not take the lives below the one that ended it).
pub fn over(g: *const Game) bool {
    return g.corr.end_up;
}

// ---- the killer's step ----

/// A killer's walk step has brought its frame to `left` from the strip's end
/// (`movement.targetMoveTick`): the warning starts.
pub fn stepped(g: *Game, left: i16) void {
    if (g.fixes.serial_killer_warning and left == warn_left) _ = sound.play(g, 0, g.corr.warn_wave);
}

/// The shot of a killer took a life (after `g.lives` went down).
pub fn shotLanded(g: *Game, bd: *Backdrop) void {
    if (g.fixes.serial_shot_flash) g.corr.shot_at = g.plat.ticks();
    if (g.fixes.serial_lives_display) {
        target.drawLives(g, bd);
        target.blitLivesBox(g, bd);
    }
}

/// `CARREGA.WAV`, opened with the others when the warning is on.
pub fn openWaves(g: *Game) void {
    if (g.fixes.serial_killer_warning) g.corr.warn_wave = sound.open(g, "CARREGA.WAV");
}

/// Is `t` (a killer) in its warning: walking, its frame from the one the warning
/// starts at to the one before the shot's.
fn warning(t: *Object) bool {
    if (t.mover.moving == 0) return false;
    const left = position.frameCount(t) -% t.curFrame;
    return left <= warn_left and left > shot_left;
}

fn anyWarning(g: *Game) bool {
    for (killers) |i| if (g.targets[i]) |t| if (warning(t)) return true;
    return false;
}

// ---- the picture ----

/// The picture to present at `now` (`host.Program.view`), or null for the screen
/// itself: nothing of the Corrigida is showing.
pub fn view(g: *Game, now: u32) ?*const Screen {
    const f = g.fixes;
    const c = &g.corr;
    const flash = f.serial_shot_flash and if (c.shot_at) |at| now -% at < flash_ms else false;
    const warn = f.serial_killer_warning and anyWarning(g);
    if (!(c.intro or c.end_up or flash or warn)) return null;
    const sc = g.scene orelse return null;
    const bd = sc.backdrop orelse return null;
    if (bd.pixels.len == 0) return null;

    if (c.screen == null) {
        c.screen = g.gpa.create(Screen) catch return null;
        c.screen.?.* = .{};
    }
    const out = c.screen.?;
    const scr = g.plat.screen();
    out.pixels = scr.pixels;
    out.palette = scr.palette;
    const s: platform.Surface = .{
        .pixels = out.pixels[0..],
        .width = platform.screen_width,
        .height = platform.screen_height,
        .bottom_up = false,
        .colors = &bd.bmiColors,
    };

    if (warn) for (killers) |i| if (g.targets[i]) |t| if (warning(t)) drawWarning(g, s, t, now);
    if (flash) drawFlash(s, now -% c.shot_at.?);
    if (c.intro) drawIntro(g, out, s, bd);
    if (c.end_up) drawEnd(g, s);
    return out;
}

fn red(s: platform.Surface) u8 {
    return screen.nearest(s.colors, 0x000000ff);
}

/// The sign on a killer in its warning: its frame blinks red and yellow and a "!"
/// hangs over its head (a road sign: yellow, black "!").
fn drawWarning(g: *Game, s: platform.Surface, t: *Object, now: u32) void {
    const w: i32 = position.width(t);
    const h: i32 = position.height(t);
    const colour: u8 = if ((now / 110) % 2 == 0) red(s) else screen.nearest(s.colors, 0x0000ffff);
    screen.frame(s, t.x, t.y, w, h, 3, colour);
    const yellow = screen.nearest(s.colors, 0x0000ffff);
    const black = screen.nearest(s.colors, 0);
    const bx: i32 = t.x + @divTrunc(w, 2) - 13;
    const by: i32 = @max(t.y - 36, 4);
    screen.fill(s, bx - 2, by - 2, 30, 36, black);
    screen.fill(s, bx, by, 26, 32, yellow);
    screen.fill(s, bx + 10, by + 4, 6, 15, black);
    screen.fill(s, bx + 10, by + 22, 6, 6, black);
    _ = g;
}

/// The edge of the screen in red, wide at first, then thin.
fn drawFlash(s: platform.Surface, since: u32) void {
    const t: i32 = if (since < flash_wide_ms) 18 else 8;
    screen.frame(s, 0, 0, platform.screen_width, platform.screen_height, t, red(s));
}

// ---- the intro screen ----

pub const intro_panel: screen.Rect = .{ .x = 40, .y = 4, .w = 560, .h = 452 };

const Row = struct {
    figure: usize,
    /// The strip frame shown.
    frame: i16,
    head: []const u8,
    lines: [2][]const u8,
};

// Windows-1252 (the system font's).
const intro_rows = [_]Row{
    .{
        .figure = 10, // 3svelh: the old lady
        .frame = 0,
        .head = "Mate os bonzinhos: +100",
        .lines = .{ "fada, Lennon, velhinha, escoteiro,", "Kennedy e o coelhinho da P\xe1scoa" },
    },
    .{
        .figure = 5, // 3shitl
        .frame = 0,
        .head = "Poupe os malvados: -100",
        .lines = .{ "Hitler, Klan, mafioso, pirata, \xe1rabe,", "a bab\xe1 e o Papai Noel que n\xe3o atiram" },
    },
    .{
        .figure = 2, // 3sbabt at its shot
        .frame = 9,
        .head = "Cuidado com os outros assassinos!",
        .lines = .{ "A bab\xe1 e o Papai Noel que atiram avisam", "com um '!' antes. Acerte primeiro: +200" },
    },
};

const row_pitch: i32 = 108;
/// The pictures' column: from the panel's left, its width.
const pic_x: i32 = 24;
const pic_w: i32 = 90;
const text_x: i32 = 132;

fn drawIntro(g: *Game, out: *Screen, s: platform.Surface, bd: *Backdrop) void {
    const plat = g.plat;
    const r = intro_panel;
    const fh: i32 = @intCast(plat.textExtent("A") >> 16);
    screen.dim(s, r.x, r.y, r.w, r.h);
    screen.frame(s, r.x + 4, r.y + 4, r.w - 8, r.h - 8, 2, screen.nearest(s.colors, 0x0000ffff));
    var y: i32 = r.y + 18;
    screen.centred(plat, s, r, y, 0x0000ffff, "SERIAL KILLER");
    y += fh + 4;
    screen.centred(plat, s, r, y, 0x00c0c0c0, "Voc\xea \xe9 o serial killer. 5 vidas, 2 minutos.");
    y += fh + 10;
    for (intro_rows) |row| {
        const lines_h = 3 * fh + 6;
        var ty = y + @divTrunc(row_pitch - lines_h, 2);
        screen.text(plat, s, r.x + text_x, ty, 0x0000ffff, row.head);
        ty += fh + 3;
        for (row.lines) |line| {
            screen.text(plat, s, r.x + text_x, ty, 0x00ffffff, line);
            ty += fh + 3;
        }
        drawFigure(g, out, bd, row.figure, row.frame, r.x + pic_x, y);
        y += row_pitch;
    }
    // The keys.
    const arrows_w: i32 = 26 + 6 + 26 + 6 + screen.textWidth(plat, "mira") + 22;
    const space_w: i32 = screen.textWidth(plat, "Espa\xe7o") + 12 + 6 + screen.textWidth(plat, "atira");
    var x: i32 = r.x + @divTrunc(r.w - arrows_w - space_w, 2);
    const cy: i32 = y + 2;
    x += screen.cap(plat, s, x, cy, .left, fh) + 6;
    x += screen.cap(plat, s, x, cy, .right, fh) + 6;
    screen.text(plat, s, x, cy + @divTrunc(screen.cap_h - fh, 2), 0x00ffffff, "mira");
    x += screen.textWidth(plat, "mira") + 22;
    x += screen.cap(plat, s, x, cy, .space, fh) + 6;
    screen.text(plat, s, x, cy + @divTrunc(screen.cap_h - fh, 2), 0x00ffffff, "atira");
    screen.centred(plat, s, r, r.y + r.h - 18 - fh, 0x0000ffff, screen.start_text);
}

/// Frame `frame` of figure `idx`'s strip, in the picture's column at row top
/// `top` (centred in the column and the row).
fn drawFigure(g: *Game, out: *Screen, bd: *Backdrop, idx: usize, frame: i16, left: i32, top: i32) void {
    const t = g.targets[idx] orelse return;
    const fr = &t.frames[0];
    const src = fr.dib orelse return;
    const c = &g.corr;
    if (c.scratch.len != bd.pixels.len) {
        g.gpa.free(c.scratch);
        c.scratch = g.gpa.alloc(u8, bd.pixels.len) catch {
            c.scratch = &.{};
            return;
        };
    }
    const key = g.unk00A8;
    @memset(c.scratch, key);
    const w: i32 = fr.width;
    const h: i32 = fr.height;
    const x: i32 = left + @divTrunc(pic_w - w, 2);
    const y: i32 = top + @max(0, @divTrunc(row_pitch - h, 2));
    const orient: i16 = @truncate(t.dibFormatOk);
    _ = dib.copyTransparent(&bd.bmiHeader, c.scratch, @intCast(x), @intCast(y), src.bits, &src.header, position.frameCellX(fr, frame), position.frameCellY(fr, frame), fr.width, orient *% fr.height, key) catch return;
    const width: i32 = bd.bmiHeader.biWidth;
    const height: i32 = @intCast(@abs(bd.bmiHeader.biHeight));
    const stride: usize = (@as(usize, @intCast(width)) + 3) & ~@as(usize, 3);
    const bottom_up = bd.bmiHeader.biHeight > 0;
    var j: i32 = @max(y, 0);
    while (j < @min(y + h, @min(height, platform.screen_height))) : (j += 1) {
        const row: usize = @intCast(if (bottom_up) height - 1 - j else j);
        var i: i32 = @max(x, 0);
        while (i < @min(x + w, @min(width, platform.screen_width))) : (i += 1) {
            const p = c.scratch[row * stride + @as(usize, @intCast(i))];
            if (p == key) continue;
            out.pixels[@as(usize, @intCast(j)) * platform.screen_width + @as(usize, @intCast(i))] = p;
        }
    }
}

// ---- the end screen ----

pub const end_panel: screen.Rect = .{ .x = 170, .y = 140, .w = 300, .h = 190 };

fn drawEnd(g: *Game, s: platform.Surface) void {
    var score_buf: [40]u8 = undefined;
    var lives_buf: [40]u8 = undefined;
    const score_line = std.fmt.bufPrint(&score_buf, "Pontos: {d}", .{g.score}) catch "";
    const lives_line = std.fmt.bufPrint(&lives_buf, "Vidas que sobraram: {d}", .{@max(g.lives, 0)}) catch "";
    const lines = [_][]const u8{ score_line, lives_line };
    screen.drawMessage(g.plat, s, .{
        .panel = end_panel,
        .title = if (g.lives > 0) "Voc\xea sobreviveu!" else "Fim de jogo!",
        .lines = &lines,
        .footer = "Aperte uma tecla",
    });
}

test "the intro keeps the game until a key, which is then let go; the end screen takes any key" {
    const TestGame = @import("core/game.zig").TestGame;
    const t = try TestGame.init(std.testing.allocator);
    defer t.deinit();
    const g = t.game;
    g.fixes.serial_intro_screen = true;
    g.fixes.serial_end_screen = true;
    g.corr.intro = true;
    try std.testing.expect(gate(g, .{ .id = wm.systimer, .wparam = 7 }) == null);
    try std.testing.expect(gate(g, .{ .id = msg.noite.minigame_hello }) != null);
    try std.testing.expect(gate(g, .{ .id = wm.paint }) != null);
    // No figures in a bare game: the timers cannot be armed, so test the key's hold alone.
    g.corr.intro = false;
    g.corr.held_key = 0x20;
    try std.testing.expect(gate(g, .{ .id = wm.keydown, .wparam = 0x20 }) == null);
    try std.testing.expect(gate(g, .{ .id = wm.keyup, .wparam = 0x20 }) == null);
    try std.testing.expect(g.corr.held_key == null);
    try std.testing.expect(gate(g, .{ .id = wm.keydown, .wparam = 0x20 }) != null);
    // The end: the clock ends the game, the screen holds the result back.
    finish(g);
    try std.testing.expect(g.corr.end_up and !g.corr.ended);
    try std.testing.expect(gate(g, .{ .id = wm.systimer, .wparam = 3 }) == null);
    try std.testing.expect(gate(g, .{ .id = wm.keydown, .wparam = 0x25 }) == null);
    try std.testing.expect(g.corr.ended);
}
