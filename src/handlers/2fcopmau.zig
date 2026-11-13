//! Port unit `handler_2fcopmau` (handler). scene handler 1020:1a5a.
//!
//! The bad-cop roadblock. When the scene starts the cop (object 0x14)
//! speaks; afterwards he comments on the gift package (object 0x6b) or the
//! player is arrested (scene 2apremau). Items dropped on the cop (0x14) or
//! his post (0x10e) get their WAVE reply from the INI and come back with the
//! misuse score; the wallet (0x47) is the right answer (anthem, score, on to
//! 2ffesta4); the gift, four wrong offers, or five seconds with an empty
//! inventory end in the arrest.

const Game = @import("../core/game.zig").Game;
const Object = @import("../core/object.zig").Object;
const msg = @import("../core/msg.zig");
const Msg = msg.Msg;
const cstr = @import("../core/cstr.zig");
const Wave = @import("../platform/platform.zig").Wave;
const backdrop = @import("../backdrop.zig");
const frames = @import("../frames.zig");
const game_scenes = @import("../game_scenes.zig");
const ini = @import("../ini.zig");
const object_list = @import("../object_list.zig");
const draw_list = @import("../draw_list.zig");
const portable = @import("../portable.zig");
const sound = @import("../sound.zig");
const update_list = @import("../update_list.zig");
const animation = @import("../behaviour/animation.zig");
const occupancy = @import("../behaviour/occupancy.zig");
const tick = @import("../behaviour/tick.zig");
const visibility = @import("../behaviour/visibility.zig");

const COP_ID: i16 = 0x14;
const POST_ID: i16 = 0x10e;
const GIFT_ID: i16 = 0x6b;
const WALLET_ID: i16 = 0x47;
/// Timer (WM_TIMER) that fires when the player arrives with nothing.
const TIMEOUT_TIMER: u16 = 0x15;

pub const State = struct {
    // @orig g_s2fcopmauHasGift
    hasGift: i16 = 0,
    // @orig g_s2fcopmauGreetingPending (initial value 1 in the EXE's data)
    greetingPending: i16 = 1,
    // @orig g_s2fcopmauOfferCount
    offerCount: i16 = 0,
    // @orig g_s2fcopmauRightItem
    rightItem: i16 = 0,
    // @orig g_s2fcopmauTimedOut
    timedOut: i16 = 0,
    // @orig g_s2fcopmauWaveVariant
    waveVariant: i16 = 0,
    // @orig g_s2fcopmauHitObject
    hitObject: ?*Object = null,
    // @orig g_s2fcopmauCop
    cop: ?*Object = null,
    // @orig g_s2fcopmauScanObject
    scanObject: ?*Object = null,
    // @orig g_s2fcopmauReturnedItem
    returnedItem: ?*Object = null,
    // @orig g_s2fcopmauWavePath
    wavePath: [256]u8 = @splat(0),
    // @orig g_s2fcopmauGiftFrame
    giftFrame: i16 = 0,
    // @orig g_s2fcopmauUnkA2BA (only ever written with 0)
    unkA2BA: i16 = 0,
    // @orig g_s2fcopmauAnthemWave
    anthemWave: ?Wave = null,
};

/// The block of assignments every exit of the scene repeats.
fn resetState(s: *State) void {
    s.greetingPending = 1;
    s.offerCount = 0;
    s.waveVariant = 0;
    s.unkA2BA = 0;
    s.rightItem = 0;
    s.hasGift = 0;
    s.timedOut = 0;
}

/// Opens the wave `<CD>` + `rel` (null when it does not exist).
fn openWave(g: *Game, rel: []const u8) ?Wave {
    const path = ini.concatStrings(&g.concatBuf, &g.driveCD, rel);
    return sound.open(g, path) catch null;
}

fn playWave(g: *Game, wave: ?Wave) void {
    _ = sound.play(g, msg.main_window, wave);
}

/// The cop starts his animation (slot 0xc0 of his Animation part).
fn copPlay(g: *Game, s: *State) void {
    tick.play(g, s.cop.?, g.scene.?.backdrop.?);
}

