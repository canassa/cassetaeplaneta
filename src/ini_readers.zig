//! Port unit `ini_readers` (module). One reader per INI key (Screen=, Local=,
//! Exit=, Portable=, Lives= ...).
//!
//! Every reader is the same routine in the original: find `Key=` in the
//! current section (`ini.findKey`), read the rest of the line into a 256-byte
//! buffer, `sscanf` it with a fixed format into the caller's out pointers, and
//! on a field count other than the number of conversions show the "Erro
//! Fatal!" box (`Não consegui ler todos os campos do X!`) and return 0.
//! Returns 1 on success, 0 when the key is absent or the line is malformed.
//!
//! The port has one generic `readKey` and a thin tagged function per key. The
//! out pointers of the original (`short *` / `char *`, passed as far pointer
//! pairs) are a tuple, in the format's order: `*i16` for `%d`, `[]u8` for `%s`
//! (call it `.{ &number, &name_buf, ... }`). `%s` is the CRT's: it stops at
//! white space, not at the comma, which is why the INI has a space after each
//! name. Out values are written as far as the line parses, as `sscanf` does.
//!
//! Known divergences, in data the game never has: `%s` into a buffer too
//! small for the name is `error.LimitExceeded` (the original overflows); a
//! `%d` wraps to 16 bits.

const std = @import("std");
const platform = @import("platform/platform.zig");
const File = platform.File;
const Platform = platform.Platform;
const cstr = @import("core/cstr.zig");
const modstate = @import("core/modstate.zig");
const Ini = modstate.Ini;
const Fixes = @import("core/fixes.zig").Fixes;
const errors = @import("core/errors.zig");
const ini_mod = @import("ini.zig");

pub const Error = errors.Error;

// CRT `isspace` in the C locale.
fn isSpace(c: u8) bool {
    return c == ' ' or (c >= 9 and c <= 13);
}

/// The out-pointer tuple of a format: one element per conversion.
pub fn Args(comptime fmt: []const u8) type {
    comptime {
        var types: [convCount(fmt)]type = undefined;
        var n: usize = 0;
        var i: usize = 0;
        while (i < fmt.len) : (i += 1) {
            if (fmt[i] != '%') continue;
            i += 1;
            types[n] = switch (fmt[i]) {
                'd' => *i16,
                's' => []u8,
                else => @compileError("unsupported conversion"),
            };
            n += 1;
        }
        return @Tuple(&types);
    }
}

fn convCount(comptime fmt: []const u8) usize {
    comptime {
        var n: usize = 0;
        for (fmt) |c| {
            if (c == '%') n += 1;
        }
        return n;
    }
}

/// `%d`: optional white space, optional sign, at least one digit.
fn scanInt(line: []const u8, p: *usize) ?i16 {
    var i = p.*;
    while (i < line.len and isSpace(line[i])) i += 1;
    var neg = false;
    if (i < line.len and (line[i] == '-' or line[i] == '+')) {
        neg = line[i] == '-';
        i += 1;
    }
    const digits = i;
    var v: u32 = 0;
    while (i < line.len and line[i] >= '0' and line[i] <= '9') : (i += 1) v = v *% 10 +% (line[i] - '0');
    if (i == digits) return null;
    p.* = i;
    return @truncate(@as(i32, @bitCast(if (neg) 0 -% v else v)));
}

/// CRT `sscanf` for the formats of this unit (`%d`, `%s`, white space,
/// literal characters). Returns the number of conversions stored.
fn scan(line: []const u8, comptime fmt: []const u8, args: Args(fmt)) Error!i16 {
    var p: usize = 0;
    var count: i16 = 0;
    comptime var ai: usize = 0;
    comptime var i: usize = 0;
    inline while (i < fmt.len) : (i += 1) {
        const c = fmt[i];
        if (c == '%') {
            i += 1;
            if (fmt[i] == 'd') {
                const v = scanInt(line, &p) orelse return count;
                args[ai].* = v;
            } else {
                while (p < line.len and isSpace(line[p])) p += 1;
                const start = p;
                while (p < line.len and !isSpace(line[p])) p += 1;
                if (p == start) return count;
                if (p - start >= args[ai].len) return error.LimitExceeded;
                cstr.copy(args[ai], line[start..p]);
            }
            ai += 1;
            count += 1;
        } else if (isSpace(c)) {
            while (p < line.len and isSpace(line[p])) p += 1;
        } else {
            if (p >= line.len or line[p] != c) return count;
            p += 1;
        }
    }
    return count;
}

