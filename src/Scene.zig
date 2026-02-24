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
const Node = @import("Node.zig");
const globals = @import("globals.zig");

arena: std.heap.ArenaAllocator,
allocator: Allocator,
indices: ArrayList(u32),
tombstones: ArrayList(u32),
sdfs: [max_obj]Sdf,
sdf_meta: [max_obj]sdf.Meta,
nodes: ArrayList(Node),
selected: ?Node.Id,
current_obj: Node.Id,

const Self = @This();
pub const max_obj = 32;

pub fn init(allocator: Allocator) Self {
    return .{
        .arena = .init(allocator),
        .allocator = undefined,
        .indices = .empty,
        .tombstones = .empty,
        .sdfs = undefined,
        .sdf_meta = undefined,
        .nodes = .empty,
        .selected = null,
        .current_obj = .root,
    };
}

pub fn deinit(self: *Self) void {
    self.arena.deinit();
}

/// Post-initialize the scene
pub fn postInit(self: *Self) void {
    self.allocator = self.arena.allocator();

    self.nodes.append(self.allocator, .root) catch oom();
    self.addObject();
}

pub fn nodeKind(self: *Self, id: Node.Id) Node.Kind {
    return self.getNode(id).kind;
}

pub fn nodeKindPtr(self: *Self, id: Node.Id) *Node.Kind {
    return &self.getNode(id).kind;
}

pub fn selectNode(self: *Self, id: Node.Id) void {
    self.selected = id;

    if (self.nodeKind(id) == .object) {
        self.current_obj = id;
    }
}

pub fn getSelectedSdf(self: *Self) ?*Sdf {
    const node = self.selected orelse return null;
    return switch (self.nodeKind(node)) {
        .sdf => |sdf_node| &self.sdfs[sdf_node.shader_id],
        else => null,
    };
}

pub fn getSelectedSdfMeta(self: *Self) ?*sdf.Meta {
    const node = self.selected orelse return null;
    return switch (self.nodeKind(node)) {
        .sdf => |sdf_node| &self.sdf_meta[sdf_node.shader_id],
        else => null,
    };
}

pub fn getCurrentObj(self: *Self) *Node.Kind.Object {
    return &self.getNode(self.current_obj).kind.object;
}

pub fn addObject(self: *Self) void {
    const obj = self.getCurrentObj();

    var new_obj: Node = .{
        .name = @splat(0),
        .kind = .{ .object = .{
            .children = .empty,
            .selected_sdf = null,
        } },
        .parent = self.current_obj,
        .visible = true,
        .prev_visible = true,
    };

    _ = std.fmt.bufPrint(&new_obj.name, "object", .{}) catch oom();

    {
        errdefer oom();
        try obj.children.add(self.allocator, .fromInt(self.nodes.items.len));
        try self.nodes.append(self.allocator, new_obj);
    }

    self.current_obj = .fromInt(self.nodes.items.len - 1);
    self.selected = self.current_obj;
}

pub fn addSdf(self: *Self, kind: sdf.Kind) void {
    const node_id: Node.Id = .fromInt(self.nodes.items.len);
    const shader_id = self.newSdfIndex();
    const parent = self.getCurrentObj();

    const params: m.Vec4 = switch (kind) {
        .sphere => .new(1.0, 0.0, 0.0, 0.0),
        .box => .new(1.0, 1.0, 1.0, 0.0),
        .cylinder => .new(1.0, 1.0, 0.0, 0.0),
        .torus => .new(1.0, 0.3, 0.0, 0.0),
    };

    // Centers the object where camera is looking
    var transform: m.Mat4 = .identity;
    const pivot = globals.camera.pivot;
    transform.fields[3][0] = pivot.x;
    transform.fields[3][1] = pivot.y;
    transform.fields[3][2] = pivot.z;

    self.sdfs[shader_id] = .{
        .transform = transform,
        .params = params,
        .scale = 1,
        .kind = kind,
        .op = .union_op,
        .smooth_factor = 0.5,
        .visible = true,
        .color = .new(1.0, 1.0, 1.0),
        .obj_id = self.current_obj.toInt(),
        .pad = undefined,
    };
    self.sdf_meta[shader_id] = .{
        .name = @splat(0),
        .rotation = .zero,
        .visible = true,
    };

    const name = @tagName(kind);
    @memcpy(self.sdf_meta[shader_id].name[0..name.len], name);

    var new_obj: Node = .{
        .name = @splat(0),
        .kind = .{ .sdf = .{
            .node_id = node_id,
            .shader_id = shader_id,
        } },
        .parent = self.current_obj,
        .visible = true,
        .prev_visible = true,
    };

    _ = std.fmt.bufPrint(&new_obj.name, "{t}", .{kind}) catch oom();

    parent.children.add(self.allocator, node_id) catch oom();
    self.nodes.append(self.allocator, new_obj) catch oom();
    self.selected = node_id;
}

fn newSdfIndex(self: *Self) u32 {
    if (self.tombstones.pop()) |index| {
        self.indices.append(self.allocator, index) catch oom();
        return index;
    }

    // TODO: proper logging
    const count = self.indices.items.len;
    if (count == max_obj) {
        std.debug.print("reached maximum object count limit in the scene: {}", .{max_obj});
    }

    self.indices.append(self.allocator, @intCast(count)) catch oom();

    return @intCast(count);
}

pub fn sdfCount(self: *const Self) u32 {
    return @intCast(self.indices.items.len);
}

pub fn getNode(self: *Self, id: Node.Id) *Node {
    return &self.nodes.items[id.toInt()];
}

fn getShaderSdfFromIndex(self: *Self, id: Node.Id) *Sdf {
    const node = self.nodeKind(id).sdf;
    return self.getShaderSdfFromNode(node);
}

