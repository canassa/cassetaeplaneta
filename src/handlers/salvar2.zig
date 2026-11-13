//! Port unit `handler_salvar2` (handler). scene handler 1018:de58.
//!
//! The save/load slot screen. Five slot objects (INI Numbers 0x143..0x147)
//! have a highlighted twin each ("lit": 0x148, 0x13f..0x142). Pressing a
//! slot shows its lit twin; on release the lit twin is hidden, the slot
//! shown again, and the game is saved (when `g.slotScreenSaves` is set; then
//! the scene recorded by the options menu is resumed and the control
//! panel's timer re-armed) or loaded from `jogoN`. The original also does
//! GetDC/ReleaseDC around the redraws; they have no effect here.

const Game = @import("../core/game.zig").Game;
const Msg = @import("../core/msg.zig").Msg;
const msg = @import("../core/msg.zig");
const Object = @import("../core/object.zig").Object;
const update_list = @import("../update_list.zig");
const backdrop = @import("../backdrop.zig");
const frames = @import("../frames.zig");
const visibility = @import("../behaviour/visibility.zig");
const game_scenes = @import("../game_scenes.zig");
const save = @import("../save.zig");
const cstr = @import("../core/cstr.zig");

pub const State = struct {
    // @orig g_salvar2HitObject
    hitObject: ?*Object = null,
    // @orig g_salvar2Slot1 .. g_salvar2Slot5
    slot: [5]?*Object = @splat(null),
    // @orig g_salvar2Slot1Lit .. g_salvar2Slot5Lit
    lit: [5]?*Object = @splat(null),
};

const SLOT1_ID: u16 = 0x143;
/// INI Number of slot N's lit twin: slot 1 is 0x148, slots 2..5 are 0x13f..0x142.
const LIT1_ID: u16 = 0x148;
const LIT2_ID: u16 = 0x13f;

const save_names = [5][]const u8{ "Jogo1", "Jogo2", "Jogo3", "Jogo4", "Jogo5" };
const load_names = [5][]const u8{ "jogo1", "jogo2", "jogo3", "jogo4", "jogo5" };

/// Slot index of an INI Number (slot or lit twin), or null.
fn slotOf(id: u16) ?usize {
    if (id >= SLOT1_ID and id <= SLOT1_ID + 4) return id - SLOT1_ID;
    if (id == LIT1_ID) return 0;
    if (id >= LIT2_ID and id <= LIT2_ID + 3) return id - LIT2_ID + 1;
    return null;
}

/// The query shared by presses and releases; sets the hit object and
/// returns whether it is usable.
fn hit(g: *Game, s: *State, m: Msg) bool {
    const bd = g.scene.?.backdrop.?;
    const q = backdrop.queryRect(g, bd, @as(i16, @bitCast(m.lo())) +% bd.originX, @as(i16, @bitCast(m.hi())) +% bd.originY, 0x10, 0x10);
    s.hitObject = q.obj;
    return q.result >= 1 and s.hitObject != null;
}

fn release(g: *Game, s: *State, i: usize) i16 {
    const bd = g.scene.?.backdrop.?;
    const lit = s.lit[i].?;
    frames.resetRects(lit);
    visibility.hideAndInvalidate(g, lit, 0, bd);
    visibility.show(g, s.slot[i].?, g.scene.?.backdrop.?);
    if (g.slotScreenSaves == 0) {
        _ = save.loadGame(g, load_names[i]);
        return 1;
    }
    save.saveGame(g, save_names[i]);
    const sp = &g.savedPosition;
    _ = game_scenes.switchScene(g, cstr.slice(&sp.scene), sp.playerX, sp.playerY, sp.hasPlayer, sp.hasControlPanel, sp.hasStatusBar, sp.is1Animation, sp.isClickExit);
    const cp = g.controlPanel.?;
    g.setSystemTimer(@bitCast(cp.anim.timerId), @bitCast(cp.anim.timerPeriod));
    return 1;
}

// @orig 1018:de58 handler_salvar2
pub fn handle(g: *Game, m: Msg) i16 {
    const s = g.sceneState(State);
    switch (m.id) {
        msg.wm.lbuttondown, msg.wm.rbuttondown => {
            if (!hit(g, s, m)) return 0;
            const id: u16 = @bitCast(s.hitObject.?.id);
            if (id < SLOT1_ID or id > SLOT1_ID + 4) return 0;
            const lit = s.lit[id - SLOT1_ID].?;
            visibility.show(g, lit, g.scene.?.backdrop.?);
            _ = visibility.invalidate(g, lit);
            return 1;
        },
        msg.wm.lbuttonup, msg.wm.rbuttonup => {
            if (!hit(g, s, m)) return 0;
            update_list.discard(&g.updateList);
            const i = slotOf(@bitCast(s.hitObject.?.id)) orelse return 0;
            return release(g, s, i);
        },
        msg.noite.object_created => {
            const i = slotOf(m.wparam) orelse return 0;
            const new = g.newObject;
            if (m.wparam >= SLOT1_ID and m.wparam <= SLOT1_ID + 4) {
                s.slot[i] = new;
            } else {
                s.lit[i] = new;
                frames.resetRects(new.?);
                visibility.hideAndInvalidate(g, new.?, 0, g.scene.?.backdrop.?);
            }
            return 0;
        },
        else => return 0,
    }
}