fn readKey(ini: *Ini, plat: Platform, fixes: Fixes, fd: File, key: []const u8, comptime fmt: []const u8, msg: []const u8, args: Args(fmt)) Error!i16 {
    var buf: [256]u8 = @splat(0);
    if (!try ini_mod.findKey(ini, plat, fixes, fd, key)) return 0;
    _ = try ini_mod.readLine(plat, fixes, fd, &buf);
    if (try scan(cstr.slice(&buf), fmt, args) == comptime convCount(fmt)) return 1;
    _ = try ini_mod.fatalError(plat, fixes, msg);
    return 0;
}

/// `Player=` line: `%d,%d,%d,%d,%s ,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d`.
// @orig 1018:9e20 ini_read_player
pub fn readPlayer(ini: *Ini, plat: Platform, fixes: Fixes, fd: File, args: Args(fmt_player)) Error!i16 {
    return readKey(ini, plat, fixes, fd, "Player", fmt_player, "N\xe3o consegui ler todos os campos do Player!", args);
}

/// `Sprite=` line: `%d,%d,%d,%d,%d,%d,%d`.
// @orig 1018:9ece ini_read_sprite
pub fn readSprite(ini: *Ini, plat: Platform, fixes: Fixes, fd: File, args: Args(fmt_sprite)) Error!i16 {
    return readKey(ini, plat, fixes, fd, "Sprite", fmt_sprite, "N\xe3o consegui ler todos os campos do Sprite!", args);
}

/// `Control=` line: `%d,%d,%s ,%d,%d,%d,%d,%d`.
// @orig 1018:9f5c ini_read_control
pub fn readControl(ini: *Ini, plat: Platform, fixes: Fixes, fd: File, args: Args(fmt_control)) Error!i16 {
    return readKey(ini, plat, fixes, fd, "Control", fmt_control, "N\xe3o consegui ler todos os campos do ControlPanel!", args);
}

/// `StatusBar=` line: `%d,%d,%d,%s ,%d,%d`.
// @orig 1018:9fee ini_read_status_bar
pub fn readStatusBar(ini: *Ini, plat: Platform, fixes: Fixes, fd: File, args: Args(fmt_statusbar)) Error!i16 {
    return readKey(ini, plat, fixes, fd, "StatusBar", fmt_statusbar, "N\xe3o consegui ler todos os campos do StatusBar!", args);
}

/// `FirstScene=` line: `%s ,%d,%d,%d,%d,%d`.
// @orig 1018:a078 ini_read_first_scene
pub fn readFirstScene(ini: *Ini, plat: Platform, fixes: Fixes, fd: File, args: Args(fmt_firstscene)) Error!i16 {
    return readKey(ini, plat, fixes, fd, "FirstScene", fmt_firstscene, "N\xe3o consegui ler todos os campos da FirstScene!", args);
}

/// `StartScene=` line: `%s ,%d,%d,%d,%d,%d`.
// @orig 1018:a102 ini_read_start_scene
pub fn readStartScene(ini: *Ini, plat: Platform, fixes: Fixes, fd: File, args: Args(fmt_startscene)) Error!i16 {
    return readKey(ini, plat, fixes, fd, "StartScene", fmt_startscene, "N\xe3o consegui ler todos os campos da StartScene!", args);
}

/// `Portable=` line: `%d,%s ,%d,%d,%s ,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d`.
// @orig 1018:a18c ini_read_portable
pub fn readPortable(ini: *Ini, plat: Platform, fixes: Fixes, fd: File, args: Args(fmt_portable)) Error!i16 {
    return readKey(ini, plat, fixes, fd, "Portable", fmt_portable, "N\xe3o consegui ler todos os campos do Portable!", args);
}

/// `ZoomPort=` line: `%d,%s ,%d,%d,%s ,%d,%d,%d,%s ,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d`.
// @orig 1018:a256 ini_read_zoom_port
pub fn readZoomPort(ini: *Ini, plat: Platform, fixes: Fixes, fd: File, args: Args(fmt_zoomport)) Error!i16 {
    return readKey(ini, plat, fixes, fd, "ZoomPort", fmt_zoomport, "N\xe3o consegui ler todos os campos do ZoomPort!", args);
}

/// `Limits=` line: `%d,%d,%d,%d,%d,%d,%d,%d`.
// @orig 1018:a324 ini_read_limits
pub fn readLimits(ini: *Ini, plat: Platform, fixes: Fixes, fd: File, args: Args(fmt_limits)) Error!i16 {
    return readKey(ini, plat, fixes, fd, "Limits", fmt_limits, "N\xe3o consegui ler todos os campos do Limits!", args);
}

/// `Screen=` line: `%d,%s ,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d`.
// @orig 1018:a3b6 ini_read_screen
pub fn readScreen(ini: *Ini, plat: Platform, fixes: Fixes, fd: File, args: Args(fmt_screen)) Error!i16 {
    return readKey(ini, plat, fixes, fd, "Screen", fmt_screen, "N\xe3o consegui ler todos os campos do Screen!", args);
}

