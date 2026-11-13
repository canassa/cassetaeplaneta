//! Port unit `draw_list` (module). the back-to-front draw list of 3D objects (100-node pool).
//!
//! A doubly linked list of `DrawListNode`s drawn from a fixed pool of 100
//! (`world.DrawList`): `head` is the used list (back to front), `freeHead`
//! the free chain (singly used through `next`; `prev` is only set on the
//! first free node by `remove`). Objects are identified by `Object.id`.
//!
//! Faithful behaviours worth knowing:
//! - `insert` with a full pool shows the "Erro Fatal!" box and returns null.
//! - `remove` with every node in use (free chain empty) dereferences the
//!   null `freeHead` in the original (a general protection fault); here that
//!   is a panic on the unwrap.
//! - The functions take `*DrawList`; `insert` needs the platform and the
//!   virtual `isInFrontOf`, so it takes `*Game`.

const std = @import("std");
const Game = @import("core/game.zig").Game;
const object = @import("core/object.zig");
const Object = object.Object;
const world = @import("core/world.zig");
const Backdrop = world.Backdrop;
const DrawList = world.DrawList;
const DrawListNode = world.DrawListNode;
const ini = @import("ini.zig");
const space3d = @import("behaviour/space3d.zig");
const visibility = @import("behaviour/visibility.zig");

/// Latin-1, as in the original's code segment (1018:2fa8).
const msg_pool_full = "Estouro no n\xfamero maximo de objetos vis\xedveis na cena";

/// Clears the prev/next links (not the item).
// @orig 1018:2b1a draw_list_node_ctor
pub fn nodeCtor(node: *DrawListNode) *DrawListNode {
    node.next = null;
    node.prev = null;
    return node;
}

/// Invalidates the screen area of the node's object (SceneObject slot 23).
/// Only the dead recursive walker calls it.
// @orig 1018:2b40 draw_list_node_invalidate
pub fn nodeInvalidate(g: *Game, node: *DrawListNode) void {
    _ = visibility.invalidate(g, node.item.?);
}

/// Constructs the 100 nodes, then resets the list.
// @orig 1018:2be6 draw_list_ctor
pub fn ctor(list: *DrawList) *DrawList {
    for (&list.nodes) |*n| _ = nodeCtor(n);
    reset(list);
    return list;
}

/// Empties the list: chains all 100 nodes into the free list and clears the
/// used list.
// @orig 1018:2c28 draw_list_reset
pub fn reset(list: *DrawList) void {
    const n = &list.nodes;
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
}

/// Inserts `obj` before the first listed object it is not in front of
/// (`obj.isInFrontOf(item, bd)` false). Returns the existing node if an
/// object with the same id is already listed (met before the insertion
/// point), null (after the fatal box) when the pool is exhausted.
// @orig 1018:2cce draw_list_insert
pub fn insert(g: *Game, bd: *Backdrop, obj: ?*Object) ?*DrawListNode {
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
        ini.messageBoxPrintf(g.plat, &g.messageBuf, "Erro Fatal!", msg_pool_full, 0);
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

/// Removes the node whose object has the same id as `obj` and returns it to
/// the free list (as its new head). Nothing happens if there is none.
// @orig 1018:2e88 draw_list_remove
pub fn remove(list: *DrawList, obj: ?*Object) void {
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
    list.freeHead.?.prev = node;
    list.freeHead = node;
}
