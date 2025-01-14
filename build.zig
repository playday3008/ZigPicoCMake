const std = @import("std");
const builtin = @import("builtin");

const pico = @import("pico.zig");

/// Default board configuration
const default_board = pico.PicoW;

/// Standard I/O configuration
const stdio: pico.Stdio = .{
    .UART = true,
    .USB = true,
};

/// Libraries to link
const link_libs_base = &[_]pico.Lib{
    pico.api.runtime.pico.printf,
    pico.api.high_level.stdlib,
};

/// Libraries to link if CYW43439 is used
const link_libs_cyw43 = &[_]pico.Lib{
    pico.api.network.cyw43_arch.none,
};

/// Get dependency path by name
inline fn getDependencyPath(b: *std.Build, name: [:0]const u8) []const u8 {
    const dep = b.dependency(name, .{});
    const lazy_path = dep.path(".");
    const path = lazy_path.getPath(b);
    std.log.debug("{s} path: {s}", .{ name, path });
    return path;
}

pub fn build(b: *std.Build) !void {
    // Get board name from command line or use default
    const board_str = b.option(
        []const u8,
        "board",
        "Board to build for",
    ) orelse default_board.name;

    const board = blk: {
        for (pico.Boards) |board| {
            if (std.mem.eql(u8, board.name, board_str)) {
                std.log.debug("Building for board: {s}", .{board.name});
                break :blk board;
            }
        }
        @panic(b.fmt("Unknown board: {s}", .{board_str}));
    };

    // Get build directory from command line or use default
    const build_dir = b.option(
        []const u8,
        "build_dir",
        "Build directory",
    ) orelse b.fmt("./build/{s}", .{board.name});
    std.log.debug("Build directory: {s}", .{build_dir});

    // Based on board, link libraries
    var link_libs = std.ArrayList(pico.Lib).init(b.allocator);
    defer link_libs.deinit();
    try link_libs.appendSlice(link_libs_base);
    if (board.wireless == .CYW43439) {
        try link_libs.appendSlice(link_libs_cyw43);
    }

    // Resolve target architecture
    const target = b.resolveTargetQuery(std.Target.Query{
        .cpu_arch = board.platform.arch.arch(),
        .cpu_model = board.platform.model(),
        .os_tag = .freestanding,
        .abi = board.platform.arch.abi(),
    });

    const optimize = b.standardOptimizeOption(.{});

    // Create the Zig library
    const lib = b.addStaticLibrary(.{
        .name = "ZigPicoCMake",
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
        .link_libc = true,
        .strip = true,
    });

    // Resolve dependency paths
    const pico_sdk_path: []const u8 = getDependencyPath(b, "pico-sdk");
    const pico_btstack_path: []const u8 = getDependencyPath(b, "btstack");
    const pico_cyw43_driver_path: []const u8 = getDependencyPath(b, "cyw43-driver");
    const pico_lwip_path: []const u8 = getDependencyPath(b, "lwip");
    const pico_tinyusb_path: []const u8 = getDependencyPath(b, "tinyusb");

    // Universal CMake arguments
    const cmake_universal_args: std.ArrayList([]u8) = blk: {
        var args: std.ArrayList([]u8) = std.ArrayList([]u8).init(b.allocator);
        // CMake project configuration
        {
            try args.appendSlice(&[_][]u8{
                b.fmt("-DPROJECT_NAME:STRING={s}", .{lib.name}),
                b.fmt("-DCMAKE_EXPORT_COMPILE_COMMANDS:BOOL={s}", .{"ON"}),
                b.fmt("-DCMAKE_BUILD_TYPE:STRING={s}", .{
                    switch (optimize) {
                        .Debug => "Debug",
                        .ReleaseFast => "Release",
                        .ReleaseSafe => "RelWithDebInfo",
                        .ReleaseSmall => "MinSizeRel",
                    },
                }),
            });
            if (lib.version) |version| {
                try args.append(b.fmt("-DPROJECT_VERSION:STRING={}", .{version}));
            }
        }
        // Pico SDK configuration
        {
            try args.appendSlice(&[_][]u8{
                // SDK locations
                b.fmt("-DPICO_SDK_PATH:PATH={s}", .{pico_sdk_path}),
                b.fmt("-DPICO_BTSTACK_PATH:PATH={s}", .{pico_btstack_path}),
                b.fmt("-DPICO_CYW43_DRIVER_PATH:PATH={s}", .{pico_cyw43_driver_path}),
                b.fmt("-DPICO_LWIP_PATH:PATH={s}", .{pico_lwip_path}),
                b.fmt("-DPICO_TINYUSB_PATH:PATH={s}", .{pico_tinyusb_path}),
                // Custom string to tell CMake which toolchain to use
                b.fmt("-DHOST_OS:STRING={s}", .{@tagName(builtin.os.tag)}),
                b.fmt("-DHOST_ARCH:STRING={s}", .{@tagName(builtin.cpu.arch)}),
                b.fmt("-DPICO_ARCH:STRING={s}", .{board.platform.arch.str()}),
                // Pico SDK settings
                b.fmt("-DPICO_BOARD:STRING={s}", .{if (board.cmake_name) |name| name else board.name}),
                b.fmt("-DPICO_PLATFORM:STRING={s}", .{board.platform.str()}),
                // Pico C++ settings
                b.fmt("-DPICO_CXX_ENABLE_EXCEPTIONS:BOOL={s}", .{"OFF"}),
                b.fmt("-DPICO_CXX_ENABLE_RTTI:BOOL={s}", .{"OFF"}),
            });
            inline for (std.meta.fields(@TypeOf(stdio))) |val| {
                std.log.debug("Stdio: {s} = {s}", .{
                    val.name,
                    if (@as(val.type, @field(stdio, val.name))) "ON" else "OFF",
                });
                try args.append(b.fmt("-DPICO_STDIO_{s}:BOOL={s}", .{
                    val.name,
                    if (@as(val.type, @field(stdio, val.name))) "ON" else "OFF",
                }));
            }
        }
        // Link libraries
        {
            var libs = std.ArrayList([]const u8).init(b.allocator);
            defer libs.deinit();
            for (link_libs.items) |l| {
                if (l.arch) |arch| {
                    if (arch != board.platform.arch) {
                        std.log.info("Skipping library {s} for {s} architecture", .{
                            l.name,
                            board.platform.arch.str(),
                        });
                        continue;
                    }
                }
                if (l.chip) |chip| {
                    if (chip != board.platform.chip) {
                        std.log.info("Skipping library {s} for {s} chip", .{
                            l.name,
                            board.platform.chip.str(),
                        });
                        continue;
                    }
                }
                std.log.debug("Linking library: {s}", .{l.name});
                try libs.append(l.name);
            }
            try args.appendSlice(&[_][]u8{
                b.fmt("-DTARGET_LINK_LIBS:STRING={s}", .{try std.mem.join(b.allocator, ";", libs.items)}),
            });
        }
        break :blk args;
    };
    defer cmake_universal_args.deinit();

    // Create CMake step to generate the build files
    const cmake_init_step = cmake: {
        const step = std.Build.Step.Run.create(b, "CMake init");
        step.addArgs(&[_][]const u8{
            "cmake",
            "-B",
            build_dir,
            "-S .",
            "--fresh",
        });
        step.addArgs(cmake_universal_args.items);
        step.setEnvironmentVariable("BUILD_FROM_ZIG", "ON");
        break :cmake step;
    };
    cmake_init_step.has_side_effects = true;

    // Custom CMake post init step
    const cmake_post_init_step = try b.allocator.create(CmakePostInitStep);
    cmake_post_init_step.* = CmakePostInitStep.init(b, lib, &build_dir);
    cmake_post_init_step.step.dependOn(&cmake_init_step.step);

    // Add the CMake post init step to the build
    lib.step.dependOn(&cmake_post_init_step.step);

    const compiled = lib.getEmittedBin();
    const install_step = b.addInstallFile(compiled, b.fmt("{s}.o", .{lib.name}));
    install_step.step.dependOn(&lib.step);

    // Create CMake step to build the project
    const cmake_build_step = b.addSystemCommand(
        &[_][]const u8{
            "cmake",
            "--build",
            build_dir,
            "--parallel",
        },
    );
    cmake_build_step.setEnvironmentVariable("BUILD_FROM_ZIG", "ON");
    cmake_build_step.has_side_effects = true;
    cmake_build_step.step.dependOn(&install_step.step);

    const uf2_create_step = b.addInstallFile(b.path(
        b.fmt("{s}/{s}.uf2", .{
            build_dir,
            lib.name,
        }),
    ), "firmware.uf2");
    uf2_create_step.step.dependOn(&cmake_build_step.step);

    const uf2_step = b.step("uf2", "Create firmware.uf2");
    uf2_step.dependOn(&uf2_create_step.step);

    b.default_step = uf2_step;

    // CMake clean
    const cmake_clean_command = b.addSystemCommand(
        &[_][]const u8{
            "cmake",
            "--build",
            build_dir,
            "--target",
            "clean",
        },
    );
    cmake_clean_command.setEnvironmentVariable("BUILD_FROM_ZIG", "ON");
    const cmake_clean_step = b.step("clean", "Clean CMake build");
    cmake_clean_step.dependOn(&cmake_clean_command.step);
}

