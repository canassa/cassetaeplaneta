//! Port unit `handler_2fportd2` (handler). scene handler 1020:505c.
//!
//! The doorman's second chance. When the scene starts the music pauses, a
//! track loops and the boy, then the doorman, then the radio speak in turn
//! (each WAVE's MM_WOM_DONE starts the next). Items dropped on the doorman
//! (object 0x17, also 0x26 and 0x19) get their WAVE reply; the wallet (item
//! 0x47) is right and leads to the party arrival (`2ffesta3`); a fourth wrong
//! offer, or an item left on the doorman after the speeches, goes back to
//! the street (`2fpontoc`). Dropping an item while the speeches run cuts
//! them off (the radio wave stays non-null, as in the original).

const Game = @import("../core/game.zig").Game;
const Msg = @import("../core/msg.zig").Msg;
const msg = @import("../core/msg.zig");
const Object = @import("../core/object.zig").Object;
const world = @import("../core/world.zig");
const Backdrop = world.Backdrop;
const Scene = world.Scene;
const Wave = @import("../platform/platform.zig").Wave;
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

/// INI Numbers: the boy, the doorman, the bus (the doorman is also the
/// drop target, with 0x26 and 0x19).
const BOY_ID: i16 = 0x27;
const DOORMAN_ID: i16 = 0x17;
const BUSF_ID: i16 = 0x26;
const DOORMAN_ID2: i16 = 0x19;
/// The right item (the wallet).
const RIGHT_ITEM_ID: i16 = 0x47;

const music_wav = "fase2\\2fportdi\\terrin5.wav";
const radio_wav = "fase2\\2fportdi\\RADIOS01.WAV";

/// Not in the original: an item released here that reaches the engine was
/// offered to a character (`game.handlerAnswersOffers`, B30's fix).
pub const answers_offers = true;

pub const State = struct {
    // @orig g_s2fportd2OfferCount
    offerCount: i16 = 0,
    // @orig g_s2fportd2RightItem
    rightItem: i16 = 0,
    // @orig g_s2fportd2WaveVariant
    waveVariant: i16 = 0,
    // @orig g_s2fportd2DoormanTurn
    doormanTurn: i16 = 0,
    // @orig g_s2fportd2BoyTurn
    boyTurn: i16 = 0,
    // @orig g_s2fportd2RadioWave
    radioWave: ?Wave = null,
    // @orig g_s2fportd2HitObject
    hitObject: ?*Object = null,
    // @orig g_s2fportd2Busf
    busf: ?*Object = null,
    // @orig g_s2fportd2Doorman
    doorman: ?*Object = null,
    // @orig g_s2fportd2Boy
    boy: ?*Object = null,
    // @orig g_s2fportd2ScanObject
    scanObject: ?*Object = null,
    // @orig g_s2fportd2ReturnedItem
    returnedItem: ?*Object = null,
    // @orig g_s2fportd2WavePath
    wavePath: [256]u8 = @splat(0),
    // @orig g_s2fportd2UnkA744 (only ever reset)
    unkA744: i16 = 0,
    // @orig g_s2fportd2MusicWave + g_scene2fportd2_A74A (offset/segment)
    musicWave: ?Wave = null,
};

/// The original's unchecked pointers: a missing one is a crash there.
fn must(comptime T: type, p: ?*T) *T {
    return p orelse @panic("2fportd2: null pointer");
}

fn bdOf(g: *Game) *Backdrop {
    return must(Backdrop, must(Scene, g.scene).backdrop);
}

fn die(e: anyerror) noreturn {
    @panic(@errorName(e));
}

fn playWave(g: *Game, path: []const u8) ?Wave {
    const w = sound.open(g, path) catch |e| die(e);
    _ = sound.play(g, msg.main_window, w);
    return w;
}

/// Re-arms the animation's own system timer (what the original does after
/// stopping it).
fn rearmTimer(g: *Game, obj: *Object) void {
    const a = must(Object, obj.as(.animation));
    g.setSystemTimer(@bitCast(a.anim.timerId), @bitCast(a.anim.timerPeriod));
}

