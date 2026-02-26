const std = @import("std");
const c = @import("c");
const gui = c.gui;
const theme = @import("theme.zig");
const globals = @import("../globals.zig");

const tfd = @cImport({
    @cInclude("tinyfiledialogs.h");
});

pub const id = "SavePopup";

const filter_patterns = [_][*c]const u8{"*.rfs"};

pub fn open() void {
    gui.ImGui_PushStyleColorImVec4(gui.ImGuiCol_Border, theme.bg_light);
    if (gui.ImGui_BeginPopup(id, 0)) {
        const res = tfd.tinyfd_saveFileDialog(
            "Save scene",
            "untitled.rfs",
            @intCast(filter_patterns.len),
            &filter_patterns,
            "RayForge Scene (*.rfs)",
        );

        if (res != null) {
            globals.scene.save(std.mem.span(res));
        }

        // Close the ImGui popup, tinyfd is blocking so this runs after the OS dialog closes
        gui.ImGui_CloseCurrentPopup();
        gui.ImGui_EndPopup();
    }

    gui.ImGui_PopStyleColor();
}