fn getShaderSdfFromNode(self: *Self, sdf_node: Node.Kind.Sdf) *Sdf {
    return &self.sdfs[sdf_node.shader_id];
}

/// Parent is assumed to be an object
pub fn reparent(self: *Self, item: Node.Id, parent: Node.Id) void {
    const item_node = self.getNode(item);

    if (item_node.parent == parent) {
        return;
    }

    const old_parent = self.getNode(item_node.parent);
    _ = old_parent.kind.object.children.remove(item);

    item_node.parent = parent;

    switch (item_node.kind) {
        .sdf => |sdf_node| {
            self.getShaderSdfFromNode(sdf_node).obj_id = parent.toInt();
        },
        .object => {},
    }

    self.nodeKindPtr(parent).object.children.add(self.allocator, item) catch oom();
}

/// Reorder `child_id` to be placed before `prev_id` within the same parent.
pub fn reorder(self: *Self, parent: Node.Id, prev_id: Node.Id, child: Node.Id) void {
    if (child == prev_id) return;

    var children = &self.getNode(parent).kind.object.children;
    const keys = children.keys();

    const new_index = children.getIndex(child).?;
    const prev_index = children.getIndex(prev_id).?;

    keys[prev_index] = child;
    keys[new_index] = prev_id;

    var old_sdf = self.nodeKind(prev_id).sdf;
    var new_sdf = self.nodeKind(child).sdf;

    const tmp = old_sdf.shader_id;
    old_sdf.shader_id = new_sdf.shader_id;
    new_sdf.shader_id = tmp;
}

pub fn delete(self: *Self, id: Node.Id) void {
    const node = self.getNode(id);
    var parent = &self.getNode(node.parent).kind.object;
    _ = parent.children.remove(id);

    const index = switch (node.kind) {
        .sdf => |s| s.shader_id,
        .object => |obj| {
            const count: usize = obj.children.count();
            for (0..count) |i| {
                self.delete(obj.children.keys()[count - i - 1]);
            }
            self.current_obj = node.parent;
            return;
        },
    };
    _ = self.indices.orderedRemove(index);
    self.tombstones.append(self.allocator, @intCast(index)) catch oom();

    if (self.selected) |selected| {
        if (selected == id) {
            self.selected = null;
        }
    }
}

// TODO: add operations?
pub fn raymarch(self: *Self, ro: m.Vec3, rd: m.Vec3) ?Node.Kind.Sdf {
    var dist: f32 = 0.0;
    var hit_node: ?Node.Kind.Sdf = null;

    const iterations = 40;

    for (0..iterations) |_| {
        const p = ro.add(rd.scale(dist));
        const res = self.raymarchObj(&self.nodes.items[0].kind.object, p);

        dist += res.d;
        hit_node = res.sdf;

        if (dist > 100 or res.d < 0.001) {
            break;
        }
    }

    if (dist < 100.0) {
        return hit_node;
    }

    return null;
}

const RaymarchRes = struct {
    d: f32,
    sdf: Node.Kind.Sdf,
};
fn raymarchObj(self: *Self, obj: *const Node.Kind.Object, p: m.Vec3) RaymarchRes {
    var d: f32 = 100;
    var sdf_res: Node.Kind.Sdf = .empty;

    for (obj.children.keys()) |id| {
        const node = self.getNode(id);

        if (!node.visible) {
            continue;
        }

        const res: RaymarchRes = switch (node.kind) {
            .object => |*child_obj| self.raymarchObj(child_obj, p),
            .sdf => |sdf_node| self.raymarchSdf(sdf_node, p),
        };

        const prev = d;
        if (res.d < prev) {
            d = res.d;
            sdf_res = res.sdf;
        }
    }

    return .{ .d = d, .sdf = sdf_res };
}

fn raymarchSdf(self: *Self, sdf_node: Node.Kind.Sdf, p: m.Vec3) RaymarchRes {
    const sdf_shader = &self.sdfs[sdf_node.shader_id];
    return .{ .d = sdf_shader.evaluateSDF(p), .sdf = sdf_node };
}

pub fn debug(self: *Self) void {
    self.current_obj = .fromInt(1);
    self.addSdf(.box);
    self.debugSetLastPos(.new(-5, 0, 0));

    self.addObject();
    self.current_obj = .fromInt(3);
    self.addSdf(.box);
    self.addSdf(.sphere);
    self.debugSetLastPos(.new(0, 2, 0));

    self.current_obj = .fromInt(0);
    self.addObject();
    self.current_obj = .fromInt(6);
    self.addSdf(.torus);
    self.debugSetLastPos(.new(5, 0, 0));

    self.current_obj = .fromInt(0);
    self.addSdf(.cylinder);
    self.debugSetLastPos(.new(0, 0, -8));

    self.current_obj = .fromInt(0);
    self.addObject();

    // self.serialize();
}

fn debugSetLastPos(self: *Self, pos: m.Vec3) void {
    self.debugSetPos(self.indices.getLast(), pos);
}

fn debugSetPos(self: *Self, index: usize, pos: m.Vec3) void {
    const transform = &self.sdfs[index].transform;

    transform.fields[3][0] = pos.x;
    transform.fields[3][1] = pos.y;
    transform.fields[3][2] = pos.z;
}

fn serialize(self: *const Self) void {
    errdefer oom();

    const stringify = std.json.fmt(.{ .nodes = self.nodes.items }, .{});
    std.log.debug("String: {any}", .{stringify.value});

    var buf: [1024]u8 = undefined;
    var w = std.fs.File.stdout().writer(&buf);
    const ww = &w.interface;
    std.log.debug("String: {any}", .{stringify.format(ww)});
}
