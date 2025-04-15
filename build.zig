const std = @import("std");

pub fn build(b: *std.Build) void {
    const src_dir = "src";
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const install_step = b.getInstallStep();

    const fmt_step = b.step("fmt", "Format the source code");
    const test_step = b.step("test", "Run the unit tests");
    const doc_step = b.step("doc", "Install the docs");
    install_step.dependOn(doc_step);

    const release_step = b.step("release", "Format source, install docs and run unit tests");
    release_step.dependOn(fmt_step);
    release_step.dependOn(doc_step);
    release_step.dependOn(test_step);

    const fmt = b.addFmt(.{ .paths = &.{src_dir} });
    fmt_step.dependOn(&fmt.step);

    const src = b.path(src_dir);
    const root = src.path(b, "serialize.zig");

    const module = b.addModule("serialization", .{
        .root_source_file = root,
        .target = target,
        .optimize = optimize,
    });

    const tests = b.addTest(.{
        .name = "serialization-tests",
        .root_module = module,
    });
    const run_tests = b.addRunArtifact(tests);
    test_step.dependOn(&run_tests.step);

    const doc_compile = b.addTest(.{
        .name = "serialization-docs",
        .root_module = module,
    });
    doc_compile.step.dependOn(fmt_step);

    const docs = doc_compile.getEmittedDocs();
    b.addNamedLazyPath("docs", docs);

    const doc_install = b.addInstallDirectory(.{
        .install_dir = .{ .custom = "doc" },
        .source_dir = docs,
        .install_subdir = &.{},
    });

    doc_step.dependOn(&doc_install.step);
}
