//! Port unit `ini` (module). INI reader: file, section index, tokens, keys, asset paths, WAVE lookup; random_below and concat_strings.
//!
//! The original reads `CASSETA.INI` one byte at a time with `_lread` and
//! moves around with `_llseek`; the port does the same through the platform's
//! DOS file calls. State (`g_ini*`) lives in `modstate.Ini`. Every reader
//! takes the platform, the open file and (when it touches it) the `Ini` state.
//! The original's `ini_fatal_error` only shows the "Erro Fatal!" box and
//! returns 0; callers carry on with that value, and so does the port.
//! `Fixes.quit_on_ini_error` makes it return `error.Fatal` instead (quit).
//! The readers that can reach it take `fixes` by value.
//!
//! Known divergences, all in data the game never has:
//! - The CRT `_ctype` table is read for bytes >= 0x80 at negative indices, into
//!   unrelated DGROUP bytes; here those bytes are neither space nor letters.
//! - Token/line buffers are written unchecked by the original; an overflow is
//!   `error.LimitExceeded`.
//! - At end of file `ini_read_line` / `ini_read_token` return without
//!   terminating the buffer; the port's buffers start zeroed, so what a
//!   caller then reads is empty instead of stale stack bytes.

const std = @import("std");
const platform = @import("platform/platform.zig");
const Platform = platform.Platform;
const File = platform.File;
const cstr = @import("core/cstr.zig");
const crt = @import("core/crt.zig");
const modstate = @import("core/modstate.zig");
const Ini = modstate.Ini;
const ini_sections = @import("ini_sections.zig");
const Fixes = @import("core/fixes.zig").Fixes;
const errors = @import("core/errors.zig");

pub const Error = errors.Error;

/// Messages (Latin-1, as in the original's code segment).
const msg_unexpected_eof = "Fim de arquivo n\xe3o esperado!";
const msg_no_section = "N\xe3o consegui encontrar a sess\xe3o procurada";
const msg_no_section_start = "N\xe3o consegui encontrar o in\xedcio da sess\xe3o procurada";
const msg_wave_fields = "N\xe3o consegui ler todos os campos do WAVE!";

// CRT `isspace` / `isupper` / `islower` (the `_ctype` flags 8, 1, 2) in the C
// locale. Non-ASCII bytes carry no flags (see the module doc).
fn isSpace(c: u8) bool {
    return c == ' ' or (c >= 9 and c <= 13);
}
fn isUpper(c: u8) bool {
    return c >= 'A' and c <= 'Z';
}
fn isLower(c: u8) bool {
    return c >= 'a' and c <= 'z';
}

/// `_lread(fd, &c, 1)`: the next byte, or null at end of file.
fn readByte(plat: Platform, fd: File) ?u8 {
    var b: [1]u8 = undefined;
    if (plat.read(fd, &b) == 0) return null;
    return b[0];
}

/// `_lseek(fd, -1, SEEK_CUR)`: step back one byte.
fn unread(plat: Platform, fd: File) void {
    _ = plat.seek(fd, -1, .cur);
}

/// Shows `msg` in the "Erro Fatal!" box (MB_OK) and returns 0; the program
/// goes on. With `fixes.quit_on_ini_error`, returns `error.Fatal` instead.
// @orig 1018:98d0 ini_fatal_error
pub fn fatalError(plat: Platform, fixes: Fixes, msg: []const u8) error{Fatal}!i16 {
    _ = plat.messageBox("Erro Fatal!", msg, platform.mb.ok);
    if (fixes.quit_on_ini_error) return error.Fatal;
    return 0;
}

