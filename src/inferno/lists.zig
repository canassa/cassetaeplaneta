//! Port unit `lists` (module) of INFERNO.EXE. ObjectList (the far `head`
//! only in INFERNO) and UpdateList (out of line, /Od).
//!
//! See docs/inferno/DESIGN.md "How to port an INFERNO unit". Each function
//! carries `// @orig <seg:xxxx> <name>` with the INFERNO address.
//!
//! Differences from TIRO's `lists`: the ObjectList has no count or
//! capacity, so `add` never drops an object and `remove` keeps no count
//! (`ctor` takes the head, not a capacity); there is no draw list, so
//! `attachToScene` neither inserts into nor removes from one and its
//! Object3D branch (never built, `asObject3D` is always null) panics.

const std = @import("std");
const Game = @import("core/game.zig").Game;
const object = @import("core/object.zig");
const Object = object.Object;
const ObjectList = object.ObjectList;
const world = @import("core/world.zig");
const Backdrop = world.Backdrop;
const Scene = world.Scene;
const UpdateList = world.UpdateList;
const cstr = @import("../core/cstr.zig");
const object_create = @import("object_create.zig");
const position = @import("behaviour/position.zig");
const occupancy = @import("behaviour/occupancy.zig");
const visibility = @import("behaviour/visibility.zig");
const render = @import("behaviour/render.zig");

/// Latin-1, as in INFERNO's code segment (1080:4710, 1080:4720).
const caption_update_full = "Erro Fatal!!";
const msg_update_full = "N\xe3o foi pos\xedvel inserir um objeto na lista de atualiza\xe7\xf5es de tela\r\nAumente o valor da constante MAX_OBJECT_QTY";

/// head = the given head.
// @orig 1080:736e object_list_ctor
pub fn ctor(list: *ObjectList, head: ?*Object) *ObjectList {
    list.head = head;
    return list;
}

/// True when `obj` is owned by this very list (not a search).
// @orig 1028:23fc object_list_contains
pub fn contains(list: *const ObjectList, obj: *const Object) bool {
    return obj.ownerList == list;
}

/// Pushes `obj` at the head unless it is already in this list.
// @orig 1028:2434 object_list_add
pub fn add(list: *ObjectList, obj: *Object) *ObjectList {
    if (contains(list, obj)) return list;
    if (list.head) |head| {
        obj.next = head;
        obj.prev = null;
        head.prev = obj;
        list.head = obj;
    } else {
        list.head = obj;
        obj.prev = null;
        obj.next = null;
    }
    obj.ownerList = list;
    return list;
}

/// Unlinks `obj` if this list owns it and clears its links.
// @orig 1028:250c object_list_remove
pub fn remove(list: *ObjectList, obj: *Object) *ObjectList {
    if (!contains(list, obj)) return list;
    if (obj.prev) |p| {
        p.next = obj.next;
        if (obj.next) |nx| nx.prev = obj.prev;
    } else {
        list.head = obj.next;
        if (list.head) |h| h.prev = null;
    }
    obj.next = null;
    obj.prev = null;
    obj.ownerList = null;
    return list;
}

/// True when the list has no head.
// @orig 1080:5710 object_list_is_empty
pub fn isEmpty(list: *const ObjectList) bool {
    return list.head == null;
}

/// Deletes every object of the list (`scene_object_scalar_dtor(obj, 1)`)
/// when it is not empty; the next link is read one object ahead. There is
/// no count to zero.
// @orig 1028:25f1 object_list_delete_all
pub fn deleteAll(g: *Game, list: *ObjectList) void {
    if (isEmpty(list)) return;
    var next = list.head.?.next;
    while (list.head) |cur| {
        _ = object_create.sceneObjectScalarDtor(g, cur, 1);
        list.head = next;
        if (next) |n| next = n.next;
    }
}

/// Walks the list: objects of `scene` (by `getSceneName`, case-insensitive)
/// are attached to its backdrop, raised to 0 and shown; the others are
/// marked not visible.
// @orig 1028:274f object_list_attach_to_scene
pub fn attachToScene(g: *Game, list: *ObjectList, scene: *Scene) void {
    var cur = list.head;
    while (cur) |obj| : (cur = obj.next) {
        if (cstr.eqlIgnoreCase(&scene.name, position.getSceneName(g, obj))) {
            const bd = scene.backdrop.?;
            if (obj.as(.object3d) != null) @panic("object_list_attach_to_scene: Object3D branch (never built in INFERNO)");
            _ = occupancy.attach(g, obj, bd);
            _ = position.setElevation(g, obj, bd, 0);
            visibility.show(g, obj, bd);
        } else {
            obj.visible = 0;
        }
    }
}

/// count = 0.
// @orig 1080:74a8 update_list_ctor
pub fn updateCtor(list: *UpdateList) *UpdateList {
    list.count = 0;
    return list;
}

/// Queues `obj` for the next flush unless it already is. A full list (30)
/// shows the "update list full" box instead. Returns the object's slot
/// (`queueIndex` when already queued, else `count - 1`).
// @orig 1080:329e update_list_add
pub fn updateAdd(g: *Game, list: *UpdateList, obj: *Object) i16 {
    if (obj.queued != 0) return obj.queueIndex;
    if (list.count == world.max_update) {
        position.messageBoxPrintf(g, caption_update_full, msg_update_full, "");
    } else {
        list.items[@intCast(list.count)] = obj;
        obj.queued = 1;
        obj.queueIndex = list.count;
        list.count +%= 1;
    }
    return list.count -% 1;
}

/// Empties the list without drawing: each object's queued flag and
/// rectangles are reset.
// @orig 1080:669a update_list_discard
pub fn updateDiscard(list: *UpdateList) void {
    var i: i16 = 0;
    while (i < list.count) : (i += 1) {
        const obj = list.items[@intCast(i)].?;
        obj.queued = 0;
        render.resetRects(obj);
    }
    list.count = 0;
}

/// True when nothing is queued.
// @orig 1080:66f8 update_list_is_empty
pub fn updateIsEmpty(list: *const UpdateList) bool {
    return list.count == 0;
}

/// Realizes the backdrop's palette on the window DC, then WinGBitBlt each
/// queued object's dirty rectangle from the backdrop's surface
/// (view-relative), resets its flag and rectangles and empties the list.
// @orig 1080:671a update_list_flush
pub fn updateFlush(g: *Game, list: *UpdateList, bd: *Backdrop) void {
    _ = g.plat.realizePalette(&bd.bmiColors);
    var i: i16 = 0;
    while (i < list.count) : (i += 1) {
        const obj = list.items[@intCast(i)].?;
        const d = obj.dirty;
        g.plat.wingBitBlt(obj.x -% bd.originX +% d.left, obj.y -% bd.originY +% d.top, d.right, d.bottom, bd.surface(), obj.x +% d.left, obj.y +% d.top);
        obj.queued = 0;
        render.resetRects(obj);
    }
    list.count = 0;
}

test "object list add/remove keep links" {
    // @orig 1028:2434 object_list_add oracle=documented
    var a: Object = .{ .kind = .hero, .id = 1 };
    var b: Object = .{ .kind = .hero, .id = 2 };
    var l: ObjectList = .{};
    _ = ctor(&l, null);
    _ = add(&l, &a);
    _ = add(&l, &a);
    _ = add(&l, &b);
    try std.testing.expect(l.head == &b and b.next == &a and a.prev == &b and contains(&l, &a));
    _ = remove(&l, &b);
    try std.testing.expect(l.head == &a and a.prev == null and b.ownerList == null);
    _ = remove(&l, &a);
    try std.testing.expect(isEmpty(&l));
}
