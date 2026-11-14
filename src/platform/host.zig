//! Several Win16 programs in one process: NOITE and the minigame EXEs it
//! starts with WinExec, or one minigame alone (docs/encaixe/DESIGN.md,
//! "Running two programs"). Platform code, not a port unit.
//!
//! The host sits between the programs and the backend (`machine`): every
//! program (a *task*) gets its own `Platform` (`Task.platform`), its own
//! message queue and timers (inside the program's state), its own window
//! (handle, title, shown or hidden, its own `Screen`) and an inbox of the
//! events meant for it. The backend's events are routed: input, focus and
//! the window's close button go to the active window's task; the media
//! notifications to the task whose call scheduled them (`Sim.task`). What a
//! task posts to another task's window lands in that task's inbox.
//!
//! Task 0 is the program `main` started and drives itself (NOITE's loop in
//! `main.zig` / `web_main.zig`, or `run` for a minigame alone). The others
//! run inside task 0's `poll`: every poll of task 0 first gives the other
//! tasks their turn (`pump`), the way a Win16 task's GetMessage yields to
//! the others. Alone, task 0's platform is the backend's, call for call:
//! NOITE runs exactly as without a host.
//!
//! Window rules (Windows 3.1, simplified; unverified details noted):
//! - WinExec of a registered program (`Options.real`) creates the task;
//!   its WinMain runs `startup_ms` later (the EXE loading), which creates
//!   its window and shows it: from then on FindWindow finds it, it is the
//!   active window, and the previously active task gets WM_ACTIVATE(0). The
//!   new program activates itself, as NOITE's `app.start` does.
//! - ShowWindow(SW_SHOW) of a hidden window makes it the top, active
//!   window (WM_ACTIVATE(1) to it, (0) to the previous one); SW_HIDE of the
//!   active window activates the top visible one left.
//! - The backend shows the top visible window's screen; with every window
//!   hidden it hides its own (the web page's "Minijogo" notice).
//! - A task whose message loop ended (WM_QUIT) is destroyed: app_exit runs,
//!   its window goes (FindWindow fails, PostMessage to it fails) and the
//!   next visible window is activated.
//! - Activation and cross-task messages are delivered through the inbox
//!   (asynchronously, at the target's next poll), not by a nested
//!   SendMessage as in Windows.
//! Programs not registered (the 8 unported minigames, or every one with
//! `--minigame-stub`) stay the backend's stub (`Sim.winExec`).

const std = @import("std");
const p = @import("platform.zig");
const msg = @import("../core/msg.zig");
const Sim = @import("sim.zig").Sim;
const Fixes = @import("../core/fixes.zig").Fixes;

const Hwnd = p.Hwnd;
const Msg = p.Msg;
const Event = p.Event;
const TaskId = p.TaskId;

/// A program the host can run as a task (one per minigame EXE ported).
/// `ctx` is the program's own state (its `Game`), made by `start`.
pub const Program = struct {
    /// CLI and WinExec name: the EXE's base name, lower case ("encaixe").
    name: []const u8,
    /// The window class and title FindWindow looks for ("Encaixe Perfeito").
    title: []const u8,
    /// The EXE's directory on the disc (`\ENCAIXE`): relative file names
    /// are looked for there too (`Sim.task_dirs`).
    dir: []const u8,
    /// False until every unit of the program is ported: WinExec keeps the
    /// stub and `--minigame NAME` refuses to run it.
    ready: bool,
    /// WinMain up to the message loop, on the task's platform.
    start: *const fn (gpa: std.mem.Allocator, plat: p.Platform, fixes: Fixes) anyerror!*anyopaque,
    /// A backend event, as Windows hands it to the program (input queued,
    /// WM_ACTIVATE / WM_CLOSE sent, a message posted).
    deliver: *const fn (ctx: *anyopaque, ev: Event) void,
    /// Dispatches one due message; false when its queue is empty.
    step: *const fn (ctx: *anyopaque) bool,
    /// When its next timer is due (null: none).
    nextDue: *const fn (ctx: *anyopaque) ?u32,
    /// Its message loop got WM_QUIT.
    quit: *const fn (ctx: *anyopaque) bool,
    /// app_exit, then frees the state (Windows ending the task).
    exit: *const fn (ctx: *anyopaque) void,
};

