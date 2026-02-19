const std = @import("std");
const c = @import("c");
const gui = c.gui;
const math = @import("../math.zig");
const Scene = @import("../Scene.zig");
const icons = @import("../icons.zig");
const Node = @import("../Node.zig");
const theme = @import("theme.zig");
const addObjPopup = @import("add_obj_popup.zig");
const oom = @import("../utils.zig").oom;

pub fn render(scene: *Scene, flags: gui.ImGuiWindowFlags) void {
    if (gui.ImGui_Begin("Scene", null, flags)) {
        header();
        sceneTree(scene);
    }
    gui.ImGui_End();
}

fn header() void {
    gui.ImGui_SameLine();
    if (gui.ImGui_Button("+")) {
        gui.ImGui_OpenPopup(addObjPopup.id, 0);
    }
    gui.ImGui_SameLine();
    if (gui.ImGui_Button("&")) {
        // Will be used to instanciate other scenes
    }
    gui.ImGui_SameLine();
    if (gui.ImGui_Button("v")) {
        //
    }
    gui.ImGui_SameLine();
    if (gui.ImGui_Button("^")) {
        //
    }

    addObjPopup.open();
    gui.ImGui_Separator();
}

var renaming: ?Node.Id = null;
var rename_just_started: bool = false;

fn sceneTree(scene: *Scene) void {
    const flags = gui.ImGuiTreeNodeFlags_DefaultOpen |
        gui.ImGuiTreeNodeFlags_SpanAvailWidth |
        gui.ImGuiTreeNodeFlags_AllowOverlap |
        gui.ImGuiTreeNodeFlags_OpenOnArrow |
        gui.ImGuiTreeNodeFlags_FramePadding |
        gui.ImGuiTreeNodeFlags_DrawLinesToNodes;

    if (gui.ImGui_TreeNodeEx("root", flags)) {
        defer gui.ImGui_TreePop();

        if (gui.ImGui_BeginDragDropTarget()) {
            if (gui.ImGui_AcceptDragDropPayload("scene_node", 0)) |payload| {
                const source_id: *const Node.Id = @ptrCast(@alignCast(payload.*.Data));
                scene.reparent(source_id.*, .zero);
            }
            gui.ImGui_EndDragDropTarget();
        }

        for (scene.nodes.items[0].kind.object.children.keys()) |root| {
            renderNode(scene, root);
        }
    }

    // Drop zone: empty area below nodes reparents to root
    const avail = gui.ImGui_GetContentRegionAvail();
    if (avail.y > 0) {
        _ = gui.ImGui_InvisibleButton("##root_drop", .{ .x = avail.x, .y = avail.y }, 0);
        if (gui.ImGui_BeginDragDropTarget()) {
            if (gui.ImGui_AcceptDragDropPayload("scene_node", 0)) |payload| {
                const source_id: *const Node.Id = @ptrCast(@alignCast(payload.*.Data));
                scene.reparent(source_id.*, .zero);
            }
            gui.ImGui_EndDragDropTarget();
        }
    }
}

