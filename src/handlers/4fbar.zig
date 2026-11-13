//! Port unit `handler_4fbar` (handler). scene handler 1020:d5ee.
//!
//! The main bar. The esoteric (object 0xd5), the sportsman (0xd6) and the
//! vampire (0xd9) each hold a multiple-choice dialogue: a click on one of
//! them starts it (`0x403` sent to ourselves), a random question picture
//! (frame 1..7) is shown with its spoken question, and the next right click
//! must land inside that question's answer rectangle. The right answer sends
//! the player on (esoteric: 4FSACAET, sportsman: 4FSALGIN minigame scene,
//! vampire: 4FJARVAMP, after his answer wave ends); a wrong one costs a
//! life. Items dropped on the three (and the boy, 0xd8, who calls the angel)
//! get a WAVE reply; the right items (0x56, 0xd0) start the matching
//! dialogue (`unk0C70`: question 7) or send the angel (`unk0C5A/0C5C`).
//! The barman (0xd7) just plays his wave.
//!
//! Original bugs reproduced: lives are tested with `DEC; JNS` (game over
//! only at -1, BUGS.md B1 note); the sportsman's picture position is read
//! from the esoteric's picture object (Speso, 0x11f) instead of Spesp
//! (0x120); the right esoteric answer switches to 4FSACAET twice with an
//! update-list discard in between; `okvamp.wav` is not on the disc (BUGS.md
//! wave-path list).

const Game = @import("../core/game.zig").Game;
const Msg = @import("../core/msg.zig").Msg;
const msg = @import("../core/msg.zig");
const Object = @import("../core/object.zig").Object;
const world = @import("../core/world.zig");
const Backdrop = world.Backdrop;
const Wave = @import("../platform/platform.zig").Wave;
const cstr = @import("../core/cstr.zig");
const animation = @import("../behaviour/animation.zig");
const movement = @import("../behaviour/movement.zig");
const occupancy = @import("../behaviour/occupancy.zig");
const render = @import("../behaviour/render.zig");
const space3d = @import("../behaviour/space3d.zig");
const tick = @import("../behaviour/tick.zig");
const visibility = @import("../behaviour/visibility.zig");
const backdrop = @import("../backdrop.zig");
const draw_list = @import("../draw_list.zig");
const frames = @import("../frames.zig");
const game_scenes = @import("../game_scenes.zig");
const ini = @import("../ini.zig");
const object_list = @import("../object_list.zig");
const panels = @import("../panels.zig");
const portable = @import("../portable.zig");
const sound = @import("../sound.zig");
const update_list = @import("../update_list.zig");

/// INI Numbers of the scene's objects.
const ESOTERIC_ID: i16 = 0xd5;
const SPORTSMAN_ID: i16 = 0xd6;
const BARMAN_ID: i16 = 0xd7;
const BOY_ID: i16 = 0xd8;
const VAMPIRE_ID: i16 = 0xd9;
const SPORTSMAN_ANIM_ID: u16 = 0xd3;
const VAMPIRE_ANIM_ID: u16 = 0xd4;
const BOOK_ITEM_ID: i16 = 0xcf;
/// The two items that are right answers (0x56, 0xd0).
const ITEM_A: i16 = 0x56;
const ITEM_B: i16 = 0xd0;

const wave_dir = "fase4\\4fbar\\";
const esoteric_wrong_wav = wave_dir ++ "ESOTER18.wav"; // 1028:11f8
const sportsman_wrong_wav = wave_dir ++ "esporr28.wav"; // 1028:1242
const vampire_ok_wav = wave_dir ++ "okvamp.wav"; // 1028:1212
const vampire_wrong_wav = wave_dir ++ "vampr38.wav"; // 1028:122a

