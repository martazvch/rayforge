const std = @import("std");
const Allocator = std.mem.Allocator;
const Scene = @import("Scene.zig");
const Node = @import("Node.zig");
const sdf = @import("sdf.zig");
const m = @import("math.zig").zlm;
const Set = @import("set.zig").Set;
const fatal = @import("utils.zig").fatal;

const SavedObject = struct {
    children: []const u16,
};

const SavedSdfNode = struct {
    node_id: u16,
    shader_id: u32,
};

const SavedNodeKind = union(enum) {
    object: SavedObject,
    sdf: SavedSdfNode,
};

const SavedNode = struct {
    name: []const u8,
    kind: SavedNodeKind,
    parent: u16,
    visible: bool,
};

const SavedSdf = struct {
    transform: [16]f32,
    params: [4]f32,
    kind: sdf.Kind,
    op: sdf.Op,
    smooth_factor: f32,
    scale: f32,
    color: [3]f32,
    visible: bool,
    obj_id: u32,
};

const SavedSdfMeta = struct {
    rotation: [3]f32,
};

const SavedScene = struct {
    nodes: []const SavedNode,
    sdfs: []const SavedSdf,
    sdf_meta: []const SavedSdfMeta,
    sdf_indices: []const u32,
    tombstones: []const u32,
    selected: ?u16,
};

pub fn serialize(scene: *const Scene, path: []const u8) void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    serializeInner(arena.allocator(), scene, path) catch |e| {
        fatal("Failed to save scene: {}", .{e});
    };
}

fn serializeInner(allocator: Allocator, scene: *const Scene, path: []const u8) !void {
    // Build node DTOs
    const saved_nodes = try allocator.alloc(SavedNode, scene.nodes.items.len);
    for (scene.nodes.items, saved_nodes) |*node, *saved| {
        const children = blk: {
            const obj = switch (node.kind) {
                .object => |o| o,
                .sdf => break :blk &[_]u16{},
            };
            const ids = try allocator.alloc(u16, obj.children.count());
            for (obj.children.keys(), ids) |id, *c| c.* = id.toInt();
            break :blk ids;
        };

        saved.* = .{
            .name = std.mem.sliceTo(&node.name, 0),
            .parent = node.parent.toInt(),
            .visible = node.visible,
            .kind = switch (node.kind) {
                .object => .{ .object = .{ .children = children } },
                .sdf => |s| .{ .sdf = .{
                    .node_id = s.node_id.toInt(),
                    .shader_id = @intCast(s.shader_id),
                } },
            },
        };
    }

    // Build sdf DTOs
    const saved_sdfs = try allocator.alloc(SavedSdf, scene.sdfs.items.len);
    for (scene.sdfs.items, saved_sdfs) |s, *saved| {
        var transform: [16]f32 = undefined;
        for (0..4) |row| for (0..4) |col| {
            transform[row * 4 + col] = s.transform.fields[row][col];
        };
        saved.* = .{
            .transform = transform,
            .params = .{ s.params.x, s.params.y, s.params.z, s.params.w },
            .kind = s.kind,
            .op = s.op,
            .smooth_factor = s.smooth_factor,
            .scale = s.scale,
            .color = .{ s.color.x, s.color.y, s.color.z },
            .visible = s.visible == 1,
            .obj_id = s.obj_id,
        };
    }

    // Build sdf_meta DTOs
    const saved_meta = try allocator.alloc(SavedSdfMeta, scene.sdf_meta.items.len);
    for (scene.sdf_meta.items, saved_meta) |sm, *saved| {
        saved.rotation = .{ sm.rotation.x, sm.rotation.y, sm.rotation.z };
    }

    const saved_scene: SavedScene = .{
        .nodes = saved_nodes,
        .sdfs = saved_sdfs,
        .sdf_meta = saved_meta,
        .sdf_indices = scene.sdf_indices.items,
        .tombstones = scene.tombstones.items,
        .selected = if (scene.selected) |s| s.toInt() else null,
    };

    const file = try std.fs.cwd().createFile(path, .{});
    defer file.close();

    const stringify = std.json.fmt(saved_scene, .{ .whitespace = .indent_4 });

    var buf: [10_000]u8 = undefined;
    var w = file.writer(&buf);
    const ww = &w.interface;
    try stringify.format(ww);
    try file.writeAll(ww.buffered());
}

