const std = @import("std");
const Allocator = std.mem.Allocator;
const c = @import("c");
const sdl = c.sdl;
const m = @import("math.zig").math;
const Editor = @import("editor/Editor.zig");
const Shader = @import("Shader.zig");
const Scene = @import("Scene.zig");
const Camera = @import("Camera.zig");
const EventLoop = @import("EventLoop.zig");
const fatal = @import("utils.zig").fatal;

window: *sdl.SDL_Window,
device: *sdl.SDL_GPUDevice,
shader: Shader,
vertex_buffer: *sdl.SDL_GPUBuffer,
index_buffer: *sdl.SDL_GPUBuffer,
scene_buffer: *sdl.SDL_GPUBuffer,
scene_trans_buffer: *sdl.SDL_GPUTransferBuffer,
pipeline: *sdl.SDL_GPUGraphicsPipeline,
viewport_texture: ViewportTexture,
pending_viewport_size: ?struct { width: u32, height: u32 } = null,

const ViewportTexture = struct {
    texture: *sdl.SDL_GPUTexture,
    width: u32,
    height: u32,
};

const Self = @This();
const Vertex = struct {
    position: m.Vec2,
    tex_coord: m.Vec2,
};

// Full screen quad
const vertices = [_]Vertex{
    .{ .position = .new(-1.0, -1.0), .tex_coord = .new(0.0, 0.0) }, // Bottom-left
    .{ .position = .new(1.0, -1.0), .tex_coord = .new(1.0, 0.0) }, // Bottom-right
    .{ .position = .new(1.0, 1.0), .tex_coord = .new(1.0, 1.0) }, // Top-right
    .{ .position = .new(-1.0, 1.0), .tex_coord = .new(0.0, 1.0) }, // Top-left
};
const indices = [_]u16{
    0, 1, 2, // First triangle
    2, 3, 0, // Second triangle
};

const UniformData = extern struct {
    resolution: m.Vec2,
    _pad: [2]f32 = undefined,

    cam_pos: m.Vec3,
    fov: f32,
    // mat3 is stored as 3 vec4 columns!
    cam_right: m.Vec4, // right.x, right.y, right.z, PAD
    cam_up: m.Vec4, // up.x, up.y, up.z, PAD
    cam_forward: m.Vec4, // forward.x, forward.y, forward.z, PAD,
};