/// Formats `fmt` (C printf syntax) with one 32-bit argument and shows it in a
/// warning box. The CRT `sprintf` is replaced: supports `%d %i %u %x %X %c`
/// (16-bit, the low word of `arg`), their `l` forms (32-bit) and `%%`; other
/// text is copied. `buf` is the original's shared buffer (DGROUP 7cd6, 100
/// bytes: `g.messageBuf`); the text is truncated to it. The box is
/// MB_ICONEXCLAMATION.
// @orig 1018:3644 message_box_printf
pub fn messageBoxPrintf(plat: Platform, buf: []u8, caption: []const u8, fmt: []const u8, arg: u32) void {
    var w: std.Io.Writer = .fixed(buf[0 .. buf.len - 1]);
    const f = cstr.slice(fmt);
    var i: usize = 0;
    while (i < f.len) : (i += 1) {
        if (f[i] != '%') {
            w.writeByte(f[i]) catch break;
            continue;
        }
        i += 1;
        if (i >= f.len) break;
        var long = false;
        if (f[i] == 'l') {
            long = true;
            i += 1;
            if (i >= f.len) break;
        }
        const wlo: u16 = @truncate(arg);
        const r = switch (f[i]) {
            '%' => w.writeByte('%'),
            'd', 'i' => if (long) w.print("{d}", .{@as(i32, @bitCast(arg))}) else w.print("{d}", .{@as(i16, @bitCast(wlo))}),
            'u' => if (long) w.print("{d}", .{arg}) else w.print("{d}", .{wlo}),
            'x' => if (long) w.print("{x}", .{arg}) else w.print("{x}", .{wlo}),
            'X' => if (long) w.print("{X}", .{arg}) else w.print("{X}", .{wlo}),
            'c' => w.writeByte(@truncate(arg)),
            else => {},
        };
        r catch break;
    }
    const n = w.buffered().len;
    buf[n] = 0;
    _ = plat.messageBox(caption, buf[0..n], platform.mb.iconexclamation);
}

/// Scans the whole file once and records every `[section]` name (lower-cased,
/// white space dropped) with the file offset just after its header line.
/// Returns 1. The original indexes the table by `g_iniSectionBuild`, which is
/// never reset, and copies the name into the 40-byte field unchecked.
// @orig 1018:98f2 ini_build_section_index
pub fn buildSectionIndex(ini: *Ini, plat: Platform, fixes: Fixes, fd: File) Error!i16 {
    while (true) {
        const c = try nextChar(ini, plat, fixes, fd);
        if (c == 0) {
            ini.sections.count = ini.sectionBuild;
            return 1;
        }
        if (c != '[') {
            _ = try readLine(plat, fixes, fd, null);
            continue;
        }
        var name: [51]u8 = @splat(0);
        _ = try readToken(plat, fixes, fd, &name, ']');
        const len = cstr.slice(&name).len;
        if (ini.sectionBuild < 0 or ini.sectionBuild >= ini_sections.max_sections or len >= ini_sections.name_len)
            return error.LimitExceeded;
        const entry = &ini.sections.entries[@intCast(ini.sectionBuild)];
        @memcpy(entry.name[0 .. len + 1], name[0 .. len + 1]);
        _ = try readLine(plat, fixes, fd, null);
        entry.offset = plat.seek(fd, 0, .cur);
        ini.sectionBuild += 1;
    }
}

/// Next character that is not white space or a newline, skipping `;` comment
/// lines; remembers it in `ini.lastChar`. 0 at end of file.
// @orig 1018:99fa ini_next_char
pub fn nextChar(ini: *Ini, plat: Platform, fixes: Fixes, fd: File) Error!u8 {
    while (true) {
        var c = readByte(plat, fd) orelse return 0;
        if (c == ';') c = try skipLine(plat, fixes, fd);
        if (isSpace(c) or c == '\n') continue;
        ini.lastChar = c;
        return c;
    }
}

/// Discards the rest of the current line; returns its terminator.
// @orig 1018:9a4e ini_skip_line
pub fn skipLine(plat: Platform, fixes: Fixes, fd: File) Error!u8 {
    return readLine(plat, fixes, fd, null);
}

/// Reads up to and including the next CR or LF into `buf` (when not null),
/// NUL-terminated; returns the last character read. At end of file: the
/// fatal box, 0, and the buffer is left unterminated.
// @orig 1018:9a68 ini_read_line
pub fn readLine(plat: Platform, fixes: Fixes, fd: File, buf: ?[]u8) Error!u8 {
    var n: usize = 0;
    while (true) {
        const c = readByte(plat, fd) orelse return @intCast(try fatalError(plat, fixes, msg_unexpected_eof));
        if (buf) |b| {
            if (n + 1 >= b.len) return error.LimitExceeded;
            b[n] = c;
            n += 1;
        }
        if (c == '\r' or c == '\n') {
            if (buf) |b| b[n] = 0;
            return c;
        }
    }
}

