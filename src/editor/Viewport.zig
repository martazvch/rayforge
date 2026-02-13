const std = @import("std");
const c = @import("c");
const gui = c.gui;
const m = @import("../math.zig").zlm;
const Rect = @import("../Rect.zig");
const globals = @import("../globals.zig");

rect: Rect,

const Self = @This();

pub fn init() Self {
    return .{
        .rect = .zero,
    };
}

pub fn setRect(self: *Self, rect: Rect) void {
    self.rect = rect;
}

pub fn render(self: *Self) void {
    const draw_list = gui.ImGui_GetBackgroundDrawList();
    const texture_ref: gui.ImTextureRef = .{
        ._TexData = null, // not used for user-defined texures
        ._TexID = @intFromPtr(globals.pipeline.viewport_texture.texture),
    };
    gui.ImDrawList_AddImage(
        draw_list,
        texture_ref,
        .{ .x = self.rect.pos.x, .y = self.rect.pos.y }, // top-left
        .{
            .x = self.rect.pos.x + self.rect.size.x,
            .y = self.rect.pos.y + self.rect.size.y,
        }, // bottom-right
    );

    globals.event_loop.setViewportState(gui.ImGui_IsWindowHovered(gui.ImGuiHoveredFlags_None));
}
