const std = @import("std");
const math = @import("math.zig");
const m = math.zlm;
const globals = @import("globals.zig");
const sdf = @import("sdf.zig");

mode: Mode,
axis: Axis,
start_pos: m.Vec3,
start_rotation: m.Vec3,
start_scale: f32,
start_mouse: m.Vec2,

const Self = @This();

pub const Mode = enum {
    normal,
    grab,
    rotate,
    scale,
};

pub const Axis = enum {
    none,
    x,
    y,
    z,
    local_x,
    local_y,
    local_z,
};

pub fn init() Self {
    return .{
        .mode = .normal,
        .axis = .none,
        .start_pos = .zero,
        .start_rotation = .zero,
        .start_scale = 1,
        .start_mouse = .zero,
    };
}

pub fn isActive(self: *const Self) bool {
    return self.mode != .normal;
}

pub fn begin(self: *Self, mode: Mode, mouse_x: f32, mouse_y: f32) void {
    const s = globals.scene.getSelectedSdf() orelse return;
    const meta = globals.scene.getSelectedSdfMeta() orelse return;

    self.mode = mode;
    self.axis = .none;
    self.start_pos = s.getPos();
    self.start_rotation = meta.rotation;
    self.start_scale = s.scale;
    self.start_mouse = .new(mouse_x, mouse_y);
}

/// Cycle the axis constraint for the current mode, local -> global -> none
pub fn setAxis(self: *Self, key_axis: Axis) void {
    const local: Axis = switch (key_axis) {
        .x => .local_x,
        .y => .local_y,
        .z => .local_z,
        else => unreachable,
    };

    self.axis = if (self.axis == key_axis)
        local
    else if (self.axis == local)
        .none
    else
        key_axis;
}

pub fn update(self: *Self, mouse_x: f32, mouse_y: f32) void {
    const current: m.Vec2 = .new(mouse_x, mouse_y);
    switch (self.mode) {
        .normal => {},
        .grab => self.updateGrab(current),
        .rotate => self.updateRotate(current),
        .scale => self.updateScale(current),
    }
}

/// Commit the manipulation and return to normal mode
pub fn confirm(self: *Self) void {
    self.mode = .normal;
    self.axis = .none;
}

/// Abort the manipulation and restore the SDF to its state before begin() was called
pub fn cancel(self: *Self) void {
    var s = globals.scene.getSelectedSdf() orelse unreachable;
    var meta = globals.scene.getSelectedSdfMeta() orelse unreachable;

    setPos(s, self.start_pos);
    s.scale = self.start_scale;
    meta.rotation = self.start_rotation;

    self.mode = .normal;
    self.axis = .none;
}

fn updateGrab(self: *Self, current: m.Vec2) void {
    const s = globals.scene.getSelectedSdf() orelse return;
    const camera = &globals.camera;
    const delta = current.sub(self.start_mouse);

    switch (self.axis) {
        .none => {
            // Move on the view plane, depth stays constant
            // How many world units does one screen pixel correspond to at the object's depth?
            const vecs = camera.toVec3();
            const obj_depth = self.start_pos.sub(camera.pos).dot(vecs.forward);
            if (obj_depth < 0.001) return;

            const vp_half_h = globals.editor.viewport.rect.size.y * 0.5;
            const units_per_px = obj_depth * @tan(camera.fov * 0.5) / vp_half_h;

            // Screen +Y is down, world +Y is up → negate Y component
            const world_delta = vecs.right.scale(delta.x * units_per_px)
                .sub(vecs.up.scale(delta.y * units_per_px));

            setPos(s, self.start_pos.add(world_delta));
        },
        else => {
            const axis_dir = getAxisDir(self.axis, s);
            const p0 = camera.worldToScreen(self.start_pos) orelse return;
            const p1 = camera.worldToScreen(self.start_pos.add(axis_dir)) orelse return;

            // Screen vector corresponding to 1 world unit along the axis
            const axis_screen = m.Vec2.new(p1[0] - p0[0], p1[1] - p0[1]);
            const px_per_world = axis_screen.length();
            if (px_per_world < 0.001) return; // axis nearly perpendicular to screen

            const axis_screen_dir = axis_screen.scale(1.0 / px_per_world);
            const t_world = delta.dot(axis_screen_dir) / px_per_world;

            setPos(s, self.start_pos.add(axis_dir.scale(t_world)));
        },
    }
}

