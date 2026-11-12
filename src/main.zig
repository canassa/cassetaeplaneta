//! Noite Animal, native port. Placeholder entry point: the game loop and the
//! platform layer arrive with the design pass.
const std = @import("std");

pub fn main() void {
    std.debug.print("noite: nothing ported yet\n", .{});
}

test {
    // Pulls in every port unit's tests (the index is generated).
    _ = @import("units.zig");
}

test "the skeleton builds" {
    try std.testing.expect(true);
}
