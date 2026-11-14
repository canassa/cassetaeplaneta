//! Fixes for the original game's bugs (BUGS.md). Every flag defaults to
//! `false`: the port reproduces the original. A unit that ports buggy code
//! reads `g.fixes.<flag>` at the bug site and keeps both paths.
//!
//! Choices, not bug fixes, left out of `all` (`choices`):
//! `quit_on_ini_error` (quit where the original only shows a message box
//! and carries on) and `hall_shuffle_each_visit` (the original shuffles the
//! hall's doors once per run, by design).
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
    /// A choice, left out of `all`: reshuffle the 3fhall doors on every
    /// visit instead of once per run (the original's design).
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
    /// An item offered to a character (a drop in a scene whose handler
    /// answers offers) stays where it was released, in the character's hands.
    drop_falls_onto_support: bool = false,
    /// B31: an object whose elevation is the top of another's 3D box, with
    /// overlapping hit boxes, is in front of it in the draw order (the
    /// sitting room's package is no longer cut by the table's redraws).
    item_on_support_in_front: bool = false,
    /// B32: a scene animation's frame (the sitting room's cat) is not drawn
    /// over the control panel and status bar: they are drawn back into the
    /// backdrop before the scene's timer puts the frame on the screen (and
    /// with it whatever else is queued, e.g. a just-picked item's erased
    /// box cutting the lives "3").
    bars_over_scene_animation: bool = false,
    /// B33: a `Static=` object met again (the kitchen's cockroach and
    /// ketchup, the parents' room's father) is drawn whole on re-entry, not
    /// only the part the last overlap of the previous visit left dirty.
    static_redraw_whole_frame: bool = false,
    /// B23: until the reply to an offer ends, the right button does nothing
    /// (it would select another item, or clear the handler's hit object),
    /// so the reply's end takes back, or consumes, the offered item.
    reply_keeps_offer: bool = false,
    /// B45: the wine given to 2fportdi's driver is not drawn again over the
    /// drinking animation, which shows the bottle in his hand.
    drinker_takes_bottle: bool = false,
    /// B40: 2fportdi's driver is drawn in front of the passing bushes, not
    /// behind them (they showed through his face).
    driver_in_front_of_scenery: bool = false,
    /// B41: 4fbarbo2 lets the control panel open (Opções: save, load,
    /// quit) instead of swallowing every mouse move near the bottom.
    bar_panel_opens: bool = false,
    /// B34: the open control panel is redrawn on the screen when the
    /// inventory changes under it (an offered item handed back to the
    /// first slot), so its icons are the items a drag takes.
    panel_follows_inventory: bool = false,
    /// B35: a strip change of the player (a walk starting or stopping, the
    /// idle pose) redraws it whole at once, so another animation's tick
    /// does not draw the new frame's overlapping pieces over the old one.
    player_strip_redraws: bool = false,
    /// B36: a dropped item's walk to its resting place aims at its own
    /// column, so the line is vertical and the walk ends there; the
    /// original aims half its width to the left and, released less than
    /// that above (or below) the rest row, it walks on forever, off the
    /// screen.
    drop_walk_straight: bool = false,
    /// B37: entering a scene drops the exit-finished messages (0x402) the
    /// old scene's exits posted, so a second door that finished on the same
    /// tick does not take the new scene's exit of that index.
    exit_finished_stays_in_scene: bool = false,
    /// B38: in 3fhall, a right click below y 0x168 with the control panel
    /// open goes to the panel only when it is on the panel; on a door it is
    /// the hall's (shuffled) door, not the door's INI exit.
    hall_low_click_takes_door: bool = false,
    /// B39: the control panel's inventory slots (the see-through holes of
    /// its bitmap) show the pristine background picture, so the player
    /// standing behind the open panel no longer shows, and animates, in them.
    panel_slots_show_background: bool = false,
    /// B42: the bad cop's arrest video (2aprema2) plays from the disc
    /// root's undamaged copy, not the `PAN\AVI\` one whose two damaged
    /// frames leave specks and stripes of garbage on the mugshots.
    clean_arrest_video: bool = false,
    /// B43: a scene change ends the fall of a dropped item in the scene it
    /// was dropped in, so its timer no longer draws it into the next scene.
    scene_change_lands_item: bool = false,
    /// B46: a scene change clears the player's off-screen walking, which
    /// the party-street arrivals turn on and nothing turns off.
    player_offscreen_per_scene: bool = false,
    /// B49: the inventory icons stay drawn while the control panel
    /// slides, lowered with its art (the original draws them only when it
    /// is open and still).
    panel_icons_while_sliding: bool = false,
    /// B50: releasing an arrow while another is held walks on towards the
    /// held one instead of stopping.
    arrow_release_resumes_held: bool = false,
    /// B48: the control panel's slide down keeps its open frame until the
    /// first step, so a redraw before that step (the player's idle tick, a
    /// walk starting) no longer cuts the closed frame into the open panel.
    panel_close_keeps_open_frame: bool = false,
    /// B44: the pope's closet places a picked item only when the pick is
    /// new, so closing a drawer without a pick no longer drops the last one
    /// again (which kept it in the closet, over the drawers, for good).
    closet_places_new_pick_once: bool = false,
    /// B47: a new game (`jogo0`) first sends every item home, so the
    /// prison's hammer, the one item `jogo0` does not name, is back in the
    /// prison and not still carried, consumed or dropped elsewhere.
    new_game_resets_items: bool = false,
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

    /// Flags left out of `all` (`--fix all`, the web build's "Corrigida"
    /// version), e.g. the hall-door reshuffle.
    pub const choices = [_][]const u8{ "quit_on_ini_error", "hall_shuffle_each_visit" };

    /// `--fix all`: every flag but the `choices`.
    pub fn all() Fixes {
        var f: Fixes = .{};
        _ = f.set("all");
        return f;
    }

    /// Turns on the fix `name` (a field name) or, for `all`, every bug
    /// fix; `-name` turns it off again (`all,-avi_exit_ignores_timer`).
    /// False if `name` is neither.
    pub fn set(f: *Fixes, name: []const u8) bool {
        const off = name.len > 0 and name[0] == '-';
        const n = if (off) name[1..] else name;
        var found = false;
        inline for (@typeInfo(Fixes).@"struct".field_names) |field| {
            const in_all = std.mem.eql(u8, n, "all") and comptime !isChoice(field);
            if (in_all or std.mem.eql(u8, n, field)) {
                @field(f, field) = !off;
                found = true;
            }
        }
        return found;
    }

    fn isChoice(field: []const u8) bool {
        for (choices) |c| if (std.mem.eql(u8, c, field)) return true;
        return false;
    }
};

test "all is every bug fix, not the choices" {
    const f = Fixes.all();
    try std.testing.expect(f.lives_game_over and f.status_bar_text and f.score_32bit);
    try std.testing.expect(!f.quit_on_ini_error and !f.hall_shuffle_each_visit);
    var g: Fixes = .{};
    try std.testing.expect(g.set("dance_music_path") and g.dance_music_path and !g.lives_game_over);
    try std.testing.expect(!g.set("nonsense"));
    var h = Fixes.all();
    try std.testing.expect(h.set("-score_32bit") and !h.score_32bit and h.lives_game_over);
    try std.testing.expect(h.set("hall_shuffle_each_visit") and h.hall_shuffle_each_visit);
}
