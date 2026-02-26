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
    try self.writer.writeAll("}");
}

fn sceneName(self: *Self, path: []const u8) !void {
    var iter = std.mem.splitBackwardsScalar(u8, path, '/');
    const name = iter.next().?;
    try self.pushKeyValue("name", name, true);
}

fn nodes(self: *Self, scene: *const Scene) !void {
    try self.openKey("nodes", .list);
    var buf: [10]u8 = undefined;

    for (scene.nodes.items, 0..) |*node, i| {
        const last = i == scene.nodes.items.len - 1;

        try self.openAnonKey(.block);
        try self.pushKeyValue("name", std.mem.sliceTo(&node.name, 0), true);
        try self.nodeKind(node.kind);
        try self.pushKeyValue("parent", try std.fmt.bufPrint(&buf, "{}", .{node.parent.toInt()}), true);
        try self.pushKeyValue("visible", if (node.visible) "true" else "false", false);
        try self.closeKey(.block, !last);
    }
    try self.closeKey(.list, true);
}

fn nodeKind(self: *Self, kind: Node.Kind) !void {
    try self.openKey("kind", .block);
    try self.pushKeyValue("tag", @tagName(kind), true);

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

fn pushKeyValue(self: *Self, key: []const u8, value: []const u8, comma: bool) !void {
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
