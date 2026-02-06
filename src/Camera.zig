const m = @import("math.zig").math;

pos: m.Vec3,
speed: f32,
dir: m.Vec3,
yaw: f32,
pitch: f32,
fov: f32,

const Self = @This();
const UP = m.Vec3.unitY;

pub fn init(pos: m.Vec3, speed: f32) Self {
    // We init yaw at -90 because angle is from +x axis (pointing to the right) to +z
    var self: Self = .{
        .pos = pos,
        .speed = speed,
        .dir = undefined,
        .yaw = -90.0,
        .pitch = 0.0,
        .fov = 45,
    };
    self.orient();
    return self;
}

/// Computes the 3 axis of orthonormed base
pub fn toCamVectors(self: Self) struct { right: m.Vec4, up: m.Vec4, forward: m.Vec4 } {
    const forward = self.dir;
    const right = forward.cross(UP).normalize();
    const up = right.cross(forward).normalize();

    return .{
        .right = .{ .x = right.x, .y = right.y, .z = right.z, .w = 0 },
        .up = .{ .x = up.x, .y = up.y, .z = up.z, .w = 0 },
        .forward = .{ .x = forward.x, .y = forward.y, .z = forward.z, .w = 0 },
    };
}

pub fn moveForward(self: *Self, factor: f32) void {
    self.pos = self.pos.add(self.dir.scale(self.speed * factor));
}

pub fn moveBackward(self: *Self, factor: f32) void {
    self.pos = self.pos.sub(self.dir.scale(self.speed * factor));
}

pub fn moveLeft(self: *Self, factor: f32) void {
    self.pos = self.pos.sub(
        self.dir.cross(UP).normalize().scale(self.speed * factor),
    );
}

pub fn moveRight(self: *Self, factor: f32) void {
    self.pos = self.pos.add(
        self.dir.cross(UP).normalize().scale(self.speed * factor),
    );
}

pub fn getLookAt(self: *const Self) m.Mat4 {
    return .createLookAt(self.pos, self.pos.add(self.dir), UP);
}

pub fn offsetYawPitch(self: *Self, yaw: f32, pitch: f32) void {
    self.yaw += yaw;
    self.pitch += pitch;

    if (self.pitch > 89.0) {
        self.pitch = 89.0;
    } else if (self.pitch < -89.0) {
        self.pitch = -89.0;
    }

    self.orient();
}

pub fn orient(self: *Self) void {
    self.dir.x = @cos(m.toRadians(self.yaw)) * @cos(m.toRadians(self.pitch));
    self.dir.y = @sin(m.toRadians(self.pitch));
    self.dir.z = @sin(m.toRadians(self.yaw)) * @cos(m.toRadians(self.pitch));
    self.dir = self.dir.normalize();
}

pub fn offsetFov(self: *Self, offset: f32) void {
    self.fov -= offset;

    if (self.fov < 1.0) {
        self.fov = 1.0;
    } else if (self.fov > 45.0) {
        self.fov = 45.0;
    }
}