pub const Options = struct {
    /// The programs WinExec starts for real (the others are the stub).
    real: []const *const Program = &.{},
    /// The EXE load time before a started program's WinMain runs.
    startup_ms: u32 = 1500,
    fixes: Fixes = .{},
};

/// A minigame's result as it posted it (0x40a): to NOITE, or with no
/// NOITE window (a minigame alone), to nobody.
pub const Result = struct { task: TaskId, won: bool, score: i32, at: u32 };

const Inbox = struct {
    const cap = 64;
    items: [cap]Event = undefined,
    head: usize = 0,
    len: usize = 0,

    fn push(b: *Inbox, ev: Event) bool {
        if (b.len == cap) return false;
        b.items[(b.head + b.len) % cap] = ev;
        b.len += 1;
        return true;
    }
    fn pop(b: *Inbox) ?Event {
        if (b.len == 0) return null;
        const ev = b.items[b.head];
        b.head = (b.head + 1) % cap;
        b.len -= 1;
        return ev;
    }
};

pub const Task = struct {
    host: *Host,
    id: TaskId,
    state: State = .free,
    /// Null for task 0 (main drives it).
    program: ?*const Program = null,
    ctx: ?*anyopaque = null,
    /// When a starting task's WinMain runs.
    start_at: u32 = 0,
    hwnd: Hwnd = 0,
    title: []const u8 = "",
    visible: bool = false,
    /// Stacking order: the visible window with the highest is on top.
    z: u32 = 0,
    /// Task 0: the backend's screen; others: their own.
    screen: *p.Screen = undefined,
    own_screen: ?*p.Screen = null,
    inbox: Inbox = .{},
    /// The host took the focus from it (WM_ACTIVATE(0) for another task's
    /// window): its next activation gives it WM_ACTIVATE(1) back.
    host_deactivated: bool = false,

    pub const State = enum { free, starting, running };

    pub fn platform(t: *Task) p.Platform {
        return .{ .ptr = t, .vtable = &task_vtable };
    }

    fn alive(t: *const Task) bool {
        return t.state == .running;
    }
};

