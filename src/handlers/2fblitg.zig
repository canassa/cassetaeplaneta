//! Port unit `handler_2fblitg` (handler). scene handler 1020:1004.
//!
//! The good-cop roadblock. Items dropped on the cop (object 0x12) or his
//! post (0x10d) get their WAVE reply from the INI and come back to the
//! inventory with the "misuse" score; the wallet (item 0x47), or the gift
//! (0x6b) when its random picture is the third one, is the right offer:
//! the hand animation plays with the anthem, the item is used up and the
//! party scene follows. Four wrong offers, or five seconds with an empty
//! inventory, end in the arrest cutscene ("2aprebom").

const Game = @import("../core/game.zig").Game;
const Object = @import("../core/object.zig").Object;
const cstr = @import("../core/cstr.zig");
const msg = @import("../core/msg.zig");
const Msg = msg.Msg;
const Wave = @import("../platform/platform.zig").Wave;
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

const COP_ID: i16 = 0x12;
const POST_ID: i16 = 0x10d;
const HAND_ID: u16 = 0x13;
const WALLET_ITEM: i16 = 0x47;
const GIFT_ITEM: i16 = 0x6b;
/// The gift's random picture (0..3) that is the right offer.
const GIFT_RIGHT_FRAME: i16 = 2;
/// The five-second "nothing to offer" timer.
const TIMER_ID: u16 = 0x15;
const TIMER_MS: u16 = 5000;

/// Not in the original: an item released here that reaches the engine was
/// offered to a character (`game.handlerAnswersOffers`, B30's fix).
pub const answers_offers = true;

pub const State = struct {
    // @orig g_s2fblitgOfferCount
    offerCount: i16 = 0,
    // @orig g_s2fblitgRightItem
    rightItem: i16 = 0,
    // @orig g_s2fblitgTimedOut
    timedOut: i16 = 0,
    // @orig g_s2fblitgWaveVariant
    waveVariant: i16 = 0,
    // @orig g_s2fblitgHitObject
    hitObject: ?*Object = null,
    // @orig g_s2fblitgCop
    cop: ?*Object = null,
    // @orig g_s2fblitgHand
    hand: ?*Object = null,
    // @orig g_s2fblitgWaveTarget
    waveTarget: ?*Object = null,
    // @orig g_s2fblitgReturnedItem
    returnedItem: ?*Object = null,
    // @orig g_s2fblitgWavePath
    wavePath: [256]u8 = @splat(0),
    // @orig g_s2fblitgGiftFrame
    giftFrame: i16 = 0,
    // @orig g_s2fblitgUnkA19E (only ever written 0)
    unkA19E: i16 = 0,
    // @orig g_s2fblitgAnthemWave
    anthemWave: ?Wave = null,
};

/// `wave_open(concat_strings(g_driveCD, name))`.
fn openWave(g: *Game, name: []const u8) ?Wave {
    const path = ini.concatStrings(&g.concatBuf, &g.driveCD, name);
    return sound.open(g, path) catch null;
}

/// The cop starts his animation and plays the "PLBOMR02" line (the
/// roadblock's final warning).
fn copWarns(g: *Game, s: *State) void {
    tick.play(g, s.cop.?, g.scene.?.backdrop.?);
    _ = sound.play(g, msg.main_window, openWave(g, "fase2\\2fcopbom\\PLBOMR02.WAV"));
}

/// Clears the offer bookkeeping (the first group of the scene's globals).
fn resetOffers(s: *State) void {
    s.offerCount = 0;
    s.waveVariant = 0;
    s.unkA19E = 0;
    s.rightItem = 0;
    s.timedOut = 0;
}

/// To the arrest cutscene.
fn gotoArrest(g: *Game) void {
    update_list.discard(&g.updateList);
    _ = game_scenes.switchScene(g, "2aprebom", 0, 0, 0, 0, 0, 1, 0);
}

