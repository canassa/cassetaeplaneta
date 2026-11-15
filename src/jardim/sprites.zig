//! Port unit `sprites` (module) of JARDIM.EXE. The sprite queue (the depth tree of up to 100 nodes: insert, draw farthest first, flush) and labyrinth_draw_sprite_entry (projection, clipping by the column depths, the enemies' attack and step).
//!
//! The queue is an unbalanced binary tree in the 100-node pool of `world.SpriteQueue`: node 0
//! is the root of a frame's first insert, `nextFree` counts the nodes handed out, `flush` draws
//! the tree farthest first and clears every link as it goes. The original has no capacity check
//! (BUGS.md "Latent (JARDIM)": a 101st node writes over the root word and past the pool): a
//! panic naming it.
//!
//! `drawEntry` is the 16-bit arithmetic of the original: the `_aFldiv`/`_aFlmul` calls are
//! `ldiv`/`lmul` (a zero divisor or INT_MIN / -1 is the original's divide fault: a panic), the
//! 32-bit locals `i32`, the 16-bit fields wrapping. The wall distance of column `c` is read at
//! byte offset `(x + c - 20) & 0xfffc` of `g_columnDepth`; the right-hand clip test reads one
//! column past the sprite's end, which for a sprite reaching the view's right edge (x + width
//! > 500) is offset 480: the first dword of `g_hudTextBuffer` (10d0:1bfe), ASCII of the last
//! HUD text (`Game.hudTextBuffer`, read as the original does), never a wall distance.

const std = @import("std");
const msg = @import("../core/msg.zig");
const Game = @import("core/game.zig").Game;
const object = @import("core/object.zig");
const Object = object.Object;
const world = @import("core/world.zig");
const Backdrop = world.Backdrop;
const SpriteQueue = world.SpriteQueue;
const SpriteQueueEntry = world.SpriteQueueEntry;
const position = @import("behaviour/position.zig");
const animation = @import("behaviour/animation.zig");
const labmap = @import("labmap.zig");
const scaled = @import("scaled.zig");

// ---- _aFldiv / _aFlmul and 16-bit helpers ----

/// `_aFldiv(divisor, dividend)`: the signed 32-bit quotient, truncated. A zero divisor and
/// INT_MIN / -1 are the original's divide faults.
fn ldiv(dividend: i32, divisor: i32) i32 {
    if (divisor == 0 or (dividend == std.math.minInt(i32) and divisor == -1))
        @panic("BUGS.md latent (JARDIM): unchecked cells, table entries and divisors (labyrinth_draw_sprite_entry: a divide fault)");
    return @divTrunc(dividend, divisor);
}

/// `_aFlmul`: the low 32 bits of the product.
fn lmul(a: i32, b: i32) i32 {
    return a *% b;
}

fn lo16(v: i32) i16 {
    return @truncate(v);
}

/// `(u16)v << 16` as a signed dword: the numerator the sprite maths divides.
fn hi16(v: i16) i32 {
    return @bitCast(@as(u32, @as(u16, @bitCast(v))) << 16);
}

// @orig 10c0:47d6 sprite_queue_entry_ctor
/// Both links NULL.
pub fn entryCtor(e: *SpriteQueueEntry) *SpriteQueueEntry {
    e.right = null;
    e.left = null;
    return e;
}

// @orig 10c0:4704 sprite_queue_ctor
/// The 100 nodes' constructors, then the tree empty (`root` NULL) and `nextFree` 1.
pub fn ctor(q: *SpriteQueue) *SpriteQueue {
    for (&q.entries) |*e| _ = entryCtor(e);
    q.root = null;
    q.nextFree = 1;
    return q;
}

// @orig 1028:5ac6 sprite_queue_insert
/// Puts `obj` into the tree keyed by `dist` (the view-axis distance): the node of the same
/// cell (`col`, `row`) if there is one, else a new node, to the right (farther or equal) or
/// to the left of the first node walked. `row` or `col` of -1 take the object's own cell
/// (`worldY >> 5`, `worldX >> 5`). A NULL `obj` returns NULL. The first insert of a frame
/// makes `entries[0]` the root.
pub fn insert(q: *SpriteQueue, row_in: i16, col_in: i16, angle: i16, dist: i16, obj: ?*Object) ?*SpriteQueueEntry {
    const o = obj orelse return null;
    var col = col_in;
    var row = row_in;
    if (col == -1 or row == -1) {
        col = o.worldX >> 5;
        row = o.worldY >> 5;
    }
    var node: *SpriteQueueEntry = undefined;
    if (q.root == null) {
        q.root = &q.entries[0];
        node = &q.entries[0];
        node.object = o;
        node.dist = dist;
        node.angle = angle;
        node.col = col;
        node.row = row;
        return node;
    }
    var cur = q.root.?;
    while (true) {
        if (cur.col == col and cur.row == row) return cur;
        const link: *?*SpriteQueueEntry = if (cur.dist <= dist) &cur.right else &cur.left;
        if (link.*) |next| {
            cur = next;
            continue;
        }
        if (q.nextFree < 0 or q.nextFree >= world.max_sprites)
            @panic("BUGS.md latent (JARDIM): sprite_queue_insert has no capacity check (a 101st sprite in one frame)");
        node = &q.entries[@intCast(q.nextFree)];
        link.* = node;
        q.nextFree +%= 1;
        node.object = o;
        node.dist = dist;
        node.angle = angle;
        node.col = col;
        node.row = row;
        return node;
    }
}

