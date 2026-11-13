//! Port unit `handler_2fportdi` (handler). scene handler 1020:4306.
//!
//! The party doorman. A background track loops; items dropped on the
//! doorman or his helpers (objects 0x15 to 0x19) get their WAVE reply and come
//! back to the inventory with a score penalty. The wine (item 0x56) is the
//! right one: the doorman drinks it, the item is scored and consumed and the
//! barber cutscene (`2abarbei`) follows. The fourth wrong offer moves the
//! player to the doorman's second scene (`2fportd2`).

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

/// INI Numbers of the scene's objects.
const BUSF_ID: i16 = 0x15;
const DRINKING_ID: i16 = 0x16;
const DOORMAN_ID: i16 = 0x17;
const MOVS_ID: i16 = 0x18;
const SSHAV_ID: i16 = 0x19;
const SUSTO_ID: i16 = 0x20;
const SSPOB_ID: i16 = 0x122;
/// The item that is the right answer (the wine).
const RIGHT_ITEM_ID: i16 = 0x56;

const loop_wav = "fase2\\2fportdi\\TERRIN5.WAV";
const angry_wav = "fase2\\2fportdi\\PORTGR01.WAV";

pub const State = struct {
    // @orig g_s2fportdiOfferCount
    offerCount: i16 = 0,
    // @orig g_s2fportdiRightItem
    rightItem: i16 = 0,
    // @orig g_s2fportdiWaveVariant
    waveVariant: i16 = 0,
    // @orig g_s2fportdiUnkA628 (only ever written 0)
    unkA628: i16 = 0,
    // @orig g_s2fportdiHitObject
    hitObject: ?*Object = null,
    // @orig g_s2fportdiDoorman
    doorman: ?*Object = null,
    // @orig g_s2fportdiDrinking
    drinking: ?*Object = null,
    // @orig g_s2fportdiSshav
    sshav: ?*Object = null,
    // @orig g_s2fportdiSspob
    sspob: ?*Object = null,
    // @orig g_s2fportdiMovs
    movs: ?*Object = null,
    // @orig g_s2fportdiSusto
    susto: ?*Object = null,
    // @orig g_s2fportdiBusf
    busf: ?*Object = null,
    // @orig g_s2fportdiScanObject
    scanObject: ?*Object = null,
    // @orig g_s2fportdiReturnedItem
    returnedItem: ?*Object = null,
    // @orig g_s2fportdiWavePath
    wavePath: [256]u8 = @splat(0),
};