pub const Host = struct {
    gpa: std.mem.Allocator,
    machine: p.Platform,
    sim: *Sim,
    opts: Options,
    tasks: [p.max_tasks]Task = undefined,
    /// The task whose window is active (gets the input), or null.
    active: ?TaskId = 0,
    z_next: u32 = 1,
    /// Results the minigames posted (the harness's `result` check).
    results: std.ArrayList(Result) = .empty,
    /// Not reentrant: a task's turn never runs the others again.
    pumping: bool = false,
    /// Task 0's program when it is a minigame run alone (null: NOITE).
    primary_program: ?*const Program = null,

    /// `machine` is the backend's platform, `sim` its `Sim`. Task 0 is
    /// the program `main` runs: `title` is its window's.
    pub fn init(h: *Host, gpa: std.mem.Allocator, machine: p.Platform, sim: *Sim, opts: Options, title: []const u8, primary_program: ?*const Program) void {
        h.* = .{ .gpa = gpa, .machine = machine, .sim = sim, .opts = opts, .primary_program = primary_program };
        if (primary_program) |prog| sim.task_dirs[0] = prog.dir;
        for (&h.tasks, 0..) |*t, i| t.* = .{ .host = h, .id = @intCast(i) };
        const t0 = &h.tasks[0];
        t0.* = .{ .host = h, .id = 0, .state = .running, .hwnd = msg.main_window, .title = title, .visible = true, .z = 0 };
        t0.screen = machine.screen();
    }

    pub fn deinit(h: *Host) void {
        for (h.tasks[1..]) |*t| h.endTask(t);
        h.results.deinit(h.gpa);
    }

    /// Task 0's platform: what `main` gives its program.
    pub fn primary(h: *Host) p.Platform {
        return h.tasks[0].platform();
    }

    /// True while no other task exists: task 0 then is the backend.
    pub fn alone(h: *const Host) bool {
        for (h.tasks[1..]) |t| if (t.state != .free) return false;
        return true;
    }

    /// The program registered as real under the EXE base name `name`.
    pub fn find(h: *const Host, name: []const u8) ?*const Program {
        for (h.opts.real) |prog| if (std.ascii.eqlIgnoreCase(prog.name, name)) return prog;
        return null;
    }

    /// The top visible window's task (null: every window hidden).
    pub fn top(h: *Host) ?*Task {
        var best: ?*Task = null;
        for (&h.tasks) |*t| {
            if (!t.alive() or !t.visible) continue;
            if (best == null or t.z > best.?.z) best = t;
        }
        return best;
    }

    /// The screen the backend shows now (the harness's dumps).
    pub fn shownScreen(h: *Host) *const p.Screen {
        if (h.top()) |t| return t.screen;
        return h.tasks[0].screen;
    }

    /// Input for whoever has the focus (the harness's scripted input):
    /// the active task's inbox.
    pub fn input(h: *Host, m: Msg) void {
        const t = h.activeTask() orelse return;
        _ = t.inbox.push(.{ .input = m });
    }

    /// The harness's `focus 0|1`: the active window loses or regains the
    /// focus (WM_ACTIVATE).
    pub fn focus(h: *Host, on: bool) void {
        const t = h.activeTask() orelse &h.tasks[0];
        _ = t.inbox.push(.{ .activate = on });
    }

    fn activeTask(h: *Host) ?*Task {
        const id = h.active orelse return null;
        const t = &h.tasks[id];
        return if (t.alive()) t else null;
    }

    fn taskOfWindow(h: *Host, hwnd: Hwnd) ?*Task {
        if (hwnd == 0) return null;
        for (&h.tasks) |*t| if (t.alive() and t.hwnd == hwnd) return t;
        return null;
    }

    /// Makes `t` the active window; the old one gets WM_ACTIVATE(0) and,
    /// unless `t` activates itself (its start), `t` gets WM_ACTIVATE(1).
    fn activate(h: *Host, t: ?*Task, notify_new: bool) void {
        const old = h.activeTask();
        if (old == t) return;
        if (old) |o| {
            _ = o.inbox.push(.{ .activate = false });
            o.host_deactivated = true;
        }
        h.active = if (t) |n| n.id else null;
        if (t) |n| if (notify_new or n.host_deactivated) {
            _ = n.inbox.push(.{ .activate = true });
            n.host_deactivated = false;
        };
    }

    /// Pulls the backend's events due now and routes them.
    fn route(h: *Host) void {
        while (h.machine.poll()) |ev| {
            const target: ?*Task = switch (ev) {
                // A media notification is for the task that scheduled it.
                .message => blk: {
                    const t = &h.tasks[h.sim.polled_task];
                    break :blk if (t.alive()) t else null;
                },
                // The window's close button, focus and input: the active window.
                .quit, .activate, .input => h.activeTask() orelse &h.tasks[0],
            };
            if (target) |t| if (!t.inbox.push(ev)) std.log.warn("task {d}: inbox full, event lost", .{t.id});
        }
    }

    /// The other tasks' turn: starts the ones whose load time is over,
    /// delivers their inboxes, dispatches what is due, presents, and ends
    /// the ones that quit. Called from task 0's `poll`.
    pub fn pump(h: *Host) void {
        if (h.pumping) return;
        h.pumping = true;
        defer h.pumping = false;
        const now = h.machine.ticks();
        for (h.tasks[1..]) |*t| switch (t.state) {
            .free => {},
            .starting => if (@as(i32, @bitCast(now -% t.start_at)) >= 0) h.startTask(t),
            .running => {},
        };
        for (h.tasks[1..]) |*t| {
            if (t.state != .running) continue;
            const prog = t.program.?;
            const ctx = t.ctx.?;
            var budget: u32 = 50_000;
            while (budget > 0) : (budget -= 1) {
                while (t.inbox.pop()) |ev| h.withTask(t, prog.deliver, .{ ctx, ev });
                if (prog.quit(ctx)) break;
                if (!h.withTaskRet(t, bool, prog.step, .{ctx})) break;
            }
            if (budget == 0) std.log.warn("task {d}: message storm", .{t.id});
            if (prog.quit(ctx)) {
                h.endTask(t);
                continue;
            }
            if (h.top() == t) h.machine.presentScreen(t.screen);
        }
    }

    fn withTask(h: *Host, t: *Task, f: anytype, args: anytype) void {
        const saved = h.sim.task;
        h.sim.task = t.id;
        defer h.sim.task = saved;
        @call(.auto, f, args);
    }

    fn withTaskRet(h: *Host, t: *Task, comptime R: type, f: anytype, args: anytype) R {
        const saved = h.sim.task;
        h.sim.task = t.id;
        defer h.sim.task = saved;
        return @call(.auto, f, args);
    }

    /// The earliest moment another task needs a turn (null: none).
    pub fn nextDue(h: *Host) ?u32 {
        const now = h.machine.ticks();
        var best: ?u32 = null;
        for (h.tasks[1..]) |*t| {
            const due: ?u32 = switch (t.state) {
                .free => null,
                .starting => t.start_at,
                .running => if (t.inbox.len > 0) now else t.program.?.nextDue(t.ctx.?),
            };
            if (due) |d| best = if (best) |b| (if (@as(i32, @bitCast(d -% b)) < 0) d else b) else d;
        }
        return best;
    }

    fn startTask(h: *Host, t: *Task) void {
        const prog = t.program.?;
        t.state = .running;
        t.visible = true;
        t.z = h.z_next;
        h.z_next += 1;
        h.sim.task_dirs[t.id] = prog.dir;
        h.activate(t, false);
        h.machine.showMain(true);
        const ctx = h.withTaskRet(t, anyerror!*anyopaque, prog.start, .{ h.gpa, t.platform(), h.opts.fixes }) catch |e| {
            std.log.err("{s}: start failed: {t}", .{ prog.name, e });
            t.state = .free;
            h.afterWindowGone(t);
            return;
        };
        t.ctx = ctx;
    }

    fn endTask(h: *Host, t: *Task) void {
        if (t.state == .free) return;
        if (t.state == .running) if (t.ctx) |ctx| h.withTask(t, t.program.?.exit, .{ctx});
        t.state = .free;
        t.ctx = null;
        h.sim.task_dirs[t.id] = null;
        h.afterWindowGone(t);
        if (t.own_screen) |s| h.gpa.destroy(s);
        t.own_screen = null;
        t.inbox = .{};
    }

    /// `t`'s window was hidden or destroyed: the top visible one left is
    /// active, and the backend shows it (or hides itself).
    fn afterWindowGone(h: *Host, t: *Task) void {
        if (h.active == t.id) {
            h.active = null;
            h.activate(h.top(), true);
        }
        h.syncMachine();
    }

    fn syncMachine(h: *Host) void {
        if (h.alone()) return;
        const shown = h.top();
        h.machine.showMain(shown != null);
        if (shown) |s| if (s.id != 0) h.machine.presentScreen(s.screen) else h.machine.present();
    }

    // ---- what a task's platform does differently ----------------------------

    fn winExec(h: *Host, caller: *Task, command: []const u8) u16 {
        const base = exeBase(command);
        const prog = h.find(base) orelse return h.forward(caller, u16, "winExec", .{command});
        if (!prog.ready) return h.forward(caller, u16, "winExec", .{command});
        for (h.tasks[1..]) |*t| if (t.state == .free) {
            const scr = h.gpa.create(p.Screen) catch return 0;
            scr.* = .{};
            t.* = .{
                .host = h,
                .id = t.id,
                .state = .starting,
                .program = prog,
                .start_at = h.machine.ticks() +% h.opts.startup_ms,
                .hwnd = 0x100 + @as(Hwnd, t.id),
                .title = prog.title,
                .screen = scr,
                .own_screen = scr,
            };
            return 33;
        };
        return 0; // out of memory: no task slot left
    }

    fn findWindow(h: *Host, caller: *Task, title: []const u8) ?Hwnd {
        for (&h.tasks) |*t| if (t.alive() and std.mem.eql(u8, t.title, title)) return t.hwnd;
        return h.forward(caller, ?Hwnd, "findWindow", .{title});
    }

    fn postTo(h: *Host, caller: *Task, hwnd: Hwnd, m: Msg) bool {
        const minigame = caller.program != null or (caller.id == 0 and h.primary_program != null);
        if (minigame and m.id == msg.noite.minigame_result) {
            h.results.append(h.gpa, .{ .task = caller.id, .won = m.wparam != 0, .score = m.lparam, .at = h.machine.ticks() }) catch {};
        }
        if (h.taskOfWindow(hwnd)) |t| return t.inbox.push(.{ .message = m });
        // No such window (a minigame alone posts to a NOITE that is not
        // there): PostMessage fails.
        if (hwnd == 0 or minigame) return false;
        return h.forward(caller, bool, "postTo", .{ hwnd, m });
    }

    /// Alone, task 0 hiding and showing itself (a stub minigame) only
    /// changes the backend's window, as without a host; after a real task
    /// took its focus, showing it gives it back (WM_ACTIVATE(1)).
    fn showMain(h: *Host, t: *Task, show: bool) void {
        const was_alone = h.alone();
        if (show != t.visible) {
            t.visible = show;
            if (show) {
                t.z = h.z_next;
                h.z_next += 1;
                h.activate(t, !was_alone);
            } else if (was_alone) {
                if (h.active == t.id) h.active = null;
            } else h.afterWindowGone(t);
        }
        if (was_alone) h.machine.showMain(show) else h.syncMachine();
    }

    fn present(h: *Host, t: *Task) void {
        if (h.alone()) return h.machine.present();
        if (h.top() != t) return;
        if (t.id == 0) h.machine.present() else h.machine.presentScreen(t.screen);
    }

    fn poll(h: *Host, t: *Task) ?Event {
        if (t.id == 0) {
            if (h.alone()) return t.inbox.pop() orelse h.machine.poll();
            h.route();
            h.pump();
        }
        return t.inbox.pop();
    }

    fn wait(h: *Host, deadline: ?u32) void {
        var d = deadline;
        if (h.nextDue()) |o| d = if (d) |x| (if (@as(i32, @bitCast(o -% x)) < 0) o else x) else o;
        h.machine.wait(d);
    }

    /// Calls the backend for `caller` (its `Sim.task`).
    fn forward(h: *Host, caller: *Task, comptime R: type, comptime name: []const u8, args: anytype) R {
        const saved = h.sim.task;
        h.sim.task = caller.id;
        defer h.sim.task = saved;
        return @call(.auto, @field(p.Platform, name), .{h.machine} ++ args);
    }
};