/// `Local=` line: `%d,%d,%d,%s ,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d`.
// @orig 1018:a470 ini_read_local
pub fn readLocal(ini: *Ini, plat: Platform, fixes: Fixes, fd: File, args: Args(fmt_local)) Error!i16 {
    return readKey(ini, plat, fixes, fd, "Local", fmt_local, "N\xe3o consegui ler todos os campos do Local!", args);
}

/// `Animated=` line: `%d,%d,%d,%s ,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%s `.
// @orig 1018:a51e ini_read_animated
pub fn readAnimated(ini: *Ini, plat: Platform, fixes: Fixes, fd: File, args: Args(fmt_animated)) Error!i16 {
    return readKey(ini, plat, fixes, fd, "Animated", fmt_animated, "N\xe3o consegui ler todos os campos do Animated!", args);
}

/// `Static=` line: `%d,%d,%d,%s ,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%s `.
// @orig 1018:a5e0 ini_read_static
pub fn readStatic(ini: *Ini, plat: Platform, fixes: Fixes, fd: File, args: Args(fmt_static)) Error!i16 {
    return readKey(ini, plat, fixes, fd, "Static", fmt_static, "N\xe3o consegui ler todos os campos do Static!", args);
}

/// `Exit=` line: `%d,%d,%d,%s ,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%s ,%d,%d,%d,%d,%d,%d,%d,%d,%s `.
// @orig 1018:a69e ini_read_exit
pub fn readExit(ini: *Ini, plat: Platform, fixes: Fixes, fd: File, args: Args(fmt_exit)) Error!i16 {
    return readKey(ini, plat, fixes, fd, "Exit", fmt_exit, "N\xe3o consegui ler todos os campos do Exit!", args);
}

/// `2Exit=` line: `%d,%d,%d,%s ,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%s ,%d,%d,%d,%d,%d,%d,%d,%s ,%d,%d,%d,%s `.
// @orig 1018:a780 ini_read_exit2
pub fn readExit2(ini: *Ini, plat: Platform, fixes: Fixes, fd: File, args: Args(fmt_exit2)) Error!i16 {
    return readKey(ini, plat, fixes, fd, "2Exit", fmt_exit2, "N\xe3o consegui ler todos os campos do Exit!", args);
}

/// `Moveable=` line: `%d,%d,%d,%s ,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%s `.
// @orig 1018:a88c ini_read_moveable
pub fn readMoveable(ini: *Ini, plat: Platform, fixes: Fixes, fd: File, args: Args(fmt_moveable)) Error!i16 {
    return readKey(ini, plat, fixes, fd, "Moveable", fmt_moveable, "N\xe3o consegui ler todos os campos do Moveable!", args);
}

/// `C_Actor=` line: `%d,%d,%d,%s ,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%s `.
// @orig 1018:a94e ini_read_c_actor
pub fn readCActor(ini: *Ini, plat: Platform, fixes: Fixes, fd: File, args: Args(fmt_cactor)) Error!i16 {
    return readKey(ini, plat, fixes, fd, "C_Actor", fmt_cactor, "N\xe3o consegui ler todos os campos do C_Actor!", args);
}

/// `Portab=` line: `%d,%s ,%d,%d`.
// @orig 1018:ab5c ini_read_portab
pub fn readPortab(ini: *Ini, plat: Platform, fixes: Fixes, fd: File, args: Args(fmt_portab)) Error!i16 {
    return readKey(ini, plat, fixes, fd, "Portab", fmt_portab, "N\xe3o consegui ler todos os campos do Portab!", args);
}

/// `Invent=` line: `%d`.
// @orig 1018:abde ini_read_invent
pub fn readInvent(ini: *Ini, plat: Platform, fixes: Fixes, fd: File, args: Args(fmt_invent)) Error!i16 {
    return readKey(ini, plat, fixes, fd, "Invent", fmt_invent, "N\xe3o consegui ler todos os campos do Invent\xe1rio!", args);
}

/// `Stat=` line: `%d,%d,%d`.
// @orig 1018:ac54 ini_read_stat
pub fn readStat(ini: *Ini, plat: Platform, fixes: Fixes, fd: File, args: Args(fmt_stat)) Error!i16 {
    return readKey(ini, plat, fixes, fd, "Stat", fmt_stat, "N\xe3o consegui ler todos os campos do Static!", args);
}

/// `PlayerX=` line: `%d`.
// @orig 1018:acd2 ini_read_player_x
pub fn readPlayerX(ini: *Ini, plat: Platform, fixes: Fixes, fd: File, args: Args(fmt_playerx)) Error!i16 {
    return readKey(ini, plat, fixes, fd, "PlayerX", fmt_playerx, "N\xe3o consegui ler todos os campos do PlayerX!", args);
}