/// The original's unchecked pointers: a missing one is a crash there.
fn must(comptime T: type, p: ?*T) *T {
    return p orelse @panic("2fportdi: null pointer");
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

fn animOf(o: ?*Object) *Object {
    return must(Object, must(Object, o).as(.animation));
}

/// Starts the object's animation looping (SceneObject slot `play` of its
/// Animation view).
fn playAnim(g: *Game, o: ?*Object) void {
    tick.play(g, animOf(o), bdOf(g));
}

/// SetSystemTimer with the doorman animation's timer id and period.
fn restartDoormanTimer(g: *Game, s: *State) void {
    const a = animOf(s.doorman);
    g.setSystemTimer(@bitCast(a.anim.timerId), @bitCast(a.anim.timerPeriod));
}

/// Stops the doorman's animation and restarts its timer.
fn stopDoorman(g: *Game, s: *State) void {
    animation.stopAndRedraw(g, must(Object, s.doorman), bdOf(g));
    restartDoormanTimer(g, s);
}

/// Picks the object under the cursor into `s.hitObject`; returns the grid
/// query's result.
fn query(g: *Game, s: *State, m: Msg) i8 {
    const bd = bdOf(g);
    const q = backdrop.queryRect(g, bd, @as(i16, @bitCast(m.lo())) +% bd.originX, @as(i16, @bitCast(m.hi())) +% bd.originY, 16, 16);
    s.hitObject = q.obj;
    return q.result;
}

/// Hides an object and redraws what it overlapped (after its rectangles are
/// reset).
fn hideAndRedraw(g: *Game, o: ?*Object) void {
    const obj = must(Object, o);
    const bd = bdOf(g);
    frames.resetRects(obj);
    visibility.hideAndInvalidate(g, obj, 0, bd);
    visibility.redrawOverlapping(g, obj, bd, 0);
}

fn showAndInvalidate(g: *Game, o: ?*Object) void {
    const obj = must(Object, o);
    visibility.show(g, obj, bdOf(g));
    _ = visibility.invalidate(g, obj);
}

fn resetOffers(s: *State) void {
    s.offerCount = 0;
    s.waveVariant = 0;
    s.unkA628 = 0;
    s.rightItem = 0;
}

/// Gives the selected item back to the player's inventory.
fn takeItemBack(g: *Game, s: *State) void {
    const item = must(Object, g.selectedItem).as(.portable) orelse @panic("2fportdi: asPortable returned NULL");
    s.returnedItem = item;
    _ = portable.pickUp(g, item, must(Object, must(Object, g.player).as(.player)));
}

// @orig 1020:4306 handler_2fportdi
pub fn handle(g: *Game, m: Msg) i16 {
    const s = g.sceneState(State);
    switch (m.id) {
        msg.wm.rbuttondown => {
            if (s.rightItem != 0) {
                g.itemSelected = 0;
                return 1;
            }
            if (query(g, s, m) <= 0) return 0;
            const h = s.hitObject orelse return 0;
            return switch (h.id) {
                BUSF_ID, DRINKING_ID, DOORMAN_ID, MOVS_ID, SSHAV_ID, SUSTO_ID, SSPOB_ID => 1,
                else => 0,
            };
        },
        msg.wm.rbuttonup => {
            if (g.itemSelected == 0) return 1;
            if (query(g, s, m) <= 0 or s.hitObject == null) {
                g.itemSelected = 0;
                g.selectedItem = null;
                return 1;
            }
            const doorman = must(Object, s.doorman);
            if (animation.isRunning(g, doorman)) {
                // The doorman is still talking: cut him off, the item goes back.
                stopDoorman(g, s);
                takeItemBack(g, s);
                sound.stop(&g.sound, g.plat, doorman.wave);
            }
            const hit = must(Object, s.hitObject);
            if (hit.id != DOORMAN_ID and hit.id != SSHAV_ID and hit.id != BUSF_ID and hit.id != MOVS_ID) {
                g.itemSelected = 0;
                g.selectedItem = null;
                return 1;
            }
            s.offerCount +%= 1;
            const fd = iniFd(g);
            const name = cstr.slice(&g.curSceneName);
            _ = ini.seekSection(&g.ini, g.plat, g.fixes, fd, name, true) catch |e| die(e);
            const item = must(Object, g.selectedItem);
            if (item.id == RIGHT_ITEM_ID) {
                s.waveVariant = 0;
                s.rightItem = 1;
                hideAndRedraw(g, s.doorman);
                animation.stopAndRedraw(g, doorman, bdOf(g));
                hideAndRedraw(g, s.sshav);
                animation.stopAndRedraw(g, must(Object, s.sshav), bdOf(g));
                hideAndRedraw(g, s.busf);
                showAndInvalidate(g, s.drinking);
                showAndInvalidate(g, s.sspob);
                playAnim(g, s.drinking);
                playAnim(g, s.sspob);
                _ = sound.play(g, msg.main_window, must(Object, s.drinking).wave);
            } else if (s.offerCount < 4) {
                _ = ini.seekSection(&g.ini, g.plat, g.fixes, fd, name, true) catch |e| die(e);
                _ = ini.findWave(&g.ini, g.plat, g.fixes, fd, DOORMAN_ID, s.waveVariant, item.id, &g.sound.cache, &g.ini.rec.nomeWave, &g.ini.rec.waveObject) catch |e| die(e);
                s.waveVariant = s.unkA628;
                s.scanObject = object_list.findById(&must(Scene, g.scene).objects, g.ini.rec.waveObject);
                const p = ini.assetPath(&g.ini, &g.driveCD, &g.driveHD, &g.ini.rec.nomeWave, -3);
                cstr.copy(&s.wavePath, p);
                playAnim(g, s.doorman);
                playWave(g, &s.wavePath);
            } else {
                playAnim(g, s.doorman);
                playWave(g, ini.concatStrings(&g.concatBuf, &g.driveCD, angry_wav));
            }
            return 0;
        },
        msg.wm.mm_wom_done => {
            if (g.selectedItem == null) {
                animation.stopAndRedraw(g, must(Object, s.doorman), bdOf(g));
                restartDoormanTimer(g, s);
                return 1;
            }
            const bd = bdOf(g);
            if (s.rightItem != 0) {
                const item = must(Object, g.selectedItem);
                g.score +%= item.portable.scoreUse;
                visibility.hideAndInvalidate(g, item, 0, bd);
                _ = object_list.remove(&g.globalObjects, item);
                draw_list.remove(&g.drawList, item);
                _ = object_list.add(g, &g.usedObjects, item);
                animation.stopAndRedraw(g, must(Object, s.drinking), bd);
                animation.stopAndRedraw(g, must(Object, s.sspob), bd);
                restartDoormanTimer(g, s);
                resetOffers(s);
                sound.stop(&g.sound, g.plat, null);
                update_list.discard(&g.updateList);
                _ = game_scenes.switchScene(g, "2abarbei", 0, 0, 0, 0, 0, 1, 0);
                return 1;
            }
            if (s.hitObject) |h| {
                // A wrong offer: penalty, the item goes back to the inventory.
                const item = must(Object, g.selectedItem);
                g.score +%= item.portable.scoreMisuse;
                takeItemBack(g, s);
                const ret = must(Object, s.returnedItem);
                frames.resetRects(ret);
                visibility.hideAndInvalidate(g, ret, 0, bd);
                visibility.redrawOverlapping(g, ret, bd, 0);
                stopDoorman(g, s);
                occupancy.reoccupy(g, h, bd);
            }
            g.selectedItem = null;
            if (s.offerCount < 4) return 0;
            resetOffers(s);
            update_list.discard(&g.updateList);
            _ = game_scenes.switchScene(g, "2fportd2", 0, 0, 0, 1, 0, 0, 0);
            return 1;
        },
        msg.noite.scene_started => {
            _ = g.plat.mciString("stop musica");
            const w = sound.open(g, ini.concatStrings(&g.concatBuf, &g.driveCD, loop_wav)) catch |e| die(e);
            _ = sound.playLoop(g, msg.main_window, w);
            playAnim(g, s.doorman);
            playAnim(g, s.sshav);
            playAnim(g, s.movs);
            showAndInvalidate(g, s.busf);
            _ = sound.play(g, msg.main_window, must(Object, s.doorman).wave);
            return 1;
        },
        msg.noite.object_created => {
            switch (@as(i16, @bitCast(m.wparam))) {
                BUSF_ID => s.busf = g.newObject,
                DRINKING_ID => {
                    s.drinking = g.newObject;
                    hideAndRedraw(g, s.drinking);
                },
                DOORMAN_ID => s.doorman = g.newObject,
                MOVS_ID => s.movs = g.newObject,
                SSHAV_ID => s.sshav = g.newObject,
                SUSTO_ID => s.susto = g.newObject,
                SSPOB_ID => {
                    s.sspob = g.newObject;
                    hideAndRedraw(g, s.sspob);
                },
                else => {},
            }
            return 1;
        },
        else => return 0,
    }
}
