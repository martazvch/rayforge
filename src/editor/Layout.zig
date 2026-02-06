const std = @import("std");
const c = @import("c");
const gui = c.gui;
const guiEx = c.guiEx;

var first_time: bool = true;

pub fn renderDockSpace() void {
    // Gets the main viewport (OS window)
    const viewport = gui.ImGui_GetMainViewport();

    // Creates a full-screen invisible window

    // Sets the next window's position to WorkPos (top-left of usable area, excluding OS taskbar)
    // ImGuiCond_Always = apply this every frame
    // {.x=0, .y=0} = pivot point (0,0 = top-left corner of window aligns with position)
    gui.ImGui_SetNextWindowPosEx(viewport.*.WorkPos, gui.ImGuiCond_Always, .{ .x = 0, .y = 0 });
    // Sets size to fill the entire viewport (WorkSize = usable area)
    gui.ImGui_SetNextWindowSize(viewport.*.WorkSize, gui.ImGuiCond_Always);
    // Binds this window to the main viewport (important for multi-viewport setups)
    gui.ImGui_SetNextWindowViewport(viewport.*.ID);

    // Make it invisible, just a container
    gui.ImGui_PushStyleVar(gui.ImGuiStyleVar_WindowRounding, 0.0);
    gui.ImGui_PushStyleVar(gui.ImGuiStyleVar_WindowBorderSize, 0.0);
    gui.ImGui_PushStyleVarImVec2(gui.ImGuiStyleVar_WindowPadding, .{ .x = 0, .y = 0 });

    // Window flags to make it invisible and non-interactive
    const window_flags = gui.ImGuiWindowFlags_MenuBar |
        gui.ImGuiWindowFlags_NoDocking | // can't dock other windows into this one
        gui.ImGuiWindowFlags_NoTitleBar |
        gui.ImGuiWindowFlags_NoCollapse |
        gui.ImGuiWindowFlags_NoResize |
        gui.ImGuiWindowFlags_NoMove |
        gui.ImGuiWindowFlags_NoBringToFrontOnFocus |
        gui.ImGuiWindowFlags_NoNavFocus |
        gui.ImGuiWindowFlags_NoBackground;

    // Creates and show the window, `null` for no close button
    _ = gui.ImGui_Begin("DockSpaceWindow", null, window_flags);
    // Pop the 3 style vars we pushed earlier
    gui.ImGui_PopStyleVarEx(3);

    // Creates a unique ID from string
    const dockspace_id = gui.ImGui_GetID("MainDockSpace");

    // Setup default layout on first run
    if (first_time) {
        first_time = false;
        setupDefaultLayout(dockspace_id);
    }

    // Creates the actual dockspace inside the host window
    // {.x=0, .y=0} = size (0,0 means "fill available space")
    // Other windows can now dock into this area
    _ = gui.ImGui_DockSpaceEx(dockspace_id, .{ .x = 0, .y = 0 }, gui.ImGuiDockNodeFlags_None, null);
    gui.ImGui_End();
}

fn setupDefaultLayout(dockspace_id: gui.ImGuiID) void {
    // Clears any existing layout for this dockspace (from imgui.ini or previous runs)
    _ = guiEx.ImGui_DockBuilderRemoveNode(dockspace_id);
    // Creates a new empty dock node with the given ID, mark it as a dockspace, not a floatting window
    _ = guiEx.ImGui_DockBuilderAddNodeEx(dockspace_id, guiEx.ImGuiDockNodeFlags_DockSpace);

    const viewport = gui.ImGui_GetMainViewport();
    _ = guiEx.ImGui_DockBuilderSetNodeSize(dockspace_id, viewport.*.WorkSize);

    // Split: left (viewport 70%) | right (panels 30%)
    var dock_left: gui.ImGuiID = undefined;
    var dock_right: gui.ImGuiID = undefined;
    _ = guiEx.ImGui_DockBuilderSplitNode(dockspace_id, gui.ImGuiDir_Left, 0.7, &dock_left, &dock_right);

    // Split right: top (scene tree) | bottom (properties)
    var dock_right_top: gui.ImGuiID = undefined;
    var dock_right_bottom: gui.ImGuiID = undefined;
    _ = guiEx.ImGui_DockBuilderSplitNode(dock_right, gui.ImGuiDir_Up, 0.5, &dock_right_top, &dock_right_bottom);

    // Dock windows
    _ = guiEx.ImGui_DockBuilderDockWindow("Viewport", dock_left);
    _ = guiEx.ImGui_DockBuilderDockWindow("Scene Tree", dock_right_top);
    _ = guiEx.ImGui_DockBuilderDockWindow("Properties", dock_right_bottom);

    guiEx.ImGui_DockBuilderFinish(dockspace_id);
}
