//! Port unit `condition` (module). exit conditions: Condition and FlagCondition, the two static conditions.

const std = @import("std");

const world = @import("core/world.zig");
const Condition = world.Condition;
const Game = @import("core/game.zig").Game;

/// Virtual slot 00: whether the condition holds. The base class's vtable
/// (1010:9f36) answers true; a flag condition answers its stored flag.
pub fn evaluate(cond: *const Condition) i16 {
    return switch (cond.kind) {
        .base => 1,
        .flag => flagConditionEvaluate(cond),
    };
}

/// Virtual slot 01: sets the condition. Only flag conditions are ever set
/// (the base vtable's entry was not traced; it is treated as a no-op that
/// reports success).
pub fn set(cond: *Condition) i16 {
    return switch (cond.kind) {
        .base => 1,
        .flag => flagConditionSet(cond),
    };
}

/// Virtual slot 02: clears the condition (see `set` for the base case).
pub fn clear(cond: *Condition) i16 {
    return switch (cond.kind) {
        .base => 1,
        .flag => flagConditionClear(cond),
    };
}

// @orig 1010:0a74 flag_condition_set
fn flagConditionSet(cond: *Condition) i16 {
    cond.value = 1;
    return 1;
}

// @orig 1010:0a8c flag_condition_clear
fn flagConditionClear(cond: *Condition) i16 {
    cond.value = 0;
    return 1;
}

// @orig 1010:0aa6 flag_condition_evaluate
fn flagConditionEvaluate(cond: *const Condition) i16 {
    return cond.value;
}

// @orig 1010:7644 condition_ctor
/// The base constructor only installs the base vtable: `kind = .base`.
fn conditionCtor(cond: *Condition) *Condition {
    cond.kind = .base;
    return cond;
}

// @orig 1018:1dcc flag_condition_ctor
pub fn flagConditionCtor(cond: *Condition, value: i16) *Condition {
    _ = conditionCtor(cond);
    cond.kind = .flag; // overwrites the base vtable with the flag one
    cond.value = value;
    return cond;
}

// @orig 1018:1e52 init_static_conditions
pub fn initStaticConditions(g: *Game) void {
    _ = flagConditionCtor(&g.conditionTrue, 1);
    _ = flagConditionCtor(&g.conditionFalse, 0);
}

test "static conditions" {
    var c: Condition = .{};
    try std.testing.expectEqual(@as(i16, 1), evaluate(&c));
    _ = flagConditionCtor(&c, 0);
    try std.testing.expectEqual(@as(i16, 0), evaluate(&c));
    try std.testing.expectEqual(@as(i16, 1), set(&c));
    try std.testing.expectEqual(@as(i16, 1), evaluate(&c));
    _ = clear(&c);
    try std.testing.expectEqual(@as(i16, 0), evaluate(&c));
}
