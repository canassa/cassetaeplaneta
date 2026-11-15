//! Port unit `prop` (module) of INFERNO.EXE. the Prop class (drinks, rocks,
//! the cross): its SceneObject overrides (restoreBackground, moveToEdgeH,
//! moveTick; slot 5A isPowerUp), PropVtbl moveTick/stepMove/tryStep, the
//! cross tick, inferno_create_rocks_and_cross.
//!
//! GetDC/ReleaseDC and the hwnd parameters are gone (the platform's
//! screen). Every function carries `// @orig <seg:xxxx> <name>` with the
//! INFERNO address.

const std = @import("std");
const Game = @import("core/game.zig").Game;
const object = @import("core/object.zig");
const Object = object.Object;
const world = @import("core/world.zig");
const Backdrop = world.Backdrop;
const object_create = @import("object_create.zig");
const animation = @import("behaviour/animation.zig");
const movement = @import("behaviour/movement.zig");
const occupancy = @import("behaviour/occupancy.zig");
const position = @import("behaviour/position.zig");
const render = @import("behaviour/render.zig");
const visibility = @import("behaviour/visibility.zig");
const dib = @import("dib.zig");

pub const Error = object_create.Error;

fn abs16(v: i16) i16 {
    return if (v < 0) 0 -% v else v;
}

/// The original indexes the global arrays unchecked.
fn idx(i: i16) usize {
    return @as(u16, @bitCast(i));
}

/// SceneObject slot 5A isPowerUp (dispatcher): prop_is_power_up (prop,
/// hazard: `powerUp`) / default 0 (hero, platform).
pub fn isPowerUp(g: *Game, obj: *Object) bool {
    _ = g;
    return switch (obj.kind) {
        .prop, .hazard => propIsPowerUp(obj),
        .hero, .platform => false,
    };
}

// @orig 1080:7296 prop_is_power_up
fn propIsPowerUp(obj: *Object) bool {
    return obj.prop.powerUp != 0;
}

// @orig 1068:35c2 prop_restore_background
/// SceneObject slot 14 restoreBackground override (render.restoreBackground's
/// prop and hazard arm). As the engine's mover_restore_background (the box
/// covering the previous and the current position, marked dirty, then copied
/// from the background with the colour key `g_unk0082`) but 5 px wider, so
/// the 5 px steps leave no trail. `flag` is unused.
pub fn restoreBackground(g: *Game, obj: *Object, bd: *Backdrop, flag: i16) void {
    _ = flag;
    const left = @min(obj.mover.prevX, obj.x);
    const top = @min(obj.mover.prevY, obj.y);
    const w = position.width(obj) +% position.getStepX(g, obj) +% 5;
    const h = position.getStepY(g, obj) +% position.height(obj);
    render.addDirtyRect(g, obj, left -% obj.x, top -% obj.y, w, h);
    const bg = bd.background orelse return;
    if (bd.pixels.len == 0) return;
    _ = dib.copyTransparent(&bd.bmiHeader, bd.pixels, left, top, bg.bits, &bg.header, left, top, w, h, g.unk0082) catch |e|
        std.debug.panic("inferno prop: background restore left its buffers ({s})", .{@errorName(e)});
}

// @orig 1068:2c4f prop_move_to_edge_h
/// SceneObject slot 30 moveToEdgeH override (movement.moveToEdgeH's prop and
/// hazard arm). As the mover's, without the movement timer: dir 2 the right
/// edge, dir 1 half off the left edge, a horizontal Bresenham line; any other
/// dir or no distance stops.
pub fn moveToEdgeH(g: *Game, obj: *Object, bd: *Backdrop, dir: i16) void {
    _ = g;
    const m = &obj.mover;
    m.stepX = abs16(m.stepX);
    m.stepY = abs16(m.stepY);
    m.moving = 1;
    const w = position.width(obj);
    if (dir == 2) {
        m.targetX = 0 -% (w -% bd.bgWidth);
    } else if (dir == 1) {
        m.targetX = 0 -% @divTrunc(w, 2);
    } else {
        m.moving = 0;
        return;
    }
    m.targetY = obj.y;
    obj.nextX = obj.x;
    obj.nextY = obj.y;
    m.lineDx = m.targetX -% obj.nextX;
    m.lineDy = 1;
    if (m.lineDx < 0) {
        m.stepX = 0 -% m.stepX;
        m.lineDx = 0 -% m.lineDx;
    } else if (m.lineDx == 0) {
        m.moving = 0;
        return;
    }
    m.errIncX = m.lineDy << 1;
    m.lineErr = m.errIncX -% m.lineDx;
    m.errIncDiag = m.lineErr -% m.lineDx;
    m.errIncY = 0;
}

