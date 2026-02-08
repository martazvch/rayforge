pub const sdl = @cImport({
    @cDefine("SDL_MAIN_HANDLED", {});
    @cInclude("SDL3/SDL.h");
    @cInclude("SDL3/SDL_main.h");
});

pub const img = @cImport({
    @cDefine("STB_IMAGE_IMPLEMENTATION", {});
    @cDefine("STBI_ONLY_PNG", {});
    @cInclude("stb_image.h");
});

pub const gui = @cImport({
    @cInclude("dcimgui/dcimgui.h");
    @cInclude("dcimgui/dcimgui_impl_sdl3.h");
    @cInclude("dcimgui/dcimgui_impl_sdl3gpu.h");
});

// Manual declarations for DockBuilder (these are C functions in dcimgui)
// Due to incomplete opaque type in `dcimgui_internal.h`, we have to declare them manually
// All of those definitions have been greped in ImGUI source files
pub const guiEx = struct {
    pub extern fn ImGui_DockBuilderRemoveNode(node_id: gui.ImGuiID) void;
    pub extern fn ImGui_DockBuilderAddNodeEx(node_id: gui.ImGuiID, flags: gui.ImGuiDockNodeFlags) gui.ImGuiID;
    pub extern fn ImGui_DockBuilderSetNodeSize(node_id: gui.ImGuiID, size: gui.ImVec2) void;
    pub extern fn ImGui_DockBuilderSplitNode(node_id: gui.ImGuiID, split_dir: gui.ImGuiDir, size_ratio: f32, out_id_at_dir: *gui.ImGuiID, out_id_at_opposite_dir: *gui.ImGuiID) gui.ImGuiID;
    pub extern fn ImGui_DockBuilderDockWindow(window_name: [*:0]const u8, node_id: gui.ImGuiID) void;
    pub extern fn ImGui_DockBuilderFinish(node_id: gui.ImGuiID) void;

    pub const ImGuiDockNodeFlags_DockSpace = 1 >> 10;
};
