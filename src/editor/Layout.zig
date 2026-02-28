const std = @import("std");
const Allocator = std.mem.Allocator;
const c = @import("c");
const gui = c.gui;
const guiEx = c.guiEx;
const math = @import("../math.zig");
const rayUi = @import("../rayui.zig");
const Rect = @import("../Rect.zig");
const Scene = @import("../Scene.zig");
const SceneTree = @import("SceneTree.zig");
const Properties = @import("properties.zig");
const Viewport = @import("Viewport.zig");
const icons = @import("../icons.zig");
const sdf = @import("../sdf.zig");
const theme = @import("theme.zig");
const Set = @import("../set.zig").Set;
const globals = @import("../globals.zig");
const SavePopup = @import("save_popup.zig");
const TabBar = @import("TabBar.zig");
const ToolBar = @import("ToolBar.zig");
const oom = @import("../utils.zig").oom;

const STATUSBAR_HEIGHT: f32 = 22;
const DEFAULT_PROPERTIES_WIDTH: f32 = 200;
const DEFAULT_SCENE_WIDTH: f32 = 200;
const MIN_PANEL_WIDTH: f32 = 100;
const MIN_VIEWPORT_WIDTH: f32 = 200;
const MIN_PANEL_HEIGHT: f32 = 80;
const SPLITTER_THICKNESS: f32 = 4;

var menu_bar_height: f32 = 19;

// Resizable sizes (persisted across frames)
var total_panel_width: f32 = DEFAULT_PROPERTIES_WIDTH + DEFAULT_SCENE_WIDTH;
var properties_ratio: f32 = 0.5; // Properties takes 50% of panel width
var scene_height_ratio: f32 = 0.7;

// Splitter dragging state
var dragging_viewport_splitter: bool = false;
var dragging_panel_splitter: bool = false;
var dragging_horizontal_splitter: bool = false;

// Deferred popup open flags
// https://github.com/ocornut/imgui/issues/5684
var open_save_popup: bool = false;

tabbar: TabBar,
scene_tree: SceneTree,

const Self = @This();

pub fn init() Self {
    return .{
        .tabbar = .init(),
        .scene_tree = .init(),
    };
}

pub fn deinit(self: *Self) void {
    self.tabbar.deinit();
    self.scene_tree.deinit();
}

pub fn render(self: *Self, viewport: *Viewport) void {
    const vp = gui.ImGui_GetMainViewport();
    const work_pos = vp.*.WorkPos;
    const work_size = vp.*.WorkSize;

    var y_offset: f32 = work_pos.y;

    // Main Menu Bar (keep default spacing for menu items)
    if (gui.ImGui_BeginMainMenuBar()) {
        if (gui.ImGui_BeginMenu("File")) {
            globals.event_loop.on_menu = true;

            if (gui.ImGui_MenuItemEx("New", "Ctrl+N", false, true)) {}
            if (gui.ImGui_MenuItemEx("Open", "Ctrl+O", false, true)) {}
            if (gui.ImGui_MenuItemEx("Save", "Ctrl+S", false, true)) {
                open_save_popup = true;
            }
            gui.ImGui_Separator();
            if (gui.ImGui_MenuItemEx("Exit", "Alt+F4", false, true)) {}
            gui.ImGui_EndMenu();
        } else {
            globals.event_loop.on_menu = false;
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

    // Render popups outside the menu bar context
    if (open_save_popup) {
        gui.ImGui_OpenPopup(SavePopup.id, 0);
        open_save_popup = false;
    }
    SavePopup.open();

    // Calculate layout dimensions
    const viewport_width = work_size.x - total_panel_width;
    const properties_width = total_panel_width * properties_ratio;
    const scene_width = total_panel_width - properties_width;
    const status_y = work_pos.y + work_size.y - STATUSBAR_HEIGHT;
    const panel_y = y_offset;
    const panel_height = work_size.y;
    const scene_h = panel_height * scene_height_ratio;

    // Tab Bar
    y_offset += self.tabbar.render(.{ .x = work_pos.x, .y = y_offset });
    // Toolbar
    y_offset += ToolBar.render(.{ .x = work_pos.x, .y = y_offset });

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
    // TODO: investigate this 12 offset
    viewport.setRect(.{
        .pos = .{
            .x = work_pos.x,
            .y = y_offset + 12,
        },
        .size = .{
            .x = viewport_width,
            .y = status_y - y_offset - 12,
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
    Properties.render(panel_flags);

    // Scene panel
    panel_x = work_pos.x + viewport_width + properties_width;
    gui.ImGui_SetNextWindowPos(.{ .x = panel_x, .y = panel_y }, gui.ImGuiCond_Always);
    gui.ImGui_SetNextWindowSize(.{ .x = scene_width, .y = scene_h }, gui.ImGuiCond_Always);
    self.scene_tree.render(panel_flags);

    // Modifiers panel
    gui.ImGui_SetNextWindowPos(.{ .x = panel_x, .y = panel_y + scene_h }, gui.ImGuiCond_Always);
    gui.ImGui_SetNextWindowSize(.{ .x = scene_width, .y = panel_height - scene_h }, gui.ImGuiCond_Always);
    if (gui.ImGui_Begin("Modifiers", null, panel_flags)) {}
    gui.ImGui_End();

    // Handle splitters and draw borders
    handleSplitters(work_pos, work_size, viewport_width, properties_width, scene_width, panel_y, panel_height, scene_h);
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
        theme.border_color,
    );
    // Border: Properties | Scene (stop at bottom)
    gui.ImDrawList_AddLine(
        draw_list,
        .{ .x = work_pos.x + viewport_width + properties_width, .y = panel_y },
        .{ .x = work_pos.x + viewport_width + properties_width, .y = work_pos.y + work_size.y },
        theme.border_color,
    );
    // Border: Scene | Chunks (horizontal)
    gui.ImDrawList_AddLine(
        draw_list,
        .{ .x = work_pos.x + viewport_width + properties_width, .y = panel_y + scene_h },
        .{ .x = work_pos.x + work_size.x, .y = panel_y + scene_h },
        theme.border_color,
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