// @orig 1028:5cea sprite_queue_draw_tree
/// In order, farthest first: the right subtree (larger `dist`), the node, the left one; each
/// link is cleared once its subtree is drawn.
pub fn drawTree(g: *Game, q: *SpriteQueue, bd: *Backdrop, node_in: ?*SpriteQueueEntry) void {
    const node = node_in orelse return;
    drawTree(g, q, bd, node.right);
    node.right = null;
    drawEntry(g, node, bd);
    drawTree(g, q, bd, node.left);
    node.left = null;
}

// @orig 1028:5d6d sprite_queue_flush
/// Draws the whole tree and empties the queue.
pub fn flush(g: *Game, q: *SpriteQueue, bd: *Backdrop) void {
    drawTree(g, q, bd, q.root);
    q.root = null;
    q.nextFree = 1;
}

/// `g_columnDepth` at the byte offset the original computes from the 16-bit `v`
/// (`(v & 0xfffc)`): column `v >> 2`. Offset 480 is the HUD text buffer (see the header).
fn depthAt(g: *const Game, v: i16) i32 {
    const idx: usize = (@as(u16, @bitCast(v)) & 0xfffc) >> 2;
    if (idx < world.view_columns) return g.columnDepth[idx];
    if (idx == world.view_columns) return std.mem.readInt(i32, g.hudTextBuffer[0..4], .little);
    @panic("BUGS.md latent (JARDIM): unchecked cells, table entries and divisors (sprites: g_columnDepth read far outside the array)");
}

/// The map cell of a world coordinate: `(v & 0xffe7) >> 3` is a byte offset of
/// the row/column pointer arrays, i.e. `v >> 5` for a coordinate in the map.
fn cell(v: i16, limit: usize) usize {
    const c = v >> 5;
    if (c < 0 or c >= limit) @panic("BUGS.md latent (JARDIM): unchecked cells, table entries and divisors (sprites: an enemy step outside the map)");
    return @intCast(c);
}

