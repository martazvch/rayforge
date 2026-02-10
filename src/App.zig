const std = @import("std");
const Allocator = std.mem.Allocator;
const c = @import("c");
const sdl = c.sdl;
const Camera = @import("Camera.zig");
const Scene = @import("Scene.zig");
const EventLoop = @import("EventLoop.zig");
const Pipeline = @import("Pipeline.zig");
const Editor = @import("editor/Editor.zig");
const icons = @import("icons.zig");

pipeline: Pipeline,
event_loop: EventLoop,
scene: Scene,
editor: Editor,
camera: Camera,

const Self = @This();

pub fn init(allocator: Allocator) Self {
    return .{
        .pipeline = .init(allocator),
        .scene = .init(allocator),
        .event_loop = .init(),
        .editor = undefined,
        .camera = .init(),
    };
}

pub fn deinit(self: *Self) void {
    self.editor.deinit();
    self.pipeline.deinit();
    self.scene.deinit();
}

/// Binds several part of the software together
pub fn bind(self: *Self) void {
    self.editor = .init(self.pipeline.device, self.pipeline.window);
    self.scene.createAlloc();
    self.scene.debug();
    self.event_loop.bind(&self.scene, &self.camera, &self.editor.viewport);

    icons.init(self.pipeline.device);
}

pub fn frame(self: *Self) !sdl.SDL_AppResult {
    return self.pipeline.frame(&self.scene, &self.camera, &self.editor, &self.event_loop);
}
