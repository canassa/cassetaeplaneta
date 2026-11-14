//! Port unit `handler_2fshardi` (handler). scene handler 1020:32b2.
//!
//! A dressing room: a singer with a German-sounding accent and her band
//! (waves STONES*.WAV). Items dropped on them (objects 0xb-0xd,
//! 0x21) get their WAVE reply and come back to the inventory with a score
//! penalty. The bible (item 0x30), or the gift package (item 0x6b) when its
//! random picture is not the fourth one, is the right answer and leads to
//! the party arrival (`2ffesta3`). Four wrong offers, or five seconds with an
//! empty inventory, send the player back to the street (`2fpontoc`); no life
//! is taken here.
//!
//! Timers: 0x15 (5 s, empty inventory) and 0x14 (5 s after the gift).
//! The original builds some WAVE paths wrong (BUGS.md: wave fallback), they
//! are kept as they are.

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
const render = @import("../behaviour/render.zig");
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

/// Object ids (INI Number): the hit targets and the animations.
const SSHAB_ID: u16 = 0xa;
const SSHAA_ID: u16 = 0xb;
const SSHAF_ID: u16 = 0xc;
const SSHAV_ID: u16 = 0xd;
const MOVS_ID: u16 = 0x21;
/// Item ids: the bible and the gift package.
const BIBLE_ID: i16 = 0x30;
const GIFT_ID: i16 = 0x6b;

const TIMER_EMPTY: u16 = 0x15;
const TIMER_GIFT: u16 = 0x14;

const wav_timeout = "fase2\\2shardi\\STONES07.wav";
const wav_bible = "fase2\\2shardi\\STONES02.wav";
const wav_gift = "fase2\\2shardi\\STONES04.wav";
/// Sic: no directory (the wave fallback finds it).
const wav_enough = "STONES07.wav";

/// Not in the original: an item released here that reaches the engine was
/// offered to a character (`game.handlerAnswersOffers`, B30's fix).
pub const answers_offers = true;

pub const State = struct {
    // @orig g_s2fshardiOfferCount
    offerCount: i16 = 0,
    // @orig g_s2fshardiRightItem
    rightItem: i16 = 0,
    // @orig g_s2fshardiGreeting
    greeting: i16 = 0,
    // @orig g_s2fshardiGiftPending
    giftPending: i16 = 0,
    // @orig g_s2fshardiWaveVariant
    waveVariant: i16 = 0,
    // @orig g_s2fshardiTimedOut
    timedOut: i16 = 0,
    // @orig g_s2fshardiUnkA4F8
    unkA4F8: i16 = 0,
    // @orig g_s2fshardiGiftFrame
    giftFrame: i16 = 0,
    // @orig g_s2fshardiHitObject
    hitObject: ?*Object = null,
    // @orig g_s2fshardiSshaf
    sshaf: ?*Object = null,
    // @orig g_s2fshardiSshaa
    sshaa: ?*Object = null,
    // @orig g_s2fshardiSshav
    sshav: ?*Object = null,
    // @orig g_s2fshardiSshab
    sshab: ?*Object = null,
    // @orig g_s2fshardiMovs
    movs: ?*Object = null,
    // @orig g_s2fshardiScanObject
    scanObject: ?*Object = null,
    // @orig g_s2fshardiReturnedItem
    returnedItem: ?*Object = null,
    // @orig g_s2fshardiWavePath
    wavePath: [256]u8 = @splat(0),
};

/// The original's unchecked pointers: a missing one is a crash there.
fn must(comptime T: type, p: ?*T) *T {
    return p orelse @panic("2fshardi: null pointer");
}

fn bdOf(g: *Game) *Backdrop {
    return must(Backdrop, must(Scene, g.scene).backdrop);
}

fn die(e: anyerror) noreturn {
    @panic(@errorName(e));
}

fn anim(o: ?*Object) *Object {
    return must(Object, must(Object, o).as(.animation));
}

fn playWave(g: *Game, path: []const u8) void {
    const w = sound.open(g, path) catch |e| die(e);
    _ = sound.play(g, msg.main_window, w);
}

