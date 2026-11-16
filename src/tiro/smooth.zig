//! Not in the original (`Fixes.tiro_smooth_motion`, a Corrigida addition):
//! the walking targets and the flying arrow shown between their steps.
//!
//! TIRO moves a target 20 px every 100 ms (10 steps a second) and the
//! arrow 10 px every 55 ms, drawing each step straight into the backdrop
//! and blitting it to the window, so the figures jump. This module draws
//! nothing into the window's screen or the backdrop: the host asks for the
//! picture to present (`host.Program.view`, at the backend's frame rate),
//! and `view` returns a copy of the screen in which each moving figure is
//! shown between the position it left at its last step and the one it
//! took, in proportion to the time from that step to its timer's next tick
//! (the display lags the game by at most one step). Positions, the
//! occupancy grid, the hit tests, timers, randomness and scores are the
//! game's, untouched; only the presented picture differs.
//!
//! The picture: for each figure shown away from its game position, the
//! rectangle covering both positions is rebuilt from the background and
//! every object drawn over it, at its shown position, in the game's order:
//! the crossbow, the targets (walking ones over falling ones as the
//! original does, or `visibility.drawOrder` with T8's fix), the arrow.
//! Elsewhere the picture is the screen as the game left it.
//!
//! Also here, `Fixes.tiro_arrows_on_counter`: the counter at the bottom
//! left shows the arrows still to fire (see `drawCounter`).

const std = @import("std");
const platform = @import("../platform/platform.zig");
const Screen = platform.Screen;
const Game = @import("core/game.zig").Game;
const object = @import("core/object.zig");
const Object = object.Object;
const BitmapInfoHeader = object.BitmapInfoHeader;
const world = @import("core/world.zig");
const Backdrop = world.Backdrop;
const dib = @import("dib.zig");
const position = @import("behaviour/position.zig");
const visibility = @import("behaviour/visibility.zig");

/// The presentation buffers, made at the first `view` that needs them.
pub const State = struct {
    screen: ?*Screen = null,
    /// A copy of the backdrop's bitmap layout the rectangles are rebuilt in.
    scratch: []u8 = &.{},

    pub fn deinit(s: *State, gpa: std.mem.Allocator) void {
        if (s.screen) |scr| gpa.destroy(scr);
        gpa.free(s.scratch);
        s.* = .{};
    }
};

const Pos = struct { x: i16, y: i16 };
const Rc = struct { x0: i32, y0: i32, x1: i32, y1: i32 };

/// Where `obj` is shown at `now`: between its last step's two positions
/// while its timer has not ticked again, else null (at its game position).
/// The step must be the latest move (the object is still where it took
/// it, still moving, its timer ticking once since).
pub fn shownAt(g: *Game, obj: *Object, now: u32) ?Pos {
    const s = obj.step;
    if (!s.valid or obj.mover.moving == 0) return null;
    if (obj.x != s.toX or obj.y != s.toY) return null;
    const t = g.queue.findTimer(.system, @bitCast(obj.mover.timerId)) orelse return null;
    const span: i32 = @bitCast(t.due -% s.at);
    if (span <= 0 or span > t.period) return null;
    const since: i32 = @bitCast(now -% s.at);
    if (since < 0 or since >= span) return null;
    const p: Pos = .{ .x = between(s.fromX, s.toX, since, span), .y = between(s.fromY, s.toY, since, span) };
    if (p.x == obj.x and p.y == obj.y) return null;
    return p;
}

/// `from` moved the fraction `num / den` (< 1) of the way to `to`.
fn between(from: i16, to: i16, num: i32, den: i32) i16 {
    return @intCast(from + @divTrunc((@as(i32, to) - from) * num, den));
}

/// The arrow is in flight and has been drawn (its first step placed it):
/// before that, and once it stopped, the game shows nothing of it.
fn arrowShown(a: *Object) bool {
    return a.mover.moving != 0 and a.step.valid and a.x == a.step.toX and a.y == a.step.toY;
}

