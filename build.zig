const std = @import("std");

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

    const lib = b.addLibrary(.{
        .name = "lz4",
        .root_module = b.createModule(.{
            .root_source_file = b.path(LIB_SRC),
            .target = target,
            .optimize = optimize,
        }),
        .linkage = .static,
    });

    const lz4_module = b.addModule("zig-lz4", .{
        .root_source_file = b.path("src/lib.zig"),
    });

    lz4_module.linkLibrary(lib);

    const FLAGS = [_][]const u8{
        "-DLZ4LIB_API=extern\"C\"",
    };

    for (HEADER_DIRS) |dir| {
        lib.root_module.addIncludePath(lz4_dependency.path(dir));
    }
    lib.root_module.link_libcpp = true;
    for (SOURCE_FILES) |file| {
        lib.root_module.addCSourceFile(.{ .file = lz4_dependency.path(file), .flags = &FLAGS });
    }

    lib.installHeader(lz4_dependency.path("lib/lz4.h"), "lz4.h");
    lib.installHeader(lz4_dependency.path("lib/lz4frame.h"), "lz4frame.h");

    b.installArtifact(lib);

    // Unit tests
    const lib_unit_tests = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path(LIB_SRC),
            .target = target,
            .optimize = optimize,
        }),
    });

    lib_unit_tests.root_module.linkLibrary(lib);
    lib_unit_tests.root_module.addIncludePath(lz4_dependency.path("lib"));

    const run_lib_unit_tests = b.addRunArtifact(lib_unit_tests);

    const test_step = b.step("test", "Run unit tests");
    test_step.dependOn(&run_lib_unit_tests.step);

    // Docs
    const docs_step = b.step("docs", "Build documentation");

    const docs_obj = b.addObject(.{
        .name = "docs",
        .root_module = b.createModule(.{
            .root_source_file = b.path(LIB_SRC),
            .target = target,
            .optimize = optimize,
        }),
    });

    docs_obj.root_module.linkLibrary(lib);
    docs_obj.root_module.addIncludePath(lz4_dependency.path("lib"));

    const install_docs = b.addInstallDirectory(.{
        .source_dir = docs_obj.getEmittedDocs(),
        .install_dir = .prefix,
        .install_subdir = "docs",
    });
    docs_step.dependOn(&install_docs.step);
}
