//! The game state as JSON, for bug reports (debug code, not a port unit):
//! the web page's "Relatório" button (`noite_report`, src/web_main.zig) and
//! the harness's `report FILE` script command write the same document, so
//! a native reproduction can be compared with what a player sent.
//!
//! Strings from the game (code page 1252) are written as JSON escapes for
//! every byte outside printable ASCII (`\u00XX`, the byte's Latin-1 code
//! point), so the output is ASCII. List walks stop after `max_walk` links:
//! the report is taken in whatever state a bug left, loops included.

const std = @import("std");
const Game = @import("../core/game.zig").Game;
const object = @import("../core/object.zig");
const Object = object.Object;
const ObjectList = object.ObjectList;
const cstr = @import("../core/cstr.zig");
const harness = @import("harness.zig");

const Writer = std.Io.Writer;
const max_walk = 500;

/// The whole report (one JSON object, no trailing newline).
pub fn write(g: *const Game, w: *Writer) Writer.Error!void {
    var j: J = .{ .w = w };
    try j.open('{');
    try j.field("ticks", g.plat.ticks());
    try j.key("scene");
    if (g.scene) |s| {
        try j.open('{');
        try j.field("name", Str{ .s = &s.name });
        try j.field("number", s.sceneNumber);
        try j.field("hasPlayer", s.hasPlayer);
        try j.field("hasStatusBar", s.hasStatusBar);
        try j.field("hasControlPanel", s.hasControlPanel);
        try j.field("is1Animation", s.is1Animation);
        try j.field("isClickExit", s.isClickExit);
        try j.field("mayDropObject", s.mayDropObject);
        try j.field("handlerEnabled", s.handlerEnabled);
        try j.field("exitCount", s.exitCount);
        if (s.backdrop) |bd| {
            try j.field("originX", bd.originX);
            try j.field("originY", bd.originY);
        }
        try j.close('}');
    } else try j.raw("null");
    try j.field("prevSceneNumber", g.prevSceneNumber);
    try j.field("fixes", if (std.meta.eql(g.fixes, .all())) "all" else if (std.meta.eql(g.fixes, .{})) "none" else "some");
    try j.field("oneButton", g.oneButton.filter != null);
    try j.field("lives", g.lives);
    try j.field("score", g.score);
    try j.field("inputLocked", g.inputLocked);
    try j.field("exitPending", g.exitPending);
    try j.field("aviPlaying", Ref{ .o = g.aviPlaying });
    try j.field("itemSelected", g.itemSelected);
    try j.field("selectedItem", Ref{ .o = g.selectedItem });
    try j.field("minigameWon", g.minigameWon);

    try j.key("drag");
    try j.open('{');
    try j.field("item", Ref{ .o = g.drag.item });
    try j.field("x", g.drag.x);
    try j.field("y", g.drag.y);
    try j.field("press", @tagName(g.oneButton.press));
    try j.field("held", g.oneButton.held);
    try j.key("pending");
    if (g.oneButton.pending) |pd| {
        try j.open('{');
        try j.field("target", Ref{ .o = pd.target });
        try j.field("x", pd.x);
        try j.field("y", pd.y);
        try j.close('}');
    } else try j.raw("null");
    try j.close('}');

    try j.key("panel");
    if (g.controlPanel) |cp| {
        try j.open('{');
        try j.field("open", cp.panel.isOpen != 0);
        try j.field("slideDir", cp.panel.slideDir);
        try j.field("slideStepsLeft", cp.panel.slideStepsLeft);
        try j.field("visible", cp.visible);
        try j.field("message", Str{ .s = &cp.panel.message });
        try j.close('}');
    } else try j.raw("null");

    try j.key("player");
    if (g.player) |pl| {
        try j.open('{');
        try j.field("x", pl.x);
        try j.field("y", pl.y);
        try j.field("curStrip", pl.curStrip);
        try j.field("curFrame", pl.curFrame);
        try j.field("visible", pl.visible);
        try j.field("moving", pl.mover.moving);
        try j.field("allowOffscreen", pl.mover.allowOffscreen);
        try j.field("targetX", pl.mover.targetX);
        try j.field("targetY", pl.mover.targetY);
        try j.field("worldX", pl.o3d.worldX);
        try j.field("worldDepth", pl.o3d.worldDepth);
        try j.field("worldElev", pl.o3d.worldElev);
        try j.close('}');
        try j.key("inventory");
        try items(&j, &pl.actor.inventory);
    } else {
        try j.raw("null");
        try j.field("inventory", [0]u8{});
    }
    try j.key("usedObjects");
    try items(&j, &g.usedObjects);

    try j.key("objects");
    try j.open('[');
    if (g.scene) |s| {
        var it = s.objects.head;
        var n: usize = 0;
        while (it) |o| : (it = o.next) {
            if (n == max_walk) break;
            n += 1;
            try j.item();
            try obj(&j, g, o);
        }
    }
    try j.close(']');

    try j.key("drawList");
    try j.open('[');
    {
        var it = g.drawList.head;
        var n: usize = 0;
        while (it) |node| : (it = node.next) {
            if (n == max_walk) break;
            n += 1;
            try j.item();
            if (node.item) |o| try obj(&j, g, o) else try j.raw("null");
        }
    }
    try j.close(']');

    try j.key("updateList");
    try j.open('[');
    for (g.updateList.items[0..@intCast(std.math.clamp(g.updateList.count, 0, g.updateList.items.len))]) |o| {
        try j.item();
        try j.value(Ref{ .o = o });
    }
    try j.close(']');

    try j.key("portables");
    try j.open('[');
    for (g.livePortables.items) |o| {
        try j.item();
        try j.open('{');
        try j.field("id", o.id);
        try j.field("name", name(o));
        try j.field("scene", Str{ .s = &o.sceneName });
        try j.field("prevScene", Str{ .s = &o.portable.prevSceneName });
        try j.field("homeScene", Str{ .s = &o.portable.homeSceneName });
        try j.field("list", listName(g, o.ownerList));
        try j.field("owner", Ref{ .o = o.portable.owner });
        try j.field("visible", o.visible);
        try j.field("x", o.x);
        try j.field("y", o.y);
        try j.field("worldElev", o.o3d.worldElev);
        try j.close('}');
    }
    try j.close(']');

    try j.key("timers");
    try j.open('[');
    for (g.queue.timers[0..@min(g.queue.timer_count, g.queue.timers.len)]) |t| {
        try j.item();
        try j.open('{');
        try j.field("kind", @tagName(t.kind));
        try j.field("id", t.id);
        try j.field("period", t.period);
        try j.field("due", t.due);
        try j.close('}');
    }
    try j.close(']');

    try j.key("queue");
    try j.open('{');
    try j.field("posted", g.queue.posted.len);
    try j.field("input", g.queue.input.len);
    try j.field("paintPending", g.queue.paint_pending);
    try j.close('}');

    try j.key("trail");
    try j.open('[');
    for (0..g.trail.size()) |i| {
        const e = g.trail.get(i);
        try j.item();
        try j.open('{');
        try j.field("at", e.at);
        try j.field("how", &[1]u8{e.how});
        try j.field("depth", e.depth);
        try j.field("msg", std.mem.trimEnd(u8, harness.msgName(e.m.id), " "));
        try j.field("id", e.m.id);
        try j.field("wparam", e.m.wparam);
        try j.field("lparam", @as(u32, @bitCast(e.m.lparam)));
        try j.close('}');
    }
    try j.close(']');
    try j.close('}');
}

