//! Not in the original (`Fixes.sauna_clean_render`, and the arcade rules' pictures): the picture the
//! backend presents for SAUNA's window (`host.Program.view`, at the backend's frame rate).
//!
//! BUGS.md P9: SAUNA draws each actor into the backdrop and blits its rectangles to the window,
//! erasing with a rectangle of the dotted background that is larger than the actor (the step is
//! added to its size) and that wipes any other actor on it, which is redrawn only at its own next
//! tick: the sprites show cut off, and in different frames (Pacman's tick and the ghosts' are two
//! timers) the cuts come and go. This module never draws an actor into the screen: it takes a
//! copy of the screen, and for each actor rebuilds the rectangle from the dotted background and
//! draws every actor whole over it, Pacman first, the ghosts over him. Positions, pictures, the
//! occupancy grid, hit tests, timers and results are the game's.
//!
//! With the arcade rules the actors are never in the screen at all, and the picture shows them
//! between the game's frames: the position at the previous frame to the current one in proportion
//! to the time since that frame, so the motion is smooth at any display rate.

const std = @import("std");
const platform = @import("../../platform/platform.zig");
const Screen = platform.Screen;
const Game = @import("../core/game.zig").Game;
const object = @import("../core/object.zig");
const world = @import("../core/world.zig");
const dib = @import("../dib.zig");
const position = @import("../behaviour/position.zig");
const controls = @import("controls.zig");
const glue = @import("glue.zig");
const sim = @import("sim.zig");
const screen_ctl = @import("../../core/controls_screen.zig");

const bd_h: i32 = 460;

/// An 8-bit DIB's rows: 4-byte aligned, bottom-up for a positive height.
const Layout = struct {
    width: i32,
    height: i32,
    stride: usize,
    bottom_up: bool,

    fn of(h: *const object.BitmapInfoHeader) Layout {
        const w: i32 = h.biWidth;
        return .{
            .width = w,
            .height = @intCast(@abs(h.biHeight)),
            .stride = (@as(usize, @intCast(w)) + 3) & ~@as(usize, 3),
            .bottom_up = h.biHeight > 0,
        };
    }

    fn offset(l: Layout, x: i32, y: i32) usize {
        const row: usize = @intCast(if (l.bottom_up) l.height - 1 - y else y);
        return row * l.stride + @as(usize, @intCast(x));
    }
};

/// Where `sp` is at `now`: between its two frames' positions.
fn lerp(sp: glue.Sprite, frame_ms: u32, now: u32) struct { x: i32, y: i32 } {
    const since: i64 = @as(i32, @bitCast(now -% frame_ms));
    const num = std.math.clamp(since * sim.frames_per_second, 0, 1000);
    const dx = sp.x1 - sp.x0;
    const dy = sp.y1 - sp.y0;
    return .{
        .x = sp.x0 + @as(i32, @intCast(@divTrunc(@as(i64, dx) * num, 1000))),
        .y = sp.y0 + @as(i32, @intCast(@divTrunc(@as(i64, dy) * num, 1000))),
    };
}

/// What to draw: one actor's picture and where.
const Draw = struct { obj: *object.Object, strip: i16, frame: i16, x: i32, y: i32 };

