//! Port unit `handler_2fgaydir` (handler). scene handler 1020:5a90.
//!
//! The gay club. The host (`sgayf`) makes a speech when the scene starts;
//! the club people (`sgayc`/`sgayd`, the waiter `suaboy`, the shaver `sshav`)
//! are the drop targets for inventory items. Items dropped on them get a
//! WAVE reply from the INI and come back to the inventory; the third wrong
//! offer plays a special reaction, the fourth (or five seconds with an empty
//! inventory) sends the player back to the street (`2fpontoc`). The shirt
//! (item 0x45) triggers the chain of reactions that ends in the party
//! arrival (`2ffesta3`), the present (item 0x62) plays the vibrator
//! animation and ends there too. The control panel is blocked during the
//! intro (`panelAllowed`, `panelClickAllowed`).

const Game = @import("../core/game.zig").Game;
const Msg = @import("../core/msg.zig").Msg;
const msg = @import("../core/msg.zig");
const Object = @import("../core/object.zig").Object;
const world = @import("../core/world.zig");
const Backdrop = world.Backdrop;
const Scene = world.Scene;
const cstr = @import("../core/cstr.zig");
const animation = @import("../behaviour/animation.zig");
const render = @import("../behaviour/render.zig");
const tick = @import("../behaviour/tick.zig");
const visibility = @import("../behaviour/visibility.zig");
const backdrop = @import("../backdrop.zig");
const draw_list = @import("../draw_list.zig");
const frames = @import("../frames.zig");
const game_scenes = @import("../game_scenes.zig");
const ini = @import("../ini.zig");
const object_list = @import("../object_list.zig");
const occupancy = @import("../behaviour/occupancy.zig");
const panels = @import("../panels.zig");
const portable = @import("../portable.zig");
const sound = @import("../sound.zig");
const update_list = @import("../update_list.zig");

// INI object numbers (`[2fgaydir]` Number=).
const SGAYC_ID: u16 = 0x0e; // club people: reaction animation
const SGAYD_ID: u16 = 0x0f; // club people: frame holder (0 / 1 / 2)
const SGAYF_ID: u16 = 0x10; // host
const SGAYA_ID: u16 = 0x22;
const MOVS_ID: u16 = 0x23;
const SSHAV_ID: u16 = 0x25;
const VIBRATOR_ID: u16 = 0x2b;
const SUABOY_ID: u16 = 0x10c;
/// Items: the shirt and the present.
const SHIRT_ITEM_ID: i16 = 0x45;
const PRESENT_ITEM_ID: i16 = 0x62;
/// The five-second empty-inventory timer.
const TIMER_ID: u16 = 0x15;
/// Mouse y from which the control panel starts.
const PANEL_Y: u16 = 0x168;

const wav_boiolr01 = "fase2\\2fgaytdir\\boiolr01.wav";
const wav_boiolr02 = "fase2\\2fgaytdir\\boiolr02.wav";
const wav_boiolr05 = "fase2\\2fgaytdir\\boiolr05.wav";
const wav_boiols03 = "fase2\\2fgaytdir\\boiols03.wav";

/// Not in the original: an item released here that reaches the engine was
/// offered to a character (`game.handlerAnswersOffers`, B30's fix).
pub const answers_offers = true;

pub const State = struct {
    // @orig g_s2fgaydirWaveVariant
    waveVariant: i16 = 0,
    // @orig g_s2fgaydirShirtTaken
    shirtTaken: i16 = 0,
    // @orig g_s2fgaydirIntro
    intro: i16 = 0,
    // @orig g_s2fgaydirTimedOut
    timedOut: i16 = 0,
    // @orig g_s2fgaydirHasPresent
    hasPresent: i16 = 0,
    // @orig g_s2fgaydirRemark
    remark: i16 = 0,
    // @orig g_s2fgaydirFinished
    finished: i16 = 0,
    // @orig g_s2fgaydirPanelAllowed
    panelAllowed: i16 = 0,
    // @orig g_s2fgaydirPanelClickAllowed
    panelClickAllowed: i16 = 1,
    // @orig g_s2fgaydirOfferCount
    offerCount: i16 = 0,
    // @orig g_s2fgaydirPresentGiven
    presentGiven: i16 = 0,
    // @orig g_s2fgaydirHitObject
    hitObject: ?*Object = null,
    // @orig g_s2fgaydirSgayf
    sgayf: ?*Object = null,
    // @orig g_s2fgaydirSgayc
    sgayc: ?*Object = null,
    // @orig g_s2fgaydirSshav
    sshav: ?*Object = null,
    // @orig g_s2fgaydirSgayd
    sgayd: ?*Object = null,
    // @orig g_s2fgaydirMovs
    movs: ?*Object = null,
    // @orig g_s2fgaydirSgaya
    sgaya: ?*Object = null,
    // @orig g_s2fgaydirVibrator
    vibrator: ?*Object = null,
    // @orig g_s2fgaydirSuaboy
    suaboy: ?*Object = null,
    // @orig g_s2fgaydirScanObject
    scanObject: ?*Object = null,
    // @orig g_s2fgaydirReturnedItem
    returnedItem: ?*Object = null,
    // @orig g_s2fgaydirWavePath
    wavePath: [256]u8 = @splat(0),
};