pub fn init(allocator: Allocator) Self {
    const window = sdl.SDL_CreateWindow("Hello SDL3", 1280, 800, sdl.SDL_WINDOW_RESIZABLE) orelse {
        fatal("unable to create window: {s}", .{sdl.SDL_GetError()});
    };
    errdefer sdl.SDL_DestroyWindow(window);

    const device = sdl.SDL_CreateGPUDevice(sdl.SDL_GPU_SHADERFORMAT_MSL, true, null) orelse {
        fatal("unable to create gpu device: {s}", .{sdl.SDL_GetError()});
    };
    errdefer sdl.SDL_DestroyGPUDevice(device);

    if (!sdl.SDL_ClaimWindowForGPUDevice(device, window)) {
        fatal("unable to claim window for gpu device: {s}", .{sdl.SDL_GetError()});
    }

    // Vertex buffer
    const vertex_buffer = sdl.SDL_CreateGPUBuffer(
        device,
        &.{
            .size = @sizeOf(@TypeOf(vertices)),
            .usage = sdl.SDL_GPU_BUFFERUSAGE_VERTEX,
        },
    ) orelse {
        fatal("failed to create buffer: {s}", .{sdl.SDL_GetError()});
    };

    // Index buffer
    const index_buffer = sdl.SDL_CreateGPUBuffer(
        device,
        &.{
            .size = @sizeOf(@TypeOf(indices)),
            .usage = sdl.SDL_GPU_BUFFERUSAGE_INDEX,
        },
    ) orelse {
        fatal("failed to create buffer: {s}", .{sdl.SDL_GetError()});
    };

    // Scene buffer
    const scene_buffer = sdl.SDL_CreateGPUBuffer(
        device,
        &.{
            .size = @sizeOf(Scene.Data),
            .usage = sdl.SDL_GPU_BUFFERUSAGE_GRAPHICS_STORAGE_READ,
        },
    ) orelse {
        fatal("failed to create buffer: {s}", .{sdl.SDL_GetError()});
    };

    // Transfert buffer
    const vertex_trans_buffer = sdl.SDL_CreateGPUTransferBuffer(
        device,
        &.{
            .size = @sizeOf(@TypeOf(vertices)) + @sizeOf(@TypeOf(indices)),
            .usage = sdl.SDL_GPU_TRANSFERBUFFERUSAGE_UPLOAD,
        },
    ) orelse {
        fatal("failed to create transfer buffer: {s}", .{sdl.SDL_GetError()});
    };

    {
        const data_ptr = sdl.SDL_MapGPUTransferBuffer(device, vertex_trans_buffer, false) orelse {
            fatal("unable to map transfer buffer data: {s}", .{sdl.SDL_GetError()});
        };
        const vertex_data: [*]Vertex = @ptrCast(@alignCast(data_ptr));
        @memcpy(vertex_data[0..vertices.len], vertices[0..vertices.len]);

        const raw_bytes: [*]u8 = @ptrCast(data_ptr);
        const index_data: [*]u16 = @ptrCast(@alignCast(raw_bytes + @sizeOf(@TypeOf(vertices))));
        @memcpy(index_data[0..indices.len], indices[0..indices.len]);

        sdl.SDL_UnmapGPUTransferBuffer(device, vertex_trans_buffer);
    }

    const scene_trans_buffer = sdl.SDL_CreateGPUTransferBuffer(
        device,
        &.{
            .size = @sizeOf(Scene.Data),
            .usage = sdl.SDL_GPU_TRANSFERBUFFERUSAGE_UPLOAD,
        },
    ) orelse {
        fatal("failed to create scene transfer buffer: {s}", .{sdl.SDL_GetError()});
    };

    // Copy pass
    {
        const cmd_buffer = sdl.SDL_AcquireGPUCommandBuffer(device) orelse {
            fatal("unable to acquire command buffer: {s}", .{sdl.SDL_GetError()});
        };

        const pass = sdl.SDL_BeginGPUCopyPass(cmd_buffer) orelse {
            fatal("failed to begin copy pass: {s}", .{sdl.SDL_GetError()});
        };

        // Where is the data
        const location: sdl.SDL_GPUTransferBufferLocation = .{
            .offset = 0,
            .transfer_buffer = vertex_trans_buffer,
        };

        // Where to upload the data
        const region: sdl.SDL_GPUBufferRegion = .{
            .buffer = vertex_buffer,
            .size = @sizeOf(@TypeOf(vertices)),
            .offset = 0,
        };
        // Upload the data
        sdl.SDL_UploadToGPUBuffer(pass, &location, &region, true);

        // Where is the data
        const index_location: sdl.SDL_GPUTransferBufferLocation = .{
            .offset = @sizeOf(@TypeOf(vertices)),
            .transfer_buffer = vertex_trans_buffer,
        };

        // Where to upload the data
        const index_region: sdl.SDL_GPUBufferRegion = .{
            .buffer = index_buffer,
            .size = @sizeOf(@TypeOf(indices)),
            .offset = 0,
        };
        // Upload the data
        sdl.SDL_UploadToGPUBuffer(pass, &index_location, &index_region, true);

        sdl.SDL_EndGPUCopyPass(pass);

        if (!sdl.SDL_SubmitGPUCommandBuffer(cmd_buffer)) {
            fatal("failed to submit upload command buffer: {s}", .{sdl.SDL_GetError()});
        }
    }

    // Shaders
    const shader: Shader = .init(device, allocator, "raymarch");

    // Graphics pipeline
    var pipeline_info: sdl.SDL_GPUGraphicsPipelineCreateInfo = .{
        .vertex_shader = shader.vert,
        .fragment_shader = shader.frag,
        .vertex_input_state = .{
            .num_vertex_buffers = 1,
            .vertex_buffer_descriptions = &[_]sdl.SDL_GPUVertexBufferDescription{
                .{
                    .slot = 0,
                    .input_rate = sdl.SDL_GPU_VERTEXINPUTRATE_VERTEX,
                    .instance_step_rate = 0,
                    .pitch = @sizeOf(Vertex),
                },
            },
            .num_vertex_attributes = 2,
            .vertex_attributes = &[_]sdl.SDL_GPUVertexAttribute{
                .{
                    .buffer_slot = 0,
                    .location = 0,
                    .format = sdl.SDL_GPU_VERTEXELEMENTFORMAT_FLOAT2,
                    .offset = 0,
                },
                .{
                    .buffer_slot = 0,
                    .location = 1,
                    .format = sdl.SDL_GPU_VERTEXELEMENTFORMAT_FLOAT2,
                    .offset = @offsetOf(Vertex, "tex_coord"),
                },
            },
        },
        .primitive_type = sdl.SDL_GPU_PRIMITIVETYPE_TRIANGLELIST,
        .target_info = .{
            .num_color_targets = 1,
            .color_target_descriptions = &[_]sdl.SDL_GPUColorTargetDescription{
                .{
                    .format = sdl.SDL_GetGPUSwapchainTextureFormat(device, window),
                },
            },
        },
        .rasterizer_state = .{
            .fill_mode = sdl.SDL_GPU_FILLMODE_FILL,
            .cull_mode = sdl.SDL_GPU_CULLMODE_NONE,
            .front_face = sdl.SDL_GPU_FRONTFACE_COUNTER_CLOCKWISE,
        },
        .multisample_state = .{
            .sample_count = sdl.SDL_GPU_SAMPLECOUNT_1,
        },
    };

    const pipeline = sdl.SDL_CreateGPUGraphicsPipeline(device, &pipeline_info) orelse {
        fatal("failed to create graphics pipeline: {s}", .{sdl.SDL_GetError()});
    };

    return .{
        .device = device,
        .window = window,
        .shader = shader,
        .index_buffer = index_buffer,
        .vertex_buffer = vertex_buffer,
        .scene_buffer = scene_buffer,
        .scene_trans_buffer = scene_trans_buffer,
        .pipeline = pipeline,
        .viewport_texture = makeViewportTexture(device, window, 100, 100),
    };
}

