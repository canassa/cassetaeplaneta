//! Skeleton helper: the body of a declared but not yet ported function
//! (a virtual-slot dispatcher whose owning unit is still pending). Calling
//! one is a bug in the port's progress, not in the game: it panics.

pub fn unported(comptime what: []const u8) noreturn {
    @panic("unported: " ++ what);
}
