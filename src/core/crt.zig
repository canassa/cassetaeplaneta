//! The MSVC 1.5 C runtime pieces whose behaviour the game depends on.
//! Replaced CRT functions are not ported units; their behaviour lives here
//! (or in the platform for I/O), cited with plain comments.

/// rand()/srand() (1008:05e8 / 1008:05d0): the CRT LCG. `random_below`
/// reseeds it from time() on every call, so the clock (platform
/// `unixTime`) decides the sequence; tests inject it.
pub const Rand = struct {
    // g_crtHoldRand
    seed: u32 = 1,

    pub fn srand(r: *Rand, s: u16) void {
        r.seed = s;
    }

    pub fn rand(r: *Rand) i16 {
        r.seed = r.seed *% 0x343fd +% 0x269ec3;
        return @intCast((r.seed >> 16) & 0x7fff);
    }
};

test "rand follows the CRT LCG" {
    var r: Rand = .{};
    // MSVC: srand(1); rand() → 41, 18467, 6334
    try @import("std").testing.expectEqual(@as(i16, 41), r.rand());
    try @import("std").testing.expectEqual(@as(i16, 18467), r.rand());
    try @import("std").testing.expectEqual(@as(i16, 6334), r.rand());
}