pub fn deinit(self: *Self) void {
    self.shader.deinit(self.device);

    sdl.SDL_ReleaseGPUGraphicsPipeline(self.device, self.pipeline);
    sdl.SDL_ReleaseGPUBuffer(self.device, self.vertex_buffer);
    sdl.SDL_ReleaseGPUTransferBuffer(self.device, self.scene_trans_buffer);
    sdl.SDL_DestroyGPUDevice(self.device);
    sdl.SDL_DestroyWindow(self.window);
}

fn makeViewportTexture(device: *sdl.SDL_GPUDevice, window: *sdl.SDL_Window, width: u32, height: u32) ViewportTexture {
    const create_info = sdl.SDL_GPUTextureCreateInfo{
        .type = sdl.SDL_GPU_TEXTURETYPE_2D,
        .format = sdl.SDL_GetGPUSwapchainTextureFormat(device, window),
        .width = width,
        .height = height,
        .layer_count_or_depth = 1,
        .num_levels = 1,
        .sample_count = sdl.SDL_GPU_SAMPLECOUNT_1,
        .usage = sdl.SDL_GPU_TEXTUREUSAGE_COLOR_TARGET | sdl.SDL_GPU_TEXTUREUSAGE_SAMPLER,
        .props = 0,
    };

    const texture = sdl.SDL_CreateGPUTexture(device, &create_info) orelse {
        fatal("failed to create viewport GPU texture: {s}", .{sdl.SDL_GetError()});
    };

    return .{
        .width = width,
        .height = height,
        .texture = texture,
    };
}

// This function is called after rendering the 3D scene by the Editor. So if there are some changes
// they must be applied to the next frame. We only save the change
pub fn resizeViewport(self: *Self, width: u32, height: u32) void {
    if (width != self.viewport_texture.width or height != self.viewport_texture.height) {
        self.pending_viewport_size = .{ .width = width, .height = height };
    }
}

