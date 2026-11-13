//! Port unit `portable` (module). portable items: pick up, drop, move to scene, icons.
//!
//! A portable item is in exactly one of two places: the owner's inventory
//! (`portable.owner` set, on no scene) or on a scene (`owner` null, listed
//! in `g.globalObjects`, scene named by `sceneName`). `prevSceneName`
//! remembers the scene it came from. Each function ends by setting the
//! SceneObject `unk492` mark and returns the item.
//!
//! The original copies `char*` arguments with strncpy(…, 0x13) and writes a
//! NUL at index 0x13; the swap in `moveToScene` goes through a 18-byte
//! stack buffer that a 20-character name would overflow (not reachable
//! with the shipped scene names; here the buffer is large enough).

const std = @import("std");
const Game = @import("core/game.zig").Game;
const object = @import("core/object.zig");
const Object = object.Object;
const world = @import("core/world.zig");
const Backdrop = world.Backdrop;
const Scene = world.Scene;
const cstr = @import("core/cstr.zig");
const object_list = @import("object_list.zig");
const draw_list = @import("draw_list.zig");
const dib = @import("dib.zig");

/// strncpy(dst, src, 0x13) followed by dst[0x13] = 0.
fn setSceneName(dst: *[22]u8, src: []const u8) void {
    const s = cstr.slice(src);
    const n = @min(s.len, 0x13);
    @memcpy(dst[0..n], s[0..n]);
    @memset(dst[n..0x13], 0);
    dst[0x13] = 0;
}

// @orig 1010:6fe6 portable_pick_up
/// Gives the item to `owner`: from the global object list (the current scene
/// becomes the previous one) or from its current owner's inventory; takes it
/// off the draw list.
pub fn pickUp(g: *Game, obj: *Object, owner: *Object) *Object {
    const p = &obj.portable;
    const already = p.owner == owner;
    if (p.owner == null) {
        _ = object_list.remove(&g.globalObjects, obj);
        p.owner = owner;
        cstr.copy(&p.prevSceneName, &obj.sceneName);
        _ = object_list.add(g, &owner.actor.inventory, obj);
    } else if (!already) {
        _ = object_list.remove(&p.owner.?.actor.inventory, obj);
        p.owner = owner;
        _ = object_list.add(g, &owner.actor.inventory, obj);
    }
    draw_list.remove(&g.drawList, obj);
    obj.unk492 = 1;
    return obj;
}

// @orig 1010:71ac portable_drop
/// Puts the item into `scene`: back from the owner's inventory to the global
/// list (the old scene name becomes the previous one), takes the scene's
/// name and enters the draw list.
pub fn drop(g: *Game, obj: *Object, scene: *Scene) *Object {
    const p = &obj.portable;
    if (p.owner) |own| {
        cstr.copy(&p.prevSceneName, &obj.sceneName);
        _ = object_list.remove(&own.actor.inventory, obj);
        p.owner = null;
        setSceneName(&obj.sceneName, &scene.name);
        _ = object_list.add(g, &g.globalObjects, obj);
    } else {
        cstr.copy(&p.prevSceneName, &obj.sceneName);
        setSceneName(&obj.sceneName, &scene.name);
        draw_list.remove(&g.drawList, obj);
    }
    _ = draw_list.insert(g, scene.backdrop.?, obj);
    obj.unk492 = 1;
    return obj;
}

// @orig 1010:73de portable_move_to_scene
/// Moves the item to the scene called `scene_name` without touching the draw
/// list. A carried item is returned to the global list first. Passing the
/// item's own `prevSceneName` buffer swaps the previous and current names.
pub fn moveToScene(g: *Game, obj: *Object, scene_name: []const u8) *Object {
    const p = &obj.portable;
    if (p.owner) |own| {
        _ = object_list.remove(&own.actor.inventory, obj);
        p.owner = null;
        setSceneName(&obj.sceneName, scene_name);
        _ = object_list.add(g, &g.globalObjects, obj);
    } else if (scene_name.ptr == @as([*]const u8, &p.prevSceneName)) {
        var tmp: [32]u8 = undefined;
        cstr.copy(&tmp, &p.prevSceneName);
        cstr.copy(&p.prevSceneName, &obj.sceneName);
        cstr.copy(&obj.sceneName, &tmp);
    } else {
        cstr.copy(&p.prevSceneName, &obj.sceneName);
        setSceneName(&obj.sceneName, scene_name);
    }
    obj.unk492 = 1;
    return obj;
}

// @orig 1010:75b4 portable_draw_icon
/// Draws the inventory icon, transparent where it equals `g.unk001C`, into
/// the backdrop bitmap at (`x`, `y`), if both the icon and the bitmap exist.
pub fn drawIcon(g: *Game, obj: *Object, bd: *Backdrop, x: i16, y: i16) dib.Error!void {
    const p = &obj.portable;
    const icon = p.icon orelse return;
    if (bd.pixels.len == 0) return;
    const orient: i16 = @truncate(obj.dibFormatOk);
    _ = try dib.copyTransparent(&bd.bmiHeader, bd.pixels, x, y, icon.bits, &icon.header, 0, 0, p.iconW, orient *% p.iconH, g.unk001C);
}

// @orig 1018:3776 portable_set_icon
/// Records the icon's bitmap path and cell size and loads the icon. (The
/// original stores the caller's `char*`; the path is copied here.)
pub fn setIcon(g: *Game, obj: *Object, path: []const u8, width: i16, height: i16) dib.Error!*Object {
    const p = &obj.portable;
    cstr.copy(&p.iconPath, path);
    p.iconW = width;
    p.iconH = height;
    p.icon = try dib.loadDib(g.gpa, g.plat, g.fixes, &g.dibPathBuf, &g.driveCD, cstr.slice(&p.iconPath));
    return obj;
}
