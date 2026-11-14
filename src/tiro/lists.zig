//! Port unit `lists` (module) of TIRO.EXE. ObjectList, DrawList and
//! UpdateList (out of line in TIRO; ENCAIXE inlines it).
//!
//! See docs/tiro/DESIGN.md "How to port a TIRO unit". Each function
//! carries `// @orig <seg:xxxx> <name>` with the TIRO address.
//! `message_box_printf` (the shared g_messageText) lives in `position`
//! (`position.messageBoxPrintf`).
//!
//! Naming: the lists share verbs, so the DrawList's carry a `draw` prefix
//! (`drawCtor`, `drawInsert`, `drawRemove`) and the UpdateList's an `update`
//! prefix; the ObjectList's are bare (`ctor`, `contains`, `add`, `remove`,
//! `deleteAll`, `isEmpty`, `isFull`, `attachToScene`).
//!
//! Faithful behaviours worth knowing:
//! - `add` ignores an object silently when the list is non-empty and full
//!   (NOITE shows a fatal box; TIRO's code has none). An empty list takes
//!   the object whatever its capacity.
//! - `drawRemove` with the whole 100-node pool in use dereferences the null
//!   `freeHead` in the original (as NOITE's, BUGS.md L5); here a panic.
//! - `updateAdd` on a full list shows its box, adds nothing and still
//!   returns `count - 1` (the last slot's index). Its text (111 bytes)
//!   overruns the 100-byte g_messageText in the original (BUGS.md L6);
//!   `messageBoxPrintf` truncates it.
//! - Draw-list items are identified by `Object.id` (the original reads the
//!   word at SceneObject+0xe through the Object3D's virtual-base pointer).

const std = @import("std");
const Game = @import("core/game.zig").Game;
const object = @import("core/object.zig");
const Object = object.Object;
const ObjectList = object.ObjectList;
const world = @import("core/world.zig");
const Scene = world.Scene;
const DrawList = world.DrawList;
const DrawListNode = world.DrawListNode;
const UpdateList = world.UpdateList;
const cstr = @import("../core/cstr.zig");
const object_create = @import("object_create.zig");
const position = @import("behaviour/position.zig");
const occupancy = @import("behaviour/occupancy.zig");
const space3d = @import("behaviour/space3d.zig");
const visibility = @import("behaviour/visibility.zig");
const render = @import("behaviour/render.zig");

/// Latin-1, as in TIRO's data segment (1090:03a1, 1090:03d6).
const msg_pool_full = "Estouro no n\xfamero maximo de objetos vis\xedveis na cena";
const caption_pool_full = "Erro Fatal!";
/// 1090:0612 and 1090:0622.
const caption_update_full = "Erro Fatal!!";
const msg_update_full = "N\xe3o foi pos\xedvel inserir um objeto na lista de atualiza\xe7\xf5es de tela\r\nAumente o valor da constante MAX_OBJECT_QTY";

/// head = null, count = 0, the capacity given (30 for a scene's list).
// @orig 1088:50c0 object_list_ctor
pub fn ctor(list: *ObjectList, capacity: i16) *ObjectList {
    list.head = null;
    list.count = 0;
    list.capacity = capacity;
    return list;
}

/// True when `obj` is owned by this very list (not a search).
// @orig 1028:1927 object_list_contains
pub fn contains(list: *const ObjectList, obj: *const Object) bool {
    return obj.ownerList == list;
}

/// Pushes `obj` at the head unless it is already in this list. A non-empty
/// full list drops it without a word.
// @orig 1028:1953 object_list_add
pub fn add(list: *ObjectList, obj: *Object) *ObjectList {
    if (contains(list, obj)) return list;
    if (list.head) |head| {
        if (list.capacity <= list.count) return list;
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
    list.count +%= 1;
    return list;
}

/// Unlinks `obj` if this list owns it and clears its links.
// @orig 1028:19d7 object_list_remove
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
    list.count -%= 1;
    return list;
}

/// True when the list has no head.
// @orig 1088:3acc object_list_is_empty
pub fn isEmpty(list: *const ObjectList) bool {
    return list.head == null;
}

