//! Port unit `target` (module) of SERIAL.EXE. the 15 figures: creation (srand(time)), TargetVtbl startTimer and checkEdge (the wrap), hit (by kind: -100 / +100 / +200), hide and blit, the score box.
//!
//! Each function carries `// @orig <seg:xxxx> <name>` with the SERIAL address.
//! The hwnd and hdc parameters are dropped (the platform's screen).

const std = @import("std");
const platform = @import("../platform/platform.zig");
const Game = @import("core/game.zig").Game;
const object = @import("core/object.zig");
const Object = object.Object;
const world = @import("core/world.zig");
const Backdrop = world.Backdrop;
const dib = @import("dib.zig");
const sound = @import("sound.zig");
const object_create = @import("object_create.zig");
const movement = @import("behaviour/movement.zig");
const occupancy = @import("behaviour/occupancy.zig");
const position = @import("behaviour/position.zig");
const visibility = @import("behaviour/visibility.zig");

pub const Error = object_create.Error;

/// The figure `index` (0-14); the original indexes `g_targets` unchecked.
fn targetAt(g: *Game, index: i16) *Object {
    return g.targets[@as(u16, @bitCast(index))].?;
}

// @orig 1068:013f serial_create_targets
/// The 15 figures (kind `target`, hidden, one strip each from the
/// `g_targetStrip*` tables, steps 20 x 20, hit box = the strip frame,
/// y 0x118, x 0), attached, each with its `g_targetKinds` entry. Figures
/// 0-12 walk on timer `g_timerIds[0]` (200 ms), 13-14 on `[3]` (100 ms).
/// `srand(time(NULL))` first. Then through startTimer: figure 0 index 0
/// the lane 0/1 spawn timer (`[4]`, `[4]`), figure 0 index 99 the 60-s
/// clock (`[5]`), `clockTicks` and `laneBusy` cleared, figure 13 index 13
/// the lane 2 spawn timer (`[7]`, BUGS.md K5: `[6]` behind
/// `serial_lane2_own_timer`).
pub fn createTargets(g: *Game, bd: *Backdrop) Error!void {
    g.rand.srand(@truncate(@as(u32, @bitCast(g.plat.unixTime()))));
    var i: i16 = 0;
    while (i < 15) : (i += 1) {
        const lane2 = i >= 13;
        const t = try newTarget(g, @intCast(i), if (lane2) g.timerPeriods[3] else g.timerPeriods[0], if (lane2) g.timerIds[3] else g.timerIds[0]);
        g.targets[@intCast(i)] = t;
        _ = occupancy.attach(g, t, bd);
        t.target.kind = g.targetKinds[@intCast(i)];
    }
    _ = startTimer(g, targetAt(g, 0), g.timerIds[4], g.timerPeriods[4], 0);
    _ = startTimer(g, targetAt(g, 0), g.timerIds[5], @bitCast(@as(u16, 0xea60)), 99);
    targetAt(g, 0).target.clockTicks = 0;
    i = 0;
    while (i < 3) : (i += 1) targetAt(g, 0).target.laneBusy[@intCast(i)] = 0;
    _ = startTimer(g, targetAt(g, 13), lane2Timer(g), g.timerPeriods[4], 13);
}

/// The id of lane 2's spawn timer (BUGS.md K5: 9 with `serial_lane2_own_timer`).
fn lane2Timer(g: *Game) i16 {
    return if (g.fixes.serial_lane2_own_timer) g.timerIds[6] else g.timerIds[7];
}

/// Not in the original (`Fixes.serial_intro_screen`): the game's three timers
/// (the spawns every 5 s, lane 2's, the 60-s clock) stop while the intro screen
/// is up ...
pub fn disarmTimers(g: *Game) void {
    g.killSystemTimer(@bitCast(g.timerIds[4]));
    g.killSystemTimer(@bitCast(g.timerIds[5]));
    g.killSystemTimer(@bitCast(lane2Timer(g)));
}

/// ... and start, as `createTargets` starts them, when it goes.
pub fn armTimers(g: *Game) void {
    _ = startTimer(g, targetAt(g, 0), g.timerIds[4], g.timerPeriods[4], 0);
    _ = startTimer(g, targetAt(g, 0), g.timerIds[5], @bitCast(@as(u16, 0xea60)), 99);
    _ = startTimer(g, targetAt(g, 13), lane2Timer(g), g.timerPeriods[4], 13);
}

/// `operator_new(0x4c8)` + `target_ctor` for figure `i`. A failed
/// allocation is a null object in the original, which then crashes.
fn newTarget(g: *Game, i: usize, period: i16, timer_id: i16) Error!*Object {
    const t = g.local().create(Object) catch return error.OutOfMemory;
    t.* = .{ .kind = .target };
    try object_create.targetCtor(
        g,
        t,
        0,
        0x118,
        1,
        g.targetStripFiles[i..],
        g.targetStripFrames[i..],
        g.targetStripWidths[i..],
        g.targetStripHeights[i..],
        0,
        0,
        g.targetStripWidths[i],
        g.targetStripHeights[i],
        timer_id,
        period,
        0x14,
        0x14,
        0,
        0,
        true,
    );
    return t;
}

