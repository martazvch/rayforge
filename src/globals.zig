const std = @import("std");
const Allocator = std.mem.Allocator;
const c = @import("c");
const sdl = c.sdl;
const Camera = @import("Camera.zig");
const Scene = @import("Scene.zig");
const EventLoop = @import("EventLoop.zig");
const Pipeline = @import("Pipeline.zig");
const Editor = @import("editor/Editor.zig");

pub var allocator: Allocator = undefined;
pub var window: *sdl.SDL_Window = undefined;
pub var device: *sdl.SDL_GPUDevice = undefined;

pub var pipeline: Pipeline = undefined;
pub var event_loop: EventLoop = undefined;
pub var scene: Scene = undefined;
pub var editor: Editor = undefined;
pub var camera: Camera = undefined;

pub fn init(alloc: Allocator) void {
    allocator = alloc;
    pipeline = .init(alloc);
    scene = .init(alloc);
    scene.postInit();
    scene.debug();
    event_loop = .init();
    editor = .init();
    camera = .init();
}

pub fn deinit() void {
    editor.deinit();
    pipeline.deinit();
    scene.deinit();
}
