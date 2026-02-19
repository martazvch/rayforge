const gui = @import("c").gui;
const Texture = @import("Texture.zig");
const icons = @import("icons.zig");

pub fn separatorVert(height: f32, color: u32, thick: f32, padding: f32) void {
    var sep_pos = gui.ImGui_GetCursorScreenPos();
    sep_pos.x += padding;

    const draw_list = gui.ImGui_GetWindowDrawList();
    gui.ImDrawList_AddLineEx(
        draw_list,
        sep_pos,
        .{ .x = sep_pos.x, .y = sep_pos.y + height },
        color,
        thick,
    );
    // Advance cursor past the line
    gui.ImGui_Dummy(.{ .x = padding * 2, .y = 0 });
}

pub fn selectableIconLabel(label: [*c]const u8, icon: Texture) bool {
    gui.ImGui_PushID(label);
    defer gui.ImGui_PopID();

    const selected = gui.ImGui_SelectableEx("##hidden", false, 0, .{ .x = 0, .y = icons.size });
    gui.ImGui_SameLineEx(0, 0);
    gui.ImGui_Image(icon.toImGuiRef(), icons.size_vec);
    gui.ImGui_SameLine();
    gui.ImGui_Text(label);
    return selected;
}
