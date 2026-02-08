const m = @import("math.zig").math;
const Aabb = @import("Aabb.zig");

pub const Kind = enum(u32) {
    sphere,
    box,
    torus,
    cylinder,
};

pub const Op = enum(u32) {
    none,
    union_op,
    subtract,
    intersect,
    smooth_union,
    smooth_subtract,
    smooth_intersect,
};

pub const Sdf = extern struct {
    position: m.Vec3,
    kind: Kind,

    params: m.Vec4,

    color: m.Vec3,
    op: Op,

    smooth_factor: f32,
    visible: bool,
    _pad: [2]f32 = undefined,

    pub fn evaluateSDF(self: *const Sdf, p: m.Vec3) f32 {
        // Local position
        const lp = p.sub(self.position);

        return switch (self.kind) {
            .sphere => sdSphere(lp, self.params.x),
            .box => sdBox(lp, .{ .x = self.params.x, .y = self.params.y, .z = self.params.z }, self.params.z),
            .torus => @panic("Not implemented yet"),
            .cylinder => @panic("Not implemented yet"),
        };
    }

    fn sdSphere(lp: m.Vec3, r: f32) f32 {
        return lp.length() - r;
    }

    fn sdBox(lp: m.Vec3, b: m.Vec3, r: f32) f32 {
        const q: m.Vec3 = lp.abs().sub(b).add(m.Vec3.one.scale(r));
        return q.componentMax(.zero).length() + @min(@max(b.x, @max(b.y, b.z)), 0.0) - r;
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
            .torus => .{
                .min = pos.sub(.new(par.x + par.y, par.y, par.x + par.y)),
                .max = pos.add(.new(par.x + par.y, par.y, par.x + par.y)),
            },
            .cylinder => .{
                .min = pos.sub(.new(par.x, par.y, par.z)),
                .max = pos.add(.new(par.x, par.y, par.z)),
            },
        };
    }
};