fn renderNode(scene: *Scene, id: Node.Id) void {
    const node = scene.getNode(id);

    var flags = gui.ImGuiTreeNodeFlags_DefaultOpen |
        gui.ImGuiTreeNodeFlags_SpanAvailWidth |
        gui.ImGuiTreeNodeFlags_AllowOverlap |
        gui.ImGuiTreeNodeFlags_OpenOnArrow |
        gui.ImGuiTreeNodeFlags_FramePadding |
        gui.ImGuiTreeNodeFlags_DrawLinesToNodes;

    if (scene.selected) |selected_id| {
        if (selected_id == id) {
            flags |= gui.ImGuiTreeNodeFlags_Selected;
        }
    }

    const is_leaf = leaf: switch (node.kind) {
        .sdf => {
            flags |= gui.ImGuiTreeNodeFlags_Leaf;
            break :leaf true;
        },
        else => false,
    };

    // Hide the name to insert icon in-between
    gui.ImGui_PushID(&@intCast(id.toInt()));
    defer gui.ImGui_PopID();
    const open = gui.ImGui_TreeNodeEx("##node", flags);

    // Save tree node interaction state (resolved after eye button)
    const node_clicked = gui.ImGui_IsItemClicked();
    const node_right_clicked = gui.ImGui_IsItemClickedEx(gui.ImGuiButtonFlags_MouseButtonRight);
    const node_hovered = gui.ImGui_IsItemHovered(0);
    const node_double_clicked = node_hovered and gui.ImGui_IsMouseDoubleClicked(0);

    // Drag and drop
    if (gui.ImGui_BeginDragDropSource(0)) {
        _ = gui.ImGui_SetDragDropPayload("scene_node", &id, @sizeOf(Node.Id), 0);
        gui.ImGui_Text(@ptrCast(&node.name));
        gui.ImGui_EndDragDropSource();
    }

    // Objects accept reparenting and leaves accept reordering
    if (gui.ImGui_BeginDragDropTarget()) {
        if (gui.ImGui_AcceptDragDropPayload("scene_node", 0)) |payload| {
            const source_id: *const Node.Id = @ptrCast(@alignCast(payload.*.Data));
            if (!is_leaf) {
                scene.reparent(source_id.*, id);
                std.log.debug("Nop", .{});
            } else {
                const source_node = scene.getNode(source_id.*);
                if (source_node.parent != null and node.parent != null and source_node.parent.? == node.parent.?) {
                    scene.reorder(node.parent.?, source_id.*, id);
                } else {}
            }
        }

        gui.ImGui_EndDragDropTarget();
    }

    // Icon
    var node_start = gui.ImGui_GetCursorPosX();
    if (is_leaf) {
        node_start -= 12;
    }
    gui.ImGui_SameLineEx(node_start, 0);

    const cursor_y = gui.ImGui_GetCursorPosY();
    gui.ImGui_SetCursorPosY(cursor_y + 2);
    gui.ImGui_Image(nodeIcon(scene, node), icons.size_vec);
    const icon_min_x = gui.ImGui_GetItemRectMin().x;

    gui.ImGui_SameLine();
    if (renaming != null and renaming.? == id) {
        const avail = gui.ImGui_GetContentRegionAvail().x - icons.size;
        gui.ImGui_SetNextItemWidth(avail);

        if (rename_just_started) {
            gui.ImGui_SetKeyboardFocusHere();
            rename_just_started = false;
        }

        const pad_y = gui.ImGui_GetStyle().*.FramePadding.y;
        gui.ImGui_SetCursorPosY(gui.ImGui_GetCursorPosY() + pad_y);
        gui.ImGui_PushStyleVarImVec2(gui.ImGuiStyleVar_FramePadding, .{ .x = 4, .y = 0 });

        if (gui.ImGui_InputText(
            "##rename",
            &node.name,
            node.name.len,
            gui.ImGuiInputTextFlags_EnterReturnsTrue |
                gui.ImGuiInputTextFlags_AutoSelectAll,
        )) {
            renaming = null;
        }

        gui.ImGui_PopStyleVar();

        if (gui.ImGui_IsItemDeactivated()) {
            renaming = null;
        }
    } else {
        gui.ImGui_Text(@ptrCast(&node.name));
    }

    // Eye
    gui.ImGui_SameLine();
    const content_max_x = gui.ImGui_GetWindowContentRegionMax().x;
    gui.ImGui_SetCursorPosX(content_max_x - icons.size);
    gui.ImGui_SetCursorPosY(cursor_y + 2);

    gui.ImGui_PushStyleVarImVec2(gui.ImGuiStyleVar_FramePadding, .{ .x = 0, .y = 0 });
    gui.ImGui_PushStyleColorImVec4(gui.ImGuiCol_ButtonActive, .{ .x = 1, .y = 1, .z = 1, .w = 0.25 });

    const eye_icon = if (node.visible) icons.eye else icons.eye_closed;
    if (gui.ImGui_ImageButton("##eye", eye_icon.toImGuiRef(), icons.size_vec)) {
        toggleVisibility(scene, node);
    }

    const eye_hovered = gui.ImGui_IsItemHovered(0);
    gui.ImGui_PopStyleColor();
    gui.ImGui_PopStyleVar();

    // Selection: tree node clicked, but not on eye
    if (node_clicked and !eye_hovered) {
        scene.selectNode(id);
    }

    // Double-click to rename: only on icon+text area (not arrow, not eye)
    if (node_double_clicked and !eye_hovered) {
        // Arrow part
        const mouse_x = gui.ImGui_GetMousePos().x;
        if (mouse_x >= icon_min_x) {
            renaming = id;
            rename_just_started = true;
        }
    }

    if (node_right_clicked) {
        rightClicMenu();
    }

    // Children
    if (open) {
        switch (node.kind) {
            .object => |obj| {
                for (obj.children.keys()) |child_id| {
                    renderNode(scene, child_id);
                }
            },
            .sdf => {},
        }
        gui.ImGui_TreePop();
    }
}

fn nodeIcon(scene: *const Scene, node: *const Node) gui.ImTextureRef {
    const texture = switch (node.kind) {
        .object => icons.object,
        .sdf => |index| icon: {
            const sdf = scene.sdfs[index.shader_id];
            break :icon switch (sdf.kind) {
                .sphere => icons.sphere,
                .box => icons.cube,
                .cylinder => icons.cylinder,
                .torus => icons.torus,
            };
        },
    };
    return texture.toImGuiRef();
}

fn toggleVisibility(scene: *Scene, node: *Node) void {
    if (scene.getNode(node.parent.?).visible) {
        node.visible = !node.visible;
    }

    const obj = switch (node.kind) {
        .object => |*obj| obj,
        .sdf => |sdf| {
            scene.sdfs[sdf.shader_id].visible = node.visible;
            return;
        },
    };

    toggleObjectVisibility(scene, node, obj);
}

fn toggleObjectVisibility(scene: *Scene, node: *Node, obj: *Node.Kind.Object) void {
    for (obj.children.keys()) |child| {
        switch (scene.nodeKindPtr(child).*) {
            .sdf => |sdf| {
                const sdf_node = scene.getNode(sdf.node_id);
                const shader_id = sdf.shader_id;
                var meta = &scene.sdf_meta[shader_id];

                if (node.visible == sdf_node.visible) {
                    continue;
                }

                if (!node.visible) {
                    meta.visible = scene.sdfs[shader_id].visible;
                    scene.sdfs[shader_id].visible = false;
                    sdf_node.visible = false;
                } else {
                    scene.sdfs[shader_id].visible = meta.visible;
                    sdf_node.visible = meta.visible;
                }
            },
            .object => |*child_obj| {
                var child_node = scene.getNode(child);

                if (!node.visible) {
                    child_node.prev_visible = child_node.visible;
                    child_node.visible = false;
                } else {
                    child_node.visible = child_node.prev_visible;
                }

                return toggleObjectVisibility(scene, child_node, child_obj);
            },
        }
    }
}

fn rightClicMenu() void {}