/// The EXE base name of a WinExec command line (`d:\encaixe\encaixe.exe x`
/// → `encaixe`).
pub fn exeBase(command: []const u8) []const u8 {
    const cmd = std.mem.trim(u8, command, " ");
    const exe_path = cmd[0 .. std.mem.indexOfScalar(u8, cmd, ' ') orelse cmd.len];
    var base = exe_path[(std.mem.lastIndexOfAny(u8, exe_path, "\\/:") orelse 0)..];
    base = std.mem.trimStart(u8, base, "\\/:");
    if (std.mem.lastIndexOfScalar(u8, base, '.')) |dot| base = base[0..dot];
    return base;
}

// ---- the task's platform ------------------------------------------------------

fn taskOf(ptr: *anyopaque) *Task {
    return @ptrCast(@alignCast(ptr));
}

fn hostOf(ptr: *anyopaque) *Host {
    return taskOf(ptr).host;
}

/// A plain forward to the backend, as the calling task.
fn Fwd(comptime name: []const u8) type {
    const F = @typeInfo(@FieldType(p.Platform.VTable, name)).pointer.child;
    const info = @typeInfo(F).@"fn";
    const R = info.return_type.?;
    const P = info.param_types;
    return struct {
        fn f0(ptr: *anyopaque) R {
            const t = taskOf(ptr);
            return t.host.forward(t, R, name, .{});
        }
        fn f1(ptr: *anyopaque, a: P[1].?) R {
            const t = taskOf(ptr);
            return t.host.forward(t, R, name, .{a});
        }
        fn f2(ptr: *anyopaque, a: P[1].?, b: P[2].?) R {
            const t = taskOf(ptr);
            return t.host.forward(t, R, name, .{ a, b });
        }
        fn f3(ptr: *anyopaque, a: P[1].?, b: P[2].?, c: P[3].?) R {
            const t = taskOf(ptr);
            return t.host.forward(t, R, name, .{ a, b, c });
        }
        fn f4(ptr: *anyopaque, a: P[1].?, b: P[2].?, c: P[3].?, d: P[4].?) R {
            const t = taskOf(ptr);
            return t.host.forward(t, R, name, .{ a, b, c, d });
        }
        fn f5(ptr: *anyopaque, a: P[1].?, b: P[2].?, c: P[3].?, d: P[4].?, e: P[5].?) R {
            const t = taskOf(ptr);
            return t.host.forward(t, R, name, .{ a, b, c, d, e });
        }
        fn f6(ptr: *anyopaque, a: P[1].?, b: P[2].?, c: P[3].?, d: P[4].?, e: P[5].?, g: P[6].?) R {
            const t = taskOf(ptr);
            return t.host.forward(t, R, name, .{ a, b, c, d, e, g });
        }
        const func = switch (P.len) {
            1 => f0,
            2 => f1,
            3 => f2,
            4 => f3,
            5 => f4,
            6 => f5,
            7 => f6,
            else => @compileError("no forwarder for " ++ name),
        };
    };
}