pub const State = struct {
    // @orig g_s4fbarUnk0C56 (the barman was clicked: his wave is playing)
    unk0C56: i16 = 0,
    // @orig g_s4fbarIdle (1 = no question is waiting for an answer)
    idle: i16 = 1,
    // @orig g_s4fbarUnk0C5A (right item 0x56 given to the boy)
    unk0C5A: i16 = 0,
    // @orig g_s4fbarUnk0C5C (right item 0xd0 given to the boy)
    unk0C5C: i16 = 0,
    // @orig g_s4fbarEsotericDialog
    esotericDialog: i16 = 0,
    // @orig g_s4fbarVampireDialog
    vampireDialog: i16 = 0,
    // @orig g_s4fbarSportsmanDialog
    sportsmanDialog: i16 = 0,
    // @orig g_s4fbarVampireConvinced
    vampireConvinced: i16 = 0,
    // @orig g_s4fbarEsotericReply
    esotericReply: i16 = 0,
    // @orig g_s4fbarSportsmanReply
    sportsmanReply: i16 = 0,
    // @orig g_s4fbarVampireReply
    vampireReply: i16 = 0,
    // @orig g_s4fbarOfferCount
    offerCount: i16 = 0,
    // @orig g_s4fbarUnk0C6E (only ever written 0)
    unk0C6E: i16 = 0,
    // @orig g_s4fbarUnk0C70 (the right item was given: next question is 7)
    unk0C70: i16 = 0,
    // @orig g_s4fbarWaveVariant (only ever written 0)
    waveVariant: i16 = 0,
    // @orig g_s4fbarReturnedItem
    returnedItem: ?*Object = null,
    // @orig g_s4fbarHitObject
    hitObject: ?*Object = null,
    // @orig g_s4fbarBarmanFront
    barmanFront: ?*Object = null,
    // @orig g_s4fbarVampireAnim
    vampireAnim: ?*Object = null,
    // @orig g_s4fbarEsotericAnim
    esotericAnim: ?*Object = null,
    // @orig g_s4fbarSportsmanAnim
    sportsmanAnim: ?*Object = null,
    // @orig g_s4fbarVampire
    vampire: ?*Object = null,
    // @orig g_s4fbarEsoteric
    esoteric: ?*Object = null,
    // @orig g_s4fbarSportsman
    sportsman: ?*Object = null,
    // @orig g_s4fbarBoy
    boy: ?*Object = null,
    // @orig g_s4fbarAngel
    angel: ?*Object = null,
    // @orig g_s4fbarAngelAnim
    angelAnim: ?*Object = null,
    // @orig g_s4fbarBooks
    books: ?*Object = null,
    // @orig g_s4fbarSpeso (the esoteric's question picture)
    speso: ?*Object = null,
    // @orig g_s4fbarSpvam (the vampire's question picture)
    spvam: ?*Object = null,
    // @orig g_s4fbarSpesp (the sportsman's question picture)
    spesp: ?*Object = null,
    // @orig g_s4fbarTalkingAnim (also the inventory-walk cursor)
    talkingAnim: ?*Object = null,
    // @orig g_s4fbarPictureX
    pictureX: i16 = 0,
    // @orig g_s4fbarPictureY
    pictureY: i16 = 0,
    // @orig g_s4fbarQuestion
    question: i16 = 0,
    // @orig g_s4fbarQuestionWave
    questionWave: ?Wave = null,
};

const Who = enum { esoteric, sportsman, vampire };

/// Answer rectangles per question 1..7, as offsets from the question
/// picture's position: left, top, right, bottom (1028 jump-table code of
/// the 0x11f / 0x120 / 0x121 cases).
const answer_rects = [3][7][4]i16{
    // esoteric
    .{
        .{ 0x14, 0x103, 0xe3, 0x123 },
        .{ 0x11, 0xb9, 0xed, 0xe6 },
        .{ 0xd, 0xfd, 0xf6, 0x12e },
        .{ 0x13, 0x10a, 0xf2, 0x138 },
        .{ 0xb, 0x74, 0xf0, 0xa4 },
        .{ 0xc, 0x130, 0xf6, 0x162 },
        .{ 0x11, 0xc9, 0x87, 0xe7 },
    },
    // sportsman
    .{
        .{ 0x19, 0xb5, 0xc3, 0xd9 },
        .{ 0x16, 0xbe, 0x75, 0xe2 },
        .{ 0x1a, 0x6a, 0x51, 0x88 },
        .{ 0x16, 0xe0, 0xa9, 0x109 },
        .{ 0x1d, 0xa1, 0x90, 0xc4 },
        .{ 0x1a, 0x77, 0x91, 0x99 },
        .{ 0x1b, 0xbf, 0x62, 0xe0 },
    },
    // vampire
    .{
        .{ 0x13, 0x95, 0xa0, 0xb1 },
        .{ 0x14, 0xba, 0x8d, 0xd8 },
        .{ 0x17, 0x10a, 0x7a, 0x12e },
        .{ 0x12, 0x56, 0xcf, 0x88 },
        .{ 0x17, 0x9f, 0x84, 0xc2 },
        .{ 0x1d, 0xfc, 0x81, 0x124 },
        .{ 0x23, 0xde, 0xc4, 0x105 },
    },
};

