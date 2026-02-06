const std = @import("std");
const c = @import("c.zig");
const sdl = c.sdl;
const m = @import("math.zig").math;
const Editor = @import("Editor.zig");
const Shader = @import("Shader.zig");
const fatal = @import("utils.zig").fatal;

var window: *sdl.SDL_Window = undefined;
var device: *sdl.SDL_GPUDevice = undefined;
var editor: Editor = undefined;
var shader: Shader = undefined;

const Vertex = struct {
    pos: m.Vec3,
    color: m.Vec4,
};
const vertices = [_]Vertex{
    .{ .pos = .new(0.0, 0.5, 0.0), .color = .new(1.0, 0.0, 0.0, 1.0) }, // top vertex
    .{ .pos = .new(-0.5, -0.5, 0.0), .color = .new(1.0, 1.0, 0.0, 1.0) }, // bottom let vertex
    .{ .pos = .new(0.5, -0.5, 0.0), .color = .new(1.0, 0.0, 1.0, 1.0) }, // bottom right vertex
};
var vertex_buffer: *sdl.SDL_GPUBuffer = undefined;
var transfert_buffer: *sdl.SDL_GPUTransferBuffer = undefined;

const TimeUniform = struct {
    time: f32,
};

pub fn main() !u8 {
    app_err.reset();
    var empty_argv: [0:null]?[*:0]u8 = .{};
    const status: u8 = @truncate(@as(c_uint, @bitCast(sdl.SDL_RunApp(empty_argv.len, @ptrCast(&empty_argv), sdlMainC, null))));
    return app_err.load() orelse status;
}

fn sdlMainC(argc: c_int, argv: ?[*:null]?[*:0]u8) callconv(.c) c_int {
    return sdl.SDL_EnterAppMainCallbacks(argc, @ptrCast(argv), sdlAppInitC, sdlAppIterateC, sdlAppEventC, sdlAppQuitC);
}

fn sdlAppInit(appstate: ?*?*anyopaque, argv: [][*:0]u8) !sdl.SDL_AppResult {
    _ = appstate;
    _ = argv;

    window = sdl.SDL_CreateWindow("Hello SDL3", 800, 600, sdl.SDL_WINDOW_RESIZABLE) orelse {
        fatal("unable to create window: {s}", .{sdl.SDL_GetError()});
    };
    errdefer sdl.SDL_DestroyWindow(window);

    device = sdl.SDL_CreateGPUDevice(sdl.SDL_GPU_SHADERFORMAT_MSL, true, null) orelse {
        fatal("unable to create gpu device: {s}", .{sdl.SDL_GetError()});
    };
    errdefer sdl.SDL_DestroyGPUDevice(device);

    if (!sdl.SDL_ClaimWindowForGPUDevice(device, window)) {
        fatal("unable to claim window for gpu device: {s}", .{sdl.SDL_GetError()});
    }

    const buffer_info: sdl.SDL_GPUBufferCreateInfo = .{
        .size = @sizeOf(@TypeOf(vertices)),
        .usage = sdl.SDL_GPU_BUFFERUSAGE_VERTEX,
    };
    vertex_buffer = sdl.SDL_CreateGPUBuffer(device, &buffer_info) orelse {
        fatal("failed to create buffer: {s}", .{sdl.SDL_GetError()});
    };

    const transfert_buffer_info: sdl.SDL_GPUTransferBufferCreateInfo = .{
        .size = @sizeOf(@TypeOf(vertices)),
        .usage = sdl.SDL_GPU_TRANSFERBUFFERUSAGE_UPLOAD,
    };
    transfert_buffer = sdl.SDL_CreateGPUTransferBuffer(device, &transfert_buffer_info) orelse {
        fatal("failed to create transfer buffer: {s}", .{sdl.SDL_GetError()});
    };

    // For now, we don't change data so wa can do it once here
    {
        const raw_data = sdl.SDL_MapGPUTransferBuffer(device, transfert_buffer, false) orelse {
            fatal("unable to map transfer buffer data: {s}", .{sdl.SDL_GetError()});
        };
        const data: [*]Vertex = @ptrCast(@alignCast(raw_data));
        @memcpy(data[0..vertices.len], vertices[0..vertices.len]);

        sdl.SDL_UnmapGPUTransferBuffer(device, transfert_buffer);
    }

    editor = .init(device, window);
    shader = .init(
        device,
        .{ .path = "shaders/msl/vert.msl" },
        .{ .path = "shaders/msl/frag.msl", .uniform_count = 1 },
    );

    return sdl.SDL_APP_CONTINUE;
}

