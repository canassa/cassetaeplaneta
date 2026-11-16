//! Not in the original (`Fixes.inv_clean_render`, and the arcade rules' pictures): the picture the
//! backend presents for INV's window (`host.Program.view`, at the backend's frame rate).
//!
//! INV draws each object into the backdrop at its own timer's step and blits rectangles of it to the
//! window, erasing the 20-px trail with a rectangle a step wider than the object: the sprites jump,
//! flicker and leave pieces of each other (BUGS.md P9's kind of bug). This module never draws an
//! object into the screen: every frame it takes the clean background (`Espaco.bmp`) and draws every
//! sprite whole over it, at the position it is at.
//!
//! With the arcade rules the sprites are the game's (`sim.Sim`): the rack's invaders cut one by one
//! from `Movein.bmp`'s column, the bunkers as blocks, the bombs, the shot, the saucer, the cannon, the
//! bursts; what moves smoothly (the cannon, the shot, the bombs, the saucer) is shown between the
//! game's frames, from where it was a frame ago to where it is, so the motion is as smooth as the
//! display. Without them it draws the 1995 objects where the game has them.

const std = @import("std");
const platform = @import("../../platform/platform.zig");
const Screen = platform.Screen;
const Game = @import("../core/game.zig").Game;
const object = @import("../core/object.zig");
const Dib = object.Dib;
const sim = @import("sim.zig");
const bunker = @import("bunker.zig");
const controls = @import("controls.zig");
const glue = @import("glue.zig");
const screen_ctl = @import("../../core/controls_screen.zig");

const W = platform.screen_width;
const H = platform.screen_height;
/// The sprites' transparent index; `Bomtir.bmp` is on black.
const key_blue: u8 = 11;
const key_black: u8 = 0;

fn sourcePixel(d: *const Dib, x: i32, y: i32) u8 {
    const w: usize = @intCast(d.header.biWidth);
    const h: i32 = @intCast(@abs(d.header.biHeight));
    const stride = (w + 3) & ~@as(usize, 3);
    const row: usize = @intCast(if (d.header.biHeight > 0) h - 1 - y else y);
    return d.bits[row * stride + @as(usize, @intCast(x))];
}

/// Copies the `w` x `h` rectangle at (`sx`, `sy`) of the sheet to (`dx`, `dy`) of the picture, clipped,
/// skipping `key`.
fn blit(out: *Screen, d: *const Dib, sx: i32, sy: i32, w: i32, h: i32, dx: i32, dy: i32, key: u8) void {
    const sw: i32 = d.header.biWidth;
    const sh: i32 = @intCast(@abs(d.header.biHeight));
    var j: i32 = 0;
    while (j < h) : (j += 1) {
        const y = dy + j;
        const syy = sy + j;
        if (y < 0 or y >= H or syy < 0 or syy >= sh) continue;
        var i: i32 = 0;
        while (i < w) : (i += 1) {
            const x = dx + i;
            const sxx = sx + i;
            if (x < 0 or x >= W or sxx < 0 or sxx >= sw) continue;
            const c = sourcePixel(d, sxx, syy);
            if (c == key) continue;
            out.pixels[@as(usize, @intCast(y)) * W + @as(usize, @intCast(x))] = c;
        }
    }
}

/// `blit` of the whole `sw` x `sh` sheet at (`sx`, `sy`) shrunk to `dw` x `dh` by taking one pixel in
/// each cell (the lives' little cannons).
fn blitScaled(out: *Screen, d: *const Dib, sx: i32, sy: i32, sw: i32, sh: i32, dw: i32, dh: i32, dx: i32, dy: i32, key: u8) void {
    var j: i32 = 0;
    while (j < dh) : (j += 1) {
        const y = dy + j;
        if (y < 0 or y >= H) continue;
        var i: i32 = 0;
        while (i < dw) : (i += 1) {
            const x = dx + i;
            if (x < 0 or x >= W) continue;
            const c = sourcePixel(d, sx + @divTrunc((2 * i + 1) * sw, 2 * dw), sy + @divTrunc((2 * j + 1) * sh, 2 * dh));
            if (c == key) continue;
            out.pixels[@as(usize, @intCast(y)) * W + @as(usize, @intCast(x))] = c;
        }
    }
}

fn fillRect(out: *Screen, x: i32, y: i32, w: i32, h: i32, index: u8) void {
    var j = @max(y, 0);
    while (j < @min(y + h, H)) : (j += 1) {
        var i = @max(x, 0);
        while (i < @min(x + w, W)) : (i += 1) out.pixels[@as(usize, @intCast(j)) * W + @as(usize, @intCast(i))] = index;
    }
}

/// The part of the way from the last frame to the current one `now` is (0..256).
fn fraction(st: *const glue.State, now: u32) i32 {
    const since: i64 = @as(i32, @bitCast(now -% st.frame_ms));
    return @intCast(std.math.clamp(@divTrunc(since * sim.fps * 256, 1000), 0, 256));
}