/// The report in a new buffer (caller frees).
pub fn alloc(g: *const Game, gpa: std.mem.Allocator) ![]u8 {
    var out: Writer.Allocating = .init(gpa);
    defer out.deinit();
    write(g, &out.writer) catch return error.OutOfMemory;
    return out.toOwnedSlice();
}

/// The inventory or used items: `[{id, name}]`.
fn items(j: *J, list: *const ObjectList) !void {
    try j.open('[');
    var it = list.head;
    var n: usize = 0;
    while (it) |o| : (it = o.next) {
        if (n == max_walk) break;
        n += 1;
        try j.item();
        try j.open('{');
        try j.field("id", o.id);
        try j.field("name", name(o));
        try j.close('}');
    }
    try j.close(']');
}

fn obj(j: *J, g: *const Game, o: *const Object) !void {
    try j.open('{');
    try j.field("id", o.id);
    try j.field("kind", @tagName(o.kind));
    try j.field("name", name(o));
    try j.field("x", o.x);
    try j.field("y", o.y);
    try j.field("visible", o.visible);
    try j.field("curStrip", o.curStrip);
    try j.field("curFrame", o.curFrame);
    try j.field("dirty", rect(o.dirty));
    try j.field("clip", rect(o.clip));
    if (o.kind.isAnimation()) {
        try j.field("animTimer", o.anim.timerId);
        try j.field("animPeriod", o.anim.timerPeriod);
        try j.field("animRunning", o.anim.running);
        try j.field("animArmed", armed(g, o.anim.timerId));
        if (o.anim.isAvi != 0) try j.field("avi", Str{ .s = &o.anim.aviName });
    }
    if (o.kind.isMover()) {
        try j.field("moveTimer", o.mover.timerId);
        try j.field("moving", o.mover.moving);
        try j.field("moveArmed", armed(g, o.mover.timerId));
    }
    if (o.kind == .exit) {
        try j.field("exitTo", Str{ .s = &o.exit.sceneName });
        try j.field("exitPlaying", o.exit.playing);
    }
    if (o.kind == .portable) try j.field("scene", Str{ .s = &o.sceneName });
    try j.close('}');
}

