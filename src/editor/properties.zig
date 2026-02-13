const c = @import("c");
const gui = c.gui;
const guiEx = c.guiEx;
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

    gui.ImGui_PushStyleVarImVec2(gui.ImGuiStyleVar_FramePadding, .{ .x = 0, .y = 0 });

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

    gui.ImGui_PopStyleVar();
}

fn resetableDragFloat(id: [*c]const u8, prop: *f32, speed: f32, min: f32, max: f32, fmt: [*c]const u8, reset_val: f32) void {
    const reset_offset: f32 = if (prop.* != reset_val) 30 else 0;

    gui.ImGui_SetNextItemWidth(gui.ImGui_GetContentRegionAvail().x - reset_offset);
    _ = gui.ImGui_DragFloatEx(id, prop, speed, min, max, fmt, 0);

    if (reset_offset > 0) {
        gui.ImGui_PushID(id);
        defer gui.ImGui_PopID();

        gui.ImGui_SameLine();
        if (gui.ImGui_ImageButton("reset", icons.reset.toImGuiRef(), icons.size_vec)) {
            prop.* = reset_val;
        }
    }
}

fn vec3Edit(id: [*c]const u8, v: *m.Vec3, speed: f32, v_min: f32, v_max: f32, fmt: [*c]const u8) void {
    if (!category(id)) return;

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
    if (!category("Scale")) return;
    resetableDragFloat("##Scale", &sdf.scale, 0.01, 0.01, 100, "%.2f", 1);
}

fn operations(sdf: *Sdf.Sdf) void {
    if (!category("Operation")) return;

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
        icons.size_vec,
        .{ .x = 0, .y = 0 },
        .{ .x = 1, .y = 1 },
        math.guiVec4Zero,
        tint,
    )) {
        sdf.op = op;
    }
}

var picker_openned: bool = false;

fn category(label: [*c]const u8) bool {
    gui.ImGui_Spacing();

    // Persistent open state (default: open)
    const id = gui.ImGui_GetID(label);
    const p_open = gui.ImGuiStorage_GetBoolRef(gui.ImGui_GetStateStorage(), id, true);

    const arrow_scale: f32 = 0.5;
    const font_size = gui.ImGui_GetFontSize();
    const arrow_space = font_size * arrow_scale + 4;

    // Full-width button with left padding for arrow, no background
    gui.ImGui_PushStyleVarImVec2(gui.ImGuiStyleVar_ButtonTextAlign, .{ .x = 0, .y = 0.5 });
    gui.ImGui_PushStyleVarImVec2(gui.ImGuiStyleVar_FramePadding, .{ .x = arrow_space, .y = 0 });
    gui.ImGui_PushStyleColorImVec4(gui.ImGuiCol_Button, math.guiVec4Zero);
    gui.ImGui_PushStyleColorImVec4(gui.ImGuiCol_ButtonHovered, math.guiVec4Zero);
    gui.ImGui_PushStyleColorImVec4(gui.ImGuiCol_ButtonActive, math.guiVec4Zero);

    if (gui.ImGui_ButtonEx(label, .{ .x = -std.math.floatMin(f32), .y = 0 })) {
        p_open.* = !p_open.*;
    }

    gui.ImGui_PopStyleColorEx(3);
    gui.ImGui_PopStyleVarEx(2);

    // Draw small arrow on the left (inside the button area)
    const rect_min = gui.ImGui_GetItemRectMin();
    const rect_max = gui.ImGui_GetItemRectMax();
    const arrow_pos: gui.ImVec2 = .{
        .x = rect_min.x - 6,
        .y = rect_min.y + (rect_max.y - rect_min.y - font_size * arrow_scale) / 2.0,
    };
    const dir: gui.ImGuiDir = if (p_open.*) gui.ImGuiDir_Down else gui.ImGuiDir_Right;
    guiEx.ImGui_RenderArrowEx(gui.ImGui_GetWindowDrawList(), arrow_pos, gui.ImGui_GetColorU32(gui.ImGuiCol_Text), dir, arrow_scale);

    return p_open.*;
}

fn material(sdf: *Sdf.Sdf) void {
    if (!category("Material")) return;

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
