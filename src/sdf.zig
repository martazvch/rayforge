const math = @import("math.zig");
const m = math.zlm;
const Aabb = @import("Aabb.zig");

pub const Kind = enum(u32) {
    sphere,
    box,
    cylinder,
    torus,
};

pub const Op = enum(u32) {
    none,
    union_op,
    subtract,
    intersect,
};

pub const Sdf = extern struct {
    transform: m.Mat4,
    /// Sphere
    ///  x: radius
    /// Box
    ///  x: first dimension
    ///  y: second dimension
    ///  z: third dimension
    /// Cylinder
    ///  x: radius
    ///  y: half-height
    /// Torus:
    ///  x: major radius
    ///  y: minor radius
    params: m.Vec4,

    kind: Kind,
    op: Op,
    smooth_factor: f32,
    scale: f32,

    color: m.Vec3,
    visible: bool,

    pub fn getPos(self: *const Sdf) m.Vec3 {
        return math.vec3FromSlice(self.transform.fields[3][0..3]);
    }

    pub fn evaluateSDF(self: *const Sdf, p: m.Vec3) f32 {
        // Local position
        const lp = p.sub(self.getPos());

        return switch (self.kind) {
            .sphere => sdSphere(lp, self.params.x),
            .box => sdBox(lp, .{ .x = self.params.x, .y = self.params.y, .z = self.params.z }, self.params.w),
            .cylinder => sdCylinder(lp, .{ .x = self.params.x, .y = self.params.y }),
            .torus => sdTorus(lp, .{ .x = self.params.x, .y = self.params.y }),
        };
    }

    fn sdSphere(lp: m.Vec3, r: f32) f32 {
        return lp.length() - r;
    }

    fn sdBox(lp: m.Vec3, b: m.Vec3, r: f32) f32 {
        const q: m.Vec3 = lp.abs().sub(b).add(m.Vec3.one.scale(r));
        return q.componentMax(.zero).length() + @min(@max(b.x, @max(b.y, b.z)), 0.0) - r;
    }

    fn sdCylinder(lp: m.Vec3, h: m.Vec2) f32 {
        const d = m.Vec2.new(m.Vec2.new(lp.x, lp.z).length(), lp.y)
            .abs()
            .sub(h);

        return @min(@max(d.x, d.y), 0) + d.componentMax(.zero).length();
    }

    fn sdTorus(lp: m.Vec3, t: m.Vec2) f32 {
        const q = m.Vec2.new(m.Vec2.new(lp.x, lp.z).length() - t.x, lp.y);

        return q.length() - t.y;
    }

    pub fn getLocalAABB(self: *const Sdf) Aabb {
        const par = self.params;

        return switch (self.kind) {
            .sphere => .{
                .min = m.Vec3.one.scale(-par.x),
                .max = m.Vec3.one.scale(par.x),
            },
            .box => .{
                .min = .new(-par.x, -par.y, -par.z),
                .max = .new(par.x, par.y, par.z),
            },
            .cylinder => .{
                .min = .new(-par.x, -par.y, -par.x),
                .max = .new(par.x, par.y, par.x),
            },
            .torus => .{
                .min = .new(-(par.x + par.y), -par.y, -(par.x + par.y)),
                .max = .new(par.x + par.y, par.y, par.x + par.y),
            },
        };
    }

    pub fn getAABB(self: *const Sdf) Aabb {
        const pos = self.getPos();
        const par = self.params;

        return switch (self.kind) {
            .sphere => .{
                .min = pos.sub(m.Vec3.one.scale(par.x)),
                .max = pos.add(m.Vec3.one.scale(par.x)),
            },
            .box => .{
                .min = pos.sub(.new(par.x, par.y, par.z)),
                .max = pos.add(.new(par.x, par.y, par.z)),
            },
            .cylinder => .{
                .min = pos.sub(.new(par.x, par.y, par.x)),
                .max = pos.add(.new(par.x, par.y, par.x)),
            },
            .torus => .{
                .min = pos.sub(.new(par.x + par.y, par.y, par.x + par.y)),
                .max = pos.add(.new(par.x + par.y, par.y, par.x + par.y)),
            },
        };
    }
};