/// The arrest cutscene.
fn arrest(g: *Game) void {
    _ = game_scenes.switchScene(g, "2apremau", 0, 0, 0, 0, 0, 1, 0);
}

fn iniFd(g: *Game) u16 {
    return g.iniFile; // Game+0x680
}

// @orig 1020:1a5a handler_2fcopmau
pub fn handle(g: *Game, m: Msg) i16 {
    const s = g.sceneState(State);
    switch (m.id) {
        msg.wm.timer => {
            // Five seconds with an empty inventory: the cop loses patience.
            g.killTimer(TIMEOUT_TIMER);
            copPlay(g, s);
            // Original bug B3: the path has a doubled extension.
            const rel = if (g.fixes.double_wav_extension) "fase2\\2fcopmau\\PMAUS08.WAV" else "fase2\\2fcopmau\\PMAUS08.WAV.WAV";
            playWave(g, openWave(g, rel));
            s.timedOut = 1;
            return 1;
        },
        msg.wm.rbuttondown => {
            const bd = g.scene.?.backdrop.?;
            const q = backdrop.queryRect(g, bd, @as(i16, @bitCast(m.lo())) +% bd.originX, @as(i16, @bitCast(m.hi())) +% bd.originY, 0x10, 0x10);
            s.hitObject = q.obj;
            if (q.result < 1) return 0;
            const hit = s.hitObject orelse return 0;
            if (hit.id == COP_ID) return 1;
            if (hit.id == POST_ID) return 1;
            return 0;
        },
        msg.wm.rbuttonup => return rightButtonUp(g, s, m),
        msg.wm.mm_wom_done => return womDone(g, s),
        msg.noite.scene_started => {
            g.selectedItem = null;
            s.anthemWave = openWave(g, "fase2\\2fcopmau\\Brasil.wav");
            const inv = &g.player.?.actor.inventory;
            s.scanObject = inv.head;
            while (s.scanObject) |o| {
                if (o.id == GIFT_ID) {
                    s.hasGift = 1;
                    break;
                }
                s.scanObject = o.next;
            }
            if (object_list.isEmpty(&g.player.?.actor.inventory)) {
                g.setTimer(TIMEOUT_TIMER, 5000);
                return 0;
            }
            copPlay(g, s);
            playWave(g, s.cop.?.wave);
            return 0;
        },
        msg.noite.object_created => {
            if (m.wparam == @as(u16, @bitCast(COP_ID))) s.cop = g.newObject;
            return 1;
        },
        else => return 0,
    }
}

fn rightButtonUp(g: *Game, s: *State, m: Msg) i16 {
    if (g.itemSelected == 0) return 1;
    const bd = g.scene.?.backdrop.?;
    const q = backdrop.queryRect(g, bd, @as(i16, @bitCast(m.lo())) +% bd.originX, @as(i16, @bitCast(m.hi())) +% bd.originY, 0x10, 0x10);
    s.hitObject = q.obj;
    if (q.result < 1) {
        g.itemSelected = 0;
        g.selectedItem = null;
        return 1;
    }
    const hit = s.hitObject orelse return 1;
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
    if (hit.id != POST_ID and hit.id != COP_ID) {
        g.itemSelected = 0;
        g.selectedItem = null;
        return 1;
    }
    s.offerCount +%= 1;
    _ = ini.seekSection(&g.ini, g.plat, g.fixes, iniFd(g), cstr.slice(&g.scene.?.name), true) catch |e| @panic(@errorName(e));
    if (item.id == WALLET_ID) {
        s.rightItem = 1;
        s.waveVariant = 0;
        playWave(g, s.anthemWave);
    } else if (item.id == GIFT_ID) {
        s.giftFrame = ini.randomBelow(&g.rand, g.plat, 4);
        _ = frames.setCurFrame(item, @bitCast(s.giftFrame));
        s.waveVariant = s.giftFrame;
    }
    if (s.offerCount > 3 and s.rightItem != 1) {
        // Fourth wrong offer: the cop speaks his last line.
        copPlay(g, s);
        playWave(g, openWave(g, "fase2\\2fcopmau\\PMAUS07.WAV"));
        return 1;
    }
    // The INI's WAVE reply for (cop or post, variant, item).
    _ = ini.findWave(&g.ini, g.plat, g.fixes, iniFd(g), hit.id, s.waveVariant, item.id, &g.sound.cache, &g.ini.rec.nomeWave, &g.ini.rec.waveObject) catch |e| @panic(@errorName(e));
    s.waveVariant = s.unkA2BA;
    s.scanObject = g.scene.?.objects.head;
    while (s.scanObject) |o| {
        if (o.id == g.ini.rec.waveObject) break;
        s.scanObject = o.next;
    }
    const path = ini.assetPath(&g.ini, &g.driveCD, &g.driveHD, &g.ini.rec.nomeWave, -3);
    cstr.copy(&s.wavePath, path);
    copPlay(g, s);
    playWave(g, sound.open(g, cstr.slice(&s.wavePath)) catch null);
    return 0;
}

