const std = @import("std");
const Allocator = std.mem.Allocator;
const c = @import("c");
const sdl = c.sdl;
const gui = c.gui;
const math = @import("../math.zig");
const m = math.zlm;
const theme = @import("theme.zig");
const State = @import("State.zig");
const Layout = @import("layout.zig");
const Viewport = @import("Viewport.zig");
const Projection = @import("../Projection.zig");
const Rect = @import("../Rect.zig");
const globals = @import("../globals.zig");
const fatal = @import("../utils.zig").fatal;

imio: *gui.ImGuiIO,
state: State,
layout: Layout,
viewport: Viewport,

const Self = @This();

pub fn init() Self {
    _ = gui.CIMGUI_CHECKVERSION();
    _ = gui.ImGui_CreateContext(null);

    const imio = gui.ImGui_GetIO();
    imio.*.ConfigFlags = gui.ImGuiConfigFlags_NavEnableKeyboard;
    imio.*.ConfigFlags = gui.ImGuiConfigFlags_DockingEnable;

    if (!gui.cImGui_ImplSDL3_InitForSDLGPU(@ptrCast(globals.window))) {
        fatal("failed to initialize ImGUI window", .{});
    }

    var init_info: gui.struct_ImGui_ImplSDLGPU3_InitInfo_t = .{
        .Device = @ptrCast(globals.device),
        .ColorTargetFormat = sdl.SDL_GetGPUSwapchainTextureFormat(globals.device, globals.window),
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
        .layout = .init(),
        .viewport = .init(),
    };
}

pub fn deinit(self: *Self) void {
    self.layout.deinit();
    gui.cImGui_ImplSDL3_Shutdown();
    gui.cImGui_ImplSDLGPU3_Shutdown();
    gui.ImGui_DestroyContext(null);
}

pub fn newFrame(_: *const Self) void {
    gui.cImGui_ImplSDL3_NewFrame();
    gui.cImGui_ImplSDLGPU3_NewFrame();
    gui.ImGui_NewFrame();
}

pub fn render(self: *Self) void {
    // --------
    //  Render
    // --------
    self.newFrame();

    // Render layout and get viewport region
    self.layout.render(&globals.scene, &self.viewport);

    // Viewport
    _ = self.viewport.render();

    // Selected object
    drawBoundingBox(self.viewport.rect);
    drawGuizmo(self.viewport.rect);

    gui.ImGui_Render();

    // --------
    //  States
    // --------

    // Resize viewport texture to match the layout region
    const width: u32 = @max(1, @as(u32, @intFromFloat(self.viewport.rect.size.x)));
    const height: u32 = @max(1, @as(u32, @intFromFloat(self.viewport.rect.size.y)));
    globals.pipeline.resizeViewport(width, height);

    // Check if mouse is over viewport region for input handling
    const mouse_pos = gui.ImGui_GetMousePos();
    globals.event_loop.setViewportState(self.viewport.rect.isIn(mouse_pos.x, mouse_pos.y));
}

fn drawGuizmo(vp: Rect) void {
    const axis_len = 2;
    const drawlist = gui.ImGui_GetForegroundDrawList();

    const proj: Projection = .init(&globals.camera, vp.pos.x, vp.pos.y, vp.size.x, vp.size.y);
    const sdf = globals.scene.getSelectedSdf() orelse return;
    const pos = sdf.getPos();
    const pos_proj = proj.worldToScreen(pos).?;
    const start: gui.ImVec2 = .{ .x = pos_proj[0], .y = pos_proj[1] };

    // const pos_proj_vec_bot: gui.ImVec2 = .{ .x = pos_proj[0], .y = pos_proj[1] + 50 };

    for (
        [_]m.Vec3{ .unitX, .unitY, .unitZ },
        [_]u32{ 0xFF0000FF, 0x00FF00FF, 0x0000FFFF },
    ) |unit_axis, color| {
        const axis = unit_axis.scale(axis_len);

        const end_pos = math.mulMat4Vec3(pos.add(axis), sdf.transform.transpose());
        const end_proj = proj.worldToScreen(end_pos).?;
        const end: gui.ImVec2 = .{ .x = end_proj[0], .y = end_proj[1] };
        std.log.debug("End: {any}", .{end});
        gui.ImDrawList_AddLine(drawlist, start, end, color);
    }
    std.log.debug("----", .{});
}

fn drawBoundingBox(vp: Rect) void {
    const sdf = globals.scene.getSelectedSdf() orelse return;
    const proj: Projection = .init(&globals.camera, vp.pos.x, vp.pos.y, vp.size.x, vp.size.y);

    // Get local AABB (centered at origin), then transform each corner
    // by scale, rotation, and translation to get a proper OBB.
    const local_corners = sdf.getLocalAABB().getCorners();
    const pos = sdf.getPos();

    var corners_3d: [8]m.Vec3 = undefined;
    for (0..8) |i| {
        const scaled = local_corners[i].scale(sdf.scale);
        corners_3d[i] = math.mulMat4Vec3(scaled, sdf.transform.transpose()).add(pos);
    }

    // Face visibility via cross-product normals.
    // Each face is defined by 3 corner indices (a, b, c) such that
    // (b-a) x (c-a) points outward.
    //
    //      4 ────── 5
    //     /|       /|
    //    / |      / |
    //  7 ────── 6   |
    //  |   0 ───|── 1
    //  |  /     |  /
    //  | /      | /
    //  3 ────── 2
    const faces = [6][3]u8{
        .{ 0, 1, 3 }, // 0: -Y (bottom)
        .{ 4, 7, 5 }, // 1: +Y (top)
        .{ 0, 3, 4 }, // 2: -X (left)
        .{ 1, 5, 2 }, // 3: +X (right)
        .{ 0, 4, 1 }, // 4: -Z (back)
        .{ 2, 6, 3 }, // 5: +Z (front)
    };

    var face_visible: [6]bool = undefined;
    for (faces, 0..) |f, i| {
        const a = corners_3d[f[0]];
        const normal = corners_3d[f[1]].sub(a).cross(corners_3d[f[2]].sub(a));
        face_visible[i] = normal.dot(globals.camera.pos.sub(a)) > 0;
    }

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

    // Draw on top of everything but only on 3D viewport
    const draw_list = gui.ImGui_GetForegroundDrawList();
    gui.ImDrawList_PushClipRect(
        draw_list,
        .{ .x = vp.pos.x, .y = vp.pos.y },
        .{ .x = vp.pos.x + vp.size.x, .y = vp.pos.y + vp.size.y },
        true,
    );
    defer gui.ImDrawList_PopClipRect(draw_list);

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
