//! Port unit `hazard` (module) of INFERNO.EXE. the Hazard class (coal, devil,
//! fire): its SceneObject overrides (stopMoving, moveTick), PropVtbl moveTick
//! (hazard_tick), spawn/despawn, hazard_hit_player (BUGS.md H6, H7),
//! inferno_create_hazards.
//!
//! GetDC/ReleaseDC and the hwnd parameters are gone (the platform's
//! screen). Every function carries `// @orig <seg:xxxx> <name>` with the
//! INFERNO address.

const Game = @import("core/game.zig").Game;
const object = @import("core/object.zig");
const Object = object.Object;
const world = @import("core/world.zig");
const Backdrop = world.Backdrop;
const object_create = @import("object_create.zig");
const backdrop = @import("backdrop.zig");
const prop = @import("prop.zig");
const score = @import("score.zig");
const animation = @import("behaviour/animation.zig");
const movement = @import("behaviour/movement.zig");
const occupancy = @import("behaviour/occupancy.zig");
const position = @import("behaviour/position.zig");
const render = @import("behaviour/render.zig");
const visibility = @import("behaviour/visibility.zig");

pub const Error = object_create.Error;

/// The original indexes the global arrays unchecked.
fn idx(i: i16) usize {
    return @as(u16, @bitCast(i));
}

/// The hazard parks off screen at x = -width (its own y).
fn parkLeft(g: *Game, obj: *Object, bd: *Backdrop) void {
    movement.placeAt(g, obj, 0 -% position.width(obj), obj.y, bd);
}

// @orig 1068:3f86 hazard_hit_player
/// The hazard's side of a hazard/hero collision (only `moveTick` calls it,
/// with `linked` a player). Big hero: death strip 10/11 (by facing), frame 0,
/// put on `g_floorY`; the hazard is erased and parked, +150, the hero plays
/// once. Small hero: `linked` = this; a stomp (hero y < hazard y - 30)
/// latches `g_stompScored` (H7) and gives +150 once, the hazard is hidden
/// and parked; otherwise, with the hero's animation not running, a life is
/// lost, the whole occupancy grid is wiped (H6, skipped with
/// `inferno_hit_keeps_grid`), the platforms and drinks are redrawn, the
/// hazard is hidden and parked and the hero plays strip 8 (facing 2) or 9.
pub fn hitPlayer(g: *Game, obj: *Object, bd: *Backdrop) void {
    const linked = obj.linked orelse return;
    if (!linked.is(.player)) {
        // Unreachable: the only caller tests isPlayer first.
        if (prop.isPowerUp(g, linked)) {
            const w = position.width(linked);
            movement.placeAt(g, obj, obj.x -% w, obj.y, bd);
            visibility.invalidate(g, obj);
            tick(g, obj, bd);
        }
        return;
    }
    const h = g.hero.?;
    if (h.hero.altStrips == 0) {
        h.linked = obj;
        if (h.y < obj.y -% 30) {
            if (g.stompScored == 0) {
                g.stompScored = 1;
                score.add150(g, bd);
            }
            visibility.hide(g, obj, bd);
            visibility.blitToDc(g, obj, bd);
            parkLeft(g, obj, bd);
        } else if (!animation.isRunning(g, h)) {
            score.loseLife(g, bd);
            if (!g.fixes.inferno_hit_keeps_grid) {
                const bd2 = backdrop.asGridBackdrop(g, bd).?;
                backdrop.gridClear(g, bd2.grid.?, null);
            }
            for (g.platforms) |p| render.draw(g, p.?.platform.item.?, bd);
            for (g.platforms) |p| visibility.show(g, p.?, bd);
            visibility.hide(g, obj, bd);
            visibility.blitToDc(g, obj, bd);
            parkLeft(g, obj, bd);
            h.curStrip = if (g.hero.?.hero.facing == 2) 8 else 9;
            animation.playOnce(g, h, bd);
        }
    } else {
        h.curStrip = if (h.hero.facing == 2) 10 else 11;
        h.curFrame = 0;
        movement.placeAt(g, h, h.x, g.floorY, bd);
        visibility.invalidate(g, h);
        render.erase(g, obj, bd);
        visibility.blitToDc(g, obj, bd);
        parkLeft(g, obj, bd);
        score.add150(g, bd);
        animation.playOnce(g, h, bd);
    }
}

// @orig 1068:46f7 hazard_tick
/// PropVtbl moveTick (the 60 ms timer 14, for each active hazard in
/// `g_hazardOrder`). At x <= 50 the next hazard enters if it is not on
/// screen; then a hazard fully off the left edge despawns, else it moves.
pub fn tick(g: *Game, obj: *Object, bd: *Backdrop) void {
    if (obj.x <= 0x32) {
        if (g.hazards[idx(g.hazardIndex)].?.prop.active == 0) spawn(g, obj, bd);
        if (0 -% position.width(obj) < obj.x) {
            moveTick(g, obj, bd);
        } else {
            despawn(g, obj);
        }
    } else {
        moveTick(g, obj, bd);
    }
}

// @orig 1068:47c2 hazard_despawn
/// `g_hazardOrder` rotates left, the hazard is off, `g_hazardIndex` cycles
/// 0-5.
pub fn despawn(g: *Game, obj: *Object) void {
    const first = g.hazardOrder[0];
    var i: usize = 1;
    while (i < 6) : (i += 1) g.hazardOrder[i - 1] = g.hazardOrder[i];
    g.hazardOrder[5] = first;
    obj.prop.active = 0;
    g.hazardIndex +%= 1;
    if (g.hazardIndex == 6) g.hazardIndex = 0;
}

