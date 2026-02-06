const std = @import("std");
const Allocator = std.mem.Allocator;
const c = @import("c");
const sdl = c.sdl;
const Camera = @import("Camera.zig");
const Scene = @import("Scene.zig");
const EventLoop = @import("EventLoop.zig");
const Pipeline = @import("Pipeline.zig");
const Editor = @import("editor/Editor.zig");

pipeline: Pipeline,
event_loop: EventLoop,
scene: Scene,
editor: Editor,
state: State,

const State = struct {
    delta_time: f32 = 0,
    last_frame: f32 = 0,
};

const Self = @This();

pub fn init(allocator: Allocator) Self {
    return .{
        .pipeline = .init(allocator),
        .scene = .init(),
        .event_loop = .init(),
        .editor = undefined,
        .state = .{},
    };
}

pub fn deinit(self: *Self) void {
    self.editor.deinit();
    self.pipeline.deinit();
}

pub fn initEditor(self: *Self) void {
    self.editor = .init(self.pipeline.device, self.pipeline.window);
    self.scene.debug();
}

pub fn bindCurrentCamera(self: *Self) void {
    self.event_loop.bindCamera(&self.scene.camera);
}

pub fn frame(self: *Self) !sdl.SDL_AppResult {
    const time = @as(f32, @floatFromInt(sdl.SDL_GetTicksNS())) / 1e9;
    self.state.delta_time = time - self.state.last_frame;
    self.state.last_frame = time;

    return self.pipeline.frame(&self.scene, &self.editor);
}