// @orig 1068:2e59 prop_move_tick
/// SceneObject slot 34 moveTick override (movement.moveTick's prop arm). Not
/// moving: moveToEdgeH(1). One step, `canStep` (its result ignored: props
/// pass through everything), placeAt, redrawOverlapping, invalidate.
pub fn moveTick(g: *Game, obj: *Object, bd: *Backdrop) void {
    if (obj.mover.moving == 0) movement.moveToEdgeH(g, obj, bd, 1);
    movement.moverStep(obj);
    _ = occupancy.canStep(g, obj, bd);
    movement.placeAt(g, obj, obj.nextX, obj.nextY, bd);
    visibility.redrawOverlapping(g, obj, bd, 1);
    visibility.invalidate(g, obj);
}

// @orig 1068:2b5a prop_hit_player
/// The prop was blocked by the hero: the hero's `linked` becomes this prop
/// and its `play` (hero_play, hero_collide) runs.
pub fn hitPlayer(g: *Game, obj: *Object, bd: *Backdrop) void {
    const player = obj.linked.?.as(.player).?;
    player.linked = obj;
    animation.play(g, player, bd);
}

// @orig 1068:2f93 prop_cross_tick
/// The cross's 120 ms tick (`state`: 2 launched right, 8 falling, 1 sliding
/// left). One step; falling with the hero in the scroll zone (x >= 340,
/// facing right, walking or in a jump) it also loses half a step. Blocked by
/// the hero: `hitPlayer`; by a wall (no object): stops and follows its state
/// (1 parks at x 640, 8 slides left, 2 falls); by another object: ignored.
/// Free: below y 327 it lands (a falling cross slides left). Else it is
/// placed (5 px further left while the world scrolls and it falls) and the
/// world is redrawn over it.
pub fn crossTick(g: *Game, obj: *Object, bd: *Backdrop) void {
    movement.moverStep(obj);
    if (obj.prop.state == 8) {
        const h = g.hero.?;
        if (h.x >= 0x154 and h.hero.facing != 1 and (h.hero.walking != 0 or h.hero.busy != 0)) {
            obj.nextX -%= @divTrunc(obj.mover.stepX, 2);
        }
    }
    if (!occupancy.canStep(g, obj, bd)) {
        if (obj.linked) |l| {
            if (l.is(.player)) {
                hitPlayer(g, obj, bd);
                return;
            }
        } else {
            movement.moverStopMoving(g, obj, bd);
            if (obj.prop.state == 1) {
                movement.placeAt(g, obj, 0x280, obj.y, bd);
                visibility.invalidate(g, obj);
                return;
            }
            if (obj.prop.state == 8) {
                obj.prop.state = 1;
                movement.moverMoveToEdgeH(g, obj, bd, 1);
                return;
            }
            if (obj.prop.state == 2) {
                obj.prop.state = 8;
                movement.moverMoveToEdgeV(g, obj, bd, 8);
                return;
            }
        }
    } else if (obj.y >= 0x147) {
        obj.y = 0x147;
        if (obj.prop.state == 8) {
            obj.prop.state = 1;
            movement.moverMoveToEdgeH(g, obj, bd, 1);
            return;
        }
    }
    if (g.scrolling != 0 and obj.prop.state == 8) obj.nextX -%= 5;
    movement.placeAt(g, obj, obj.nextX, obj.nextY, bd);
    visibility.redrawOverlapping(g, obj, bd, 1);
    for (g.platforms) |p| {
        const item = p.?.platform.item.?;
        if (item.curFrame == 0) visibility.show(g, item, bd);
    }
    for (g.platforms) |p| visibility.show(g, p.?, bd);
    render.draw(g, g.hero.?, bd);
    render.draw(g, obj, bd);
    visibility.invalidate(g, obj);
}

// @orig 1068:381d prop_rock_tick
/// A rock's tick (the hero's move tick calls it for each rock). At the left
/// edge (x <= 0) the next rock in `g_rockIndex` enters if it is not on
/// screen; a rock fully off screen leaves (`g_rockOrder` rotates, it is
/// off, `g_rockIndex` cycles 0-5), the others move.
pub fn rockTick(g: *Game, obj: *Object, bd: *Backdrop) void {
    if (obj.x > 0) {
        moveTick(g, obj, bd);
        return;
    }
    if (g.rocks[idx(g.rockIndex)].?.prop.active == 0) rockSpawn(g, bd);
    if (0 -% position.width(obj) < obj.x) {
        moveTick(g, obj, bd);
    } else {
        var i: usize = 1;
        while (i < 6) : (i += 1) g.rockOrder[i - 1] = g.rockOrder[i];
        g.rockOrder[5] = obj.prop.index;
        obj.prop.active = 0;
        g.rockIndex +%= 1;
        if (g.rockIndex == 6) g.rockIndex = 0;
    }
}

// @orig 1068:392b prop_drink_step
/// A drink's step: moves while it is not fully off the left edge.
pub fn drinkStep(g: *Game, obj: *Object, bd: *Backdrop) void {
    if (0 -% position.width(obj) < obj.x) moveTick(g, obj, bd);
}

