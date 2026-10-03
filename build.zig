const std = @import("std");
const Translator = @import("translate_c").Translator;

const SOURCE_FILES = [_][]const u8{
    "lib/lz4.c",
    "lib/lz4frame.c",
    "lib/lz4hc.c",
    "lib/xxhash.c",
};

const HEADER_DIRS = [_][]const u8{
    "lib",
};

const LIB_SRC = "src/lib.zig";

pub fn build(b: *std.Build) void {
    const lz4_dependency = b.lazyDependency("lz4", .{}) orelse unreachable;

    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const lz4_module = b.createModule(.{
        .target = target,
        .optimize = optimize,
        .link_libc = true,
    });

    const FLAGS = [_][]const u8{
        "-DLZ4LIB_API=extern\"C\"",
    };
    for (SOURCE_FILES) |file| {
        lz4_module.addCSourceFile(.{ .file = lz4_dependency.path(file), .flags = &FLAGS });
    }
    for (HEADER_DIRS) |dir| {
        lz4_module.addIncludePath(lz4_dependency.path(dir));
    }

    const lz4 = b.addLibrary(.{
        .name = "lz4",
        .root_module = lz4_module,
    });
    lz4.installHeader(lz4_dependency.path("lib/lz4.h"), "lz4.h");
    lz4.installHeader(lz4_dependency.path("lib/lz4frame.h"), "lz4frame.h");

    const translate_c = b.dependency("translate_c", .{});
    const translator: Translator = .init(translate_c, .{
        .c_source_file = b.path("src/c.h"),
        .target = target,
        .optimize = optimize,
    });
    translator.linkLibrary(lz4);

    const zig_lz4_module = b.addModule("zig-lz4", .{
        .root_source_file = b.path("src/lib.zig"),
        .target = target,
        .optimize = optimize,
        .imports = &.{.{ .name = "c", .module = translator.mod }},
    });
    const zig_lz4 = b.addLibrary(.{
        .name = "zig-lz4",
        .root_module = lz4_module,
    });

    b.installArtifact(zig_lz4);

    // Unit tests
    const lib_unit_tests = b.addTest(.{
        .root_module = zig_lz4_module,
    });

    const run_lib_unit_tests = b.addRunArtifact(lib_unit_tests);

    const test_step = b.step("test", "Run unit tests");
    test_step.dependOn(&run_lib_unit_tests.step);

    // Docs
    const docs_step = b.step("docs", "Build documentation");

    const docs_obj = b.addObject(.{
        .name = "docs",
        .root_module = zig_lz4_module,
    });

    const install_docs = b.addInstallDirectory(.{
        .source_dir = docs_obj.getEmittedDocs(),
        .install_dir = .prefix,
        .install_subdir = "docs",
    });
    docs_step.dependOn(&install_docs.step);
}
