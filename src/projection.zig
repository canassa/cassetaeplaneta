//! Port unit `projection` (module). Perspective projection between world
//! coordinates (x, depth, height) and screen coordinates, through the
//! backdrop's vanishing point.
//!
//! The original calls the backdrop's virtual getters (`getVanishX`,
//! `getVanishY`, `getEyeDistance`, `getAxisX`, slots 0x0C/0x0D/0x0E/0x0F).
//! Only PerspectiveBackdrop exists and its getters are plain field reads, so
//! the port reads the `Backdrop` fields directly. The original's out-pointers
//! become a returned struct.
//!
//! Arithmetic follows the original's machine code: values are 16-bit `int`s,
//! sign-extended to 32 bits for the products and quotients (`IMUL`/`IDIV`
//! keep the low 32 bits), and the results are truncated back to 16 bits.

const std = @import("std");
const Backdrop = @import("core/world.zig").Backdrop;

/// A screen position (the original's `*out_sx`, `*out_sy`).
pub const ScreenPoint = struct { x: i16, y: i16 };

/// A world position on the ground plane (the original's `*out_x`,
/// `*out_depth`).
pub const WorldPoint = struct { x: i16, depth: i16 };

/// `IMUL ECX` then `CDQ; IDIV ECX`: the product keeps its low 32 bits, the
/// division truncates toward zero. `b` must be non-zero. (The one case the
/// CPU faults on, `minInt(i32) / -1`, is memory-corruption territory; it
/// wraps here.)
fn mulDiv(a: i32, m: i32, b: i32) i16 {
    const prod: i32 = a *% m;
    const q: i64 = @divTrunc(@as(i64, prod), @as(i64, b));
    return @truncate(q);
}

// @orig 1010:4964 perspective_project_point
/// Projects the world point (`x`, `depth`, `height`) onto the view. Screen
/// `y` is measured from the top of the view; `bd.vanishY` is measured up
/// from the bottom.
///
/// When `eyeDistance + depth` is zero as a 16-bit sum, the point is placed at
/// the vanishing point (no division). Otherwise the divisor is the 32-bit
/// sum, which is never zero then.
pub fn projectPoint(bd: *const Backdrop, x: i16, depth: i16, height: i16) ScreenPoint {
    const xa: i16 = x -% bd.axisX;
    if (bd.eyeDistance +% depth == 0) {
        return .{ .x = bd.vanishX, .y = -%(bd.vanishY -% bd.viewHeight) };
    }
    const d: i32 = depth;
    const denom: i32 = @as(i32, bd.eyeDistance) + d;
    const sx = mulDiv(@as(i32, bd.vanishX) - xa, d, denom) +% xa;
    const sy = mulDiv(@as(i32, height) - bd.vanishY, d, denom) +% bd.viewHeight -% height;
    return .{ .x = sx, .y = sy };
}

// @orig 1010:4836 perspective_unproject_point
/// Inverse of `projectPoint` for a point at `height`: `screen_y` is measured
/// up from the bottom, like `bd.vanishY`. On the horizon row (`screen_y ==
/// vanishY`) the point is at `axisX + screen_x` and `depth == vanishY`
/// (sic: the original returns the vanishing y as the depth there).
pub fn unprojectPoint(bd: *const Backdrop, height: i16, screen_x: i16, screen_y: i16) WorldPoint {
    if (screen_y == bd.vanishY) {
        return .{ .x = bd.axisX +% screen_x, .depth = bd.vanishY };
    }
    const sy: i32 = screen_y;
    const dy: i32 = sy - bd.vanishY; // nonzero
    const x = mulDiv(@as(i32, bd.vanishX) - screen_x, sy - height, dy) +% bd.axisX +% screen_x;
    const depth = mulDiv(@as(i32, height) - sy, bd.eyeDistance, dy);
    return .{ .x = x, .depth = depth };
}

fn testBackdrop(c: [5]i16) Backdrop {
    return .{ .axisX = c[0], .eyeDistance = c[1], .vanishX = c[2], .vanishY = c[3], .viewHeight = c[4] };
}

// Expected values: the original functions run in tools/oracle (Unicorn),
// with fake getters returning the configured values. Configs are
// { axisX, eyeDistance, vanishX, vanishY, viewHeight }; they include
// eye + depth == 0, a horizon row, and 16/32-bit wraparound.

