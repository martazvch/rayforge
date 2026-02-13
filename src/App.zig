const std = @import("std");
const Allocator = std.mem.Allocator;
const c = @import("c");
const sdl = c.sdl;
const icons = @import("icons.zig");
const globals = @import("globals.zig");

pub fn init(allocator: Allocator) void {
    globals.init(allocator);
    icons.init(globals.device);
}

pub fn frame() !sdl.SDL_AppResult {
    return globals.pipeline.frame();
}