/// The original's unchecked pointers: a missing one is a crash there.
fn must(comptime T: type, p: ?*T) *T {
    return p orelse @panic("2fgaydir: null pointer");
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

fn playBundled(g: *Game, name: []const u8) void {
    playWave(g, ini.concatStrings(&g.concatBuf, &g.driveCD, name));
}

/// `wave_play` of the object's own wave.
fn playOwnWave(g: *Game, o: ?*Object) void {
    _ = sound.play(g, msg.main_window, must(Object, o).wave);
}

/// `asAnimation()->play(bd)` through the object's virtual base (slot 30).
fn play(g: *Game, o: ?*Object) void {
    tick.play(g, must(Object, must(Object, o).as(.animation)), bdOf(g));
}

/// Animation slot 07 on `asAnimation()`.
fn playOnce(g: *Game, o: ?*Object) void {
    animation.playOnce(g, must(Object, must(Object, o).as(.animation)), bdOf(g));
}

fn stop(g: *Game, o: ?*Object) void {
    animation.stopAndRedraw(g, must(Object, o), bdOf(g));
}

/// stopAndRedraw, then the animation's system timer is re-armed (the
/// original reads timerId and timerPeriod through two `asAnimation` calls).
fn stopAndRearm(g: *Game, o: ?*Object) void {
    stop(g, o);
    const a = must(Object, must(Object, o).as(.animation));
    g.setSystemTimer(@bitCast(a.anim.timerId), @bitCast(a.anim.timerPeriod));
}

/// GetDC/ReleaseDC dropped.
fn hide(g: *Game, o: ?*Object) void {
    visibility.hideAndInvalidate(g, must(Object, o), 0, bdOf(g));
}

fn invalidate(g: *Game, o: ?*Object) void {
    _ = visibility.invalidate(g, must(Object, o));
}

fn redraw(g: *Game, o: ?*Object) void {
    visibility.redraw(g, must(Object, o), bdOf(g));
}

fn drawObj(g: *Game, o: ?*Object) void {
    render.draw(g, must(Object, o), bdOf(g));
}

/// `scene_object_set_cur_frame` + `scene_object_reset_rects`.
fn setFrame(o: ?*Object, frame: u16) void {
    _ = frames.setCurFrame(must(Object, o), frame);
    frames.resetRects(must(Object, o));
}

/// The sgayd frame change that is followed by redraw + invalidate.
fn showFrame(g: *Game, s: *State, frame: u16) void {
    setFrame(s.sgayd, frame);
    redraw(g, s.sgayd);
    invalidate(g, s.sgayd);
}

/// The nine flags cleared whenever the scene is left, plus the panel click
/// flag set back.
fn resetFlags(s: *State) void {
    s.offerCount = 0;
    s.waveVariant = 0;
    s.presentGiven = 0;
    s.shirtTaken = 0;
    s.intro = 0;
    s.hasPresent = 0;
    s.remark = 0;
    s.finished = 0;
    s.panelAllowed = 0;
    s.panelClickAllowed = 1;
}

fn toStreet(g: *Game) void {
    _ = game_scenes.switchScene(g, "2fpontoc", 0xf0, 0xfa, 1, 1, 0, 0, 0);
}

fn toParty(g: *Game) void {
    _ = game_scenes.switchScene(g, "2ffesta3", 700, 0xfa, 1, 0, 0, 0, 0);
}

/// Picks the object under the cursor into `s.hitObject`; the result is the
/// grid query's.
fn query(g: *Game, s: *State, m: Msg) i8 {
    const bd = bdOf(g);
    const q = backdrop.queryRect(g, bd, @as(i16, @bitCast(m.lo())) +% bd.originX, @as(i16, @bitCast(m.hi())) +% bd.originY, 16, 16);
    s.hitObject = q.obj;
    return q.result;
}

/// Seeks the scene's INI section and looks up the WAVE line for
/// (`hit_id`, variant, selected item) into the shared WAVE record, then
/// copies its resolved path into `s.wavePath`.
fn findWavePath(g: *Game, s: *State, hit_id: i16) void {
    const fd = iniFd(g);
    _ = ini.seekSection(&g.ini, g.plat, g.fixes, fd, cstr.slice(&g.curSceneName), true) catch |e| die(e);
    const item = must(Object, g.selectedItem);
    _ = ini.findWave(&g.ini, g.plat, g.fixes, fd, hit_id, s.waveVariant, item.id, &g.sound.cache, &g.ini.rec.nomeWave, &g.ini.rec.waveObject) catch |e| die(e);
}

fn copyWavePath(g: *Game, s: *State) void {
    const p = ini.assetPath(&g.ini, &g.driveCD, &g.driveHD, &g.ini.rec.nomeWave, -3);
    cstr.copy(&s.wavePath, p);
}

fn seekSection(g: *Game) void {
    _ = ini.seekSection(&g.ini, g.plat, g.fixes, iniFd(g), cstr.slice(&g.curSceneName), true) catch |e| die(e);
}

// @orig 1020:5a90 handler_2fgaydir
pub fn handle(g: *Game, m: Msg) i16 {
    const s = g.sceneState(State);
    switch (m.id) {
        msg.wm.timer => {
            g.killTimer(TIMER_ID);
            sound.freeAll(&g.sound, g.plat);
            playBundled(g, wav_boiolr05);
            play(g, s.sgayf);
            s.timedOut = 1;
            return 1;
        },
        msg.wm.mousemove => {
            if (m.hi() <= PANEL_Y) return 0;
            return @intFromBool(s.panelAllowed == 0);
        },
        msg.wm.lbuttondown => return 1,
        msg.wm.rbuttondown => return rbuttonDown(g, s, m),
        msg.wm.rbuttonup => return rbuttonUp(g, s, m),
        msg.wm.mm_wom_done => return womDone(g, s),
        msg.noite.scene_started => return sceneStarted(g, s),
        msg.noite.animation_finished => {
            if (m.wparam != SGAYC_ID) return 1;
            if (s.offerCount == 3) return 1;
            showFrame(g, s, 0);
            playOnce(g, s.sgaya);
            s.shirtTaken = 1;
            return 1;
        },
        msg.noite.object_created => {
            switch (m.wparam) {
                SGAYA_ID => s.sgaya = g.newObject,
                SGAYC_ID => {
                    s.sgayc = g.newObject;
                    must(Object, s.sgayc).playOnceRewinds = 0;
                    hide(g, s.sgayc);
                },
                SGAYD_ID => s.sgayd = g.newObject,
                SGAYF_ID => s.sgayf = g.newObject,
                MOVS_ID => s.movs = g.newObject,
                SSHAV_ID => s.sshav = g.newObject,
                VIBRATOR_ID => s.vibrator = g.newObject,
                SUABOY_ID => s.suaboy = g.newObject,
                else => {},
            }
            return 1;
        },
        else => return 0,
    }
}

/// Scene start: the shirt/present state is read off the inventory, the
/// scene's animations start and the host's speech plays.
fn sceneStarted(g: *Game, s: *State) i16 {
    g.selectedItem = null;
    const player = must(Object, must(Object, g.player).as(.player));
    s.scanObject = player.actor.inventory.head;
    while (s.scanObject) |o| {
        if (o.id == PRESENT_ITEM_ID) {
            s.hasPresent = 1;
            break;
        }
        s.scanObject = o.next;
    }
    play(g, s.movs);
    play(g, s.sgayf);
    play(g, s.suaboy);
    play(g, s.sshav);
    playOwnWave(g, s.sgayf);
    s.intro = 1;
    return 0;
}

/// Hot objects of the scene: the pointer shows its "pick" cursor over them.
fn rbuttonDown(g: *Game, s: *State, m: Msg) i16 {
    if (m.hi() >= PANEL_Y and panels.isOpen(g, must(Object, g.controlPanel)) and s.panelClickAllowed == 0) return 1;
    if (query(g, s, m) <= 0) return 0;
    const h = s.hitObject orelse return 0;
    return switch (@as(u16, @bitCast(h.id))) {
        0x22, 0x0e, 0x0f, 0x10, 0x23, 0x25, 0x2b, 0x10c => 1,
        else => 0,
    };
}

/// An item dropped on a club person.
fn rbuttonUp(g: *Game, s: *State, m: Msg) i16 {
    if (g.itemSelected == 0) return 0;
    if (query(g, s, m) <= 0) {
        g.itemSelected = 0;
        g.selectedItem = null;
        return 1;
    }
    const hit = s.hitObject orelse return rejectDrop(g);
    if (must(Object, g.selectedItem).id == 0) return rejectDrop(g);

    if (animation.isRunning(g, must(Object, s.sgayf)) or animation.isRunning(g, must(Object, s.sgayc))) {
        stop(g, s.sgayf);
        stop(g, s.sgayc);
        const a = must(Object, must(Object, s.sgayf).as(.animation));
        g.setSystemTimer(@bitCast(a.anim.timerId), @bitCast(a.anim.timerPeriod));
        sound.stop(&g.sound, g.plat, must(Object, s.sgayf).wave);
        sound.stop(&g.sound, g.plat, must(Object, s.sgayc).wave);
    }
    switch (@as(u16, @bitCast(hit.id))) {
        SGAYF_ID, SGAYC_ID, SSHAV_ID, MOVS_ID => {},
        else => return rejectDrop(g),
    }

    s.offerCount +%= 1;
    s.panelClickAllowed = 0;
    seekSection(g);
    const item = must(Object, g.selectedItem);
    switch (item.id) {
        SHIRT_ITEM_ID => {
            stopAndRearm(g, s.suaboy);
            hide(g, s.suaboy);
            showFrame(g, s, 1);
            if (s.offerCount < 4) {
                stopAndRearm(g, s.sshav);
                hide(g, s.sshav);
                hide(g, s.sgayf);
            }
            if (s.offerCount == 4) {
                setFrame(s.sgayd, 0);
                redraw(g, s.sgayd);
                invalidate(g, s.sgayd);
                hide(g, s.sgayc);
                playOnce(g, s.sgaya);
            } else {
                playOnce(g, s.sgayc);
            }
            playOwnWave(g, s.sgayc);
            return 0;
        },
        PRESENT_ITEM_ID => {
            s.presentGiven = 1;
            seekSection(g);
            findWavePath(g, s, hit.id);
            copyWavePath(g, s);
            stop(g, s.suaboy);
            hide(g, s.sgayc);
            const a = must(Object, must(Object, s.suaboy).as(.animation));
            g.setSystemTimer(@bitCast(a.anim.timerId), @bitCast(a.anim.timerPeriod));
            hide(g, s.movs);
            hide(g, s.suaboy);
            setFrame(s.sgayd, 2);
            drawObj(g, s.sgayd);
            frames.resetRects(must(Object, s.sgayf));
            drawObj(g, s.sgayf);
            frames.resetRects(must(Object, s.sshav));
            drawObj(g, s.sshav);
            drawObj(g, g.controlPanel);
            backdrop.blitToDc(g, bdOf(g));
            update_list.discard(&g.updateList);
            play(g, s.sgayf);
            playBundled(g, wav_boiolr01);
            return 0;
        },
        else => {},
    }

    if (s.offerCount == 3) {
        stop(g, s.suaboy);
        stop(g, s.sshav);
        stop(g, s.movs);
        const a = must(Object, must(Object, s.sshav).as(.animation));
        g.setSystemTimer(@bitCast(a.anim.timerId), @bitCast(a.anim.timerPeriod));
        hide(g, s.sshav);
        hide(g, s.sgayf);
        hide(g, s.suaboy);
        visibility.show(g, must(Object, s.sgayc), bdOf(g));
        invalidate(g, s.sgayc);
        showFrame(g, s, 1);
        playOnce(g, s.sgayc);
        playBundled(g, wav_boiolr02);
        return 0;
    }
    if (s.offerCount > 3) {
        sound.freeAll(&g.sound, g.plat);
        playBundled(g, wav_boiolr05);
        return 1;
    }

    // Offers 1 and 2: the WAVE reply of the host from the INI.
    seekSection(g);
    findWavePath(g, s, SGAYF_ID);
    s.waveVariant = 0;
    s.scanObject = must(Scene, g.scene).objects.head;
    while (s.scanObject) |o| {
        if (o.id == g.ini.rec.waveObject) break;
        s.scanObject = o.next;
    }
    copyWavePath(g, s);
    play(g, s.sgayf);
    playWave(g, &s.wavePath);
    return 0;
}

/// The drop did not hit anything usable: forget the selection.
fn rejectDrop(g: *Game) i16 {
    g.itemSelected = 0;
    g.selectedItem = null;
    return 1;
}

/// A wave (or the intro) ended: the scene's story advances.
fn womDone(g: *Game, s: *State) i16 {
    s.panelClickAllowed = 1;
    if (s.timedOut != 0) {
        s.timedOut = 0;
        resetFlags(s);
        update_list.discard(&g.updateList);
        g.itemSelected = 0;
        toStreet(g);
        return 1;
    }
    if (s.intro != 0) {
        s.intro = 0;
        if (s.hasPresent != 0) {
            playBundled(g, wav_boiols03);
            s.remark = 1;
        } else {
            stopAndRearm(g, s.sgayf);
            s.panelAllowed = 1;
        }
        const player = must(Object, must(Object, g.player).as(.player));
        if (!object_list.isEmpty(&player.actor.inventory)) return 1;
        g.setTimer(TIMER_ID, 5000);
        return 1;
    }
    if (s.remark != 0) {
        s.remark = 0;
        s.panelAllowed = 1;
        stopAndRearm(g, s.sgayf);
        return 1;
    }
    if (s.shirtTaken != 0) {
        resetFlags(s);
        update_list.discard(&g.updateList);
        toParty(g);
        return 1;
    }

    if (g.selectedItem) |sel| {
        if (sel.id == SHIRT_ITEM_ID) {
            // The shirt was given: it is consumed and the party starts.
            hide(g, sel);
            invalidate(g, sel);
            _ = object_list.remove(&must(Scene, g.scene).objects, sel);
            draw_list.remove(&g.drawList, sel);
            resetFlags(s);
            update_list.discard(&g.updateList);
            toParty(g);
            return 1;
        }
    }
    if (s.finished != 0) {
        resetFlags(s);
        update_list.discard(&g.updateList);
        toParty(g);
        return 1;
    }
    const sel = g.selectedItem orelse return 1;

    if (s.presentGiven != 0) {
        // The present: scored and consumed, the vibrator plays.
        g.score +%= sel.portable.scoreUse;
        hide(g, sel);
        _ = object_list.remove(&g.globalObjects, sel);
        // Unlike the other scenes it is not put on the used list: the
        // original loses (leaks) it; the port parks it until exit.
        g.leakObject(sel);
        draw_list.remove(&g.drawList, sel);
        stop(g, s.sgayf);
        stop(g, s.sshav);
        const a = must(Object, must(Object, s.sgayf).as(.animation));
        g.setSystemTimer(@bitCast(a.anim.timerId), @bitCast(a.anim.timerPeriod));
        hide(g, s.sgayf);
        hide(g, s.sshav);
        _ = frames.setCurFrame(must(Object, s.vibrator), 1);
        play(g, s.vibrator);
        playOwnWave(g, s.vibrator);
        s.finished = 1;
        return 1;
    }
    if (s.hitObject == null) {
        g.selectedItem = null;
        return 1;
    }

    // A wrong offer: scored as a misuse, the item goes back to the inventory.
    g.score +%= sel.portable.scoreMisuse;
    const item = sel.as(.portable) orelse @panic("2fgaydir: asPortable returned NULL");
    s.returnedItem = item;
    _ = portable.pickUp(g, item, must(Object, must(Object, g.player).as(.player)));
    frames.resetRects(item);
    hide(g, item);
    visibility.redrawOverlapping(g, item, bdOf(g), 0);
    if (s.offerCount == 3) {
        occupancy.reoccupy(g, must(Object, s.hitObject), bdOf(g));
    } else if (s.offerCount < 3) {
        stopAndRearm(g, s.sgayf);
    }
    if (s.offerCount > 3) {
        resetFlags(s);
        update_list.discard(&g.updateList);
        g.itemSelected = 0;
        toStreet(g);
        return 1;
    }
    g.selectedItem = null;
    return 1;
}