fn playCdWave(g: *Game, rel: []const u8) void {
    playWave(g, ini.concatStrings(&g.concatBuf, &g.driveCD, rel));
}

/// The state reset of every way out of the scene (the callers differ in
/// whether `giftPending` and `timedOut` are cleared too).
fn resetOffers(s: *State) void {
    s.offerCount = 0;
    s.waveVariant = 0;
    s.unkA4F8 = 0;
    s.rightItem = 0;
    s.greeting = 0;
}

/// Stops the singer's animation and re-arms its system timer.
fn stopSinger(g: *Game, s: *State) void {
    const sf = must(Object, s.sshaf);
    animation.stopAndRedraw(g, sf, bdOf(g));
    const a = anim(sf);
    g.setSystemTimer(@bitCast(a.anim.timerId), @bitCast(a.anim.timerPeriod));
}

fn query(g: *Game, s: *State, m: Msg) i8 {
    const bd = bdOf(g);
    const q = backdrop.queryRect(g, bd, @as(i16, @bitCast(m.lo())) +% bd.originX, @as(i16, @bitCast(m.hi())) +% bd.originY, 16, 16);
    s.hitObject = q.obj;
    return q.result;
}

/// Gives the selected (wrongly offered) item back to the player and redraws it.
fn returnItem(g: *Game, s: *State) *Object {
    // The gift's 5 s timer can end after the selection was cleared (another
    // reply ended meanwhile): the original reads through NULL (BUGS.md B24).
    const sel = g.selectedItem orelse @panic("2fshardi: item returned with none selected (original GPF, BUGS.md B24)");
    const item = must(Object, sel.as(.portable));
    s.returnedItem = item;
    _ = portable.pickUp(g, item, must(Object, must(Object, g.player).as(.player)));
    return item;
}

fn leaveForStreet(g: *Game) void {
    update_list.discard(&g.updateList);
    _ = game_scenes.switchScene(g, "2fpontoc", 0xf0, 0x96, 1, 1, 0, 0, 0);
}

// @orig 1020:32b2 handler_2fshardi
pub fn handle(g: *Game, m: Msg) i16 {
    const s = g.sceneState(State);
    switch (m.id) {
        msg.wm.rbuttonup => return rightUp(g, s, m),
        msg.wm.timer => return onTimer(g, s, m.wparam),
        msg.wm.mousemove => {
            if (m.hi() < 0x169) return 0;
            return @intFromBool(s.rightItem != 0);
        },
        msg.wm.rbuttondown => {
            if (s.rightItem != 0) {
                g.itemSelected = 0;
                return 1;
            }
            if (query(g, s, m) < 1) return 0;
            const h = s.hitObject orelse return 0;
            const id: u16 = @bitCast(h.id);
            return @intFromBool(id == MOVS_ID or (id >= SSHAB_ID and id <= SSHAV_ID));
        },
        msg.wm.mm_wom_done => return waveDone(g, s),
        msg.noite.scene_started => {
            const bd = bdOf(g);
            tick.play(g, anim(s.sshaf), bd);
            tick.play(g, anim(s.sshav), bdOf(g));
            tick.play(g, anim(s.movs), bdOf(g));
            const player = must(Object, must(Object, g.player).as(.player));
            if (object_list.isEmpty(&player.actor.inventory)) {
                g.setTimer(TIMER_EMPTY, 5000);
                return 1;
            }
            s.greeting = 1;
            _ = sound.play(g, msg.main_window, must(Object, s.sshaf).wave);
            return 0;
        },
        msg.noite.animation_finished => {
            if (m.wparam != SSHAA_ID) return 0;
            resetOffers(s);
            update_list.discard(&g.updateList);
            _ = game_scenes.switchScene(g, "2ffesta3", -0x96, 0xfa, 1, 0, 0, 0, 0);
            return 1;
        },
        msg.noite.object_created => {
            switch (m.wparam) {
                MOVS_ID => s.movs = g.newObject,
                SSHAB_ID => s.sshab = g.newObject,
                SSHAA_ID => s.sshaa = g.newObject,
                SSHAF_ID => s.sshaf = g.newObject,
                SSHAV_ID => s.sshav = g.newObject,
                else => {},
            }
            return 1;
        },
        else => return 0,
    }
}