fn armed(g: *const Game, id: i16) bool {
    return g.queue.findTimer(.normal, @bitCast(id)) != null;
}

fn rect(r: object.Rect) [4]i16 {
    return .{ r.left, r.top, r.right, r.bottom };
}

/// The object's INI bitmap name (its first strip's file; a portable in
/// the inventory has only its icon's, `<name>2`), or its clip's.
fn name(o: *const Object) Str {
    if (o.frames.len > 0) if (o.frames[0].dib) |d| return .{ .s = &d.name };
    if (o.kind == .portable) if (o.portable.icon) |d| return .{ .s = &d.name };
    if (o.kind.isAnimation() and o.anim.isAvi != 0) return .{ .s = &o.anim.aviName };
    return .{ .s = "" };
}

fn listName(g: *const Game, list: ?*const ObjectList) []const u8 {
    const l = list orelse return "none";
    if (l == &g.globalObjects) return "global";
    if (l == &g.usedObjects) return "used";
    if (g.scene) |s| if (l == &s.objects) return "scene";
    if (g.player) |pl| if (l == &pl.actor.inventory) return "inventory";
    return "other";
}

/// A C string (up to its NUL, trailing blanks dropped: INI names are
/// padded), written escaped.
const Str = struct { s: []const u8 };
/// An object by id (null for none).
const Ref = struct { o: ?*const Object };

/// A minimal JSON writer: `field`/`item` put the commas.
const J = struct {
    w: *Writer,
    first: bool = true,

    fn open(j: *J, c: u8) !void {
        try j.w.writeByte(c);
        j.first = true;
    }
    fn close(j: *J, c: u8) !void {
        try j.w.writeByte(c);
        j.first = false;
    }
    fn item(j: *J) !void {
        if (!j.first) try j.w.writeByte(',');
        j.first = false;
    }
    fn key(j: *J, k: []const u8) !void {
        try j.item();
        try j.str(k);
        try j.w.writeByte(':');
    }
    fn raw(j: *J, s: []const u8) !void {
        try j.w.writeAll(s);
        j.first = false;
    }
    fn field(j: *J, k: []const u8, v: anytype) !void {
        try j.key(k);
        try j.value(v);
    }
    fn value(j: *J, v: anytype) !void {
        const T = @TypeOf(v);
        if (T == Str) return j.str(std.mem.trimEnd(u8, cstr.slice(v.s), " "));
        if (T == Ref) return if (v.o) |o| j.w.print("{d}", .{o.id}) else j.w.writeAll("null");
        switch (@typeInfo(T)) {
            .bool => try j.w.writeAll(if (v) "true" else "false"),
            .int, .comptime_int => try j.w.print("{d}", .{v}),
            .array => {
                try j.open('[');
                for (v) |x| {
                    try j.item();
                    try j.value(x);
                }
                try j.close(']');
            },
            .pointer => try j.str(v),
            else => @compileError("report: no JSON for " ++ @typeName(T)),
        }
        j.first = false;
    }
    fn str(j: *J, s: []const u8) !void {
        try j.w.writeByte('"');
        for (s) |c| switch (c) {
            '"' => try j.w.writeAll("\\\""),
            '\\' => try j.w.writeAll("\\\\"),
            0x20...0x21, 0x23...0x5b, 0x5d...0x7e => try j.w.writeByte(c),
            else => try j.w.print("\\u{x:0>4}", .{c}),
        };
        try j.w.writeByte('"');
    }
};

test "the report of a game without a scene is valid JSON" {
    var t = try @import("../core/game.zig").TestGame.init(std.testing.allocator);
    defer t.deinit();
    const text = try alloc(t.game, std.testing.allocator);
    defer std.testing.allocator.free(text);
    const parsed = try std.json.parseFromSlice(std.json.Value, std.testing.allocator, text, .{});
    defer parsed.deinit();
    try std.testing.expect(parsed.value.object.get("scene").? == .null);
}