/// The wave that was playing (the cop's speech, the anthem, ...) ended.
fn womDone(g: *Game, s: *State) i16 {
    if (s.timedOut != 0) {
        resetState(s);
        update_list.discard(&g.updateList);
        arrest(g);
        return 1;
    }
    const item = g.selectedItem orelse return greeting(g, s);
    const hit = s.hitObject orelse return greeting(g, s);

    if (s.rightItem != 0) {
        // The wallet: score, the item is used up, on to the party.
        g.score +%= item.portable.scoreUse;
        visibility.hideAndInvalidate(g, item, 0, g.scene.?.backdrop.?);
        _ = object_list.remove(&g.globalObjects, item);
        draw_list.remove(&g.drawList, item.as(.object3d));
        _ = object_list.add(g, &g.usedObjects, item);
        resetState(s);
        animation.stopAndRedraw(g, s.cop.?, g.scene.?.backdrop.?);
        update_list.discard(&g.updateList);
        _ = game_scenes.switchScene(g, "2ffesta4", -0x96, 0xfa, 1, 0, 0, 0, 0);
        g.selectedItem = null;
        return 0;
    }

    // A wrong item: misuse score, it goes back to the player's inventory.
    g.score +%= item.portable.scoreMisuse;
    s.returnedItem = item;
    _ = portable.pickUp(g, item, g.player.?);
    frames.resetRects(item);
    visibility.hideAndInvalidate(g, item, 0, g.scene.?.backdrop.?);
    visibility.redrawOverlapping(g, item, g.scene.?.backdrop.?, 0);
    animation.stopAndRedraw(g, s.cop.?, g.scene.?.backdrop.?);
    occupancy.reoccupy(g, hit, g.scene.?.backdrop.?);
    const gift_fell = item.id == GIFT_ID and (s.giftFrame == 1 or s.giftFrame == 2 or s.giftFrame == 3);
    if (gift_fell or s.offerCount > 3) {
        resetState(s);
        update_list.discard(&g.updateList);
        arrest(g);
        // The gift case returns at once, leaving the item selected.
        if (gift_fell) return 1;
    }
    g.selectedItem = null;
    return 0;
}

/// MM_WOM_DONE with nothing offered: the cop's first speech ended (comment
/// on the gift or arrest), later ones just rest his animation.
fn greeting(g: *Game, s: *State) i16 {
    if (s.greetingPending != 0) {
        s.greetingPending = 0;
        if (s.hasGift != 0) {
            copPlay(g, s);
            playWave(g, openWave(g, "fase2\\2fcopmau\\PMAUS03.WAV"));
            s.hasGift = 0;
            return 0;
        }
        resetState(s);
        update_list.discard(&g.updateList);
        arrest(g);
        // The original then stops the animation of the cop it has just
        // deleted with the scene (a dangling object); skipped here.
        return 0;
    }
    animation.stopAndRedraw(g, s.cop.?, g.scene.?.backdrop.?);
    return 0;
}
