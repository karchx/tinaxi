const std = @import("std");

pub fn build(b: *std.Build) void {
    const exe = b.addExecutable(.{
        .name = "tinaxi",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/main.zig"),
            .target = b.graph.host,
        }),
    });

    b.installArtifact(exe);

    const run_exe = b.addRunArtifact(exe);

    const run_step = b.step("run", "Run the tinaxi application");
    run_step.dependOn(&run_exe.step);

    const lib_unit_tests = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/kv.zig"),
            .target = b.graph.host,
            .optimize = b.standardOptimizeOption(.{})
        }),
    });
    const run_lib_unit_tests = b.addRunArtifact(lib_unit_tests);

    const test_step = b.step("test", "Run tests");
    test_step.dependOn(&run_lib_unit_tests.step);
}