/// TargetVtbl slot 01 startTimer (target_start_timer; hwnd dropped): stores
/// `timer_id` by `index` (0-12 timerId2, 13-14 timerId13, 99 clockTimerId)
/// and arms the system timer (`elapse` ms: the original's int, 60000 is
/// passed as -0x15a0). Returns the target.
// @orig 1068:035c target_start_timer
pub fn startTimer(g: *Game, obj: *Object, timer_id: i16, elapse: i16, index: i16) *Object {
    if (index >= 0) {
        if (index < 0xd) {
            obj.target.timerId2 = timer_id;
        } else if (index == 13 or index == 14) {
            obj.target.timerId13 = timer_id;
        } else if (index == 99) {
            obj.target.clockTimerId = timer_id;
        }
    }
    g.setSystemTimer(@bitCast(timer_id), @bitCast(elapse));
    return obj;
}

/// Frees the lane of figure `index` in `g_targets[0]->laneBusy`:
/// 0-6 lane 0, 7-12 lane 1, else lane 2.
fn freeLane(g: *Game, index: i16) void {
    const lane: usize = if (index < 7) 0 else if (index < 0xd) 1 else 2;
    targetAt(g, 0).target.laneBusy[lane] = 0;
}

// @orig 1068:0c42 target_hit
/// A figure was hit (`obj` = `this`, `index` its number). Kind 1: +100;
/// kind 0: -100; kind 2: +200 (`morte2.wav`, score box). Then it stops and
/// hides (virtual stopMovingDc of `g_targets[index]`), frees its lane, and
/// `hideAndBlit`. No animation, no respawn.
pub fn hit(g: *Game, obj: *Object, bd: *Backdrop, index: i16) void {
    if (obj.target.kind == 1) hitKind1(g, bd) else hitKind0_2(g, bd, obj.target.kind == 2);
    movement.stopMovingDc(g, targetAt(g, index), bd);
    freeLane(g, index);
    hideAndBlit(g, obj, bd, index);
}

// @orig 1068:0d0d target_hide_and_blit
/// hideAndInvalidate on `g_targets[index]` and a blit of its rectangle to
/// the window (`mover_blit_to_dc`, the one blitToDc dispatches to). `obj`
/// (`this`) is not read.
pub fn hideAndBlit(g: *Game, obj: *Object, bd: *Backdrop, index: i16) void {
    _ = obj;
    const t = targetAt(g, index);
    visibility.hideAndInvalidate(g, t, 0, bd);
    visibility.blitToDc(g, t, bd);
}

/// TargetVtbl slot 03 checkEdge (target_wrap_at_edge; hwnd dropped): the
/// edge test of figure `index` (0-14). `obj` (`this`) gives the width, the
/// flag and the stop; the position and direction come from
/// `g_targets[index]`. Moving left (direction 1) at x <= -(width / 2):
/// `wrapFlag` = 1, stop (virtual), lane freed, hide, blit, then x =
/// `bgWidth - width` with `targetX` = `nextX` = x. Moving right
/// (direction 2) at x >= 630: `wrapFlag` = 0, the same, then x = 0x18 only.
/// After either, and otherwise, one `moveTick` of `g_targets[index]`
/// (a no-op once stopped).
// @orig 1068:0f59 target_wrap_at_edge
pub fn checkEdge(g: *Game, obj: *Object, bd: *Backdrop, index: i16) void {
    const t = targetAt(g, index);
    const w = position.width(obj);
    if (t.x <= 0 -% @divTrunc(w, 2) and t.mover.direction == 1) {
        obj.target.wrapFlag = 1;
        movement.stopMovingDc(g, obj, bd);
        freeLane(g, index);
        visibility.hideAndInvalidate(g, obj, 0, bd);
        visibility.blitToDc(g, obj, bd);
        t.x = 0 -% (position.width(obj) -% bd.bgWidth);
        t.mover.targetX = t.x;
        t.nextX = t.mover.targetX;
    } else if (t.x > 0x275 and t.mover.direction == 2) {
        obj.target.wrapFlag = 0;
        movement.stopMovingDc(g, obj, bd);
        freeLane(g, index);
        visibility.hideAndInvalidate(g, obj, 0, bd);
        visibility.blitToDc(g, obj, bd);
        t.x = 0x18;
    }
    movement.moveTick(g, targetAt(g, index), bd);
}

// @orig 1068:47b2 serial_hit_kind1
/// Kind 1 hit: `morte2.wav`, score + 100 (no clamp), the box.
fn hitKind1(g: *Game, bd: *Backdrop) void {
    _ = sound.play(g, 0, g.hitWave);
    g.score +%= 100;
    drawScore(g, bd);
    blitScoreBox(g, bd);
}