/// The picture to present at `now`, or null for the screen itself.
pub fn view(g: *Game, now: u32) ?*const Screen {
    const f = g.fixes;
    const st = &g.arcade;
    if (!(f.inv_clean_render or f.inv_arcade_rules or st.ctl.up)) return null;
    const scene = g.scene orelse return null;
    const bd = scene.backdrop orelse return null;
    const bg = bd.background orelse return null;
    if (bg.header.biWidth != W or @abs(bg.header.biHeight) != H) return null;

    if (st.shown == null) st.shown = g.gpa.create(Screen) catch return null;
    if (st.background.len != W * H) {
        g.gpa.free(st.background);
        st.background = g.gpa.alloc(u8, W * H) catch {
            st.background = &.{};
            return null;
        };
        for (0..H) |y| for (0..W) |x| {
            st.background[y * W + x] = sourcePixel(bg, @intCast(x), @intCast(y));
        };
    }
    const out = st.shown.?;
    const scr = g.plat.screen();
    out.palette = scr.palette;
    out.overlay = .{};
    @memcpy(&out.pixels, st.background);

    if (f.inv_arcade_rules) {
        if (st.has_sim) drawArcade(g, out, bd, now);
    } else {
        drawOriginal(g, out);
        drawScore(g, out, bd);
    }
    if (st.ctl.up) {
        const surface: platform.Surface = .{
            .pixels = &out.pixels,
            .width = W,
            .height = H,
            .bottom_up = false,
            .colors = &bd.bmiColors,
        };
        controls.draw(g, surface);
    }
    return out;
}

// ---- the 1995 game's objects, drawn clean ----

fn drawOriginal(g: *Game, out: *Screen) void {
    const objs = [_]?*object.Object{
        g.invaderColumns[0], g.invaderColumns[1], g.invaderColumns[2], g.invaderColumns[3],
        g.saucer,            g.bombs[0],          g.bombs[1],          g.shots[0],
        g.invaderExplosion,  g.cannon,
    };
    for (objs) |maybe| {
        const o = maybe orelse continue;
        if (o.visible == 0) continue;
        if (o.curStrip < 0 or o.curStrip >= o.frames.len) continue;
        const fr = &o.frames[@intCast(o.curStrip)];
        const d = fr.dib orelse continue;
        var h: i32 = fr.height;
        if (o.kind == .invader_column) {
            if (o.invader.lowestAlive < 0) continue;
            h = @min(h, (@as(i32, o.invader.lowestAlive) + 1) * 44);
        }
        blit(out, d, 0, @as(i32, fr.height) * o.curFrame, fr.width, h, o.x, o.y, key_blue);
    }
}

// ---- the arcade game ----

