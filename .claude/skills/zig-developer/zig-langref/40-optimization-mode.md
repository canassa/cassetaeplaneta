## [Optimization Mode](#toc-Optimization-Mode) [§](#Optimization-Mode)

Zig has four optimization modes:

- [debug](#debug) (default)
- [fast](#fast)
- [safe](#safe)
- [small](#small)

To add standard build options to a `build.zig` file:

    const std = @import("std");

    pub fn build(b: *std.Build) void {
        const optimize = b.standardOptimizeOption(.{});
        const exe = b.addExecutable(.{
            .name = "example",
            .root_module = b.createModule(.{
                .root_source_file = b.path("example.zig"),
                .optimize = optimize,
            }),
        });
        b.default_step.dependOn(&exe.step);
    }

build.zig

This causes these options to be available:

-Doptimize=debug  
Optimizations off and safety on (default)

-Doptimize=safe  
Optimizations on and safety on

-Doptimize=fast  
Optimizations on and safety off

-Doptimize=small  
Size optimizations on and safety off

### [debug](#toc-debug) [§](#debug)

    $ zig build-exe example.zig

Shell

- Fast compilation speed
- Safety checks enabled
- Slow runtime performance
- Large binary size
- No reproducible build requirement

### [fast](#toc-fast) [§](#fast)

    $ zig build-exe example.zig -Ofast

Shell

- Fast runtime performance
- Safety checks disabled
- Slow compilation speed
- Large binary size
- Reproducible build

### [safe](#toc-safe) [§](#safe)

    $ zig build-exe example.zig -Osafe

Shell

- Medium runtime performance
- Safety checks enabled
- Slow compilation speed
- Large binary size
- Reproducible build

### [small](#toc-small) [§](#small)

    $ zig build-exe example.zig -Osmall

Shell

- Medium runtime performance
- Safety checks disabled
- Slow compilation speed
- Small binary size
- Reproducible build

See also:

- [Compile Variables](#Compile-Variables)
- [Zig Build System](#Zig-Build-System)
- [Illegal Behavior](#Illegal-Behavior)
