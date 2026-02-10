const m = @import("math.zig").zlm;

min: m.Vec3,
max: m.Vec3,

const Self = @This();

//      4 ────── 5
//     /|       /|
//    / |      / |
//  7 ────── 6   |
//  |   0 ───|── 1
//  |  /     |  /
//  | /      | /
//  3 ────── 2
pub fn getCorners(aabb: Self) [8]m.Vec3 {
    const lo = aabb.min;
    const hi = aabb.max;
    return .{
        .new(lo.x, lo.y, lo.z), // 0: left  bottom back
        .new(hi.x, lo.y, lo.z), // 1: right bottom back
        .new(hi.x, lo.y, hi.z), // 2: right bottom front
        .new(lo.x, lo.y, hi.z), // 3: left  bottom front
        .new(lo.x, hi.y, lo.z), // 4: left  top    back
        .new(hi.x, hi.y, lo.z), // 5: right top    back
        .new(hi.x, hi.y, hi.z), // 6: right top    front
        .new(lo.x, hi.y, hi.z), // 7: left  top    front
    };
}