fn fwd(comptime name: []const u8) @FieldType(p.Platform.VTable, name) {
    return &Fwd(name).func;
}

fn tScreen(ptr: *anyopaque) *p.Screen {
    return taskOf(ptr).screen;
}
fn tPresent(ptr: *anyopaque) void {
    const t = taskOf(ptr);
    t.host.present(t);
}
fn tPresentScreen(ptr: *anyopaque, scr: ?*const p.Screen) void {
    hostOf(ptr).machine.presentScreen(scr);
}
fn tPoll(ptr: *anyopaque) ?Event {
    const t = taskOf(ptr);
    return t.host.poll(t);
}
fn tWait(ptr: *anyopaque, deadline: ?u32) void {
    hostOf(ptr).wait(deadline);
}
fn tWinExec(ptr: *anyopaque, command: []const u8) u16 {
    const t = taskOf(ptr);
    return t.host.winExec(t, command);
}
fn tFindWindow(ptr: *anyopaque, title: []const u8) ?Hwnd {
    const t = taskOf(ptr);
    return t.host.findWindow(t, title);
}
fn tPostTo(ptr: *anyopaque, hwnd: Hwnd, m: Msg) bool {
    const t = taskOf(ptr);
    return t.host.postTo(t, hwnd, m);
}
fn tShowMain(ptr: *anyopaque, show: bool) void {
    const t = taskOf(ptr);
    t.host.showMain(t, show);
}
fn tWindowHandle(ptr: *anyopaque) Hwnd {
    return taskOf(ptr).hwnd;
}
fn tAviPlay(ptr: *anyopaque, dev: p.Device) u32 {
    const t = taskOf(ptr);
    return t.host.forward(t, u32, "aviPlay", .{dev});
}

