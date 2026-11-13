//! Port unit `handler_4fbarboy` (handler). scene handler 1020:a050.
//!
//! The bar with the barman and the boys. Right-clicking the barman in front
//! (object 0xe6) makes him ask a yes/no question (object 0x12c, the answer
//! rectangles are in `yesRect`/`noRect`); yes ends the scene with the boys'
//! remark (score -3000) and a return to the disco entrance (`4FINIFES`), no
//! costs 500. Dropping an item on him: the right one (0x111) is served and
//! leads to the DJ booth (`4FDJ`); wrong ones come back with a score penalty
//! and the fourth sends the player back to `4FINIFES`. The drunk (0xe5)
//! grumbles when clicked until the right item was given.

const Game = @import("../core/game.zig").Game;
const Msg = @import("../core/msg.zig").Msg;
const msg = @import("../core/msg.zig");
const Object = @import("../core/object.zig").Object;
const Rect = @import("../core/object.zig").Rect;
const world = @import("../core/world.zig");
const Backdrop = world.Backdrop;
const Scene = world.Scene;
const cstr = @import("../core/cstr.zig");
const animation = @import("../behaviour/animation.zig");
const movement = @import("../behaviour/space3d.zig");
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

/// INI Numbers of the scene's objects.
const BARMAN_ID: i16 = 0xdf;
const DRUNK_ID: i16 = 0xe0;
const ESOTERIC_ANIM_ID: i16 = 0xe1;
const ESOTERIC_ID: i16 = 0xe2;
const SMARR_ID: i16 = 0xe3;
const BOYS_ID: i16 = 0xe4;
const DRUNK_DYING_ID: i16 = 0xe5;
const BARMAN_FRONT_ID: i16 = 0xe6;
const YESNO_ID: i16 = 0x12c;
/// The right item.
const RIGHT_ITEM_ID: i16 = 0x111;

const question_wav = "fase4\\4fbarboy\\barman1.wav";
const refuse_wav = "fase4\\4fbarboy\\barcaido.wav";
const served_wav = "fase4\\4fbarboy\\barmr06.wav";

pub const State = struct {
    // @orig g_s4fbarboyQuestionPlaying
    questionPlaying: i16 = 0,
    // @orig g_s4fbarboyAwaitingAnswer
    awaitingAnswer: i16 = 0,
    // @orig g_s4fbarboyAnsweredYes
    answeredYes: i16 = 0,
    // @orig g_s4fbarboyUnk0BFA (never set, only tested)
    unk0BFA: i16 = 0,
    // @orig g_s4fbarboyAnsweredNo
    answeredNo: i16 = 0,
    // @orig g_s4fbarboyQuestionAsked
    questionAsked: i16 = 0,
    // @orig g_s4fbarboyDrunkTalking
    drunkTalking: i16 = 0,
    // @orig g_s4fbarboyServed
    served: i16 = 0,
    // @orig g_s4fbarboyDone
    done: i16 = 0,
    // @orig g_s4fbarboyRightItemGiven
    rightItemGiven: i16 = 0,
    // @orig g_s4fbarboyUnk0C08 (only ever reset)
    unk0C08: i16 = 0,
    // @orig g_s4fbarboyOfferCount
    offerCount: i16 = 0,
    // @orig g_s4fbarboyRightItem
    rightItem: i16 = 0,
    // @orig g_s4fbarboyWaveVariant
    waveVariant: i16 = 0,
    // @orig g_s4fbarboyYesNoX
    yesNoX: i16 = 0,
    // @orig g_s4fbarboyHitObject
    hitObject: ?*Object = null,
    // @orig g_s4fbarboyWaveTarget
    waveTarget: ?*Object = null,
    // @orig g_s4fbarboyEsotericAnim
    esotericAnim: ?*Object = null,
    // @orig g_s4fbarboyBarmanFront
    barmanFront: ?*Object = null,
    // @orig g_s4fbarboyBarman
    barman: ?*Object = null,
    // @orig g_s4fbarboySmarr
    smarr: ?*Object = null,
    // @orig g_s4fbarboyYesNo
    yesNo: ?*Object = null,
    // @orig g_s4fbarboyDrunkDying
    drunkDying: ?*Object = null,
    // @orig g_s4fbarboyDrunk
    drunk: ?*Object = null,
    // @orig g_s4fbarboyBoys
    boys: ?*Object = null,
    // @orig g_s4fbarboyEsoteric
    esoteric: ?*Object = null,
    // @orig g_s4fbarboyReturnedItem
    returnedItem: ?*Object = null,
    // @orig g_s4fbarboyYesRect (1040:0004; BSS, zero until object 0x12c is created)
    yesRect: Rect = .{},
    // @orig g_s4fbarboyNoRect (1040:000c)
    noRect: Rect = .{},
    // The barman's saved position (unnamed POINT at 1040:0000, BSS).
    savedX: i16 = 0,
    savedY: i16 = 0,
};

