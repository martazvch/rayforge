const std = @import("std");
const Io = std.Io;
const Allocator = std.mem.Allocator;
const c = @import("c");
const sdl = c.sdl;
const icons = @import("icons.zig");
const globals = @import("globals.zig");

pub fn init(io: Io, allocator: Allocator) void {
    globals.init(io, allocator);
    icons.init(globals.device);
}

pub fn frame() !sdl.SDL_AppResult {
    return globals.pipeline.frame();
}
