//! Port unit `sound` (module). WaveMix: the wave table (max 30), play/loop/stop, activation.
//!
//! The wave table and the session handle live in `modstate.Sound`
//! (`g.sound`). WaveMix goes through the platform's WaveMix calls, which
//! return the DLL's results (0 = success, a session/wave handle or 0/null).
//! Functions that show a message box or post take `*Game`; the others take
//! `*Sound` + the platform.
//!
//! Waves are identified by the platform's `Wave` handle; the original's
//! `void *` handle (NULL = no wave) is `?Wave`.

const std = @import("std");
const Game = @import("core/game.zig").Game;
const cstr = @import("core/cstr.zig");
const msg = @import("core/msg.zig");
const platform = @import("platform/platform.zig");
const Platform = platform.Platform;
const Wave = platform.Wave;
const modstate = @import("core/modstate.zig");
const Sound = modstate.Sound;

/// Channels WaveMix is configured with; a wave plays on channel
/// (table index) mod 8.
const channels = 8;

// @orig 1018:bad2 wave_mix_init
/// Opens the session (22 kHz mono), all its channels and activates it.
/// Returns the activate result (0 = success); 1 when a session is already
/// open; 0 after showing a failure box (GetInfo, ConfigureInit,
/// OpenChannel). GetModuleHandle (`g_moduleHandle`) has no counterpart.
pub fn mixInit(g: *Game) u16 {
    const snd = &g.sound;
    if (snd.session != 0) return 1;
    if (g.plat.mixGetInfo() != 0) {
        _ = g.plat.messageBox("WaveMix Erro", "N\xe3o consegiu pegar informa\xe7\xe3o", platform.mb.iconexclamation);
        return 0;
    }
    snd.session = g.plat.mixConfigureInit(1, 22);
    if (snd.session == 0) {
        _ = g.plat.messageBox("Erro Wave Mix", "N\xe3o consegue iniciar sess\xe3o", platform.mb.iconexclamation);
        return 0;
    }
    snd.openResult = g.plat.mixOpenChannel(snd.session, 0, platform.wmix.openall);
    if (snd.openResult != 0) {
        _ = g.plat.messageBox("Erro Wave Mix", "N\xe3o consegue abrir canais", platform.mb.iconexclamation);
        return 0;
    }
    return g.plat.mixActivate(snd.session, true);
}

// @orig 1018:bb94 wave_open
/// Opens the WAVE file `path` (a DOS path) into the table; when that fails
/// retries `<assetRoot>pan\wav\<file name>.wav`, where the file name is
/// `_splitpath`'s (no directory, no extension; BUGS.md B3 comes from this).
/// Returns null on failure. With 30 waves open it shows a box and fails.
/// Like the original, `openResult` is left holding the wave handle. The
/// fallback path is formatted into `g.wavePathBuf` (50 bytes in the
/// original, unchecked; a longer path is `error.LimitExceeded`).
pub fn open(g: *Game, path: []const u8) error{LimitExceeded}!?Wave {
    const snd = &g.sound;
    if (snd.count >= modstate.max_waves) {
        _ = g.plat.messageBox("Casseta e Planeta", "Sai dessa lama e chega de perguntar MAN\xc9.", platform.mb.iconexclamation);
        return null;
    }
    const idx: usize = @intCast(snd.count);
    snd.waves[idx] = g.plat.waveOpen(snd.session, cstr.slice(path));
    snd.openResult = snd.waves[idx] orelse 0;
    if (snd.openResult == 0) {
        const root = cstr.slice(&g.driveCD); // g_assetRoot = &g_driveCD
        const fname = splitFname(path);
        if (root.len + "pan\\wav\\".len + fname.len + ".wav".len >= g.wavePathBuf.len) return error.LimitExceeded;
        const alt = cstr.print(&g.wavePathBuf, "{s}pan\\wav\\{s}.wav", .{ root, fname });
        snd.waves[idx] = g.plat.waveOpen(snd.session, alt);
        snd.openResult = snd.waves[idx] orelse 0;
        if (snd.openResult == 0) return null;
    }
    snd.count += 1;
    return snd.waves[idx];
}

/// The `fname` of the CRT's `_splitpath`: after the last `\`, `/` or `:`,
/// up to the last `.`.
fn splitFname(path: []const u8) []const u8 {
    const p = cstr.slice(path);
    var start: usize = 0;
    for (p, 0..) |c, i| {
        if (c == '\\' or c == '/' or c == ':') start = i + 1;
    }
    const base = p[start..];
    const dot = std.mem.lastIndexOfScalar(u8, base, '.') orelse base.len;
    return base[0..dot];
}

// @orig 1018:bc90 wave_mix_activate
/// Re-activates the session (window regained focus). 1 on success or with
/// no session, 0 on failure.
pub fn mixActivate(snd: *Sound, plat: Platform) i16 {
    if (snd.session != 0) {
        snd.openResult = plat.mixActivate(snd.session, true);
        if (snd.openResult != 0) return 0;
    }
    return 1;
}

