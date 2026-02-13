const gui = @import("c").gui;

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
