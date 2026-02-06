const std = @import("std");

pub fn oom() noreturn {
    std.debug.print("outof memory", .{});
    std.process.exit(1);
}

pub fn fatal(comptime format: []const u8, args: anytype) noreturn {
    var buf: [2056]u8 = undefined;
    var writer = std.fs.File.stderr().writer(&buf);
    const interface = &writer.interface;
    interface.print("[Fatal error]: " ++ format ++ "\n", args) catch oom();
    interface.flush() catch oom();
    std.process.exit(1);
}
