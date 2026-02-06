const Self = @This();

pub const GizmoMode = enum {
    translate,
    rotate,
    scale,
};

gizmo_mode: GizmoMode,
show_grid: bool,
snap_enabled: bool,
snap_value: f32,
should_quit: bool,

pub fn init() Self {
    return .{
        .gizmo_mode = .translate,
        .show_grid = true,
        .snap_enabled = false,
        .snap_value = 0.5,
        .should_quit = false,
    };
}
