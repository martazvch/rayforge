const std = @import("std");
const Writer = std.io.Writer;
const Scene = @import("Scene.zig");
const Node = @import("Node.zig");
const sdf = @import("sdf.zig");
const fatal = @import("utils.zig").fatal;

indent_level: usize,
writer: *Writer,

const Self = @This();
const spaces: []const u8 = " " ** 1024;
const INDENT_SIZE = 4;

pub fn init() Self {
    return .{
        .indent_level = 1,
        .writer = undefined,
    };
}

pub fn serialize(self: *Self, filepath: []const u8, scene: *const Scene) void {
    var buf: [10]u8 = undefined;
    // Should not fail as path comes from tinyfiledialog
    var file = std.fs.cwd().createFile(filepath, .{}) catch |e| {
        fatal("file-system changed while saving scene to disk: {t}", .{e});
    };
    defer file.close();

    var fw = file.writer(&.{});
    self.writer = &fw.interface;

    errdefer fatal("Unexpected error while saving scene to disk", .{});
    try self.writer.writeAll("{\n");
    try self.sceneName(filepath);
    try self.nodes(scene);
    try self.sdfs(scene);
    try self.sdfs_meta(scene);
    try self.indices(scene);
    try self.tombstones(scene);
    try self.pushKeyValue(
        "selected",
        if (scene.selected) |s| try std.fmt.bufPrint(&buf, "{}", .{s.toInt()}) else "-1",
        false,
    );
    try self.writer.writeAll("}");
}

fn sceneName(self: *Self, path: []const u8) !void {
    var iter = std.mem.splitBackwardsScalar(u8, path, '/');
    const name = iter.next().?;
    try self.pushKeyValueStr("name", name, true);
}

fn nodes(self: *Self, scene: *const Scene) !void {
    try self.openKey("nodes", .list);
    var buf: [10]u8 = undefined;

    for (scene.nodes.items, 0..) |*node, i| {
        const last = i == scene.nodes.items.len - 1;

        try self.openAnonKey(.block);
        try self.pushKeyValueStr("name", std.mem.sliceTo(&node.name, 0), true);
        try self.nodeKind(node.kind);
        try self.pushKeyValue("parent", try std.fmt.bufPrint(&buf, "{}", .{node.parent.toInt()}), true);
        try self.pushKeyValue("visible", if (node.visible) "true" else "false", false);
        try self.closeKey(.block, !last);
    }
    try self.closeKey(.list, true);
}

fn nodeKind(self: *Self, kind: Node.Kind) !void {
    try self.openKey("kind", .block);
    try self.pushKeyValueStr("tag", @tagName(kind), true);

    var buf: [10]u8 = undefined;

    switch (kind) {
        .sdf => |s| {
            try self.pushKeyValue("node_id", try std.fmt.bufPrint(&buf, "{}", .{s.node_id.toInt()}), true);
            try self.pushKeyValue("shader_id", try std.fmt.bufPrint(&buf, "{}", .{s.shader_id}), false);
        },
        .object => |o| {
            try self.openKey("children", .list);
            for (o.children.keys(), 0..) |child, i| {
                const last = i == o.children.count() - 1;
                try self.pushKeyValue("id", try std.fmt.bufPrint(&buf, "{}", .{child.toInt()}), !last);
            }
            try self.closeKey(.list, false);
        },
    }

    try self.closeKey(.block, true);
}

fn sdfs(self: *Self, scene: *const Scene) !void {
    try self.openKey("sdfs", .list);
    var buf: [20]u8 = undefined;

    for (scene.sdfs.items, 0..) |s, i| {
        const last = i == scene.sdfs.items.len - 1;

        try self.openAnonKey(.block);
        {
            try self.openKey("transform", .block);
            try self.pushKeyValue("11", try std.fmt.bufPrint(&buf, "{}", .{s.transform.fields[0][0]}), true);
            try self.pushKeyValue("12", try std.fmt.bufPrint(&buf, "{}", .{s.transform.fields[0][1]}), true);
            try self.pushKeyValue("13", try std.fmt.bufPrint(&buf, "{}", .{s.transform.fields[0][2]}), true);
            try self.pushKeyValue("14", try std.fmt.bufPrint(&buf, "{}", .{s.transform.fields[0][3]}), true);
            try self.pushKeyValue("21", try std.fmt.bufPrint(&buf, "{}", .{s.transform.fields[1][0]}), true);
            try self.pushKeyValue("22", try std.fmt.bufPrint(&buf, "{}", .{s.transform.fields[1][1]}), true);
            try self.pushKeyValue("23", try std.fmt.bufPrint(&buf, "{}", .{s.transform.fields[1][2]}), true);
            try self.pushKeyValue("24", try std.fmt.bufPrint(&buf, "{}", .{s.transform.fields[1][3]}), true);
            try self.pushKeyValue("31", try std.fmt.bufPrint(&buf, "{}", .{s.transform.fields[2][0]}), true);
            try self.pushKeyValue("32", try std.fmt.bufPrint(&buf, "{}", .{s.transform.fields[2][1]}), true);
            try self.pushKeyValue("33", try std.fmt.bufPrint(&buf, "{}", .{s.transform.fields[2][2]}), true);
            try self.pushKeyValue("34", try std.fmt.bufPrint(&buf, "{}", .{s.transform.fields[2][3]}), true);
            try self.pushKeyValue("41", try std.fmt.bufPrint(&buf, "{}", .{s.transform.fields[3][0]}), true);
            try self.pushKeyValue("42", try std.fmt.bufPrint(&buf, "{}", .{s.transform.fields[3][1]}), true);
            try self.pushKeyValue("43", try std.fmt.bufPrint(&buf, "{}", .{s.transform.fields[3][2]}), true);
            try self.pushKeyValue("44", try std.fmt.bufPrint(&buf, "{}", .{s.transform.fields[3][3]}), false);
            try self.closeKey(.block, true);
        }
        {
            try self.openKey("params", .block);
            try self.pushKeyValue("x", try std.fmt.bufPrint(&buf, "{}", .{s.params.x}), true);
            try self.pushKeyValue("y", try std.fmt.bufPrint(&buf, "{}", .{s.params.y}), true);
            try self.pushKeyValue("z", try std.fmt.bufPrint(&buf, "{}", .{s.params.z}), true);
            try self.pushKeyValue("w", try std.fmt.bufPrint(&buf, "{}", .{s.params.w}), false);
            try self.closeKey(.block, true);
        }
        try self.pushKeyValueStr("kind", @tagName(s.kind), true);
        try self.pushKeyValueStr("op", @tagName(s.op), true);
        try self.pushKeyValue("smooth_factor", try std.fmt.bufPrint(&buf, "{}", .{s.smooth_factor}), true);
        try self.pushKeyValue("scale", try std.fmt.bufPrint(&buf, "{}", .{s.scale}), true);
        {
            try self.openKey("color", .block);
            try self.pushKeyValue("r", try std.fmt.bufPrint(&buf, "{}", .{s.color.x}), true);
            try self.pushKeyValue("g", try std.fmt.bufPrint(&buf, "{}", .{s.color.y}), true);
            try self.pushKeyValue("b", try std.fmt.bufPrint(&buf, "{}", .{s.color.z}), false);
            try self.closeKey(.block, true);
        }
        try self.pushKeyValue("visible", if (s.visible == 1) "true" else "false", true);
        try self.pushKeyValue("obj_id", try std.fmt.bufPrint(&buf, "{}", .{s.obj_id}), false);
        try self.closeKey(.block, !last);
    }

    try self.closeKey(.list, true);
}

