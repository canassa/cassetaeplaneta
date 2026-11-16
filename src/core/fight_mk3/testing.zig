//! A synthetic character pack for the tests (no art, no private files): one
//! 1x1 picture per frame and boxes the size of a standing fighter, so the
//! mechanics can be tested without the sprites.

const std = @import("std");
const character = @import("character.zig");

/// The pack's bytes (owned by the caller, for `Character.load`). Every
/// clip has frame 0 (a standing hurt box), attacks have frame 1 (the
/// active one: a 70-px limb at chest height); crouching clips use frame 2
/// (hurt box up to the waist).
pub fn pack(gpa: std.mem.Allocator) ![]u8 {
    @setEvalBranchQuota(200_000);
    var js: std.ArrayList(u8) = .empty;
    defer js.deinit(gpa);
    try js.appendSlice(gpa,
        \\{"name":"test","scale":2,"stand":110,"palette":[[0,0,0],[255,255,255]],"frames":[
        \\{"w":1,"h":1,"ox":0,"oy":-1,"off":0,"hurt":[-26,-110,26,0],"hit":null},
        \\{"w":1,"h":1,"ox":0,"oy":-1,"off":1,"hurt":[-26,-110,26,0],"hit":[20,-100,90,-60]},
        \\{"w":1,"h":1,"ox":0,"oy":-1,"off":0,"hurt":[-26,-55,26,0],"hit":null},
        \\{"w":1,"h":1,"ox":0,"oy":-1,"off":1,"hurt":[-26,-55,26,0],"hit":[20,-45,90,-20]},
        \\{"w":1,"h":1,"ox":0,"oy":-1,"off":1,"hurt":null,"hit":null}],"clips":[
    );
    inline for (@typeInfo(character.Anim).@"enum".field_names, 0..) |fname, i| {
        const attack = comptime isAttack(fname);
        const low = comptime std.mem.indexOf(u8, fname, "crouch") != null or std.mem.eql(u8, fname, "block_lo") or std.mem.eql(u8, fname, "hit_lo") or std.mem.startsWith(u8, fname, "c_") or std.mem.eql(u8, fname, "uppercut") or std.mem.eql(u8, fname, "sweep");
        const down = comptime std.mem.eql(u8, fname, "fall") or std.mem.eql(u8, fname, "down");
        const s = if (down)
            \\{"name":"
        else
            \\{"name":"
        ;
        try js.appendSlice(gpa, if (i > 0) "," else "");
        try js.appendSlice(gpa, s);
        try js.appendSlice(gpa, fname);
        if (attack) {
            const a: []const u8 = if (low) "3" else "1";
            const rest = if (low) "2" else "0";
            try js.appendSlice(gpa, "\",\"frames\":[");
            try js.appendSlice(gpa, rest);
            try js.appendSlice(gpa, ",");
            try js.appendSlice(gpa, a);
            try js.appendSlice(gpa, ",");
            try js.appendSlice(gpa, rest);
            try js.appendSlice(gpa, "],\"ms\":[100,100,100],\"loop\":false,\"active\":[1,1]}");
        } else {
            const fr: []const u8 = if (down) "4" else if (low) "2" else "0";
            try js.appendSlice(gpa, "\",\"frames\":[");
            try js.appendSlice(gpa, fr);
            try js.appendSlice(gpa, "],\"ms\":[100],\"loop\":true}");
        }
    }
    try js.appendSlice(gpa, "]}");
    var out = try gpa.alloc(u8, 8 + js.items.len + 2);
    @memcpy(out[0..4], "MK3P");
    std.mem.writeInt(u32, out[4..8], @intCast(js.items.len), .little);
    @memcpy(out[8..][0..js.items.len], js.items);
    out[8 + js.items.len] = 1;
    out[8 + js.items.len + 1] = 1;
    return out;
}

fn isAttack(name: []const u8) bool {
    const names = [_][]const u8{ "lp", "hp", "lk", "hk", "roundhouse", "c_lp", "uppercut", "c_lk", "sweep", "j_lp", "j_hp", "j_lk", "j_hk", "throw" };
    for (names) |n| if (std.mem.eql(u8, n, name)) return true;
    return false;
}
