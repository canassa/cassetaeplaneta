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
//!                       return/escape/space/pgup/home/end/insert/a/s/d/f/
//!                       f1..f12)
//!     hold K MS         key down, up MS later (the arrows walk while held)
//!     dump [NAME]       write a frame dump (needs --dump DIR)
//!     scene NAME [X Y PLAYER PANEL STATUS ANIM CLICK]
//!                       switch to an INI scene now (as `--scene`)
//!     log TEXT          print a marker in the log
//!     state             print the scene, player, inventory, lives, score
//!     report FILE       write the state report (src/platform/report.zig,
//!                       the web page's "Relatório") to FILE as JSON
//!     expect NAME [| NAME]
//!                       fail the run (exit 1) unless NAME is the scene;
//!                       the NAME after `|`, when given, is what a run with
//!                       a `--fix` on must be in instead (as `result`)
//!     wait NAME [MS]    hold the script until NAME is the scene (fail
//!                       after MS, default 120000); every later time
//!                       moves by the time waited
//!     take ID           put portable ID (INI Number) in the player's
//!                       inventory (testing; not from the current scene)
//!     drawn ID 0|1      fail the run unless portable ID is (1) or is not
//!                       (0) on the screen: visible and most of its frame
//!                       showing where it stands
//!     pixel X Y INDEX [| INDEX]
//!                       fail the run unless the screen's pixel at X Y has
//!                       palette index INDEX (0x for hex); the INDEX after
//!                       `|`, when given, is what a run with a `--fix` on
//!                       must show instead (as `result`)
//!     where ID          print where portable ID is: on a scene (its scene
//!                       names, position, visible, moving), carried, used
//!     offer SLOT X Y    open the panel, drag inventory slot SLOT (0-7) to
//!                       X Y and release it there (takes 2 s)
//!     focus 0|1         the window loses or regains focus (WM_ACTIVATE)
//!     freeze MS         a time jump: the clock runs on MS while the game
//!                       dispatches nothing (the web page hidden, its frame
//!                       loop stopped), then everything due fires at once;
//!                       later relative times count from the end of it
//!     result won|lost|none [SCORE] [| won|lost|none [SCORE]]
//!                       fail the run unless the last minigame result
//!                       (0x40a, from a real minigame: `host.zig`) is a
//!                       win / a loss (with that score delta), or none came;
//!                       the part after `|`, when given, is what a run with
//!                       a `--fix` on must get instead (a bug that changes
//!                       the result, as SERIAL's BUGS.md K1/K2)
//!     close             close the active window, as the user (the web page's
//!                       tab closed, Windows' End Task): WM_CLOSE to it
//!     quit              end the run
//!     delay MS          every later time moves by MS (as a `wait` that
//!                       waited MS); for a `?FLAG` line, below
//!     keymap K1 K2      later `key` and `hold` lines naming K1 press K2
//!
//! A command may start with a condition: `?FLAG` runs the line only when
//! the fix FLAG (a `src/core/fixes.zig` field) is on, `!FLAG` only when it
//! is off. A line that does not run is dropped whole, its time too: a
//! later `+` time counts from the line before it. E.g. the fights'
//! Corrigida controls screen and keys (`fight_controls_screen`,
//! `fight_keys_asdf`):
//!
//!     50 ?fight_controls_screen key return
//!     50 ?fight_controls_screen delay 50
//!     0 ?fight_keys_asdf keymap up s
//!
//! A minigame run alone (`--minigame encaixe`) takes the input, `dump`,
//! `log`, `focus`, `freeze`, `result`, `close` and `quit` commands; the
//! others need NOITE. Once it has quit, its remaining `result` and `log`
//! lines still run.
//!
//! Mouse commands keep track of the buttons held, as `wParam` (MK_*).

const std = @import("std");
const msg = @import("../core/msg.zig");
const wm = msg.wm;
const Fixes = @import("../core/fixes.zig").Fixes;

pub const Action = union(enum) {
    input: msg.Msg,
    dump: []const u8,
    scene: SceneJump,
    log: []const u8,
    state,
    report: []const u8,
    expect: SceneExpect,
    wait: Wait,
    take: i16,
    drawn: Drawn,
    pixel: Pixel,
    where: i16,
    focus: bool,
    freeze: u32,
    result: ResultCheck,
    close,
    quit,
};

/// `result won|lost|none [SCORE] [| won|lost|none [SCORE]]`.
pub const ResultCheck = struct {
    want: Want,
    score: ?i32 = null,
    /// The expectation of a run with fixes (after `|`), if it differs.
    fixed: ?Expect = null,

    pub const Want = enum { won, lost, none };
    pub const Expect = struct { want: Want, score: ?i32 = null };
};

pub const Wait = struct { name: []const u8, max_ms: u32 };