/// The original's unchecked pointers: a missing one is a crash there.
fn must(comptime T: type, p: ?*T) *T {
    return p orelse @panic("4fbarboy: null pointer");
}

fn bdOf(g: *Game) *Backdrop {
    return must(Backdrop, must(Scene, g.scene).backdrop);
}

fn die(e: anyerror) noreturn {
    @panic(@errorName(e));
}

fn ptInRect(r: Rect, x: i16, y: i16) bool {
    return x >= r.left and x < r.right and y >= r.top and y < r.bottom;
}

/// reset_rects + draw (slot 1B).
fn resetDraw(g: *Game, o: ?*Object) void {
    const obj = must(Object, o);
    frames.resetRects(obj);
    render.draw(g, obj, bdOf(g));
}

/// Redraws the four people over the backdrop, then the control panel.
fn redrawPeople(g: *Game, s: *State) void {
    resetDraw(g, s.barmanFront);
    resetDraw(g, s.drunk);
    resetDraw(g, s.boys);
    resetDraw(g, s.esoteric);
    render.draw(g, must(Object, g.controlPanel), bdOf(g));
}

/// The final GetDC + backdrop blit + update-list discard.
fn flush(g: *Game) void {
    backdrop.blitToDc(g, bdOf(g));
    update_list.discard(&g.updateList);
}

fn playAnim(g: *Game, o: ?*Object) void {
    const obj = must(Object, o);
    tick.play(g, must(Object, obj.as(.animation)), bdOf(g));
}

fn waveOf(g: *Game, o: ?*Object) void {
    _ = sound.play(g, msg.main_window, must(Object, o).wave);
}

fn playPath(g: *Game, path: []const u8) void {
    const w = sound.open(g, path) catch |e| die(e);
    _ = sound.play(g, msg.main_window, w);
}

fn rearmTimer(g: *Game, obj: *Object) void {
    const a = must(Object, obj.as(.animation));
    g.setSystemTimer(@bitCast(a.anim.timerId), @bitCast(a.anim.timerPeriod));
}

fn resetFlags(s: *State) void {
    s.questionPlaying = 0;
    s.awaitingAnswer = 0;
    s.answeredYes = 0;
    s.unk0BFA = 0;
    s.answeredNo = 0;
    s.questionAsked = 0;
    s.drunkTalking = 0;
    s.served = 0;
    s.done = 0;
    s.rightItemGiven = 0;
    s.unk0C08 = 0;
    s.offerCount = 0;
    s.rightItem = 0;
}

/// Leaves for another scene (`x`=`y`=0, no player, no status bar).
fn leave(g: *Game, name: []const u8, has_control_panel: i16) void {
    _ = game_scenes.switchScene(g, name, 0, 0, 0, has_control_panel, 0, 0, 0);
}

fn query(g: *Game, s: *State, m: Msg) i8 {
    const bd = bdOf(g);
    const q = backdrop.queryRect(g, bd, @as(i16, @bitCast(m.lo())) +% bd.originX, @as(i16, @bitCast(m.hi())) +% bd.originY, 16, 16);
    s.hitObject = q.obj;
    return q.result;
}

