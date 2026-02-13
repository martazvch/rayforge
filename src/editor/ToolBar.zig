const c = @import("c");
const gui = c.gui;
const rayUi = @import("../rayui.zig");
const math = @import("../math.zig");
const tab_mod = @import("scene_tab.zig");
const sdf = @import("../sdf.zig");
const icons = @import("../icons.zig");
const Tab = tab_mod.Tab;
const Manager = tab_mod.Manager;
const theme = @import("theme.zig");
const globals = @import("../globals.zig");

const height: f32 = 20;

pub fn render(pos: gui.ImVec2) f32 {
    gui.ImGui_SetNextWindowPos(pos, gui.ImGuiCond_Always);
    gui.ImGui_SetNextWindowSize(
        .{ .x = globals.editor.viewport.rect.size.x, .y = height },
        gui.ImGuiCond_Always,
    );

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
        rayUi.separatorVert(height, theme.border_color, 2, 8);
        gui.ImGui_SameLine();

        // Shape buttons — draggable into viewport
        shapeButton("##Sphere", icons.sphere.toImGuiRef(), icons.size_vec, .sphere);
        gui.ImGui_SameLine();
        shapeButton("##Box", icons.cube.toImGuiRef(), icons.size_vec, .box);
        gui.ImGui_SameLine();
        shapeButton("##Cylinder", icons.cylinder.toImGuiRef(), icons.size_vec, .cylinder);
        gui.ImGui_SameLine();
        shapeButton("##Torus", icons.torus.toImGuiRef(), icons.size_vec, .torus);

        // Fullscreen toggle at far right
        gui.ImGui_SameLine();
        const avail = gui.ImGui_GetContentRegionAvail();
        const button_width: f32 = 32;
        gui.ImGui_SetCursorPosX(gui.ImGui_GetCursorPosX() + avail.x - button_width);
        if (gui.ImGui_ImageButton("##Fullscreen", icons.fullscreen.toImGuiRef(), icons.size_vec)) {
            // Toggle fullscreen
        }
    }
    gui.ImGui_End();
    gui.ImGui_PopStyleVarEx(2);

    return height;
}

fn shapeButton(id: [*c]const u8, icon: gui.ImTextureRef, size: gui.ImVec2, kind: sdf.Kind) void {
    _ = gui.ImGui_ImageButton(id, icon, size);

    if (gui.ImGui_BeginDragDropSource(0)) {
        _ = gui.ImGui_SetDragDropPayload("NEW_SHAPE", &kind, @sizeOf(sdf.Kind), 0);
        gui.ImGui_Image(icon, size);
        gui.ImGui_EndDragDropSource();
    }
}