const task_vtable: p.Platform.VTable = .{
    .ticks = fwd("ticks"),
    .unixTime = fwd("unixTime"),
    .poll = tPoll,
    .wait = tWait,
    .screen = tScreen,
    .present = tPresent,
    .presentScreen = tPresentScreen,
    .textOut = fwd("textOut"),
    .textExtent = fwd("textExtent"),
    .open = fwd("open"),
    .read = fwd("read"),
    .write = fwd("write"),
    .seek = fwd("seek"),
    .close = fwd("close"),
    .mixGetInfo = fwd("mixGetInfo"),
    .mixConfigureInit = fwd("mixConfigureInit"),
    .mixOpenChannel = fwd("mixOpenChannel"),
    .mixCloseChannel = fwd("mixCloseChannel"),
    .mixCloseSession = fwd("mixCloseSession"),
    .mixActivate = fwd("mixActivate"),
    .waveOpen = fwd("waveOpen"),
    .waveFree = fwd("waveFree"),
    .wavePlay = fwd("wavePlay"),
    .waveFlush = fwd("waveFlush"),
    .mciString = fwd("mciString"),
    .aviOpen = fwd("aviOpen"),
    .aviPlay = tAviPlay,
    .aviStop = fwd("aviStop"),
    .aviClose = fwd("aviClose"),
    .winExec = tWinExec,
    .findWindow = tFindWindow,
    .postTo = tPostTo,
    .showMain = tShowMain,
    .windowHandle = tWindowHandle,
    .messageBox = fwd("messageBox"),
    .filterInput = fwd("filterInput"),
    .freeze = fwd("freeze"),
};

