const std = @import("std");
const c = @import("c");
const sdl = c.sdl;
const gui = c.gui;
const theme = @import("theme.zig");
const State = @import("State.zig");
const Layout = @import("Layout.zig");
const fatal = @import("../utils.zig").fatal;

imio: *gui.ImGuiIO,
state: State,

const Self = @This();

pub fn init(device: ?*sdl.SDL_GPUDevice, window: ?*sdl.SDL_Window) Self {
    _ = gui.CIMGUI_CHECKVERSION();
    _ = gui.ImGui_CreateContext(null);

    const imio = gui.ImGui_GetIO();
    imio.*.ConfigFlags = gui.ImGuiConfigFlags_NavEnableKeyboard;
    imio.*.ConfigFlags = gui.ImGuiConfigFlags_DockingEnable;

    if (!gui.cImGui_ImplSDL3_InitForSDLGPU(@ptrCast(window))) {
        fatal("failed to initialize ImGUI window", .{});
    }

    theme.applyTheme();

    var init_info: gui.struct_ImGui_ImplSDLGPU3_InitInfo_t = .{
        .Device = @ptrCast(device),
        .ColorTargetFormat = sdl.SDL_GetGPUSwapchainTextureFormat(device, window),
        .MSAASamples = sdl.SDL_GPU_SAMPLECOUNT_1, // only used in multi-viewports mode
        .SwapchainComposition = sdl.SDL_GPU_SWAPCHAINCOMPOSITION_SDR, // same
        .PresentMode = sdl.SDL_GPU_PRESENTMODE_VSYNC,
    };
    _ = gui.cImGui_ImplSDLGPU3_Init(&init_info);

    return .{
        .imio = imio,
        .state = .init(),
    };
}

pub fn deinit(_: *const Self) void {
    gui.cImGui_ImplSDL3_Shutdown();
    gui.cImGui_ImplSDLGPU3_Shutdown();
    gui.ImGui_DestroyContext(null);
}

pub fn newFrame(_: *const Self) void {
    gui.cImGui_ImplSDL3_NewFrame();
    gui.cImGui_ImplSDLGPU3_NewFrame();
    gui.ImGui_NewFrame();
}

pub fn render(self: *const Self) void {
    self.newFrame();

    Layout.renderDockSpace();

    if (gui.ImGui_Begin("Editor", null, 0)) {
        if (gui.ImGui_Button("Add shape")) {
            std.log.debug("Oui", .{});
        }
    }
    gui.ImGui_End();
    gui.ImGui_Render();
}

pub fn prepareDrawData(_: *const Self, cmd_buffer: ?*sdl.SDL_GPUCommandBuffer) void {
    gui.cImGui_ImplSDLGPU3_PrepareDrawData(gui.ImGui_GetDrawData(), @ptrCast(cmd_buffer));
}

pub fn renderDraw(_: *const Self, cmd_buffer: ?*sdl.SDL_GPUCommandBuffer, pass: ?*sdl.SDL_GPURenderPass) void {
    gui.cImGui_ImplSDLGPU3_RenderDrawData(gui.ImGui_GetDrawData(), @ptrCast(cmd_buffer), @ptrCast(pass));
}
