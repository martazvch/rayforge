const c = @import("c");
const sdl = c.sdl;
const m = @import("math.zig").math;
const Camera = @import("Camera.zig");
const sdf = @import("sdf.zig");
const Sdf = sdf.Sdf;

data: Data,
objects: [MAX_OBJECTS]Object,
selected: ?usize,

const Self = @This();
const MAX_OBJECTS = 32;

pub const Data = extern struct {
    count: u32,
    _pad: [3]u32 = undefined,
    sdfs: [MAX_OBJECTS]Sdf,

    pub const empty: Data = .{
        .count = 0,
        .sdfs = undefined,
    };
};

const Object = struct {
    name: [name_size]u8 = @splat(0),
    index: usize,
    properties: Properties,

    pub const name_size = 64;
};

const Properties = struct {
    transform: m.Vec3,
    scale: m.Vec3,
    rotation: m.Vec3,

    pub const init: Properties = .{
        .transform = .zero,
        .scale = .one,
        .rotation = .zero,
    };
};

pub fn init() Self {
    return .{
        .data = .empty,
        .selected = null,
        .objects = undefined,
    };
}

pub fn getSelectedSdf(self: *Self) ?*Sdf {
    return &self.data.sdfs[
        self.selected orelse return null
    ];
}

pub fn getSelectedObj(self: *Self) ?*Object {
    return &self.objects[
        self.selected orelse return null
    ];
}

pub fn addObject(self: *Self, name: []const u8, kind: sdf.Kind, params: m.Vec4) void {
    self.data.sdfs[self.data.count] = .{
        .position = .zero,
        .kind = kind,
        .params = params,
        .color = .new(1.0, 1.0, 1.0),
        .op = if (self.data.count == 0) .none else .union_op,
        .smooth_factor = 0.5,
        .visible = true,
    };
    self.objects[self.data.count] = .{
        .index = self.data.count,
        .properties = .init,
    };
    @memcpy(self.objects[self.data.count].name[0..name.len], name);
    self.data.count += 1;
}

pub fn raymarch(self: *const Self, ro: m.Vec3, rd: m.Vec3) ?usize {
    var dist: f32 = 0.0;
    var index: ?usize = null;

    const iterations = 80;

    for (0..iterations) |_| {
        const p = ro.add(rd.scale(dist));

        var result_dist: f32 = 100.0;
        var result_index: ?usize = null;

        for (0..self.data.count) |i| {
            const obj = &self.data.sdfs[i];

            if (!obj.visible) {
                continue;
            }

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
    self.addObject("Sphere", .sphere, .new(1.0, 0.0, 0.0, 0.0));
    self.addObject("Sphere", .sphere, .new(1.0, 0.0, 0.0, 0.0));

    // self.data.sdfs[0] = .{
    //     .position = .new(0.0, 2.0, -5.0),
    //     .kind = .sphere,
    //     .params = .new(1.0, 0.0, 0.0, 0.0), // Radius 1
    //     .color = .new(1.0, 1.0, 1.0),
    //     .op = .none, // First object should use none
    //     .smooth_factor = 0.0,
    // };
    // self.data.count += 1;

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