// @orig 1068:480c serial_hit_kind0_2
/// Kind 0 / 2 hit: `morte2.wav`, score - 100 (kind 0) or + 200 (kind 2),
/// no clamp (it goes negative), the box.
fn hitKind0_2(g: *Game, bd: *Backdrop, is_kind2: bool) void {
    _ = sound.play(g, 0, g.hitWave);
    g.score -%= if (is_kind2) -200 else 100;
    drawScore(g, bd);
    blitScoreBox(g, bd);
}

// @orig 1068:4871 serial_blit_score_box
/// WinGBitBlt of the 192 x 32 score box at (416, 400) from the backdrop to
/// the window (the palette calls are the platform's).
pub fn blitScoreBox(g: *Game, bd: *Backdrop) void {
    g.plat.wingBitBlt(0x1a0, 400, 0xc0, 0x20, bd.surface(), 0x1a0, 400);
}

// @orig 1068:48bc serial_draw_score
/// Restores the score box (416, 400, 192 x 32) from the background onto the
/// backdrop (key `g_unk00A8`), then draws `sprintf(" %04d", score)` or, for
/// a negative score, `sprintf("-%04d", -score)`, one `TextOut` per character
/// (the leading space too) at x = 460 + 32 i, y = 408, near white
/// (0xEDEEEE, TIRO's is black), transparent.
pub fn drawScore(g: *Game, bd: *Backdrop) void {
    if (bd.background) |bg| {
        if (bd.pixels.len != 0) {
            _ = dib.copyTransparent(&bd.bmiHeader, bd.pixels, 0x1a0, 400, bg.bits, &bg.header, 0x1a0, 400, 0xc0, 0x20, g.unk00A8) catch |e|
                std.debug.panic("serial target: score box restore left its buffers ({s})", .{@errorName(e)});
        }
    }
    const style: platform.TextStyle = .{ .color = 0xedeeee, .bk_mode = .transparent };
    var buf: [16]u8 = undefined;
    const text = formatScore(&buf, g.score);
    var x: i16 = 0x1cc;
    for (0..text.len) |i| {
        _ = g.plat.textOut(bd.surface(), style, x, 0x198, text[i..][0..1]);
        x +%= 0x20;
    }
}

/// Not in the original (`Fixes.serial_lives_display`): the lives' box, at the
/// bottom left as the score's is at the bottom right, where nothing is drawn but the
/// gun (x 200 and on) and the left-aim bullet (above y 350). Near the score's, the
/// gun's and the right-aim bullet's rectangles restore the background over it. The
/// score's art is 200 x 36, a little more than the 192 x 32 that is restored.
const lives_x: i16 = 0;
const lives_y: i16 = 400;

/// The score box's picture (restored from the background, as `drawScore` does)
/// copied to the left, then "Vidas:" and the lives drawn in its colour and font,
/// the digit where the score's last one is.
pub fn drawLives(g: *Game, bd: *Backdrop) void {
    if (bd.background) |bg| {
        if (bd.pixels.len != 0) {
            _ = dib.copyRect(&bd.bmiHeader, bd.pixels, lives_x, lives_y, bg.bits, &bg.header, 0x1a0, 400, 200, 36) catch |e|
                std.debug.panic("serial target: lives box copy left its buffers ({s})", .{@errorName(e)});
        }
    }
    const style: platform.TextStyle = .{ .color = 0xedeeee, .bk_mode = .transparent };
    _ = g.plat.textOut(bd.surface(), style, lives_x + 16, lives_y + 8, "Vidas:");
    var buf: [8]u8 = undefined;
    const digits = std.fmt.bufPrint(&buf, "{d}", .{@max(g.lives, 0)}) catch "?";
    _ = g.plat.textOut(bd.surface(), style, lives_x + 0xac, lives_y + 8, digits);
}

/// WinGBitBlt of the lives' box to the window.
pub fn blitLivesBox(g: *Game, bd: *Backdrop) void {
    g.plat.wingBitBlt(lives_x, lives_y, 0xc0, 0x20, bd.surface(), lives_x, lives_y);
}

/// `sprintf(text, "-%04d", -score)` or `" %04d"`; for -32768 the negation
/// wraps to -32768 again and `%04d` prints "-32768".
fn formatScore(buf: *[16]u8, score: i16) []const u8 {
    if (score < 0) {
        const v: i16 = 0 -% score;
        const sign: []const u8 = if (v < 0) "-" else "";
        return std.fmt.bufPrint(buf, "-{s}{d:0>4}", .{ sign, @abs(v) }) catch unreachable;
    }
    return std.fmt.bufPrint(buf, " {d:0>4}", .{@as(u16, @intCast(score))}) catch unreachable;
}

test "formatScore is sprintf's" {
    var b: [16]u8 = undefined;
    try std.testing.expectEqualStrings(" 0000", formatScore(&b, 0));
    try std.testing.expectEqualStrings(" 0150", formatScore(&b, 150));
    try std.testing.expectEqualStrings("-0150", formatScore(&b, -150));
    try std.testing.expectEqualStrings("--32768", formatScore(&b, std.math.minInt(i16)));
}
