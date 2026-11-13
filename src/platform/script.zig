//! Scripted input for the test harness (`noite --input FILE`). Platform/debug
//! code, not a port unit. One command per line, `#` starts a comment:
//!
//!     <time> <command> [args]
//!
//! `<time>` is milliseconds since start (`1500`), or relative to the
//! previous line (`+500`). Commands:
//!
//!     move X Y          mouse move (window coordinates)
//!     click X Y         move, left button down, up 50 ms later
//!     rclick X Y        move, right button down, up 50 ms later
//!     ldown|lup|rdown|rup X Y
//!     key K             key down + up (K: a number, or left/right/up/down/
//!                       return/escape/space/f1..f12)
//!     hold K MS         key down, up MS later (the arrows walk while held)
//!     dump [NAME]       write a frame dump (needs --dump DIR)
//!     scene NAME [X Y PLAYER PANEL STATUS ANIM CLICK]
//!                       switch to an INI scene now (as `--scene`)
//!     log TEXT          print a marker in the log
//!     state             print the scene, player, inventory, lives, score
//!     expect NAME       fail the run (exit 1) unless NAME is the scene
//!     wait NAME [MS]    hold the script until NAME is the scene (fail
//!                       after MS, default 120000); every later time
//!                       moves by the time waited
//!     quit              end the run
//!
//! Mouse commands keep track of the buttons held, as `wParam` (MK_*).

const std = @import("std");
const msg = @import("../core/msg.zig");
const wm = msg.wm;

pub const Action = union(enum) {
    input: msg.Msg,
    dump: []const u8,
    scene: SceneJump,
    log: []const u8,
    state,
    expect: []const u8,
    wait: Wait,
    quit,
};

pub const Wait = struct { name: []const u8, max_ms: u32 };

pub const SceneJump = struct {
    name: []const u8,
    /// Null: derived from the exits that lead to the scene.
    flags: ?Flags = null,

    pub const Flags = struct {
        x: i16 = 0,
        y: i16 = 0,
        player: i16 = 0,
        panel: i16 = 0,
        status: i16 = 0,
        anim: i16 = 0,
        click: i16 = 0,
    };
};

pub const Step = struct { at: u32, action: Action };

pub const Script = struct {
    steps: std.ArrayList(Step) = .empty,
    /// Owns the text the actions' slices point into.
    text: []u8 = &.{},
    next: usize = 0,
    /// How far the `wait`s have pushed the remaining steps.
    shift: u32 = 0,
    /// A `wait` in progress: its deadline.
    waiting_until: ?u32 = null,
    /// A `wait` gave up.
    timed_out: bool = false,

    pub fn deinit(s: *Script, gpa: std.mem.Allocator) void {
        s.steps.deinit(gpa);
        gpa.free(s.text);
    }

    /// When the script next needs the loop (`now` while waiting: it polls
    /// the scene every 50 ms).
    pub fn nextAt(s: *const Script, now: u32) ?u32 {
        if (s.next >= s.steps.items.len) return null;
        if (s.waiting_until != null) return now + 50;
        return s.steps.items[s.next].at + s.shift;
    }

    /// The next action due at `now`, if any; `scene` is the current scene's
    /// name (for `wait`, which is consumed here).
    pub fn due(s: *Script, now: u32, scene: []const u8) ?Action {
        while (s.next < s.steps.items.len) {
            const st = s.steps.items[s.next];
            if (st.at + s.shift > now) return null;
            if (st.action != .wait) {
                s.next += 1;
                return st.action;
            }
            const w = st.action.wait;
            if (std.ascii.eqlIgnoreCase(std.mem.trim(u8, scene, " "), w.name)) {
                s.shift = now - st.at;
                s.waiting_until = null;
                s.next += 1;
                continue;
            }
            const deadline = s.waiting_until orelse now + w.max_ms;
            if (now >= deadline) {
                std.debug.print("[{d}] wait {s}: FAILED, the scene is {s}\n", .{ now, w.name, scene });
                s.timed_out = true;
                s.waiting_until = null;
                s.next += 1;
                continue;
            }
            s.waiting_until = deadline;
            return null;
        }
        return null;
    }
};

pub const ParseError = error{ BadScript, OutOfMemory };

