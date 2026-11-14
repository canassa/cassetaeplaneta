//! Port unit `target` (module) of TIRO.EXE. the targets: creation, TargetVtbl checkEdge (the wrap), hit (+150 girl / -150 traveco), respawn, the score box.
//!
//! Each function carries `// @orig <seg:xxxx> <name>` with the TIRO address.
//! The hwnd and hdc parameters are dropped (the platform's screen).

const std = @import("std");
const msg = @import("../core/msg.zig");
const platform = @import("../platform/platform.zig");
const Game = @import("core/game.zig").Game;
const object = @import("core/object.zig");
const Object = object.Object;
const world = @import("core/world.zig");
const Backdrop = world.Backdrop;
const dib = @import("dib.zig");
const sound = @import("sound.zig");
const object_create = @import("object_create.zig");
const animation = @import("behaviour/animation.zig");
const movement = @import("behaviour/movement.zig");
const occupancy = @import("behaviour/occupancy.zig");
const position = @import("behaviour/position.zig");
const visibility = @import("behaviour/visibility.zig");

pub const Error = object_create.Error;

/// The target `index` (0-3); the original indexes `g_targets` unchecked.
fn targetAt(g: *Game, index: i16) *Object {
    return g.targets[@as(u16, @bitCast(index))].?;
}

// @orig 1068:0163 tiro_create_targets
/// Four Targets (kind `target`) from the ten strip tables, 100 ms timers
/// 0xc-0xf, steps 20 x 20, hit box 75 x 95. `srand(GetTickCount())` first;
/// each identity is `rand() % 10`, drawn right after the target is built
/// (upper `[i]`, then lower `[2+i]`, for i = 0, 1). Upper row y 0x55 at
/// x 44 and 207, lower row y 0x82 at x 124 and 287. All four attach, then
/// start moving at once from where they stand: `[0]`, `[1]` right
/// (`moveToEdgeH` 2), `[2]`, `[3]` left (`moveToEdgeH` 1), the direction
/// set after the call, `hitFrame` -1.
pub fn createTargets(g: *Game, bd: *Backdrop) Error!void {
    g.rand.srand(@truncate(g.plat.ticks()));
    var i: i16 = 0;
    while (i < 2) : (i += 1) {
        const upper = try newTarget(g, 0xc + i, 0x55, i *% 0xa3 +% 0x2c);
        g.targets[@intCast(i)] = upper;
        upper.curStrip = @rem(g.rand.rand(), 10);
        const lower = try newTarget(g, 0xe + i, 0x82, i *% 0xa3 +% 0x7c);
        g.targets[@intCast(2 + i)] = lower;
        lower.curStrip = @rem(g.rand.rand(), 10);
    }
    i = 0;
    while (i < 4) : (i += 1) {
        const t = g.targets[@intCast(i)].?;
        _ = occupancy.attach(g, t, bd);
        if (i < 2) {
            movement.moveToEdgeH(g, t, bd, 2);
            t.mover.direction = 2;
        } else {
            movement.moveToEdgeH(g, t, bd, 1);
            t.mover.direction = 1;
        }
        t.target.hitFrame = -1;
    }
}

/// `operator_new(0x4be)` + `target_ctor`. A failed allocation is a null
/// object in the original, which then crashes.
fn newTarget(g: *Game, timer_id: i16, y: i16, x: i16) Error!*Object {
    const t = g.local().create(Object) catch return error.OutOfMemory;
    t.* = .{ .kind = .target };
    try object_create.targetCtor(
        g,
        t,
        x,
        y,
        10,
        &g.targetStripFiles,
        &g.targetStripFrames,
        &g.targetStripWidths,
        &g.targetStripHeights,
        0,
        0,
        g.targetStripWidths[0],
        g.targetStripHeights[0],
        timer_id,
        100,
        0x14,
        0x14,
        1,
        0,
        true,
    );
    return t;
}

/// `mover_stop_moving_dc` (1028:15cb; `movement`'s copy is private): the
/// base stop that `target_hit` calls directly, without the Target
/// override's hide / place / blit. Not tagged: movement owns it.
fn moverStopMovingDc(g: *Game, obj: *Object) void {
    const m = &obj.mover;
    m.moving = 0;
    g.killSystemTimer(@bitCast(m.timerId));
    m.stepX = absI16(m.stepX);
    m.stepY = absI16(m.stepY);
    m.prevX = obj.x;
    m.targetX = obj.x;
    m.prevY = obj.y;
    m.targetY = obj.y;
    _ = g.post(.{ .id = msg.noite.movement_finished, .wparam = @bitCast(obj.id) });
}

