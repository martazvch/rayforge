const c = @import("c");
const gui = c.gui;
const m = @import("../math.zig").math;
const Scene = @import("../Scene.zig");

const axis_labels = [3][*c]const u8{ "x", "y", "z" };
const axis_drag_ids = [3][*c]const u8{ "##x", "##y", "##z" };

pub fn render(scene: *Scene, flags: gui.ImGuiWindowFlags) void {
    defer gui.ImGui_End();
    if (!gui.ImGui_Begin("Properties", null, flags)) return;

    const sdf = scene.getSelectedSdf() orelse return;
    const obj = scene.getSelectedObj() orelse return;

    gui.ImGui_SeparatorText("Transform");
    vec3Edit("transform", &sdf.position, 0.05, 0, 0, "%.2f");

    gui.ImGui_SeparatorText("Scale");
    vec3Edit("scale", &obj.properties.scale, 0.05, 0.01, 100.0, "%.2f");

    gui.ImGui_SeparatorText("Rotation");
    vec3Edit("rotation", &obj.properties.rotation, 0.5, -360.0, 360.0, "%.1f");
}

fn vec3Edit(id: [*:0]const u8, v: *m.Vec3, speed: f32, v_min: f32, v_max: f32, fmt: [*:0]const u8) void {
    gui.ImGui_PushID(id);
    defer gui.ImGui_PopID();

    gui.ImGui_PushStyleVarImVec2(gui.ImGuiStyleVar_FramePadding, .{ .x = 4, .y = 2 });
    defer gui.ImGui_PopStyleVar();

    const components: [3]*f32 = .{ &v.x, &v.y, &v.z };

    for (0..3) |i| {
        gui.ImGui_PushIDInt(@intCast(i));
        defer gui.ImGui_PopID();

        gui.ImGui_AlignTextToFramePadding();
        gui.ImGui_Text(axis_labels[i]);

        gui.ImGui_SameLine();
        gui.ImGui_SetNextItemWidth(gui.ImGui_GetContentRegionAvail().x);
        _ = gui.ImGui_DragFloatEx(axis_drag_ids[i], components[i], speed, v_min, v_max, fmt, 0);
    }
}