/// The picture to present at `now`, or null for the screen itself.
pub fn view(g: *Game, now: u32) ?*const Screen {
    const f = g.fixes;
    const st = &g.arcade;
    if (!(f.sauna_clean_render or f.sauna_arcade_rules or st.ctl.up)) return null;
    const scene = g.scene orelse return null;
    const bd = scene.backdrop orelse return null;
    if (bd.pixels2.len == 0 or bd.pixels.len == 0) return null;
    const pac = g.pacman orelse return null;

    var draws: [5]Draw = undefined;
    var n: usize = 0;
    if (f.sauna_arcade_rules) {
        if (!st.has_sim) return null;
        for (st.sprites, 0..) |sp, i| {
            if (!sp.visible) continue;
            const o = if (i == 0) pac else scene.ghosts[i - 1] orelse continue;
            const p = lerp(sp, st.frame_ms, now);
            draws[n] = .{ .obj = o, .strip = sp.strip, .frame = sp.frame, .x = p.x, .y = p.y };
            n += 1;
        }
    } else {
        // The 1995 movement, drawn clean: where the game has the actors.
        const objs = [5]?*object.Object{ pac, scene.ghosts[0], scene.ghosts[1], scene.ghosts[2], scene.ghosts[3] };
        for (objs) |maybe| {
            const o = maybe orelse continue;
            if (o.visible == 0) continue;
            draws[n] = .{ .obj = o, .strip = o.curStrip, .frame = o.curFrame, .x = o.x, .y = o.y };
            n += 1;
        }
    }

    if (st.shown == null) st.shown = g.gpa.create(Screen) catch return null;
    if (st.scratch.len != bd.pixels2.len) {
        g.gpa.free(st.scratch);
        st.scratch = g.gpa.alloc(u8, bd.pixels2.len) catch {
            st.scratch = &.{};
            return null;
        };
    }
    const out = st.shown.?;
    const scr = g.plat.screen();
    out.pixels = scr.pixels;
    out.palette = scr.palette;
    out.overlay = .{};

    // The dotted background, the actors over it.
    @memcpy(st.scratch, bd.pixels2);
    for (draws[0..n]) |d| {
        const fr = &d.obj.frames[@intCast(d.strip)];
        const src = fr.dib orelse continue;
        const orient: i16 = @truncate(d.obj.dibFormatOk);
        _ = dib.copyTransparent(&bd.bmiHeader, st.scratch, @intCast(d.x), @intCast(d.y), src.bits, &src.header, position.frameCellX(fr, d.frame), position.frameCellY(fr, d.frame), fr.width, orient *% fr.height, @truncate(g.transparentColor)) catch {};
    }
    // Their rectangles onto the picture.
    const layout = Layout.of(&bd.bmiHeader);
    for (draws[0..n]) |d| {
        const fr = &d.obj.frames[@intCast(d.strip)];
        const x0 = @max(d.x, 0);
        const y0 = @max(d.y, 0);
        const x1 = @min(d.x + fr.width, @min(layout.width, platform.screen_width));
        const y1 = @min(d.y + fr.height, @min(bd_h, platform.screen_height));
        var y = y0;
        while (y < y1) : (y += 1) {
            var x = x0;
            while (x < x1) : (x += 1) {
                const o = layout.offset(x, y);
                if (o >= st.scratch.len) continue;
                out.pixels[@as(usize, @intCast(y)) * platform.screen_width + @as(usize, @intCast(x))] = st.scratch[o];
            }
        }
    }
    if (f.sauna_arcade_rules and st.debug) debugOverlay(g, out, bd);
    if (st.ctl.up) {
        const surface: platform.Surface = .{
            .pixels = &out.pixels,
            .width = platform.screen_width,
            .height = platform.screen_height,
            .bottom_up = false,
            .colors = &bd.bmiColors,
        };
        controls.draw(g, surface);
    }
    return out;
}

fn fillRect(out: *Screen, x: i32, y: i32, w: i32, h: i32, index: u8) void {
    var j = @max(y, 0);
    while (j < @min(y + h, platform.screen_height)) : (j += 1) {
        var i = @max(x, 0);
        while (i < @min(x + w, platform.screen_width)) : (i += 1) {
            out.pixels[@as(usize, @intCast(j)) * platform.screen_width + @as(usize, @intCast(i))] = index;
        }
    }
}

/// F9 (Debug builds): each ghost's target tile as a square of its colour (Blinky red, Pinky pink,
/// Inky cyan, Clyde orange), the tile Pacman is in, and the ghosts' mode in a corner square
/// (white scatter, black chase, blue frightened).
fn debugOverlay(g: *Game, out: *Screen, bd: *const world.Backdrop) void {
    const st = &g.arcade;
    const colors: [4]u32 = .{ 0x000000ff, 0x00b0b0ff, 0x00ffff00, 0x000080ff };
    for (st.drv.sim.ghosts, colors) |gh, c| {
        const idx = screen_ctl.nearest(&bd.bmiColors, c);
        const t = st.drv.sim.targetOf(&gh);
        const x = std.math.clamp(16 * t.a, 4, platform.screen_width - 4);
        const y = std.math.clamp(16 * t.b, 4, platform.screen_height - 4);
        fillRect(out, x - 4, y - 4, 8, 8, idx);
    }
    const white = screen_ctl.nearest(&bd.bmiColors, 0x00ffffff);
    fillRect(out, 16 * @divFloor(st.drv.sim.pac.x + 3, 8) - 8, 16 * @divFloor(st.drv.sim.pac.y + 3, 8) - 8, 16, 2, white);
    const mode: u32 = if (st.drv.sim.fright_on) 0x00ff0000 else if (st.drv.sim.cmd == .scatter) 0x00ffffff else 0x00000000;
    fillRect(out, 4, 4, 10, 10, screen_ctl.nearest(&bd.bmiColors, mode));
}