// @orig 1068:4828 hazard_stop_moving
/// SceneObject slot 33 stopMoving override (movement.stopMoving's hazard
/// arm): off, parked at (640, 0).
pub fn stopMoving(g: *Game, obj: *Object, bd: *Backdrop) void {
    obj.prop.active = 0;
    obj.nextX = 0x280;
    obj.nextY = 0;
    movement.placeAt(g, obj, obj.nextX, obj.nextY, bd);
    visibility.invalidate(g, obj);
}

// @orig 1068:48bd hazard_spawn
/// The hazard `g_hazardIndex` enters at x 638 (y 329 for 0, 3, 5; 326 for 1,
/// 2; 335 for 4), set to move left, on screen. (`this` is unused.)
pub fn spawn(g: *Game, this: *Object, bd: *Backdrop) void {
    _ = this;
    const i = g.hazardIndex;
    const y: i16 = if (i == 0 or i == 3 or i == 5) 0x149 else if (i == 1 or i == 2) 0x146 else 0x14f;
    const h = g.hazards[idx(i)].?;
    h.x = 0x27e;
    h.y = y;
    movement.placeAt(g, h, 0x27e, y, bd);
    visibility.invalidate(g, h);
    prop.moveToEdgeH(g, h, bd, 1);
    g.hazards[idx(g.hazardIndex)].?.prop.active = 1;
}

// @orig 1068:49fb hazard_move_tick
/// SceneObject slot 34 moveTick override (movement.moveTick's hazard arm).
/// Not moving: moveToEdgeH(1). Next frame, one step, 5 px further left while
/// the world scrolls. Blocked by the hero (a player): `hitPlayer`. Else
/// placed, redrawn over and invalidated.
pub fn moveTick(g: *Game, obj: *Object, bd: *Backdrop) void {
    if (obj.mover.moving == 0) movement.moveToEdgeH(g, obj, bd, 1);
    _ = animation.nextFrame(g, obj);
    movement.moverStep(obj);
    if (g.scrolling != 0) obj.nextX -%= 5;
    if (!occupancy.canStep(g, obj, bd)) {
        if (obj.linked) |l| {
            if (l.is(.player)) {
                hitPlayer(g, obj, bd);
                return;
            }
        }
    }
    movement.placeAt(g, obj, obj.nextX, obj.nextY, bd);
    visibility.redrawOverlapping(g, obj, bd, 1);
    visibility.invalidate(g, obj);
}

/// `operator_new(0x4d2)` + `hazard_ctor` (timer 14 at 60 ms, steps 5 x 5,
/// hit box at 0, 0). Four strips are passed for the 3-entry tables: the
/// fourth reads what follows them (BUGS.md "Harmless (INFERNO)"): path
/// 0002:0002 (rejected, no DIB), frame count 26 (`g_hazardStripWidths[0]`),
/// width 26 (`Heights[0]`), height 0x614d ("Ma" of `s_gameName`).
fn newHazard(g: *Game, x: i16, y: i16, hit_w: i16, hit_h: i16, strip: i16) Error!*Object {
    const paths = [4][]const u8{ g.hazardStripFiles[0], g.hazardStripFiles[1], g.hazardStripFiles[2], "\x02" };
    const counts = [4]i16{ g.hazardStripFrames[0], g.hazardStripFrames[1], g.hazardStripFrames[2], g.hazardStripWidths[0] };
    const widths = [4]i16{ g.hazardStripWidths[0], g.hazardStripWidths[1], g.hazardStripWidths[2], g.hazardStripHeights[0] };
    const heights = [4]i16{ g.hazardStripHeights[0], g.hazardStripHeights[1], g.hazardStripHeights[2], 0x614d };
    const o = g.local().create(Object) catch return error.OutOfMemory;
    o.* = .{ .kind = .hazard };
    try object_create.hazardCtor(g, o, x, y, 4, &paths, &counts, &widths, &heights, 0, 0, hit_w, hit_h, 14, 0x3c, 5, 5, 1, 0, true);
    o.curStrip = strip;
    return o;
}

// @orig 1068:3bf8 inferno_create_hazards
/// Six hazards (carvao 26 x 26 at (43, 329), diabo 71 x 46 twice at (640,
/// 326), carvao at (640, 329), fogo 29 x 37 at (640, 335), carvao at (640,
/// 329); strips 0, 1, 1, 0, 2, 0). All attach; hazard i has `index` i, is
/// off, and `g_hazardOrder[i]` is i. Hazard 0 is on and walks left.
pub fn createHazards(g: *Game, bd: *Backdrop) Error!void {
    g.hazards[0] = try newHazard(g, 0x2b, 0x149, 0x1a, 0x1a, 0);
    g.hazards[1] = try newHazard(g, 0x280, 0x146, 0x47, 0x2e, 1);
    g.hazards[2] = try newHazard(g, 0x280, 0x146, 0x47, 0x2e, 1);
    g.hazards[3] = try newHazard(g, 0x280, 0x149, 0x1a, 0x1a, 0);
    g.hazards[4] = try newHazard(g, 0x280, 0x14f, 0x1d, 0x25, 2);
    g.hazards[5] = try newHazard(g, 0x280, 0x149, 0x1a, 0x1a, 0);
    var i: i16 = 0;
    while (i < 6) : (i += 1) {
        const h = g.hazards[idx(i)].?;
        _ = occupancy.attach(g, h, bd);
        h.prop.index = i;
        h.prop.active = 0;
        g.hazardOrder[idx(i)] = i;
    }
    g.hazards[0].?.prop.active = 1;
    movement.moverMoveToEdgeH(g, g.hazards[0].?, bd, 1);
}