fn onTimer(g: *Game, s: *State, id: u16) i16 {
    if (id == TIMER_EMPTY) {
        g.killTimer(TIMER_EMPTY);
        tick.play(g, anim(s.sshaf), bdOf(g));
        playCdWave(g, wav_timeout);
        s.timedOut = 1;
        return 1;
    }
    if (id != TIMER_GIFT) return 1;
    g.killTimer(TIMER_GIFT);
    // The gift's reaction is over: the item comes back.
    const bd = bdOf(g);
    const item = returnItem(g, s);
    frames.resetRects(item);
    visibility.hideAndInvalidate(g, item, 0, bd);
    visibility.redrawOverlapping(g, item, bdOf(g), 0);
    render.draw(g, item, bdOf(g));
    _ = visibility.invalidate(g, item);
    if (s.giftFrame == 3) return 1;
    const sb = must(Object, s.sshab);
    frames.resetRects(sb);
    visibility.hideAndInvalidate(g, sb, 0, bdOf(g));
    visibility.redraw(g, sb, bdOf(g));
    _ = visibility.invalidate(g, sb);
    _ = frames.setCurFrame(sb, 1);
    frames.resetRects(sb);
    visibility.redraw(g, sb, bdOf(g));
    _ = visibility.invalidate(g, sb);
    return 1;
}

fn clearSelection(g: *Game) i16 {
    g.itemSelected = 0;
    g.selectedItem = null;
    return 1;
}

fn rightUp(g: *Game, s: *State, m: Msg) i16 {
    if (g.itemSelected == 0 or s.giftPending != 0) return clearSelection(g);
    s.greeting = 0;
    if (query(g, s, m) < 1) return clearSelection(g);
    const hit = s.hitObject orelse return clearSelection(g);
    const sf = must(Object, s.sshaf);
    if (animation.isRunning(g, sf)) {
        stopSinger(g, s);
        sound.stop(&g.sound, g.plat, sf.wave);
    }
    const id: u16 = @bitCast(hit.id);
    if (id != SSHAF_ID and id != SSHAA_ID and id != SSHAV_ID and id != MOVS_ID) return clearSelection(g);
    return offer(g, s, hit);
}

/// An item was dropped on the band.
fn offer(g: *Game, s: *State, hit: *Object) i16 {
    s.offerCount +%= 1;
    const fd = g.iniFile;
    const name = cstr.slice(&g.curSceneName);
    _ = ini.seekSection(&g.ini, g.plat, g.fixes, fd, name, true) catch |e| die(e);
    const item = must(Object, g.selectedItem);
    if (item.id == BIBLE_ID) {
        s.waveVariant = 0;
        s.rightItem = 1;
        tick.play(g, anim(s.sshaf), bdOf(g));
        playCdWave(g, wav_bible);
        return 0;
    }
    if (item.id == GIFT_ID) {
        s.giftFrame = ini.randomBelow(&g.rand, g.plat, 4);
        s.rightItem = 1;
        if (s.giftFrame == 1) s.giftFrame = 2;
        _ = frames.setCurFrame(item, @bitCast(s.giftFrame));
        s.waveVariant = s.giftFrame;
        g.setTimer(TIMER_GIFT, 5000);
        s.giftPending = 1;
        if (s.giftFrame == 3) {
            tick.play(g, anim(s.sshaf), bdOf(g));
            playCdWave(g, wav_gift);
            return 0;
        }
    }
    if (s.offerCount > 3 and s.rightItem != 1) {
        // The fourth wrong offer: the item comes back, the band reacts.
        const bd = bdOf(g);
        const ret = returnItem(g, s);
        frames.resetRects(ret);
        visibility.hideAndInvalidate(g, ret, 0, bd);
        visibility.redrawOverlapping(g, ret, bdOf(g), 0);
        tick.play(g, anim(s.sshaf), bdOf(g));
        playCdWave(g, wav_enough);
        occupancy.reoccupy(g, hit, bdOf(g));
        return 1;
    }
    _ = ini.seekSection(&g.ini, g.plat, g.fixes, fd, name, true) catch |e| die(e);
    _ = ini.findWave(&g.ini, g.plat, g.fixes, fd, 0xd, s.waveVariant, item.id, &g.sound.cache, &g.ini.rec.nomeWave, &g.ini.rec.waveObject) catch |e| die(e);
    s.waveVariant = s.unkA4F8;
    s.scanObject = must(Scene, g.scene).objects.head;
    while (s.scanObject) |o| {
        if (o.id == g.ini.rec.waveObject) break;
        s.scanObject = o.next;
    }
    const p = ini.assetPath(&g.ini, &g.driveCD, &g.driveHD, &g.ini.rec.nomeWave, -3);
    cstr.copy(&s.wavePath, p);
    tick.play(g, anim(s.sshaf), bdOf(g));
    playWave(g, &s.wavePath);
    return 0;
}

