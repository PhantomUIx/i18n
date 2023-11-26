const std = @import("std");

const Sdk = blk: {
    const buildDeps = @import("root").dependencies;
    for (buildDeps.root_deps) |dep| {
        if (std.mem.eql(u8, dep[0], "phantom")) {
            const pkg = @field(buildDeps.packages, dep[1]);
            for (pkg.deps) |childDeps| {
                if (std.mem.eql(u8, childDeps[0], "phantom-sdk")) {
                    break :blk @field(buildDeps.packages, childDeps[1]).build_zig;
                }
            }
        }
    }

    break :blk null;
};

pub usingnamespace if (@typeInfo(@TypeOf(Sdk)) != .Null) struct {
    pub const phantomModule = Sdk.PhantomModule{};
} else struct {};

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});
    const no_docs = b.option(bool, "no-docs", "skip installing documentation") orelse false;

    const metaplus = b.dependency("metaplus", .{
        .target = target,
        .optimize = optimize,
    });

    _ = b.addModule("meta+", .{
        .source_file = .{
            .path = metaplus.builder.pathFromRoot(metaplus.module("meta+").source_file.path),
        },
    });

    const phantom_i18n = b.addModule("phantom.i18n", .{
        .source_file = .{ .path = b.pathFromRoot("src/phantom.zig") },
        .dependencies = &.{
            .{
                .name = "meta+",
                .module = metaplus.module("meta+"),
            },
        },
    });

    const step_test = b.step("test", "Run all unit tests");

    const unit_tests = b.addTest(.{
        .root_source_file = .{
            .path = b.pathFromRoot("src/phantom.zig"),
        },
        .target = target,
        .optimize = optimize,
    });

    unit_tests.addModule("meta+", metaplus.module("meta+"));

    const run_unit_tests = b.addRunArtifact(unit_tests);
    step_test.dependOn(&run_unit_tests.step);

    const exe_example = b.addExecutable(.{
        .name = "example",
        .root_source_file = .{
            .path = b.pathFromRoot("src/example.zig"),
        },
        .target = target,
        .optimize = optimize,
    });

    exe_example.addModule("phantom.i18n", phantom_i18n);
    b.installArtifact(exe_example);

    if (!no_docs) {
        const docs = b.addInstallDirectory(.{
            .source_dir = unit_tests.getEmittedDocs(),
            .install_dir = .prefix,
            .install_subdir = "docs",
        });

        b.getInstallStep().dependOn(&docs.step);
    }
}
