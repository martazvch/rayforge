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
const Serializer = @import("Serializer.zig");

arena: std.heap.ArenaAllocator,
allocator: Allocator,
sdfs: ArrayList(Sdf),
sdf_meta: ArrayList(sdf.Meta),
/// Sdf indices grouped by object id
sdf_indices: ArrayList(u32),
nodes: ArrayList(Node),
tombstones: ArrayList(u32),
selected: ?Node.Id,

const Self = @This();
pub const max_obj = 32;

pub fn init(allocator: Allocator) Self {
    return .{
        .arena = .init(allocator),
        .allocator = undefined,
        .sdfs = .empty,
        .sdf_meta = .empty,
        .sdf_indices = .empty,
        .nodes = .empty,
        .tombstones = .empty,
        .selected = null,
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
}

pub fn getSelectedSdf(self: *Self) ?*Sdf {
    const node = self.selected orelse return null;
    return switch (self.nodeKind(node)) {
        .sdf => |sdf_node| &self.sdfs.items[sdf_node.shader_id],
        else => null,
    };
}

pub fn getSelectedSdfMeta(self: *Self) ?*sdf.Meta {
    const node = self.selected orelse return null;
    return switch (self.nodeKind(node)) {
        .sdf => |sdf_node| &self.sdf_meta.items[sdf_node.shader_id],
        else => null,
    };
}

pub fn addObject(self: *Self) void {
    const parent_index = self.getParentObjIndex();
    const new_id: Node.Id = .fromInt(self.nodes.items.len);

    var new_obj: Node = .{
        .name = @splat(0),
        .kind = .{ .object = .{
            .children = .empty,
            .selected_sdf = null,
        } },
        .parent = parent_index,
        .visible = true,
        .prev_visible = true,
    };
    const name = "object";
    @memcpy(new_obj.name[0..name.len], name);

    self.nodes.append(self.allocator, new_obj) catch oom();
    // Get a fresh pointer after append
    self.getNode(parent_index).kind.object.children.add(self.allocator, new_id) catch oom();

    // Select the newly created object
    self.selected = new_id;
}

pub fn addSdf(self: *Self, kind: sdf.Kind) void {
    const node_id: Node.Id = .fromInt(self.nodes.items.len);
    const parent_index = self.getParentObjIndex();

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

    const index, const new_sdf, const new_meta = self.newSdf();

    new_sdf.* = .{
        .transform = transform,
        .params = params,
        .scale = 1,
        .kind = kind,
        .op = .union_op,
        .smooth_factor = 0.5,
        .visible = @intFromBool(true),
        .color = .one,
        .obj_id = parent_index.toInt(),
        .pad = undefined,
    };

    new_meta.* = .{
        .rotation = .zero,
    };

    var new_obj: Node = .{
        .name = @splat(0),
        .kind = .{
            .sdf = .{
                .node_id = node_id,
                .shader_id = index,
            },
        },
        .parent = parent_index,
        .visible = true,
        .prev_visible = true,
    };

    const name = @tagName(kind);
    @memcpy(new_obj.name[0..name.len], name);

    self.nodes.append(self.allocator, new_obj) catch oom();
    // Get a fresh pointer after append
    self.getNode(parent_index).kind.object.children.add(self.allocator, node_id) catch oom();
    self.insertSdfIndex(@intCast(index), parent_index.toInt());

    // Select the newly created Sdf
    self.selected = node_id;
}

/// Insert shader_id into sdf_indices after all existing entries with the same obj_id
fn insertSdfIndex(self: *Self, shader_id: u32, obj_id: u32) void {
    var insert_pos: usize = self.sdf_indices.items.len;
    var in_group = false;
    for (self.sdf_indices.items, 0..) |idx, i| {
        if (self.sdfs.items[idx].obj_id == obj_id) {
            in_group = true;
        } else if (in_group) {
            insert_pos = i;
            break;
        }
    }
    self.sdf_indices.insert(self.allocator, insert_pos, shader_id) catch oom();
}

fn removeSdfIndex(self: *Self, shader_id: u32) void {
    for (self.sdf_indices.items, 0..) |idx, i| {
        if (idx == shader_id) {
            _ = self.sdf_indices.orderedRemove(i);
            return;
        }
    }
}

fn newSdf(self: *Self) struct { usize, *Sdf, *sdf.Meta } {
    if (self.tombstones.pop()) |index| {
        return .{
            index,
            &self.sdfs.items[index],
            &self.sdf_meta.items[index],
        };
    }

    return .{
        self.sdfs.items.len,
        self.sdfs.addOne(self.allocator) catch oom(),
        self.sdf_meta.addOne(self.allocator) catch oom(),
    };
}

pub fn getNode(self: *Self, id: Node.Id) *Node {
    return &self.nodes.items[id.toInt()];
}

/// If a SDF is selected, get its parent, otherwise get the object
fn getParentObjIndex(self: *Self) Node.Id {
    const index = self.selected orelse return .root;
    const node = self.getNode(index);

    return switch (node.kind) {
        .sdf => node.parent,
        .object => index,
    };
}

fn getShaderSdfFromIndex(self: *Self, id: Node.Id) *Sdf {
    const node = self.nodeKind(id).sdf;
    return self.getShaderSdfFromNode(node);
}

fn getShaderSdfFromNode(self: *Self, sdf_node: Node.Kind.Sdf) *Sdf {
    return &self.sdfs.items[sdf_node.shader_id];
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
            self.removeSdfIndex(@intCast(sdf_node.shader_id));
            self.getShaderSdfFromNode(sdf_node).obj_id = parent.toInt();
            self.insertSdfIndex(@intCast(sdf_node.shader_id), parent.toInt());
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

    const prev_pos = children.getIndex(prev_id).?;
    const child_pos = children.getIndex(child).?;

    keys[prev_pos] = child;
    keys[child_pos] = prev_id;

    // Swap evaluation order in sdf_indices to match new visual order
    const prev_shader_id = self.nodeKind(prev_id).sdf.shader_id;
    const child_shader_id = self.nodeKind(child).sdf.shader_id;

    var prev_idx_pos: ?usize = null;
    var child_idx_pos: ?usize = null;
    for (self.sdf_indices.items, 0..) |idx, i| {
        if (idx == prev_shader_id) prev_idx_pos = i;
        if (idx == child_shader_id) child_idx_pos = i;
    }

    if (prev_idx_pos) |pp| if (child_idx_pos) |cp| {
        const tmp = self.sdf_indices.items[pp];
        self.sdf_indices.items[pp] = self.sdf_indices.items[cp];
        self.sdf_indices.items[cp] = tmp;
    };
}

pub fn delete(self: *Self, id: Node.Id) void {
    const node = self.getNode(id);
    var parent = &self.getNode(node.parent).kind.object;
    _ = parent.children.remove(id);

    if (self.selected) |selected| {
        if (selected == id) {
            self.selected = null;
        }
    }

    switch (node.kind) {
        .sdf => |s| {
            self.removeSdfIndex(@intCast(s.shader_id));
            self.sdfs.items[s.shader_id].visible = 0;
            self.tombstones.append(self.allocator, @intCast(s.shader_id)) catch oom();
        },
        .object => |*obj| {
            // Remove in reverse order to avoid oob acces
            const count: usize = obj.children.count();
            for (0..count) |i| {
                self.delete(obj.children.keys()[count - i - 1]);
            }
        },
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
    const sdf_shader = &self.sdfs.items[sdf_node.shader_id];
    return .{ .d = sdf_shader.evaluateSDF(p), .sdf = sdf_node };
}

pub fn save(self: *Self, path: []const u8) void {
    var serializer: Serializer = .init();
    serializer.serialize(path, self);
}

pub fn debug(self: *Self) void {
    self.selectNode(.fromInt(1));
    self.addSdf(.box);
    self.debugSetLastPos(.new(-5, 0, 0));

    self.addObject();
    self.selectNode(.fromInt(3));
    self.addSdf(.box);
    self.addSdf(.sphere);
    self.debugSetLastPos(.new(0, 2, 0));

    self.selectNode(.fromInt(0));
    self.addObject();
    self.selectNode(.fromInt(6));
    self.addSdf(.torus);
    self.debugSetLastPos(.new(5, 0, 0));

    self.selectNode(.fromInt(0));
    self.addSdf(.cylinder);
    self.debugSetLastPos(.new(0, 0, -8));

    self.selectNode(.fromInt(0));
    self.addObject();
}

fn debugSetLastPos(self: *Self, pos: m.Vec3) void {
    self.debugSetPos(self.sdfs.items.len - 1, pos);
}

fn debugSetPos(self: *Self, index: usize, pos: m.Vec3) void {
    const transform = &self.sdfs.items[index].transform;

    transform.fields[3][0] = pos.x;
    transform.fields[3][1] = pos.y;
    transform.fields[3][2] = pos.z;
}
