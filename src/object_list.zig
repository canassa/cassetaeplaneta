//! Port unit `object_list` (module). the intrusive object list (scene objects, global objects, inventories).
//!
//! The list is intrusive: `Object.next/prev/ownerList` are the links and
//! `ObjectList.head/count/capacity` the header. Membership is just
//! `obj.ownerList == list`.
//!
//! Faithful behaviours worth knowing:
//! - `add` only checks the capacity when the list is not empty, and with a
//!   full list it shows the "Erro Fatal!!" box and returns without adding
//!   (the object is left untouched). The 131-byte message is cut to the
//!   shared 100-byte message buffer, as everywhere in the port.
//! - `attachToScene` writes the word 1 at SceneObject+0x45a and a zero dword
//!   at +0x45e for a non-portable 3D object of the scene; +0x45a is the
//!   `linked` pointer here, so the port sets `linked = null` (the word 1
//!   would be an invalid pointer), `unk45E = 0` and `queued = 0`.

const std = @import("std");
const Game = @import("core/game.zig").Game;
const object = @import("core/object.zig");
const Object = object.Object;
const ObjectList = object.ObjectList;
const world = @import("core/world.zig");
const Scene = world.Scene;
const cstr = @import("core/cstr.zig");
const ini = @import("ini.zig");
const frames = @import("frames.zig");
const draw_list = @import("draw_list.zig");
const misc = @import("behaviour/misc.zig");
const occupancy = @import("behaviour/occupancy.zig");
const render = @import("behaviour/render.zig");
const space3d = @import("behaviour/space3d.zig");
const visibility = @import("behaviour/visibility.zig");

/// Latin-1, as in the original's code segment (1010:d7bc).
const msg_list_full = "N\xe3o foi pos\xedvel inserir um objeto na lista de objetos portateis/est\xe1ticos da aplica\xe7\xe3o\r\nAumente o valor da constante MAX_OBJECT_QTY";

/// Empty list with room for `capacity` objects.
// @orig 1010:12bc object_list_ctor
pub fn ctor(list: *ObjectList, capacity: i16) *ObjectList {
    list.head = null;
    list.count = 0;
    list.capacity = capacity;
    return list;
}

/// True when the list has no head object.
// @orig 1010:af7e object_list_is_empty
pub fn isEmpty(list: *const ObjectList) bool {
    return list.head == null;
}

/// True when `obj` is owned by this very list (not a search).
// @orig 1010:d2b2 object_list_contains
pub fn contains(list: *const ObjectList, obj: *const Object) bool {
    return obj.ownerList == list;
}

/// First object (from the head) whose id is `id`, or null.
// @orig 1010:d2da object_list_find_by_id
pub fn findById(list: *const ObjectList, id: i16) ?*Object {
    var cur = list.head;
    while (cur) |o| : (cur = o.next) {
        if (o.id == id) return o;
    }
    return null;
}

/// True when `count == capacity`.
// @orig 1010:e27a object_list_is_full
pub fn isFull(list: *const ObjectList) bool {
    return list.count == list.capacity;
}

/// Pushes `obj` at the head unless it is already in this list. A non-empty
/// full list shows the fatal box and leaves everything as it was.
// @orig 1010:d322 object_list_add
pub fn add(g: *Game, list: *ObjectList, obj: *Object) *ObjectList {
    if (contains(list, obj)) return list;
    if (list.head) |head| {
        if (list.capacity <= list.count) {
            ini.messageBoxPrintf(g.plat, &g.messageBuf, "Erro Fatal!!", msg_list_full, 0);
            return list;
        }
        obj.next = head;
        obj.prev = null;
        head.prev = obj;
        list.head = obj;
        obj.ownerList = list;
    } else {
        list.head = obj;
        obj.prev = null;
        obj.next = null; // head.next = head.prev: the head is `obj` itself
        obj.ownerList = list;
    }
    list.count +%= 1;
    return list;
}

/// Unlinks `obj` if this list owns it and clears its links.
// @orig 1010:d3e4 object_list_remove
pub fn remove(list: *ObjectList, obj: *Object) *ObjectList {
    if (!contains(list, obj)) return list;
    if (obj.prev) |p| {
        p.next = obj.next;
        if (obj.next) |n| n.prev = obj.prev;
    } else {
        list.head = obj.next;
        if (list.head) |h| h.prev = null;
    }
    obj.next = null;
    obj.prev = null;
    obj.ownerList = null;
    list.count -%= 1;
    return list;
}

/// Walks the list: objects that belong to `scene` are attached to its
/// backdrop (and 3D ones inserted in the draw list); the others, if 3D, are
/// taken off it again.
// @orig 1010:d4f6 object_list_attach_to_scene
pub fn attachToScene(g: *Game, list: *ObjectList, scene: *Scene) void {
    var cur = list.head;
    while (cur) |obj| : (cur = obj.next) {
        const o3d = obj.as(.object3d);
        if (cstr.eqlIgnoreCase(&scene.name, misc.getSceneName(g, obj))) {
            const bd = scene.backdrop.?;
            if (o3d) |o| {
                if (o.is(.portable)) {
                    _ = occupancy.attach(g, obj, bd);
                    _ = space3d.setElevation(g, obj, bd, o.o3d.worldElev);
                    visibility.show(g, obj, bd);
                } else {
                    render.draw(g, obj, bd);
                    _ = occupancy.occupy(g, obj, bd);
                    obj.linked = null; // original: word 1 at +0x45a
                    frames.resetRects(obj);
                    obj.unk45E = 0;
                    obj.queued = 0;
                    continue;
                }
            } else {
                _ = occupancy.attach(g, obj, bd);
                _ = space3d.setElevation(g, obj, bd, 0);
                visibility.show(g, obj, bd);
            }
            _ = draw_list.insert(g, bd, o3d);
        } else if (o3d) |o| {
            if (o.is(.portable)) {
                const p = o.as(.portable).?;
                if (p.portable.owner != null) _ = occupancy.attach(g, obj, scene.backdrop.?);
            }
            draw_list.remove(&g.drawList, o);
            obj.visible = 0;
        }
    }
}

test "list add/remove keep links and count" {
    // @orig 1010:d322 object_list_add oracle=documented
    var a: Object = .{ .kind = .local, .id = 1 };
    var b: Object = .{ .kind = .local, .id = 2 };
    var l: ObjectList = undefined;
    _ = ctor(&l, 2);
    try std.testing.expect(isEmpty(&l) and !isFull(&l));
    // `add` needs a Game only for the fatal box; refs below force analysis.
    std.testing.refAllDecls(@This());
    // Manual link as `add` does for an empty list.
    l.head = &a;
    a.ownerList = &l;
    l.count = 1;
    try std.testing.expect(contains(&l, &a) and !contains(&l, &b));
    _ = remove(&l, &a);
    try std.testing.expect(isEmpty(&l) and l.count == 0 and a.ownerList == null);
}