/// The original's unchecked pointers: a missing one is a crash there.
fn must(comptime T: type, p: ?*T) *T {
    return p orelse @panic("4fbar: null pointer");
}

fn bdOf(g: *Game) *Backdrop {
    return must(Backdrop, must(world.Scene, g.scene).backdrop);
}

fn die(e: anyerror) noreturn {
    @panic(@errorName(e));
}

fn iniFd(g: *Game) u16 {
    return g.iniFile; // Game+0x680
}

/// reset_rects + draw (slot 1B).
fn redraw(g: *Game, o: ?*Object) void {
    const obj = must(Object, o);
    frames.resetRects(obj);
    render.draw(g, obj, bdOf(g));
}

/// Starts the object's animation (Animation view, slot 30).
fn playAnim(g: *Game, o: ?*Object) void {
    const a = must(Object, must(Object, o).as(.animation));
    tick.play(g, a, bdOf(g));
}

/// SetSystemTimer with the animation's timer id and period.
fn restartTimer(g: *Game, o: ?*Object) void {
    const a = must(Object, must(Object, o).as(.animation));
    g.setSystemTimer(@bitCast(a.anim.timerId), @bitCast(a.anim.timerPeriod));
}

fn stopAnim(g: *Game, o: ?*Object) void {
    animation.stopAndRedraw(g, must(Object, o), bdOf(g));
}

fn reoccupy(g: *Game, o: ?*Object) void {
    occupancy.reoccupy(g, must(Object, o), bdOf(g));
}

/// Slot 29 on the eight characters, in the original's order.
fn reoccupyAll(g: *Game, s: *State) void {
    reoccupy(g, s.barmanFront);
    reoccupy(g, s.vampire);
    reoccupy(g, s.vampireAnim);
    reoccupy(g, s.esoteric);
    reoccupy(g, s.esotericAnim);
    reoccupy(g, s.sportsman);
    reoccupy(g, s.sportsmanAnim);
    reoccupy(g, s.boy);
}

fn seekScene(g: *Game) void {
    _ = ini.seekSection(&g.ini, g.plat, g.fixes, iniFd(g), cstr.slice(&g.curSceneName), true) catch |e| die(e);
}

/// sprintf(buf, "%s%s", driveCD, name); wave_open; wave_play.
fn playNamedWave(g: *Game, name: []const u8) void {
    var buf: [256]u8 = undefined;
    const path = cstr.print(&buf, "{s}{s}", .{ cstr.slice(&g.driveCD), name });
    const w = sound.open(g, path) catch |e| die(e);
    _ = sound.play(g, msg.main_window, w);
}

/// ini_find_wave(hit, variant, item) then the wave it names: copies the
/// path to a local buffer, opens it. Returns the handle.
fn openIniWave(g: *Game, number: i16, variant: i16, arg3: i16) ?Wave {
    _ = ini.findWave(&g.ini, g.plat, g.fixes, iniFd(g), number, variant, arg3, &g.sound.cache, &g.ini.rec.nomeWave, &g.ini.rec.waveObject) catch |e| die(e);
    const p = ini.assetPath(&g.ini, &g.driveCD, &g.driveHD, &g.ini.rec.nomeWave, -3);
    var buf: [256]u8 = undefined;
    cstr.copy(&buf, p);
    return sound.open(g, &buf) catch |e| die(e);
}

/// The 14 globals every "dialogue is over" path clears (`idle` and
/// `unk0C58`'s neighbours are not among them).
fn resetAll(s: *State) void {
    s.waveVariant = 0;
    s.unk0C56 = 0;
    s.unk0C5A = 0;
    s.unk0C5C = 0;
    s.esotericDialog = 0;
    s.unk0C70 = 0;
    s.vampireDialog = 0;
    s.sportsmanDialog = 0;
    s.vampireConvinced = 0;
    s.esotericReply = 0;
    s.sportsmanReply = 0;
    s.vampireReply = 0;
    s.offerCount = 0;
    s.unk0C6E = 0;
}

