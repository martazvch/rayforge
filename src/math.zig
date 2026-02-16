pub const zlm = @import("zlm").as(f32);
const gui = @import("c").gui;

pub const guiVec4Zero: gui.ImVec4 = .{ .x = 0, .y = 0, .z = 0, .w = 0 };
pub const guiVec4One: gui.ImVec4 = .{ .x = 1, .y = 1, .z = 1, .w = 1 };

pub fn zlmVec4ToImGui(v: zlm.Vec4) gui.ImVec4 {
    return @bitCast(v);
}

pub fn zlmVec2ToImGui(v: zlm.Vec2) gui.ImVec2 {
    return @bitCast(v);
}

pub fn extendVec3(v: zlm.Vec3, w: f32) zlm.Vec4 {
    return .{ .x = v.x, .y = v.y, .z = v.z, .w = w };
}

pub fn vec3FromSlice(slice: *const [3]f32) zlm.Vec3 {
    return .{
        .x = slice[0],
        .y = slice[1],
        .z = slice[2],
    };
}

/// Transforms a Vec3 by the 3x3 rotation part of a Mat4 (row-major, v*M convention)
pub fn mulMat4Vec3(mat: zlm.Mat4, v: zlm.Vec3) zlm.Vec3 {
    const f = mat.fields;
    return .{
        .x = v.x * f[0][0] + v.y * f[1][0] + v.z * f[2][0],
        .y = v.x * f[0][1] + v.y * f[1][1] + v.z * f[2][1],
        .z = v.x * f[0][2] + v.y * f[1][2] + v.z * f[2][2],
    };
}
