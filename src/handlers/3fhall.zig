//! Port unit `handler_3fhall` (handler). scene handler 1020:7b06.
//!
//! The hall with five doors. A right click on a door goes to the
//! destination shuffled to it once per run (sauna, the TIRO shooting
//! minigame, pharaoh, pope's punishment, disco entrance); the minigame's
//! result sends the player to the prison on a win or costs a life on a loss.
//! A click on the bottom strip (y 0x168..0x1cc, control panel closed) goes
//! to 3fentseg. A click that hits no door repeats the previous choice
//! (initially 0: the sauna).
//!
//! Original bugs reproduced: the shuffle happens once per run (B10, fix
//! `hall_shuffle_each_visit`) and the INI exit of door 139 to 3fpapclo is
//! never taken (B6, fix `pope_closet_reachable`).

const Game = @import("../core/game.zig").Game;
const Object = @import("../core/object.zig").Object;
const msg = @import("../core/msg.zig");
const Msg = msg.Msg;
const backdrop = @import("../backdrop.zig");
const cstr = @import("../core/cstr.zig");
const game_scenes = @import("../game_scenes.zig");
const ini = @import("../ini.zig");
const panels = @import("../panels.zig");
const update_list = @import("../update_list.zig");

pub const State = struct {
    // @orig g_s3fhallMinigameRunning
    minigameRunning: i16 = 0,
    // @orig g_s3fhallMinigameWnd
    minigameWnd: u16 = 0,
    // @orig g_s3fhallDoorChoice
    doorChoice: i16 = 0,
    // @orig g_s3fhallShuffleDoors
    shuffleDoors: i16 = 1,
    // @orig g_s3fhallDoorTargets
    doorTargets: [5]i16 = @splat(0),
    // @orig g_s3fhallHitObject
    hitObject: ?*Object = null,
    // @orig g_s3fhallShuffleCounter
    shuffleCounter: i16 = 0,
};

const minigame_title = "Tiro ao Alvaro"; // 1020:9be4

// @orig 1020:7b06 handler_3fhall
pub fn handle(g: *Game, m: Msg) i16 {
    const s = g.sceneState(State);
    if (s.shuffleDoors != 0) {
        s.shuffleDoors = 0;
        s.shuffleCounter = ini.randomBelow(&g.rand, g.plat, 5);
        for (&s.doorTargets) |*t| {
            t.* = s.shuffleCounter;
            s.shuffleCounter +%= 1;
            if (s.shuffleCounter > 4) s.shuffleCounter = 0;
        }
    }
    switch (m.id) {
        msg.wm.rbuttondown => return rightButton(g, s, m),
        msg.wm.timer => {
            if (m.wparam != 0x14) return 0;
            s.minigameWnd = g.plat.findWindow(minigame_title) orelse 0;
            if (s.minigameWnd == 0) return 0;
            g.killTimer(0x14);
            // PostMessage(minigame, 0x40b, 0, lParam = our window).
            _ = g.plat.postTo(s.minigameWnd, Msg{ .id = msg.noite.minigame_hello, .wparam = 0, .lparam = msg.main_window });
            return 0;
        },
        msg.wm.systimer => {
            if (s.minigameRunning == 0) return 0;
            if (g.plat.findWindow(minigame_title) == null) {
                // The minigame is gone without reporting: a lost game, score 0.
                _ = g.post(Msg.make(msg.noite.minigame_result, 0, 0, 0));
            }
            return 1;
        },
        msg.noite.scene_started => {
            if (g.fixes.hall_shuffle_each_visit) s.shuffleDoors = 1;
            return 0;
        },
        msg.noite.minigame_result => return minigameResult(g, s, m),
        msg.noite.minigame_ready => {
            s.minigameRunning = 1;
            g.plat.showMain(false);
            return 0;
        },
        else => return 0,
    }
}

/// Clear the minigame bookkeeping, then leave through `name`.
fn leave(g: *Game, s: *State, name: []const u8, x: i16, y: i16, has_player: i16, has_panel: i16, is_1animation: i16) i16 {
    s.minigameRunning = 0;
    s.minigameWnd = 0;
    update_list.discard(&g.updateList);
    _ = game_scenes.switchScene(g, name, x, y, has_player, has_panel, 0, is_1animation, 0);
    return 1;
}