/// ini_seek_section on the current scene; returns the ini file handle.
fn seek(g: *Game) u16 {
    const fd = g.iniFile;
    _ = ini.seekSection(&g.ini, g.plat, g.fixes, fd, cstr.slice(&g.curSceneName), true) catch |e| die(e);
    return fd;
}

fn findWave(g: *Game, fd: u16, id: i16, variant: i16, item: i16) void {
    _ = ini.findWave(&g.ini, g.plat, g.fixes, fd, id, variant, item, &g.sound.cache, &g.ini.rec.nomeWave, &g.ini.rec.waveObject) catch |e| die(e);
}

/// The WAVE found by `findWave`, copied to a local buffer (as the original
/// does) and played.
fn playFound(g: *Game) void {
    var buf: [256]u8 = @splat(0);
    cstr.copy(&buf, ini.assetPath(&g.ini, &g.driveCD, &g.driveHD, &g.ini.rec.nomeWave, -3));
    playPath(g, cstr.slice(&buf));
}

// @orig 1020:a050 handler_4fbarboy
pub fn handle(g: *Game, m: Msg) i16 {
    const s = g.sceneState(State);
    switch (m.id) {
        msg.wm.rbuttondown => return rbuttonDown(g, s, m),
        msg.wm.rbuttonup => return rbuttonUp(g, s, m),
        msg.wm.mm_wom_done => return waveDone(g, s),
        0x401 => {
            // Moves the dying drunk away.
            const dd = must(Object, s.drunkDying);
            const bd = bdOf(g);
            render.erase(g, dd, bd);
            movement.moveToAndDrop(g, dd, 0x280, 0x1e0, bd);
            redrawPeople(g, s);
            return 0;
        },
        0x403 => {
            if (s.served == 0) {
                if (s.answeredYes == 0) return 0;
                s.answeredYes = 0;
                _ = frames.setCurFrame(must(Object, s.barman), 7);
                resetDraw(g, s.barman);
                resetDraw(g, s.drunk);
                resetDraw(g, s.boys);
                resetDraw(g, s.esoteric);
                render.draw(g, must(Object, g.controlPanel), bdOf(g));
                flush(g);
                s.served = 1;
                playAnim(g, s.boys);
                waveOf(g, s.boys);
                return 0;
            }
            resetFlags(s);
            const bf = must(Object, s.barmanFront);
            bf.x = s.savedX;
            bf.y = s.savedY;
            update_list.discard(&g.updateList);
            leave(g, "4FINIFES", 0);
            return 0;
        },
        msg.noite.object_created => {
            const obj = g.newObject;
            switch (@as(i16, @bitCast(m.wparam))) {
                YESNO_ID => {
                    s.yesNo = obj;
                    s.yesNoX = must(Object, obj).x;
                    const x = s.yesNoX;
                    s.yesRect = .{ .left = x +% 0x42, .top = 0xe0, .right = x +% 0x70, .bottom = 0xf8 };
                    s.noRect = .{ .left = x +% 0x95, .top = 0xdb, .right = x +% 0xc5, .bottom = 0xf6 };
                },
                BARMAN_ID => {
                    s.barman = obj;
                    must(Object, obj).playOnceRewinds = 0;
                },
                DRUNK_ID => {
                    s.drunk = obj;
                    must(Object, obj).playOnceRewinds = 0;
                },
                ESOTERIC_ANIM_ID => s.esotericAnim = obj,
                ESOTERIC_ID => s.esoteric = obj,
                SMARR_ID => s.smarr = obj,
                BOYS_ID => s.boys = obj,
                DRUNK_DYING_ID => s.drunkDying = obj,
                BARMAN_FRONT_ID => s.barmanFront = obj,
                else => {},
            }
            return 0;
        },
        else => return 0,
    }
}