// ---- tests ----------------------------------------------------------------------

/// A stand-in minigame: answers the hello with 0x40c (wParam = its window),
/// reports a win 1 s later and quits.
const Fake = struct {
    plat: p.Platform,
    queue: @import("../core/queue.zig").Queue = .{},
    noite: Hwnd = 0,
    quit: bool = false,
    exited: *bool,
    gpa: std.mem.Allocator,
    var exited_flag: bool = false;

    fn start(gpa: std.mem.Allocator, plat: p.Platform, _: Fixes) anyerror!*anyopaque {
        const f = try gpa.create(Fake);
        f.* = .{ .plat = plat, .exited = &exited_flag, .gpa = gpa };
        return f;
    }
    fn of(ctx: *anyopaque) *Fake {
        return @ptrCast(@alignCast(ctx));
    }
    fn deliver(ctx: *anyopaque, ev: Event) void {
        const f = of(ctx);
        switch (ev) {
            .message => |m| _ = f.queue.post(m),
            else => {},
        }
    }
    fn step(ctx: *anyopaque) bool {
        const f = of(ctx);
        const m = f.queue.next(f.plat.ticks()) orelse return false;
        switch (m.id) {
            msg.noite.minigame_hello => {
                f.noite = m.lo();
                _ = f.plat.postTo(f.noite, .{ .id = msg.noite.minigame_ready, .wparam = f.plat.windowHandle() });
                _ = f.queue.setTimer(.system, 1, 1000, f.plat.ticks());
            },
            msg.wm.systimer => {
                _ = f.plat.postTo(f.noite, .{ .id = msg.noite.minigame_result, .wparam = 0xffff, .lparam = 1500 });
                f.quit = true;
            },
            else => {},
        }
        return true;
    }
    fn nextDue(ctx: *anyopaque) ?u32 {
        return of(ctx).queue.nextDue();
    }
    fn quitFn(ctx: *anyopaque) bool {
        return of(ctx).quit;
    }
    fn exit(ctx: *anyopaque) void {
        const f = of(ctx);
        f.exited.* = true;
        f.gpa.destroy(f);
    }
    const program: Program = .{
        .name = "encaixe",
        .title = "Encaixe Perfeito",
        .dir = "\\ENCAIXE",
        .ready = true,
        .start = start,
        .deliver = deliver,
        .step = step,
        .nextDue = nextDue,
        .quit = quitFn,
        .exit = exit,
    };
};

