//! Port unit `sound` (module) of SAUNA.EXE. WaveMix (the six SAUNA waves, the looped control.wav).
//!
//! See docs/sauna/DESIGN.md "How to port a SAUNA unit". Each function
//! carries `// @orig <seg:xxxx> <name>` with the SAUNA address.
//!
//! The WaveMix state is `g.waveMixSession`, `g.waveMixOpenResult`,
//! `g.waves` and `g.waveCount`. WaveMix goes through the platform (0 =
//! success, as the DLL). The wave table has 20 entries (the original's
//! unchecked `g_waves[g_waveCount]`; SAUNA opens six).

const Game = @import("core/game.zig").Game;
const msg = @import("../core/msg.zig");
const platform = @import("../platform/platform.zig");
const Wave = platform.Wave;

// @orig 1090:0000 wave_mix_init
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

// @orig 1090:00e8 wave_open
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

// @orig 1090:0170 wave_mix_activate
/// Activates the session (the window became active). 1 on success.
pub fn mixActivate(g: *Game) u16 {
    g.waveMixOpenResult = g.plat.mixActivate(g.waveMixSession, true);
    return @intFromBool(g.waveMixOpenResult == 0);
}

// @orig 1090:01ac wave_mix_deactivate
/// Deactivates the session (the window was minimised). 1 on success.
pub fn mixDeactivate(g: *Game) u16 {
    g.waveMixOpenResult = g.plat.mixActivate(g.waveMixSession, false);
    return @intFromBool(g.waveMixOpenResult == 0);
}

// @orig 1090:01e8 wave_play
/// Plays `wave` once on channel 0 (flags the constant 5: CLEARQUEUE | HIPRIORITY,
/// no USELRUCHANNEL, unlike JARDIM's); `hwnd` (0 = none) is notified when it
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
        });
        return @intFromBool(g.waveMixOpenResult == 0);
    }
    return 0;
}

// @orig 1090:0295 wave_play_loop
/// Like `play`, but on the wave's own channel (its index in the table) and
/// looping forever (wLoops 0xFFFF); flags are the constant 5 (no
/// USELRUCHANNEL: the loop owns its channel), whatever `hwnd` is. 1 when
/// playback started; 0 for a wave not in the table or a failure.
pub fn playLoop(g: *Game, hwnd: msg.Hwnd, wave: ?Wave) u16 {
    const w = wave orelse return 0;
    const n: usize = @intCast(@max(g.waveCount, 0));
    for (g.waves[0..n], 0..) |e, i| {
        if (e != w) continue;
        g.waveMixOpenResult = g.plat.wavePlay(.{
            .session = g.waveMixSession,
            .channel = @intCast(i),
            .wave = w,
            .notify = hwnd != 0,
            .loops = 0xffff,
            .clear_queue = true,
            .high_priority = true,
        });
        return @intFromBool(g.waveMixOpenResult == 0);
    }
    return 0;
}

// @orig 1090:03a8 wave_stop_all
/// Flushes every channel (WMIX_ALL) when a session is open.
pub fn stopAll(g: *Game) void {
    if (g.waveMixSession == 0) return;
    _ = g.plat.waveFlush(g.waveMixSession, 0, platform.wmix.all);
}

// @orig 1090:0343 wave_stop
/// Flushes (WMIX_NOREMIX) the channel `wave` plays on (its table index, for every
/// matching entry); only with a session. A null wave matches nothing.
pub fn stop(g: *Game, wave: ?Wave) void {
    if (g.waveMixSession == 0) return;
    const w = wave orelse return;
    const n: usize = @intCast(@max(g.waveCount, 0));
    for (g.waves[0..n], 0..) |e, i| {
        if (e != w) continue;
        _ = g.plat.waveFlush(g.waveMixSession, @intCast(i), platform.wmix.noremix);
    }
}

// @orig 1090:03f0 wave_free_all
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

// @orig 1090:0461 wave_mix_close
/// Deactivates the session and closes its channels and the session.
pub fn mixClose(g: *Game) void {
    _ = g.plat.mixActivate(g.waveMixSession, false);
    _ = g.plat.mixCloseChannel(g.waveMixSession, 0, platform.wmix.openall);
    _ = g.plat.mixCloseSession(g.waveMixSession);
    g.waveMixSession = 0;
}
