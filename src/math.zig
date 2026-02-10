pub const zlm = @import("zlm").as(f32);
const gui = @import("c").gui;

pub const guiVec4Zero: gui.ImVec4 = .{ .x = 0, .y = 0, .z = 0, .w = 0 };
pub const guiVec4One: gui.ImVec4 = .{ .x = 1, .y = 1, .z = 1, .w = 1 };

pub fn zlmToImGui(v: zlm.Vec4) gui.ImVec4 {
    return @bitCast(v);
}

pub fn extendVec3(v: zlm.Vec3, w: f32) zlm.Vec4 {
    return .{ .x = v.x, .y = v.y, .z = v.z, .w = w };
}
