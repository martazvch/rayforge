const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const exe = b.addExecutable(.{
        .name = "ray-forge",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/main.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });

    // -------
    //  ZLM
    // -------
    const zlm_dep = b.dependency("zlm", .{
        .target = target,
        .optimize = optimize,
    });
    exe.root_module.addImport("zlm", zlm_dep.module("zlm"));

    // -------
    //  SDL3
    // -------
    const sdl_dep = b.dependency("sdl", .{
        .target = target,
        .optimize = optimize,
        .preferred_linkage = .static,
    });
    const sdl_lib = sdl_dep.artifact("SDL3");

    // -------
    //  ImGUI
    // -------
    const imgui_dep = b.dependency("zimgui", .{
        .target = target,
        .optimize = optimize,
    });
    const imgui_lib = imgui_dep.artifact("imgui");

    // -------
    //  Zstbi
    // -------
    const zstbi_dep = b.dependency("zstbi", .{
        .target = target,
        .optimize = optimize,
    });
    const zstbi_lib = zstbi_dep.artifact("zstbi");

    // -------
    //  All C
    // -------
    const c = b.createModule(.{
        .root_source_file = b.path("src/c.zig"),
        .target = target,
        .optimize = optimize,
    });
    c.linkLibrary(sdl_lib);
    c.linkLibrary(imgui_lib);
    c.linkLibrary(zstbi_lib);
    exe.root_module.addImport("c", c);

    b.installArtifact(exe);

    const run_step = b.step("run", "Run the app");
    const run_cmd = b.addRunArtifact(exe);
    run_step.dependOn(&run_cmd.step);
    run_cmd.step.dependOn(b.getInstallStep());

    if (b.args) |args| {
        run_cmd.addArgs(args);
    }

    const exe_tests = b.addTest(.{
        .root_module = exe.root_module,
    });
    const run_exe_tests = b.addRunArtifact(exe_tests);

    const test_step = b.step("test", "Run tests");
    test_step.dependOn(&run_exe_tests.step);

    // ---------
    //  Shaders
    // ---------
    var build_shaders = b.addSystemCommand(&.{"sh"});
    build_shaders.addFileArg(b.path("build_shaders.sh"));
    exe.step.dependOn(&build_shaders.step);

    // --------
    // For ZLS
    // --------
    const exe_check = b.addExecutable(.{
        .name = "foo",
        .root_module = exe.root_module,
    });
    exe_check.root_module.linkLibrary(sdl_lib);
    exe_check.root_module.linkLibrary(imgui_lib);
    exe_check.root_module.linkLibrary(zstbi_lib);
    exe_check.root_module.addImport("zlm", zlm_dep.module("zlm"));

    const check = b.step("check", "Check if foo compiles");
    check.dependOn(&exe_check.step);
}