// @orig 1068:08ab target_hit
/// A target was hit (`obj` = `this`, the one the handler found; `index` its
/// number: the original reads the stop, the timers and the hit counter
/// through `g_targets[index]`, the identity and the animation through
/// `this`). It stops (base `mover_stop_moving_dc`), `framesLeft` = 8, the
/// animation period 55 ms and the timer re-armed at 55 ms; identity < 3
/// (unsigned): girl +150, else traveco -150 (waves, score box);
/// `animation_play`, one tick (the first hit frame), `hitFrame` + 1.
/// Nothing guards a target already in its hit animation.
pub fn hit(g: *Game, obj: *Object, bd: *Backdrop, index: i16) void {
    const t = targetAt(g, index);
    moverStopMovingDc(g, t);
    t.anim.framesLeft = 8;
    t.anim.timerPeriod = 0x37;
    g.setSystemTimer(@bitCast(t.anim.timerId), 0x37);
    if (@as(u16, @bitCast(obj.curStrip)) < 3) hitGirl(g, bd) else hitTraveco(g, bd);
    animation.play(g, obj, bd);
    animation.tick(g, obj, bd);
    targetAt(g, index).target.hitFrame +%= 1;
}

// @orig 1068:0991 target_respawn
/// End of the hit animation of target `index`: `stopAndRedraw`; the mover's
/// period back to 100 ms (the animation's stays 55) and the timer re-armed
/// at 100; hide, new identity `rand() % 10`, blit. Then by index: 0 and 1
/// face right at x 0x18, 2 and 3 face left at `bgWidth - width`; `targetX`
/// = `nextX` = x. `[0]` and `[3]` start at once; `[1]` only when
/// |x0 - x1| > 0x58, `[2]` only when |x2 - x3| > 0xb0 (else they wait,
/// stopped, for the tick handler). `hitFrame` = -1. `obj` (`this`) is
/// not read.
pub fn respawn(g: *Game, obj: *Object, bd: *Backdrop, index: i16) void {
    _ = obj;
    const t = targetAt(g, index);
    animation.stopAndRedraw(g, t, bd);
    t.mover.timerPeriod = 100;
    g.setSystemTimer(@bitCast(t.anim.timerId), 100);
    visibility.hideAndInvalidate(g, t, 0, bd);
    t.curStrip = @rem(g.rand.rand(), 10);
    visibility.blitToDc(g, t, bd);
    switch (index) {
        0 => {
            t.mover.direction = 2;
            t.x = 0x18;
            t.mover.targetX = t.x;
            t.nextX = t.mover.targetX;
            movement.moveToEdgeH(g, t, bd, 2);
        },
        1 => {
            t.mover.direction = 2;
            t.x = 0x18;
            t.mover.targetX = t.x;
            t.nextX = t.mover.targetX;
            if (absI16(0 -% (targetAt(g, 0).x -% t.x)) > 0x58) movement.moveToEdgeH(g, t, bd, 2);
        },
        2 => {
            t.mover.direction = 1;
            t.x = 0 -% (position.width(t) -% bd.bgWidth);
            t.nextX = t.x;
            t.mover.targetX = t.nextX;
            if (absI16(0 -% (t.x -% targetAt(g, 3).x)) > 0xb0) movement.moveToEdgeH(g, t, bd, 1);
        },
        3 => {
            t.mover.direction = 1;
            t.x = 0 -% (position.width(t) -% bd.bgWidth);
            t.nextX = t.x;
            t.mover.targetX = t.nextX;
            movement.moveToEdgeH(g, t, bd, 1);
        },
        else => {},
    }
    targetAt(g, index).target.hitFrame = -1;
}

/// CRT `abs` (an int).
fn absI16(v: i16) i16 {
    return if (v < 0) 0 -% v else v;
}

