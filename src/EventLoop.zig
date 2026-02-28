const std = @import("std");
const c = @import("c");
const sdl = c.sdl;
const math = @import("math.zig");
const m = math.zlm;
const Viewport = @import("editor/Viewport.zig");
const globals = @import("globals.zig");
const Manipulator = @import("Manipulator.zig");

shift_pressed: bool,
viewport_hovered: bool,

// Cam
enable_cam: bool,

on_menu: bool,

// Axis
// enable_drag: ?Axis,
// axis_hovered: ?Axis,
/// Per-axis: screen-space direction and world-units-per-pixel ratio, set by drawGuizmo.
// axis_screen_dir: [3]m.Vec2,
// axis_world_per_px: [3]f32,

/// Last known absolute mouse position (updated on every motion event).
last_mouse: m.Vec2,

const Self = @This();
pub const Axis = enum {
    x,
    y,
    z,
};

pub fn init() Self {
    return .{
        .shift_pressed = false,
        .enable_cam = false,
        // .enable_drag = null,
        .viewport_hovered = false,
        // .axis_hovered = null,
        // .axis_screen_dir = @splat(.zero),
        // .axis_world_per_px = @splat(0),
        .last_mouse = .zero,
        .on_menu = false,
    };
}

pub fn setViewportState(self: *Self, hovered: bool) void {
    self.viewport_hovered = hovered;
}

pub fn process(self: *Self, appstate: ?*anyopaque, event: *sdl.SDL_Event) !sdl.SDL_AppResult {
    _ = appstate;

    // Returns if there was an event processed or not
    _ = c.gui.cImGui_ImplSDL3_ProcessEvent(@ptrCast(event));

    switch (event.type) {
        // TODO: what's the diffrence?
        sdl.SDL_EVENT_QUIT, sdl.SDL_EVENT_WINDOW_CLOSE_REQUESTED => {
            return sdl.SDL_APP_SUCCESS;
        },
        sdl.SDL_EVENT_MOUSE_WHEEL => {
            if (self.viewport_hovered) {
                globals.camera.zoom(event.wheel.y);
            }
        },
        sdl.SDL_EVENT_MOUSE_BUTTON_UP => {
            if (event.button.button == sdl.SDL_BUTTON_MIDDLE) {
                self.enable_cam = false;
            }
            // else if (event.button.button == sdl.SDL_BUTTON_LEFT) {
            //     self.enable_drag = null;
            // }
        },
        sdl.SDL_EVENT_MOUSE_BUTTON_DOWN => {
            const manip = &globals.editor.manipulator;

            if (event.button.button == sdl.SDL_BUTTON_MIDDLE and self.viewport_hovered) {
                self.enable_cam = true;
            } else if (event.button.button == sdl.SDL_BUTTON_LEFT) {
                if (manip.isActive()) {
                    manip.confirm();
                } else if (self.viewport_hovered and !self.on_menu) {
                    // if (self.axis_hovered) |axis| {
                    //     self.enable_drag = axis;
                    // } else {
                    const x = event.motion.x - globals.editor.viewport.rect.pos.x;
                    const y = event.motion.y - globals.editor.viewport.rect.pos.y;
                    const ray = globals.camera.screenToRay(x, y);

                    if (globals.scene.raymarch(ray.ro, ray.rd)) |hit| {
                        globals.scene.selectNode(hit.node_id);
                    } else {
                        globals.scene.selected = null;
                    }
                    // }
                }
            } else if (event.button.button == sdl.SDL_BUTTON_RIGHT) {
                if (manip.isActive()) {
                    manip.cancel();
                }
            }
        },
        sdl.SDL_EVENT_KEY_UP => {
            if (event.key.key == sdl.SDLK_LSHIFT or event.key.key == sdl.SDLK_RSHIFT) {
                self.shift_pressed = false;
            }
        },
        sdl.SDL_EVENT_KEY_DOWN => {
            const manip = &globals.editor.manipulator;

            if (event.key.key == sdl.SDLK_ESCAPE) {
                if (manip.isActive()) {
                    manip.cancel();
                }
            }

            if (event.key.key == sdl.SDLK_LSHIFT or event.key.key == sdl.SDLK_RSHIFT) {
                self.shift_pressed = true;
            }

            // Focus camera on selected SDF
            if (event.key.key == sdl.SDLK_F and !event.key.repeat) {
                if (globals.scene.getSelectedSdf()) |sdf| {
                    globals.camera.pivot = sdf.getPos();
                    globals.camera.orbit();
                }
            }

            if (self.viewport_hovered and !event.key.repeat) {
                if (event.key.key == sdl.SDLK_G) {
                    manip.begin(.grab, self.last_mouse.x, self.last_mouse.y);
                } else if (event.key.key == sdl.SDLK_R) {
                    manip.begin(.rotate, self.last_mouse.x, self.last_mouse.y);
                } else if (event.key.key == sdl.SDLK_S) {
                    manip.begin(.scale, self.last_mouse.x, self.last_mouse.y);
                }
            }

            // Axis constraints
            if (!event.key.repeat) {
                if (event.key.key == sdl.SDLK_X) manip.setAxis(.x);
                if (event.key.key == sdl.SDLK_Y) manip.setAxis(.y);
                if (event.key.key == sdl.SDLK_Z) manip.setAxis(.z);
            }

            // Enter confirms the active manipulation
            if (event.key.key == sdl.SDLK_RETURN and !event.key.repeat) {
                if (manip.isActive()) {
                    manip.confirm();
                }
            }
        },
        sdl.SDL_EVENT_MOUSE_MOTION => {
            self.last_mouse = .new(event.motion.x, event.motion.y);

            if (self.enable_cam) {
                const x = event.motion.xrel * 0.1;
                const y = event.motion.yrel * 0.1;

                if (self.shift_pressed) {
                    globals.camera.pan(x, y);
                } else {
                    globals.camera.rotate(x, y);
                }
            } else if (globals.editor.manipulator.isActive()) {
                // Keyboard manipulation takes priority over gizmo arrow drag.
                globals.editor.manipulator.update(event.motion.x, event.motion.y);
            }
            // else if (self.enable_drag) |axis| {
            //     const s = globals.scene.getSelectedSdf().?;
            //     const i = @intFromEnum(axis);
            //     const d = self.axis_screen_dir[i];
            //     // Project mouse delta onto screen-space axis direction
            //     const mouse_delta = m.Vec2.new(event.motion.xrel, event.motion.yrel);
            //     const px_along_axis = mouse_delta.dot(d);
            //     // Convert screen pixels to world units
            //     const world_delta = px_along_axis * self.axis_world_per_px[i];
            //     // Apply along the world-space axis direction
            //     const units = [_]m.Vec3{ .unitX, .unitY, .unitZ };
            //     const world_dir = math.mulMat4Vec3(s.transform.transpose(), units[i]);
            //     s.transform.fields[3][0] += world_dir.x * world_delta;
            //     s.transform.fields[3][1] += world_dir.y * world_delta;
            //     s.transform.fields[3][2] += world_dir.z * world_delta;
            // }
        },
        else => {},
    }

    return sdl.SDL_APP_CONTINUE;
}
