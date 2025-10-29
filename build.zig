const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{
        .default_target = .{
            .os_tag = .uefi,
            .abi = .msvc,
            .ofmt = .coff,
        },
    });

    const optimize = b.standardOptimizeOption(.{});

    b.exe_dir = "zig-out/EFI/BOOT/";

    const exe = b.addExecutable(.{
        .name = "BOOTX64",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/main.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });

    // b.installArtifact(exe);
    const install_step = b.addInstallArtifact(exe, .{ .dest_dir = .{ .override = .bin } });
    b.getInstallStep().dependOn(&install_step.step);

    const run_step = b.step("run", "Run the app");

    const run_cmd = b.addRunArtifact(exe);
    run_step.dependOn(&run_cmd.step);

    run_cmd.step.dependOn(b.getInstallStep());

    if (b.args) |args| {
        run_cmd.addArgs(args);
    }
}
