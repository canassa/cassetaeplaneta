//! Port unit `handler_2fcopmu` (handler). scene handler 1020:2576.
//!
//! The policewoman roadblock. Right-clicking an inventory item and releasing
//! it on her (object 0x1a) or her post (0x110) gives the item's WAVE reply
//! and sends it back to the inventory with the misuse score. Only the gift
//! (item 0x6b) whose random fourth picture shows up is the right offer
//! (score for use, item consumed, on to the seduction cutscene); the gift's
//! second picture, four wrong offers, or five seconds with an empty
//! inventory end in the arrest cutscene.

const Game = @import("../core/game.zig").Game;
const Msg = @import("../core/msg.zig").Msg;
const msg = @import("../core/msg.zig");
const Object = @import("../core/object.zig").Object;
const cstr = @import("../core/cstr.zig");
const platform = @import("../platform/platform.zig");
const backdrop = @import("../backdrop.zig");
const draw_list = @import("../draw_list.zig");
const frames = @import("../frames.zig");
const game_scenes = @import("../game_scenes.zig");
const ini = @import("../ini.zig");
const object_list = @import("../object_list.zig");
const portable = @import("../portable.zig");
const sound = @import("../sound.zig");
const update_list = @import("../update_list.zig");
const animation = @import("../behaviour/animation.zig");
const occupancy = @import("../behaviour/occupancy.zig");
const tick = @import("../behaviour/tick.zig");
const visibility = @import("../behaviour/visibility.zig");

/// INI Numbers: the policewoman, her post, the gift item.
const COP_ID: i16 = 0x1a;
const POST_ID: i16 = 0x110;
const GIFT_ID: i16 = 0x6b;
/// Timer id of the "empty inventory" time-out.
const TIMER_ID: u16 = 0x15;

pub const State = struct {
    // @orig g_s2fcopmuHasGift
    hasGift: i16 = 0,
    // @orig g_s2fcopmuGreetingSaid
    greetingSaid: i16 = 0,
    // @orig g_s2fcopmuGreetingPending
    greetingPending: i16 = 1,
    // @orig g_s2fcopmuTimedOut
    timedOut: i16 = 0,
    // @orig g_s2fcopmuOfferCount
    offerCount: i16 = 0,
    // @orig g_s2fcopmuRightItem
    rightItem: i16 = 0,
    // @orig g_s2fcopmuWaveVariant
    waveVariant: i16 = 0,
    // @orig g_s2fcopmuHitObject
    hitObject: ?*Object = null,
    // @orig g_s2fcopmuCop
    cop: ?*Object = null,
    // @orig g_s2fcopmuScanObject
    scanObject: ?*Object = null,
    // @orig g_s2fcopmuReturnedItem
    returnedItem: ?*Object = null,
    // @orig g_s2fcopmuWavePath
    wavePath: [256]u8 = @splat(0),
    // @orig g_s2fcopmuUnkA3D4 (only ever written, with 0)
    unkA3D4: i16 = 0,
    // @orig g_s2fcopmuGiftFrame
    giftFrame: i16 = 0,
};

fn resetOffers(s: *State) void {
    s.greetingPending = 1;
    s.offerCount = 0;
    s.waveVariant = 0;
    s.unkA3D4 = 0;
    s.rightItem = 0;
    s.hasGift = 0;
    s.greetingSaid = 0;
    s.timedOut = 0;
}

fn die(e: anyerror) noreturn {
    @panic(@errorName(e));
}

/// Opens `<driveCD><rel>` and plays it (an unopenable wave plays as "done").
fn playFile(g: *Game, rel: []const u8) void {
    const path = ini.concatStrings(&g.concatBuf, &g.driveCD, rel);
    const wave = sound.open(g, path) catch null;
    _ = sound.play(g, msg.main_window, wave);
}

/// The cop's animation starts looping.
fn playCop(g: *Game, s: *State) void {
    tick.play(g, s.cop.?.as(.animation).?, g.scene.?.backdrop.?);
}