/// Rectangle query under the click, stored in `hitObject`; true when it
/// found something occupied.
fn pick(g: *Game, s: *State, m: Msg) bool {
    const bd = g.scene.?.backdrop.?;
    const q = backdrop.queryRect(g, bd, @as(i16, @bitCast(m.lo())) +% bd.originX, @as(i16, @bitCast(m.hi())) +% bd.originY, 0x10, 0x10);
    s.hitObject = q.obj;
    return q.result >= 1;
}

// @orig 1020:1004 handler_2fblitg
pub fn handle(g: *Game, m: Msg) i16 {
    const s = g.sceneState(State);
    switch (m.id) {
        msg.wm.rbuttondown => {
            if (!pick(g, s, m)) return 0;
            const hit = s.hitObject orelse return 0;
            if (hit.id == COP_ID or hit.id == POST_ID) return 1;
            return 0;
        },
        msg.wm.rbuttonup => return rightButtonUp(g, s, m),
        msg.wm.timer => {
            // Any timer message, not only 0x15 (as the original).
            g.killTimer(TIMER_ID);
            copWarns(g, s);
            s.timedOut = 1;
            return 1;
        },
        msg.wm.mm_wom_done => {
            womDone(g, s);
            return 0;
        },
        msg.noite.scene_started => {
            s.anthemWave = openWave(g, "fase2\\2fcopbom\\Brasil.wav");
            g.selectedItem = null;
            const cop = s.cop.?;
            tick.play(g, cop, g.scene.?.backdrop.?);
            _ = sound.play(g, msg.main_window, cop.wave);
            if (object_list.isEmpty(&g.player.?.actor.inventory)) g.setTimer(TIMER_ID, TIMER_MS);
            return 0;
        },
        msg.noite.object_created => {
            if (m.wparam == @as(u16, @intCast(COP_ID))) {
                s.cop = g.newObject;
            } else if (m.wparam == HAND_ID) {
                const hand = g.newObject.?;
                s.hand = hand;
                frames.resetRects(hand);
                const bd = g.scene.?.backdrop.?;
                visibility.hideAndInvalidate(g, hand, 0, bd);
                visibility.redrawOverlapping(g, hand, g.scene.?.backdrop.?, 0);
            }
            return 1;
        },
        else => return 0,
    }
}

/// Right button released while carrying an item: the offer.
fn rightButtonUp(g: *Game, s: *State, m: Msg) i16 {
    if (g.itemSelected == 0) return 1;
    if (!pick(g, s, m) or s.hitObject == null) {
        g.itemSelected = 0;
        g.selectedItem = null;
        return 1;
    }
    const cop = s.cop.?;
    if (animation.isRunning(g, cop)) {
        animation.stopAndRedraw(g, cop, g.scene.?.backdrop.?);
        g.setSystemTimer(@bitCast(cop.anim.timerId), @bitCast(cop.anim.timerPeriod));
        sound.stop(&g.sound, g.plat, cop.wave);
    }
    const item = g.selectedItem orelse {
        g.itemSelected = 0;
        g.selectedItem = null;
        return 1;
    };
    const hit = s.hitObject.?;
    if (hit.id != POST_ID and hit.id != COP_ID) {
        g.itemSelected = 0;
        g.selectedItem = null;
        return 1;
    }
    s.offerCount +%= 1;
    _ = ini.seekSection(&g.ini, g.plat, g.fixes, g.iniFile, &g.curSceneName, true) catch |e| @panic(@errorName(e));

    var right = false;
    if (item.id == WALLET_ITEM) {
        s.waveVariant = 0;
        right = true;
    } else if (item.id == GIFT_ITEM) {
        s.giftFrame = ini.randomBelow(&g.rand, g.plat, 4);
        _ = frames.setCurFrame(g.selectedItem.?, @bitCast(s.giftFrame));
        s.waveVariant = s.giftFrame;
        right = s.giftFrame == GIFT_RIGHT_FRAME;
    }
    if (right) {
        s.rightItem = 1;
        const hand = s.hand.?;
        visibility.show(g, hand, g.scene.?.backdrop.?);
        _ = visibility.invalidate(g, hand);
        tick.play(g, hand, g.scene.?.backdrop.?);
        _ = sound.play(g, msg.main_window, s.anthemWave);
    }

    if (s.offerCount > 3 and s.rightItem != 1) {
        copWarns(g, s);
        return 1;
    }

    // The scripted reply: WAVE=<hit id>,<variant>,<item id>,<file>,<object>.
    _ = ini.findWave(&g.ini, g.plat, g.fixes, g.iniFile, hit.id, s.waveVariant, g.selectedItem.?.id, &g.sound.cache, &g.ini.rec.nomeWave, &g.ini.rec.waveObject) catch |e| @panic(@errorName(e));
    s.waveVariant = s.unkA19E;
    // Look up the scene object the reply belongs to (the result is unused).
    s.waveTarget = g.scene.?.objects.head;
    while (s.waveTarget) |t| : (s.waveTarget = t.next) {
        if (t.id == g.ini.rec.waveObject) break;
    }
    cstr.copy(&s.wavePath, ini.assetPath(&g.ini, &g.driveCD, &g.driveHD, &g.ini.rec.nomeWave, -3));
    tick.play(g, cop, g.scene.?.backdrop.?);
    const wave = sound.open(g, &s.wavePath) catch null;
    _ = sound.play(g, msg.main_window, wave);
    return 0;
}