fn drawArcade(g: *Game, out: *Screen, bd: *const @import("../core/world.zig").Backdrop, now: u32) void {
    const st = &g.arcade;
    const s = &st.drv.sim;
    const art = st.art;
    const fr = fraction(st, now);

    // The bunkers.
    const green = screen_ctl.nearest(&bd.bmiColors, 0x0040d040);
    for (s.bunkers) |bk| {
        for (0..bunker.cols) |c| for (0..bunker.rows) |r| {
            if (!bk.cells[c][r]) continue;
            fillRect(out, bk.x + @as(i32, @intCast(c)) * bunker.block, bk.bottom() - (@as(i32, @intCast(r)) + 1) * bunker.block, bunker.block, bunker.block, green);
        };
    }

    // The bombs and their bursts.
    for (s.bombs, 0..) |b, k| switch (b.state) {
        .idle => {},
        .fall => if (art.bomb) |d| blit(out, d, 0, 0, sim.bomb_w, sim.bomb_h, b.x, sim.Sim.lerp(s.prev.bomb_y[k], b.y, fr), key_blue),
        .blow => if (art.impact) |d| {
            const frame: i32 = @min(2, @divTrunc((sim.bomb_burst_frames - @as(i32, b.blow)) * 3, sim.bomb_burst_frames));
            blit(out, d, 0, frame * 28, 25, 28, b.bx - 12, b.by - 26, key_black);
        },
    };

    // The invaders.
    if (art.invaders) |d| {
        // The rack is drawn between its last two places, as one block.
        const rdx = sim.Sim.lerp(s.prev.rack_fx, s.rack_fx, fr) - s.rack_x;
        const rdy = sim.Sim.lerp(s.prev.rack_y * sim.fix, s.rack_y * sim.fix, fr) - s.rack_y;
        for (s.inv, 0..) |iv, i| {
            if (!iv.alive) continue;
            const k: i32 = @intCast(sim.rows - 1 - sim.Sim.rowOf(i));
            blit(out, d, 0, 3 + 45 * k + 216 * @as(i32, iv.frame), sim.inv_w, sim.inv_h, iv.x + rdx, iv.y + rdy, key_blue);
        }
    }
    if (art.boom) |d| if (s.burst_t > 0) {
        const frame: i32 = @min(7, @divTrunc(sim.invader_burst - @as(i32, s.burst_t), 2));
        blit(out, d, 0, frame * 44, 88, 44, s.burst_x, s.burst_y - 5, key_blue);
    };

    // The saucer: flying, or bursting with its score.
    const sc = s.saucer;
    switch (sc.state) {
        .none => {},
        .fly => if (art.saucer) |d| {
            const x = sim.Sim.lerp(s.prev.saucer_x, sc.x, fr);
            blit(out, d, 0, @as(i32, @intCast((s.t / 6) % 3)) * 32, sim.saucer_w, sim.saucer_h, x, sim.saucer_y, key_blue);
        },
        .hit => {
            const x = sc.x >> 8;
            if (art.saucer_boom) |d| {
                const frame: i32 = @min(7, @divTrunc(sim.saucer_burst - @as(i32, sc.t), 4));
                blit(out, d, 0, frame * 103, 111, 103, x + 30 - 55, sim.saucer_y + 16 - 51, key_blue);
            }
            if (sc.shown > 0) {
                var buf: [8]u8 = undefined;
                const txt = std.fmt.bufPrint(&buf, "{d}", .{sc.shown}) catch "";
                // White on a black outline: it stands on the fire.
                const tx = x + 30 - @divTrunc(@as(i32, @intCast(g.plat.textExtent(txt) & 0xffff)), 2);
                const ty = sim.saucer_y + 8;
                for ([_][2]i32{ .{ -1, 0 }, .{ 1, 0 }, .{ 0, -1 }, .{ 0, 1 }, .{ -1, -1 }, .{ 1, 1 }, .{ -1, 1 }, .{ 1, -1 } }) |o| text(g, out, bd, tx + o[0], ty + o[1], 0x00000000, txt);
                text(g, out, bd, tx, ty, 0x00ffffff, txt);
            }
        },
    }

    // The cannon's shot and its burst.
    const sh = s.shot;
    switch (sh.state) {
        .fly => if (art.shot) |d| blit(out, d, 0, 0, sim.shot_w, sim.shot_h, sh.x, sim.Sim.lerp(s.prev.shot_y, sh.y, fr), key_blue),
        .blow => if (art.impact) |d| {
            const frame: i32 = @min(2, @divTrunc((sim.shot_burst_frames - @as(i32, sh.t)) * 3, sim.shot_burst_frames));
            blit(out, d, 0, frame * 28, 25, 28, sh.bx - 12, sh.by - 14, key_black);
        },
        else => {},
    }

    // The cannon, or its end.
    const cx = sim.Sim.lerp(s.prev.cx, s.cx, fr);
    if (s.mode == .dying) {
        if (art.brocha) |d| {
            const frame: i32 = @min(6, @as(i32, @intCast(s.death_t / 6)));
            blit(out, d, 0, frame * sim.cannon_h, sim.cannon_w, sim.cannon_h, s.cannonX(), sim.cannon_y, key_blue);
        }
    } else if (art.cannon) |d| {
        blit(out, d, 0, 0, sim.cannon_w, sim.cannon_h, cx, sim.cannon_y, key_blue);
    }

    drawScore(g, out, bd);
    drawLives(g, out, bd, s.lives);
}

fn text(g: *Game, out: *Screen, bd: *const @import("../core/world.zig").Backdrop, x: i32, y: i32, color: u32, t: []const u8) void {
    const surface: platform.Surface = .{ .pixels = &out.pixels, .width = W, .height = H, .bottom_up = false, .colors = &bd.bmiColors };
    _ = g.plat.textOut(surface, .{ .color = color, .bk_mode = .transparent }, @intCast(x), @intCast(y), t);
}

/// INV's score box: `sprintf(" %04d")` (or "-%04d"), a character at a time at x 460 + 32 i, y 445, pale
/// grey (`score.drawScore`).
fn drawScore(g: *Game, out: *Screen, bd: *const @import("../core/world.zig").Backdrop) void {
    var buf: [16]u8 = undefined;
    const txt = if (g.score < 0)
        std.fmt.bufPrint(&buf, "-{d:0>4}", .{@abs(@as(i32, g.score))}) catch return
    else
        std.fmt.bufPrint(&buf, " {d:0>4}", .{@as(u16, @intCast(g.score))}) catch return;
    var x: i32 = 0x1cc;
    for (0..txt.len) |i| {
        text(g, out, bd, x, 0x1bd, 0x00edeeee, txt[i..][0..1]);
        x += 0x20;
    }
}

/// The lives: the number and a little cannon for each one waiting, along the ground (the window shows
/// 459 rows of the 480; the cannon's base ends at 447).
fn drawLives(g: *Game, out: *Screen, bd: *const @import("../core/world.zig").Backdrop, lives: u8) void {
    var buf: [4]u8 = undefined;
    const txt = std.fmt.bufPrint(&buf, "{d}", .{lives}) catch return;
    text(g, out, bd, 8, 445, 0x00edeeee, txt);
    const d = g.arcade.art.cannon orelse return;
    var i: i32 = 1;
    while (i < lives) : (i += 1) {
        blitScaled(out, d, 0, 0, sim.cannon_w, sim.cannon_h, 14, 14, 24 + (i - 1) * 18, 445, key_blue);
    }
}