/// Resets the offer state and goes to a cutscene (`is_1animation` set).
fn switchCutscene(g: *Game, name: []const u8) void {
    update_list.discard(&g.updateList);
    _ = game_scenes.switchScene(g, name, 0, 0, 0, 0, 0, 1, 0);
}

fn seekCurrentSection(g: *Game) void {
    _ = ini.seekSection(&g.ini, g.plat, g.fixes, @bitCast(g.iniFile), cstr.slice(&g.curSceneName), true) catch |e| die(e);
}

/// 0x205: the item is released at `hit` (the cop or her post).
fn dropOnCop(g: *Game, s: *State, hit: *Object) i16 {
    const item = g.selectedItem.?;
    s.offerCount +%= 1;
    seekCurrentSection(g);
    if (item.id == GIFT_ID) {
        s.giftFrame = ini.randomBelow(&g.rand, g.plat, 4);
        _ = frames.setCurFrame(item, @bitCast(s.giftFrame));
        s.waveVariant = s.giftFrame;
        s.rightItem = @intFromBool(s.giftFrame == 3);
    }
    if (s.offerCount > 3 and s.rightItem != 1) {
        playCop(g, s);
        playFile(g, "PLMULR71.WAV");
        return 1;
    }
    seekCurrentSection(g);
    _ = ini.findWave(&g.ini, g.plat, g.fixes, @bitCast(g.iniFile), hit.id, s.waveVariant, item.id, &g.sound.cache, &g.ini.rec.nomeWave, &g.ini.rec.waveObject) catch |e| die(e);
    s.waveVariant = s.unkA3D4;
    // Looks for the object the WAVE line names (the result is never used).
    s.scanObject = g.scene.?.objects.head;
    while (s.scanObject) |o| : (s.scanObject = o.next) {
        if (o.id == g.ini.rec.waveObject) break;
    }
    cstr.copy(&s.wavePath, ini.assetPath(&g.ini, &g.driveCD, &g.driveHD, &g.ini.rec.nomeWave, -3));
    playCop(g, s);
    const wave = sound.open(g, cstr.slice(&s.wavePath)) catch null;
    _ = sound.play(g, msg.main_window, wave);
    return 0;
}

// @orig 1020:2576 handler_2fcopmu
pub fn handle(g: *Game, m: Msg) i16 {
    const s = g.sceneState(State);
    switch (m.id) {
        msg.wm.timer => {
            g.killTimer(TIMER_ID);
            playCop(g, s);
            // BUGS.md B3: the doubled extension makes the open fail.
            playFile(g, if (g.fixes.double_wav_extension) "fase2\\2fcopmu\\PLMULR71.WAV" else "fase2\\2fcopmu\\PLMULR71.WAV.WAV");
            s.timedOut = 1;
            return 1;
        },
        msg.wm.rbuttondown => {
            const bd = g.scene.?.backdrop.?;
            const q = backdrop.queryRect(g, bd, @as(i16, @bitCast(m.lo())) +% bd.originX, @as(i16, @bitCast(m.hi())) +% bd.originY, 0x10, 0x10);
            s.hitObject = q.obj;
            if (q.result < 1) return 0;
            const hit = s.hitObject orelse return 0;
            if (hit.id == COP_ID or hit.id == POST_ID) return 1;
            return 0;
        },
        msg.wm.rbuttonup => {
            if (g.itemSelected == 0) return 1;
            const bd = g.scene.?.backdrop.?;
            const q = backdrop.queryRect(g, bd, @as(i16, @bitCast(m.lo())) +% bd.originX, @as(i16, @bitCast(m.hi())) +% bd.originY, 0x10, 0x10);
            s.hitObject = q.obj;
            const hit = s.hitObject orelse {
                g.itemSelected = 0;
                g.selectedItem = null;
                return 1;
            };
            if (q.result < 1) {
                g.itemSelected = 0;
                g.selectedItem = null;
                return 1;
            }
            const cop = s.cop.?;
            if (animation.isRunning(g, cop)) {
                animation.stopAndRedraw(g, cop, g.scene.?.backdrop.?);
                // Re-arms the animation timer, then silences the cop.
                g.setSystemTimer(@bitCast(cop.anim.timerId), @bitCast(cop.anim.timerPeriod));
                sound.stop(&g.sound, g.plat, cop.wave);
            }
            if (g.selectedItem != null and (hit.id == POST_ID or hit.id == COP_ID)) {
                return dropOnCop(g, s, hit);
            }
            g.itemSelected = 0;
            g.selectedItem = null;
            return 1;
        },
        msg.wm.mm_wom_done => return womDone(g, s),
        msg.noite.scene_started => {
            g.selectedItem = null;
            const player = g.player.?;
            s.scanObject = player.actor.inventory.head;
            while (s.scanObject) |o| : (s.scanObject = o.next) {
                if (o.id == GIFT_ID) {
                    s.hasGift = 1;
                    break;
                }
            }
            if (object_list.isEmpty(&player.actor.inventory)) {
                g.setTimer(TIMER_ID, 5000);
                return 0;
            }
            playCop(g, s);
            _ = sound.play(g, msg.main_window, s.cop.?.wave);
            return 0;
        },
        msg.noite.object_created => {
            if (m.wparam == @as(u16, @bitCast(COP_ID))) s.cop = g.newObject;
            return 1;
        },
        else => return 0,
    }
}

