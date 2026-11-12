//! Port unit `ini_sections` (module). INI section index: section table lookup (trial unit).
//!
//! The original keeps the section table in two DGROUP globals filled while
//! `CASSETA.INI` is scanned. The port holds it in `SectionTable`, a plain
//! value that the INI module will embed in the `Game` state struct and pass
//! down explicitly (no global singleton), so this lookup is testable on its
//! own.

const std = @import("std");

/// Capacity of the original's `g_iniSections` array.
pub const max_sections = 150;

/// Length of `IniSection.name`, NUL terminator included.
pub const name_len = 40;

/// One section header found in the INI file.
pub const IniSection = extern struct {
    // @orig IniSection+0x0
    /// Section name without the brackets, NUL-terminated.
    name: [name_len]u8,
    // @orig IniSection+0x28
    /// Byte offset of the section in the INI file (a C `long`).
    offset: i32,
};

/// The section table of the INI file in use.
pub const SectionTable = struct {
    // @orig g_iniSections
    entries: [max_sections]IniSection = undefined,
    // @orig g_iniSectionCount
    /// Number of valid entries; the original keeps it as a C `int` (16 bits).
    /// Invariant: `0 <= count <= max_sections`.
    count: i16 = 0,
};

/// Looks `name` up in `table`, ignoring ASCII case, and returns the section's
/// file offset, or -1 if there is none (the original's sentinel, kept so the
/// INI module's callers translate one-to-one). The first match wins. Both
/// names end at the first NUL byte, as C strings do.
// @orig 1018:99ac ini_find_section_offset
pub fn findSectionOffset(table: *const SectionTable, name: []const u8) i32 {
    // The CRT `_fstricmp` (1008:0566) is replaced by `std.ascii.eqlIgnoreCase`,
    // which folds A-Z only, like the CRT.
    const wanted = std.mem.sliceTo(name, 0);
    var i: i16 = 0;
    while (i < table.count) : (i += 1) {
        const entry = &table.entries[@intCast(i)];
        if (std.ascii.eqlIgnoreCase(std.mem.sliceTo(&entry.name, 0), wanted)) return entry.offset;
    }
    return -1;
}

fn addSection(table: *SectionTable, name: []const u8, offset: i32) void {
    var entry = IniSection{ .name = @splat(0), .offset = offset };
    @memcpy(entry.name[0..name.len], name);
    table.entries[@intCast(table.count)] = entry;
    table.count += 1;
}

// @orig 1018:99ac ini_find_section_offset oracle=asset
test "findSectionOffset finds every section header of assets/CASSETA.INI" {
    const gpa = std.testing.allocator;
    const text = try std.Io.Dir.cwd().readFileAlloc(std.testing.io, "assets/CASSETA.INI", gpa, .limited(1 << 20));
    defer gpa.free(text);

    // The oracle is the file itself: every line `[name]` is a section whose
    // offset is where that line starts.
    var table: SectionTable = .{};
    var pos: usize = 0;
    var lines = std.mem.splitScalar(u8, text, '\n');
    while (lines.next()) |line| : (pos += line.len + 1) {
        const trimmed = std.mem.trimEnd(u8, line, "\r");
        if (trimmed.len < 3 or trimmed[0] != '[' or trimmed[trimmed.len - 1] != ']') continue;
        addSection(&table, trimmed[1 .. trimmed.len - 1], @intCast(pos));
    }
    try std.testing.expect(table.count > 100);

    var found: usize = 0;
    for (table.entries[0..@intCast(table.count)]) |entry| {
        const name = std.mem.sliceTo(&entry.name, 0);
        const upper = try std.ascii.allocUpperString(gpa, name);
        defer gpa.free(upper);
        const off = findSectionOffset(&table, upper);
        // the file text at the offset is the header the lookup claims
        try std.testing.expect(off >= 0);
        const at: usize = @intCast(off);
        try std.testing.expectEqual(@as(u8, '['), text[at]);
        try std.testing.expect(std.ascii.eqlIgnoreCase(text[at + 1 ..][0..name.len], name));
        found += 1;
    }
    try std.testing.expectEqual(@as(usize, @intCast(table.count)), found);

    try std.testing.expectEqual(@as(i32, -1), findSectionOffset(&table, "nonexistent"));
    try std.testing.expectEqual(@as(i32, -1), findSectionOffset(&table, ""));
}

// @orig 1018:99ac ini_find_section_offset oracle=documented
test "findSectionOffset on an empty table returns -1" {
    const table: SectionTable = .{};
    try std.testing.expectEqual(@as(i32, -1), findSectionOffset(&table, "Casseta"));
}