pub fn deserialize(scene: *Scene, path: []const u8) void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    deserializeInner(arena.allocator(), scene, path) catch |e| {
        fatal("Failed to load scene: {}", .{e});
    };
}

fn deserializeInner(allocator: Allocator, scene: *Scene, path: []const u8) !void {
    const file = try std.fs.cwd().openFile(path, .{});
    defer file.close();

    const content = try file.readToEndAlloc(allocator, 10 * 1024 * 1024);
    const parsed = try std.json.parseFromSlice(SavedScene, allocator, content, .{});
    defer parsed.deinit();
    const saved = parsed.value;

    // Reset scene state, keeping the underlying arena allocator alive
    _ = scene.arena.reset(.retain_capacity);
    scene.allocator = scene.arena.allocator();
    scene.sdfs = .empty;
    scene.sdf_meta = .empty;
    scene.sdf_indices = .empty;
    scene.nodes = .empty;
    scene.tombstones = .empty;
    scene.selected = null;

    // Rebuild nodes
    try scene.nodes.ensureTotalCapacity(scene.allocator, saved.nodes.len);
    for (saved.nodes) |saved_node| {
        var node: Node = undefined;
        node.name = @splat(0);
        const name = saved_node.name[0..@min(saved_node.name.len, Node.name_size)];
        @memcpy(node.name[0..name.len], name);
        node.parent = .fromInt(saved_node.parent);
        node.visible = saved_node.visible;
        node.prev_visible = saved_node.visible;
        node.kind = switch (saved_node.kind) {
            .object => |o| blk: {
                var children: Set(Node.Id) = .empty;
                try children.ensureUnused(scene.allocator, o.children.len);
                for (o.children) |c| children.addAssume(.fromInt(c));
                break :blk .{ .object = .{ .children = children, .selected_sdf = null } };
            },
            .sdf => |s| .{ .sdf = .{
                .node_id = .fromInt(s.node_id),
                .shader_id = s.shader_id,
            } },
        };
        scene.nodes.appendAssumeCapacity(node);
    }

    // Rebuild sdfs
    try scene.sdfs.ensureTotalCapacity(scene.allocator, saved.sdfs.len);
    for (saved.sdfs) |s| {
        var transform: m.Mat4 = undefined;
        for (0..4) |row| for (0..4) |col| {
            transform.fields[row][col] = s.transform[row * 4 + col];
        };
        scene.sdfs.appendAssumeCapacity(.{
            .transform = transform,
            .params = .new(s.params[0], s.params[1], s.params[2], s.params[3]),
            .kind = s.kind,
            .op = s.op,
            .smooth_factor = s.smooth_factor,
            .scale = s.scale,
            .color = .new(s.color[0], s.color[1], s.color[2]),
            .visible = @intFromBool(s.visible),
            .obj_id = s.obj_id,
            .pad = undefined,
        });
    }

    // Rebuild sdf_meta
    try scene.sdf_meta.ensureTotalCapacity(scene.allocator, saved.sdf_meta.len);
    for (saved.sdf_meta) |sm| {
        scene.sdf_meta.appendAssumeCapacity(.{
            .rotation = .new(sm.rotation[0], sm.rotation[1], sm.rotation[2]),
        });
    }

    try scene.sdf_indices.appendSlice(scene.allocator, saved.sdf_indices);
    try scene.tombstones.appendSlice(scene.allocator, saved.tombstones);
    scene.selected = if (saved.selected) |s| .fromInt(s) else null;
}
