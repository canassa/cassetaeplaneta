//! Port unit `handler_2fsuabig` (handler). scene handler 1020:0000.
//!
//! The hold-up. Items dropped on the robber's gun (object 6) get their WAVE
//! reply and come back to the inventory; the gift package (item 0x6b) is the
//! right one: it is scored, consumed and the follow-up cutscene (`2fonifin`)
//! starts. Four wrong offers, or five seconds with an empty inventory, end
//! in a shot that costs a life (no game-over test, BUGS.md B1) and returns to
//! the street (`2fpontoc`).

const Game = @import("../core/game.zig").Game;
const Msg = @import("../core/msg.zig").Msg;
const msg = @import("../core/msg.zig");
const Object = @import("../core/object.zig").Object;
const world = @import("../core/world.zig");
const Backdrop = world.Backdrop;
const Scene = world.Scene;
const cstr = @import("../core/cstr.zig");
const animation = @import("../behaviour/animation.zig");
const occupancy = @import("../behaviour/occupancy.zig");
const tick = @import("../behaviour/tick.zig");
const visibility = @import("../behaviour/visibility.zig");
const backdrop = @import("../backdrop.zig");
const draw_list = @import("../draw_list.zig");
const frames = @import("../frames.zig");
const game_scenes = @import("../game_scenes.zig");
const ini = @import("../ini.zig");
const object_list = @import("../object_list.zig");
const portable = @import("../portable.zig");
const sound = @import("../sound.zig");
const update_list = @import("../update_list.zig");

/// The robber's gun (the drop target) and the robber (the animation).
const GUN_ID: i16 = 6;
const ROBBER_ID: i16 = 5;
/// The item that is the right answer (the gift package).
const RIGHT_ITEM_ID: i16 = 0x6b;
/// The 5-second hold-up timer.
const TIMER_ID: u16 = 0x15;

const shot_wav = "fase2\\2apolit\\tiro.wav";

pub const State = struct {
    // @orig g_s2fsuabigOfferCount
    offerCount: i16 = 0,
    // @orig g_s2fsuabigRightItem
    rightItem: i16 = 0,
    // @orig g_s2fsuabigShot
    shot: i16 = 0,
    // @orig g_s2fsuabigWaveVariant
    waveVariant: i16 = 0,
    // @orig g_s2fsuabigHitObject
    hitObject: ?*Object = null,
    // @orig g_s2fsuabigRobber
    robber: ?*Object = null,
    // @orig g_s2fsuabigHitResult
    hitResult: i8 = 0,
    // @orig g_s2fsuabigReturnedItem
    returnedItem: ?*Object = null,
    // @orig g_s2fsuabigWavePath
    wavePath: [256]u8 = @splat(0),
};

/// The original's unchecked pointers: a missing one is a crash there.
fn must(comptime T: type, p: ?*T) *T {
    return p orelse @panic("2fsuabig: null pointer");
}

fn bdOf(g: *Game) *Backdrop {
    return must(Backdrop, must(Scene, g.scene).backdrop);
}

fn die(e: anyerror) noreturn {
    @panic(@errorName(e));
}

fn iniFd(g: *Game) u16 {
    return g.iniFile; // Game+0x680
}

fn playWave(g: *Game, path: []const u8) void {
    const w = sound.open(g, path) catch |e| die(e);
    _ = sound.play(g, msg.main_window, w);
}

fn playShot(g: *Game) void {
    playWave(g, ini.concatStrings(&g.concatBuf, &g.driveCD, shot_wav));
}

/// Picks the object under the cursor into `s.hitObject` and `s.hitResult`;
/// the result is the grid query's.
fn query(g: *Game, s: *State, m: Msg) i8 {
    const bd = bdOf(g);
    const q = backdrop.queryRect(g, bd, @as(i16, @bitCast(m.lo())) +% bd.originX, @as(i16, @bitCast(m.hi())) +% bd.originY, 16, 16);
    s.hitObject = q.obj;
    s.hitResult = q.result;
    return q.result;
}

/// The shot or the fourth wrong offer: reset the offer state, take a life
/// (no game-over test), stop the robber and go back to the street.
fn lose(g: *Game, s: *State) void {
    s.offerCount = 0;
    s.waveVariant = 0;
    s.rightItem = 0;
    g.lives -%= 1;
    animation.stopAndRedraw(g, must(Object, s.robber), bdOf(g));
    update_list.discard(&g.updateList);
    _ = game_scenes.switchScene(g, "2fpontoc", 0xf0, 0xfa, 1, 1, 0, 0, 0);
}