fn sdlAppIterate(appstate: ?*anyopaque) !sdl.SDL_AppResult {
    _ = appstate;

    editor.newFrame();
    c.gui.ImGui_ShowDemoWindow(null);
    editor.render();

    // TODO: can be done only once?
    const cmd_buffer = sdl.SDL_AcquireGPUCommandBuffer(device) orelse {
        fatal("unable to acquire command buffer: {s}", .{sdl.SDL_GetError()});
    };

    // Fills the texture with the swapchain texture and gets its width and height
    // Can be null, for example when window is minimized
    var texture: ?*sdl.SDL_GPUTexture = undefined;
    var width: u32 = 0;
    var height: u32 = 0;
    if (!sdl.SDL_WaitAndAcquireGPUSwapchainTexture(cmd_buffer, window, &texture, &width, &height)) {
        fatal("unable to acquire swapchain texture: {s}", .{sdl.SDL_GetError()});
    }

    if (texture == null) {
        if (!sdl.SDL_SubmitGPUCommandBuffer(cmd_buffer)) {
            fatal("unable to submit command buffer: {s}", .{sdl.SDL_GetError()});
        }
        return sdl.SDL_APP_CONTINUE;
    }

    // Graphics pipeline
    var pipeline_info: sdl.SDL_GPUGraphicsPipelineCreateInfo = .{
        .vertex_shader = shader.vert,
        .fragment_shader = shader.frag,
        .primitive_type = sdl.SDL_GPU_PRIMITIVETYPE_TRIANGLELIST,
    };

    // Buffers
    const buffer_desc = [_]sdl.SDL_GPUVertexBufferDescription{
        .{
            .slot = 0,
            // The buffer input rate is set to change its be per VERTEX and not per INSTANCE
            // This means that the select data from the buffer will be changed to the next on every vertex
            // So, the first vertex gets vertices[0], the second vertex gets vertices[1], and so on.
            .input_rate = sdl.SDL_GPU_VERTEXINPUTRATE_VERTEX,
            .instance_step_rate = 0,
            // How many bytes to jump after each cycle
            .pitch = @sizeOf(Vertex),
        },
    };
    pipeline_info.vertex_input_state.num_vertex_buffers = 1;
    pipeline_info.vertex_input_state.vertex_buffer_descriptions = &buffer_desc;

    // Vertex attributes
    const vertex_attr = [_]sdl.SDL_GPUVertexAttribute{
        .{
            .buffer_slot = 0,
            .location = 0,
            .format = sdl.SDL_GPU_VERTEXELEMENTFORMAT_FLOAT3,
            .offset = 0,
        },
        .{
            .buffer_slot = 0,
            .location = 1,
            .format = sdl.SDL_GPU_VERTEXELEMENTFORMAT_FLOAT4,
            .offset = @offsetOf(Vertex, "color"),
        },
    };
    pipeline_info.vertex_input_state.num_vertex_attributes = 2;
    pipeline_info.vertex_input_state.vertex_attributes = &vertex_attr;

    // Color target
    const color_target = [_]sdl.SDL_GPUColorTargetDescription{
        .{
            .format = sdl.SDL_GetGPUSwapchainTextureFormat(device, window),
        },
    };
    pipeline_info.target_info.num_color_targets = 1;
    pipeline_info.target_info.color_target_descriptions = &color_target;

    const pipeline = sdl.SDL_CreateGPUGraphicsPipeline(device, &pipeline_info) orelse {
        fatal("failed to create graphics pipeline: {s}", .{sdl.SDL_GetError()});
    };
    defer sdl.SDL_ReleaseGPUGraphicsPipeline(device, pipeline);

    // Copy pass
    {
        const pass = sdl.SDL_BeginGPUCopyPass(cmd_buffer) orelse {
            fatal("failed to begin copy pass: {s}", .{sdl.SDL_GetError()});
        };
        // Where is the data
        const location: sdl.SDL_GPUTransferBufferLocation = .{
            .offset = 0,
            .transfer_buffer = transfert_buffer,
        };
        // Where to upload the data
        const region: sdl.SDL_GPUBufferRegion = .{
            .buffer = vertex_buffer,
            .size = @sizeOf(@TypeOf(vertices)),
            .offset = 0,
        };
        // Upload the data
        sdl.SDL_UploadToGPUBuffer(pass, &location, &region, true);
        sdl.SDL_EndGPUCopyPass(pass);
    }

    // Render pass
    {
        editor.prepareDrawData(cmd_buffer);

        const color_target_info: sdl.SDL_GPUColorTargetInfo = .{
            .clear_color = .{
                .r = 1.0,
                .g = 219.0 / 255.0,
                .b = 187.0 / 255.0,
                .a = 1.0,
            },
            // Deletes previous content
            .load_op = sdl.SDL_GPU_LOADOP_CLEAR,
            // Store the content to the texture
            .store_op = sdl.SDL_GPU_STOREOP_STORE,
            // Texture where we load it
            .texture = texture,
        };

        const pass = sdl.SDL_BeginGPURenderPass(cmd_buffer, &color_target_info, 1, null) orelse {
            fatal("failed to begin render pass: {s}", .{sdl.SDL_GetError()});
        };

        // Binds the pipeline
        sdl.SDL_BindGPUGraphicsPipeline(pass, pipeline);
        // Binds vertex buffer
        const buffer_binding = [_]sdl.SDL_GPUBufferBinding{
            .{
                .buffer = vertex_buffer,
                .offset = 0,
            },
        };
        sdl.SDL_BindGPUVertexBuffers(pass, 0, &buffer_binding, 1);

        // Uniforms
        const time = @as(f32, @floatFromInt(sdl.SDL_GetTicksNS())) / 1e9;
        const time_uniform: TimeUniform = .{
            .time = time,
        };
        sdl.SDL_PushGPUFragmentUniformData(cmd_buffer, 0, &time_uniform, @sizeOf(TimeUniform));

        // issue a draw call, 3 vertices, 1 instance, start first vertex and first instance
        sdl.SDL_DrawGPUPrimitives(pass, 3, 1, 0, 0);
        editor.renderDraw(cmd_buffer, pass);

        sdl.SDL_EndGPURenderPass(pass);
    }

    if (!sdl.SDL_SubmitGPUCommandBuffer(cmd_buffer)) {
        fatal("unable to submit command buffer: {s}", .{sdl.SDL_GetError()});
    }

    return sdl.SDL_APP_CONTINUE;
}
fn sdlAppEvent(appstate: ?*anyopaque, event: *sdl.SDL_Event) !sdl.SDL_AppResult {
    _ = appstate;

    // Returns if there was an event processed or not
    _ = c.gui.cImGui_ImplSDL3_ProcessEvent(@ptrCast(event));

    switch (event.type) {
        // TODO: what's the diffrence?
        sdl.SDL_EVENT_QUIT, sdl.SDL_EVENT_WINDOW_CLOSE_REQUESTED => {
            return sdl.SDL_APP_SUCCESS;
        },
        else => {},
    }

    if (event.key.key == sdl.SDLK_Q) {
        return sdl.SDL_APP_SUCCESS;
    }

    return sdl.SDL_APP_CONTINUE;
}
fn sdlAppQuit(appstate: ?*anyopaque, result: anyerror!sdl.SDL_AppResult) void {
    _ = appstate;
    _ = result catch {};

    const asserts = sdl.SDL_GetAssertionReport();
    var assert = asserts;
    while (assert != null) : (assert = assert[0].next) {
        std.log.debug(
            "{s}, {s} ({s}:{}), triggered {} times, always ignore: {}.",
            .{ assert[0].condition, assert[0].function, assert[0].filename, assert[0].linenum, assert[0].trigger_count, assert[0].always_ignore },
        );
    }

    editor.deinit();
    shader.deinit(device);

    // TODO: we never go here if we encounter a `fatal`
    sdl.SDL_ReleaseGPUBuffer(device, vertex_buffer);
    sdl.SDL_ReleaseGPUTransferBuffer(device, transfert_buffer);
    sdl.SDL_DestroyGPUDevice(device);
    sdl.SDL_DestroyWindow(window);
}

