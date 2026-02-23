show_grid: bool,
snap_enabled: bool,
snap_value: f32,
should_quit: bool,

const Self = @This();

pub fn init() Self {
    return .{
        .show_grid = true,
        .snap_enabled = false,
        .snap_value = 0.5,
        .should_quit = false,
    };
}
