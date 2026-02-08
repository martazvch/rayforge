const std = @import("std");
const c = @import("c");
const sdl = c.sdl;
const gui = c.gui;
const m = @import("../math.zig").math;
const theme = @import("theme.zig");
const State = @import("State.zig");
const Scene = @import("../Scene.zig");
const Layout = @import("layout.zig");
const Viewport = @import("Viewport.zig");
const Pipeline = @import("../Pipeline.zig");
const EventLoop = @import("../EventLoop.zig");
const Camera = @import("../Camera.zig");
const Projection = @import("../Projection.zig");
const Rect = @import("../Rect.zig");
const fatal = @import("../utils.zig").fatal;

imio: *gui.ImGuiIO,
state: State,
device: *sdl.SDL_GPUDevice,
window: *sdl.SDL_Window,
viewport: Viewport,

const Self = @This();

pub fn init(device: *sdl.SDL_GPUDevice, window: *sdl.SDL_Window) Self {
    _ = gui.CIMGUI_CHECKVERSION();
    _ = gui.ImGui_CreateContext(null);

    const imio = gui.ImGui_GetIO();
    imio.*.ConfigFlags = gui.ImGuiConfigFlags_NavEnableKeyboard;
    imio.*.ConfigFlags = gui.ImGuiConfigFlags_DockingEnable;

    if (!gui.cImGui_ImplSDL3_InitForSDLGPU(@ptrCast(window))) {
        fatal("failed to initialize ImGUI window", .{});
    }

    var init_info: gui.struct_ImGui_ImplSDLGPU3_InitInfo_t = .{
        .Device = @ptrCast(device),
        .ColorTargetFormat = sdl.SDL_GetGPUSwapchainTextureFormat(device, window),
        .MSAASamples = sdl.SDL_GPU_SAMPLECOUNT_1, // only used in multi-viewports mode
        .SwapchainComposition = sdl.SDL_GPU_SWAPCHAINCOMPOSITION_SDR, // same
        .PresentMode = sdl.SDL_GPU_PRESENTMODE_VSYNC,
    };
    _ = gui.cImGui_ImplSDLGPU3_Init(&init_info);

    // Font
    const font_data = @embedFile("../assets/fonts/Inter-VariableFont_opsz,wght.ttf");

    // Got from imgui_draw.cpp:2424 (imgui-docking) because zero-initializing it crashes
    const config: gui.ImFontConfig = .{
        .OversampleH = 0,
        .OversampleV = 0,
        .ExtraSizeScale = 1,
        .GlyphMaxAdvanceX = std.math.floatMax(f32),
        .RasterizerDensity = 1,
        .RasterizerMultiply = 1,
        .EllipsisChar = 0,
        .FontDataOwnedByAtlas = false,
    };

    const font = gui.ImFontAtlas_AddFontFromMemoryTTF(
        imio.*.Fonts,
        @constCast(font_data),
        font_data.len,
        16.0,
        &config,
        null,
    );

    // Last added font is automatically set
    _ = font;
    _ = gui.ImFontAtlas_Build(imio.*.Fonts);

    theme.applyTheme();

    return .{
        .imio = imio,
        .state = .init(),
        .device = device,
        .window = window,
        .viewport = .init(),
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

pub fn render(self: *Self, pipeline: *Pipeline, scene: *Scene, camera: *const Camera, event_loop: *EventLoop) void {
    // --------
    //  Render
    // --------
    self.newFrame();

    // Render layout and get viewport region
    Layout.render(scene, &self.viewport);

    // Viewport
    _ = self.viewport.render(pipeline, event_loop);

    // Selected object
    drawBoundingBox(scene, camera, self.viewport.rect);

    gui.ImGui_Render();

    // --------
    //  States
    // --------

    // Resize viewport texture to match the layout region
    const width: u32 = @max(1, @as(u32, @intFromFloat(self.viewport.rect.size.x)));
    const height: u32 = @max(1, @as(u32, @intFromFloat(self.viewport.rect.size.y)));
    pipeline.resizeViewport(width, height);

    // Check if mouse is over viewport region for input handling
    const mouse_pos = gui.ImGui_GetMousePos();
    event_loop.setViewportState(self.viewport.rect.isIn(mouse_pos.x, mouse_pos.y));
}

fn drawBoundingBox(scene: *Scene, camera: *const Camera, vp: Rect) void {
    const obj = scene.getSelectedSdf() orelse return;

    if (!obj.visible) {
        return;
    }

    const proj: Projection = .init(camera, vp.pos.x, vp.pos.y, vp.size.x, vp.size.y);

    const aabb = obj.getAABB();
    const lo = aabb.min;
    const hi = aabb.max;

    // Which faces point toward the camera?
    // For an AABB this is just 6 comparisons — no dot products needed.
    // The camera sees a face if it's on the "outside" of that face.
    const face_visible = [6]bool{
        camera.pos.y < lo.y, // 0: -Y (bottom) — camera is below the box
        camera.pos.y > hi.y, // 1: +Y (top)    — camera is above
        camera.pos.x < lo.x, // 2: -X (left)   — camera is to the left
        camera.pos.x > hi.x, // 3: +X (right)  — camera is to the right
        camera.pos.z < lo.z, // 4: -Z (back)   — camera is behind
        camera.pos.z > hi.z, // 5: +Z (front)  — camera is in front
    };

    const corners_3d = aabb.getCorners();

    // Project all 8 corners to screen space
    var corners: [8]?[2]f32 = undefined;
    for (0..8) |i| {
        corners[i] = proj.worldToScreen(corners_3d[i]);
    }

    // Each edge and which 2 faces it borders:
    // vertex A, vertex B, face 1, face 2
    const edges = [12][4]u8{
        // Bottom face edges
        .{ 0, 1, 0, 4 }, // bottom + back
        .{ 1, 2, 0, 3 }, // bottom + right
        .{ 2, 3, 0, 5 }, // bottom + front
        .{ 3, 0, 0, 2 }, // bottom + left
        // Top face edges
        .{ 4, 5, 1, 4 }, // top + back
        .{ 5, 6, 1, 3 }, // top + right
        .{ 6, 7, 1, 5 }, // top + front
        .{ 7, 4, 1, 2 }, // top + left
        // Vertical edges
        .{ 0, 4, 4, 2 }, // back  + left
        .{ 1, 5, 4, 3 }, // back  + right
        .{ 2, 6, 5, 3 }, // front + right
        .{ 3, 7, 5, 2 }, // front + left
    };

    // Draw on top of everything
    const draw_list = gui.ImGui_GetForegroundDrawList();

    for (edges) |e| {
        const a = corners[e[0]] orelse continue;
        const b = corners[e[1]] orelse continue;

        // Edge is visible if at least one adjacent face is front-facing
        const visible = face_visible[e[2]] or face_visible[e[3]];

        if (visible) {
            gui.ImDrawList_AddLineEx(
                draw_list,
                .{ .x = a[0], .y = a[1] },
                .{ .x = b[0], .y = b[1] },
                0xFF00BFFF,
                1.5,
            );
        }
    }
}

pub fn prepareDrawData(_: *const Self, cmd_buffer: ?*sdl.SDL_GPUCommandBuffer) void {
    gui.cImGui_ImplSDLGPU3_PrepareDrawData(gui.ImGui_GetDrawData(), @ptrCast(cmd_buffer));
}

pub fn renderDraw(_: *const Self, cmd_buffer: ?*sdl.SDL_GPUCommandBuffer, pass: ?*sdl.SDL_GPURenderPass) void {
    gui.cImGui_ImplSDLGPU3_RenderDrawData(gui.ImGui_GetDrawData(), @ptrCast(cmd_buffer), @ptrCast(pass));
}
