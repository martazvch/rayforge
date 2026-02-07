const c = @import("c");
const sdl = c.sdl;
const m = @import("math.zig").math;
const Camera = @import("Camera.zig");
const Object = @import("object.zig").Object;

data: Data,
obj_selected: ?usize,

const Self = @This();

const MAX_OBJECTS = 32;

pub const Data = extern struct {
    object_count: u32,
    _pad: [3]u32 = undefined,
    objects: [MAX_OBJECTS]Object,

    pub const empty: Data = .{
        .object_count = 0,
        .objects = undefined,
    };
};

pub fn init() Self {
    return .{
        .data = .empty,
        .obj_selected = null,
    };
}

pub fn selected(self: *const Self) ?*const Object {
    return &self.data.objects[
        self.obj_selected orelse return null
    ];
}

pub fn raymarch(self: *const Self, ro: m.Vec3, rd: m.Vec3) ?usize {
    var dist: f32 = 0.0;
    var index: ?usize = null;

    const iterations = 80;

    for (0..iterations) |_| {
        const p = ro.add(rd.scale(dist));

        var result_dist: f32 = 100.0;
        var result_index: ?usize = null;

        for (0..self.data.object_count) |i| {
            const obj = &self.data.objects[i];
            const d = obj.evaluateSDF(p);

            if (d < result_dist) {
                result_dist = d;
                result_index = i;
            }
        }

        dist += result_dist;
        index = result_index;

        if (dist > 100 or result_dist < 0.001) {
            break;
        }
    }

    if (dist < 100.0) {
        return index;
    }

    return null;
}

pub fn debug(self: *Self) void {
    self.data.objects[0] = .{
        .position = .new(0.0, 2.0, -5.0),
        .kind = .sphere,
        .params = .new(1.0, 0.0, 0.0, 0.0), // Radius 1
        .color = .new(1.0, 1.0, 1.0),
        .op = .none, // First object should use none
        .smooth_factor = 0.0,
    };
    self.data.object_count += 1;

    // self.data.objects[1] = .{
    //     .position = .new(1.0, 1.0, -5.0),
    //     .sdf_type = @intFromEnum(Type.box),
    //     .params = .new(0.8, 0.8, 0.8, 0.0), // Half-extents of 0.8
    //     // .color = .new(0.0, 1.0, 0.0),
    //     .color = .new(1.0, 1.0, 1.0),
    //     .operation = @intFromEnum(Op.smooth_union), // Union with previous objects
    //     .smooth_factor = 0.8,
    // };
    // self.data.object_count += 1;
}
