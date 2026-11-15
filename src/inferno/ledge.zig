//! Port unit `ledge` (module) of INFERNO.EXE. the Platform class (4 platforms
//! carrying the drinks): its SceneObject overrides (play, moveToEdgeH,
//! moveTick), PlatformVtbl moveTick (platform_tick, the respawn), drop_cross,
//! inferno_create_platforms.
//!
//! The Platform is an Actor2D whose SceneObject sits at Platform + 0x52 in
//! the original (`this` of the three overrides); here that is just `obj`.
//! GetDC/ReleaseDC and hwnd are gone (the DC is the platform screen).

const Game = @import("core/game.zig").Game;
const object = @import("core/object.zig");
const Object = object.Object;
const world = @import("core/world.zig");
const Backdrop = world.Backdrop;
const object_create = @import("object_create.zig");
const prop = @import("prop.zig");
const score = @import("score.zig");
const animation = @import("behaviour/animation.zig");
const movement = @import("behaviour/movement.zig");
const occupancy = @import("behaviour/occupancy.zig");
const position = @import("behaviour/position.zig");
const render = @import("behaviour/render.zig");
const visibility = @import("behaviour/visibility.zig");

fn abs16(v: i16) i16 {
    return if (v < 0) 0 -% v else v;
}

/// One platform: `operator_new(0x4d2)` + `platform_ctor` (hit box 84 x 12,
/// timer id 12 at 120 ms, steps 5, one strip `Plataf`).
fn newPlatform(g: *Game, x: i16, y: i16) object_create.Error!*Object {
    const o = g.local().create(Object) catch return error.OutOfMemory;
    o.* = .{ .kind = .platform };
    try object_create.platformCtor(g, o, x, y, 1, &g.platformStripFiles, &g.platformStripFrames, &g.platformStripWidths, &g.platformStripHeights, 0, 0, 84, 12, 12, 120, 5, 5, 1, 0, true);
    return o;
}

/// One drink: `operator_new(0x4d2)` + `prop_ctor` (hit box w x h, the same
/// timer, four strips: cerva, chopp, copo, 3spres).
fn newDrink(g: *Game, x: i16, y: i16, hit_w: i16, hit_h: i16) object_create.Error!*Object {
    const o = g.local().create(Object) catch return error.OutOfMemory;
    o.* = .{ .kind = .prop };
    try object_create.propCtor(g, o, x, y, 4, &g.drinkStripFiles, &g.drinkStripFrames, &g.drinkStripWidths, &g.drinkStripHeights, 0, 0, hit_w, hit_h, 12, 120, 5, 5, 1, 0, true);
    return o;
}

// @orig 1068:1a1e inferno_create_platforms
/// Builds the 4 Platforms and the 4 drinks they carry, then attaches them
/// to the backdrop (hwnd dropped; the original calls `scene_object_attach`
/// directly, `occupancy.attach` adds a `linked = null` that is already null).
pub fn createPlatforms(g: *Game, bd: *Backdrop) object_create.Error!void {
    const px = [4]i16{ 38, 201, 380, 524 };
    const py = [4]i16{ 247, 204, 264, 204 };
    const dx = [4]i16{ 49, 218, 385, 530 };
    const dy = [4]i16{ 223, 190, 249, 147 };
    const dw = [4]i16{ 11, 17, 16, 16 };
    const dh = [4]i16{ 24, 14, 15, 22 };
    for (0..4) |i| {
        g.platforms[i] = try newPlatform(g, px[i], py[i]);
        g.platforms[i].?.platform.item = try newDrink(g, dx[i], dy[i], dw[i], dh[i]);
    }
    for (0..4) |i| {
        const p = g.platforms[i].?;
        const item = p.platform.item.?;
        const n: i16 = @intCast(i);
        p.platform.slot = n;
        item.prop.index = n;
        item.curStrip = n;
        _ = occupancy.attach(g, p, bd);
        _ = occupancy.attach(g, item, bd);
    }
    g.platforms[3].?.platform.presentReady = 1;
}

