const c = @import("c");
const sdl = c.sdl;
const gui = c.gui;
const img = c.img;
const fatal = @import("utils.zig").fatal;

texture: *sdl.SDL_GPUTexture,
width: usize,
height: usize,

const Self = @This();

pub fn load(device: *sdl.SDL_GPUDevice, comptime path: []const u8) Self {
    const data = @embedFile(path);

    var w: c_int = 0;
    var h: c_int = 0;
    var channels: c_int = 0;
    const pixels = img.stbi_load_from_memory(
        data,
        @intCast(data.len),
        &w,
        &h,
        &channels,
        4, // force RGBA
    ) orelse fatal("failed to load texture: {s}", .{path});
    defer img.stbi_image_free(pixels);

    const width: u32 = @intCast(w);
    const height: u32 = @intCast(h);
    const data_size: u32 = width * height * 4;

    const texture = sdl.SDL_CreateGPUTexture(device, &.{
        .type = sdl.SDL_GPU_TEXTURETYPE_2D,
        .format = sdl.SDL_GPU_TEXTUREFORMAT_R8G8B8A8_UNORM,
        .width = width,
        .height = height,
        .layer_count_or_depth = 1,
        .num_levels = 1,
        .sample_count = sdl.SDL_GPU_SAMPLECOUNT_1,
        .usage = sdl.SDL_GPU_TEXTUREUSAGE_SAMPLER,
        .props = 0,
    }) orelse fatal("failed to create GPU texture for: {s}", .{path});

    const transfer_buf = sdl.SDL_CreateGPUTransferBuffer(device, &.{
        .size = data_size,
        .usage = sdl.SDL_GPU_TRANSFERBUFFERUSAGE_UPLOAD,
    }) orelse fatal("failed to create transfer buffer for texture loading", .{});
    defer sdl.SDL_ReleaseGPUTransferBuffer(device, transfer_buf);

    const dest: [*]u8 = @ptrCast(sdl.SDL_MapGPUTransferBuffer(
        device,
        transfer_buf,
        false,
    ) orelse fatal("failed to map transfer buffer for texture loading", .{}));
    @memcpy(dest[0..data_size], @as([*]const u8, @ptrCast(pixels))[0..data_size]);
    sdl.SDL_UnmapGPUTransferBuffer(device, transfer_buf);

    const cmd = sdl.SDL_AcquireGPUCommandBuffer(device) orelse fatal("failed to acquire command buffer for texture loading", .{});
    const pass = sdl.SDL_BeginGPUCopyPass(cmd) orelse fatal("failed to begin copy pass for texture loading", .{});

    sdl.SDL_UploadToGPUTexture(
        pass,
        &.{
            .transfer_buffer = transfer_buf,
            .offset = 0,
        },
        &.{
            .texture = texture,
            .w = width,
            .h = height,
            .d = 1,
        },
        false,
    );

    sdl.SDL_EndGPUCopyPass(pass);
    _ = sdl.SDL_SubmitGPUCommandBuffer(cmd);

    return .{
        .texture = texture,
        .width = width,
        .height = height,
    };
}

pub fn toImGuiRef(self: Self) gui.ImTextureRef {
    return .{
        ._TexData = null, // not used for user-defined texures
        ._TexID = @intFromPtr(self.texture),
    };
}
