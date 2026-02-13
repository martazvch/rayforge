const std = @import("std");
const Allocator = std.mem.Allocator;
const ArrayList = std.ArrayListUnmanaged;
const Set = @import("set.zig").Set;

pub const Id = enum(u16) {
    zero,
    _,

    pub fn fromInt(i: usize) Id {
        return @enumFromInt(i);
    }
    pub fn toInt(self: Id) u16 {
        return @intFromEnum(self);
    }
};

pub const Kind = union(enum) {
    object: Object,
    sdf: Sdf,

    pub const Object = struct {
        children: Set(Id),
        selected_sdf: ?Id,

        pub const empty: Object = .{
            .children = .empty,
            .selected_sdf = null,
        };
    };

    pub const Sdf = struct {
        node_id: Id,
        shader_id: usize,

        pub const empty: Sdf = .{
            .node_id = .zero,
            .shader_id = 0,
        };
    };
};

const Self = @This();
pub const name_size = 64;

name: [name_size:0]u8,
kind: Kind,
parent: ?Id,
visible: bool,
prev_visible: bool,

pub const root: Self = .{
    .name = @splat(0),
    .kind = .{ .object = .empty },
    .parent = null,
    .visible = true,
    .prev_visible = true,
};