/// A wave finished: the time-out, or the end of a reply (wrong item goes
/// back to the inventory, the right one is used up and the scene ends).
fn womDone(g: *Game, s: *State) void {
    // Set when the time-out has already switched to the arrest: the old
    // scene, the cop and the hit object are freed (BUGS.md B17).
    var switched = false;
    if (s.timedOut != 0) {
        resetOffers(s);
        gotoArrest(g);
        switched = true;
        // The old scene (and the cop) is gone; the original now touches the
        // freed cop with the new backdrop, which has no visible effect.
        if (g.selectedItem == null or s.hitObject == null) return;
    } else if (g.selectedItem == null or s.hitObject == null) {
        animation.stopAndRedraw(g, s.cop.?, g.scene.?.backdrop.?);
        return;
    }
    const item = g.selectedItem.?;
    const cop = s.cop.?;
    if (s.rightItem == 0) {
        // Wrong offer: the item returns to the inventory, score penalty.
        g.score +%= item.portable.scoreMisuse;
        const ret = item.as(.portable).?;
        s.returnedItem = ret;
        _ = portable.pickUp(g, ret, g.player.?);
        frames.resetRects(ret);
        visibility.hideAndInvalidate(g, ret, 0, g.scene.?.backdrop.?);
        visibility.redrawOverlapping(g, ret, g.scene.?.backdrop.?, 0);
        // After the time-out switch the hit object and the cop are freed:
        // the original's reoccupy and stopAndRedraw on them are skipped
        // (an offer still pending when the time-out wave ends).
        if (!switched) {
            occupancy.reoccupy(g, s.hitObject.?, g.scene.?.backdrop.?);
            animation.stopAndRedraw(g, cop, g.scene.?.backdrop.?);
        }
        if (s.offerCount >= 4) {
            resetOffers(s);
            gotoArrest(g);
        }
        g.selectedItem = null;
        return;
    }
    // Right offer: the item is used up.
    g.score +%= item.portable.scoreUse;
    visibility.hideAndInvalidate(g, item, 0, g.scene.?.backdrop.?);
    _ = object_list.remove(&g.globalObjects, item);
    draw_list.remove(&g.drawList, item);
    _ = object_list.add(g, &g.usedObjects, item);
    animation.stopAndRedraw(g, cop, g.scene.?.backdrop.?);
    animation.stopAndRedraw(g, s.hand.?, g.scene.?.backdrop.?);
    resetOffers(s);
    update_list.discard(&g.updateList);
    _ = game_scenes.switchScene(g, "2ffesta4", -0x96, 0xfa, 1, 0, 0, 0, 0);
    g.selectedItem = null;
}