// @orig 1028:52a8 labyrinth_draw_sprite_entry
/// Projects, draws and runs the logic of the queued object: snaps a non-shot object to the
/// middle of its cell, finds its depth `d = dx*cos + dy*sin` and screen column, clips the
/// span against the wall distances, draws the visible part (`dibStretchCopyTransparent`);
/// an enemy then steps its sound, hits once per animation cycle (health -1, a life at 0, the
/// loss at 0 lives) and steps one cell back along the view axis if the cell is free.
pub fn drawEntry(g: *Game, entry: *SpriteQueueEntry, bd: *Backdrop) void {
    const obj = entry.object.?;
    if (bd.shot != obj) {
        obj.worldX = entry.col *% 32 +% 0x10;
        obj.worldY = entry.row *% 32 +% 0x10;
    }
    const ang: usize = @intCast(bd.viewAngle);
    const t0 = g.tables.trig[0];
    const t5 = g.tables.trig[5];
    const t6 = g.tables.trig[6];
    const px = lo16(bd.playerX);
    const py = lo16(bd.playerY);

    const a = ldiv(hi16(obj.worldX -% px), t5[ang]);
    const b = ldiv(hi16(obj.worldY -% py), t6[ang]);
    const c = ldiv(hi16(px -% obj.worldX), t6[ang]);
    const e = ldiv(hi16(obj.worldY -% py), t5[ang]);
    const depth: i32 = b +% a;
    const lateral: i32 = e +% c;
    entry.dist = lo16(depth);

    // The high word of -(tan 30 * depth), rounded up.
    const prod = lmul(t0[0xf0], depth);
    const prod_hi: i16 = @truncate(prod >> 16);
    const carry: i16 = @intFromBool(@as(i16, @truncate(prod)) != 0);
    const k: i16 = 0 -% (prod_hi +% carry);
    var scale: i32 = undefined;
    if (k == 0) {
        scale = 0x65ae;
        obj.x = 0x104;
    } else {
        const q: i16 = lo16(ldiv(0x57e4, entry.dist));
        scale = if (q < 0) -%q else q;
        obj.x = lo16(ldiv(lmul(lateral, 0xf0), k)) +% 0x104;
    }
    const w: i32 = ldiv(lmul(position.width(obj), scale), 300);
    obj.x -%= lo16(ldiv(w, 2));
    obj.visible = 0;
    if (@as(i32, obj.x) + w < 0x14 or obj.x > 0x1f4) return;

    var clip_left: i32 = 0;
    var clip_right: i32 = w;
    if (obj.x < 0x14) clip_left = @as(i16, 0x14) -% obj.x;
    if (@as(i32, obj.x) + w > 500) {
        clip_right = @as(i16, 500) -% obj.x;
    }
    const dist: i32 = entry.dist;
    if (depthAt(g, obj.x +% lo16(clip_left) -% 0x14) < dist) {
        while (clip_right > clip_left) {
            if (depthAt(g, obj.x +% lo16(clip_left) -% 0x14) > dist) break;
            clip_left += 1;
        }
    }
    if (depthAt(g, obj.x +% lo16(clip_right) -% 0x14) < dist) {
        while (clip_right > clip_left) {
            if (depthAt(g, obj.x +% lo16(clip_right) -% 0x14) > dist) break;
            clip_right -= 1;
        }
    }
    const h: i32 = ldiv(lmul(position.height(obj), scale), 300);
    obj.y = lo16((scale +% 300) >> 1) -% lo16(h) +% 0x2a;
    if (clip_left < clip_right and h > 0) {
        const src_h: i16 = lo16(obj.dibFormatOk) *% position.height(obj);
        const src_w: i16 = lo16(ldiv(lmul(clip_right -% clip_left, 300), scale));
        const src_y = position.frameSrcY(obj);
        const src_x: i16 = lo16(ldiv(lmul(clip_left, 300), scale)) +% position.frameSrcX(obj);
        const src = position.dib(obj).?;
        _ = scaled.dibStretchCopyTransparent(&bd.bmiHeader, bd.pixels, obj.x +% lo16(clip_left), obj.y, lo16(clip_right -% clip_left), lo16(h), src.bits, &src.header, src_x, src_y, src_w, src_h, g.spriteKey, g.fixes);
        // Not in the original: a motion frame (`g.viewOnly`, `wolf.zig`) only shows the
        // enemies; they act on the game tick's frames.
        if (obj.isEnemy != 0 and !g.viewOnly) {
            const scene = bd.scene.?;
            scene.playEnemyStepSound(g, obj);
            if (position.frameCount(obj) -% obj.curFrame == 1) {
                bd.health -%= 1;
                scene.playEnemyAttackSound(g, obj);
            }
            if (bd.health < 1) {
                bd.health = 100;
                bd.lives -%= 1;
            }
            if (bd.lives == 0) _ = g.post(msg.Msg.make(msg.wm.destroy, 0, 0, 0));
        }
    }
    if (obj.isEnemy != 0 and !g.viewOnly) {
        const nx: i16 = obj.worldX +% lo16(ldiv(-0x200000, t5[ang]));
        const ny: i16 = obj.worldY +% lo16(ldiv(-0x200000, t6[ang]));
        const wall = bd.wallRows[cell(ny, world.map_rows)][cell(nx, world.map_cols + 1)];
        if (wall <= 0) {
            const occ = bd.objectRows[cell(ny, world.map_rows)][cell(nx, world.map_cols)];
            if ((occ == null or obj.id == occ.?.id) and obj.curFrame == 0) {
                labmap.removeObject(bd, obj);
                obj.worldX = nx;
                obj.worldY = ny;
                labmap.placeObject(g, bd, -1, -1, obj);
            }
        }
        _ = animation.nextFrame(g, obj);
    }
}

// ---- tests ----

const testing = std.testing;

test "insert orders by distance, merges a cell and flushes farthest first" {
    var q: SpriteQueue = .{};
    _ = ctor(&q);
    try testing.expect(insert(&q, 1, 1, 0, 5, null) == null);
    var objs: [4]Object = @splat(.{ .kind = .portable });
    const n0 = insert(&q, 3, 3, 0, 50, &objs[0]).?;
    try testing.expect(n0 == &q.entries[0] and q.root == n0);
    const n1 = insert(&q, 4, 4, 0, 20, &objs[1]).?;
    const n2 = insert(&q, 5, 5, 0, 80, &objs[2]).?;
    try testing.expect(n0.left == n1 and n0.right == n2);
    try testing.expect(insert(&q, 4, 4, 9, 10, &objs[3]).? == n1);
    objs[3].worldX = 7 * 32;
    objs[3].worldY = 6 * 32;
    const n3 = insert(&q, -1, -1, 0, 50, &objs[3]).?;
    try testing.expectEqual(@as(i16, 7), n3.col);
    try testing.expectEqual(@as(i16, 6), n3.row);
    try testing.expect(n0.right.? == n2 and n2.left == n3);
    try testing.expectEqual(@as(i16, 4), q.nextFree);
}