/// The picture to present at `now` (`host.Program.view`), or null for the
/// screen itself: the flag is off, or nothing is between two steps.
pub fn view(g: *Game, now: u32) ?*const Screen {
    if (!g.fixes.tiro_smooth_motion and !g.fixes.tiro_arrows_on_counter) return null;
    const scene = g.scene orelse return null;
    const bd = scene.backdrop orelse return null;
    const bg = bd.background orelse return null;
    if (bd.pixels.len == 0) return null;

    var movers: [5]?*Object = .{ g.targets[0], g.targets[1], g.targets[2], g.targets[3], g.arrows[0] };
    var rects: [6]Rc = undefined;
    var n: usize = 0;
    // The counter: rebuilt whenever shown, which also wipes the arrow the
    // game leaves lying at its creation point.
    if (g.fixes.tiro_arrows_on_counter and g.crossbow != null and g.arrows[0] != null) {
        const a = g.arrows[0].?;
        rects[n] = .{ .x0 = 0, .y0 = counter_y, .x1 = counter_step * (counter_cols - 1) + position.width(a), .y1 = counter_y + counter_row_dy + position.height(a) };
        n += 1;
    }
    for (&movers) |*m| {
        if (!g.fixes.tiro_smooth_motion) break;
        const o = m.* orelse continue;
        if (o.kind == .arrow and !arrowShown(o)) continue;
        const p = shownAt(g, o, now) orelse continue;
        const w = position.width(o);
        const h = position.height(o);
        rects[n] = .{
            .x0 = @min(o.x, p.x),
            .y0 = @min(o.y, p.y),
            .x1 = @as(i32, @max(o.x, p.x)) + w,
            .y1 = @as(i32, @max(o.y, p.y)) + h,
        };
        n += 1;
    }
    if (n == 0) return null;

    const st = &g.smooth;
    if (st.screen == null) st.screen = g.gpa.create(Screen) catch return null;
    if (st.scratch.len != bd.pixels.len) {
        g.gpa.free(st.scratch);
        st.scratch = g.gpa.alloc(u8, bd.pixels.len) catch {
            st.scratch = &.{};
            return null;
        };
    }
    const out = st.screen.?;
    const scr = g.plat.screen();
    out.pixels = scr.pixels;
    out.palette = scr.palette;
    out.overlay = .{};

    const layout = Layout.of(&bd.bmiHeader);
    const bg_layout = Layout.of(&bg.header);
    for (rects[0..n]) |r0| {
        const r: Rc = .{
            .x0 = @max(r0.x0, 0),
            .y0 = @max(r0.y0, 0),
            .x1 = @min(r0.x1, @min(layout.width, bg_layout.width)),
            .y1 = @min(r0.y1, @min(layout.height, bg_layout.height)),
        };
        if (r.x0 >= r.x1 or r.y0 >= r.y1) continue;
        // The background, opaque.
        var y = r.y0;
        while (y < r.y1) : (y += 1) {
            const d = layout.offset(r.x0, y);
            const s = bg_layout.offset(r.x0, y);
            const len: usize = @intCast(r.x1 - r.x0);
            if (s + len > bg.bits.len or d + len > st.scratch.len) continue;
            @memcpy(st.scratch[d..][0..len], bg.bits[s..][0..len]);
        }
        if (g.fixes.tiro_arrows_on_counter) drawCounter(g, bd);
        // Every object over it, back to front, where it is shown.
        if (g.crossbow) |cb| drawAt(g, bd, cb, cb.x, cb.y);
        for (targetOrder(g)) |t| {
            const p = (if (g.fixes.tiro_smooth_motion) shownAt(g, t, now) else null) orelse Pos{ .x = t.x, .y = t.y };
            drawAt(g, bd, t, p.x, p.y);
        }
        if (g.arrows[0]) |a| if (arrowShown(a)) {
            const p = (if (g.fixes.tiro_smooth_motion) shownAt(g, a, now) else null) orelse Pos{ .x = a.x, .y = a.y };
            drawAt(g, bd, a, p.x, p.y);
        };
        // The rectangle onto the picture.
        y = r.y0;
        while (y < r.y1) : (y += 1) {
            const sy = y - bd.originY;
            if (sy < 0 or sy >= platform.screen_height) continue;
            var x = r.x0;
            while (x < r.x1) : (x += 1) {
                const sx = x - bd.originX;
                if (sx < 0 or sx >= platform.screen_width) continue;
                const o = layout.offset(x, y);
                if (o >= st.scratch.len) continue;
                out.pixels[@as(usize, @intCast(sy)) * platform.screen_width + @as(usize, @intCast(sx))] = st.scratch[o];
            }
        }
    }
    return out;
}

/// The counter's row: arrow `i` of the `lives` left lies at x `i *
/// counter_step`, y 380 (where the game leaves its one arrow), the picture
/// of the arrow's strip 1 (`Tirofr`), each over the one before.
const counter_y = 372;
const counter_step = 20;
const counter_cols = 8;
const counter_row_dy = 20;
const counter_max = 16;