/// Picks the object under the cursor into `s.hitObject`; returns the grid
/// query's result.
fn query(g: *Game, s: *State, m: Msg) i8 {
    const bd = bdOf(g);
    const q = backdrop.queryRect(g, bd, @as(i16, @bitCast(m.lo())) +% bd.originX, @as(i16, @bitCast(m.hi())) +% bd.originY, 16, 16);
    s.hitObject = q.obj;
    return q.result;
}

fn resetOffers(g: *Game, s: *State) void {
    s.offerCount = 0;
    s.waveVariant = 0;
    s.unkA744 = 0;
    s.rightItem = 0;
    s.doormanTurn = 0;
    s.boyTurn = 0;
    g.itemSelected = 0;
}

/// Back to the street (`2fpontoc`).
fn toStreet(g: *Game) void {
    _ = game_scenes.switchScene(g, "2fpontoc", 0xf0, 0xfa, 1, 1, 0, 0, 0);
}

// @orig 1020:505c handler_2fportd2
pub fn handle(g: *Game, m: Msg) i16 {
    const s = g.sceneState(State);
    switch (m.id) {
        msg.wm.rbuttondown => {
            if (query(g, s, m) <= 0) return 0;
            const h = s.hitObject orelse return 0;
            if (h.id == BOY_ID or h.id == DOORMAN_ID or h.id == BUSF_ID) return 1;
            return 0;
        },
        msg.wm.rbuttonup => return rbuttonUp(g, s, m),
        msg.wm.mm_wom_done => return womDone(g, s),
        msg.noite.scene_started => {
            _ = g.plat.mciString("pause musica");
            const path = ini.concatStrings(&g.concatBuf, &g.driveCD, music_wav);
            s.musicWave = sound.open(g, path) catch |e| die(e);
            _ = sound.playLoop(g, msg.main_window, s.musicWave);
            s.boyTurn = 1;
            s.doormanTurn = 1;
            const boy = must(Object, s.boy);
            tick.play(g, must(Object, boy.as(.animation)), bdOf(g));
            _ = sound.play(g, msg.main_window, boy.wave);
            return 1;
        },
        msg.noite.object_created => {
            switch (m.wparam) {
                @as(u16, @bitCast(BOY_ID)) => s.boy = g.newObject,
                @as(u16, @bitCast(DOORMAN_ID)) => s.doorman = g.newObject,
                @as(u16, @bitCast(BUSF_ID)) => s.busf = g.newObject,
                else => {},
            }
            return 0;
        },
        else => return 0,
    }
}

