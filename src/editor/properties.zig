const c = @import("c");
const gui = c.gui;
const math = @import("../math.zig");
const m = math.zlm;
const Sdf = @import("../sdf.zig");
const Scene = @import("../Scene.zig");
const Texture = @import("../Texture.zig");
const icons = @import("../icons.zig");

const axis_labels = [3][*c]const u8{ "x", "y", "z" };
const axis_drag_ids = [3][*c]const u8{ "##x", "##y", "##z" };

const std = @import("std");
pub fn render(scene: *Scene, flags: gui.ImGuiWindowFlags) void {
    defer gui.ImGui_End();
    if (!gui.ImGui_Begin("Properties", null, flags)) return;

    const sdf = scene.getSelectedSdf() orelse return;
    const meta = scene.getSelectedSdfMeta() orelse return;

    var pos: m.Vec3 = sdf.getPos();
    vec3Edit("Transform", &pos, 0.05, 0, 0, "%.2f");

    vec3Edit("Rotation", &meta.rotation, 0.5, -360.0, 360.0, "%.1f");

    sdf.transform = m.Mat4.createAngleAxis(.unitX, m.toRadians(meta.rotation.x))
        .mul(.createAngleAxis(.unitY, m.toRadians(meta.rotation.y)))
        .mul(.createAngleAxis(.unitZ, m.toRadians(meta.rotation.z)))
        .transpose();

    sdf.transform.fields[3][0] = pos.x;
    sdf.transform.fields[3][1] = pos.y;
    sdf.transform.fields[3][2] = pos.z;

    scale(sdf);
    operations(sdf);
    material(sdf);
}

fn resetableDragFloat(id: [*c]const u8, prop: *f32, speed: f32, min: f32, max: f32, fmt: [*c]const u8, reset_val: f32) void {
    const reset_offset: f32 = if (prop.* != reset_val) 30 else 0;

    gui.ImGui_SetNextItemWidth(gui.ImGui_GetContentRegionAvail().x - reset_offset);
    _ = gui.ImGui_DragFloatEx(id, prop, speed, min, max, fmt, 0);

    if (reset_offset > 0) {
        gui.ImGui_PushID(id);
        defer gui.ImGui_PopID();

        gui.ImGui_SameLine();
        if (gui.ImGui_ImageButton("reset", icons.reset.toImGuiRef(), .{ .x = icons.size, .y = icons.size })) {
            prop.* = reset_val;
        }
    }
}

fn vec3Edit(id: [*c]const u8, v: *m.Vec3, speed: f32, v_min: f32, v_max: f32, fmt: [*c]const u8) void {
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
        resetableDragFloat(axis_drag_ids[i], components[i], speed, v_min, v_max, fmt, 0);
    }
}

fn scale(sdf: *Sdf.Sdf) void {
    gui.ImGui_SeparatorText("Scale");
    resetableDragFloat("##Scale", &sdf.scale, 0.01, 0.01, 100, "%.2f", 1);
}

fn operations(sdf: *Sdf.Sdf) void {
    gui.ImGui_SeparatorText("Operation");

    // If properties is openned, we have a selected SDF
    operation("union", icons.union_op, sdf, .union_op);
    gui.ImGui_SameLine();
    operation("subtract", icons.subtract_op, sdf, .subtract);
    gui.ImGui_SameLine();
    operation("intersect", icons.intersect_op, sdf, .intersect);

    gui.ImGui_AlignTextToFramePadding();
    gui.ImGui_Text("Smooth");
    gui.ImGui_SameLine();
    resetableDragFloat("##Smoothness", &sdf.smooth_factor, 0.005, 0, 4, "%.2f", 0.5);
}

fn operation(name: [*c]const u8, icon: Texture, sdf: *Sdf.Sdf, op: Sdf.Op) void {
    const tint: gui.ImVec4 = if (sdf.op == op)
        .{ .x = 0.078, .y = 0.565, .z = 0.549, .w = 1 }
    else
        math.guiVec4One;

    if (gui.ImGui_ImageButtonEx(
        name,
        icon.toImGuiRef(),
        .{ .x = icons.size, .y = icons.size },
        .{ .x = 0, .y = 0 },
        .{ .x = 1, .y = 1 },
        math.guiVec4Zero,
        tint,
    )) {
        sdf.op = op;
    }
}

var picker_openned: bool = false;

fn material(sdf: *Sdf.Sdf) void {
    gui.ImGui_SeparatorText("Material");

    if (!picker_openned) {
        if (gui.ImGui_ColorButton("##color", math.zlmToImGui(math.extendVec3(sdf.color, 1)), 0)) {
            picker_openned = true;
        }
    } else {
        if (gui.ImGui_ColorPicker3("picker", &sdf.color.x, 0)) {
            //
        }

        // if (!gui.ImGui_IsItemHovered(0) and gui.ImGui_IsMouseClickedEx(gui.ImGuiMouseButton_Left, false)) {
        if (!gui.ImGui_IsItemHovered(0)) {
            picker_openned = false;
        }
    }
}