/// `PlayerY=` line: `%d`.
// @orig 1018:ad48 ini_read_player_y
pub fn readPlayerY(ini: *Ini, plat: Platform, fixes: Fixes, fd: File, args: Args(fmt_playery)) Error!i16 {
    return readKey(ini, plat, fixes, fd, "PlayerY", fmt_playery, "N\xe3o consegui ler todos os campos do PlayerY!", args);
}

/// `Score=` line: `%d`.
// @orig 1018:adbe ini_read_score
pub fn readScore(ini: *Ini, plat: Platform, fixes: Fixes, fd: File, args: Args(fmt_score)) Error!i16 {
    return readKey(ini, plat, fixes, fd, "Score", fmt_score, "N\xe3o consegui ler todos os campos de Score!", args);
}

/// `Lives=` line: `%d`.
// @orig 1018:ae34 ini_read_lives
pub fn readLives(ini: *Ini, plat: Platform, fixes: Fixes, fd: File, args: Args(fmt_lives)) Error!i16 {
    return readKey(ini, plat, fixes, fd, "Lives", fmt_lives, "N\xe3o consegui ler todos os campos de Lives!", args);
}

const fmt_player = "%d,%d,%d,%d,%s ,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d";
const fmt_sprite = "%d,%d,%d,%d,%d,%d,%d";
const fmt_control = "%d,%d,%s ,%d,%d,%d,%d,%d";
const fmt_statusbar = "%d,%d,%d,%s ,%d,%d";
const fmt_firstscene = "%s ,%d,%d,%d,%d,%d";
const fmt_startscene = "%s ,%d,%d,%d,%d,%d";
const fmt_portable = "%d,%s ,%d,%d,%s ,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d";
const fmt_zoomport = "%d,%s ,%d,%d,%s ,%d,%d,%d,%s ,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d";
const fmt_limits = "%d,%d,%d,%d,%d,%d,%d,%d";
const fmt_screen = "%d,%s ,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d";
const fmt_local = "%d,%d,%d,%s ,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d";
const fmt_animated = "%d,%d,%d,%s ,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%s ";
const fmt_static = "%d,%d,%d,%s ,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%s ";
const fmt_exit = "%d,%d,%d,%s ,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%s ,%d,%d,%d,%d,%d,%d,%d,%d,%s ";
const fmt_exit2 = "%d,%d,%d,%s ,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%s ,%d,%d,%d,%d,%d,%d,%d,%s ,%d,%d,%d,%s ";
const fmt_moveable = "%d,%d,%d,%s ,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%s ";
const fmt_cactor = "%d,%d,%d,%s ,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%s ";
const fmt_portab = "%d,%s ,%d,%d";
const fmt_invent = "%d";
const fmt_stat = "%d,%d,%d";
const fmt_playerx = "%d";
const fmt_playery = "%d";
const fmt_score = "%d";
const fmt_lives = "%d";

// @orig 1018:a18c ini_read_portable oracle=asset
test "scan: Portable line of CASSETA.INI" {
    // oracle=asset: first Portable= line of assets/CASSETA.INI.
    var number: i16 = 0;
    var scene: [50]u8 = @splat(0);
    var bmp: [50]u8 = @splat(0);
    var v: [19]i16 = @splat(0);
    const line = "91,1fquarbo ,166,375,P\\1pbola ,50,50,0,0,50,50,3,46,50,50,50,0,4,200,1000,0,-1500\r\n";
    const n = try scan(line, fmt_portable, .{
        &number, &scene, &v[0],  &v[1],  &bmp,   &v[2],  &v[3],  &v[4],  &v[5],
        &v[6],   &v[7],  &v[8],  &v[9],  &v[10], &v[11], &v[12], &v[13], &v[14],
        &v[15],  &v[16], &v[17], &v[18],
    });
    try std.testing.expectEqual(@as(i16, 22), n);
    try std.testing.expectEqual(@as(i16, 91), number);
    try std.testing.expectEqualStrings("1fquarbo", cstr.slice(&scene));
    try std.testing.expectEqualStrings("P\\1pbola", cstr.slice(&bmp));
    try std.testing.expectEqual(@as(i16, 166), v[0]);
    try std.testing.expectEqual(@as(i16, -1500), v[18]);
}

test "scan: stops at the first field that does not parse" {
    var a: i16 = 0;
    var b: i16 = 0;
    try std.testing.expectEqual(@as(i16, 1), try scan("7,x", "%d,%d", .{ &a, &b }));
    try std.testing.expectEqual(@as(i16, 7), a);
}