test "a real minigame: started by WinExec, found, hello/ready/result, then gone" {
    const Headless = @import("headless.zig").Headless;
    const gpa = std.testing.allocator;
    var hl = Headless.init(gpa, std.testing.io, .{});
    defer hl.deinit();
    var h: Host = undefined;
    const real = [_]*const Program{&Fake.program};
    h.init(gpa, hl.platform(), &hl.sim, .{ .real = &real, .startup_ms = 500 }, "Noite Animal", null);
    defer h.deinit();
    const noite = h.primary();
    Fake.exited_flag = false;

    try std.testing.expect(noite.winExec("D:\\ENCAIXE\\ENCAIXE.EXE") >= 32);
    try std.testing.expectEqual(@as(?Hwnd, null), noite.findWindow("Encaixe Perfeito"));
    // Its WinMain runs after the load time; NOITE is deactivated.
    noite.wait(null);
    try std.testing.expectEqual(@as(u32, 500), noite.ticks());
    try std.testing.expectEqual(@as(?Event, .{ .activate = false }), noite.poll());
    const w = noite.findWindow("Encaixe Perfeito").?;
    try std.testing.expect(w != msg.main_window);
    try std.testing.expect(h.top().?.id != 0);
    // Hello → ready (with its window handle) in NOITE's inbox.
    try std.testing.expect(noite.postTo(w, Msg.make(msg.noite.minigame_hello, 0, msg.main_window, 0)));
    const ready = noite.poll().?.message;
    try std.testing.expectEqual(msg.noite.minigame_ready, ready.id);
    try std.testing.expectEqual(w, ready.wparam);
    noite.showMain(false);
    try std.testing.expect(h.top().?.id != 0);
    // A second later the result, and the task is gone.
    noite.wait(null);
    try std.testing.expectEqual(@as(u32, 1500), noite.ticks());
    const res = noite.poll().?.message;
    try std.testing.expectEqual(msg.noite.minigame_result, res.id);
    try std.testing.expectEqual(@as(i32, 1500), res.lparam);
    try std.testing.expect(Fake.exited_flag);
    try std.testing.expectEqual(@as(?Hwnd, null), noite.findWindow("Encaixe Perfeito"));
    try std.testing.expectEqual(@as(usize, 1), h.results.items.len);
    try std.testing.expect(h.results.items[0].won);
    // NOITE shows itself again: it is the active window.
    noite.showMain(true);
    try std.testing.expect(h.alone());
    try std.testing.expectEqual(@as(?TaskId, 0), h.active);
    try std.testing.expectEqual(@as(?Event, .{ .activate = true }), noite.poll());
}

test "a program that is not ready stays the stub" {
    const Headless = @import("headless.zig").Headless;
    const gpa = std.testing.allocator;
    var hl = Headless.init(gpa, std.testing.io, .{});
    defer hl.deinit();
    var h: Host = undefined;
    var unready = Fake.program;
    unready.ready = false;
    const real = [_]*const Program{&unready};
    h.init(gpa, hl.platform(), &hl.sim, .{ .real = &real }, "Noite Animal", null);
    defer h.deinit();
    try std.testing.expect(h.primary().winExec("encaixe\\encaixe.exe") >= 32);
    try std.testing.expect(h.alone());
    try std.testing.expectEqualStrings("ENCAIXE", exeBase("D:\\ENCAIXE\\ENCAIXE.EXE /x"));
}