fn rightButton(g: *Game, s: *State, m: Msg) i16 {
    const y = m.hi();
    if (y >= 0x168 and panels.isOpen(g, g.controlPanel.?)) return 0;
    const bd = g.scene.?.backdrop.?;
    const q = backdrop.queryRect(g, bd, @as(i16, @bitCast(m.lo())) +% bd.originX, @as(i16, @bitCast(y)) +% bd.originY, 0x10, 0x10);
    s.hitObject = q.obj;
    const hitFlag: i8 = @truncate(q.result);
    if (hitFlag > 0 and s.hitObject != null) {
        if (y >= 0x168 and !panels.isOpen(g, g.controlPanel.?) and y <= 0x1cc) {
            // 1020:9bda "3fentseg"
            return leave(g, s, "3fentseg", 0xf0, 0xaa, 1, 1, 0);
        }
        switch (s.hitObject.?.id) {
            0x8b => s.doorChoice = s.doorTargets[3],
            0x8c => s.doorChoice = s.doorTargets[4],
            0x8d => s.doorChoice = s.doorTargets[2],
            0x8e => s.doorChoice = s.doorTargets[1],
            0x8f => s.doorChoice = s.doorTargets[0],
            else => {},
        }
    }
    switch (s.doorChoice) {
        // 1020:9bf4 "3fsauna"
        0 => return leave(g, s, "3fsauna", 0, 0, 0, 0, 0),
        1 => {
            s.minigameRunning = 0;
            s.minigameWnd = 0;
            var buf: [257]u8 = undefined;
            // 1020:9bfc "tiro\\tiro.exe"
            const cmd = cstr.print(&buf, "{s}{s}", .{ cstr.slice(&g.driveCD), "tiro\\tiro.exe" });
            _ = g.plat.winExec(cmd);
            g.setTimer(0x14, 100);
            return 1;
        },
        // 1020:9c0a "3ffarao"
        2 => return leave(g, s, "3ffarao", 0, 0, 0, 0, 1),
        3 => {
            if (g.fixes.pope_closet_reachable) {
                // B6: take the INI exit of door 139 (3fpapclo).
                const sc = g.scene.?;
                for (sc.exits, 0..) |e, i| {
                    const eo = e orelse continue;
                    if (eo.id == 139) {
                        s.minigameRunning = 0;
                        s.minigameWnd = 0;
                        update_list.discard(&g.updateList);
                        _ = game_scenes.takeExit(g, @intCast(i));
                        return 1;
                    }
                }
            }
            // 1020:9c12 "3fpapmal"
            return leave(g, s, "3fpapmal", 0, 0, 0, 0, 1);
        },
        // 1020:9c1c "4finifes"
        4 => return leave(g, s, "4finifes", 0, 0, 0, 0, 0),
        else => return 1,
    }
}

/// 0x40a from TIRO: wParam = won, lParam = score.
fn minigameResult(g: *Game, s: *State, m: Msg) i16 {
    // GetDC + SelectPalette(backdrop palette) + RealizePalette + ReleaseDC
    g.plat.realizePalette(&g.scene.?.backdrop.?.bmiColors);
    s.minigameRunning = 0;
    g.plat.showMain(true);
    g.minigameWon[1] = @intFromBool(m.wparam != 0);
    g.score +%= m.lparam;
    if (g.minigameWon[1] != 0) {
        update_list.discard(&g.updateList);
        // 1020:9c26 "3fprisao"
        _ = game_scenes.switchScene(g, "3fprisao", 0xf0, 0xc8, 1, 1, 0, 0, 0);
        return 0;
    }
    g.lives -%= 1;
    update_list.discard(&g.updateList);
    if (g.lives != 0) {
        // 1020:9c30 "3fhall"
        _ = game_scenes.switchScene(g, "3fhall", 0xf0, 0xc8, 1, 1, 0, 0, 0);
    } else {
        // 1018:f17a "6fsaida"
        _ = game_scenes.switchScene(g, "6fsaida", 0, 0, 0, 0, 0, 1, 0);
    }
    return 0;
}