// @orig 1020:0000 handler_2fsuabig
pub fn handle(g: *Game, m: Msg) i16 {
    const s = g.sceneState(State);
    switch (m.id) {
        msg.wm.rbuttonup => {
            if (g.itemSelected != 0) {
                const hit = query(g, s, m);
                if (hit > 0) {
                    if (s.hitObject) |h| {
                        if (h.id == GUN_ID) return offer(g, s, h);
                    }
                }
                g.itemSelected = 0;
                g.selectedItem = null;
            }
            return 1;
        },
        msg.wm.timer => {
            g.killTimer(TIMER_ID);
            playShot(g);
            s.shot = 1;
            return 1;
        },
        msg.wm.rbuttondown => {
            if (query(g, s, m) <= 0) return 0;
            const h = s.hitObject orelse return 0;
            if (h.id == GUN_ID) return 1;
            if (h.id == ROBBER_ID) return 1;
            return 0;
        },
        msg.wm.mm_wom_done => {
            if (s.shot != 0) {
                s.shot = 0;
                lose(g, s);
                return 1;
            }
            if (g.selectedItem == null and s.hitObject == null) return 0;
            const bd = bdOf(g);
            if (s.rightItem != 0) {
                const item = must(Object, g.selectedItem);
                g.score +%= item.portable.scoreUse;
                visibility.hideAndInvalidate(g, item, 0, bd);
                _ = visibility.invalidate(g, item);
                _ = object_list.remove(&g.globalObjects, item);
                draw_list.remove(&g.drawList, item);
                _ = object_list.add(g, &g.usedObjects, item);
                animation.stopAndRedraw(g, must(Object, s.robber), bd);
                s.offerCount = 0;
                s.waveVariant = 0;
                s.rightItem = 0;
                update_list.discard(&g.updateList);
                _ = game_scenes.switchScene(g, "2fonifin", 0, 0, 0, 0, 0, 1, 0);
                g.selectedItem = null;
                return 0;
            }
            // A wrong offer: the item goes back to the player's inventory.
            const item = must(Object, g.selectedItem).as(.portable) orelse @panic("2fsuabig: asPortable returned NULL");
            s.returnedItem = item;
            _ = portable.pickUp(g, item, must(Object, must(Object, g.player).as(.player)));
            frames.resetRects(item);
            visibility.hideAndInvalidate(g, item, 0, bd);
            visibility.redrawOverlapping(g, item, bd, 0);
            occupancy.reoccupy(g, must(Object, s.hitObject), bd);
            if (s.offerCount < 4) return 1;
            lose(g, s);
            return 1;
        },
        msg.noite.scene_started => {
            if (s.robber) |r| {
                tick.play(g, must(Object, r.as(.animation)), bdOf(g));
            }
            if (!object_list.isEmpty(&must(Object, must(Object, g.player).as(.player)).actor.inventory)) return 1;
            g.setTimer(TIMER_ID, 5000);
            return 1;
        },
        msg.noite.object_created => {
            if (m.wparam == @as(u16, @bitCast(ROBBER_ID))) s.robber = g.newObject;
            return 1;
        },
        else => return 0,
    }
}

/// An item was dropped on the gun: the fourth offer is the shot, the others
/// get their WAVE reply from the scene's `WAVE=` lines (hit object, variant,
/// item). The selected item is marked right when it is the gift package.
fn offer(g: *Game, s: *State, hit: *Object) i16 {
    s.offerCount +%= 1;
    if (s.offerCount < 4) {
        const fd = iniFd(g);
        const name = cstr.slice(&g.curSceneName);
        _ = ini.seekSection(&g.ini, g.plat, g.fixes, fd, name, true) catch |e| die(e);
        s.waveVariant = 0;
        const item = must(Object, g.selectedItem);
        const is_right = item.id == RIGHT_ITEM_ID;
        if (is_right) {
            s.rightItem = 1;
            _ = frames.setCurFrame(item, 1);
        }
        s.waveVariant = @intFromBool(is_right);
        _ = ini.seekSection(&g.ini, g.plat, g.fixes, fd, name, true) catch |e| die(e);
        _ = ini.findWave(&g.ini, g.plat, g.fixes, fd, hit.id, s.waveVariant, item.id, &g.sound.cache, &g.ini.rec.nomeWave, &g.ini.rec.waveObject) catch |e| die(e);
        const p = ini.assetPath(&g.ini, &g.driveCD, &g.driveHD, &g.ini.rec.nomeWave, -3);
        cstr.copy(&s.wavePath, p);
        playWave(g, &s.wavePath);
    } else {
        playShot(g);
    }
    return 0;
}
