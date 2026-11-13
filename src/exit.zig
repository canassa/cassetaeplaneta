//! Port unit `exit` (module). exit links and key objects; SceneObject slots 5F isEnabled and 60 getExitIndex.
//!
//! The Exit fields live in `Object.exit` (`ExitPart`); the setters take the
//! object (kind `.exit`) and return it, like the originals return `this`.

const Game = @import("core/game.zig").Game;
const object = @import("core/object.zig");
const Object = object.Object;
const world = @import("core/world.zig");
const condition = @import("condition.zig");
const object_list = @import("object_list.zig");

/// SceneObject slot 5F: evaluates the exit's condition; 0 when it has none.
pub fn isEnabled(g: *Game, obj: *Object) bool {
    _ = .{g};
    return switch (obj.kind) {
        // @orig 1010:1cf8 scene_object_is_enabled_default (absorbed)
        .local, .animated, .moveable, .actor, .player, .portable, .control_panel, .status_bar => false,
        .exit => exitIsEnabled(obj),
    };
}

/// SceneObject slot 60: the exit's index in its scene's exit table.
pub fn getExitIndex(g: *Game, obj: *Object) i16 {
    _ = .{g};
    return switch (obj.kind) {
        // @orig 1010:1d04 scene_object_get_exit_index_default (absorbed)
        .local, .animated, .moveable, .actor, .player, .portable, .control_panel, .status_bar => -1,
        .exit => exitGetExitIndex(obj),
    };
}

// @orig 1010:4190 exit_is_enabled
fn exitIsEnabled(obj: *Object) bool {
    const cond = obj.exit.condition orelse return false;
    return condition.evaluate(cond) != 0;
}

// @orig 1010:41ec exit_get_exit_index
fn exitGetExitIndex(obj: *Object) i16 {
    return obj.exit.exitIndex;
}

/// `_fstrncpy(dst, src, 0x13)` then `dst[0x13] = 0`: copies at most 19
/// chars, zero-padding like strncpy.
fn copyName(dst: *[20]u8, src: []const u8) void {
    var n: usize = 0;
    while (n < 19 and n < src.len and src[n] != 0) : (n += 1) dst[n] = src[n];
    @memset(dst[n..], 0);
}

// @orig 1010:6674 exit_has_key_object
/// True when the exit needs no key object or `player` (the game's player
/// when null) carries the object whose id is the exit's key; with `take`
/// the object moves from the player's inventory to the game's used list.
pub fn hasKeyObject(g: *Game, obj: *Object, take: bool, player: ?*Object) bool {
    const key = obj.exit.keyObject;
    if (key == 0) return true;
    const p = player orelse (g.player orelse @panic("exit.hasKeyObject: no player")).as(.player) orelse
        @panic("exit.hasKeyObject: asPlayer returned NULL"); // the original dereferences NULL
    var cur = p.actor.inventory.head;
    while (cur) |item| : (cur = item.next) {
        if (item.id != key) continue;
        if (take) {
            _ = object_list.remove(&p.actor.inventory, item);
            _ = object_list.add(g, &g.usedObjects, item);
        }
        return true;
    }
    return false;
}

// @orig 1018:2714 exit_set_link
pub fn setLink(obj: *Object, playerX: i16, playerY: i16, cond: ?*world.Condition, exitIndex: i16) *Object {
    obj.exit.playerX = playerX;
    obj.exit.playerY = playerY;
    obj.exit.condition = cond;
    obj.exit.exitIndex = exitIndex;
    obj.exit.playing = 0;
    return obj;
}

// @orig 1018:2756 exit_set_link_to_scene
pub fn setLinkToScene(obj: *Object, sceneName: []const u8, playerX: i16, playerY: i16, cond: ?*world.Condition, exitIndex: i16) *Object {
    copyName(&obj.exit.sceneName, sceneName);
    return setLink(obj, playerX, playerY, cond, exitIndex);
}

// @orig 1018:27be exit_set_alt_link
pub fn setAltLink(obj: *Object, altSceneName: []const u8, altX: i16, altY: i16, altExitIndex: i16) *Object {
    copyName(&obj.exit.altSceneName, altSceneName);
    obj.exit.altPlayerX = altX;
    obj.exit.altPlayerY = altY;
    obj.exit.altExitIndex = altExitIndex;
    return obj;
}

// @orig 1018:2814 exit_set_exit_index
pub fn setExitIndex(obj: *Object, exitIndex: i16) *Object {
    obj.exit.exitIndex = exitIndex;
    return obj;
}

// @orig 1018:68d8 exit_set_target
/// Initialises the link from an INI Exit line; the condition is the static
/// always-true one (1030:0), the exit index -1.
pub fn setTarget(g: *Game, obj: *Object, sceneName: []const u8, playerX: i16, playerY: i16, hasPlayer: i16, hasControlPanel: i16, hasStatusBar: i16) *Object {
    copyName(&obj.exit.sceneName, sceneName);
    obj.exit.playerX = playerX;
    obj.exit.playerY = playerY;
    obj.exit.hasPlayer = hasPlayer;
    obj.exit.hasControlPanel = hasControlPanel;
    obj.exit.hasStatusBar = hasStatusBar;
    obj.exit.condition = &g.conditionTrue;
    obj.exit.exitIndex = -1;
    obj.exit.playing = 0;
    return obj;
}

// @orig 1018:695a exit_set_key_object
pub fn setKeyObject(obj: *Object, keyObject: i16) *Object {
    obj.exit.keyObject = keyObject;
    return obj;
}

// @orig 1018:68d8 exit_set_target oracle=documented
test "set_target truncates the scene name to 19 chars and links the true condition" {
    const std = @import("std");
    var g: Game = undefined;
    g.conditionTrue = .{ .kind = .flag, .value = 1 };
    var o: Object = .{ .kind = .exit };
    _ = setTarget(&g, &o, "0123456789012345678901", 1, 2, 1, 0, 1);
    try std.testing.expectEqualStrings("0123456789012345678", @import("core/cstr.zig").slice(&o.exit.sceneName));
    try std.testing.expect(o.exit.condition == &g.conditionTrue);
    try std.testing.expectEqual(@as(i16, -1), getExitIndex(&g, &o));
    try std.testing.expect(isEnabled(&g, &o));
}