// @orig 1010:4964 perspective_project_point oracle=emulated
test "projectPoint matches the original" {
    // points are { x, depth, height }
    const cases = [_]struct { [5]i16, [3]i16, [2]i16 }{
        .{ .{ 10, 200, 320, 100, 480 }, .{ 50, 100, 30 }, .{ 133, 427 } },
        .{ .{ 10, 200, 320, 100, 480 }, .{ 50, 0, 0 }, .{ 40, 480 } },
        .{ .{ 10, 200, 320, 100, 480 }, .{ 0, -200, 30 }, .{ 320, 380 } },
        .{ .{ 10, 200, 320, 100, 480 }, .{ -300, 500, 300 }, .{ 140, 322 } },
        .{ .{ 10, 200, 320, 100, 480 }, .{ 32767, 32767, 32767 }, .{ 517, 181 } },
        .{ .{ 10, 200, 320, 100, 480 }, .{ -32768, -32768, -32768 }, .{ 121, 179 } },
        .{ .{ 10, 200, 320, 100, 480 }, .{ 100, -200, 0 }, .{ 320, 380 } },
        .{ .{ 10, 200, 320, 100, 480 }, .{ 0, 30000, -20000 }, .{ 317, 514 } },
        .{ .{ 10, 200, 320, 100, 480 }, .{ -5, 0, 3 }, .{ -15, 477 } },
        .{ .{ 10, 200, 320, 100, 480 }, .{ 1, 2, 3 }, .{ -6, 477 } },
        .{ .{ 0, 0, 320, 100, 480 }, .{ 50, 100, 30 }, .{ 320, 380 } },
        .{ .{ 0, 0, 320, 100, 480 }, .{ 50, 0, 0 }, .{ 320, 380 } },
        .{ .{ 0, 0, 320, 100, 480 }, .{ 0, -200, 30 }, .{ 320, 380 } },
        .{ .{ 0, 0, 320, 100, 480 }, .{ -300, 500, 300 }, .{ 320, 380 } },
        .{ .{ 0, 0, 320, 100, 480 }, .{ 32767, 32767, 32767 }, .{ 320, 380 } },
        .{ .{ 0, 0, 320, 100, 480 }, .{ -32768, -32768, -32768 }, .{ 320, 380 } },
        .{ .{ 0, 0, 320, 100, 480 }, .{ 100, -200, 0 }, .{ 320, 380 } },
        .{ .{ 0, 0, 320, 100, 480 }, .{ 0, 30000, -20000 }, .{ 320, 380 } },
        .{ .{ 0, 0, 320, 100, 480 }, .{ -5, 0, 3 }, .{ 320, 380 } },
        .{ .{ 0, 0, 320, 100, 480 }, .{ 1, 2, 3 }, .{ 320, 380 } },
        .{ .{ -7, 32767, -300, -5, 32767 }, .{ 50, 100, 30 }, .{ 56, 32737 } },
        .{ .{ -7, 32767, -300, -5, 32767 }, .{ 50, 0, 0 }, .{ 57, 32767 } },
        .{ .{ -7, 32767, -300, -5, 32767 }, .{ 0, -200, 30 }, .{ 8, 32737 } },
        .{ .{ -7, 32767, -300, -5, 32767 }, .{ -300, 500, 300 }, .{ -293, 32471 } },
        .{ .{ -7, 32767, -300, -5, 32767 }, .{ 32767, 32767, 32767 }, .{ -16531, 16386 } },
        .{ .{ -7, 32767, -300, -5, 32767 }, .{ -32768, -32768, -32768 }, .{ 7, 32767 } },
        .{ .{ -7, 32767, -300, -5, 32767 }, .{ 100, -200, 0 }, .{ 109, 32767 } },
        .{ .{ -7, 32767, -300, -5, 32767 }, .{ 0, 30000, -20000 }, .{ -139, -22325 } },
        .{ .{ -7, 32767, -300, -5, 32767 }, .{ -5, 0, 3 }, .{ 2, 32764 } },
        .{ .{ -7, 32767, -300, -5, 32767 }, .{ 1, 2, 3 }, .{ 8, 32764 } },
        .{ .{ 5, -30000, 32000, -32000, -32768 }, .{ 50, 100, 30 }, .{ -61, 32631 } },
        .{ .{ 5, -30000, 32000, -32000, -32768 }, .{ 50, 0, 0 }, .{ 45, -32768 } },
        .{ .{ 5, -30000, 32000, -32000, -32768 }, .{ 0, -200, 30 }, .{ 206, -32586 } },
        .{ .{ 5, -30000, 32000, -32000, -32768 }, .{ -300, 500, 300 }, .{ -852, 31921 } },
        .{ .{ 5, -30000, 32000, -32000, -32768 }, .{ 32767, 32767, 32767 }, .{ 23739, -19456 } },
        .{ .{ 5, -30000, 32000, -32000, -32768 }, .{ -32768, -32768, -32768 }, .{ 32365, -400 } },
        .{ .{ 5, -30000, 32000, -32000, -32768 }, .{ 100, -200, 0 }, .{ 306, -32557 } },
        .{ .{ 5, -30000, 32000, -32000, -32768 }, .{ 0, 30000, -20000 }, .{ 32000, -768 } },
        .{ .{ 5, -30000, 32000, -32000, -32768 }, .{ -5, 0, 3 }, .{ -10, 32765 } },
        .{ .{ 5, -30000, 32000, -32000, -32768 }, .{ 1, 2, 3 }, .{ -6, 32763 } },
    };
    for (cases) |c| {
        const r = projectPoint(&testBackdrop(c[0]), c[1][0], c[1][1], c[1][2]);
        try std.testing.expectEqual(c[2][0], r.x);
        try std.testing.expectEqual(c[2][1], r.y);
    }
}

