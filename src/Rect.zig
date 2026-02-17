const m = @import("math.zig").zlm;

pos: m.Vec2,
size: m.Vec2,

const Self = @This();

pub const zero: Self = .{
    .pos = .zero,
    .size = .zero,
};

pub fn ratio(self: Self) f32 {
    return self.size.x / self.size.y;
}

pub fn isIn(self: Self, x: f32, y: f32) bool {
    return x >= self.pos.x and
        x < self.pos.x + self.size.x and
        y >= self.pos.y and
        y < self.pos.y + self.size.y;
}