fn sdfs_meta(self: *Self, scene: *const Scene) !void {
    try self.openKey("sdfs_meta", .list);
    var buf: [20]u8 = undefined;

    for (scene.sdf_meta.items, 0..) |s, i| {
        const last = i == scene.sdf_meta.items.len - 1;
        try self.openKey("rotation", .block);
        try self.pushKeyValue("x", try std.fmt.bufPrint(&buf, "{}", .{s.rotation.x}), true);
        try self.pushKeyValue("y", try std.fmt.bufPrint(&buf, "{}", .{s.rotation.y}), true);
        try self.pushKeyValue("z", try std.fmt.bufPrint(&buf, "{}", .{s.rotation.z}), false);
        try self.closeKey(.block, !last);
    }

    try self.closeKey(.list, true);
}

fn indices(self: *Self, scene: *const Scene) !void {
    try self.openKey("indices", .list);
    var buf: [20]u8 = undefined;

    for (scene.sdf_indices.items, 0..) |index, i| {
        const last = i == scene.sdf_indices.items.len - 1;
        try self.pushValue(try std.fmt.bufPrint(&buf, "{}", .{index}), !last);
    }

    try self.closeKey(.list, true);
}

fn tombstones(self: *Self, scene: *const Scene) !void {
    try self.openKey("tombstones", .list);
    var buf: [20]u8 = undefined;

    for (scene.tombstones.items, 0..) |index, i| {
        const last = i == scene.tombstones.items.len - 1;
        try self.pushValue(try std.fmt.bufPrint(&buf, "{}", .{index}), !last);
    }

    try self.closeKey(.list, true);
}

const KeyTag = enum {
    block,
    list,

    pub fn toOpenStr(self: KeyTag) []const u8 {
        return switch (self) {
            .block => "{",
            .list => "[",
        };
    }

    pub fn toCloseStr(self: KeyTag) []const u8 {
        return switch (self) {
            .block => "}",
            .list => "]",
        };
    }
};

fn openKey(self: *Self, key: []const u8, tag: KeyTag) !void {
    try self.indent();
    try self.writer.print("\"{s}\": {s}\n", .{ key, tag.toOpenStr() });
    self.indent_level += 1;
}

fn openAnonKey(self: *Self, tag: KeyTag) !void {
    try self.indent();
    try self.writer.print("{s}\n", .{tag.toOpenStr()});
    self.indent_level += 1;
}

fn closeKey(self: *Self, tag: KeyTag, comma: bool) !void {
    self.indent_level -= 1;
    try self.indent();
    try self.writer.print("{s}", .{tag.toCloseStr()});
    try self.finishPush(comma);
}

fn emptyKey(self: *Self, key: []const u8, tag: KeyTag, comma: bool) !void {
    try self.indent();
    try self.writer.print("\"{s}\": {s}{s}", .{ key, tag.toOpenStr(), tag.toCloseStr() });
    try self.finishPush(comma);
}

fn pushValue(self: *Self, value: []const u8, comma: bool) !void {
    try self.indent();
    try self.writer.writeAll(value);
    try self.finishPush(comma);
}

fn pushKeyValue(self: *Self, key: []const u8, value: []const u8, comma: bool) !void {
    try self.indent();
    try self.writer.print("\"{s}\": {s}", .{ key, value });
    try self.finishPush(comma);
}

fn pushKeyValueStr(self: *Self, key: []const u8, value: []const u8, comma: bool) !void {
    try self.indent();
    try self.writer.print("\"{s}\": \"{s}\"", .{ key, value });
    try self.finishPush(comma);
}

fn finishPush(self: *Self, comma: bool) !void {
    try self.writer.print("{s}\n", .{if (comma) "," else ""});
}

fn indent(self: *Self) !void {
    try self.writer.writeAll(spaces[0 .. self.indent_level * INDENT_SIZE]);
}