fn updateRotate(self: *Self, current: m.Vec2) void {
    const s = globals.scene.getSelectedSdf() orelse return;
    const meta = globals.scene.getSelectedSdfMeta() orelse return;
    defer rebuildTransform(s, meta);

    const speed: f32 = 0.5;

    switch (self.axis) {
        .none => {
            // Free rotation: compute the signed angle swept around the object's screen
            // center, then distribute it across the Euler angles weighted by the camera's
            // forward direction (approximation of "rotate around view axis")
            const camera = &globals.camera;
            const obj_screen = camera.worldToScreen(self.start_pos) orelse return;

            const center = m.Vec2.new(obj_screen[0], obj_screen[1]);
            const v0 = self.start_mouse.sub(center);
            const v1 = current.sub(center);
            if (v0.length() < 2 or v1.length() < 2) return;

            // Signed angle from v0 to v1 (radians), via 2D cross and dot products
            const cross = v0.x * v1.y - v0.y * v1.x;
            const dot = v0.x * v1.x + v0.y * v1.y;
            const angle_deg = m.toDegrees(std.math.atan2(cross, dot));

            // Distribute the rotation across the three Euler axes based on how much
            // the camera forward direction aligns with each world axis
            const d = camera.dir;
            meta.rotation.x = self.start_rotation.x + d.x * angle_deg;
            meta.rotation.y = self.start_rotation.y + d.y * angle_deg;
            meta.rotation.z = self.start_rotation.z + d.z * angle_deg;
        },
        .x, .local_x => meta.rotation.x = self.start_rotation.x + (current.x - self.start_mouse.x) * speed,
        .y, .local_y => meta.rotation.y = self.start_rotation.y + (current.x - self.start_mouse.x) * speed,
        .z, .local_z => meta.rotation.z = self.start_rotation.z + (current.x - self.start_mouse.x) * speed,
    }
}

fn updateScale(self: *Self, current: m.Vec2) void {
    const s = globals.scene.getSelectedSdf() orelse return;
    const camera = &globals.camera;

    // Blender-style: ratio of mouse distance from object center to initial distance
    const obj_screen = camera.worldToScreen(self.start_pos) orelse {
        // Linear horizontal drag
        const dx = current.x - self.start_mouse.x;
        s.scale = @max(0.0001, self.start_scale * (1.0 + dx * 0.01));
        return;
    };

    const center = m.Vec2.new(obj_screen[0], obj_screen[1]);
    const initial_dist = self.start_mouse.sub(center).length();
    const current_dist = current.sub(center).length();

    if (initial_dist < 0.001) return;
    s.scale = @max(0.0001, self.start_scale * (current_dist / initial_dist));
}

fn setPos(s: *sdf.Sdf, pos: m.Vec3) void {
    s.transform.fields[3][0] = pos.x;
    s.transform.fields[3][1] = pos.y;
    s.transform.fields[3][2] = pos.z;
}

fn getAxisDir(axis: Axis, s: *const sdf.Sdf) m.Vec3 {
    return switch (axis) {
        .none => .zero,
        .x => .unitX,
        .y => .unitY,
        .z => .unitZ,
        .local_x => math.mulMat4Vec3(s.transform.transpose(), .unitX).normalize(),
        .local_y => math.mulMat4Vec3(s.transform.transpose(), .unitY).normalize(),
        .local_z => math.mulMat4Vec3(s.transform.transpose(), .unitZ).normalize(),
    };
}

fn rebuildTransform(s: *sdf.Sdf, meta: *const sdf.Meta) void {
    const pos = s.getPos();
    s.transform = m.Mat4.createAngleAxis(.unitX, m.toRadians(meta.rotation.x))
        .mul(m.Mat4.createAngleAxis(.unitY, m.toRadians(meta.rotation.y)))
        .mul(m.Mat4.createAngleAxis(.unitZ, m.toRadians(meta.rotation.z)))
        .transpose();
    setPos(s, pos);
}