/// Reads characters up to `delim` into `buf`, dropping white space and
/// lower-casing letters; NUL-terminated. Returns 1; at end of file the
/// fatal box's 0, with the buffer unterminated.
// @orig 1018:9b02 ini_read_token
pub fn readToken(plat: Platform, fixes: Fixes, fd: File, buf: []u8, delim: u8) Error!i16 {
    var n: usize = 0;
    while (true) {
        const c = readByte(plat, fd) orelse return fatalError(plat, fixes, msg_unexpected_eof);
        if (c == delim) break;
        if (isSpace(c) or c == '\n') continue;
        if (n + 1 >= buf.len) return error.LimitExceeded;
        buf[n] = if (isUpper(c)) c + 0x20 else c;
        n += 1;
    }
    buf[n] = 0;
    return 1;
}

/// From the current position, scans the lines of the current section for
/// `key=` (case-insensitive) and stops just after the `=`. True if found;
/// false when the next section header is reached (`ini.sectionEnd` = 1) or
/// when a line starts with another letter than the key's first (the
/// original compares that first byte exactly, a quirk kept as is).
// @orig 1018:9bbe ini_find_key
pub fn findKey(ini: *Ini, plat: Platform, fixes: Fixes, fd: File, key: []const u8) Error!bool {
    const k = cstr.slice(key);
    const first: u8 = if (k.len > 0) k[0] else 0;
    ini.sectionEnd = 0;
    ini.keySearch = 1;
    while (true) {
        const c = try nextChar(ini, plat, fixes, fd);
        if (c == '[') {
            ini.sectionEnd = 1;
            ini.keySearch = 0;
            return false;
        }
        unread(plat, fd);
        if (first != ini.lastChar) break;
        var token: [256]u8 = @splat(0);
        _ = try readToken(plat, fixes, fd, &token, '=');
        if (cstr.eqlIgnoreCase(&token, k)) return true;
        _ = try readLine(plat, fixes, fd, null);
    }
    ini.keySearch = 0;
    return false;
}

/// Opens `path` for reading; null on failure. The original expands it with
/// `_fullpath` first; the platform resolves paths itself.
// @orig 1018:9c50 ini_open
pub fn open(plat: Platform, path: []const u8) ?File {
    return plat.open(cstr.slice(path), .read);
}

// @orig 1018:9c96 ini_close
pub fn close(plat: Platform, fd: File) void {
    plat.close(fd);
}

/// Positions the file in the named section: just after its header when
/// `after_header`, otherwise back on its `[`. Returns 1; an unknown section
/// (or no `[` before it) shows the fatal box and returns 0.
// @orig 1018:9caa ini_seek_section
pub fn seekSection(ini: *const Ini, plat: Platform, fixes: Fixes, fd: File, name: []const u8, after_header: bool) Error!i16 {
    const off = ini_sections.findSectionOffset(&ini.sections, name);
    if (off == -1) return fatalError(plat, fixes, msg_no_section);
    _ = plat.seek(fd, off, .set);
    if (after_header) return 1;
    // The original tests an uninitialised stack byte before the first read;
    // it is taken as "not '['" (the offset is past the header, so the first
    // byte read is never the '[' anyway).
    var c: u8 = 0;
    while (true) {
        if (c == '[') {
            unread(plat, fd);
            return 1;
        }
        _ = plat.seek(fd, -2, .cur);
        c = readByte(plat, fd) orelse return fatalError(plat, fixes, msg_no_section_start);
    }
}

/// Builds a full asset file name in `ini.assetPath` from a base name: kind -1
/// `.bmp`, -3 `.wav`, -4 `.rle` (under `drive_cd`), -2 `.avi` (under
/// `drive_hd`); any other kind appends the number then `.bmp`. Returns the
/// name (a slice of `ini.assetPath`).
// @orig 1018:9d4e ini_asset_path
pub fn assetPath(ini: *Ini, drive_cd: []const u8, drive_hd: []const u8, name: []const u8, kind: i16) []const u8 {
    const cd = cstr.slice(drive_cd);
    const n = cstr.slice(name);
    return switch (kind) {
        -1 => cstr.print(&ini.assetPath, "{s}{s}.bmp", .{ cd, n }),
        -2 => cstr.print(&ini.assetPath, "{s}{s}.avi", .{ cstr.slice(drive_hd), n }),
        -3 => cstr.print(&ini.assetPath, "{s}{s}.wav", .{ cd, n }),
        -4 => cstr.print(&ini.assetPath, "{s}{s}.rle", .{ cd, n }),
        else => cstr.print(&ini.assetPath, "{s}{s}{d}.bmp", .{ cd, n, kind }),
    };
}

