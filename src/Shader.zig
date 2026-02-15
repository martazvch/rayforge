const std = @import("std");
const Allocator = std.mem.Allocator;
const builtin = @import("builtin");
const sdl = @import("c").sdl;
const fatal = @import("utils.zig").fatal;

vert: *sdl.SDL_GPUShader,
frag: *sdl.SDL_GPUShader,

const Self = @This();

pub const format = switch (builtin.os.tag) {
    .linux => sdl.SDL_GPU_SHADERFORMAT_SPIRV,
    .macos => sdl.SDL_GPU_SHADERFORMAT_MSL,
    .windows => sdl.SDL_GPU_SHADERFORMAT_DXIL,
    else => |os| fatal("unsupported OS: {}", .{os}),
};

const extension = switch (builtin.os.tag) {
    .linux => "spv",
    .macos => "msl",
    .windows => "dxil",
    else => @compileError("OS not supported"),
};

pub fn init(device: *sdl.SDL_GPUDevice, allocator: Allocator, comptime name: []const u8) Self {
    return .{
        .vert = createShader(device, allocator, name, .vert),
        .frag = createShader(device, allocator, name, .frag),
    };
}

pub fn deinit(self: *Self, device: *sdl.SDL_GPUDevice) void {
    sdl.SDL_ReleaseGPUShader(device, self.vert);
    sdl.SDL_ReleaseGPUShader(device, self.frag);
}

const Stage = enum {
    vert,
    frag,
};
const ShaderInfo = struct {
    samplers: u32,
    storage_textures: u32,
    storage_buffers: u32,
    uniform_buffers: u32,
    inputs: []const Input,
    outputs: []const Output,

    const Input = struct {
        name: []const u8,
        type: []const u8,
        location: u32,
    };
    const Output = struct {
        name: []const u8,
        type: []const u8,
        location: u32,
    };
};

fn createShader(device: *sdl.SDL_GPUDevice, allocator: Allocator, comptime name: []const u8, comptime stage: Stage) *sdl.SDL_GPUShader {
    const code_path = comptime getPath(name, extension, stage);
    const code = @embedFile(code_path);

    const json_path = comptime getPath(name, "json", stage);
    const json = @embedFile(json_path);

    const info = std.json.parseFromSlice(ShaderInfo, allocator, json, .{ .allocate = .alloc_if_needed }) catch {
        fatal("Unable to fetch metadata for shader at: {s}", .{json_path});
    };
    defer info.deinit();

    var shader_info: sdl.SDL_GPUShaderCreateInfo = .{
        .code = code,
        .code_size = code.len,
        // Metal specific entrypoint
        .entrypoint = if (builtin.os.tag == .macos) "main0" else "main",
        .format = format,
        .stage = if (stage == .vert) sdl.SDL_GPU_SHADERSTAGE_VERTEX else sdl.SDL_GPU_SHADERSTAGE_FRAGMENT,
        .num_samplers = info.value.samplers,
        .num_storage_buffers = info.value.storage_buffers,
        .num_storage_textures = info.value.storage_textures,
        .num_uniform_buffers = info.value.uniform_buffers,
    };

    return sdl.SDL_CreateGPUShader(device, &shader_info) orelse {
        fatal("failed to create {t} shader {s}: {s}", .{ stage, code_path, sdl.SDL_GetError() });
    };
}

fn getPath(comptime name: []const u8, comptime ext: []const u8, comptime stage: Stage) []const u8 {
    return "shaders/" ++ ext ++ "/" ++ name ++ "." ++ @tagName(stage) ++ "." ++ ext;
}
