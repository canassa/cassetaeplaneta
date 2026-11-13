//! Port unit `misc` (behaviour). SceneObject slots 00-04 (touched mark, RLE mode, scene name) and 1F (empty debug hook).

const std = @import("std");
const Game = @import("../core/game.zig").Game;
const object = @import("../core/object.zig");
const Object = object.Object;
const world = @import("../core/world.zig");
const Backdrop = world.Backdrop;
const cstr = @import("../core/cstr.zig");
const frames = @import("../frames.zig");

/// SceneObject slot 00: marks the object as touched (the default; never overridden).
pub fn slot00(g: *Game, obj: *Object) void {
    _ = g;
    // @orig 1010:12e6 FUN_1010_12e6
    obj.unk492 = 1;
}

/// SceneObject slot 01: reads the mark set by slot 00.
pub fn slot01(g: *Game, obj: *Object) i16 {
    _ = g;
    // @orig 1010:12fe FUN_1010_12fe
    return @bitCast(obj.unk492);
}

/// SceneObject slot 02: switches the object to RLE drawing. `rleBits`
/// points at the current strip's pixels (the original computes
/// dib + biSize + biClrUsed*4, i.e. just past the colour table) and the
/// header height is made negative (top-down). The height arithmetic is on
/// the low 16 bits, as in the original (`abs` then `neg`, sign-extended).
pub fn enableRle(g: *Game, obj: *Object) void {
    _ = g;
    // @orig 1010:b6d0 scene_object_enable_rle
    obj.rleMode = 1;
    const d = frames.dib(obj).?;
    obj.rleBits = d.bits;
    const lo: i16 = @truncate(obj.bmiHeader.biHeight);
    const a: i16 = if (lo < 0) 0 -% lo else lo;
    obj.bmiHeader.biHeight = 0 -% a;
}

/// SceneObject slot 03.
pub fn isRle(g: *Game, obj: *Object) bool {
    _ = g;
    // @orig 1010:1314 scene_object_is_rle
    return obj.rleMode != 0;
}

/// SceneObject slot 04: the name of the scene a persistent object belongs to.
pub fn getSceneName(g: *Game, obj: *Object) []const u8 {
    _ = g;
    // @orig 1010:132a scene_object_get_scene_name
    return cstr.slice(&obj.sceneName);
}

/// SceneObject slot 1F: every kind's implementation (the base and the
/// Animation one, plus the vtordisp thunks) only calls an empty helper.
pub fn slot1F(g: *Game, obj: *Object, bd: *Backdrop) void {
    _ = g;
    switch (obj.kind) {
        .animated, .actor, .player, .exit, .control_panel => animationSlot1F(obj, bd),
        else => slot1FDefault(obj, bd),
    }
}

// @orig 1010:1720 FUN_1010_1720
fn slot1FDefault(obj: *Object, bd: *Backdrop) void {
    debugDc(obj, 1, bd);
}

// @orig 1010:2776 FUN_1010_2776
// The Animation implementation (the vtordisp thunks 8b24, 85ce, 81c8,
// 7c6a, 7ee2 are absorbed here).
fn animationSlot1F(obj: *Object, bd: *Backdrop) void {
    debugDc(obj, 1, bd);
}

// @orig 1010:b348 FUN_1010_b348
fn debugDc(obj: *Object, flag: i16, bd: *Backdrop) void {
    _ = .{ flag, bd }; // the original passes bd->hdc (no DC in the port)
    debugEmpty(obj, 0);
}

// @orig 1010:b33e FUN_1010_b33e
// Empty body (compiled-out debug code).
fn debugEmpty(obj: *Object, hdc: u16) void {
    _ = .{ obj, hdc };
}
