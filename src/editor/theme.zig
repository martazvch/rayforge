const std = @import("std");
const gui = @import("c").gui;

pub fn applyTheme() void {
    const style: *gui.ImGuiStyle_t = gui.ImGui_GetStyle();
    const colors = &style.Colors;

    // Palette
    const bg_very_dark = gui.ImVec4{ .x = 0.09, .y = 0.09, .z = 0.11, .w = 1.00 }; // #17171c
    const bg_dark = gui.ImVec4{ .x = 0.12, .y = 0.12, .z = 0.14, .w = 1.00 }; // #1e1e24
    const bg_medium = gui.ImVec4{ .x = 0.15, .y = 0.15, .z = 0.18, .w = 1.00 }; // #26262e
    const bg_light = gui.ImVec4{ .x = 0.18, .y = 0.18, .z = 0.22, .w = 1.00 }; // #2e2e38
    const border = gui.ImVec4{ .x = 0.25, .y = 0.25, .z = 0.30, .w = 1.00 }; // #40404d
    const text = gui.ImVec4{ .x = 0.85, .y = 0.85, .z = 0.88, .w = 1.00 }; // #d9d9e0
    const text_dim = gui.ImVec4{ .x = 0.55, .y = 0.55, .z = 0.60, .w = 1.00 }; // #8c8c99
    const accent_purple = gui.ImVec4{ .x = 0.58, .y = 0.44, .z = 0.86, .w = 1.00 }; // #9470db
    const accent_purple_dim = gui.ImVec4{ .x = 0.48, .y = 0.34, .z = 0.76, .w = 0.80 }; // #7a57c2
    const accent_blue = gui.ImVec4{ .x = 0.40, .y = 0.63, .z = 0.90, .w = 1.00 }; // #66a0e6

    // General configuration
    style.WindowPadding = gui.ImVec2{ .x = 12, .y = 12 };
    style.FramePadding = gui.ImVec2{ .x = 8, .y = 6 };
    style.CellPadding = gui.ImVec2{ .x = 6, .y = 4 };
    style.ItemSpacing = gui.ImVec2{ .x = 8, .y = 6 };
    style.ItemInnerSpacing = gui.ImVec2{ .x = 6, .y = 6 };
    style.TouchExtraPadding = gui.ImVec2{ .x = 0, .y = 0 };
    style.IndentSpacing = 20.0;
    style.ScrollbarSize = 14.0;
    style.GrabMinSize = 10.0;

    // Borders
    style.WindowBorderSize = 1.0;
    style.ChildBorderSize = 1.0;
    style.PopupBorderSize = 1.0;
    style.FrameBorderSize = 0.0;
    style.TabBorderSize = 0.0;

    // Roundings
    style.WindowRounding = 8.0;
    style.ChildRounding = 6.0;
    style.FrameRounding = 5.0;
    style.PopupRounding = 6.0;
    style.ScrollbarRounding = 9.0;
    style.GrabRounding = 5.0;
    style.LogSliderDeadzone = 4.0;
    style.TabRounding = 6.0;

    // Alignment
    style.WindowTitleAlign = gui.ImVec2{ .x = 0.50, .y = 0.50 };
    style.WindowMenuButtonPosition = gui.ImGuiDir_Left;
    style.ColorButtonPosition = gui.ImGuiDir_Right;
    style.ButtonTextAlign = gui.ImVec2{ .x = 0.50, .y = 0.50 };
    style.SelectableTextAlign = gui.ImVec2{ .x = 0.00, .y = 0.00 };

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
    colors[gui.ImGuiCol_BorderShadow] = gui.ImVec4{ .x = 0.00, .y = 0.00, .z = 0.00, .w = 0.00 };
    colors[gui.ImGuiCol_FrameBg] = bg_medium;
    colors[gui.ImGuiCol_FrameBgHovered] = bg_light;
    colors[gui.ImGuiCol_FrameBgActive] = gui.ImVec4{ .x = 0.20, .y = 0.20, .z = 0.25, .w = 1.00 };
    colors[gui.ImGuiCol_TitleBg] = bg_very_dark;
    colors[gui.ImGuiCol_TitleBgActive] = bg_dark;
    colors[gui.ImGuiCol_TitleBgCollapsed] = bg_very_dark;
    colors[gui.ImGuiCol_MenuBarBg] = bg_dark;
    colors[gui.ImGuiCol_ScrollbarBg] = bg_dark;
    colors[gui.ImGuiCol_ScrollbarGrab] = bg_light;
    colors[gui.ImGuiCol_ScrollbarGrabHovered] = gui.ImVec4{ .x = 0.25, .y = 0.25, .z = 0.30, .w = 1.00 };
    colors[gui.ImGuiCol_ScrollbarGrabActive] = accent_purple_dim;
    colors[gui.ImGuiCol_CheckMark] = accent_purple;
    colors[gui.ImGuiCol_SliderGrab] = accent_purple;
    colors[gui.ImGuiCol_SliderGrabActive] = accent_blue;
    colors[gui.ImGuiCol_Button] = bg_light;
    colors[gui.ImGuiCol_ButtonHovered] = gui.ImVec4{ .x = 0.22, .y = 0.22, .z = 0.28, .w = 1.00 };
    colors[gui.ImGuiCol_ButtonActive] = accent_purple_dim;
    colors[gui.ImGuiCol_Header] = bg_light;
    colors[gui.ImGuiCol_HeaderHovered] = gui.ImVec4{ .x = 0.25, .y = 0.25, .z = 0.32, .w = 1.00 };
    colors[gui.ImGuiCol_HeaderActive] = accent_purple_dim;
    colors[gui.ImGuiCol_Separator] = border;
    colors[gui.ImGuiCol_SeparatorHovered] = accent_purple_dim;
    colors[gui.ImGuiCol_SeparatorActive] = accent_purple;
    colors[gui.ImGuiCol_ResizeGrip] = bg_light;
    colors[gui.ImGuiCol_ResizeGripHovered] = accent_purple_dim;
    colors[gui.ImGuiCol_ResizeGripActive] = accent_purple;
    colors[gui.ImGuiCol_Tab] = bg_medium;
    colors[gui.ImGuiCol_TabHovered] = accent_purple_dim;
    colors[gui.ImGuiCol_TabActive] = bg_light;
    colors[gui.ImGuiCol_TabUnfocused] = bg_dark;
    colors[gui.ImGuiCol_TabUnfocusedActive] = bg_medium;
    colors[gui.ImGuiCol_DockingPreview] = accent_purple_dim;
    colors[gui.ImGuiCol_DockingEmptyBg] = bg_very_dark;
    colors[gui.ImGuiCol_PlotLines] = accent_blue;
    colors[gui.ImGuiCol_PlotLinesHovered] = accent_purple;
    colors[gui.ImGuiCol_PlotHistogram] = accent_purple;
    colors[gui.ImGuiCol_PlotHistogramHovered] = accent_blue;
    colors[gui.ImGuiCol_TableHeaderBg] = bg_medium;
    colors[gui.ImGuiCol_TableBorderStrong] = border;
    colors[gui.ImGuiCol_TableBorderLight] = gui.ImVec4{ .x = 0.20, .y = 0.20, .z = 0.25, .w = 1.00 };
    colors[gui.ImGuiCol_TableRowBg] = gui.ImVec4{ .x = 0.00, .y = 0.00, .z = 0.00, .w = 0.00 };
    colors[gui.ImGuiCol_TableRowBgAlt] = gui.ImVec4{ .x = 1.00, .y = 1.00, .z = 1.00, .w = 0.03 };
    colors[gui.ImGuiCol_TextSelectedBg] = accent_purple_dim;
    colors[gui.ImGuiCol_DragDropTarget] = accent_blue;
    colors[gui.ImGuiCol_NavHighlight] = accent_purple;
    colors[gui.ImGuiCol_NavWindowingHighlight] = accent_purple;
    colors[gui.ImGuiCol_NavWindowingDimBg] = gui.ImVec4{ .x = 0.20, .y = 0.20, .z = 0.20, .w = 0.50 };
    colors[gui.ImGuiCol_ModalWindowDimBg] = gui.ImVec4{ .x = 0.10, .y = 0.10, .z = 0.10, .w = 0.60 };
}

pub fn applyObsidianThemeLight() void {
    applyTheme();

    const style = gui.igGetStyle();
    const colors = &style.Colors;

    colors[gui.ImGuiCol_WindowBg] = gui.ImVec4{ .x = 0.14, .y = 0.14, .z = 0.16, .w = 1.00 };
    colors[gui.ImGuiCol_ChildBg] = gui.ImVec4{ .x = 0.17, .y = 0.17, .z = 0.20, .w = 1.00 };
    colors[gui.ImGuiCol_FrameBg] = gui.ImVec4{ .x = 0.20, .y = 0.20, .z = 0.24, .w = 1.00 };
}
