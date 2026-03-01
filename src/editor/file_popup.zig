const std = @import("std");
const c = @import("c");
const gui = c.gui;
const theme = @import("theme.zig");
const globals = @import("../globals.zig");

const tfd = @cImport({
    @cInclude("tinyfiledialogs.h");
});

pub const open_id = "SavePopup";
pub const load_id = "LoadPopup";

const filter_patterns = [_][*c]const u8{"*.rfs"};

pub fn openSave() void {
    gui.ImGui_PushStyleColorImVec4(gui.ImGuiCol_Border, theme.bg_light);
    if (gui.ImGui_BeginPopup(open_id, 0)) {
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

pub fn openLoad() void {
    gui.ImGui_PushStyleColorImVec4(gui.ImGuiCol_Border, theme.bg_light);
    if (gui.ImGui_BeginPopup(load_id, 0)) {
        const res = tfd.tinyfd_openFileDialog(
            "Load scene",
            null,
            @intCast(filter_patterns.len),
            &filter_patterns,
            "RayForge Scene (*.rfs)",
            @intFromBool(false),
        );

        if (res != null) {
            globals.scene.load(std.mem.span(res));
        }

        // Close the ImGui popup, tinyfd is blocking so this runs after the OS dialog closes
        gui.ImGui_CloseCurrentPopup();
        gui.ImGui_EndPopup();
    }

    gui.ImGui_PopStyleColor();
}
