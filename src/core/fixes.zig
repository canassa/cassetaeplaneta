//! Fixes for the original game's bugs (BUGS.md). Every flag defaults to
//! `false`: the port reproduces the original. A unit that ports buggy code
//! reads `g.fixes.<flag>` at the bug site and keeps both paths.
//!
//! Not bugs but choices: `quit_on_ini_error` (quit where the original only
//! shows a message box and carries on).
//!
//! Latent bugs (L*) are not flags: the port never executes them either,
//! and where it would, it returns an error instead of corrupting memory (or,
//! where the callers cannot return errors, truncates / drops the write /
//! panics naming the bug: L5–L7).
//! Add a flag here (with its BUGS.md id) when you port a bug's site.

const std = @import("std");

pub const Fixes = struct {
    /// B1: 2fsuabig, 2fasspap and 4fboydj take a life without the game-over
    /// test; with the fix they switch to `6fsaida` when lives reach 0.
    lives_game_over: bool = false,
    /// B2: open the 4fpistav dance music from a path that exists.
    dance_music_path: bool = false,
    /// B3: drop the doubled `.WAV.WAV` in 2fcopmau/2fcopmu time-out waves.
    double_wav_extension: bool = false,
    /// B4: close the save file after loading a game.
    close_loaded_save: bool = false,
    /// B5: 2ffesta3 skips the remark when the previous scene has none.
    festa3_uninitialised_path: bool = false,
    /// B6: the hall door to 3fpapclo leads to the closet game.
    pope_closet_reachable: bool = false,
    /// B10: reshuffle the 3fhall doors on every visit.
    hall_shuffle_each_visit: bool = false,
    /// B12: the opaque row copy copies black pixels at row ends too.
    opaque_copy_black_tail: bool = false,
    /// B13: load_dib closes a bitmap file it cannot read as a DIB.
    close_unreadable_dib: bool = false,
    /// B14: the scene destructor deletes the Is_1Animation scene's own
    /// animation object (and its bitmaps) too.
    free_scene_animation: bool = false,
    /// B15: a right click in 3fhall that hits no door does nothing (instead
    /// of taking the last door chosen again).
    hall_door_click_only: bool = false,
    /// B16: 4fbarboy adds the right item's `scoreUse` like the other scenes.
    barboy_right_item_score: bool = false,
    /// B17: 2fcopmu returns after switching to the arrest scene (no
    /// garots05 over it, no stale greeting flags).
    roadblock_return_after_switch: bool = false,
    /// B20: 2fshardi waits for 2sshaa's animation after the right item
    /// instead of replaying it on every (instant, the wave is missing)
    /// MM_WOM_DONE, which freezes the game.
    shardi_reply_once: bool = false,
    /// B21: a one-animation scene's video exit is not ticked by an
    /// animation timer that another scene left running (which takes the
    /// exit when the video ends: 3fstreet skips XILINDRO, 3ffarao exits to
    /// the missing `JTETRIS` section, a fatal INI error).
    avi_exit_ignores_timer: bool = false,
    /// B24: 4fbarboy and 2fsuabig ignore a wave end with no item selected
    /// instead of reading through the NULL item (a GPF in the original).
    reply_without_item: bool = false,
    /// B19: the control panel shows, and the save keeps, the whole 32-bit
    /// score (not its low word).
    score_32bit: bool = false,
    /// B25: an item dropped where it stays (no walk to a resting place)
    /// takes its position as its previous one, so picking it up again
    /// erases its image.
    drop_syncs_previous_position: bool = false,
    /// B26: entering a scene cancels the player's walk, so the next timer
    /// tick does not resume the old scene's walk (and leave a frame behind).
    scene_entry_stops_walk: bool = false,
    /// B27: the control panel's lives and score follow the panel art's
    /// boxes as it slides (per-frame y) instead of 20-pixel steps.
    panel_text_follows_art: bool = false,
    /// B28: a right click on an exit plays its wave only when the click
    /// takes the exit (player within reach, exit enabled).
    exit_sound_needs_reach: bool = false,
    /// B29: a vacate (an item picked up, an object hidden or stepping)
    /// points the cells other objects still occupy back at one of them, so
    /// an item that lay under or next to it can still be right-clicked.
    vacate_keeps_other_occupants: bool = false,
    /// B30: a dropped item falls straight down onto the first real support
    /// (a 3D box under it whose top is below the release point) or to the
    /// floor row; it never rises, and a door or picture never holds it up.
    drop_falls_onto_support: bool = false,
    /// B31: an object whose elevation is the top of another's 3D box, with
    /// overlapping hit boxes, is in front of it in the draw order (the
    /// sitting room's package is no longer cut by the table's redraws).
    item_on_support_in_front: bool = false,
    /// B32: a scene animation's frame (the sitting room's cat) is not drawn
    /// over the control panel and status bar: they are drawn back into the
    /// backdrop before the scene's timer puts the frame on the screen.
    bars_over_scene_animation: bool = false,
    /// B33: a `Static=` object met again (the kitchen's cockroach and
    /// ketchup, the parents' room's father) is drawn whole on re-entry, not
    /// only the part the last overlap of the previous visit left dirty.
    static_redraw_whole_frame: bool = false,
    /// Not a bug but a Corrigida addition (BUGS.md, "Corrigida additions"):
    /// while an inventory item is dragged out of the control panel (right
    /// button held), its panel icon follows the pointer. The original shows
    /// nothing. Drawn over the presented frame (`Screen.overlay`), never
    /// into the screen or the backdrop; game logic is unchanged.
    drag_shows_item: bool = false,
    /// Not a bug but a Corrigida addition (BUGS.md, "Corrigida additions"):
    /// a dropped item's fall is drawn in 2-row frames between its 10-row
    /// steps (same steps, same end, same timing).
    smooth_item_fall: bool = false,
    /// U1: draw the status-bar text.
    status_bar_text: bool = false,
    /// `ini_fatal_error` ("Erro Fatal!") quits (`error.Fatal`) instead of
    /// returning 0 and letting the caller carry on as the original does.
    quit_on_ini_error: bool = false,

    /// Every bug fix (`--fix all`, the web build's "Corrigida" version):
    /// all flags but `quit_on_ini_error`, which is a choice.
    pub fn all() Fixes {
        var f: Fixes = .{};
        _ = f.set("all");
        return f;
    }

    /// Turns on the fix `name` (a field name) or, for `all`, every bug
    /// fix; `-name` turns it off again (`all,-hall_shuffle_each_visit`).
    /// False if `name` is neither.
    pub fn set(f: *Fixes, name: []const u8) bool {
        const off = name.len > 0 and name[0] == '-';
        const n = if (off) name[1..] else name;
        var found = false;
        inline for (@typeInfo(Fixes).@"struct".field_names) |field| {
            const in_all = std.mem.eql(u8, n, "all") and !std.mem.eql(u8, field, "quit_on_ini_error");
            if (in_all or std.mem.eql(u8, n, field)) {
                @field(f, field) = !off;
                found = true;
            }
        }
        return found;
    }
};

test "all is every bug fix, not the INI-error choice" {
    const f = Fixes.all();
    try std.testing.expect(f.lives_game_over and f.status_bar_text and f.score_32bit);
    try std.testing.expect(!f.quit_on_ini_error);
    var g: Fixes = .{};
    try std.testing.expect(g.set("dance_music_path") and g.dance_music_path and !g.lives_game_over);
    try std.testing.expect(!g.set("nonsense"));
    var h = Fixes.all();
    try std.testing.expect(h.set("-hall_shuffle_each_visit") and !h.hall_shuffle_each_visit and h.score_32bit);
}