/// The next non-blank character, not consumed.
// @orig 1018:9dec ini_peek_char
pub fn peekChar(ini: *Ini, plat: Platform, fixes: Fixes, fd: File) Error!u8 {
    const c = try nextChar(ini, plat, fixes, fd);
    unread(plat, fd);
    return c;
}

/// The CRT `sscanf(line, "%d,%d,%d,%s ,%d ", a, b, c, name, value)`: `%d`
/// skips white space and stores 16 bits, `,` must match exactly, `%s` skips
/// white space and takes the run of non-white-space (commas included), a space
/// skips white space. Returns the number of conversions, stopping at the
/// first failure; fields are stored as they are converted.
fn scanWave(line: []const u8, cache: *[3]u16, name: []u8, value: *i16) u8 {
    var p: usize = 0;
    var count: u8 = 0;
    for (0..3) |i| {
        if (i > 0) {
            if (p >= line.len or line[p] != ',') return count;
            p += 1;
        }
        const v = scanInt(line, &p) orelse return count;
        cache[i] = @truncate(@as(u32, @bitCast(v)));
        count += 1;
    }
    if (p >= line.len or line[p] != ',') return count;
    p += 1;
    while (p < line.len and isSpace(line[p])) p += 1;
    const start = p;
    while (p < line.len and !isSpace(line[p])) p += 1;
    if (p == start) return count;
    cstr.copy(name, line[start..p]);
    count += 1;
    while (p < line.len and isSpace(line[p])) p += 1;
    if (p >= line.len or line[p] != ',') return count;
    p += 1;
    const v = scanInt(line, &p) orelse return count;
    value.* = @truncate(v);
    return count + 1;
}

/// `%d`: optional white space, optional sign, at least one digit.
fn scanInt(line: []const u8, p: *usize) ?i32 {
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
    return @bitCast(if (neg) 0 -% v else v);
}

/// Scans the current section's `WAVE=` lines for the one whose first three
/// numbers equal `number`, `arg2`, `arg3`; its file name goes to `wave_name`
/// and its last number to `value`. The numbers read are left in `cache`
/// (`g_waveCacheA..C`, the sound unit's `cache`), also for non-matching lines.
/// True when found or when the section ends; false when no `WAVE=` key is
/// left; a malformed line shows the fatal box and returns false. `wave_name`
/// and `value` are only written
/// for lines that are parsed (maybe not the matching one).
// @orig 1018:aa14 ini_find_wave
pub fn findWave(
    ini: *Ini,
    plat: Platform,
    fixes: Fixes,
    fd: File,
    number: i16,
    arg2: i16,
    arg3: i16,
    cache: *[3]u16,
    wave_name: []u8,
    value: *i16,
) Error!bool {
    var line: [257]u8 = @splat(0);
    while (true) {
        const p = try peekChar(ini, plat, fixes, fd);
        const c = if (isLower(p)) p - 0x20 else p;
        // The original peeks a second time; the file position is unchanged.
        _ = try peekChar(ini, plat, fixes, fd);
        if (c == 'W') {
            if (!try findKey(ini, plat, fixes, fd, "WAVE")) return false;
            _ = try readLine(plat, fixes, fd, &line);
            if (scanWave(cstr.slice(&line), cache, wave_name, value) != 5)
                return try fatalError(plat, fixes, msg_wave_fields) != 0;
            if (cache[0] == @as(u16, @bitCast(number)) and
                @as(u16, @bitCast(arg2)) == cache[1] and
                @as(u16, @bitCast(arg3)) == cache[2]) return true;
        }
        _ = try readLine(plat, fixes, fd, null);
        if (c == '[') return true;
    }
}

/// Low word of the file's current position.
// @orig 1018:aafa ini_tell
pub fn tell(plat: Platform, fd: File) i16 {
    return @truncate(plat.seek(fd, 0, .cur));
}

/// Moves to an absolute position; returns the low word of the result.
// @orig 1018:ab12 ini_seek
pub fn seek(plat: Platform, fd: File, pos: i32) i16 {
    return @truncate(plat.seek(fd, pos, .set));
}

