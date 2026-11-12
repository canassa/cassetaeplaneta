## [Compile Variables](#toc-Compile-Variables) [§](#Compile-Variables)

Compile variables are accessible by importing the `"builtin"` package, which the compiler makes available to every Zig source file. It contains compile-time constants such as the current target, endianness, and release mode.

    const builtin = @import("builtin");
    const separator = if (builtin.os.tag == .windows) '\\' else '/';

compile_variables.zig

Example of what is imported with `@import``(``"builtin"``)`:

    const std = @import("std");
    pub const zig_version = std.SemanticVersion.parse(zig_version_string) catch unreachable;
    pub const zig_version_string = "0.17.0-dev.2324+08e113808";
    pub const zig_backend = std.lang.CompilerBackend.stage2_x86_64;

    pub const output_mode: std.lang.OutputMode = .Exe;
    pub const link_mode: std.lang.LinkMode = .static;
    pub const unwind_tables: std.lang.UnwindTables = .async;
    pub const is_test = false;
    pub const single_threaded = false;
    /// Deprecated; to be removed in 0.18.0. Use `target.abi` instead.
    pub const abi: std.Target.Abi = .gnu;
    /// Deprecated; to be removed in 0.18.0. Use `target.cpu` instead.
    pub const cpu: std.Target.Cpu = .{
        .arch = .x86_64,
        .model = &std.Target.x86.cpu.znver4,
        .features = std.Target.x86.featureSet(&.{
            .@"64bit",
            .adx,
            .aes,
            .allow_light_256_bit,
            .avx,
            .avx2,
            .avx512bf16,
            .avx512bitalg,
            .avx512bw,
            .avx512cd,
            .avx512dq,
            .avx512f,
            .avx512ifma,
            .avx512vbmi,
            .avx512vbmi2,
            .avx512vl,
            .avx512vnni,
            .avx512vpopcntdq,
            .bmi,
            .bmi2,
            .branchfusion,
            .clflushopt,
            .clwb,
            .clzero,
            .cmov,
            .crc32,
            .cx16,
            .cx8,
            .f16c,
            .fast_15bytenop,
            .fast_bextr,
            .fast_dpwssd,
            .fast_imm16,
            .fast_lzcnt,
            .fast_movbe,
            .fast_scalar_fsqrt,
            .fast_scalar_shift_masks,
            .fast_variable_perlane_shuffle,
            .fast_vector_fsqrt,
            .fma,
            .fsgsbase,
            .fsrm,
            .fxsr,
            .gfni,
            .idivq_to_divl,
            .invpcid,
            .lzcnt,
            .macrofusion,
            .mmx,
            .movbe,
            .mwaitx,
            .nopl,
            .pclmul,
            .pku,
            .popcnt,
            .prfchw,
            .rdpid,
            .rdpru,
            .rdrnd,
            .rdseed,
            .sahf,
            .sbb_dep_breaking,
            .sha,
            .shstk,
            .smap,
            .smep,
            .sse,
            .sse2,
            .sse3,
            .sse4_1,
            .sse4_2,
            .sse4a,
            .ssse3,
            .vaes,
            .vpclmulqdq,
            .vzeroupper,
            .wbnoinvd,
            .x87,
            .xsave,
            .xsavec,
            .xsaveopt,
            .xsaves,
        }),
    };
    /// Deprecated; to be removed in 0.18.0. Use `target.os` instead.
    pub const os: std.Target.Os = .{
        .tag = .linux,
        .version_range = .{ .linux = .{
            .range = .{
                .min = .{
                    .major = 7,
                    .minor = 2,
                    .patch = 6,
                },
                .max = .{
                    .major = 7,
                    .minor = 2,
                    .patch = 6,
                },
            },
            .glibc = .{
                .major = 2,
                .minor = 42,
                .patch = 0,
            },
            .android = 29,
        }},
    };
    pub const target: std.Target = .{
        .cpu = cpu,
        .os = os,
        .abi = abi,
        .ofmt = object_format,
        .dynamic_linker = .init("/nix/store/rkiwrqh8g6gs5rws4bf1s3mrdcs15gm9-glibc-2.42-84/lib/ld-linux-x86-64.so.2"),
    };
    /// Deprecated; to be removed in 0.18.0. Use `target.ofmt` instead.
    pub const object_format: std.Target.ObjectFormat = .elf;
    /// Deprecated, to be removed after 0.18.0
    pub const mode = optimize;
    pub const optimize: std.lang.Optimize = .debug;
    pub const link_libc = false;
    pub const link_libcpp = false;
    pub const have_error_return_tracing = true;
    pub const valgrind_support = true;
    pub const sanitize_thread = false;
    pub const fuzz = false;
    pub const position_independent_code = false;
    pub const position_independent_executable = false;
    pub const strip_debug_info = false;
    pub const code_model: std.lang.CodeModel = .default;
    pub const omit_frame_pointer = false;

@import("builtin")

See also:

- [Optimization Mode](#Optimization-Mode)
