//! Fixes for the original game's bugs (BUGS.md). Every flag defaults to
//! `false`: the port reproduces the original. A unit that ports buggy code
//! reads `g.fixes.<flag>` at the bug site and keeps both paths.
//!
//! Latent bugs (L1–L4) are not flags: the port never executes them either,
//! and where it would, it returns an error instead of corrupting memory.
//! Add a flag here (with its BUGS.md id) when you port a bug's site.

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
    /// U1: draw the status-bar text.
    status_bar_text: bool = false,
};