// Applies any pending resize from previous frame
fn applyPendingResize(self: *Self) void {
    if (self.pending_viewport_size) |size| {
        sdl.SDL_ReleaseGPUTexture(self.device, self.viewport_texture.texture);
        self.viewport_texture = makeViewportTexture(self.device, self.window, size.width, size.height);
        self.pending_viewport_size = null;
    }
}

pub fn frame(
    self: *Self,
    scene: *Scene,
    camera: *const Camera,
    editor: *Editor,
    event_loop: *EventLoop,
) !sdl.SDL_AppResult {
    self.applyPendingResize();

    // A render pass is a GPU operation where you're drawing things to a texture (called the "render target")
    // Can't read from and write to the same texture within the same render pass
    const cmd_buffer = sdl.SDL_AcquireGPUCommandBuffer(self.device) orelse {
        fatal("unable to acquire command buffer: {s}", .{sdl.SDL_GetError()});
    };

    // TODO: check if nothing changed?
    {
        const pass = sdl.SDL_BeginGPUCopyPass(cmd_buffer) orelse {
            fatal("failed to begin copy pass: {s}", .{sdl.SDL_GetError()});
        };

        // self.updateSceneBuffer(scene);

        const data_ptr = sdl.SDL_MapGPUTransferBuffer(self.device, self.scene_trans_buffer, false) orelse {
            fatal("unable to map transfer buffer data: {s}", .{sdl.SDL_GetError()});
        };
        const src_bytes = @as([*]const u8, @ptrCast(&scene.data));
        const dst_bytes = @as([*]u8, @ptrCast(data_ptr));
        @memcpy(dst_bytes[0..@sizeOf(Scene.Data)], src_bytes[0..@sizeOf(Scene.Data)]);

        sdl.SDL_UnmapGPUTransferBuffer(self.device, self.scene_trans_buffer);

        // Upload the data
        sdl.SDL_UploadToGPUBuffer(
            pass,
            &.{
                .offset = 0,
                .transfer_buffer = self.scene_trans_buffer,
            },
            &.{
                .buffer = self.scene_buffer,
                .size = @sizeOf(Scene.Data),
                .offset = 0,
            },
            true,
        );

        sdl.SDL_EndGPUCopyPass(pass);
    }

    // Pass 1: Render your 3D scene
    // Input: vertex/index buffers, uniforms, shaders
    // Output: viewport_texture (the render target)
    // Raymarching shader runs and writes pixels into viewport_texture
    {
        const pass = sdl.SDL_BeginGPURenderPass(
            cmd_buffer,
            &.{
                .clear_color = .{ .r = 1.0, .g = 1.0, .b = 1.0, .a = 1.0 },
                .load_op = sdl.SDL_GPU_LOADOP_CLEAR,
                .store_op = sdl.SDL_GPU_STOREOP_STORE,
                .texture = self.viewport_texture.texture,
            },
            1,
            null,
        ) orelse {
            fatal("failed to begin render pass: {s}", .{sdl.SDL_GetError()});
        };

        // Binds the pipeline
        sdl.SDL_BindGPUGraphicsPipeline(pass, self.pipeline);

        // Binds vertex buffer
        sdl.SDL_BindGPUVertexBuffers(
            pass,
            0,
            &[_]sdl.SDL_GPUBufferBinding{
                .{
                    .buffer = self.vertex_buffer,
                    .offset = 0,
                },
            },
            1,
        );

        // Indices
        sdl.SDL_BindGPUIndexBuffer(
            pass,
            &.{
                .buffer = self.index_buffer,
                .offset = 0,
            },
            sdl.SDL_GPU_INDEXELEMENTSIZE_16BIT,
        );

        // Bind le storage buffer
        sdl.SDL_BindGPUFragmentStorageBuffers(
            pass,
            0,
            &self.scene_buffer,
            1,
        );

        // Camera uniform
        {
            const cam_vecs = camera.toVec4();

            const uniform_data: UniformData = .{
                .resolution = .new(
                    @floatFromInt(self.viewport_texture.width),
                    @floatFromInt(self.viewport_texture.height),
                ),
                .cam_pos = camera.pos,
                .fov = camera.fov,
                .cam_right = cam_vecs.right,
                .cam_up = cam_vecs.up,
                .cam_forward = cam_vecs.forward,
            };
            sdl.SDL_PushGPUFragmentUniformData(cmd_buffer, 0, &uniform_data, @sizeOf(UniformData));
        }

        sdl.SDL_DrawGPUIndexedPrimitives(pass, 6, 1, 0, 0, 0);

        sdl.SDL_EndGPURenderPass(pass);
    }

    // Pass 2: Render ImGui
    // Input: ImGui vertex data, AND viewport_texture (as a sampler)
    // Output: swapchain_texture (the screen)
    // ImGui draws its UI to the screen. When it hits your ImGui_Image() call, it reads from viewport_texture to display it
    var swapchain_texture: ?*sdl.SDL_GPUTexture = undefined;
    var width: u32 = 0;
    var height: u32 = 0;
    if (!sdl.SDL_WaitAndAcquireGPUSwapchainTexture(cmd_buffer, self.window, &swapchain_texture, &width, &height)) {
        fatal("unable to acquire swapchain texture: {s}", .{sdl.SDL_GetError()});
    }

    // Can be null, for example when window is minimized
    if (swapchain_texture == null) {
        std.log.debug("Strange...", .{});
        if (!sdl.SDL_SubmitGPUCommandBuffer(cmd_buffer)) {
            fatal("unable to submit command buffer: {s}", .{sdl.SDL_GetError()});
        }
        return sdl.SDL_APP_CONTINUE;
    }

    // Second render pass
    {
        editor.render(self, scene, camera, event_loop);
        editor.prepareDrawData(cmd_buffer);

        const pass = sdl.SDL_BeginGPURenderPass(
            cmd_buffer,
            &.{
                .clear_color = .{ .r = 0.0, .g = 0.0, .b = 0.0, .a = 1.0 },
                .load_op = sdl.SDL_GPU_LOADOP_CLEAR,
                .store_op = sdl.SDL_GPU_STOREOP_STORE,
                .texture = swapchain_texture,
            },
            1,
            null,
        ) orelse {
            fatal("failed to begin render pass: {s}", .{sdl.SDL_GetError()});
        };

        editor.renderDraw(cmd_buffer, pass);
        sdl.SDL_EndGPURenderPass(pass);
    }

    if (!sdl.SDL_SubmitGPUCommandBuffer(cmd_buffer)) {
        fatal("unable to submit command buffer: {s}", .{sdl.SDL_GetError()});
    }

    return sdl.SDL_APP_CONTINUE;
}