fn rbuttonUp(g: *Game, s: *State, m: Msg) i16 {
    if (g.itemSelected == 0) return 0;
    if (query(g, s, m) <= 0) {
        g.itemSelected = 0;
        g.selectedItem = null;
        return 0;
    }
    const hit = s.hitObject orelse return 0;
    const bd = bdOf(g);
    const boy = must(Object, s.boy);
    const doorman = must(Object, s.doorman);
    if (animation.isRunning(g, boy) or s.radioWave != null or animation.isRunning(g, doorman)) {
        // An offer cuts the speeches off.
        animation.stopAndRedraw(g, boy, bd);
        animation.stopAndRedraw(g, doorman, bd);
        rearmTimer(g, boy);
        sound.stop(&g.sound, g.plat, boy.wave);
        sound.stop(&g.sound, g.plat, doorman.wave);
        sound.stop(&g.sound, g.plat, s.radioWave);
        s.doormanTurn = 0;
        s.boyTurn = 0;
    }
    if (hit.id != BUSF_ID and hit.id != DOORMAN_ID and hit.id != DOORMAN_ID2) {
        g.itemSelected = 0;
        g.selectedItem = null;
        return 0;
    }
    s.offerCount +%= 1;
    const fd = g.iniFile;
    const name = cstr.slice(&g.curSceneName);
    _ = ini.seekSection(&g.ini, g.plat, g.fixes, fd, name, true) catch |e| die(e);
    const item = must(Object, g.selectedItem);
    if (item.id == RIGHT_ITEM_ID) {
        // The wallet: scored and consumed, on to the party arrival.
        resetOffers(g, s);
        s.radioWave = null;
        g.score +%= item.portable.scoreUse;
        visibility.hideAndInvalidate(g, item, 0, bd);
        _ = object_list.remove(&g.globalObjects, item);
        draw_list.remove(&g.drawList, item);
        _ = object_list.add(g, &g.usedObjects, item);
        occupancy.reoccupy(g, hit, bd);
        g.selectedItem = null;
        _ = g.plat.mciString("play musica");
        update_list.discard(&g.updateList);
        _ = game_scenes.switchScene(g, "2ffesta3", -150, 0xfa, 1, 0, 0, 0, 0);
        return 1;
    }
    if (s.offerCount >= 4 and s.rightItem != 1) {
        resetOffers(g, s);
        update_list.discard(&g.updateList);
        toStreet(g);
        return 0;
    }
    // A wrong offer: the doorman answers with the item's WAVE reply.
    _ = ini.seekSection(&g.ini, g.plat, g.fixes, fd, name, true) catch |e| die(e);
    _ = ini.findWave(&g.ini, g.plat, g.fixes, fd, DOORMAN_ID, s.waveVariant, item.id, &g.sound.cache, &g.ini.rec.nomeWave, &g.ini.rec.waveObject) catch |e| die(e);
    s.waveVariant = s.unkA744;
    s.scanObject = must(Scene, g.scene).objects.head;
    while (s.scanObject) |o| {
        if (o.id == g.ini.rec.waveObject) break;
        s.scanObject = o.next;
    }
    const p = ini.assetPath(&g.ini, &g.driveCD, &g.driveHD, &g.ini.rec.nomeWave, -3);
    cstr.copy(&s.wavePath, p);
    tick.play(g, must(Object, doorman.as(.animation)), bd);
    _ = playWave(g, &s.wavePath);
    return 0;
}

/// MM_WOM_DONE: the boy's wave ends and the doorman speaks; then the radio;
/// after that a returned item is given back (and a spent offer sends the
/// player to the street).
fn womDone(g: *Game, s: *State) i16 {
    const bd = bdOf(g);
    if (s.boyTurn != 0) {
        const boy = must(Object, s.boy);
        animation.stopAndRedraw(g, boy, bd);
        rearmTimer(g, boy);
        _ = frames.setCurFrame(must(Object, boy.as(.animation)), 1);
        s.boyTurn = 0;
        const doorman = must(Object, s.doorman);
        tick.play(g, must(Object, doorman.as(.animation)), bd);
        _ = sound.play(g, msg.main_window, doorman.wave);
        s.doormanTurn = 1;
        return 0;
    }
    if (s.doormanTurn != 0) {
        animation.stopAndRedraw(g, must(Object, s.doorman), bd);
        const path = ini.concatStrings(&g.concatBuf, &g.driveCD, radio_wav);
        s.radioWave = sound.open(g, path) catch |e| die(e);
        _ = sound.play(g, msg.main_window, s.radioWave);
        s.doormanTurn = 0;
        return 0;
    }
    if (g.selectedItem != null and s.hitObject != null) {
        // The item is handed back with a score penalty.
        const sel = must(Object, g.selectedItem);
        g.score +%= sel.portable.scoreMisuse;
        const item = sel.as(.portable) orelse @panic("2fportd2: asPortable returned NULL");
        s.returnedItem = item;
        _ = portable.pickUp(g, item, must(Object, must(Object, g.player).as(.player)));
        frames.resetRects(item);
        visibility.hideAndInvalidate(g, item, 0, bd);
        visibility.redrawOverlapping(g, item, bd, 0);
        const doorman = must(Object, s.doorman);
        animation.stopAndRedraw(g, doorman, bd);
        rearmTimer(g, doorman);
        occupancy.reoccupy(g, must(Object, s.hitObject), bd);
        g.selectedItem = null;
    }
    if (s.offerCount < 1) return 0;
    resetOffers(g, s);
    update_list.discard(&g.updateList);
    s.radioWave = null;
    toStreet(g);
    return 0;
}