const CmakePostInitStep = struct {
    b: *std.Build,
    step: std.Build.Step,
    lib: *std.Build.Step.Compile,
    build_dir: []const u8,
    sysroot_resolved: bool = false,

    pub fn init(b: *std.Build, lib: *std.Build.Step.Compile, build_dir: *const []const u8) CmakePostInitStep {
        return .{
            .step = std.Build.Step.init(.{
                .id = .custom,
                .name = "CMake post init",
                .owner = b,
                .makeFn = CmakePostInitStep.doStep,
            }),
            .b = b,
            .lib = lib,
            .build_dir = build_dir.*,
        };
    }

    /// From CMake generated file extract all suff from `C_DEFINES`, `C_INCLUDES`, `C_FLAGS`
    ///
    pub fn doStep(step: *std.Build.Step, prog_node: std.Progress.Node) anyerror!void {
        _ = prog_node;
        const self: *CmakePostInitStep = @fieldParentPtr("step", step);

        try self.parseCmakeFlags();
        if (!self.sysroot_resolved) {
            try self.resolveToolchainIncludePaths();
        }
    }

    /// Parse CMake generated flags.make file
    /// and extract all flags from `C_DEFINES`, `C_INCLUDES`, `C_FLAGS`
    ///
    /// This will also find sysroot if exists
    fn parseCmakeFlags(self: *CmakePostInitStep) !void {
        const flags_file = self.b.path(self.b.fmt("{s}/CMakeFiles/{s}.dir/flags.make", .{ self.build_dir, self.lib.name }));

        const file = try std.fs.openFileAbsolute(flags_file.getPath(self.b), .{});
        defer file.close();

        const reader = file.reader();
        const content = try reader.readAllAlloc(self.b.allocator, std.math.maxInt(usize));
        defer self.b.allocator.free(content);

        var it = std.mem.splitSequence(u8, content, "\n");
        while (it.next()) |line| {
            // Line is `C_DEFINES = -D<MACRO>[=<VALUE>] ...`
            if (std.mem.startsWith(u8, line, "C_DEFINES")) {
                var flags = std.mem.splitSequence(
                    u8,
                    line[(std.mem.indexOf(
                        u8,
                        line,
                        "=",
                    ) orelse continue) + 1 ..],
                    " ",
                );
                const macro_needle = "-D";
                while (flags.next()) |_flag| {
                    if (std.mem.startsWith(u8, _flag, macro_needle)) {
                        const flag = _flag[macro_needle.len..];
                        // Split <MACRO>=<VALUE>
                        var split = std.mem.splitSequence(
                            u8,
                            flag,
                            "=",
                        );
                        self.lib.root_module.addCMacro(split.first(), split.peek() orelse "1");
                    }
                }
            }
            // Line is `C_INCLUDES = -I<path> -I... -isystem <path> -isystem ...`
            if (std.mem.startsWith(u8, line, "C_INCLUDES")) {
                var paths = std.mem.splitSequence(
                    u8,
                    line[(std.mem.indexOf(
                        u8,
                        line,
                        "=",
                    ) orelse continue) + 1 ..],
                    " ",
                );
                const include_needle = "-I";
                const system_include_needle = "-isystem";
                var is_system = false;
                while (paths.next()) |path| {
                    if (path.len == 0) continue;
                    if (is_system) {
                        self.lib.addSystemIncludePath(.{ .cwd_relative = path });
                        is_system = false;
                    } else if (std.mem.startsWith(u8, path, include_needle)) {
                        self.lib.addIncludePath(.{ .cwd_relative = path[include_needle.len..] });
                    } else if (std.mem.startsWith(u8, path, system_include_needle)) {
                        is_system = true;
                        continue;
                    } else {
                        unreachable;
                    }
                }
            }
            // Line is `C_FLAGS = [...] --sysroot <path>[...]`
            if (std.mem.startsWith(u8, line, "C_FLAGS")) {
                var flags = std.mem.splitSequence(
                    u8,
                    line[(std.mem.indexOf(
                        u8,
                        line,
                        "=",
                    ) orelse continue) + 1 ..],
                    " ",
                );
                const sysroot_needle = "--sysroot";
                var is_sysroot = false;
                while (flags.next()) |flag| {
                    if (is_sysroot) {
                        self.b.addSearchPrefix(flag);
                        self.lib.addSystemIncludePath(.{ .cwd_relative = self.b.pathJoin(&[_][]const u8{ flag, "include" }) });
                        self.sysroot_resolved = true;
                        is_sysroot = false;
                        break;
                    } else if (std.mem.startsWith(u8, flag, sysroot_needle)) {
                        is_sysroot = true;
                    }
                }
            }
        }
    }

    /// Resolve toolchain include paths
    ///
    /// Called when sysroot is not found in `C_FLAGS`
    fn resolveToolchainIncludePaths(self: *CmakePostInitStep) !void {
        const cmake_cache = self.b.path(self.b.fmt("{s}/CMakeCache.txt", .{self.build_dir}));

        const file = try std.fs.openFileAbsolute(cmake_cache.getPath(self.b), .{});
        defer file.close();

        const reader = file.reader();
        const content = try reader.readAllAlloc(self.b.allocator, std.math.maxInt(usize));
        defer self.b.allocator.free(content);

        var c_compiler_path: ?[]const u8 = null;
        var toolchain_path: ?[]const u8 = null;

        var cache_it = std.mem.splitSequence(u8, content, "\n");
        while (cache_it.next()) |line| {
            if (std.mem.startsWith(u8, line, "CMAKE_C_COMPILER:")) {
                c_compiler_path = line[(std.mem.indexOf(
                    u8,
                    line,
                    "=",
                ) orelse continue) + 1 ..];
            }
            if (std.mem.startsWith(u8, line, "PICO_TOOLCHAIN_PATH:")) {
                toolchain_path = line[(std.mem.indexOf(
                    u8,
                    line,
                    "=",
                ) orelse continue) + 1 ..];
            }
        }

        if (toolchain_path) |toolchain| {
            if (c_compiler_path) |c_compiler| {
                if (!std.mem.startsWith(u8, c_compiler, toolchain)) {
                    std.log.err("{s} is not in {s}", .{ c_compiler, toolchain });
                    @panic("CMAKE_C_COMPILER is not in PICO_TOOLCHAIN_PATH");
                }

                // Run compiler with
                // on Unix: `-E -Wp,-v -xc /dev/null`
                // on Windows: `-E -Wp,-v -xc nul`
                // then read stdout to get include paths
                var compiler = std.process.Child.init(&[_][]const u8{
                    c_compiler,
                    "-E",
                    "-Wp,-v",
                    "-xc",
                    if (builtin.os.tag == .windows) "nul" else "/dev/null",
                }, self.b.allocator);

                compiler.stdout_behavior = .Pipe;
                compiler.stderr_behavior = .Pipe;
                compiler.spawn() catch |err| {
                    @panic(self.b.fmt("Could not run compiler: {}", .{err}));
                };

                const stdout_output = try compiler.stdout.?.reader().readAllAlloc(self.b.allocator, 16384);
                defer self.b.allocator.free(stdout_output);
                const stderr_output = try compiler.stderr.?.reader().readAllAlloc(self.b.allocator, 16384);
                defer self.b.allocator.free(stderr_output);
                const output = try std.mem.concat(self.b.allocator, u8, &[_][]const u8{ stderr_output, stdout_output });
                defer self.b.allocator.free(output);

                const term = try compiler.wait();
                switch (term) {
                    .Exited => |code| {
                        if (code != 0) {
                            @panic(self.b.fmt("Compiler exited with code {d}", .{code}));
                        }
                    },
                    else => {
                        @panic(self.b.fmt("Compiler failed with error {}", .{term}));
                    },
                }

                var output_it = std.mem.splitSequence(u8, output, "\n");
                while (output_it.next()) |line| {
                    if (std.mem.startsWith(u8, line, "#include <...> search starts here:")) {
                        while (output_it.next()) |path| {
                            if (std.mem.startsWith(u8, path, "End of search list.")) break;
                            const trimmed = std.mem.trim(
                                u8,
                                path,
                                " ",
                            );
                            // Make sure the path is in the toolchain directory
                            if (std.mem.startsWith(u8, trimmed, toolchain)) {
                                self.lib.addSystemIncludePath(.{
                                    .cwd_relative = trimmed,
                                });
                            }
                        }
                        break;
                    }
                }
            } else {
                @panic("Could not find CMAKE_C_COMPILER in CMakeCache.txt");
            }
        } else {
            @panic("Could not find PICO_TOOLCHAIN_PATH in CMakeCache.txt");
        }
    }
};