var debug_logged: bool = false;

fn updateSceneBuffer(self: *Self, scene: *const Scene) void {
    if (!debug_logged) {
        debug_logged = true;
        std.debug.print("DEBUG: Scene.Data size = {}\n", .{@sizeOf(Scene.Data)});
        std.debug.print("DEBUG: SDFObject size = {}\n", .{@sizeOf(Scene.SDFObject)});
        std.debug.print("DEBUG: object_count = {}\n", .{scene.data.count});
        std.debug.print("DEBUG: First 32 bytes: ", .{});
        const bytes = @as([*]const u8, @ptrCast(&scene.data));
        for (0..32) |i| {
            std.debug.print("{x:0>2} ", .{bytes[i]});
        }
        std.debug.print("\n", .{});
    }

    const data_ptr = sdl.SDL_MapGPUTransferBuffer(self.device, self.scene_trans_buffer, false) orelse {
        fatal("unable to map transfer buffer data: {s}", .{sdl.SDL_GetError()});
    };
    const src_bytes = @as([*]const u8, @ptrCast(&scene.data));
    const dst_bytes = @as([*]u8, @ptrCast(data_ptr));
    @memcpy(dst_bytes[0..@sizeOf(Scene.Data)], src_bytes[0..@sizeOf(Scene.Data)]);

    sdl.SDL_UnmapGPUTransferBuffer(self.device, self.scene_trans_buffer);
}
