const std = @import("std");
const c = @import("c");
const gui = c.gui;
const Pipeline = @import("../Pipeline.zig");
const EventLoop = @import("../EventLoop.zig");

pub const ViewportBounds = struct {
    pos: gui.ImVec2,
    size: gui.ImVec2,
};

pub fn render(pipeline: *Pipeline, event_loop: *EventLoop) ?ViewportBounds {
    gui.ImGui_PushStyleVarImVec2(gui.ImGuiStyleVar_WindowPadding, .{ .x = 0, .y = 0 });

    var bounds: ?ViewportBounds = null;

    if (gui.ImGui_Begin("Viewport", null, gui.ImGuiWindowFlags_NoScrollbar | gui.ImGuiWindowFlags_NoScrollWithMouse)) {
        const content_size = gui.ImGui_GetContentRegionAvail();
        const window_pos = gui.ImGui_GetCursorScreenPos();

        const width: u32 = @max(1, @as(u32, @intFromFloat(content_size.x)));
        const height: u32 = @max(1, @as(u32, @intFromFloat(content_size.y)));

        // Resize viewport texture if needed
        if (width != pipeline.viewport_width or height != pipeline.viewport_height) {
            pipeline.resizeViewport(width, height);
        }

        // Display the render texture
        if (pipeline.getViewportTextureHandle()) |texture_handle| {
            gui.ImGui_Image(
                texture_handle,
                content_size,
                .{ .x = 0, .y = 0 }, // UV0
                .{ .x = 1, .y = 1 }, // UV1
                .{ .x = 1, .y = 1, .z = 1, .w = 1 }, // tint
                .{ .x = 0, .y = 0, .z = 0, .w = 0 }, // border
            );
        }

        // Track viewport focus for input handling
        const is_hovered = gui.ImGui_IsWindowHovered(gui.ImGuiHoveredFlags_None);
        const is_focused = gui.ImGui_IsWindowFocused(gui.ImGuiFocusedFlags_None);
        event_loop.setViewportState(is_hovered, is_focused);

        bounds = .{
            .pos = window_pos,
            .size = content_size,
        };
    }
    gui.ImGui_End();

    gui.ImGui_PopStyleVar(1);

    return bounds;
}
