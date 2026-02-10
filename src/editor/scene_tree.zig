const c = @import("c");
const gui = c.gui;
const math = @import("../math.zig");
const Scene = @import("../Scene.zig");
const icons = @import("../icons.zig");

pub fn render(scene: *Scene, flags: gui.ImGuiWindowFlags) void {
    if (gui.ImGui_Begin("Scene", null, flags)) {
        header(scene);
        nodes(scene);
    }
    gui.ImGui_End();
}

fn header(scene: *Scene) void {
    gui.ImGui_Text("Objects");
    gui.ImGui_SameLine();

    gui.ImGui_PushStyleColorImVec4(gui.ImGuiCol_Button, math.guiVec4Zero);
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
            scene.addObject("Sphere", .sphere, .new(1.0, 0.0, 0.0, 0.0));
        }
        if (gui.ImGui_MenuItem("Box")) {
            scene.addObject("Box", .box, .new(1.0, 1.0, 1.0, 0.0));
        }
        if (gui.ImGui_MenuItem("Cylinder")) {
            scene.addObject("Cylinder", .cylinder, .new(1.0, 1.0, 0.0, 0.0));
        }
        if (gui.ImGui_MenuItem("Torus")) {
            scene.addObject("Torus", .torus, .new(1.0, 0.3, 0.0, 0.0));
        }
        gui.ImGui_EndPopup();
    }

    gui.ImGui_Separator();
}

var renaming_index: ?usize = null;
var rename_just_started: bool = false;

fn nodes(scene: *Scene) void {
    // Standard height of framed widgets like InputText, Button, etc
    const frame_h = gui.ImGui_GetFrameHeight();
    const icon_sz: gui.ImVec2 = .{ .x = icons.size, .y = icons.size };
    const icon_v_offset = (frame_h - icons.size) / 2.0;

    for (0..scene.data.count) |i| {
        gui.ImGui_PushIDInt(@intCast(i));
        defer gui.ImGui_PopID();

        const sdf = &scene.data.sdfs[i];
        const obj = &scene.objects[i];

        const icon = switch (sdf.kind) {
            .sphere => icons.sphere,
            .box => icons.cube,
            .cylinder => icons.cylinder,
            .torus => icons.torus,
        };

        // Full-width Selectable for highlight + click
        const is_selected = scene.selected != null and scene.selected.? == i;
        // 0 means 'use allow available width' and allow overlap passes events to children
        if (gui.ImGui_SelectableEx(
            "",
            is_selected,
            gui.ImGuiSelectableFlags_AllowOverlap,
            .{ .x = 0, .y = frame_h },
        )) {
            scene.selected = i;
        }

        if (gui.ImGui_IsItemHovered(0) and gui.ImGui_IsMouseDoubleClicked(0)) {
            renaming_index = i;
            rename_just_started = true;
        }

        // Rewind cursor to draw on top of the Selectable
        gui.ImGui_SameLineEx(0, 0);
        const cursor_y = gui.ImGui_GetCursorPosY();

        // Shape icon — vertically centered
        gui.ImGui_SetCursorPosY(cursor_y + icon_v_offset);
        gui.ImGui_Image(icon.toImGuiRef(), icon_sz);

        // Reset Y for subsequent widgets
        gui.ImGui_SameLine();
        gui.ImGui_SetCursorPosY(cursor_y);

        // Name — text or InputText
        if (renaming_index != null and renaming_index.? == i) {
            const avail = gui.ImGui_GetContentRegionAvail().x;
            gui.ImGui_SetNextItemWidth(avail - icons.size);

            if (rename_just_started) {
                gui.ImGui_SetKeyboardFocusHere();
                rename_just_started = false;
            }

            if (gui.ImGui_InputText(
                "##name",
                &obj.name,
                obj.name.len,
                gui.ImGuiInputTextFlags_EnterReturnsTrue | gui.ImGuiInputTextFlags_AutoSelectAll,
            )) {
                renaming_index = null;
            }

            if (gui.ImGui_IsItemDeactivated()) {
                renaming_index = null;
            }
        } else {
            gui.ImGui_AlignTextToFramePadding();
            gui.ImGui_Text(@ptrCast(&obj.name));
        }

        // Eye toggle — right-aligned, no background, no frame padding
        gui.ImGui_SameLine();
        const content_max_x = gui.ImGui_GetWindowContentRegionMax().x;
        gui.ImGui_SetCursorPosX(content_max_x - icons.size);
        gui.ImGui_SetCursorPosY(cursor_y + icon_v_offset);

        gui.ImGui_PushStyleVarImVec2(gui.ImGuiStyleVar_FramePadding, .{ .x = 0, .y = 0 });
        gui.ImGui_PushStyleColorImVec4(gui.ImGuiCol_ButtonActive, .{ .x = 1, .y = 1, .z = 1, .w = 0.25 });

        const eye_icon = if (sdf.visible) icons.eye else icons.eye_closed;
        if (gui.ImGui_ImageButton("##eye", eye_icon.toImGuiRef(), icon_sz)) {
            sdf.visible = !sdf.visible;
        }

        gui.ImGui_PopStyleColor();
        gui.ImGui_PopStyleVar();
    }
}