/// TargetVtbl slot 02 checkEdge (target_wrap_at_edge; hwnd dropped): the
/// edge test of target `index` (0-3). `obj` (`this`) gives the width, the
/// flag and the calls; the position and direction come from
/// `g_targets[index]`. Moving left (direction 1) at x <= width / 2: `unk40`
/// = 1, stop (the Target's, virtual), hide, blit, then x = `bgWidth - width`
/// with `targetX` = `nextX` = x (it reappears on the right, still
/// moving). Moving right (direction 2) at x >= `bgWidth - 2 * width`:
/// `unk40` = 0, the same stop / hide / blit, then x = 0x18 only: it is
/// left stopped for the handler to re-arm. Otherwise one `moveTick`.
// @orig 1068:1037 target_wrap_at_edge
pub fn checkEdge(g: *Game, obj: *Object, bd: *Backdrop, index: i16) void {
    const t = targetAt(g, index);
    if (t.x <= @divTrunc(position.width(obj), 2) and t.mover.direction == 1) {
        obj.target.unk40 = 1;
        stopHideBlit(g, obj, bd);
        t.x = 0 -% (position.width(obj) -% bd.bgWidth);
        t.mover.targetX = t.x;
        t.nextX = t.mover.targetX;
    } else if (t.x >= 0 -% (position.width(obj) *% 2 -% bd.bgWidth) and t.mover.direction == 2) {
        obj.target.unk40 = 0;
        stopHideBlit(g, obj, bd);
        t.x = 0x18;
    } else {
        movement.moveTick(g, obj, bd);
    }
}

/// The wrap's three virtual calls: slot 32 stopMovingDc, 1C
/// hideAndInvalidate, 1D blitToDc.
fn stopHideBlit(g: *Game, obj: *Object, bd: *Backdrop) void {
    movement.stopMovingDc(g, obj, bd);
    visibility.hideAndInvalidate(g, obj, 0, bd);
    visibility.blitToDc(g, obj, bd);
}

// @orig 1068:2e1c tiro_hit_girl
/// Girl hit: `uii.wav`, `tirojogo.wav`, score + 150 (no clamp), the box.
pub fn hitGirl(g: *Game, bd: *Backdrop) void {
    _ = sound.play(g, 0, g.girlHitWave);
    _ = sound.play(g, 0, g.hitWave);
    g.score +%= 150;
    drawScore(g, bd);
    blitScoreBox(g, bd);
}

// @orig 1068:2daf tiro_hit_traveco
/// Traveco hit: `nossa.wav`, `tirojogo.wav`, score - 150 (no clamp: it goes
/// negative), the box.
pub fn hitTraveco(g: *Game, bd: *Backdrop) void {
    _ = sound.play(g, 0, g.travecoHitWave);
    _ = sound.play(g, 0, g.hitWave);
    g.score -%= 150;
    drawScore(g, bd);
    blitScoreBox(g, bd);
}

// @orig 1068:2e89 tiro_blit_score_box
/// WinGBitBlt of the 192 x 32 score box at (448, 400) from the backdrop to
/// the window (the palette calls are the platform's).
pub fn blitScoreBox(g: *Game, bd: *Backdrop) void {
    g.plat.wingBitBlt(0x1c0, 400, 0xc0, 0x20, bd.surface(), 0x1c0, 400);
}

// @orig 1068:2ed4 tiro_draw_score
/// Restores the score box (448, 400, 192 x 32) from the background onto the
/// backdrop (key `g_unk00A8`), then draws `sprintf(" %04d", score)` or, for
/// a negative score, `sprintf("-%04d", -score)`, one `TextOut` per character
/// (the leading space too) at x = 492 + 32 i, y = 408, black, transparent.
pub fn drawScore(g: *Game, bd: *Backdrop) void {
    if (bd.background) |bg| {
        if (bd.pixels.len != 0) {
            _ = dib.copyTransparent(&bd.bmiHeader, bd.pixels, 0x1c0, 400, bg.bits, &bg.header, 0x1c0, 400, 0xc0, 0x20, g.unk00A8) catch |e|
                std.debug.panic("tiro target: score box restore left its buffers ({s})", .{@errorName(e)});
        }
    }
    const style: platform.TextStyle = .{ .color = 0x000000, .bk_mode = .transparent };
    var buf: [16]u8 = undefined;
    const text = formatScore(&buf, g.score);
    var x: i16 = 0x1ec;
    for (0..text.len) |i| {
        _ = g.plat.textOut(bd.surface(), style, x, 0x198, text[i..][0..1]);
        x +%= 0x20;
    }
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
