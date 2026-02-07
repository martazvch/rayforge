const m = @import("math.zig").math;
const d2r = m.toRadians;

pos: m.Vec3,
speed: f32,
dir: m.Vec3,
yaw: f32,
pitch: f32,
fov: f32,
pivot: m.Vec3,
distance: f32,

const Self = @This();
const UP = m.Vec3.unitY;

pub fn init() Self {
    // We init yaw at -90 because angle is from +x axis (pointing to the right) to +z
    var self: Self = .{
        .pos = .zero,
        .speed = 20,
        .dir = undefined,
        .yaw = d2r(-90.0),
        .pitch = d2r(20.0),
        .fov = d2r(45),
        .pivot = .zero,
        .distance = 20,
    };
    self.orbit();

    return self;
}

/// Computes the 3 axis of orthonormed base
pub fn toVec4(self: Self) struct { right: m.Vec4, up: m.Vec4, forward: m.Vec4 } {
    const forward = self.dir;
    const right = forward.cross(UP).normalize();
    const up = right.cross(forward).normalize();

    return .{
        .right = .{ .x = right.x, .y = right.y, .z = right.z, .w = 0 },
        .up = .{ .x = up.x, .y = up.y, .z = up.z, .w = 0 },
        .forward = .{ .x = forward.x, .y = forward.y, .z = forward.z, .w = 0 },
    };
}

pub fn toVec3(self: Self) struct { right: m.Vec3, up: m.Vec3, forward: m.Vec3 } {
    const forward = self.dir;
    const right = forward.cross(UP).normalize();
    const up = right.cross(forward).normalize();

    return .{
        .right = .{ .x = right.x, .y = right.y, .z = right.z },
        .up = .{ .x = up.x, .y = up.y, .z = up.z },
        .forward = .{ .x = forward.x, .y = forward.y, .z = forward.z },
    };
}

pub fn rotate(self: *Self, yaw: f32, pitch: f32) void {
    self.yaw += d2r(yaw);
    self.pitch += d2r(pitch);

    // One degree less to prevent breaking
    const pi2 = 3.14159265359 / 2.0 - 0.018;

    if (self.pitch > pi2) {
        self.pitch = pi2;
    } else if (self.pitch < -pi2) {
        self.pitch = -pi2;
    }

    self.orbit();
}

pub fn orbit(self: *Self) void {
    // 3D point from Euler angles
    const offset: m.Vec3 = .{
        .x = self.distance * @cos(self.pitch) * @cos(self.yaw),
        .y = self.distance * @sin(self.pitch),
        .z = self.distance * @cos(self.pitch) * @sin(self.yaw),
    };
    self.pos = self.pivot.add(offset);
    self.dir = self.pivot.sub(self.pos).normalize();
}

pub fn pan(self: *Self, dx: f32, dy: f32) void {
    const vecs = self.toVec3();

    // Scale pan speed by distance so it feels consistent
    const scale = self.distance * 0.002;
    self.pivot = self.pivot.add(vecs.right.scale(-dx * scale)).add(vecs.up.scale(dy * scale));
    self.orbit();
}

pub fn zoom(self: *Self, delta: f32) void {
    // Mltiplying by 0.1 makes it logarithmic, and * distance slows down when we get close
    self.distance = @max(0.1, self.distance - delta * self.distance * 0.1);
    self.orbit();
}

// This makes the camera the origin looking toward dir
pub fn getLookAt(self: *const Self) m.Mat4 {
    return .createLookAt(self.pos, self.pos.add(self.dir), UP);
}

pub fn getPerspective(self: *const Self, aspect: f32) m.Mat4 {
    return .createPerspective(
        self.fov,
        aspect,
        0.01,
        100.0, // matches MAX_DIST in shader
    );
}

pub fn screenToRay(camera: *const Self, mx: f32, my: f32, vp_size: m.Vec2) struct { ro: m.Vec3, rd: m.Vec3 } {
    // Same as shader: fragTexCoord * 2.0 - 1.0
    var uv = m.Vec2{
        .x = (mx / vp_size.x) * 2.0 - 1.0,
        .y = -((my / vp_size.y) * 2.0 - 1.0), // flip Y (screen Y is down)
    };

    // Aspect ratio
    uv.x *= vp_size.x / vp_size.y;

    // FOV
    const fov_factor = @tan(camera.fov * 0.5);
    uv.x *= fov_factor;
    uv.y *= fov_factor;

    // Ray direction in camera space → world space
    const vecs = camera.toVec3();

    // rd_local = vec3(uv.x, uv.y, 1.0) in shader
    // cam_rot * rd_local = right*uv.x + up*uv.y + forward*1.0
    const rd = vecs.right.scale(uv.x).add(vecs.up.scale(uv.y)).add(vecs.forward).normalize();

    return .{ .ro = camera.pos, .rd = rd };
}

// -----------------
// Free camera mode
// -----------------

// pub fn moveForward(self: *Self, factor: f32) void {
//     self.pos = self.pos.add(self.dir.scale(self.speed * factor));
// }
//
// pub fn moveBackward(self: *Self, factor: f32) void {
//     self.pos = self.pos.sub(self.dir.scale(self.speed * factor));
// }
//
// pub fn moveLeft(self: *Self, factor: f32) void {
//     self.pos = self.pos.sub(
//         self.dir.cross(UP).normalize().scale(self.speed * factor),
//     );
// }
//
// pub fn moveRight(self: *Self, factor: f32) void {
//     self.pos = self.pos.add(
//         self.dir.cross(UP).normalize().scale(self.speed * factor),
//     );
// }

// Moves the direction
// pub fn orient(self: *Self) void {
//     self.dir.x = @cos(m.toRadians(self.yaw)) * @cos(m.toRadians(self.pitch));
//     self.dir.y = @sin(m.toRadians(self.pitch));
//     self.dir.z = @sin(m.toRadians(self.yaw)) * @cos(m.toRadians(self.pitch));
//     self.dir = self.dir.normalize();
// }
//
// // Zoom affects the FoV
// pub fn offsetFov(self: *Self, offset: f32) void {
//     self.fov -= offset;
//
//     if (self.fov < 1.0) {
//         self.fov = 1.0;
//     } else if (self.fov > 45.0) {
//         self.fov = 45.0;
//     }
// }