fn discardUpdates(g: *Game) void {
    update_list.discard(&g.updateList);
}

/// switch_scene with every argument zero (the 4F* scenes).
fn gotoScene(g: *Game, name: []const u8) void {
    _ = game_scenes.switchScene(g, name, 0, 0, 0, 0, 0, 0, 0);
}

/// Update-list discard, then the game-over scene (1018:f17a "6fsaida").
fn gameOver(g: *Game) void {
    discardUpdates(g);
    _ = game_scenes.switchScene(g, "6fsaida", 0, 0, 0, 0, 0, 1, 0);
}

fn ptInAnswer(who: Who, question: i16, pic_x: i16, pic_y: i16, x: i16, y: i16) bool {
    if (question < 1 or question > 7) return false;
    const r = answer_rects[@backingInt(who)][@intCast(question - 1)];
    const left = pic_x +% r[0];
    const top = pic_y +% r[1];
    const right = pic_x +% r[2];
    const bottom = pic_y +% r[3];
    return x >= left and x < right and y >= top and y < bottom;
}

/// The books overlay and the question picture are erased and their cells
/// freed (done by all three answer cases).
fn eraseAndVacate(g: *Game, o: ?*Object, frame: u16) void {
    const obj = must(Object, o);
    const bd = bdOf(g);
    _ = frames.setCurFrame(obj, frame);
    frames.resetRects(obj);
    render.erase(g, obj, bd);
    _ = occupancy.vacate(g, obj, bd);
}

fn redrawOverlapping(g: *Game, o: ?*Object) void {
    visibility.redrawOverlapping(g, must(Object, o), bdOf(g), 0);
}

fn dropBooksAway(g: *Game, s: *State) void {
    space3d.moveToAndDrop(g, must(Object, s.books), 0x280, 0x1e0, bdOf(g));
}

/// A dialogue starts: pick the question, show its picture, play it.
fn startQuestion(g: *Game, s: *State, who: Who) i16 {
    s.question = ini.randomBelow(&g.rand, g.plat, 7) +% 1;
    if (who != .sportsman and s.unk0C70 != 0) s.question = 7;
    const books_frame: u16 = switch (who) {
        .esoteric => 1,
        .sportsman => 2,
        .vampire => 3,
    };
    const pic = switch (who) {
        .esoteric => s.speso,
        .sportsman => s.spesp,
        .vampire => s.spvam,
    };
    const speaker = switch (who) {
        .esoteric => s.esoteric,
        .sportsman => s.sportsman,
        .vampire => s.vampire,
    };
    // Walk the player's inventory: the book item (0xcf) puts the books
    // overlay up.
    const player = must(Object, must(Object, g.player).as(.player));
    s.talkingAnim = player.actor.inventory.head;
    while (s.talkingAnim) |t| : (s.talkingAnim = t.next) {
        if (t.id == BOOK_ITEM_ID) {
            const books = must(Object, s.books);
            space3d.moveToAndDrop(g, books, 0x30, 0x86, bdOf(g));
            _ = frames.setCurFrame(books, books_frame);
            redraw(g, books);
            _ = visibility.invalidate(g, books);
        }
    }
    const p = must(Object, pic);
    _ = frames.setCurFrame(p, @bitCast(s.question));
    redraw(g, p);
    _ = occupancy.occupy(g, p, bdOf(g));
    _ = visibility.invalidate(g, p);
    seekScene(g);
    s.questionWave = openIniWave(g, must(Object, speaker).id, s.question, p.id);
    _ = sound.play(g, msg.main_window, s.questionWave);
    s.idle = 0;
    s.unk0C70 = 0;
    return 0;
}