/// Parses `text` (takes ownership of it). Errors name the line on stderr.
pub fn parse(gpa: std.mem.Allocator, text: []u8) ParseError!Script {
    var s: Script = .{ .text = text };
    errdefer s.steps.deinit(gpa);
    var t: u32 = 0;
    var buttons: u16 = 0;
    var line_no: usize = 0;
    var lines = std.mem.splitScalar(u8, text, '\n');
    while (lines.next()) |raw| {
        line_no += 1;
        const line = std.mem.trim(u8, raw[0 .. std.mem.indexOfScalar(u8, raw, '#') orelse raw.len], " \t\r");
        if (line.len == 0) continue;
        var words = std.mem.tokenizeAny(u8, line, " \t");
        const time_word = words.next().?;
        const cmd = words.next() orelse return bad(line_no, "missing command");
        if (time_word[0] == '+') {
            t += std.fmt.parseInt(u32, time_word[1..], 10) catch return bad(line_no, "bad time");
        } else {
            t = std.fmt.parseInt(u32, time_word, 10) catch return bad(line_no, "bad time");
        }
        const eq = std.mem.eql;
        if (eq(u8, cmd, "move") or eq(u8, cmd, "click") or eq(u8, cmd, "rclick") or
            eq(u8, cmd, "ldown") or eq(u8, cmd, "lup") or eq(u8, cmd, "rdown") or eq(u8, cmd, "rup"))
        {
            const x = try num(u16, words.next(), line_no);
            const y = try num(u16, words.next(), line_no);
            const mv = msg.Msg.make(wm.mousemove, buttons, x, y);
            if (eq(u8, cmd, "move")) {
                try s.steps.append(gpa, .{ .at = t, .action = .{ .input = mv } });
            } else if (eq(u8, cmd, "click") or eq(u8, cmd, "rclick")) {
                const right = eq(u8, cmd, "rclick");
                const bit = if (right) msg.mk.rbutton else msg.mk.lbutton;
                try s.steps.append(gpa, .{ .at = t, .action = .{ .input = mv } });
                try s.steps.append(gpa, .{ .at = t, .action = .{ .input = msg.Msg.make(if (right) wm.rbuttondown else wm.lbuttondown, buttons | bit, x, y) } });
                try s.steps.append(gpa, .{ .at = t + 50, .action = .{ .input = msg.Msg.make(if (right) wm.rbuttonup else wm.lbuttonup, buttons, x, y) } });
            } else {
                const right = cmd[0] == 'r';
                const down = eq(u8, cmd[1..], "down");
                const bit = if (right) msg.mk.rbutton else msg.mk.lbutton;
                if (down) buttons |= bit else buttons &= ~bit;
                const id = if (right) (if (down) wm.rbuttondown else wm.rbuttonup) else (if (down) wm.lbuttondown else wm.lbuttonup);
                try s.steps.append(gpa, .{ .at = t, .action = .{ .input = mv } });
                try s.steps.append(gpa, .{ .at = t, .action = .{ .input = msg.Msg.make(id, buttons, x, y) } });
            }
        } else if (eq(u8, cmd, "key")) {
            const k = words.next() orelse return bad(line_no, "missing key");
            const v = keyCode(k) orelse return bad(line_no, "unknown key");
            try s.steps.append(gpa, .{ .at = t, .action = .{ .input = .{ .id = wm.keydown, .wparam = v } } });
            try s.steps.append(gpa, .{ .at = t + 50, .action = .{ .input = .{ .id = wm.keyup, .wparam = v } } });
        } else if (eq(u8, cmd, "hold")) {
            const k = words.next() orelse return bad(line_no, "missing key");
            const v = keyCode(k) orelse return bad(line_no, "unknown key");
            const ms = try num(u32, words.next(), line_no);
            try s.steps.append(gpa, .{ .at = t, .action = .{ .input = .{ .id = wm.keydown, .wparam = v } } });
            try s.steps.append(gpa, .{ .at = t + ms, .action = .{ .input = .{ .id = wm.keyup, .wparam = v } } });
        } else if (eq(u8, cmd, "dump")) {
            try s.steps.append(gpa, .{ .at = t, .action = .{ .dump = words.next() orelse "" } });
        } else if (eq(u8, cmd, "scene")) {
            var j: SceneJump = .{ .name = words.next() orelse return bad(line_no, "missing scene") };
            if (words.peek() != null) {
                var f: SceneJump.Flags = .{};
                f.x = try num(i16, words.next(), line_no);
                f.y = try num(i16, words.next(), line_no);
                f.player = try num(i16, words.next(), line_no);
                f.panel = try num(i16, words.next(), line_no);
                f.status = try num(i16, words.next(), line_no);
                if (words.peek() != null) f.anim = try num(i16, words.next(), line_no);
                if (words.peek() != null) f.click = try num(i16, words.next(), line_no);
                j.flags = f;
            }
            try s.steps.append(gpa, .{ .at = t, .action = .{ .scene = j } });
        } else if (eq(u8, cmd, "log")) {
            try s.steps.append(gpa, .{ .at = t, .action = .{ .log = std.mem.trim(u8, words.rest(), " \t") } });
        } else if (eq(u8, cmd, "wait")) {
            const name = words.next() orelse return bad(line_no, "missing scene");
            const max: u32 = if (words.peek() != null) try num(u32, words.next(), line_no) else 120_000;
            try s.steps.append(gpa, .{ .at = t, .action = .{ .wait = .{ .name = name, .max_ms = max } } });
        } else if (eq(u8, cmd, "expect")) {
            try s.steps.append(gpa, .{ .at = t, .action = .{ .expect = words.next() orelse return bad(line_no, "missing scene") } });
        } else if (eq(u8, cmd, "state")) {
            try s.steps.append(gpa, .{ .at = t, .action = .state });
        } else if (eq(u8, cmd, "quit")) {
            try s.steps.append(gpa, .{ .at = t, .action = .quit });
        } else return bad(line_no, "unknown command");
    }
    // Clicks schedule their release 50 ms on: keep the steps in time order
    // (stable, so same-time steps keep the script's order).
    std.sort.insertion(Step, s.steps.items, {}, struct {
        fn lt(_: void, a: Step, b: Step) bool {
            return a.at < b.at;
        }
    }.lt);
    return s;
}