/// 0x3bd: a wave ended. The time-out and the verdict on the last offer are
/// decided here, then the greeting / reply of the cop.
fn womDone(g: *Game, s: *State) i16 {
    // The original keeps going after switching scenes; the cop (a scene
    // object) is freed by then, so the calls on it are skipped here.
    var switched = false;
    if (s.timedOut != 0) {
        resetOffers(s);
        switchCutscene(g, "2apremu2");
        switched = true;
    }
    const item = g.selectedItem orelse return idle(g, s, switched);
    const hit = s.hitObject orelse return idle(g, s, switched);
    _ = hit;
    // (selectedItem is never set while the time-out can run.)
    if (switched) return 0;
    const bd = g.scene.?.backdrop.?;
    if (s.rightItem == 0) {
        // Wrong offer: the item goes back to the player.
        g.score +%= item.portable.scoreMisuse;
        s.returnedItem = item;
        _ = portable.pickUp(g, item, g.player.?);
        frames.resetRects(item);
        visibility.hideAndInvalidate(g, item, 0, bd);
        visibility.redrawOverlapping(g, item, bd, 0);
        animation.stopAndRedraw(g, s.cop.?, bd);
        occupancy.reoccupy(g, s.hitObject.?, bd);
        if (item.id == GIFT_ID and s.giftFrame == 1) {
            resetOffers(s);
            switchCutscene(g, "2apremu2");
            return 1;
        }
        if (s.offerCount > 3) {
            resetOffers(s);
            switchCutscene(g, "2apremu2");
        }
    } else {
        // Right offer: the item is used up.
        g.score +%= item.portable.scoreUse;
        visibility.hideAndInvalidate(g, item, 0, bd);
        _ = object_list.remove(&g.globalObjects, item);
        draw_list.remove(&g.drawList, item);
        _ = object_list.add(g, &g.usedObjects, item);
        animation.stopAndRedraw(g, s.cop.?, bd);
        resetOffers(s);
        switchCutscene(g, "2acopsex");
    }
    g.selectedItem = null;
    return 0;
}

/// 0x3bd with nothing being offered: greeting, gift remark or arrest.
fn idle(g: *Game, s: *State, switched_in: bool) i16 {
    var switched = switched_in;
    if (s.greetingSaid != 0) {
        s.greetingSaid = 0;
        if (s.hasGift != 0) {
            playCop(g, s);
            playFile(g, "fase2\\2fcopmu\\PLMULS03.WAV");
            s.hasGift = 0;
            return 0;
        }
        resetOffers(s);
        switchCutscene(g, "2apremu2");
        switched = true;
    }
    if (!switched) animation.stopAndRedraw(g, s.cop.?, g.scene.?.backdrop.?);
    if (s.greetingPending == 0) return 0;
    playFile(g, "fase2\\2fcopmu\\garots05.WAV");
    s.greetingSaid = 1;
    s.greetingPending = 0;
    return 0;
}
