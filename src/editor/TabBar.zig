const c = @import("c");
const gui = c.gui;
const math = @import("../math.zig");
const theme = @import("theme.zig");
const globals = @import("../globals.zig");

const Self = @This();
const height: f32 = 26;

pub fn render(self: *Self, pos: gui.ImVec2) f32 {
    _ = self; // autofix
    {
        const tab_win_flags = gui.ImGuiWindowFlags_NoTitleBar |
            gui.ImGuiWindowFlags_NoResize |
            gui.ImGuiWindowFlags_NoMove |
            gui.ImGuiWindowFlags_NoScrollbar |
            gui.ImGuiWindowFlags_NoSavedSettings |
            gui.ImGuiWindowFlags_NoDocking;

        gui.ImGui_SetNextWindowPos(pos, gui.ImGuiCond_Always);
        gui.ImGui_SetNextWindowSize(
            .{ .x = globals.editor.viewport.rect.size.x, .y = height },
            gui.ImGuiCond_Always,
        );

        // Darker background + compact padding + allow small window
        gui.ImGui_PushStyleColorImVec4(gui.ImGuiCol_WindowBg, theme.bg_darker);
        gui.ImGui_PushStyleVarImVec2(gui.ImGuiStyleVar_WindowMinSize, .{ .x = 0, .y = 0 });
        gui.ImGui_PushStyleVarImVec2(gui.ImGuiStyleVar_WindowPadding, .{ .x = 0, .y = 2 });
        gui.ImGui_PushStyleVarImVec2(gui.ImGuiStyleVar_FramePadding, .{ .x = 8, .y = 1 });
        gui.ImGui_PushStyleVarImVec2(gui.ImGuiStyleVar_ItemInnerSpacing, .{ .x = 0, .y = 0 });

        if (gui.ImGui_Begin("##TabBar", null, tab_win_flags)) {
            if (gui.ImGui_BeginTabBar(
                "##SceneTabs",
                gui.ImGuiTabBarFlags_AutoSelectNewTabs | gui.ImGuiTabBarFlags_Reorderable | gui.ImGuiTabBarFlags_DrawSelectedOverline,
            )) {
                for (globals.editor.scenes.items, 0..) |scene, i| {
                    var open: bool = true;

                    gui.ImGui_PushIDInt(@intCast(i));
                    defer gui.ImGui_PopID();

                    if (gui.ImGui_BeginTabItem(@ptrCast(&scene.name), &open, 0)) {
                        if (globals.scene != scene) {
                            globals.editor.change_scene = scene;
                        }
                        gui.ImGui_EndTabItem();
                    }
                }

                // "+" button with no background
                gui.ImGui_PushStyleColorImVec4(gui.ImGuiCol_Tab, math.guiVec4Zero);
                if (gui.ImGui_TabItemButton("+", gui.ImGuiTabItemFlags_Trailing | gui.ImGuiTabItemFlags_NoTooltip)) {
                    globals.editor.change_scene = globals.editor.createScene();
                }
                gui.ImGui_PopStyleColor();
                gui.ImGui_EndTabBar();
            }
        }
        gui.ImGui_End();
        gui.ImGui_PopStyleColor();
        gui.ImGui_PopStyleVarEx(4);

        return height;
    }
}
