const c = @import("c");
const gui = c.gui;
const m = @import("../math.zig").math;
const Sdf = @import("../sdf.zig");
const Scene = @import("../Scene.zig");
const Texture = @import("../Texture.zig");
const icons = @import("../icons.zig");

const axis_labels = [3][*c]const u8{ "x", "y", "z" };
const axis_drag_ids = [3][*c]const u8{ "##x", "##y", "##z" };

pub fn render(scene: *Scene, flags: gui.ImGuiWindowFlags) void {
    defer gui.ImGui_End();
    if (!gui.ImGui_Begin("Properties", null, flags)) return;

    const sdf = scene.getSelectedSdf() orelse return;
    const obj = scene.getSelectedObj() orelse return;

    vec3Edit("Transform", &sdf.position, 0.05, 0, 0, "%.2f");
    vec3Edit("Scale", &obj.properties.scale, 0.05, 0.01, 100.0, "%.2f");
    vec3Edit("Rotation", &obj.properties.rotation, 0.5, -360.0, 360.0, "%.1f");

    operations(sdf);

    gui.ImGui_AlignTextToFramePadding();
    gui.ImGui_Text("Smooth");
    gui.ImGui_SameLine();
    _ = gui.ImGui_DragFloatEx("##Smoothness", &sdf.smooth_factor, 0.005, 0, 1, "%.2f", 0);
}

fn vec3Edit(id: [*c]const u8, v: *m.Vec3, speed: f32, v_min: f32, v_max: f32, fmt: [*:0]const u8) void {
    gui.ImGui_SeparatorText(id);

    gui.ImGui_PushID(id);
    defer gui.ImGui_PopID();

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

fn operations(sdf: *Sdf.Sdf) void {
    gui.ImGui_SeparatorText("Operation");

    // If properties is openned, we have a selected SDF
    operation("union", icons.union_op, sdf, .union_op);
    gui.ImGui_SameLine();
    operation("subtract", icons.subtract_op, sdf, .subtract);
    gui.ImGui_SameLine();
    operation("intersect", icons.intersect_op, sdf, .intersect);
}

fn operation(name: [*c]const u8, icon: Texture, sdf: *Sdf.Sdf, op: Sdf.Op) void {
    const tint: gui.ImVec4 = if (sdf.op == op)
        .{ .x = 0.078, .y = 0.565, .z = 0.549, .w = 1 }
    else
        .{ .x = 1, .y = 1, .z = 1, .w = 1 };

    if (gui.ImGui_ImageButtonEx(
        name,
        icon.toImGuiRef(),
        .{ .x = icons.size, .y = icons.size },
        .{ .x = 0, .y = 0 },
        .{ .x = 1, .y = 1 },
        .{ .x = 0, .y = 0, .z = 0, .w = 0 },
        tint,
    )) {
        sdf.op = op;
    }
}
