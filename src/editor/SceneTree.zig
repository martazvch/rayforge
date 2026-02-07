const std = @import("std");
const gui = @import("c").gui;
const Scene = @import("../Scene.zig");
const Layout = @import("Layout.zig");

pub fn render(scene: *const Scene, flags: gui.ImGuiWindowFlags) void {
    _ = scene; // autofix
    if (gui.ImGui_Begin("Scene", null, flags)) {
        // "Add" button at top
        // gui.ImGui_PushStyleVar(gui.ImGuiTextFlags, val: f32)
        gui.ImGui_Text("Objects");
        gui.ImGui_SameLine();

        gui.ImGui_PushStyleColorImVec4(gui.ImGuiCol_Button, .{ .x = 0, .y = 0, .z = 0, .w = 0 });
        if (gui.ImGui_Button("+")) {
            gui.ImGui_OpenPopup("AddObjectPopup", 0);
        }
        gui.ImGui_SameLine();
        if (gui.ImGui_Button("-")) {
            //
        }
        gui.ImGui_SameLine();
        if (gui.ImGui_Button("v")) {
            //
        }
        gui.ImGui_SameLine();
        if (gui.ImGui_Button("^")) {
            //
        }
        gui.ImGui_PopStyleColor();

        if (gui.ImGui_BeginPopup("AddObjectPopup", 0)) {
            if (gui.ImGui_MenuItem("Sphere")) {
                // addObject(scene, .sphere, "Sphere");
            }
            if (gui.ImGui_MenuItem("Box")) {
                // addObject(scene, .box, "Box");
            }
            if (gui.ImGui_MenuItem("Torus")) {
                // addObject(scene, .torus, "Torus");
            }
            if (gui.ImGui_MenuItem("Cylinder")) {
                // addObject(scene, .cylinder, "Cylinder");
            }
            gui.ImGui_EndPopup();
        }

        gui.ImGui_Separator();

        // Render root-level objects (parent_index == null)
        // renderChildren(scene, null, 0);
    }
    gui.ImGui_End();
}