// @orig 1018:bcc2 wave_mix_deactivate
/// Deactivates the session (window lost focus). 1 on success or with no
/// session, 0 on failure.
pub fn mixDeactivate(snd: *Sound, plat: Platform) i16 {
    if (snd.session != 0) {
        snd.openResult = plat.mixActivate(snd.session, false);
        if (snd.openResult != 0) return 0;
    }
    return 1;
}

/// Table index of `wave` (null never matches), or null.
fn find(snd: *const Sound, wave: ?Wave) ?usize {
    const w = wave orelse return null;
    const n: usize = @intCast(@max(snd.count, 0));
    for (snd.waves[0..n], 0..) |e, i| {
        if (e == w) return i;
    }
    return null;
}

/// MM_WOM_DONE posted to the notified window (wParam and lParam 0).
fn postDone(g: *Game, hwnd: msg.Hwnd) void {
    if (hwnd != 0) _ = g.post(.{ .id = msg.wm.mm_wom_done });
}

/// The WaveMixPlay call both play routines make: flags
/// CLEARQUEUE | HIPRIORITY (| USELRUCHANNEL without a window), channel
/// index mod 8, the window notified when there is one.
fn mixPlay(snd: *Sound, plat: Platform, hwnd: msg.Hwnd, i: usize, w: Wave, loops: u16) bool {
    snd.openResult = plat.wavePlay(.{
        .session = snd.session,
        .channel = @intCast(i % channels),
        .wave = w,
        .notify = hwnd != 0,
        .loops = loops,
        .clear_queue = true,
        .high_priority = true,
        .use_lru_channel = hwnd == 0,
    });
    return snd.openResult == 0;
}

// @orig 1018:bcf4 wave_play
/// Plays `wave` once on channel (table index mod 8), clearing the queue;
/// `hwnd` (0 = none) is notified when it ends. A wave not in the table
/// posts MM_WOM_DONE to `hwnd` at once. Returns whether playback started.
pub fn play(g: *Game, hwnd: msg.Hwnd, wave: ?Wave) bool {
    if (find(&g.sound, wave)) |i| return mixPlay(&g.sound, g.plat, hwnd, i, wave.?, 0);
    postDone(g, hwnd);
    return false;
}

// @orig 1018:bdac wave_play_loop
/// Like `play`, forever (wLoops 0xFFFF). Only a NULL wave posts
/// MM_WOM_DONE, once per table entry (the original posts inside the
/// search loop); a non-null wave not in the table is silently ignored.
pub fn playLoop(g: *Game, hwnd: msg.Hwnd, wave: ?Wave) bool {
    if (find(&g.sound, wave)) |i| return mixPlay(&g.sound, g.plat, hwnd, i, wave.?, 0xffff);
    if (wave == null) {
        var n = g.sound.count;
        while (n > 0) : (n -= 1) postDone(g, hwnd);
    }
    return false;
}

// @orig 1018:be72 wave_stop
/// Flushes the channel `wave` plays on (WMIX_FLUSH of that channel, mod 8).
/// Every table entry equal to `wave` is flushed.
pub fn stop(snd: *Sound, plat: Platform, wave: ?Wave) void {
    if (snd.session == 0) return;
    const w = wave orelse return;
    const n: usize = @intCast(@max(snd.count, 0));
    for (snd.waves[0..n], 0..) |e, i| {
        if (e == w) _ = plat.waveFlush(snd.session, @intCast(i % channels), 0);
    }
}

// @orig 1018:bed4 wave_stop_all
/// Flushes every channel (WaveMixFlushChannel with WMIX_ALL).
pub fn stopAll(snd: *Sound, plat: Platform) void {
    if (snd.session == 0) return;
    _ = plat.waveFlush(snd.session, 0, platform.wmix.all);
}

// @orig 1018:bef2 wave_pump
/// WaveMixPump: feeds the playing channels. The platform mixes by itself,
/// so there is nothing to do.
pub fn pump(snd: *Sound) void {
    _ = snd;
}

// @orig 1018:bf06 wave_free_all
/// Frees every open wave and empties the table (scene changes and exit).
pub fn freeAll(snd: *Sound, plat: Platform) void {
    if (snd.session == 0) return;
    const n: usize = @intCast(@max(snd.count, 0));
    for (snd.waves[0..n]) |*e| {
        if (e.*) |w| {
            _ = plat.waveFree(snd.session, w);
            e.* = null;
        }
    }
    snd.count = 0;
}

// @orig 1018:bf4e wave_mix_close
/// Deactivates the session and closes channels and session.
pub fn mixClose(snd: *Sound, plat: Platform) void {
    _ = plat.mixActivate(snd.session, false);
    _ = plat.mixCloseChannel(snd.session, 0, platform.wmix.openall);
    _ = plat.mixCloseSession(snd.session);
    snd.session = 0;
}

test "splitFname follows _splitpath" {
    try std.testing.expectEqualStrings("PMAUS08.WAV", splitFname("D:\\fase2\\2fcopmau\\PMAUS08.WAV.WAV"));
    try std.testing.expectEqualStrings("A", splitFname("A.WAV"));
    try std.testing.expectEqualStrings("A", splitFname("\\x\\y.z\\A"));
}
