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
    // World → Clip space
    // Result is in homogeneous clip coordinates (x, y, z, w)
    const view_pos = m.Vec4.new(point.x, point.y, point.z, 1.0).transform(self.view);
    const clip = view_pos.transform(self.proj);

    // Behind camera check
    // w <= 0 means the point is behind or on the camera plane
    // Projecting it would give nonsense (flipped/infinity)
    if (clip.w <= 0.0001) return null;

    // Clip → NDC (Normalized Device Coordinates)
    // Divide by w. This is the "perspective divide"
    // it's what makes far things smaller.
    // NDC range: x,y between [-1, +1]
    const ndcx = clip.x / clip.w;
    const ndcy = clip.y / clip.w;

    // NDC → Screen pixel (ImGui coordinates)
    // NDC (-1,-1) = bottom-left, (+1,+1) = top-right
    // Screen (0,0) = top-left, (w,h) = bottom-right
    // So we flip Y
    return .{
        self.vp_x + (ndcx * 0.5 + 0.5) * self.vp_w,
        self.vp_y + (1.0 - (ndcy * 0.5 + 0.5)) * self.vp_h,
    };
}