/// Right-button click start (0x204).
fn rightButtonDown(g: *Game, s: *State, m: Msg) i16 {
    const y = m.hi();
    if (y > 0x168 and panels.isOpen(g, must(Object, g.controlPanel))) {
        s.idle = 0;
        return 0;
    }
    if (s.idle == 0 and s.esotericDialog == 0 and s.vampireDialog == 0 and s.sportsmanDialog == 0) return 0;
    const bd = bdOf(g);
    const q = backdrop.queryRect(g, bd, @as(i16, @bitCast(m.lo())) +% bd.originX, @as(i16, @bitCast(y)) +% bd.originY, 0x10, 0x10);
    s.hitObject = q.obj;
    const hitFlag: i8 = @truncate(q.result);
    if (hitFlag <= 0) return 0;
    const hit = s.hitObject orelse return 0;
    switch (hit.id) {
        0x11c, 0xd3, 0xd4 => return 1,
        ESOTERIC_ID => {
            if (s.esotericDialog != 0 or s.vampireDialog != 0 or s.sportsmanDialog != 0) return 1;
            s.idle = 0;
            s.esotericDialog = 1;
            _ = g.send(Msg.make(msg.noite.animation_finished, 0, 0, 0));
            return 1;
        },
        SPORTSMAN_ID => {
            if (s.sportsmanDialog != 0 or s.vampireDialog != 0) return 1;
            s.idle = 0;
            s.sportsmanDialog = 1;
            _ = g.send(Msg.make(msg.noite.animation_finished, 0, 0, 0));
            return 1;
        },
        BARMAN_ID => {
            if (s.esotericDialog != 0 or s.vampireDialog != 0 or s.sportsmanDialog != 0) return 1;
            s.unk0C56 = 1;
            s.idle = 1;
            const barman = must(Object, s.barmanFront);
            playAnim(g, barman);
            _ = sound.play(g, msg.main_window, barman.wave);
            return 1;
        },
        VAMPIRE_ID => {
            if (s.vampireDialog != 0 or s.sportsmanDialog != 0) return 1;
            s.idle = 0;
            s.vampireDialog = 1;
            _ = g.send(Msg.make(msg.noite.animation_finished, 0, 0, 0));
            return 1;
        },
        0x11d, 0x11e, 0x124 => return 1,
        0x11f => return answerEsoteric(g, s, m),
        0x120 => return answerSportsman(g, s, m),
        0x121 => return answerVampire(g, s, m),
        else => return 0,
    }
}

/// The esoteric's question picture was clicked (0x11f).
fn answerEsoteric(g: *Game, s: *State, m: Msg) i16 {
    if (s.esotericDialog == 0) return 0;
    const pic = must(Object, s.speso);
    s.pictureX = pic.x;
    s.pictureY = pic.y;
    sound.stop(&g.sound, g.plat, s.questionWave);
    if (ptInAnswer(.esoteric, s.question, s.pictureX, s.pictureY, @bitCast(m.lo()), @bitCast(m.hi()))) s.idle = 1;
    reoccupyAll(g, s);
    eraseAndVacate(g, s.books, 0);
    eraseAndVacate(g, s.speso, 0);
    redrawOverlapping(g, s.books);
    redrawOverlapping(g, s.speso);
    reoccupyAll(g, s);
    dropBooksAway(g, s);
    s.esotericReply = 1;
    if (s.idle == 0) {
        s.esotericDialog = 0;
        s.idle = 1;
        g.lives -%= 1;
        if (g.lives < 0) {
            s.waveVariant = 0;
            s.unk0C56 = 0;
            s.unk0C5A = 0;
            s.unk0C5C = 0;
            s.vampireDialog = 0;
            s.sportsmanDialog = 0;
            s.vampireConvinced = 0;
            s.esotericReply = 0;
            s.sportsmanReply = 0;
            s.vampireReply = 0;
            s.offerCount = 0;
            s.unk0C6E = 0;
            s.unk0C70 = 0;
            // 1028:11ee "4FSACAET"
            gotoScene(g, "4FSACAET");
            gameOver(g);
            return 1;
        }
        playAnim(g, s.esotericAnim);
        playNamedWave(g, esoteric_wrong_wav);
        return 1;
    }
    resetAll(s);
    gotoScene(g, "4FSACAET");
    discardUpdates(g);
    gotoScene(g, "4FSACAET");
    return 1;
}

