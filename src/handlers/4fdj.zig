//! Port unit `handler_4fdj` (handler). scene handler 1020:b7ac.
//!
//! The DJ booth. Right-clicking the DJ (or his spot) greets, then opens the
//! request panel, whose three buttons walk a small dialogue (`menuState`):
//! the right path leads to the dance floor (`4fpistav`), a wrong one back to
//! the bar (`4fbarbo2`). When he asks for an item, handing over item 0x6c
//! (dropped on the DJ or his spot) leads to the dance floor too, any other
//! item to the bar.
//!
//! The scene's looping dance music starts with the scene (0x401).
//!
//! Original bug (BUGS.md B7): `offerCount` is only ever tested and cleared,
//! never incremented, so the "more than three offers" way out is dead. It is
//! kept as it is (there is no `Fixes` flag for it).

const Game = @import("../core/game.zig").Game;
const Msg = @import("../core/msg.zig").Msg;
const msg = @import("../core/msg.zig");
const Object = @import("../core/object.zig").Object;
const Rect = @import("../core/object.zig").Rect;
const world = @import("../core/world.zig");
const Backdrop = world.Backdrop;
const Scene = world.Scene;
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
const sound = @import("../sound.zig");
const update_list = @import("../update_list.zig");

/// Object ids (INI Number).
const DJ_ID: i16 = 0xec;
const LIGHTS_ID: i16 = 0xed;
const DJ_SPOT_ID: i16 = 0x123;
const PANEL_ID: i16 = 0x12f;
/// The item the DJ wants.
const WANTED_ITEM: i16 = 0x6c;

const wav_dance = "fase4\\4fboydj\\dance2.wav";
const wav_dj2 = "fase4\\4fboydj\\dj2.wav";
const wav_dj3 = "fase4\\4fboydj\\dj3.wav";
const wav_dj4 = "fase4\\4fboydj\\dj4.wav";
const wav_dj5 = "fase4\\4fboydj\\dj5.wav";
const wav_dj6 = "fase4\\4fboydj\\dj6.wav";
const wav_pede = "fase4\\4fboydj\\djpede.wav";
const wav_right = "fase4\\4fboydj\\djrespb2.wav";
const wav_wrong = "fase4\\4fboydj\\djrespr.wav";

/// Not in the original: an item released here that reaches the engine was
/// offered to a character (`game.handlerAnswersOffers`, B30's fix).
pub const answers_offers = true;

pub const State = struct {
    // @orig g_s4fdjGreetingPlaying
    greetingPlaying: i16 = 0,
    // @orig g_s4fdjMenuIntroPlaying
    menuIntroPlaying: i16 = 0,
    // @orig g_s4fdjPanelShown
    panelShown: i16 = 0,
    // @orig g_s4fdjFailed
    failed: i16 = 0,
    // @orig g_s4fdjSucceeded
    succeeded: i16 = 0,
    // @orig g_s4fdjPanelAllowed
    panelAllowed: i16 = 0,
    // @orig g_s4fdjAskingItem
    askingItem: i16 = 0,
    // @orig g_s4fdjUnk0C1E
    unk0C1E: i16 = 0,
    // @orig g_s4fdjGreeted
    greeted: i16 = 0,
    // @orig g_s4fdjMenuOpened
    menuOpened: i16 = 0,
    // @orig g_s4fdjOfferCount
    offerCount: i16 = 0,
    // @orig g_s4fdjMenuState
    menuState: i16 = 0,
    // @orig g_s4fdjItemAccepted
    itemAccepted: i16 = 0,
    // @orig g_s4fdjUnk0C2A
    unk0C2A: i16 = 0,
    // @orig g_s4fdjHitObject
    hitObject: ?*Object = null,
    // @orig g_s4fdjDjSpot
    djSpot: ?*Object = null,
    // @orig g_s4fdjDj
    dj: ?*Object = null,
    // @orig g_s4fdjLights
    lights: ?*Object = null,
    // @orig g_s4fdjRequestPanel
    requestPanel: ?*Object = null,
    // @orig g_s4fdjPanelX
    panelX: i16 = 0,
    // @orig g_s4fdjPanelY
    panelY: i16 = 0,
    // @orig g_s4fdjButtonRects (BSS, zero)
    buttonRects: [3]Rect = @splat(.{}),
};