fn sdlAppInitC(appstate: ?*?*anyopaque, argc: c_int, argv: ?[*:null]?[*:0]u8) callconv(.c) sdl.SDL_AppResult {
    return sdlAppInit(appstate.?, @ptrCast(argv.?[0..@intCast(argc)])) catch |err| app_err.store(err);
}

fn sdlAppIterateC(appstate: ?*anyopaque) callconv(.c) sdl.SDL_AppResult {
    return sdlAppIterate(appstate) catch |err| app_err.store(err);
}

fn sdlAppEventC(appstate: ?*anyopaque, event: ?*sdl.SDL_Event) callconv(.c) sdl.SDL_AppResult {
    return sdlAppEvent(appstate, event.?) catch |err| app_err.store(err);
}

fn sdlAppQuitC(appstate: ?*anyopaque, result: sdl.SDL_AppResult) callconv(.c) void {
    sdlAppQuit(appstate, app_err.load() orelse result);
}

var app_err: ErrorStore = .{};

const ErrorStore = struct {
    const status_not_stored = 0;
    const status_storing = 1;
    const status_stored = 2;

    status: sdl.SDL_AtomicInt = .{},
    err: anyerror = undefined,
    trace_index: usize = undefined,
    trace_addrs: [32]usize = undefined,

    fn reset(es: *ErrorStore) void {
        _ = sdl.SDL_SetAtomicInt(&es.status, status_not_stored);
    }

    fn store(es: *ErrorStore, err: anyerror) sdl.SDL_AppResult {
        if (sdl.SDL_CompareAndSwapAtomicInt(&es.status, status_not_stored, status_storing)) {
            es.err = err;
            if (@errorReturnTrace()) |src_trace| {
                es.trace_index = src_trace.index;
                const len = @min(es.trace_addrs.len, src_trace.instruction_addresses.len);
                @memcpy(es.trace_addrs[0..len], src_trace.instruction_addresses[0..len]);
            }
            _ = sdl.SDL_SetAtomicInt(&es.status, status_stored);
        }
        return sdl.SDL_APP_FAILURE;
    }

    fn load(es: *ErrorStore) ?anyerror {
        if (sdl.SDL_GetAtomicInt(&es.status) != status_stored) return null;
        if (@errorReturnTrace()) |dst_trace| {
            dst_trace.index = es.trace_index;
            const len = @min(dst_trace.instruction_addresses.len, es.trace_addrs.len);
            @memcpy(dst_trace.instruction_addresses[0..len], es.trace_addrs[0..len]);
        }
        return es.err;
    }
};