/// The sportsman's question picture was clicked (0x120).
fn answerSportsman(g: *Game, s: *State, m: Msg) i16 {
    if (s.sportsmanDialog == 0) return 0;
    // Original bug: the position comes from Speso, not Spesp.
    const pic = must(Object, s.speso);
    s.pictureX = pic.x;
    s.pictureY = pic.y;
    sound.stop(&g.sound, g.plat, s.questionWave);
    if (ptInAnswer(.sportsman, s.question, s.pictureX, s.pictureY, @bitCast(m.lo()), @bitCast(m.hi()))) s.idle = 1;
    eraseAndVacate(g, s.books, 0);
    eraseAndVacate(g, s.spesp, 0);
    reoccupyAll(g, s);
    redrawOverlapping(g, s.books);
    redrawOverlapping(g, s.spesp);
    dropBooksAway(g, s);
    s.sportsmanReply = 1;
    playAnim(g, s.sportsmanAnim);
    playNamedWave(g, sportsman_wrong_wav);
    if (s.idle != 0) {
        resetAll(s);
        discardUpdates(g);
        // 1028:125c "4FSALGIN"
        gotoScene(g, "4FSALGIN");
        return 1;
    }
    s.idle = 1;
    s.sportsmanDialog = 0;
    return loseLife(g, s);
}

/// The vampire's question picture was clicked (0x121).
fn answerVampire(g: *Game, s: *State, m: Msg) i16 {
    if (s.vampireDialog == 0) return 0;
    const pic = must(Object, s.spvam);
    s.pictureX = pic.x;
    s.pictureY = pic.y;
    sound.stop(&g.sound, g.plat, s.questionWave);
    if (ptInAnswer(.vampire, s.question, s.pictureX, s.pictureY, @bitCast(m.lo()), @bitCast(m.hi()))) s.vampireReply = 1;
    s.idle = 1;
    s.vampireDialog = 0;
    eraseAndVacate(g, s.books, 0);
    eraseAndVacate(g, s.spvam, 0);
    reoccupyAll(g, s);
    redrawOverlapping(g, s.spvam);
    redrawOverlapping(g, s.books);
    dropBooksAway(g, s);
    playAnim(g, s.vampireAnim);
    if (s.vampireReply == 0) {
        s.vampireReply = 1;
        playNamedWave(g, vampire_wrong_wav);
        return loseLife(g, s);
    }
    s.vampireConvinced = 1;
    playNamedWave(g, vampire_ok_wav);
    return 1;
}

/// `DEC g_lives; JNS` (the game is over only below 0), shared by the wrong
/// sportsman and vampire answers. Returns 1.
fn loseLife(g: *Game, s: *State) i16 {
    g.lives -%= 1;
    if (g.lives >= 0) return 1;
    s.waveVariant = 0;
    s.unk0C70 = 0;
    gameOver(g);
    return 1;
}

/// Plays the dropped item's reply from `who` (INI WAVE lookup keyed by the
/// speaker, the item) and its talking animation.
fn speak(g: *Game, s: *State, who: Who, hit_id: i16, item_id: i16) i16 {
    seekScene(g);
    const w = openIniWave(g, hit_id, s.waveVariant, item_id);
    _ = sound.play(g, msg.main_window, w);
    s.talkingAnim = switch (who) {
        .vampire => s.vampireAnim,
        .esoteric => s.esotericAnim,
        .sportsman => s.sportsmanAnim,
    };
    playAnim(g, s.talkingAnim);
    return 0;
}

/// Sends the angel down to fetch the item (right item given to the boy).
fn callAngel(g: *Game, s: *State) i16 {
    const angel = must(Object, s.angel);
    must(Object, angel.as(.mover)).mover.allowOffscreen = 1;
    movement.moveTo(g, angel, angel.x, 0xa4, bdOf(g));
    return 0;
}

fn clearSelection(g: *Game) i16 {
    g.itemSelected = 0;
    g.selectedItem = null;
    return 1;
}

