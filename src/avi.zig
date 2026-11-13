//! Port unit `avi` (module). Animation's AVI slots: name, MCI open/play/close/stop.
//!
//! The original talks to MCI (`MCI_OPEN`/`MCI_PLAY`/`MCI_CLOSE`/`MCI_STOP` on
//! an `avivideo` device); here that is `Platform.aviOpen/aviPlay/aviClose/
//! aviStop`, which return the MCI error code like mciSendCommand. The
//! `hwnd` parameters are dropped (one window), and the `MCI_WINDOW` command
//! that shows the child window after the open has no platform counterpart
//! (it always succeeds, so its error box never shows): the sim draws the
//! frames on the screen. When MCI fails the original shows
//! mciGetErrorString's text in a "MCI Erro" box (`platform.mciGetErrorString`).

const std = @import("std");
const Game = @import("core/game.zig").Game;
const object = @import("core/object.zig");
const Object = object.Object;
const cstr = @import("core/cstr.zig");
const platform = @import("platform/platform.zig");
const ini = @import("ini.zig");
const animation = @import("behaviour/animation.zig");

/// mciGetErrorString(err, buf, 256) + MessageBox(text, "MCI Erro", MB_ICONEXCLAMATION).
fn mciError(g: *Game, err: u32) void {
    // Caption string at 1010:d796.
    _ = g.plat.messageBox("MCI Erro", platform.mciGetErrorString(err), platform.mb.iconexclamation);
}

/// Animation slot 00: marks the animation as an AVI clip.
// @orig 1010:2090 animation_set_avi
pub fn setAvi(g: *Game, obj: *Object) void {
    _ = g;
    obj.anim.isAvi = 1;
}

/// Animation slot 01: copies the clip name into the object. The original's
/// strcpy has no bound; here it truncates at the 256-byte field.
// @orig 1010:20be animation_set_avi_name
pub fn setAviName(g: *Game, obj: *Object, name: []const u8) void {
    _ = g;
    cstr.copy(&obj.anim.aviName, name);
}

/// Animation slot 02: the clip name.
// @orig 1010:20fc animation_get_avi_name
pub fn getAviName(g: *Game, obj: *Object) []const u8 {
    _ = g;
    return cstr.slice(&obj.anim.aviName);
}

/// The `fname` part of `_splitpath` (after the last `\` or `/`, up to the
/// last `.`).
fn splitFname(path: []const u8) []const u8 {
    var p = cstr.slice(path);
    if (p.len >= 2 and p[1] == ':') p = p[2..];
    if (std.mem.lastIndexOfAny(u8, p, "\\/")) |i| p = p[i + 1 ..];
    if (std.mem.lastIndexOfScalar(u8, p, '.')) |i| p = p[0..i];
    return p;
}

/// Animation slot 03: for an AVI animation opens the clip, trying the HD
/// directory (`driveHD` + base name + `.avi`), then `driveCD` + the given
/// name + `.avi`, then `driveCD` + `pan\avi\` + base name + `.avi`; records it
/// as the playing AVI and returns the device id. 0 on failure or when the
/// object is not an AVI.
// @orig 1010:c9f6 animation_open_avi
pub fn openAvi(g: *Game, obj: *Object, name: []const u8) u16 {
    var path: [256]u8 = undefined;
    var base: [256]u8 = undefined;
    cstr.copy(&path, name);
    cstr.copy(&base, splitFname(&path));
    cstr.copy(&path, ini.assetPath(&g.ini, &g.driveCD, &g.driveHD, &base, -2));
    if (!animation.isAvi(g, obj)) return 0;
    var dev: platform.Device = 0;
    var err = g.plat.aviOpen(cstr.slice(&path), &dev);
    if (err != 0) {
        _ = cstr.print(&path, "{s}{s}.avi", .{ cstr.slice(&g.driveCD), cstr.slice(name) });
        err = g.plat.aviOpen(cstr.slice(&path), &dev);
        if (err != 0) {
            _ = cstr.print(&path, "{s}pan\\avi\\{s}.avi", .{ cstr.slice(&g.driveCD), cstr.slice(&base) });
            err = g.plat.aviOpen(cstr.slice(&path), &dev);
        }
        if (err != 0) {
            mciError(g, err);
            return 0;
        }
    }
    g.aviPlaying = obj;
    obj.anim.aviDevice = dev;
    // MCI_WINDOW (show the video child window): no platform counterpart.
    return obj.anim.aviDevice;
}

/// Animation slot 04: for an AVI animation plays the device from the start
/// (the notification goes to the main window).
// @orig 1010:ccbe animation_play_avi
pub fn playAvi(g: *Game, obj: *Object, device: u16) void {
    if (!animation.isAvi(g, obj)) return;
    const err = g.plat.aviPlay(device);
    if (err != 0) mciError(g, err);
}

/// Animation slot 05: for an AVI animation clears the playing-AVI state,
/// closes the device and resets the clip name.
// @orig 1010:cd48 animation_close_avi
pub fn closeAvi(g: *Game, obj: *Object, device: u16) void {
    if (!animation.isAvi(g, obj)) return;
    g.aviPlaying = null;
    g.ini.rec.isAvi = 0;
    g.plat.aviClose(device);
    // The empty string at 1010:946e.
    setAviName(g, obj, "");
}

/// Animation slot 06: for an AVI animation stops the device.
// @orig 1010:cdea animation_stop_avi
pub fn stopAvi(g: *Game, obj: *Object, device: u16) void {
    if (!animation.isAvi(g, obj)) return;
    g.plat.aviStop(device);
}
