const std = @import("std");
const globals = @import("globals.zig");

pub fn oom() noreturn {
    std.debug.print("outof memory", .{});
    std.process.exit(1);
}

pub fn fatal(comptime format: []const u8, args: anytype) noreturn {
    var buf: [2056]u8 = undefined;
    var writer = std.Io.File.stderr().writer(globals.io, &buf);
    const interface = &writer.interface;
    interface.print("[Fatal error]: " ++ format ++ "\n", args) catch oom();
    interface.flush() catch oom();
    std.process.exit(1);
}