/// The arrows still to fire: `lives` (T2 takes one off at each shot, so the
/// one in flight is not counted; T4 lets the last fly at `lives` 0).
fn arrowsLeft(lives: i16) i16 {
    return std.math.clamp(lives, 0, counter_max);
}

/// Where arrow `i` of the row lies: two rows of eight, the first arrow at
/// the left of the upper row.
fn counterSlot(i: i16) Pos {
    return .{ .x = @rem(i, counter_cols) * counter_step, .y = counter_y + @divTrunc(i, counter_cols) * counter_row_dy };
}

fn drawCounter(g: *Game, bd: *Backdrop) void {
    const a = g.arrows[0] orelse return;
    const left = arrowsLeft(g.crossbow.?.player2d.lives);
    const f = &a.frames[1];
    const src = f.dib orelse return;
    const orient: i16 = @truncate(a.dibFormatOk);
    var i: i16 = 0;
    while (i < left) : (i += 1) {
        const at = counterSlot(i);
        _ = dib.copyTransparent(&bd.bmiHeader, g.smooth.scratch, at.x, at.y, src.bits, &src.header, 0, 0, f.width, orient *% f.height, g.unk00A8) catch {};
    }
}

/// The targets back to front as the game draws them: with T8's fix in
/// depth order; without it the falling ones (hit animation) first, since
/// every redraw puts the walking ones over them.
fn targetOrder(g: *Game) [4]*Object {
    if (g.fixes.tiro_hit_target_depth) return visibility.drawOrder(g);
    var out: [4]*Object = undefined;
    var n: usize = 0;
    for ([_]bool{ true, false }) |falling| {
        for (g.targets) |t| {
            const target = t.?;
            if ((target.curFrame != 0) != falling) continue;
            out[n] = target;
            n += 1;
        }
    }
    return out;
}

/// `mover_draw_dirty_to` of `obj`'s current frame at (x, y) of the scratch
/// bitmap (the backdrop's layout, key `g_unk00A8`).
fn drawAt(g: *Game, bd: *Backdrop, obj: *Object, x: i16, y: i16) void {
    const src = position.dib(obj) orelse return;
    const orient: i16 = @truncate(obj.dibFormatOk);
    _ = dib.copyTransparent(&bd.bmiHeader, g.smooth.scratch, x, y, src.bits, &src.header, position.frameSrcX(obj), position.frameSrcY(obj), position.width(obj), orient *% position.height(obj), g.unk00A8) catch {};
}

/// An 8-bit DIB's rows: 4-byte aligned, bottom-up for a positive height.
const Layout = struct {
    width: i32,
    height: i32,
    stride: usize,
    bottom_up: bool,

    fn of(h: *const BitmapInfoHeader) Layout {
        const w: i32 = h.biWidth;
        return .{
            .width = w,
            .height = @intCast(@abs(h.biHeight)),
            .stride = (@as(usize, @intCast(w)) + 3) & ~@as(usize, 3),
            .bottom_up = h.biHeight > 0,
        };
    }

    /// The byte of pixel (x, y), y counted from the top.
    fn offset(l: Layout, x: i32, y: i32) usize {
        const row: usize = @intCast(if (l.bottom_up) l.height - 1 - y else y);
        return row * l.stride + @as(usize, @intCast(x));
    }
};

test "the counter holds the arrows left in two rows of eight" {
    try std.testing.expectEqual(@as(i16, 16), arrowsLeft(16));
    try std.testing.expectEqual(@as(i16, 0), arrowsLeft(-1));
    try std.testing.expectEqual(Pos{ .x = 0, .y = 372 }, counterSlot(0));
    try std.testing.expectEqual(Pos{ .x = 140, .y = 372 }, counterSlot(7));
    try std.testing.expectEqual(Pos{ .x = 0, .y = 392 }, counterSlot(8));
    // Right of it ends at 140 + 55, left of the crossbow (x 200).
    try std.testing.expect(counterSlot(7).x + 55 < 200);
}

test "a step is shown in proportion to the time to the next tick" {
    try std.testing.expectEqual(@as(i16, 30), between(20, 40, 50, 100));
    try std.testing.expectEqual(@as(i16, 35), between(40, 20, 25, 100));
    try std.testing.expectEqual(@as(i16, 20), between(20, 40, 0, 100));
}
