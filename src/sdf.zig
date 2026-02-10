const m = @import("math.zig").zlm;
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

    position: m.Vec3,
    scale: f32,

    kind: Kind,
    op: Op,
    smooth_factor: f32,
    visible: bool,

    color: m.Vec3,
    _pad: f32 = undefined,

    pub fn evaluateSDF(self: *const Sdf, p: m.Vec3) f32 {
        // Local position
        const lp = p.sub(self.position);

        return switch (self.kind) {
            .sphere => sdSphere(lp, self.params.x),
            .box => sdBox(lp, .{ .x = self.params.x, .y = self.params.y, .z = self.params.z }, self.params.z),
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

    pub fn getAABB(self: *const Sdf) Aabb {
        const pos = self.position;
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
