const std = @import("std");
const c = @import("c");
const sdl = c.sdl;
const m = @import("math.zig").zlm;
const Camera = @import("Camera.zig");
const Scene = @import("Scene.zig");
const Viewport = @import("editor/Viewport.zig");

scene: *Scene,
camera: *Camera,
viewport: *const Viewport,
shift_pressed: bool,
enable_cam: bool,
viewport_hovered: bool,

const Self = @This();

pub fn init() Self {
    return .{
        .scene = undefined,
        .camera = undefined,
        .shift_pressed = false,
        .enable_cam = false,
        .viewport_hovered = false,
        .viewport = undefined,
    };
}

pub fn bind(self: *Self, scene: *Scene, camera: *Camera, viewport: *const Viewport) void {
    self.scene = scene;
    self.camera = camera;
    self.viewport = viewport;
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
                self.camera.zoom(event.wheel.y);
            }

            // Free camera
            // self.camera.offsetFov(event.wheel.y);
        },
        sdl.SDL_EVENT_MOUSE_BUTTON_UP => {
            if (event.button.button == sdl.SDL_BUTTON_MIDDLE) {
                self.enable_cam = false;
            }
        },
        sdl.SDL_EVENT_MOUSE_BUTTON_DOWN => {
            if (event.button.button == sdl.SDL_BUTTON_MIDDLE and self.viewport_hovered) {
                self.enable_cam = true;
            } else if (event.button.button == sdl.SDL_BUTTON_LEFT and self.viewport_hovered) {
                const x = event.motion.x - self.viewport.rect.pos.x;
                const y = event.motion.y - self.viewport.rect.pos.y;

                const ray = self.camera.screenToRay(x, y, self.viewport.rect.size);

                // const obj = self.scene.getSelectedObj();
                if (self.scene.raymarch(ray.ro, ray.rd)) |hit| {
                    // const obj = self.scene.shader_data.sdfs[hit].obj_id;
                    // self.scene.nodes.items[obj].kind.object.selected_sdf = .fromInt(0);
                    self.scene.selectNode(hit.node_id);
                } else {
                    self.scene.selected = null;
                }
            }
        },
        sdl.SDL_EVENT_KEY_UP => {
            if (event.key.key == sdl.SDLK_LSHIFT or event.key.key == sdl.SDLK_RSHIFT) {
                self.shift_pressed = false;
            }
        },
        sdl.SDL_EVENT_KEY_DOWN => {
            if (event.key.key == sdl.SDLK_ESCAPE) {
                return sdl.SDL_APP_SUCCESS;
            }

            if (event.key.key == sdl.SDLK_F) {
                if (self.scene.getSelectedSdf()) |sdf| {
                    self.camera.pivot = sdf.getPos();
                    self.camera.orbit();
                }
            }

            if (event.key.key == sdl.SDLK_LSHIFT or event.key.key == sdl.SDLK_RSHIFT) {
                self.shift_pressed = true;
            }
        },
        sdl.SDL_EVENT_MOUSE_MOTION => {
            if (self.enable_cam) {
                const x = event.motion.xrel * 0.1;
                const y = event.motion.yrel * 0.1;

                if (self.shift_pressed) {
                    self.camera.pan(x, y);

                    // Free camera
                    // self.camera.moveForward(y * 0.1);
                    // self.camera.moveRight(x * 0.1);
                } else {
                    self.camera.rotate(x, y);
                }
            }
        },
        else => {},
    }

    return sdl.SDL_APP_CONTINUE;
}
