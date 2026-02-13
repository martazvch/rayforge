const std = @import("std");
const c = @import("c");
const gui = c.gui;
const guiEx = c.guiEx;
const rayUi = @import("../rayui.zig");
const Rect = @import("../Rect.zig");
const Scene = @import("../Scene.zig");
const SceneTree = @import("scene_tree.zig");
const Properties = @import("properties.zig");
const Viewport = @import("Viewport.zig");
const icons = @import("../icons.zig");
const sdf = @import("../sdf.zig");

const TOOLBAR_HEIGHT: f32 = 20;
const STATUSBAR_HEIGHT: f32 = 22;
const DEFAULT_PROPERTIES_WIDTH: f32 = 200;
const DEFAULT_SCENE_WIDTH: f32 = 200;
const MIN_PANEL_WIDTH: f32 = 100;
const MIN_VIEWPORT_WIDTH: f32 = 200;
const MIN_PANEL_HEIGHT: f32 = 80;
const SPLITTER_THICKNESS: f32 = 4;
const BORDER_COLOR: u32 = 0xFF505050; // Gray border

var menu_bar_height: f32 = 19;

// Resizable sizes (persisted across frames)
var total_panel_width: f32 = DEFAULT_PROPERTIES_WIDTH + DEFAULT_SCENE_WIDTH;
var properties_ratio: f32 = 0.5; // Properties takes 50% of panel width
var scene_height_ratio: f32 = 0.7;

// Splitter dragging state
var dragging_viewport_splitter: bool = false;
var dragging_panel_splitter: bool = false;
var dragging_horizontal_splitter: bool = false;

