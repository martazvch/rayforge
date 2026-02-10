const std = @import("std");
const Allocator = std.mem.Allocator;
const ArrayList = std.ArrayListUnmanaged;
const c = @import("c");
const sdl = c.sdl;
const m = @import("math.zig").zlm;
const Camera = @import("Camera.zig");
const sdf = @import("sdf.zig");
const Sdf = sdf.Sdf;
const oom = @import("utils.zig").oom;

arena: std.heap.ArenaAllocator,
allocator: Allocator,
shader_data: ShaderSdfData,
sdf_meta: [max_obj]SdfMeta,
objects: ArrayList(Object),
selected_sdf: ?usize,
selected_obj: usize,

const Self = @This();
const max_obj = 32;
pub const name_size = 64;

pub const ShaderSdfData = extern struct {
    count: u32,
    _pad: [3]u32 = undefined,
    sdfs: [max_obj]Sdf,

    pub const empty: ShaderSdfData = .{
        .count = 0,
        .sdfs = undefined,
    };
};

pub const SdfMeta = struct {
    name: [name_size:0]u8,
    rotation: m.Vec3,
    visible: bool,
};

pub const Object = struct {
    name: [name_size:0]u8,
    sdfs: ArrayList(usize),
    visible: bool,

    pub const empty: Object = .{
        .name = @splat(0),
        .sdfs = .empty,
        .visible = true,
    };

    pub fn deinit(self: *Object, allocator: Allocator) void {
        self.sdfs.deinit(allocator);
    }
};

pub fn init(allocator: Allocator) Self {
    return .{
        .arena = .init(allocator),
        .allocator = undefined,
        .shader_data = .empty,
        .sdf_meta = undefined,
        .objects = .empty,
        .selected_sdf = null,
        .selected_obj = 0,
    };
}

pub fn deinit(self: *Self) void {
    self.arena.deinit();
}

pub fn createAlloc(self: *Self) void {
    self.allocator = self.arena.allocator();
    self.addObject("root");
}

pub fn getSelectedSdf(self: *Self) ?*Sdf {
    return &self.shader_data.sdfs[
        self.selected_sdf orelse return null
    ];
}

pub fn getSelectedSdfMeta(self: *Self) ?*SdfMeta {
    return &self.sdf_meta[
        self.selected_sdf orelse return null
    ];
}

pub fn getSelectedObj(self: *Self) *Object {
    return &self.objects.items[self.selected_obj];
}

pub fn addObject(self: *Self, name: []const u8) void {
    var obj: Object = .empty;
    @memcpy(obj.name[0..name.len], name);
    self.objects.append(self.allocator, obj) catch oom();
}

pub fn addSdf(self: *Self, name: []const u8, kind: sdf.Kind, params: m.Vec4) void {
    self.shader_data.sdfs[self.shader_data.count] = .{
        .transform = .identity,
        .params = params,
        .scale = 1,
        .kind = kind,
        .op = if (self.shader_data.count == 0) .none else .union_op,
        .smooth_factor = 0.5,
        .visible = true,
        .color = .new(1.0, 1.0, 1.0),
    };
    self.sdf_meta[self.shader_data.count] = .{
        .name = @splat(0),
        .rotation = .zero,
        .visible = true,
    };
    @memcpy(self.sdf_meta[self.shader_data.count].name[0..name.len], name);

    self.getSelectedObj().sdfs.append(self.allocator, self.shader_data.count) catch oom();
    self.shader_data.count += 1;
}

pub fn raymarch(self: *const Self, ro: m.Vec3, rd: m.Vec3) ?usize {
    var dist: f32 = 0.0;
    var index: ?usize = null;

    const iterations = 80;

    for (0..iterations) |_| {
        const p = ro.add(rd.scale(dist));

        var result_dist: f32 = 100.0;
        var result_index: ?usize = null;

        for (0..self.shader_data.count) |i| {
            const obj = &self.shader_data.sdfs[i];

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
    self.addSdf("sphere", .sphere, .new(1.0, 0.0, 0.0, 0.0));
    self.addSdf("box", .box, .new(1.0, 1.0, 1.0, 0.0));
}
