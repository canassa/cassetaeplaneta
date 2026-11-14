//! Port unit `lists` (module) of ENCAIXE.EXE. ObjectList, DrawList and message_box_printf (the shared box buffer g_messageText).
//!
//! See docs/encaixe/DESIGN.md "How to port an ENCAIXE unit". Each function
//! carries `// @orig <1008:xxxx> <name>` with the ENCAIXE address.
//!
//! Naming: the two lists share verbs, so the DrawList's carry a `draw`
//! prefix (`drawCtor`, `drawInsert`, `drawRemove`); the ObjectList's are
//! bare (`contains`, `add`, `remove`, `deleteAll`, `attachToScene`).
//!
//! Faithful behaviours worth knowing:
//! - `add` ignores an object silently when the list is non-empty and full
//!   (NOITE shows a fatal box; ENCAIXE's code has none). An empty list
//!   takes the object whatever its capacity.
//! - `drawRemove` with the whole 100-node pool in use dereferences the null
//!   `freeHead` in the original (as NOITE's, BUGS.md L5); here a panic.
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
const cstr = @import("../core/cstr.zig");
const ini = @import("../ini.zig");
const position = @import("behaviour/position.zig");
const occupancy = @import("behaviour/occupancy.zig");
const space3d = @import("behaviour/space3d.zig");
const visibility = @import("behaviour/visibility.zig");

/// Latin-1, as in the original's code segment (1018:115c).
const msg_pool_full = "Estouro no n\xfamero maximo de objetos vis\xedveis na cena";

/// `sprintf(g_messageText, fmt, arg)` then a MB_ICONEXCLAMATION box. The
/// original is varargs; every caller passes one word (0) or a string.
// @orig 1008:8c88 message_box_printf
pub fn messageBoxPrintf(g: *Game, caption: []const u8, fmt: []const u8, arg: anytype) void {
    ini.messageBoxPrintf(g.plat, &g.messageText, caption, fmt, arg);
}

/// True when `obj` is owned by this very list (not a search).
// @orig 1008:7f56 object_list_contains
pub fn contains(list: *const ObjectList, obj: *const Object) bool {
    return obj.ownerList == list;
}

/// Pushes `obj` at the head unless it is already in this list. A non-empty
/// full list drops it without a word.
// @orig 1008:7f72 object_list_add
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
// @orig 1008:7fbc object_list_remove
pub fn remove(list: *ObjectList, obj: *Object) *ObjectList {
    if (!contains(list, obj)) return list;
    if (obj.prev) |p| {
        const n = obj.next;
        p.next = n;
        if (n) |nx| nx.prev = obj.prev;
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

/// Deletes every object of the list (the scalar destructor is inlined: it
/// only resets the vtable, then `operator delete`) and zeroes the count;
/// the next link is read before each deletion. Only `game_dtor` calls it.
// @orig 1008:8014 object_list_delete_all
pub fn deleteAll(g: *Game, list: *ObjectList) void {
    var cur = list.head orelse return;
    var next = cur.next;
    while (true) {
        list.head = cur;
        g.gpa.destroy(cur);
        cur = next orelse break;
        next = cur.next;
    }
    list.head = null;
    list.count = 0;
}

/// Walks the application-wide list: objects of `scene` are attached to its
/// backdrop, raised and shown, and inserted in the game's draw list; the
/// others leave the draw list and are marked not visible.
// @orig 1008:805c object_list_attach_to_scene
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

/// Chains the 100 nodes into the free list (NOITE's ctor and reset inlined).
// @orig 1008:f87a draw_list_ctor
pub fn drawCtor(list: *DrawList) *DrawList {
    const n = &list.nodes;
    for (n) |*node| {
        node.prev = null;
        node.next = null;
    }
    list.freeHead = &n[0];
    n[0].next = &n[1];
    list.head = null;
    n[0].item = null;
    n[0].prev = null;
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
// @orig 1008:f8e0 draw_list_insert
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
        messageBoxPrintf(g, "Erro Fatal!", msg_pool_full, 0);
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
/// the free list as its new head. Nothing happens when there is none.
// @orig 1008:f9d4 draw_list_remove
pub fn drawRemove(list: *DrawList, obj: ?*Object) void {
    const o = obj orelse return;
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

test "object list add/remove keep links and count" {
    // @orig 1008:7f72 object_list_add oracle=documented
    var a: Object = .{ .kind = .piece, .id = 1 };
    var b: Object = .{ .kind = .piece, .id = 2 };
    var c: Object = .{ .kind = .piece, .id = 3 };
    var l: ObjectList = .{ .capacity = 2 };
    _ = add(&l, &a);
    _ = add(&l, &a);
    _ = add(&l, &b);
    try std.testing.expect(l.count == 2 and l.head == &b and b.next == &a and a.prev == &b);
    // Full: the third is dropped silently (no fatal box in ENCAIXE).
    _ = add(&l, &c);
    try std.testing.expect(l.count == 2 and c.ownerList == null and !contains(&l, &c));
    _ = remove(&l, &b);
    try std.testing.expect(l.head == &a and a.prev == null and b.ownerList == null and l.count == 1);
    _ = remove(&l, &a);
    try std.testing.expect(l.head == null and l.count == 0);
}

test "draw list ctor chains the pool; remove returns the node" {
    // @orig 1008:f87a draw_list_ctor oracle=documented
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