/// True when `count == capacity`.
// @orig 1088:4166 object_list_is_full
pub fn isFull(list: *const ObjectList) bool {
    return list.count == list.capacity;
}

/// Deletes every object of the list (`scene_object_scalar_dtor(obj, 1)`;
/// TIRO calls it out of line, ENCAIXE inlines it) when it is not empty and
/// zeroes the count; the next link is read one object ahead. Only
/// `game_dtor` calls it.
// @orig 1028:1a69 object_list_delete_all
pub fn deleteAll(g: *Game, list: *ObjectList) void {
    if (isEmpty(list)) return;
    var next = list.head.?.next;
    while (list.head) |cur| {
        _ = object_create.sceneObjectScalarDtor(g, cur, 1);
        list.head = next;
        if (next) |n| next = n.next;
    }
    list.count = 0;
}

/// Walks the application-wide list: objects of `scene` are attached to its
/// backdrop, raised and shown, and inserted in the game's draw list; the
/// others leave the draw list and are marked not visible.
// @orig 1028:1b5e object_list_attach_to_scene
pub fn attachToScene(g: *Game, list: *ObjectList, scene: *Scene) void {
    var cur = list.head;
    while (cur) |obj| : (cur = obj.next) {
        const o3d = obj.as(.object3d);
        if (cstr.eqlIgnoreCase(&scene.name, position.unk4E(g, obj))) {
            const bd = scene.backdrop.?;
            attachOne(g, obj, bd, if (o3d) |o| o.o3d.worldElev else 0);
            _ = drawInsert(g, bd, o3d);
        } else {
            drawRemove(&g.drawList, o3d);
            obj.visible = 0;
        }
    }
}

fn attachOne(g: *Game, obj: *Object, bd: *world.Backdrop, elev: i16) void {
    _ = occupancy.attach(g, obj, bd);
    _ = space3d.setElevation(g, obj, bd, elev);
    visibility.show(g, obj, bd);
}

/// The node constructor: next = prev = null.
// @orig 1088:6208 draw_list_node_ctor
pub fn drawNodeCtor(node: *DrawListNode) *DrawListNode {
    node.next = null;
    node.prev = null;
    return node;
}

/// Constructs the 100 nodes, then chains them into the free list (NOITE's
/// reset inlined); the last node's prev is `nodes[98]`.
// @orig 1070:0340 draw_list_ctor
pub fn drawCtor(list: *DrawList) *DrawList {
    const n = &list.nodes;
    for (n) |*node| _ = drawNodeCtor(node);
    list.head = null;
    list.freeHead = &n[0];
    n[0].prev = null;
    n[0].next = &n[1];
    n[0].item = null;
    var i: usize = 1;
    while (i < n.len - 1) : (i += 1) {
        n[i].prev = &n[i - 1];
        n[i].next = &n[i + 1];
        n[i].item = null;
    }
    n[n.len - 1].prev = &n[n.len - 2];
    n[n.len - 1].next = null;
    n[n.len - 1].item = null;
    return list;
}

/// Inserts `obj` before the first listed object it is not in front of
/// (`isInFrontOf` false). Returns the existing node when an object with the
/// same id is met first, null (after the box) when the pool is exhausted.
// @orig 1070:0408 draw_list_insert
pub fn drawInsert(g: *Game, bd: *world.Backdrop, obj: ?*Object) ?*DrawListNode {
    const o = obj orelse return null;
    const list = &g.drawList;

    if (list.head == null) {
        const node = list.freeHead.?;
        list.head = node;
        list.freeHead = node.next;
        node.item = o;
        node.prev = null;
        node.next = null;
        return node;
    }

    var before: ?*DrawListNode = null;
    var after: ?*DrawListNode = null;
    var cur = list.head;
    while (cur) |node| {
        if (node.item.?.id == o.id) return node;
        if (!space3d.isInFrontOf(g, o, node.item.?, bd)) {
            after = node;
            break;
        }
        before = node;
        cur = node.next;
    }

    const node = list.freeHead orelse {
        position.messageBoxPrintf(g, caption_pool_full, msg_pool_full, 0);
        return null;
    };
    if (before) |b| b.next = node else list.head = node;
    list.freeHead = node.next;
    if (after) |a| a.prev = node;
    node.prev = before;
    node.next = after;
    node.item = o;
    return node;
}