pub fn render(scene: *Scene, viewport: *Viewport) void {
    const vp = gui.ImGui_GetMainViewport();
    const work_pos = vp.*.WorkPos;
    const work_size = vp.*.WorkSize;
    const icon_size: gui.ImVec2 = .{ .x = icons.size, .y = icons.size };

    // Style: no rounding, no borders (we draw custom separators)
    gui.ImGui_PushStyleVar(gui.ImGuiStyleVar_WindowRounding, 0.0);
    gui.ImGui_PushStyleVar(gui.ImGuiStyleVar_FrameRounding, 0.0);
    gui.ImGui_PushStyleVar(gui.ImGuiStyleVar_ChildRounding, 0.0);
    gui.ImGui_PushStyleVar(gui.ImGuiStyleVar_WindowBorderSize, 0.0);

    var y_offset: f32 = work_pos.y;

    // Main Menu Bar (keep default spacing for menu items)
    if (gui.ImGui_BeginMainMenuBar()) {
        if (gui.ImGui_BeginMenu("File")) {
            if (gui.ImGui_MenuItemEx("New", "Ctrl+N", false, true)) {}
            if (gui.ImGui_MenuItemEx("Open", "Ctrl+O", false, true)) {}
            if (gui.ImGui_MenuItemEx("Save", "Ctrl+S", false, true)) {}
            gui.ImGui_Separator();
            if (gui.ImGui_MenuItemEx("Exit", "Alt+F4", false, true)) {}
            gui.ImGui_EndMenu();
        }
        if (gui.ImGui_BeginMenu("Edit")) {
            if (gui.ImGui_MenuItemEx("Undo", "Ctrl+Z", false, true)) {}
            if (gui.ImGui_MenuItemEx("Redo", "Ctrl+Y", false, true)) {}
            gui.ImGui_EndMenu();
        }
        if (gui.ImGui_BeginMenu("Animation")) {
            gui.ImGui_EndMenu();
        }
        if (gui.ImGui_BeginMenu("Render")) {
            gui.ImGui_EndMenu();
        }
        menu_bar_height = gui.ImGui_GetWindowHeight();
        gui.ImGui_EndMainMenuBar();
    }
    y_offset = menu_bar_height;

    // Calculate layout dimensions
    const viewport_width = work_size.x - total_panel_width;
    const properties_width = total_panel_width * properties_ratio;
    const scene_width = total_panel_width - properties_width;
    const status_y = work_pos.y + work_size.y - STATUSBAR_HEIGHT;
    const panel_y = y_offset;
    const panel_height = work_size.y;
    const scene_h = panel_height * scene_height_ratio;

    // Toolbar
    {
        gui.ImGui_SetNextWindowPos(.{ .x = work_pos.x, .y = y_offset }, gui.ImGuiCond_Always);
        gui.ImGui_SetNextWindowSize(.{ .x = viewport_width, .y = TOOLBAR_HEIGHT }, gui.ImGuiCond_Always);

        const toolbar_flags = gui.ImGuiWindowFlags_NoTitleBar |
            gui.ImGuiWindowFlags_NoResize |
            gui.ImGuiWindowFlags_NoMove |
            gui.ImGuiWindowFlags_NoScrollbar |
            gui.ImGuiWindowFlags_NoSavedSettings |
            gui.ImGuiWindowFlags_NoDocking;

        gui.ImGui_PushStyleVarImVec2(gui.ImGuiStyleVar_WindowPadding, .{ .x = 4, .y = 4 });
        gui.ImGui_PushStyleVarImVec2(gui.ImGuiStyleVar_ItemSpacing, .{ .x = 2, .y = 0 });
        // Transparent button background
        if (gui.ImGui_Begin("##Toolbar", null, toolbar_flags)) {
            // Zoom buttons
            if (gui.ImGui_Button("+")) {}
            gui.ImGui_SameLine();
            if (gui.ImGui_Button("-")) {}

            // Vertical separator with spacing
            gui.ImGui_SameLine();
            rayUi.separatorVert(TOOLBAR_HEIGHT, BORDER_COLOR, 2, 8);
            gui.ImGui_SameLine();

            // Shape buttons — draggable into viewport
            shapeButton("##Sphere", icons.sphere.toImGuiRef(), icon_size, .sphere);
            gui.ImGui_SameLine();
            shapeButton("##Box", icons.cube.toImGuiRef(), icon_size, .box);
            gui.ImGui_SameLine();
            shapeButton("##Cylinder", icons.cylinder.toImGuiRef(), icon_size, .cylinder);
            gui.ImGui_SameLine();
            shapeButton("##Torus", icons.torus.toImGuiRef(), icon_size, .torus);

            // Fullscreen toggle at far right
            gui.ImGui_SameLine();
            const avail = gui.ImGui_GetContentRegionAvail();
            const button_width: f32 = 32;
            gui.ImGui_SetCursorPosX(gui.ImGui_GetCursorPosX() + avail.x - button_width);
            if (gui.ImGui_ImageButton("##Fullscreen", icons.fullscreen.toImGuiRef(), icon_size)) {
                // Toggle fullscreen
            }
        }
        gui.ImGui_End();
        gui.ImGui_PopStyleVarEx(2);
    }

    // Status Bar
    {
        gui.ImGui_SetNextWindowPos(.{ .x = work_pos.x, .y = status_y }, gui.ImGuiCond_Always);
        gui.ImGui_SetNextWindowSize(.{ .x = viewport_width, .y = STATUSBAR_HEIGHT }, gui.ImGuiCond_Always);

        const status_flags = gui.ImGuiWindowFlags_NoTitleBar |
            gui.ImGuiWindowFlags_NoResize |
            gui.ImGuiWindowFlags_NoMove |
            gui.ImGuiWindowFlags_NoScrollbar |
            gui.ImGuiWindowFlags_NoSavedSettings |
            gui.ImGuiWindowFlags_NoDocking;

        gui.ImGui_PushStyleVarImVec2(gui.ImGuiStyleVar_WindowPadding, .{ .x = 8, .y = 3 });
        if (gui.ImGui_Begin("##StatusBar", null, status_flags)) {
            gui.ImGui_Text("Ready");
            gui.ImGui_SameLine();
            gui.ImGui_Text("FPS: %.1f", gui.ImGui_GetIO().*.Framerate);
        }
        gui.ImGui_End();
        gui.ImGui_PopStyleVar();
    }

    // Viewport region
    viewport.setRect(.{
        .pos = .{
            .x = work_pos.x,
            .y = y_offset + TOOLBAR_HEIGHT,
        },
        .size = .{
            .x = viewport_width,
            .y = status_y - (y_offset + TOOLBAR_HEIGHT),
        },
    });

    // Right panels with borders
    const panel_flags = gui.ImGuiWindowFlags_NoResize |
        gui.ImGuiWindowFlags_NoMove |
        gui.ImGuiWindowFlags_NoSavedSettings |
        gui.ImGuiWindowFlags_NoDocking |
        gui.ImGuiWindowFlags_NoCollapse;

    // Properties panel
    var panel_x = work_pos.x + viewport_width;
    gui.ImGui_SetNextWindowPos(.{ .x = panel_x, .y = panel_y }, gui.ImGuiCond_Always);
    gui.ImGui_SetNextWindowSize(.{ .x = properties_width, .y = panel_height }, gui.ImGuiCond_Always);
    Properties.render(scene, panel_flags);

    // Scene panel
    panel_x = work_pos.x + viewport_width + properties_width;
    gui.ImGui_SetNextWindowPos(.{ .x = panel_x, .y = panel_y }, gui.ImGuiCond_Always);
    gui.ImGui_SetNextWindowSize(.{ .x = scene_width, .y = scene_h }, gui.ImGuiCond_Always);
    SceneTree.render(scene, panel_flags);

    // Chunks panel
    gui.ImGui_SetNextWindowPos(.{ .x = panel_x, .y = panel_y + scene_h }, gui.ImGuiCond_Always);
    gui.ImGui_SetNextWindowSize(.{ .x = scene_width, .y = panel_height - scene_h }, gui.ImGuiCond_Always);
    if (gui.ImGui_Begin("Modifiers", null, panel_flags)) {}
    gui.ImGui_End();

    // Handle splitters and draw borders
    handleSplitters(work_pos, work_size, viewport_width, properties_width, scene_width, panel_y, panel_height, scene_h);

    // Pop the 4 main style vars
    gui.ImGui_PopStyleVarEx(4);
}