/// The original's unchecked pointers: a missing one is a crash there.
fn must(comptime T: type, p: ?*T) *T {
    return p orelse @panic("4fdj: null pointer");
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

fn ptInRect(r: Rect, x: i16, y: i16) bool {
    return x >= r.left and x < r.right and y >= r.top and y < r.bottom;
}

fn query(g: *Game, s: *State, m: Msg) i8 {
    const bd = bdOf(g);
    const q = backdrop.queryRect(g, bd, @as(i16, @bitCast(m.lo())) +% bd.originX, @as(i16, @bitCast(m.hi())) +% bd.originY, 16, 16);
    s.hitObject = q.obj;
    return q.result;
}

/// Stops the DJ's animation and re-arms its system timer.
fn stopDj(g: *Game, s: *State) void {
    const dj = must(Object, s.dj);
    animation.stopAndRedraw(g, dj, bdOf(g));
    const a = anim(dj);
    g.setSystemTimer(@bitCast(a.anim.timerId), @bitCast(a.anim.timerPeriod));
}

fn playDj(g: *Game, s: *State) void {
    tick.play(g, anim(s.dj), bdOf(g));
}

/// The state reset of every way out of the scene.
fn resetAll(s: *State) void {
    s.greetingPlaying = 0;
    s.menuIntroPlaying = 0;
    s.panelShown = 0;
    s.failed = 0;
    s.succeeded = 0;
    s.panelAllowed = 0;
    s.askingItem = 0;
    s.unk0C1E = 0;
    s.greeted = 0;
    s.menuOpened = 0;
    s.offerCount = 0;
    s.menuState = 0;
    s.itemAccepted = 0;
    s.unk0C2A = 0;
}

/// Back to the bar.
fn leaveFailed(g: *Game, s: *State) void {
    animation.stopAndRedraw(g, must(Object, s.dj), bdOf(g));
    resetAll(s);
    update_list.discard(&g.updateList);
    _ = game_scenes.switchScene(g, "4FBARBO2", 0, 0, 0, 1, 0, 0, 0);
}

/// To the dance floor.
fn leaveSucceeded(g: *Game, s: *State) void {
    resetAll(s);
    update_list.discard(&g.updateList);
    _ = game_scenes.switchScene(g, "4FPISTAV", 0, 0, 0, 0, 0, 0, 0);
}

/// Shows the request panel at its current frame.
fn redrawPanel(g: *Game, s: *State) void {
    const p = must(Object, s.requestPanel);
    frames.resetRects(p);
    render.draw(g, p, bdOf(g));
    _ = visibility.invalidate(g, p);
}

// @orig 1020:b7ac handler_4fdj
pub fn handle(g: *Game, m: Msg) i16 {
    const s = g.sceneState(State);
    switch (m.id) {
        msg.wm.mousemove => {
            if (m.hi() <= 0x168) return 0;
            return @intFromBool(s.panelAllowed == 0);
        },
        msg.wm.rbuttondown => return rightDown(g, s, m),
        msg.wm.rbuttonup => return rightUp(g, s, m),
        msg.wm.mm_wom_done => return waveDone(g, s),
        msg.noite.scene_started => {
            _ = g.plat.mciString("pause musica");
            const w = sound.open(g, ini.concatStrings(&g.concatBuf, &g.driveCD, wav_dance)) catch |e| die(e);
            _ = sound.playLoop(g, msg.main_window, w);
            tick.play(g, anim(s.lights), bdOf(g));
            return 0;
        },
        msg.noite.object_created => {
            switch (@as(i16, @bitCast(m.wparam))) {
                DJ_ID => s.dj = g.newObject,
                LIGHTS_ID => s.lights = g.newObject,
                DJ_SPOT_ID => s.djSpot = g.newObject,
                PANEL_ID => s.requestPanel = g.newObject,
                else => {},
            }
            return 0;
        },
        else => return 0,
    }
}

/// An item dropped on the DJ or his spot.
fn rightUp(g: *Game, s: *State, m: Msg) i16 {
    if (g.itemSelected == 0) return 0;
    if (query(g, s, m) < 1 or s.hitObject == null) return clearSelection(g);
    const hit = must(Object, s.hitObject);
    if (hit.id != DJ_ID and hit.id != DJ_SPOT_ID) return clearSelection(g);
    const item = must(Object, must(Object, g.selectedItem).as(.portable));
    if (item.id == WANTED_ITEM) {
        s.itemAccepted = 1;
        playCdWave(g, wav_right);
        playDj(g, s);
        return 0;
    }
    s.menuState = 0;
    s.failed = 1;
    playCdWave(g, wav_wrong);
    playDj(g, s);
    return 1;
}

fn clearSelection(g: *Game) i16 {
    g.itemSelected = 0;
    g.selectedItem = null;
    return 1;
}

fn rightDown(g: *Game, s: *State, m: Msg) i16 {
    if (query(g, s, m) < 1) return 0;
    const hit = s.hitObject orelse return 0;
    switch (hit.id) {
        LIGHTS_ID => return 1,
        DJ_ID, DJ_SPOT_ID => {
            if (s.greetingPlaying == 0 and s.greeted == 0) {
                s.greetingPlaying = 1;
                s.greeted = 1;
                playDj(g, s);
                _ = sound.play(g, msg.main_window, must(Object, s.dj).wave);
            } else {
                if (s.menuOpened != 0) return 1;
                s.menuIntroPlaying = 1;
                s.menuOpened = 1;
                playDj(g, s);
                _ = sound.play(g, msg.main_window, must(Object, s.requestPanel).wave);
            }
            return 1;
        },
        PANEL_ID => return panelClick(g, s, m),
        else => return 0,
    }
}

/// A click on the request panel: the button hit and the current state pick
/// the next state and the DJ's wave.
fn panelClick(g: *Game, s: *State, m: Msg) i16 {
    if (s.panelShown == 0) return 1;
    const p = must(Object, s.requestPanel);
    s.panelX = p.x;
    s.panelY = p.y;
    const px = s.panelX;
    const py = s.panelY;
    s.buttonRects[0] = .{ .left = px +% 0x2a, .top = py +% 0xd, .right = px +% 0xe3, .bottom = py +% 0x4d };
    s.buttonRects[1] = .{ .left = px +% 9, .top = py +% 0x66, .right = px +% 0xf8, .bottom = py +% 0x94 };
    s.buttonRects[2] = .{ .left = px +% 0x1a, .top = py +% 0xb3, .right = px +% 0xee, .bottom = py +% 0xfe };
    const x: i16 = @bitCast(m.lo());
    const y: i16 = @bitCast(m.hi());
    var wav: ?[]const u8 = null;
    if (ptInRect(s.buttonRects[0], x, y)) {
        switch (s.menuState) {
            1, 2, 4, 6 => {
                s.menuState = 5;
                wav = wav_dj5;
            },
            3 => {
                s.menuState = 5;
                wav = wav_dj3;
            },
            5 => wav = wrongAnswer(s),
            else => {},
        }
    } else if (ptInRect(s.buttonRects[1], x, y)) {
        switch (s.menuState) {
            1 => {
                s.menuState = 3;
                wav = wav_dj3;
            },
            2 => {
                s.menuState = 4;
                wav = wav_dj4;
            },
            3 => {
                s.menuState = 5;
                wav = wav_dj3;
            },
            4 => {
                s.menuState = 5;
                wav = wav_dj5;
            },
            5 => wav = wrongAnswer(s),
            6 => {
                s.succeeded = 1;
                s.menuState = 0;
                wav = wav_right;
            },
            else => {},
        }
    } else if (ptInRect(s.buttonRects[2], x, y)) {
        switch (s.menuState) {
            1 => {
                s.menuState = 2;
                wav = wav_dj2;
            },
            2, 4 => {
                s.menuState = 6;
                wav = wav_dj6;
            },
            3 => {
                s.menuState = 4;
                wav = wav_dj4;
            },
            5 => wav = wrongAnswer(s),
            6 => {
                s.askingItem = 1;
                s.menuState = 0;
                wav = wav_pede;
            },
            else => {},
        }
    } else return 1;
    if (wav) |w| playCdWave(g, w);
    playDj(g, s);
    return 1;
}

fn wrongAnswer(s: *State) []const u8 {
    s.menuState = 0;
    s.failed = 1;
    return wav_wrong;
}

fn waveDone(g: *Game, s: *State) i16 {
    if (s.greetingPlaying != 0) {
        s.greetingPlaying = 0;
        stopDj(g, s);
        return 0;
    }
    if (s.menuIntroPlaying != 0) {
        s.menuIntroPlaying = 0;
        stopDj(g, s);
        s.menuState = 1;
        _ = frames.setCurFrame(must(Object, s.requestPanel), 1);
        redrawPanel(g, s);
        s.panelShown = 1;
        return 0;
    }
    if (s.menuState != 0) {
        stopDj(g, s);
        _ = frames.setCurFrame(must(Object, s.requestPanel), @bitCast(s.menuState));
        redrawPanel(g, s);
        return 0;
    }
    if (s.failed != 0) {
        leaveFailed(g, s);
        return 0;
    }
    if (s.succeeded != 0) {
        animation.stopAndRedraw(g, must(Object, s.dj), bdOf(g));
        leaveSucceeded(g, s);
        return 0;
    }
    if (s.askingItem != 0) {
        s.askingItem = 0;
        s.panelAllowed = 1;
        stopDj(g, s);
        s.menuState = 0;
        const p = must(Object, s.requestPanel);
        _ = frames.setCurFrame(p, 0);
        frames.resetRects(p);
        visibility.hideAndInvalidate(g, p, 0, bdOf(g));
        return 0;
    }
    if (s.itemAccepted != 0) {
        const item = must(Object, g.selectedItem);
        visibility.hideAndInvalidate(g, item, 0, bdOf(g));
        _ = object_list.remove(&g.globalObjects, item);
        draw_list.remove(&g.drawList, item);
        _ = object_list.add(g, &g.usedObjects, item);
        animation.stopAndRedraw(g, must(Object, s.dj), bdOf(g));
        leaveSucceeded(g, s);
        return 0;
    }
    // Dead in the original too: the counter is never incremented (B7).
    if (s.offerCount > 3) {
        leaveFailed(g, s);
    }
    return 0;
}