// @orig 1010:4836 perspective_unproject_point oracle=emulated
test "unprojectPoint matches the original" {
    // points are { height, screen_x, screen_y }
    const cases = [_]struct { [5]i16, [3]i16, [2]i16 }{
        .{ .{ 10, 200, 320, 100, 480 }, .{ 30, 320, 50 }, .{ 330, 80 } },
        .{ .{ 10, 200, 320, 100, 480 }, .{ 30, 320, 100 }, .{ 330, 100 } },
        .{ .{ 10, 200, 320, 100, 480 }, .{ 0, 0, 0 }, .{ 10, 0 } },
        .{ .{ 10, 200, 320, 100, 480 }, .{ 0, -5, 100 }, .{ 5, 100 } },
        .{ .{ 10, 200, 320, 100, 480 }, .{ -100, 40, -32768 }, .{ 328, -198 } },
        .{ .{ 10, 200, 320, 100, 480 }, .{ 32767, -32768, 32767 }, .{ -32758, 0 } },
        .{ .{ 10, 200, 320, 100, 480 }, .{ 0, 640, 479 }, .{ 246, -252 } },
        .{ .{ 10, 200, 320, 100, 480 }, .{ 300, 100, 99 }, .{ -21206, 25336 } },
        .{ .{ 10, 200, 320, 100, 480 }, .{ -300, 32767, -1 }, .{ -2240, 592 } },
        .{ .{ 0, 0, 320, 100, 480 }, .{ 30, 320, 50 }, .{ 320, 0 } },
        .{ .{ 0, 0, 320, 100, 480 }, .{ 30, 320, 100 }, .{ 320, 100 } },
        .{ .{ 0, 0, 320, 100, 480 }, .{ 0, 0, 0 }, .{ 0, 0 } },
        .{ .{ 0, 0, 320, 100, 480 }, .{ 0, -5, 100 }, .{ -5, 100 } },
        .{ .{ 0, 0, 320, 100, 480 }, .{ -100, 40, -32768 }, .{ 318, 0 } },
        .{ .{ 0, 0, 320, 100, 480 }, .{ 32767, -32768, 32767 }, .{ -32768, 0 } },
        .{ .{ 0, 0, 320, 100, 480 }, .{ 0, 640, 479 }, .{ 236, 0 } },
        .{ .{ 0, 0, 320, 100, 480 }, .{ 300, 100, 99 }, .{ -21216, 0 } },
        .{ .{ 0, 0, 320, 100, 480 }, .{ -300, 32767, -1 }, .{ -2250, 0 } },
        .{ .{ -7, 32767, -300, -5, 32767 }, .{ 30, 320, 50 }, .{ 88, -11915 } },
        .{ .{ -7, 32767, -300, -5, 32767 }, .{ 30, 320, 100 }, .{ -100, -21844 } },
        .{ .{ -7, 32767, -300, -5, 32767 }, .{ 0, 0, 0 }, .{ -7, 0 } },
        .{ .{ -7, 32767, -300, -5, 32767 }, .{ 0, -5, 100 }, .{ -292, -31206 } },
        .{ .{ -7, 32767, -300, -5, 32767 }, .{ -100, 40, -32768 }, .{ -306, -32671 } },
        .{ .{ -7, 32767, -300, -5, 32767 }, .{ 32767, -32768, 32767 }, .{ 32761, 0 } },
        .{ .{ -7, 32767, -300, -5, 32767 }, .{ 0, 640, 479 }, .{ -297, -32428 } },
        .{ .{ -7, 32767, -300, -5, 32767 }, .{ 300, 100, 99 }, .{ 866, -2208 } },
        .{ .{ -7, 32767, -300, -5, 32767 }, .{ -300, 32767, -1 }, .{ -14166, -24501 } },
        .{ .{ 5, -30000, 32000, -32000, -32768 }, .{ 30, 320, 50 }, .{ 344, 18 } },
        .{ .{ 5, -30000, 32000, -32000, -32768 }, .{ 30, 320, 100 }, .{ 394, 65 } },
        .{ .{ 5, -30000, 32000, -32000, -32768 }, .{ 0, 0, 0 }, .{ 5, 0 } },
        .{ .{ 5, -30000, 32000, -32000, -32768 }, .{ 0, -5, 100 }, .{ 99, 93 } },
        .{ .{ 5, -30000, 32000, -32000, -32768 }, .{ -100, 40, -32768 }, .{ -16746, 30909 } },
        .{ .{ 5, -30000, 32000, -32000, -32768 }, .{ 32767, -32768, 32767 }, .{ -32763, 0 } },
        .{ .{ 5, -30000, 32000, -32000, -32768 }, .{ 0, 640, 479 }, .{ 1107, 442 } },
        .{ .{ 5, -30000, 32000, -32000, -32768 }, .{ 300, 100, 99 }, .{ -94, -187 } },
        .{ .{ 5, -30000, 32000, -32000, -32768 }, .{ -300, 32767, -1 }, .{ 32765, 280 } },
    };
    for (cases) |c| {
        const r = unprojectPoint(&testBackdrop(c[0]), c[1][0], c[1][1], c[1][2]);
        try std.testing.expectEqual(c[2][0], r.x);
        try std.testing.expectEqual(c[2][1], r.depth);
    }
}
