const std = @import("std");
const gui = @import("c").gui;
const math = @import("../math.zig");

pub const bg_very_dark: gui.ImVec4 = .{ .x = 0.12, .y = 0.12, .z = 0.14, .w = 1.00 };
pub const bg_darker: gui.ImVec4 = .{ .x = 0.15, .y = 0.15, .z = 0.18, .w = 1.00 };
pub const bg_dark: gui.ImVec4 = .{ .x = 0.18, .y = 0.18, .z = 0.21, .w = 1.00 };
pub const bg_medium: gui.ImVec4 = .{ .x = 0.22, .y = 0.22, .z = 0.26, .w = 1.00 };
pub const bg_light: gui.ImVec4 = .{ .x = 0.26, .y = 0.26, .z = 0.31, .w = 1.00 };

pub const border: gui.ImVec4 = .{ .x = 0.25, .y = 0.25, .z = 0.30, .w = 1.00 }; // #40404d
pub const text: gui.ImVec4 = .{ .x = 0.85, .y = 0.85, .z = 0.88, .w = 1.00 }; // #d9d9e0
pub const text_dim: gui.ImVec4 = .{ .x = 0.55, .y = 0.55, .z = 0.60, .w = 1.00 }; // #8c8c99
pub const accent_purple: gui.ImVec4 = .{ .x = 0.58, .y = 0.44, .z = 0.86, .w = 1.00 }; // #9470db
pub const accent_purple_dim: gui.ImVec4 = .{ .x = 0.48, .y = 0.34, .z = 0.76, .w = 0.80 }; // #7a57c2
pub const accent_blue: gui.ImVec4 = .{ .x = 0.40, .y = 0.63, .z = 0.90, .w = 1.00 }; // #66a0e6

pub const border_color: u32 = 0xFF505050; // Gray border

