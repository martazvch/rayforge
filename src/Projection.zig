const gui = @import("c").gui;
const m = @import("math.zig").zlm;
const Camera = @import("Camera.zig");
const Sdf = @import("sdf.zig").Sdf;

view: m.Mat4,
proj: m.Mat4,
// Viewport position and size in ImGui screen space
vp_x: f32,
vp_y: f32,
vp_w: f32,
vp_h: f32,

const Self = @This();

pub fn init(camera: *const Camera, vp_x: f32, vp_y: f32, vp_w: f32, vp_h: f32) Self {
    return .{
        .view = camera.getLookAt(),
        .proj = camera.getPerspective(vp_w / vp_h),
        .vp_x = vp_x,
        .vp_y = vp_y,
        .vp_w = vp_w,
        .vp_h = vp_h,
    };
}

/// Projects a 3D world point to a 2D ImGui screen position.
/// Returns null if the point is behind the camera.
pub fn worldToScreen(self: *const Self, point: m.Vec3) ?[2]f32 {

    // 1) World → Clip space
    //    Multiply by view, then by projection.
    //    Result is in "homogeneous clip coordinates" (x, y, z, w).
    // const view_pos = self.view.mul(.createTranslation(.new(point.x, point.y, point.z)));
    const view_pos = m.Vec4.new(point.x, point.y, point.z, 1.0).transform(self.view);
    // const clip = self.proj.mul(.createTranslation(view_pos));
    const clip = view_pos.transform(self.proj);

    // 2) Behind camera check
    //    w <= 0 means the point is behind or on the camera plane.
    //    Projecting it would give nonsense (flipped/infinity).
    if (clip.w <= 0.0001) return null;

    // 3) Clip → NDC (Normalized Device Coordinates)
    //    Divide by w. This is the "perspective divide" —
    //    it's what makes far things smaller.
    //    NDC range: x,y ∈ [-1, +1]
    const ndcx = clip.x / clip.w;
    const ndcy = clip.y / clip.w;

    // 4) NDC → Screen pixel (ImGui coordinates)
    //    NDC (-1,-1) = bottom-left, (+1,+1) = top-right
    //    Screen (0,0) = top-left, (w,h) = bottom-right
    //    So we flip Y.
    return .{
        self.vp_x + (ndcx * 0.5 + 0.5) * self.vp_w,
        self.vp_y + (1.0 - (ndcy * 0.5 + 0.5)) * self.vp_h,
    };
}

pub fn drawBoundingBox(proj: *const Self, obj: *const Sdf, color: u32) void {
    const aabb = obj.getAABB();
    const corners_3d = aabb.getCorners();

    // Project all 8 corners to screen space
    var corners: [8]?[2]f32 = undefined;
    for (0..8) |i| {
        corners[i] = proj.worldToScreen(corners_3d[i]);
    }

    // The 12 edges of a box: 4 bottom + 4 top + 4 vertical
    const edges = [12][2]u8{
        // Bottom face
        .{ 0, 1 }, .{ 1, 2 }, .{ 2, 3 }, .{ 3, 0 },
        // Top face
        .{ 4, 5 }, .{ 5, 6 }, .{ 6, 7 }, .{ 7, 4 },
        // Verticals connecting bottom to top
        .{ 0, 4 }, .{ 1, 5 }, .{ 2, 6 }, .{ 3, 7 },
    };

    // Get ImGui's foreground draw list — draws on top of everything
    const draw_list = gui.ImGui_GetForegroundDrawList();

    for (edges) |e| {
        const a = corners[e[0]] orelse continue; // skip if behind camera
        const b = corners[e[1]] orelse continue;

        gui.ImDrawList_AddLine(
            draw_list,
            .{ .x = a[0], .y = a[1] }, // ImVec2
            .{ .x = b[0], .y = b[1] }, // ImVec2
            color,
            1.5, // thickness in pixels
        );
    }
}