fn rbuttonDown(g: *Game, s: *State, m: Msg) i16 {
    if (m.hi() > 0x168) return 0;
    if (query(g, s, m) <= 0) return 0;
    const hit = s.hitObject orelse return 0;
    const bd = bdOf(g);
    switch (hit.id) {
        YESNO_ID => {
            if (s.awaitingAnswer == 0) return 1;
            const px: i16 = @bitCast(m.lo());
            const py: i16 = @bitCast(m.hi());
            s.awaitingAnswer = 0;
            if (ptInRect(s.yesRect, px, py)) {
                s.answeredYes = 1;
                _ = frames.setCurFrame(must(Object, s.yesNo), 0);
                render.erase(g, must(Object, s.yesNo), bd);
                const bf = must(Object, s.barmanFront);
                render.erase(g, bf, bd);
                s.savedX = bf.x;
                s.savedY = bf.y;
                movement.moveToAndDrop(g, bf, 0x280, 0x1e0, bd);
                _ = frames.setCurFrame(must(Object, s.barman), 1);
                resetDraw(g, s.barman);
                resetDraw(g, s.drunk);
                resetDraw(g, s.boys);
                resetDraw(g, s.esoteric);
                render.draw(g, must(Object, g.controlPanel), bd);
                flush(g);
                playAnim(g, s.barman);
                waveOf(g, s.barman);
                return 1;
            }
            if (!ptInRect(s.noRect, px, py)) return 1;
            s.answeredNo = 1;
            _ = frames.setCurFrame(must(Object, s.yesNo), 0);
            render.erase(g, must(Object, s.yesNo), bd);
            redrawPeople(g, s);
            flush(g);
            playAnim(g, s.barmanFront);
            playPath(g, ini.concatStrings(&g.concatBuf, &g.driveCD, question_wav));
            return 1;
        },
        0xdf, 0xe0, 0xe1, 0xe2, 0xe3 => return 1,
        DRUNK_DYING_ID => {
            if (s.rightItemGiven != 0) return 0;
            waveOf(g, s.drunkDying);
            s.drunkTalking = 1;
            return 1;
        },
        BARMAN_FRONT_ID => {
            if (s.questionPlaying != 0) return 1;
            if (s.questionAsked != 0) return 1;
            s.questionPlaying = 1;
            playAnim(g, s.barmanFront);
            waveOf(g, s.barmanFront);
            return 1;
        },
        else => return 0,
    }
}

fn rbuttonUp(g: *Game, s: *State, m: Msg) i16 {
    if (g.itemSelected == 0) return 0;
    if (query(g, s, m) <= 0) {
        g.itemSelected = 0;
        g.selectedItem = null;
        return 1;
    }
    const hit = s.hitObject orelse return 0;
    if (hit.id != BARMAN_FRONT_ID) {
        g.itemSelected = 0;
        g.selectedItem = null;
        return 1;
    }
    s.offerCount +%= 1;
    const item = must(Object, g.selectedItem);
    if (s.offerCount > 3) {
        // Four offers: he gets tired (the found WAVE is looked up but not used).
        const fd = seek(g);
        findWave(g, fd, BARMAN_ID, 3, item.id);
        var buf: [256]u8 = @splat(0);
        cstr.copy(&buf, ini.assetPath(&g.ini, &g.driveCD, &g.driveHD, &g.ini.rec.nomeWave, -3));
        playAnim(g, s.barmanFront);
        playPath(g, ini.concatStrings(&g.concatBuf, &g.driveCD, refuse_wav));
        return 0;
    }
    var fd = seek(g);
    if (item.id == RIGHT_ITEM_ID) {
        s.rightItem = 1;
        s.rightItemGiven = 1;
        fd = seek(g);
        findWave(g, fd, hit.id, s.waveVariant, item.id);
        var buf: [256]u8 = @splat(0);
        cstr.copy(&buf, ini.assetPath(&g.ini, &g.driveCD, &g.driveHD, &g.ini.rec.nomeWave, -3));
        const bd = bdOf(g);
        render.erase(g, must(Object, s.barmanFront), bd);
        _ = frames.setCurFrame(must(Object, s.smarr), 1);
        resetDraw(g, s.smarr);
        resetDraw(g, s.drunk);
        resetDraw(g, s.esoteric);
        render.draw(g, must(Object, g.controlPanel), bd);
        flush(g);
        playAnim(g, s.drunk);
        playAnim(g, s.smarr);
        playPath(g, cstr.slice(&buf));
        return 0;
    }
    fd = seek(g);
    findWave(g, fd, hit.id, s.waveVariant, item.id);
    s.waveVariant = 0;
    s.waveTarget = must(Scene, g.scene).objects.head;
    while (s.waveTarget) |o| {
        if (o.id == g.ini.rec.waveObject) break;
        s.waveTarget = o.next;
    }
    var buf: [256]u8 = @splat(0);
    cstr.copy(&buf, ini.assetPath(&g.ini, &g.driveCD, &g.driveHD, &g.ini.rec.nomeWave, -3));
    playAnim(g, s.barmanFront);
    playPath(g, cstr.slice(&buf));
    return 0;
}

