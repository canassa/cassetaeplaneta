//! C strings in fixed buffers. The original's `char[N]` fields and locals
//! stay `[N]u8`, NUL-terminated; functions take `[]const u8` (a slice that
//! ends at the first NUL, see `slice`). The copies truncate instead of
//! overflowing: an overflow is memory corruption in the original, never
//! game behaviour (docs/DESIGN.md "Conventions").

const std = @import("std");

/// The string in `buf`: up to the first NUL (or all of it).
pub fn slice(buf: []const u8) []const u8 {
    return std.mem.sliceTo(buf, 0);
}

/// strcpy into a fixed buffer; truncates, always NUL-terminates.
pub fn copy(dst: []u8, src: []const u8) void {
    const s = slice(src);
    const n = @min(s.len, dst.len - 1);
    @memcpy(dst[0..n], s[0..n]);
    dst[n] = 0;
}

/// strcat into a fixed buffer; truncates, always NUL-terminates.
pub fn cat(dst: []u8, src: []const u8) void {
    const used = slice(dst).len;
    copy(dst[used..], src);
}

/// sprintf into a fixed buffer; truncates, always NUL-terminates.
pub fn print(dst: []u8, comptime fmt: []const u8, args: anytype) []const u8 {
    const out = std.fmt.bufPrint(dst[0 .. dst.len - 1], fmt, args) catch blk: {
        // Truncated: bufPrint wrote as much as fit.
        break :blk dst[0 .. dst.len - 1];
    };
    dst[out.len] = 0;
    return out;
}

/// _fstricmp == 0 (ASCII case folding, like the CRT).
pub fn eqlIgnoreCase(a: []const u8, b: []const u8) bool {
    return std.ascii.eqlIgnoreCase(slice(a), slice(b));
}

/// A buffer of `n` bytes holding `s`, for initialising `[n]u8` fields.
pub fn init(comptime n: usize, s: []const u8) [n]u8 {
    var b: [n]u8 = @splat(0);
    copy(&b, s);
    return b;
}

test "copy and cat truncate and terminate" {
    var b: [6]u8 = undefined;
    copy(&b, "abc");
    try std.testing.expectEqualStrings("abc", slice(&b));
    cat(&b, "defgh");
    try std.testing.expectEqualStrings("abcde", slice(&b));
    _ = print(&b, "{d}", .{1234567});
    try std.testing.expectEqualStrings("12345", slice(&b));
}
