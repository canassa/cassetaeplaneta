//! Port unit `sound` (module) of INFERNO.EXE. WaveMix (the five INFERNO
//! waves; wave_play_loop for sonicf.WAV).
//!
//! See docs/inferno/DESIGN.md "How to port an INFERNO unit". Each function
//! carries `// @orig <1070:xxxx> <name>` with the INFERNO address.
//!
//! The WaveMix state is `g.waveMixSession`, `g.waves` and `g.waveCount`;
//! the call results land in `g.unk0412`/`g.unk0414` (g_unk0412/4). WaveMix
//! goes through the platform (0 = success, as the DLL). The wave table has
//! 20 entries (the original's unchecked `g_waves[g_waveCount]`).

const Game = @import("core/game.zig").Game;
const msg = @import("../core/msg.zig");
const platform = @import("../platform/platform.zig");
const Wave = platform.Wave;

// @orig 1070:0000 wave_mix_init
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
    g.unk0412 = g.plat.mixOpenChannel(g.waveMixSession, 0, platform.wmix.openall);
    g.unk0414 = 0;
    if (g.unk0412 != 0) {
        _ = g.plat.messageBox("Erro Wave Mix", "N\xe3o consegue abrir canais", platform.mb.iconexclamation);
        return 0;
    }
    return g.plat.mixActivate(g.waveMixSession, true);
}

// @orig 1070:00e8 wave_open
/// Opens the WAVE file `path` into the table (null on failure, after a
/// box). Like the original, `unk0412` is left holding the handle.
pub fn open(g: *Game, path: []const u8) ?Wave {
    const idx: usize = @intCast(g.waveCount);
    g.waves[idx] = g.plat.waveOpen(g.waveMixSession, path);
    g.unk0412 = g.waves[idx] orelse 0;
    if (g.unk0412 == 0) {
        _ = g.plat.messageBox("WAveMix Erro", "Error ao abrir waves", platform.mb.iconexclamation);
        return null;
    }
    g.waveCount += 1;
    return g.waves[idx];
}

// @orig 1070:0170 wave_mix_activate
/// Activates the session (the window became active). 1 on success.
pub fn mixActivate(g: *Game) u16 {
    g.unk0412 = g.plat.mixActivate(g.waveMixSession, true);
    g.unk0414 = 0;
    return @intFromBool(g.unk0412 == 0);
}

// @orig 1070:01ac wave_mix_deactivate
/// Deactivates the session (the window was minimised). 1 on success.
pub fn mixDeactivate(g: *Game) u16 {
    g.unk0412 = g.plat.mixActivate(g.waveMixSession, false);
    g.unk0414 = 0;
    return @intFromBool(g.unk0412 == 0);
}

// @orig 1070:01e8 wave_play
/// Plays `wave` once on channel 0 (flags 5 | (hwnd == 0 ? 2 : 0): CLEARQUEUE |
/// HIPRIORITY, plus USELRUCHANNEL without a notify window); `hwnd` (0 = none)
/// is notified when it ends. 1 when playback started; 0 for a wave not in
/// the table or a failure.
pub fn play(g: *Game, hwnd: msg.Hwnd, wave: ?Wave) u16 {
    const w = wave orelse return 0;
    const n: usize = @intCast(@max(g.waveCount, 0));
    for (g.waves[0..n]) |e| {
        if (e != w) continue;
        g.unk0412 = g.plat.wavePlay(.{
            .session = g.waveMixSession,
            .channel = 0,
            .wave = w,
            .notify = hwnd != 0,
            .loops = 0,
            .clear_queue = true,
            .high_priority = true,
            .use_lru_channel = hwnd == 0,
        });
        g.unk0414 = 0;
        return @intFromBool(g.unk0412 == 0);
    }
    return 0;
}

// @orig 1070:029e wave_play_loop
/// Like `play`, but on the wave's own channel (its index in the table) and
/// looping forever (wLoops 0xFFFF); flags are the constant 5 (no
/// USELRUCHANNEL), whatever `hwnd` is. 1 when playback started; 0 for a
/// wave not in the table or a failure.
pub fn playLoop(g: *Game, hwnd: msg.Hwnd, wave: ?Wave) u16 {
    const w = wave orelse return 0;
    const n: usize = @intCast(@max(g.waveCount, 0));
    for (g.waves[0..n], 0..) |e, i| {
        if (e != w) continue;
        g.unk0412 = g.plat.wavePlay(.{
            .session = g.waveMixSession,
            .channel = @intCast(i),
            .wave = w,
            .notify = hwnd != 0,
            .loops = 0xffff,
            .clear_queue = true,
            .high_priority = true,
        });
        g.unk0414 = 0;
        return @intFromBool(g.unk0412 == 0);
    }
    return 0;
}

// @orig 1070:03b1 wave_stop_all
/// Flushes every channel (WMIX_ALL) when a session is open.
pub fn stopAll(g: *Game) void {
    if (g.waveMixSession == 0) return;
    _ = g.plat.waveFlush(g.waveMixSession, 0, platform.wmix.all);
}

// @orig 1070:03f9 wave_free_all
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

// @orig 1070:046a wave_mix_close
/// Deactivates the session and closes its channels and the session.
pub fn mixClose(g: *Game) void {
    _ = g.plat.mixActivate(g.waveMixSession, false);
    _ = g.plat.mixCloseChannel(g.waveMixSession, 0, platform.wmix.openall);
    _ = g.plat.mixCloseSession(g.waveMixSession);
    g.waveMixSession = 0;
}
