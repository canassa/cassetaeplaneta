//! Port unit `sound` (module) of TIRO.EXE. WaveMix (the five TIRO waves).
//!
//! See docs/tiro/DESIGN.md "How to port a TIRO unit". Each function
//! carries `// @orig <1078:xxxx> <name>` with the TIRO address.
//!
//! The WaveMix state is `g.waveMixSession`, `g.waveMixOpenResult`,
//! `g.waves` and `g.waveCount`. WaveMix goes through the platform (0 =
//! success, as the DLL). The wave table has 20 entries (the original's
//! unchecked `g_waves[g_waveCount]`; the game opens five).

const Game = @import("core/game.zig").Game;
const msg = @import("../core/msg.zig");
const platform = @import("../platform/platform.zig");
const Wave = platform.Wave;

// @orig 1078:0000 wave_mix_init
/// Opens the session (22 kHz mono), its channels and activates it. Returns
/// the activate result (0 = success, as the original returns it); 1 when a
/// session is already open; 0 after a failure box (GetInfo, ConfigureInit,
/// OpenChannel). GetModuleHandle (`g_moduleHandle`) has no counterpart.
pub fn mixInit(g: *Game) u16 {
    if (g.waveMixSession != 0) return 1;
    if (g.plat.mixGetInfo() != 0) {
        _ = g.plat.messageBox("WaveMix Erro", "N\xe3o consegiu pegar informa\xe7\xe3o", platform.mb.iconexclamation);
        return 0;
    }
    g.waveMixSession = g.plat.mixConfigureInit(1, 22);
    if (g.waveMixSession == 0) {
        _ = g.plat.messageBox("Erro Wave Mix", "N\xe3o consegue iniciar sess\xe3o", platform.mb.iconexclamation);
        return 0;
    }
    g.waveMixOpenResult = g.plat.mixOpenChannel(g.waveMixSession, 0, platform.wmix.openall);
    if (g.waveMixOpenResult != 0) {
        _ = g.plat.messageBox("Erro Wave Mix", "N\xe3o consegue abrir canais", platform.mb.iconexclamation);
        return 0;
    }
    return g.plat.mixActivate(g.waveMixSession, true);
}

// @orig 1078:00e8 wave_open
/// Opens the WAVE file `path` into the table (null on failure, after a
/// box). Like the original, `waveMixOpenResult` is left holding the handle.
pub fn open(g: *Game, path: []const u8) ?Wave {
    const idx: usize = @intCast(g.waveCount);
    g.waves[idx] = g.plat.waveOpen(g.waveMixSession, path);
    g.waveMixOpenResult = g.waves[idx] orelse 0;
    if (g.waveMixOpenResult == 0) {
        _ = g.plat.messageBox("WAveMix Erro", "Error ao abrir waves", platform.mb.iconexclamation);
        return null;
    }
    g.waveCount += 1;
    return g.waves[idx];
}

// @orig 1078:016e wave_mix_activate
/// Activates the session (the window became active). 1 on success.
pub fn mixActivate(g: *Game) u16 {
    g.waveMixOpenResult = g.plat.mixActivate(g.waveMixSession, true);
    return @intFromBool(g.waveMixOpenResult == 0);
}

// @orig 1078:01aa wave_mix_deactivate
/// Deactivates the session (the window was minimised). 1 on success.
pub fn mixDeactivate(g: *Game) u16 {
    g.waveMixOpenResult = g.plat.mixActivate(g.waveMixSession, false);
    return @intFromBool(g.waveMixOpenResult == 0);
}

// @orig 1078:01e6 wave_play
/// Plays `wave` once on channel 0 (CLEARQUEUE | HIPRIORITY always; TIRO has
/// no USELRUCHANNEL branch); `hwnd` (0 = none) is notified when it
/// ends. 1 when playback started; 0 for a wave not in the table (nothing
/// is posted, unlike NOITE's) or a failure.
pub fn play(g: *Game, hwnd: msg.Hwnd, wave: ?Wave) u16 {
    const w = wave orelse return 0;
    const n: usize = @intCast(@max(g.waveCount, 0));
    for (g.waves[0..n]) |e| {
        if (e != w) continue;
        g.waveMixOpenResult = g.plat.wavePlay(.{
            .session = g.waveMixSession,
            .channel = 0,
            .wave = w,
            .notify = hwnd != 0,
            .loops = 0,
            .clear_queue = true,
            .high_priority = true,
            .use_lru_channel = false,
        });
        return @intFromBool(g.waveMixOpenResult == 0);
    }
    return 0;
}

// @orig 1078:03a6 wave_stop_all
/// Flushes every channel (WMIX_ALL) when a session is open.
pub fn stopAll(g: *Game) void {
    if (g.waveMixSession == 0) return;
    _ = g.plat.waveFlush(g.waveMixSession, 0, platform.wmix.all);
}

// @orig 1078:03ee wave_free_all
/// Frees every open wave and empties the table (only with a session).
pub fn freeAll(g: *Game) void {
    if (g.waveMixSession == 0) return;
    const n: usize = @intCast(@max(g.waveCount, 0));
    for (g.waves[0..n]) |*e| {
        if (e.*) |w| {
            _ = g.plat.waveFree(g.waveMixSession, w);
            e.* = null;
        }
    }
    g.waveCount = 0;
}

// @orig 1078:045f wave_mix_close
/// Deactivates the session and closes its channels and the session.
pub fn mixClose(g: *Game) void {
    _ = g.plat.mixActivate(g.waveMixSession, false);
    _ = g.plat.mixCloseChannel(g.waveMixSession, 0, platform.wmix.openall);
    _ = g.plat.mixCloseSession(g.waveMixSession);
    g.waveMixSession = 0;
}