pub fn applyTheme() void {
    const style: *gui.ImGuiStyle_t = gui.ImGui_GetStyle();
    const colors = &style.Colors;

    // General configuration
    style.WindowPadding = .{ .x = 12, .y = 12 };
    style.FramePadding = .{ .x = 4, .y = 2 };
    style.CellPadding = .{ .x = 6, .y = 4 };
    style.ItemSpacing = .{ .x = 8, .y = 6 };
    style.ItemInnerSpacing = .{ .x = 6, .y = 6 };
    style.TouchExtraPadding = .{ .x = 0, .y = 0 };
    style.IndentSpacing = 20;
    style.ScrollbarSize = 14;
    style.GrabMinSize = 10;

    // Borders
    style.WindowBorderSize = 0;
    style.ChildBorderSize = 0;
    style.PopupBorderSize = 1;
    style.FrameBorderSize = 0;
    style.TabBorderSize = 0;
    style.TabBarBorderSize = 0;

    // Roundings
    style.WindowRounding = 0;
    style.ChildRounding = 0;
    style.FrameRounding = 0;
    style.PopupRounding = 0;
    style.ScrollbarRounding = 9;
    style.GrabRounding = 5;
    style.LogSliderDeadzone = 4;
    style.TabRounding = 0;

    // Alignment
    style.WindowTitleAlign = .{ .x = 0.5, .y = 0.5 };
    style.WindowMenuButtonPosition = gui.ImGuiDir_Left;
    style.ColorButtonPosition = gui.ImGuiDir_Right;
    style.ButtonTextAlign = .{ .x = 0.5, .y = 0.5 };
    style.SelectableTextAlign = .{ .x = 0, .y = 0 };

    // Anti-aliasing
    style.AntiAliasedLines = true;
    style.AntiAliasedLinesUseTex = true;
    style.AntiAliasedFill = true;

    // Colors
    colors[gui.ImGuiCol_Text] = text;
    colors[gui.ImGuiCol_TextDisabled] = text_dim;
    colors[gui.ImGuiCol_WindowBg] = bg_dark;
    colors[gui.ImGuiCol_ChildBg] = bg_medium;
    colors[gui.ImGuiCol_PopupBg] = bg_dark;
    colors[gui.ImGuiCol_Border] = border;
    colors[gui.ImGuiCol_BorderShadow] = math.guiVec4Zero;
    colors[gui.ImGuiCol_FrameBg] = bg_medium;
    colors[gui.ImGuiCol_FrameBgHovered] = bg_light;
    colors[gui.ImGuiCol_FrameBgActive] = .{ .x = 0.2, .y = 0.2, .z = 0.25, .w = 1 };
    colors[gui.ImGuiCol_TitleBg] = bg_dark;
    colors[gui.ImGuiCol_TitleBgActive] = bg_dark;
    colors[gui.ImGuiCol_TitleBgCollapsed] = bg_medium;
    colors[gui.ImGuiCol_MenuBarBg] = bg_very_dark;
    colors[gui.ImGuiCol_ScrollbarBg] = bg_dark;
    colors[gui.ImGuiCol_ScrollbarGrab] = bg_light;
    colors[gui.ImGuiCol_ScrollbarGrabHovered] = .{ .x = 0.25, .y = 0.25, .z = 0.3, .w = 1 };
    colors[gui.ImGuiCol_ScrollbarGrabActive] = accent_purple_dim;
    colors[gui.ImGuiCol_CheckMark] = accent_purple;
    colors[gui.ImGuiCol_SliderGrab] = accent_purple;
    colors[gui.ImGuiCol_SliderGrabActive] = accent_blue;
    colors[gui.ImGuiCol_Button] = math.guiVec4Zero;
    colors[gui.ImGuiCol_ButtonHovered] = math.guiVec4Zero;
    colors[gui.ImGuiCol_ButtonActive] = math.guiVec4Zero;
    colors[gui.ImGuiCol_Header] = bg_light;
    colors[gui.ImGuiCol_HeaderHovered] = .{ .x = 0.25, .y = 0.25, .z = 0.32, .w = 1 };
    colors[gui.ImGuiCol_HeaderActive] = math.guiVec4Zero;
    colors[gui.ImGuiCol_Separator] = border;
    colors[gui.ImGuiCol_SeparatorHovered] = accent_purple_dim;
    colors[gui.ImGuiCol_SeparatorActive] = accent_purple;
    colors[gui.ImGuiCol_ResizeGrip] = bg_light;
    colors[gui.ImGuiCol_ResizeGripHovered] = accent_purple_dim;
    colors[gui.ImGuiCol_ResizeGripActive] = accent_purple;
    colors[gui.ImGuiCol_Tab] = bg_darker;
    colors[gui.ImGuiCol_TabHovered] = accent_purple_dim;
    colors[gui.ImGuiCol_TabActive] = bg_dark;
    colors[gui.ImGuiCol_TabUnfocused] = bg_darker;
    colors[gui.ImGuiCol_TabUnfocusedActive] = bg_medium;
    colors[gui.ImGuiCol_DockingPreview] = accent_purple_dim;
    colors[gui.ImGuiCol_DockingEmptyBg] = bg_very_dark;
    colors[gui.ImGuiCol_PlotLines] = accent_blue;
    colors[gui.ImGuiCol_PlotLinesHovered] = accent_purple;
    colors[gui.ImGuiCol_PlotHistogram] = accent_purple;
    colors[gui.ImGuiCol_PlotHistogramHovered] = accent_blue;
    colors[gui.ImGuiCol_TableHeaderBg] = bg_medium;
    colors[gui.ImGuiCol_TableBorderStrong] = border;
    colors[gui.ImGuiCol_TableBorderLight] = .{ .x = 0.2, .y = 0.2, .z = 0.25, .w = 1 };
    colors[gui.ImGuiCol_TableRowBg] = math.guiVec4Zero;
    colors[gui.ImGuiCol_TableRowBgAlt] = .{ .x = 1, .y = 1, .z = 1, .w = 0.03 };
    colors[gui.ImGuiCol_TextSelectedBg] = accent_purple_dim;
    colors[gui.ImGuiCol_DragDropTarget] = accent_blue;
    colors[gui.ImGuiCol_NavHighlight] = accent_purple;
    colors[gui.ImGuiCol_NavWindowingHighlight] = accent_purple;
    colors[gui.ImGuiCol_NavWindowingDimBg] = .{ .x = 0.2, .y = 0.2, .z = 0.2, .w = 0.5 };
    colors[gui.ImGuiCol_ModalWindowDimBg] = .{ .x = 0.1, .y = 0.1, .z = 0.1, .w = 0.6 };
}