/// MM_WOM_DONE: advances the dialogue.
fn waveDone(g: *Game, s: *State) i16 {
    const bd = bdOf(g);
    if (s.questionPlaying != 0) {
        s.questionPlaying = 0;
        s.questionAsked = 1;
        animation.stop(g, must(Object, s.barmanFront));
        s.awaitingAnswer = 1;
        redrawPeople(g, s);
        _ = frames.setCurFrame(must(Object, s.yesNo), 1);
        resetDraw(g, s.yesNo);
        flush(g);
        return 0;
    }
    if (s.unk0BFA != 0) {
        s.unk0BFA = 0;
        animation.stop(g, must(Object, s.esotericAnim));
        return 0;
    }
    if (s.drunkTalking != 0) {
        s.drunkTalking = 0;
        return 0;
    }
    if (s.answeredYes != 0) {
        g.score -%= 3000;
        return 1;
    }
    if (s.answeredNo != 0) {
        s.answeredNo = 0;
        animation.stop(g, must(Object, s.barmanFront));
        g.score -%= 500;
        return 0;
    }
    if (s.done != 0) {
        resetFlags(s);
        update_list.discard(&g.updateList);
        leave(g, "4FDJ", 1);
        return 0;
    }
    if (s.served != 0) return 1;
    if (s.rightItem == 0) {
        // A wrong item comes back with a penalty (it stays "selected").
        const sel = must(Object, g.selectedItem);
        g.score +%= sel.portable.scoreMisuse;
        const item = sel.as(.portable) orelse @panic("4fbarboy: asPortable returned NULL");
        s.returnedItem = item;
        _ = portable.pickUp(g, item, must(Object, must(Object, g.player).as(.player)));
        frames.resetRects(item);
        visibility.hideAndInvalidate(g, item, 0, bd);
        visibility.redrawOverlapping(g, item, bd, 0);
        const bf = must(Object, s.barmanFront);
        animation.stopAndRedraw(g, bf, bd);
        rearmTimer(g, bf);
        redrawPeople(g, s);
        flush(g);
        if (s.offerCount < 4) return 0;
        animation.stop(g, bf);
        resetFlags(s);
        update_list.discard(&g.updateList);
        leave(g, "4FINIFES", 0);
        return 0;
    }
    // The right item: consumed, the drunk is carried off, the barman answers.
    const item = must(Object, g.selectedItem);
    visibility.hideAndInvalidate(g, item, 0, bd);
    _ = object_list.remove(&g.globalObjects, item);
    draw_list.remove(&g.drawList, item);
    _ = object_list.add(g, &g.usedObjects, item);
    _ = frames.setCurFrame(must(Object, s.smarr), 0);
    render.erase(g, must(Object, s.smarr), bd);
    resetDraw(g, s.barmanFront);
    resetDraw(g, s.boys);
    _ = frames.setCurFrame(must(Object, s.drunk), 0);
    movement.moveToAndDrop(g, must(Object, s.drunk), 0x280, 0x1e0, bd);
    movement.moveToAndDrop(g, must(Object, s.drunkDying), 0x1ba, 0x4b, bd);
    resetDraw(g, s.drunkDying);
    resetDraw(g, s.esoteric);
    render.draw(g, must(Object, g.controlPanel), bd);
    flush(g);
    s.done = 1;
    playAnim(g, s.barmanFront);
    playPath(g, ini.concatStrings(&g.concatBuf, &g.driveCD, served_wav));
    return 0;
}