/// Reseeds the CRT generator from the clock and returns `rand() % n`
/// (C remainder; `n` must not be 0, as the original would fault).
// @orig 1018:ab30 random_below
pub fn randomBelow(rand: *crt.Rand, plat: Platform, n: i16) i16 {
    rand.srand(@truncate(@as(u32, @bitCast(plat.unixTime()))));
    return @rem(rand.rand(), n);
}

/// Concatenates `a` and `b` into `buf` (the original's shared buffer at
/// DGROUP 9d26, 256 bytes: `g.concatBuf`) and returns the result.
// @orig 1018:aeaa concat_strings
pub fn concatStrings(buf: []u8, a: []const u8, b: []const u8) []const u8 {
    return cstr.print(buf, "{s}{s}", .{ cstr.slice(a), cstr.slice(b) });
}

// @orig 1018:98f2 ini_build_section_index oracle=asset
test "buildSectionIndex and findWave agree with assets/CASSETA.INI" {
    const Headless = @import("platform/headless.zig").Headless;
    const gpa = std.testing.allocator;
    var h = Headless.init(gpa, std.testing.io, .{});
    defer h.deinit();
    const plat = h.platform();
    const text = try std.Io.Dir.cwd().readFileAlloc(std.testing.io, "assets/CASSETA.INI", gpa, .limited(1 << 20));
    defer gpa.free(text);

    const fd = open(plat, "\\CASSETA.INI") orelse return error.SkipZigTest;
    defer close(plat, fd);
    var ini: Ini = .{};
    try std.testing.expectEqual(@as(i16, 1), try buildSectionIndex(&ini, plat, .{}, fd));

    // Oracle: every `[name]` line; the offset is just after its CR (readLine stops at CR, before the LF).
    var expected: usize = 0;
    var pos: usize = 0;
    var lines = std.mem.splitScalar(u8, text, '\n');
    while (lines.next()) |line| : (pos += line.len + 1) {
        const t = std.mem.trim(u8, line, " \t\r");
        if (t.len < 3 or t[0] != '[' or t[t.len - 1] != ']') continue;
        var lower: [64]u8 = undefined;
        const name = std.ascii.lowerString(&lower, t[1 .. t.len - 1]);
        try std.testing.expectEqual(@as(i32, @intCast(pos + line.len)), ini_sections.findSectionOffset(&ini.sections, name));
        expected += 1;
    }
    try std.testing.expectEqual(@as(i16, @intCast(expected)), ini.sections.count);

    // First WAVE line of the file.
    const wpos = std.mem.indexOf(u8, text, "\nWAVE=").?;
    const wline = std.mem.sliceTo(text[wpos + 6 ..], '\r');
    var nums: [4]i16 = undefined;
    var it = std.mem.tokenizeAny(u8, wline, ", ");
    for (0..3) |i| nums[i] = try std.fmt.parseInt(i16, it.next().?, 10);
    const wname = it.next().?;
    nums[3] = try std.fmt.parseInt(i16, it.next().?, 10);
    // Find the section holding it: seek to the last header before wpos.
    var best: i32 = 0;
    for (ini.sections.entries[0..@intCast(ini.sections.count)]) |e| {
        if (e.offset <= wpos and e.offset > best) best = e.offset;
    }
    _ = seek(plat, fd, best);
    var cache: [3]u16 = undefined;
    var name_buf: [50]u8 = undefined;
    var value: i16 = -1;
    try std.testing.expect(try findWave(&ini, plat, .{}, fd, nums[0], nums[1], nums[2], &cache, &name_buf, &value));
    try std.testing.expectEqualStrings(wname, cstr.slice(&name_buf));
    try std.testing.expectEqual(nums[3], value);
}

// @orig 1018:9d4e ini_asset_path oracle=documented
test "assetPath picks the extension by kind" {
    var ini: Ini = .{};
    try std.testing.expectEqualStrings("D:\\X.avi", assetPath(&ini, "C:\\", "D:\\", "X", -2));
    try std.testing.expectEqualStrings("C:\\X.wav", assetPath(&ini, "C:\\", "D:\\", "X", -3));
    try std.testing.expectEqualStrings("C:\\X7.bmp", assetPath(&ini, "C:\\", "D:\\", "X", 7));
}
