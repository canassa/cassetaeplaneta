//! Port unit `handler_fundini1` (handler). scene handler 1018:d31e.
//!
//! The in-game options screen (INI `[fundini1]`, scene 115): a title menu
//! plus a back button and a save button. Each button is a pair of objects:
//! a transparent hotspot that is hit-tested, and a "lit" picture shown while
//! the pointer is pressed on it. Back returns to the scene recorded when the
//! options were opened; save and load open the slot screen (`salvar2`); new
//! game loads slot 0 (`jogo0`); quit goes to the credits. `leaving` is a
//! latch set when the screen is left: the next back release only clears it.

const Game = @import("../core/game.zig").Game;
const Msg = @import("../core/msg.zig").Msg;
const msg = @import("../core/msg.zig");
const Object = @import("../core/object.zig").Object;
const cstr = @import("../core/cstr.zig");
const backdrop = @import("../backdrop.zig");
const frames = @import("../frames.zig");
const save = @import("../save.zig");
const update_list = @import("../update_list.zig");
const game_scenes = @import("../game_scenes.zig");
const visibility = @import("../behaviour/visibility.zig");

// INI object numbers (`[fundini1]` Local=).
const back_lit_id = 0x14a; // volta
const back_button_id = 0x14b; // voltrans
const play_panel_id = 0x14d; // inijogar
const play_hotspot_id = 0x14e; // t6
const quit_panel_id = 0x14f; // inisair
const quit_hotspot_id = 0x150; // t3
const save_hotspot_id = 0x151; // t5
const quit_now_lit_id = 0x152; // agora
const quit_later_lit_id = 0x153; // depois
const quit_now_hotspot_id = 0x154; // t1
const quit_later_hotspot_id = 0x155; // t2
const new_game_lit_id = 0x156; // novojogo
const load_game_lit_id = 0x157; // chamarjo
const new_game_hotspot_id = 0x158; // t7
const load_game_hotspot_id = 0x159; // t8
const save_lit_id = 0x15a; // salvarop

pub const State = struct {
    // @orig g_fundini1HitObject
    hitObject: ?*Object = null,
    // @orig g_fundini1Leaving
    leaving: i16 = 0,
    // @orig g_fundini1QuitPanel
    quitPanel: ?*Object = null,
    // @orig g_fundini1PlayPanel
    playPanel: ?*Object = null,
    // @orig g_fundini1SaveLit
    saveLit: ?*Object = null,
    // @orig g_fundini1QuitNowLit
    quitNowLit: ?*Object = null,
    // @orig g_fundini1QuitLaterLit
    quitLaterLit: ?*Object = null,
    // @orig g_fundini1NewGameLit
    newGameLit: ?*Object = null,
    // @orig g_fundini1LoadGameLit
    loadGameLit: ?*Object = null,
    // @orig g_fundini1BackLit
    backLit: ?*Object = null,
    // @orig g_fundini1QuitNowHotspot
    quitNowHotspot: ?*Object = null,
    // @orig g_fundini1QuitLaterHotspot
    quitLaterHotspot: ?*Object = null,
    // @orig g_fundini1NewGameHotspot
    newGameHotspot: ?*Object = null,
    // @orig g_fundini1LoadGameHotspot
    loadGameHotspot: ?*Object = null,
    // @orig g_fundini1SaveHotspot
    saveHotspot: ?*Object = null,
    // @orig g_fundini1PlayHotspot
    playHotspot: ?*Object = null,
    // @orig g_fundini1QuitHotspot
    quitHotspot: ?*Object = null,
    // @orig g_fundini1BackButton
    backButton: ?*Object = null,
};

// The original dereferences every one of these unchecked.
fn show(g: *Game, o: ?*Object) void {
    visibility.show(g, o.?, g.scene.?.backdrop.?);
}

fn invalidate(g: *Game, o: ?*Object) void {
    _ = visibility.invalidate(g, o.?);
}

/// GetDC/ReleaseDC dropped (one window, no hdc).
fn resetAndHide(g: *Game, o: ?*Object) void {
    frames.resetRects(o.?);
    visibility.hideAndInvalidate(g, o.?, 0, g.scene.?.backdrop.?);
}

/// The press (button down) side: light the pressed button.
fn pressed(g: *Game, s: *State, id: i16) i16 {
    switch (id) {
        back_button_id => {
            show(g, s.backLit);
            invalidate(g, s.backLit);
        },
        play_hotspot_id => {
            show(g, s.playPanel);
            invalidate(g, s.playPanel);
            show(g, s.newGameHotspot);
            show(g, s.loadGameHotspot);
        },
        quit_hotspot_id => {
            show(g, s.quitPanel);
            invalidate(g, s.quitPanel);
            show(g, s.quitNowHotspot);
            show(g, s.quitLaterHotspot);
        },
        save_hotspot_id => {
            show(g, s.saveLit);
            invalidate(g, s.saveLit);
        },
        quit_now_hotspot_id => {
            if (s.quitPanel.?.visible == 0) return 0;
            if (s.quitLaterLit.?.visible != 0) resetAndHide(g, s.quitLaterLit);
            show(g, s.quitNowLit);
            invalidate(g, s.quitNowLit);
        },
        quit_later_hotspot_id => {
            if (s.quitPanel.?.visible == 0) return 0;
            if (s.quitNowLit.?.visible != 0) resetAndHide(g, s.quitNowLit);
            show(g, s.quitLaterLit);
            invalidate(g, s.quitLaterLit);
        },
        new_game_hotspot_id => {
            if (s.playPanel.?.visible == 0) return 0;
            if (s.loadGameLit.?.visible != 0) resetAndHide(g, s.loadGameLit);
            show(g, s.newGameLit);
            invalidate(g, s.newGameLit);
            show(g, s.loadGameHotspot);
        },
        load_game_hotspot_id => {
            if (s.playPanel.?.visible == 0) return 0;
            if (s.newGameLit.?.visible != 0) resetAndHide(g, s.newGameLit);
            show(g, s.loadGameLit);
            invalidate(g, s.loadGameLit);
            show(g, s.newGameHotspot);
        },
        else => return 0,
    }
    return 1;
}

