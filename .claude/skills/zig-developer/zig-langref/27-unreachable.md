## [unreachable](#toc-unreachable) [§](#unreachable)

In [debug](#debug) and [safe](#safe) mode `unreachable` emits a call to `panic` with the message `reached unreachable code`.

In [fast](#fast) and [small](#small) mode, the optimizer uses the assumption that `unreachable` code will never be hit to perform optimizations.

### [Basics](#toc-Basics) [§](#Basics)

    // unreachable is used to assert that control flow will never reach a
    // particular location:
    test "basic math" {
        const x = 1;
        const y = 2;
        if (x + y != 3) {
            unreachable;
        }
    }

test_unreachable.zig

    $ zig test test_unreachable.zig
    1/1 test_unreachable.test.basic math...OK
    All 1 tests passed.

Shell

In fact, this is how `std.debug.assert` is implemented:

    // This is how std.debug.assert is implemented
    fn assert(ok: bool) void {
        if (!ok) unreachable; // assertion failure
    }

    // This test will fail because we hit unreachable.
    test "this will fail" {
        assert(false);
    }

test_assertion_failure.zig

    $ zig test test_assertion_failure.zig
    1/1 test_assertion_failure.test.this will fail...thread 708684 panic: reached unreachable code
    /home/andy/src/zig/doc/langref/test_assertion_failure.zig:3:14: 0x124c5a9 in assert (test_assertion_failure.zig)
        if (!ok) unreachable; // assertion failure
                 ^
    /home/andy/src/zig/doc/langref/test_assertion_failure.zig:8:11: 0x124c57e in test.this will fail (test_assertion_failure.zig)
        assert(false);
              ^
    /home/andy/src/zig/lib/compiler/test_runner.zig:295:25: 0x1200951 in mainTerminal (test_runner.zig)
            if (test_fn.func()) |_| {
                            ^
    /home/andy/src/zig/lib/compiler/test_runner.zig:74:28: 0x1200132 in main (test_runner.zig)
            return mainTerminal(init);
                               ^
    /home/andy/src/zig/lib/std/start.zig:789:88: 0x11fc8cf in callMain (std.zig)
        if (fn_info.param_types[0].? == std.process.Init.Minimal) return wrapMain(root.main(.{
                                                                                           ^
    /home/andy/src/zig/lib/std/start.zig:248:5: 0x11fc2b1 in _start (std.zig)
        asm volatile (switch (native_arch) {
        ^
    error: the following test command terminated with signal ABRT:
    /home/andy/src/zig/.zig-cache/o/fd00e88bd13ffee28e46bc2aecbfd750/test --seed=0x3b92b89e

Shell

### [At Compile-Time](#toc-At-Compile-Time) [§](#At-Compile-Time)

    const assert = @import("std").debug.assert;

    test "type of unreachable" {
        comptime {
            // The type of unreachable is noreturn.

            // However this assertion will still fail to compile because
            // unreachable expressions are compile errors.

            assert(@TypeOf(unreachable) == noreturn);
        }
    }

test_comptime_unreachable.zig

    $ zig test test_comptime_unreachable.zig
    /home/andy/src/zig/doc/langref/test_comptime_unreachable.zig:10:16: error: unreachable code
            assert(@TypeOf(unreachable) == noreturn);
                   ^~~~~~~~~~~~~~~~~~~~
    /home/andy/src/zig/doc/langref/test_comptime_unreachable.zig:10:24: note: control flow is diverted here
            assert(@TypeOf(unreachable) == noreturn);
                           ^~~~~~~~~~~

Shell

See also:

- [Zig Test](#Zig-Test)
- [Optimization Mode](#Optimization-Mode)
- [comptime](#comptime)