// @orig 1068:1e5d platform_drop_cross
/// Drops the cross from a platform: x = platform.x + width, y = platform.y
/// - platform.height - cross.height (at least 1), `index` 5, `active` 1,
/// `state` 2, a move to the right edge, then the platform is drawn and
/// invalidated (hwnd dropped).
pub fn dropCross(g: *Game, obj: *Object, bd: *Backdrop) void {
    const cross = g.cross.?;
    const w = position.width(obj);
    const x = obj.x;
    const h = position.height(obj);
    const y = obj.y;
    const ch = position.height(cross);
    var cy: i16 = (0 -% ch) -% (h -% y);
    if (cy < 0) cy = 1;
    cross.prop.index = 5;
    cross.prop.active = 1;
    cross.x = w +% x;
    cross.y = cy;
    cross.prop.state = 2;
    movement.moverMoveToEdgeH(g, cross, bd, 2);
    render.draw(g, obj, bd);
    visibility.invalidate(g, obj);
}

/// SceneObject slot 30 moveToEdgeH override (movement.moveToEdgeH's platform
/// arm). Like mover_move_to_edge_h but it never starts the movement timer:
/// the platform is stepped by the hero's move tick.
// @orig 1068:1fb9 platform_move_to_edge_h
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

/// SceneObject slot 34 moveTick override (movement.moveTick's platform arm;
/// GetDC/ReleaseDC dropped): one step towards the left edge; a blocked step
/// that touches the hero attaches the hero to the platform (`linked`) and,
/// for the present with a small hero, readies it.
// @orig 1068:21c3 platform_move_tick
pub fn moveTick(g: *Game, obj: *Object, bd: *Backdrop) void {
    if (obj.mover.moving == 0) moveToEdgeH(g, obj, bd, 1);
    movement.moverStep(obj);
    if (!occupancy.canStep(g, obj, bd)) {
        if (obj.linked) |l| {
            if (l.is(.player)) {
                const item = obj.platform.item.?;
                if (item.curStrip == 3 and g.hero.?.hero.altStrips == 0) obj.platform.presentReady = 1;
                if (l.as(.player)) |p| p.linked = obj;
            }
        }
    }
    movement.placeAt(g, obj, obj.nextX, obj.nextY, bd);
    visibility.redrawOverlapping(g, obj, bd, 1);
    visibility.invalidate(g, obj);
}

// @orig 1068:240d platform_tick
/// PlatformVtbl moveTick, called from the hero's move tick: a platform that
/// is not yet fully off the left edge takes a move tick; one that is comes
/// back at x 638 at the next slot's height with the slot's drink, then heads
/// left again (hwnd and the DC dropped). Slot 1 skips the platform's own
/// `curFrame = 0`, as the original does.
pub fn tick(g: *Game, obj: *Object, bd: *Backdrop) void {
    if (0 -% position.width(obj) < obj.x) {
        moveTick(g, obj, bd);
        return;
    }
    const x: i16 = 0x27e;
    var y: i16 = undefined;
    if (obj.platform.slot == 1) {
        y = 0xcc;
    } else {
        if (obj.platform.slot == 2) {
            y = 0x108;
        } else if (obj.platform.slot == 3) {
            y = 0xcc;
        } else {
            y = 0xf7;
        }
        obj.curFrame = 0;
    }
    const item = obj.platform.item.?;
    item.curFrame = 0;
    prop.drinkRespawn(g, item, obj.platform.slot, bd);
    obj.platform.presentReady = @intFromBool(item.curStrip == 3);
    obj.platform.slot +%= 1;
    if (obj.platform.slot == 4) obj.platform.slot = 0;
    obj.x = x;
    obj.y = y;
    movement.placeAt(g, obj, x, y, bd);
    visibility.invalidate(g, obj);
    moveToEdgeH(g, obj, bd, 1);
}

/// SceneObject slot 29 play override (animation.play's platform arm; hwnd
/// dropped): hit from below. A drink not yet taken (`curFrame` 0) gives
/// +100 and is hidden until the respawn; the present, when ready and the
/// hero is small, gives +100 and starts its play-once animation.
// @orig 1068:25e3 platform_play
pub fn play(g: *Game, obj: *Object, bd: *Backdrop) void {
    const item = obj.platform.item.?;
    if (obj.platform.presentReady == 0 or g.hero.?.hero.altStrips != 0) {
        if (item.curFrame == 0) score.add100(g, bd);
        visibility.hide(g, item, bd);
        render.draw(g, obj, bd);
        visibility.invalidate(g, item);
        item.curFrame = 1;
    } else {
        score.add100(g, bd);
        animation.playOnce(g, item, bd);
    }
}