/// Right button released with an item (0x205).
fn rightButtonUp(g: *Game, s: *State, m: Msg) i16 {
    if (g.itemSelected == 0) return 0;
    const bd = bdOf(g);
    const q = backdrop.queryRect(g, bd, @as(i16, @bitCast(m.lo())) +% bd.originX, @as(i16, @bitCast(m.hi())) +% bd.originY, 0x10, 0x10);
    s.hitObject = q.obj;
    const hitFlag: i8 = @truncate(q.result);
    if (hitFlag <= 0 or s.hitObject == null) return clearSelection(g);
    const hit = s.hitObject.?;
    if (hit.id != ESOTERIC_ID and hit.id != BOY_ID and hit.id != VAMPIRE_ID and hit.id != SPORTSMAN_ID) return clearSelection(g);
    s.offerCount +%= 1;
    if (s.offerCount == 0x19) {
        s.offerCount = 0xf;
        return 1;
    }
    seekScene(g);
    const item_id = must(Object, g.selectedItem).id;
    if (item_id == ITEM_A) {
        switch (hit.id) {
            ESOTERIC_ID => {
                s.unk0C70 = 1;
                return speak(g, s, .esoteric, hit.id, item_id);
            },
            VAMPIRE_ID => return speak(g, s, .vampire, hit.id, item_id),
            SPORTSMAN_ID => return speak(g, s, .sportsman, hit.id, item_id),
            else => {
                s.unk0C5A = 1;
                return callAngel(g, s);
            },
        }
    }
    if (item_id == ITEM_B) {
        switch (hit.id) {
            VAMPIRE_ID => {
                s.unk0C70 = 1;
                return speak(g, s, .vampire, hit.id, item_id);
            },
            ESOTERIC_ID => return speak(g, s, .esoteric, hit.id, item_id),
            SPORTSMAN_ID => return speak(g, s, .sportsman, hit.id, item_id),
            else => {
                s.unk0C5C = 1;
                return callAngel(g, s);
            },
        }
    }
    switch (hit.id) {
        ESOTERIC_ID => return speak(g, s, .esoteric, hit.id, item_id),
        VAMPIRE_ID => return speak(g, s, .vampire, hit.id, item_id),
        SPORTSMAN_ID => return speak(g, s, .sportsman, hit.id, item_id),
        else => return 1,
    }
}

/// A wave ended (MM_WOM_DONE, 0x3bd).
fn waveDone(g: *Game, s: *State) i16 {
    const bd = bdOf(g);
    if (s.unk0C56 != 0) {
        // The barman finished his line.
        s.unk0C56 = 0;
        stopAnim(g, s.barmanFront);
        redraw(g, s.esoteric);
        redraw(g, s.sportsman);
        redraw(g, s.boy);
        render.draw(g, must(Object, g.controlPanel), bd);
        backdrop.blitToDc(g, bd);
        discardUpdates(g);
        return 0;
    }
    if (s.unk0C5A != 0 or s.unk0C5C != 0) {
        // The angel's line ended: it flies off and the item is returned.
        stopAnim(g, s.angelAnim);
        restartTimer(g, s.angelAnim);
        s.idle = 1;
        s.unk0C5A = 0;
        s.unk0C5C = 0;
        const aa = must(Object, s.angelAnim);
        _ = frames.setCurFrame(aa, 0);
        redraw(g, aa);
        _ = visibility.invalidate(g, aa);
        const angel = must(Object, s.angel);
        redraw(g, angel);
        _ = visibility.invalidate(g, angel);
        must(Object, angel.as(.mover)).mover.allowOffscreen = 1;
        movement.moveTo(g, angel, angel.x, @bitCast(@as(u16, 0xff42)), bd);
        returnItem(g, s);
        reoccupy(g, s.boy);
        return 0;
    }
    if (s.vampireReply != 0) {
        s.vampireReply = 0;
        stopAnim(g, s.vampireAnim);
        if (s.vampireConvinced == 0) return 0;
        s.idle = 1;
        resetAll(s);
        discardUpdates(g);
        // 1028:1266 "4FJARVAMP"
        gotoScene(g, "4FJARVAMP");
        return 0;
    }
    if (s.sportsmanReply != 0) {
        s.sportsmanReply = 0;
        stopAnim(g, s.sportsmanAnim);
        s.sportsmanDialog = 0;
        return 1;
    }
    if (s.esotericReply != 0) {
        s.esotericReply = 0;
        stopAnim(g, s.esotericAnim);
        s.esotericDialog = 0;
        return 1;
    }
    if (s.vampireDialog != 0 or s.esotericDialog != 0 or s.sportsmanDialog != 0) return 1;
    if (s.unk0C70 != 0) {
        // The right item was accepted: it is consumed.
        const item = must(Object, g.selectedItem);
        visibility.hideAndInvalidate(g, item, 0, bd);
        _ = object_list.remove(&g.globalObjects, item);
        draw_list.remove(&g.drawList, item);
        _ = object_list.add(g, &g.usedObjects, item);
        stopAnim(g, s.talkingAnim);
        restartTimer(g, s.talkingAnim);
        reoccupy(g, s.hitObject);
        redraw(g, s.esoteric);
        redraw(g, s.vampire);
        redraw(g, s.boy);
        render.draw(g, must(Object, g.controlPanel), bd);
        backdrop.blitToDc(g, bd);
        discardUpdates(g);
        s.idle = 1;
        return 0;
    }
    // A wrong item: score penalty, it goes back to the inventory.
    if (g.itemSelected != 0) return 0;
    const item = g.selectedItem orelse return 0;
    if (s.hitObject == null) return 0;
    if (s.talkingAnim == null) return 0;
    g.score +%= item.portable.scoreMisuse;
    returnItem(g, s);
    stopAnim(g, s.talkingAnim);
    restartTimer(g, s.talkingAnim);
    reoccupyAll(g, s);
    g.selectedItem = null;
    s.hitObject = null;
    s.talkingAnim = null;
    s.idle = 1;
    return 0;
}