/// Unlinks the node whose object has the same id as `obj` and returns it to
/// the free list as its new head. Nothing happens when there is none (or
/// the list is empty).
// @orig 1070:0545 draw_list_remove
pub fn drawRemove(list: *DrawList, obj: ?*Object) void {
    const o = obj orelse return;
    if (list.head == null) return;
    var before: ?*DrawListNode = null;
    var cur = list.head;
    while (cur) |node| : (cur = node.next) {
        if (node.item.?.id == o.id) break;
        before = node;
    }
    const node = cur orelse return;

    if (before) |b| b.next = node.next else list.head = node.next;
    if (node.next) |nx| nx.prev = before;
    node.item = null;
    node.next = list.freeHead;
    node.prev = null;
    const free_head = list.freeHead orelse @panic("draw_list_remove: free list empty (original GPF, BUGS.md L5)");
    free_head.prev = node;
    list.freeHead = node;
}

/// count = 0.
// @orig 1088:5256 update_list_ctor
pub fn updateCtor(list: *UpdateList) *UpdateList {
    list.count = 0;
    return list;
}

/// Queues `obj` for the next flush unless it already is. A full list (30)
/// shows the "update list full" box instead. Returns the object's slot
/// (`queueIndex` when already queued, else `count - 1`).
// @orig 1088:2440 update_list_add
pub fn updateAdd(g: *Game, list: *UpdateList, obj: *Object) i16 {
    if (obj.queued != 0) return obj.queueIndex;
    if (list.count == world.max_update) {
        position.messageBoxPrintf(g, caption_update_full, msg_update_full, 0);
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
// @orig 1088:4192 update_list_discard
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
// @orig 1088:41dc update_list_is_empty
pub fn updateIsEmpty(list: *const UpdateList) bool {
    return list.count == 0;
}

/// Realizes the backdrop's palette on the window DC (SelectPalette +
/// RealizePalette), then WinGBitBlt each queued object's dirty rectangle
/// from the backdrop's surface (view-relative), resets its flag and
/// rectangles and empties the list. The hdc parameter is the platform's
/// window DC. Unlike ENCAIXE's inlined one there is no `count == 0` test:
/// the palette is realized on every call.
// @orig 1088:41fe update_list_flush
pub fn updateFlush(g: *Game, list: *UpdateList, bd: *world.Backdrop) void {
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

test "object list add/remove keep links and count" {
    // @orig 1028:1953 object_list_add oracle=documented
    var a: Object = .{ .kind = .target, .id = 1 };
    var b: Object = .{ .kind = .target, .id = 2 };
    var c: Object = .{ .kind = .target, .id = 3 };
    var l: ObjectList = undefined;
    _ = ctor(&l, 2);
    _ = add(&l, &a);
    _ = add(&l, &a);
    _ = add(&l, &b);
    try std.testing.expect(l.count == 2 and l.head == &b and b.next == &a and a.prev == &b);
    // Full: the third is dropped silently.
    _ = add(&l, &c);
    try std.testing.expect(l.count == 2 and c.ownerList == null and !contains(&l, &c) and isFull(&l));
    _ = remove(&l, &b);
    try std.testing.expect(l.head == &a and a.prev == null and b.ownerList == null and l.count == 1);
    _ = remove(&l, &a);
    try std.testing.expect(isEmpty(&l) and l.count == 0);
}

test "draw list ctor chains the pool; remove returns the node" {
    // @orig 1070:0340 draw_list_ctor oracle=documented
    var list: DrawList = .{};
    _ = drawCtor(&list);
    try std.testing.expect(list.head == null and list.freeHead == &list.nodes[0]);
    try std.testing.expect(list.nodes[5].prev == &list.nodes[4] and list.nodes[5].next == &list.nodes[6]);
    try std.testing.expect(list.nodes[99].next == null);
    var o: Object = .{ .kind = .control_panel, .id = 7 };
    const node = &list.nodes[0];
    list.head = node;
    list.freeHead = node.next;
    node.item = &o;
    node.next = null;
    drawRemove(&list, &o);
    try std.testing.expect(list.head == null and list.freeHead == node and node.item == null);
}
