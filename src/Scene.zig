const c = @import("c");
const sdl = c.sdl;
const m = @import("math.zig").math;
const Camera = @import("Camera.zig");

camera: Camera,
data: Data,

const Self = @This();

const MAX_OBJECTS = 32;

const Type = enum(u32) {
    sphere,
    box,
    torus,
    cylinder,
};

const Op = enum(u32) {
    none,
    union_op,
    subtract,
    intersect,
    smooth_union,
    smooth_subtract,
    smooth_intersect,
};

pub const SDFObject = extern struct {
    position: m.Vec3,
    sdf_type: u32,

    params: m.Vec4,

    color: m.Vec3,
    operation: u32,

    smooth_factor: f32,
    _pad: [3]f32 = undefined,
};

pub const Data = extern struct {
    object_count: u32,
    _pad: [3]u32 = undefined,
    objects: [MAX_OBJECTS]SDFObject,

    pub const empty: Data = .{
        .object_count = 0,
        .objects = undefined,
    };
};

pub fn init() Self {
    return .{
        .data = .empty,
        .camera = .init(.new(0.0, 2.0, 3.0), 20),
    };
}

pub fn debug(self: *Self) void {
    self.data.objects[0] = .{
        .position = .new(0.0, 1.0, -5.0), // In front of camera
        .sdf_type = @intFromEnum(Type.sphere),
        .params = .new(1.0, 0.0, 0.0, 0.0), // Radius 1
        .color = .new(1.0, 0.0, 0.0),
        .operation = @intFromEnum(Op.none), // First object should use none
        .smooth_factor = 0.0,
    };
    self.data.object_count += 1;

    self.data.objects[1] = .{
        .position = .new(1.0, 1.0, -5.0), // Next to sphere
        .sdf_type = @intFromEnum(Type.box),
        .params = .new(0.8, 0.8, 0.8, 0.0), // Half-extents of 0.8
        .color = .new(0.0, 1.0, 0.0),
        .operation = @intFromEnum(Op.smooth_union), // Union with previous objects
        .smooth_factor = 0.8,
    };
    self.data.object_count += 1;
}