// @orig 1068:398d prop_drink_respawn
/// The drink comes back at x 638 at the platform slot's height (1: 190,
/// 2: 249, 3: 147, else 223); its strip is the slot, frame 0; placed, then
/// set to move left.
pub fn drinkRespawn(g: *Game, obj: *Object, slot: i16, bd: *Backdrop) void {
    const x: i16 = 0x27e;
    var y: i16 = undefined;
    if (slot == 1) {
        y = 0xbe;
        obj.curStrip = 1;
    } else if (slot == 2) {
        y = 0xf9;
        obj.curStrip = 2;
    } else if (slot == 3) {
        y = 0x93;
        obj.curStrip = 3;
    } else {
        y = 0xdf;
        obj.curStrip = 0;
    }
    obj.x = x;
    obj.y = y;
    obj.curFrame = 0;
    movement.placeAt(g, obj, x, y, bd);
    visibility.invalidate(g, obj);
    moveToEdgeH(g, obj, bd, 1);
}

// @orig 1068:3ac3 prop_rock_spawn
/// The rock `g_rockIndex` enters at x 638 (y 24 for 0 and 3, 39 for 1 and 4,
/// 45 for 2 and 5), set to move left, on screen. (`this` is unused: the
/// original reads the rock through `g_rocks`.)
pub fn rockSpawn(g: *Game, bd: *Backdrop) void {
    const y: i16 = if (g.rockIndex == 0 or g.rockIndex == 3) 0x18 else if (g.rockIndex == 1 or g.rockIndex == 4) 0x27 else 0x2d;
    const r = g.rocks[idx(g.rockIndex)].?;
    r.x = 0x27e;
    r.y = y;
    movement.placeAt(g, r, 0x27e, y, bd);
    visibility.invalidate(g, r);
    moveToEdgeH(g, r, bd, 1);
    r.prop.active = 1;
}

/// `operator_new(0x4d2)` + `prop_ctor` (timer 3 at 120 ms, steps 5 x 5,
/// hit box at 0, 0). A failed allocation is a null object in the original,
/// which then crashes.
fn newProp(
    g: *Game,
    x: i16,
    y: i16,
    count: i16,
    paths: []const []const u8,
    counts: []const i16,
    widths: []const i16,
    heights: []const i16,
    hit_w: i16,
    hit_h: i16,
) Error!*Object {
    const p = g.local().create(Object) catch return error.OutOfMemory;
    p.* = .{ .kind = .prop };
    try object_create.propCtor(g, p, x, y, count, paths, counts, widths, heights, 0, 0, hit_w, hit_h, 3, 0x78, 5, 5, 1, 0, true);
    return p;
}

fn newRock(g: *Game, x: i16, y: i16, hit_w: i16, hit_h: i16) Error!*Object {
    return newProp(g, x, y, 3, &g.rockStripFiles, &g.rockStripFrames, &g.rockStripWidths, &g.rockStripHeights, hit_w, hit_h);
}

// @orig 1068:272a inferno_create_rocks_and_cross
/// Six rocks (strips rocha02, rocha01, rocha03 twice; hit boxes 171 x 35,
/// 94 x 99, 73 x 86 for the first three, then the copied 171 x 35, 94 x 99,
/// 94 x 99: BUGS.md "Harmless (INFERNO)") and the cross (cruz, hit box
/// 24 x 40, y 311, x 640, `powerUp` 1). Rocks 0-2 stand at x 63, 205, 434
/// and are on screen; 3-5 wait at x 640. All attach; rock i has `index` i
/// and `g_rockOrder[i]` i.
pub fn createRocksAndCross(g: *Game, bd: *Backdrop) Error!void {
    g.rocks[0] = try newRock(g, 0x3f, 0x18, 0xab, 0x23);
    g.rocks[1] = try newRock(g, 0xcd, 0x27, 0x5e, 0x63);
    g.rocks[2] = try newRock(g, 0x1b2, 0x2d, 0x49, 0x56);
    g.rocks[3] = try newRock(g, 0x280, 0x18, 0xab, 0x23);
    g.rocks[4] = try newRock(g, 0x280, 0x27, 0x5e, 0x63);
    g.rocks[5] = try newRock(g, 0x280, 0x2d, 0x5e, 0x63);
    g.cross = try newProp(g, 0x280, 0x137, 1, &g.crossStripFiles, &g.crossStripFrames, &g.crossStripWidths, &g.crossStripHeights, 0x18, 0x28);
    g.rocks[0].?.curStrip = 0;
    g.rocks[1].?.curStrip = 1;
    g.rocks[2].?.curStrip = 2;
    g.rocks[3].?.curStrip = 0;
    g.rocks[4].?.curStrip = 1;
    g.rocks[5].?.curStrip = 2;
    g.rocks[0].?.prop.active = 1;
    g.rocks[1].?.prop.active = 1;
    g.rocks[2].?.prop.active = 1;
    g.cross.?.prop.powerUp = 1;
    g.cross.?.curStrip = 0;
    var i: i16 = 0;
    while (i < 6) : (i += 1) {
        const r = g.rocks[idx(i)].?;
        _ = occupancy.attach(g, r, bd);
        r.prop.index = i;
        g.rockOrder[idx(i)] = i;
    }
    _ = occupancy.attach(g, g.cross.?, bd);
}