/// `expect NAME [| NAME]`: the scene, and the one a run with fixes is in
/// instead, if it differs.
pub const SceneExpect = struct { name: []const u8, fixed: ?[]const u8 = null };

/// `drawn ID 0|1`: whether portable ID must be on the screen.
pub const Drawn = struct { id: i16, on: bool };

/// `pixel X Y INDEX [| INDEX]`: the palette index the screen must show
/// there, and the one a run with fixes must show instead, if it differs.
pub const Pixel = struct { x: u16, y: u16, index: u8, fixed: ?u8 = null };

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
/// `fixes`: the run's, for the `?FLAG` / `!FLAG` conditions.
pub fn parse(gpa: std.mem.Allocator, text: []u8, fixes: Fixes) ParseError!Script {
    var s: Script = .{ .text = text };
    errdefer s.steps.deinit(gpa);
    var t: u32 = 0;
    // `delay`: added to every later step's time.
    var shift: u32 = 0;
    var keymap: std.ArrayList([2]u16) = .empty;
    defer keymap.deinit(gpa);
    var buttons: u16 = 0;
    var line_no: usize = 0;
    var lines = std.mem.splitScalar(u8, text, '\n');
    while (lines.next()) |raw| {
        line_no += 1;
        const line = std.mem.trim(u8, raw[0 .. std.mem.indexOfScalar(u8, raw, '#') orelse raw.len], " \t\r");
        if (line.len == 0) continue;
        var words = std.mem.tokenizeAny(u8, line, " \t");
        const time_word = words.next().?;
        var cmd = words.next() orelse return bad(line_no, "missing command");
        if (cmd[0] == '?' or cmd[0] == '!') {
            const on = flagOn(fixes, cmd[1..]) orelse return bad(line_no, "unknown fix in the condition");
            if (on != (cmd[0] == '?')) continue;
            cmd = words.next() orelse return bad(line_no, "missing command");
        }
        const start = s.steps.items.len;
        defer for (s.steps.items[start..]) |*st| {
            st.at += shift;
        };
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
            const v = mapped(keymap.items, keyCode(k) orelse return bad(line_no, "unknown key"));
            try s.steps.append(gpa, .{ .at = t, .action = .{ .input = .{ .id = wm.keydown, .wparam = v } } });
            try s.steps.append(gpa, .{ .at = t + 50, .action = .{ .input = .{ .id = wm.keyup, .wparam = v } } });
        } else if (eq(u8, cmd, "hold")) {
            const k = words.next() orelse return bad(line_no, "missing key");
            const v = mapped(keymap.items, keyCode(k) orelse return bad(line_no, "unknown key"));
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
        } else if (eq(u8, cmd, "take")) {
            try s.steps.append(gpa, .{ .at = t, .action = .{ .take = try num(i16, words.next(), line_no) } });
        } else if (eq(u8, cmd, "drawn")) {
            const id = try num(i16, words.next(), line_no);
            const on = try num(u16, words.next(), line_no) != 0;
            try s.steps.append(gpa, .{ .at = t, .action = .{ .drawn = .{ .id = id, .on = on } } });
        } else if (eq(u8, cmd, "pixel")) {
            const x = try num(u16, words.next(), line_no);
            const y = try num(u16, words.next(), line_no);
            const index = try num(u8, words.next(), line_no);
            var fixed: ?u8 = null;
            if (words.next()) |sep| {
                if (!eq(u8, sep, "|")) return bad(line_no, "want `|` before the fixed index");
                fixed = try num(u8, words.next(), line_no);
            }
            try s.steps.append(gpa, .{ .at = t, .action = .{ .pixel = .{ .x = x, .y = y, .index = index, .fixed = fixed } } });
        } else if (eq(u8, cmd, "where")) {
            try s.steps.append(gpa, .{ .at = t, .action = .{ .where = try num(i16, words.next(), line_no) } });
        } else if (eq(u8, cmd, "offer")) {
            const slot = try num(u16, words.next(), line_no);
            const x = try num(u16, words.next(), line_no);
            const y = try num(u16, words.next(), line_no);
            const sx: u16 = 110 + 56 * slot;
            try s.steps.append(gpa, .{ .at = t, .action = .{ .input = msg.Msg.make(wm.mousemove, 0, 320, 465) } });
            try s.steps.append(gpa, .{ .at = t + 1500, .action = .{ .input = msg.Msg.make(wm.mousemove, 0, sx, 430) } });
            try s.steps.append(gpa, .{ .at = t + 1500, .action = .{ .input = msg.Msg.make(wm.rbuttondown, msg.mk.rbutton, sx, 430) } });
            try s.steps.append(gpa, .{ .at = t + 1600, .action = .{ .input = msg.Msg.make(wm.mousemove, msg.mk.rbutton, x, 300) } });
            try s.steps.append(gpa, .{ .at = t + 1700, .action = .{ .input = msg.Msg.make(wm.mousemove, msg.mk.rbutton, x, y) } });
            try s.steps.append(gpa, .{ .at = t + 2000, .action = .{ .input = msg.Msg.make(wm.rbuttonup, 0, x, y) } });
        } else if (eq(u8, cmd, "wait")) {
            const name = words.next() orelse return bad(line_no, "missing scene");
            const max: u32 = if (words.peek() != null) try num(u32, words.next(), line_no) else 120_000;
            try s.steps.append(gpa, .{ .at = t, .action = .{ .wait = .{ .name = name, .max_ms = max } } });
        } else if (eq(u8, cmd, "expect")) {
            var e: SceneExpect = .{ .name = words.next() orelse return bad(line_no, "missing scene") };
            if (words.next()) |sep| {
                if (!eq(u8, sep, "|")) return bad(line_no, "want `|` before the fixed scene");
                e.fixed = words.next() orelse return bad(line_no, "missing fixed scene");
                if (words.peek() != null) return bad(line_no, "extra words after the fixed scene");
            }
            try s.steps.append(gpa, .{ .at = t, .action = .{ .expect = e } });
        } else if (eq(u8, cmd, "report")) {
            try s.steps.append(gpa, .{ .at = t, .action = .{ .report = words.next() orelse return bad(line_no, "missing file") } });
        } else if (eq(u8, cmd, "state")) {
            try s.steps.append(gpa, .{ .at = t, .action = .state });
        } else if (eq(u8, cmd, "focus")) {
            try s.steps.append(gpa, .{ .at = t, .action = .{ .focus = try num(u16, words.next(), line_no) != 0 } });
        } else if (eq(u8, cmd, "freeze")) {
            const ms = try num(u32, words.next(), line_no);
            try s.steps.append(gpa, .{ .at = t, .action = .{ .freeze = ms } });
            t += ms;
        } else if (eq(u8, cmd, "result")) {
            const first = try resultExpect(&words, line_no);
            var r: ResultCheck = .{ .want = first.want, .score = first.score };
            if (words.next()) |sep| {
                if (!eq(u8, sep, "|")) return bad(line_no, "want `|` before the fixed result");
                r.fixed = try resultExpect(&words, line_no);
                if (words.peek() != null) return bad(line_no, "extra words after the fixed result");
            }
            try s.steps.append(gpa, .{ .at = t, .action = .{ .result = r } });
        } else if (eq(u8, cmd, "close")) {
            try s.steps.append(gpa, .{ .at = t, .action = .close });
        } else if (eq(u8, cmd, "quit")) {
            try s.steps.append(gpa, .{ .at = t, .action = .quit });
        } else if (eq(u8, cmd, "delay")) {
            shift += try num(u32, words.next(), line_no);
        } else if (eq(u8, cmd, "keymap")) {
            const from = keyCode(words.next() orelse return bad(line_no, "missing key")) orelse return bad(line_no, "unknown key");
            const to = keyCode(words.next() orelse return bad(line_no, "missing key")) orelse return bad(line_no, "unknown key");
            try keymap.append(gpa, .{ from, to });
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

/// Whether the fix `name` is on; null when there is no such fix.
fn flagOn(fixes: Fixes, name: []const u8) ?bool {
    @setEvalBranchQuota(10_000);
    inline for (@typeInfo(Fixes).@"struct".field_names) |field| {
        if (std.mem.eql(u8, name, field)) return @field(fixes, field);
    }
    return null;
}

/// A key after the `keymap` lines so far.
fn mapped(map: []const [2]u16, v: u16) u16 {
    for (map) |e| if (e[0] == v) return e[1];
    return v;
}

fn bad(line: usize, what: []const u8) ParseError {
    std.debug.print("input script line {d}: {s}\n", .{ line, what });
    return error.BadScript;
}

/// `won|lost|none [SCORE]` of a `result` line.
fn resultExpect(words: anytype, line_no: usize) ParseError!ResultCheck.Expect {
    const eq = std.mem.eql;
    const w = words.next() orelse return bad(line_no, "missing won|lost|none");
    var e: ResultCheck.Expect = .{ .want = if (eq(u8, w, "won")) .won else if (eq(u8, w, "lost")) .lost else if (eq(u8, w, "none")) .none else return bad(line_no, "want won, lost or none") };
    if (words.peek()) |next| {
        if (!eq(u8, next, "|")) e.score = try num(i32, words.next(), line_no);
    }
    return e;
}

fn num(comptime T: type, word: ?[]const u8, line: usize) ParseError!T {
    const w = word orelse return bad(line, "missing number");
    return std.fmt.parseInt(T, w, 0) catch bad(line, "bad number");
}

fn keyCode(k: []const u8) ?u16 {
    if (std.fmt.parseInt(u16, k, 0)) |v| return v else |_| {}
    // The arrows, Enter, Esc, Space, the fights' PgUp, Home, End and
    // Insert (SALGIN, XILINDRO) and their Corrigida keys A, S, D, F, and
    // JARDIM's Ctrl, Shift and Caps Lock.
    const names = [_]struct { []const u8, u16 }{
        .{ "left", 0x25 },   .{ "up", 0x26 },       .{ "right", 0x27 },  .{ "down", 0x28 },
        .{ "return", 0x0d }, .{ "escape", 0x1b },   .{ "space", 0x20 },  .{ "pgup", 0x21 },
        .{ "home", 0x24 },   .{ "end", 0x23 },      .{ "insert", 0x2d }, .{ "ctrl", 0x11 },
        .{ "shift", 0x10 },  .{ "capslock", 0x14 }, .{ "a", 0x41 },      .{ "s", 0x53 },
        .{ "d", 0x44 },      .{ "f", 0x46 },
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
    var s = try parse(gpa, text, .{});
    defer s.deinit(gpa);
    try std.testing.expectEqual(@as(usize, 7), s.steps.items.len);
    try std.testing.expectEqual(wm.lbuttondown, s.steps.items[1].action.input.id);
    try std.testing.expectEqual(@as(u32, 120), s.steps.items[2].at); // keydown
    try std.testing.expectEqual(@as(u32, 150), s.steps.items[3].at); // lbuttonup
    try std.testing.expectEqual(@as(i16, 200), s.steps.items[6].action.scene.flags.?.y);
}

test "a result line can carry the fixed run's expectation" {
    const gpa = std.testing.allocator;
    const text = try gpa.dupe(u8,
        \\100 result won 32768004 | won 500
        \\200 result lost | none
        \\300 result won
    );
    var s = try parse(gpa, text, .{});
    defer s.deinit(gpa);
    const a = s.steps.items[0].action.result;
    try std.testing.expectEqual(@as(?i32, 32768004), a.score);
    try std.testing.expectEqual(ResultCheck.Want.won, a.fixed.?.want);
    try std.testing.expectEqual(@as(?i32, 500), a.fixed.?.score);
    const b = s.steps.items[1].action.result;
    try std.testing.expectEqual(ResultCheck.Want.lost, b.want);
    try std.testing.expectEqual(ResultCheck.Want.none, b.fixed.?.want);
    try std.testing.expectEqual(@as(?ResultCheck.Expect, null), s.steps.items[2].action.result.fixed);
}

test "an expect line can name the fixed run's scene" {
    const gpa = std.testing.allocator;
    const text = try gpa.dupe(u8,
        \\100 expect 3fprisao | 3fhall
        \\200 expect 3fhall
    );
    var s = try parse(gpa, text, .{});
    defer s.deinit(gpa);
    const a = s.steps.items[0].action.expect;
    try std.testing.expectEqualStrings("3fprisao", a.name);
    try std.testing.expectEqualStrings("3fhall", a.fixed.?);
    try std.testing.expectEqual(@as(?[]const u8, null), s.steps.items[1].action.expect.fixed);
}

test "conditional lines, delay and keymap" {
    const gpa = std.testing.allocator;
    const src =
        \\100 key up
        \\150 ?fight_controls_screen key return
        \\150 ?fight_controls_screen delay 50
        \\0 !fight_keys_asdf keymap up up
        \\0 ?fight_keys_asdf keymap up s
        \\200 key up
        \\+10 !fight_keys_asdf log off
    ;
    var off = try parse(gpa, try gpa.dupe(u8, src), .{});
    defer off.deinit(gpa);
    try std.testing.expectEqual(@as(usize, 5), off.steps.items.len);
    try std.testing.expectEqual(@as(u16, 0x26), off.steps.items[2].action.input.wparam);
    try std.testing.expectEqual(@as(u32, 200), off.steps.items[2].at);
    try std.testing.expectEqual(@as(u32, 210), off.steps.items[3].at);
    var on = try parse(gpa, try gpa.dupe(u8, src), Fixes.all());
    defer on.deinit(gpa);
    try std.testing.expectEqual(@as(usize, 6), on.steps.items.len);
    try std.testing.expectEqual(@as(u16, 0x0d), on.steps.items[2].action.input.wparam);
    try std.testing.expectEqual(@as(u32, 150), on.steps.items[2].at);
    try std.testing.expectEqual(@as(u16, 0x53), on.steps.items[4].action.input.wparam);
    try std.testing.expectEqual(@as(u32, 250), on.steps.items[4].at);
}