fn waveDone(g: *Game, s: *State) i16 {
    if (s.greeting != 0) {
        s.greeting = 0;
        stopSinger(g, s);
        return 1;
    }
    if (s.timedOut != 0) {
        resetOffers(s);
        s.giftPending = 0;
        s.timedOut = 0;
        leaveForStreet(g);
        return 1;
    }
    if (s.rightItem != 0) return rightWaveDone(g, s);
    // A wrong offer: the item goes back to the player's inventory.
    if (s.hitObject != null) {
        const bd = bdOf(g);
        g.score +%= must(Object, g.selectedItem).portable.scoreMisuse;
        const ret = returnItem(g, s);
        frames.resetRects(ret);
        visibility.hideAndInvalidate(g, ret, 0, bd);
        visibility.redrawOverlapping(g, ret, bdOf(g), 0);
        stopSinger(g, s);
        occupancy.reoccupy(g, must(Object, s.hitObject), bdOf(g));
        g.selectedItem = null;
    }
    if (s.offerCount <= 3) return 0;
    resetOffers(s);
    s.giftPending = 0;
    leaveForStreet(g);
    return 0;
}

/// The wave end after the right item was offered: it is scored and consumed,
/// then the party arrival follows (the gift's trick pictures stay here).
fn rightWaveDone(g: *Game, s: *State) i16 {
    const bd = bdOf(g);
    // BUGS.md B20: 2sshaa's wave is not on the disc, so its play below posts
    // MM_WOM_DONE at once and this runs again, for ever (posted messages
    // starve the timer that would end 2sshaa's animation).
    if (g.fixes.shardi_reply_once) if (g.selectedItem) |item| {
        if (object_list.contains(&g.usedObjects, item)) return 1;
    };
    if (g.selectedItem) |item| {
        g.score +%= item.portable.scoreUse;
        visibility.hideAndInvalidate(g, item, 0, bd);
        _ = object_list.remove(&g.globalObjects, item);
        draw_list.remove(&g.drawList, item);
        _ = object_list.add(g, &g.usedObjects, item);
    }
    stopSinger(g, s);
    const sf = must(Object, s.sshaf);
    frames.resetRects(sf);
    visibility.hideAndInvalidate(g, sf, 0, bdOf(g));
    visibility.redrawOverlapping(g, sf, bdOf(g), 0);
    if (must(Object, g.selectedItem).id != GIFT_ID and s.giftFrame != 3) {
        animation.playOnce(g, anim(s.sshaa), bdOf(g));
        _ = sound.play(g, msg.main_window, must(Object, s.sshaa).wave);
        return 1;
    }
    resetOffers(s);
    update_list.discard(&g.updateList);
    _ = game_scenes.switchScene(g, "2ffesta3", -0x96, 0xfa, 1, 0, 0, 0, 0);
    return 1;
}