fn handleSplitters(work_pos: gui.ImVec2, work_size: gui.ImVec2, viewport_width: f32, properties_width: f32, scene_width: f32, panel_y: f32, panel_height: f32, scene_h: f32) void {
    const mouse_pos = gui.ImGui_GetMousePos();
    const mouse_down = gui.ImGui_IsMouseDown(gui.ImGuiMouseButton_Left);
    const draw_list = gui.ImGui_GetForegroundDrawList();

    // Don't start a new splitter drag if an ImGui widget is already active (e.g. DragFloat)
    const imgui_active = gui.ImGui_IsAnyItemActive();

    // Draw borders between panels
    // Border: Viewport | Properties
    gui.ImDrawList_AddLine(
        draw_list,
        .{ .x = work_pos.x + viewport_width, .y = panel_y },
        .{ .x = work_pos.x + viewport_width, .y = work_pos.y + work_size.y },
        BORDER_COLOR,
    );
    // Border: Properties | Scene (stop at bottom)
    gui.ImDrawList_AddLine(
        draw_list,
        .{ .x = work_pos.x + viewport_width + properties_width, .y = panel_y },
        .{ .x = work_pos.x + viewport_width + properties_width, .y = work_pos.y + work_size.y },
        BORDER_COLOR,
    );
    // Border: Scene | Chunks (horizontal)
    gui.ImDrawList_AddLine(
        draw_list,
        .{ .x = work_pos.x + viewport_width + properties_width, .y = panel_y + scene_h },
        .{ .x = work_pos.x + work_size.x, .y = panel_y + scene_h },
        BORDER_COLOR,
    );

    // === Splitter: Viewport | Properties ===
    const vp_splitter_x = work_pos.x + viewport_width;
    const vp_splitter_min = gui.ImVec2{ .x = vp_splitter_x - SPLITTER_THICKNESS / 2, .y = panel_y };
    const vp_splitter_max = gui.ImVec2{ .x = vp_splitter_x + SPLITTER_THICKNESS / 2, .y = panel_y + panel_height };

    const vp_hovered = mouse_pos.x >= vp_splitter_min.x and mouse_pos.x <= vp_splitter_max.x and
        mouse_pos.y >= vp_splitter_min.y and mouse_pos.y <= vp_splitter_max.y;

    if (vp_hovered and mouse_down and !imgui_active and !dragging_panel_splitter and !dragging_horizontal_splitter) {
        dragging_viewport_splitter = true;
    }
    if (!mouse_down) dragging_viewport_splitter = false;

    if (dragging_viewport_splitter) {
        const new_viewport_width = mouse_pos.x - work_pos.x;
        const new_panel_width = work_size.x - new_viewport_width;
        if (new_viewport_width >= MIN_VIEWPORT_WIDTH and new_panel_width >= MIN_PANEL_WIDTH * 2) {
            total_panel_width = new_panel_width;
        }
        gui.ImGui_SetMouseCursor(gui.ImGuiMouseCursor_ResizeEW);
    } else if (vp_hovered) {
        gui.ImGui_SetMouseCursor(gui.ImGuiMouseCursor_ResizeEW);
    }

    // === Splitter: Properties | Scene ===
    const ps_splitter_x = work_pos.x + viewport_width + properties_width;
    const ps_splitter_min = gui.ImVec2{ .x = ps_splitter_x - SPLITTER_THICKNESS / 2, .y = panel_y };
    const ps_splitter_max = gui.ImVec2{ .x = ps_splitter_x + SPLITTER_THICKNESS / 2, .y = panel_y + panel_height };

    const ps_hovered = mouse_pos.x >= ps_splitter_min.x and mouse_pos.x <= ps_splitter_max.x and
        mouse_pos.y >= ps_splitter_min.y and mouse_pos.y <= ps_splitter_max.y;

    if (ps_hovered and mouse_down and !imgui_active and !dragging_viewport_splitter and !dragging_horizontal_splitter) {
        dragging_panel_splitter = true;
    }
    if (!mouse_down) dragging_panel_splitter = false;

    if (dragging_panel_splitter) {
        const new_props_width = mouse_pos.x - (work_pos.x + viewport_width);
        const ratio = new_props_width / total_panel_width;
        properties_ratio = @max(0.2, @min(ratio, 0.8)); // Keep between 20% and 80%
        gui.ImGui_SetMouseCursor(gui.ImGuiMouseCursor_ResizeEW);
    } else if (ps_hovered) {
        gui.ImGui_SetMouseCursor(gui.ImGuiMouseCursor_ResizeEW);
    }

    // === Splitter: Scene | Chunks (horizontal) ===
    const h_splitter_y = panel_y + scene_h;
    const h_splitter_x = work_pos.x + viewport_width + properties_width;
    const h_splitter_min = gui.ImVec2{ .x = h_splitter_x, .y = h_splitter_y - SPLITTER_THICKNESS / 2 };
    const h_splitter_max = gui.ImVec2{ .x = h_splitter_x + scene_width, .y = h_splitter_y + SPLITTER_THICKNESS / 2 };

    const h_hovered = mouse_pos.x >= h_splitter_min.x and mouse_pos.x <= h_splitter_max.x and
        mouse_pos.y >= h_splitter_min.y and mouse_pos.y <= h_splitter_max.y;

    if (h_hovered and mouse_down and !imgui_active and !dragging_viewport_splitter and !dragging_panel_splitter) {
        dragging_horizontal_splitter = true;
    }
    if (!mouse_down) dragging_horizontal_splitter = false;

    if (dragging_horizontal_splitter) {
        const new_scene_h = mouse_pos.y - panel_y;
        scene_height_ratio = @max(0.2, @min(new_scene_h / panel_height, 0.8));
        gui.ImGui_SetMouseCursor(gui.ImGuiMouseCursor_ResizeNS);
    } else if (h_hovered) {
        gui.ImGui_SetMouseCursor(gui.ImGuiMouseCursor_ResizeNS);
        // gui.ImDrawList_AddRectFilled(draw_list, h_splitter_min, h_splitter_max, 0x40FFFFFF);
    }
}

fn shapeButton(id: [*c]const u8, icon: gui.ImTextureRef, size: gui.ImVec2, kind: sdf.Kind) void {
    _ = gui.ImGui_ImageButton(id, icon, size);

    if (gui.ImGui_BeginDragDropSource(0)) {
        _ = gui.ImGui_SetDragDropPayload("NEW_SHAPE", &kind, @sizeOf(sdf.Kind), 0);
        gui.ImGui_Image(icon, size);
        gui.ImGui_EndDragDropSource();
    }
}