/// The selected item goes back to the player's inventory and is redrawn.
fn returnItem(g: *Game, s: *State) void {
    const bd = bdOf(g);
    const item = must(Object, g.selectedItem);
    const ret = must(Object, item.as(.portable));
    s.returnedItem = ret;
    _ = portable.pickUp(g, ret, must(Object, must(Object, g.player).as(.player)));
    frames.resetRects(ret);
    visibility.hideAndInvalidate(g, ret, 0, bd);
    visibility.redrawOverlapping(g, ret, bd, 0);
}

// @orig 1020:d5ee handler_4fbar
pub fn handle(g: *Game, m: Msg) i16 {
    const s = g.sceneState(State);
    switch (m.id) {
        msg.wm.mm_wom_done => return waveDone(g, s),
        msg.wm.mousemove => {
            const y = m.hi();
            if (y < 0x168 and panels.isOpen(g, must(Object, g.controlPanel))) return 0;
            if (y <= 0x168) return 1;
            return if (s.idle == 0) 1 else 0;
        },
        msg.wm.rbuttondown => return rightButtonDown(g, s, m),
        msg.wm.rbuttonup => return rightButtonUp(g, s, m),
        msg.noite.scene_started => {
            const bd = bdOf(g);
            redraw(g, s.barmanFront);
            redraw(g, s.esoteric);
            redraw(g, s.sportsman);
            redraw(g, s.boy);
            render.draw(g, must(Object, g.controlPanel), bd);
            return 0;
        },
        msg.noite.animation_finished => return animationFinished(g, s),
        msg.noite.movement_finished => {
            // The angel arrived: it speaks.
            if (s.unk0C5A == 0 and s.unk0C5C == 0) return 0;
            playAnim(g, s.angelAnim);
            _ = sound.play(g, msg.main_window, must(Object, s.angelAnim).wave);
            return 0;
        },
        msg.noite.object_created => {
            switch (m.wparam) {
                0x11c => s.angel = g.newObject,
                0x11d => s.angelAnim = g.newObject,
                0x11e => s.esotericAnim = g.newObject,
                0x11f => s.speso = g.newObject,
                0x120 => s.spesp = g.newObject,
                0x121 => s.spvam = g.newObject,
                0x124 => s.books = g.newObject,
                SPORTSMAN_ANIM_ID => s.sportsmanAnim = g.newObject,
                VAMPIRE_ANIM_ID => s.vampireAnim = g.newObject,
                0xd5 => s.esoteric = g.newObject,
                0xd6 => s.sportsman = g.newObject,
                0xd7 => s.barmanFront = g.newObject,
                0xd8 => s.boy = g.newObject,
                0xd9 => s.vampire = g.newObject,
                else => {},
            }
            return 0;
        },
        else => return 0,
    }
}

/// 0x403, sent to ourselves when a dialogue starts: show and say the
/// question.
fn animationFinished(g: *Game, s: *State) i16 {
    if (s.esotericDialog != 0) return startQuestion(g, s, .esoteric);
    if (s.vampireDialog != 0) return startQuestion(g, s, .vampire);
    if (s.sportsmanDialog != 0) return startQuestion(g, s, .sportsman);
    return 1;
}
