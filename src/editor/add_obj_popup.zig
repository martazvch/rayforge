const c = @import("c");
const gui = c.gui;
const theme = @import("theme.zig");
const icons = @import("../icons.zig");
const rayui = @import("../rayui.zig");
const sdf = @import("../sdf.zig");
const globals = @import("../globals.zig");

pub const id = "AddObjectPopup";

pub fn open() void {
    gui.ImGui_PushStyleColorImVec4(gui.ImGuiCol_Border, theme.bg_light);
    if (gui.ImGui_BeginPopup(id, 0)) {
        const items = .{
            .{ "Object", icons.object },
        };

        inline for (items) |item| {
            if (rayui.selectableIconLabel(item[0], item[1])) {
                globals.scene.addObject();
            }
        }

        gui.ImGui_Separator();

        const shapes = .{
            .{ "Sphere", icons.sphere, sdf.Kind.sphere },
            .{ "Box", icons.cube, sdf.Kind.box },
            .{ "Cylinder", icons.cylinder, sdf.Kind.cylinder },
            .{ "Torus", icons.torus, sdf.Kind.torus },
        };

        inline for (shapes) |item| {
            if (rayui.selectableIconLabel(item[0], item[1])) {
                globals.scene.addSdf(item[2]);
            }
        }

        gui.ImGui_EndPopup();
    }

    gui.ImGui_PopStyleColor();
}