/// The release side: act on the button.
fn released(g: *Game, s: *State, id: i16) i16 {
    switch (id) {
        back_lit_id, back_button_id => {
            resetAndHide(g, s.backLit);
            show(g, s.backButton);
            if (s.leaving == 0) {
                s.leaving = 1;
                update_list.discard(&g.updateList);
                const p = &g.savedPosition;
                _ = game_scenes.switchScene(g, cstr.slice(&p.scene), p.playerX, p.playerY, p.hasPlayer, p.hasControlPanel, p.hasStatusBar, p.is1Animation, p.isClickExit);
                // Restart the control panel's animation timer.
                const cp = g.controlPanel.?;
                g.setSystemTimer(@bitCast(cp.anim.timerId), @bitCast(cp.anim.timerPeriod));
                return 1;
            }
            s.leaving = 0;
            return 1;
        },
        save_hotspot_id, save_lit_id => {
            resetAndHide(g, s.saveLit);
            show(g, s.saveHotspot);
            s.leaving = 1;
            g.slotScreenSaves = 1;
            update_list.discard(&g.updateList);
            _ = game_scenes.switchScene(g, "salvar2", 0, 0, 0, 0, 0, 0, 0);
            return 1;
        },
        quit_now_lit_id, quit_now_hotspot_id => {
            if (s.quitPanel.?.visible == 0) return 0;
            update_list.discard(&g.updateList);
            _ = game_scenes.switchScene(g, "creditos", 0, 0, 0, 0, 0, 0, 0);
            return 1;
        },
        quit_later_lit_id, quit_later_hotspot_id => {
            if (s.quitPanel.?.visible == 0) return 0;
            resetAndHide(g, s.quitPanel);
            resetAndHide(g, s.quitLaterLit);
            show(g, s.quitHotspot);
            return 1;
        },
        new_game_lit_id, new_game_hotspot_id => {
            if (s.playPanel.?.visible == 0) return 0;
            s.leaving = 1;
            _ = save.loadGame(g, "jogo0");
            return 1;
        },
        load_game_lit_id, load_game_hotspot_id => {
            if (s.playPanel.?.visible == 0) return 0;
            s.leaving = 1;
            g.slotScreenSaves = 0;
            update_list.discard(&g.updateList);
            _ = game_scenes.switchScene(g, "salvar2", 0, 0, 0, 0, 0, 0, 0);
            return 1;
        },
        else => return 0,
    }
}

// @orig 1018:d31e handler_fundini1
pub fn handle(g: *Game, m: Msg) i16 {
    const s = g.sceneState(State);
    switch (m.id) {
        msg.wm.lbuttondown, msg.wm.rbuttondown, msg.wm.lbuttonup, msg.wm.rbuttonup => {
            const bd = g.scene.?.backdrop.?;
            const q = backdrop.queryRect(g, bd, @as(i16, @bitCast(m.lo())) +% bd.originX, @as(i16, @bitCast(m.hi())) +% bd.originY, 0x10, 0x10);
            s.hitObject = q.obj;
            if (q.result < 1) return 0;
            const hit = s.hitObject orelse return 0;
            if (m.id == msg.wm.lbuttondown or m.id == msg.wm.rbuttondown) return pressed(g, s, hit.id);
            return released(g, s, hit.id);
        },
        msg.noite.scene_started => {
            show(g, s.quitNowHotspot);
            show(g, s.quitLaterHotspot);
            show(g, s.quitHotspot);
            show(g, s.saveHotspot);
            show(g, s.newGameHotspot);
            show(g, s.loadGameHotspot);
            show(g, s.backButton);
            show(g, s.playHotspot);
            return 0;
        },
        msg.noite.object_created => {
            const obj = g.newObject;
            switch (@as(i16, @bitCast(m.wparam))) {
                back_lit_id => {
                    s.backLit = obj;
                    resetAndHide(g, obj);
                },
                back_button_id => s.backButton = obj,
                play_panel_id => {
                    s.playPanel = obj;
                    resetAndHide(g, obj);
                },
                play_hotspot_id => s.playHotspot = obj,
                quit_panel_id => {
                    s.quitPanel = obj;
                    resetAndHide(g, obj);
                },
                quit_hotspot_id => s.quitHotspot = obj,
                save_hotspot_id => s.saveHotspot = obj,
                quit_now_lit_id => {
                    s.quitNowLit = obj;
                    resetAndHide(g, obj);
                },
                quit_later_lit_id => {
                    s.quitLaterLit = obj;
                    resetAndHide(g, obj);
                },
                quit_now_hotspot_id => s.quitNowHotspot = obj,
                quit_later_hotspot_id => s.quitLaterHotspot = obj,
                new_game_lit_id => {
                    s.newGameLit = obj;
                    resetAndHide(g, obj);
                },
                load_game_lit_id => {
                    s.loadGameLit = obj;
                    resetAndHide(g, obj);
                },
                new_game_hotspot_id => s.newGameHotspot = obj,
                load_game_hotspot_id => s.loadGameHotspot = obj,
                save_lit_id => {
                    s.saveLit = obj;
                    resetAndHide(g, obj);
                },
                else => {},
            }
            return 0;
        },
        else => return 0,
    }
}