fn bad(line: usize, what: []const u8) ParseError {
    std.debug.print("input script line {d}: {s}\n", .{ line, what });
    return error.BadScript;
}

fn num(comptime T: type, word: ?[]const u8, line: usize) ParseError!T {
    const w = word orelse return bad(line, "missing number");
    return std.fmt.parseInt(T, w, 0) catch bad(line, "bad number");
}

fn keyCode(k: []const u8) ?u16 {
    if (std.fmt.parseInt(u16, k, 0)) |v| return v else |_| {}
    const names = [_]struct { []const u8, u16 }{
        .{ "left", 0x25 },   .{ "up", 0x26 },     .{ "right", 0x27 }, .{ "down", 0x28 },
        .{ "return", 0x0d }, .{ "escape", 0x1b }, .{ "space", 0x20 },
    };
    for (names) |n| if (std.ascii.eqlIgnoreCase(n[0], k)) return n[1];
    if (k.len >= 2 and (k[0] == 'f' or k[0] == 'F')) {
        const n = std.fmt.parseInt(u16, k[1..], 10) catch return null;
        if (n >= 1 and n <= 12) return 0x6f + n;
    }
    return null;
}

test "a script parses into timed input in order" {
    const gpa = std.testing.allocator;
    const text = try gpa.dupe(u8,
        \\# comment
        \\100 click 10 20
        \\+20 key left
        \\200 dump title
        \\+0 scene 1fsala 50 200 1 1 0
    );
    var s = try parse(gpa, text);
    defer s.deinit(gpa);
    try std.testing.expectEqual(@as(usize, 7), s.steps.items.len);
    try std.testing.expectEqual(wm.lbuttondown, s.steps.items[1].action.input.id);
    try std.testing.expectEqual(@as(u32, 120), s.steps.items[2].at); // keydown
    try std.testing.expectEqual(@as(u32, 150), s.steps.items[3].at); // lbuttonup
    try std.testing.expectEqual(@as(i16, 200), s.steps.items[6].action.scene.flags.?.y);
}
