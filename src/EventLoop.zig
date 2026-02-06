const c = @import("c");
const sdl = c.sdl;
const Camera = @import("Camera.zig");

camera: *Camera,
mouse_wheel_pressed: bool,
shift_pressed: bool,

const Self = @This();

pub fn init() Self {
    return .{
        .camera = undefined,
        .mouse_wheel_pressed = false,
        .shift_pressed = false,
    };
}

pub fn bindCamera(self: *Self, camera: *Camera) void {
    self.camera = camera;
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
            self.camera.offsetFov(event.wheel.y);
        },
        sdl.SDL_EVENT_MOUSE_BUTTON_UP => {
            if (event.button.button == sdl.SDL_BUTTON_MIDDLE) {
                self.mouse_wheel_pressed = false;
            }
        },
        sdl.SDL_EVENT_MOUSE_BUTTON_DOWN => {
            if (event.button.button == sdl.SDL_BUTTON_MIDDLE) {
                self.mouse_wheel_pressed = true;
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

            if (event.key.key == sdl.SDLK_LSHIFT or event.key.key == sdl.SDLK_RSHIFT) {
                self.shift_pressed = true;
            }
        },
        sdl.SDL_EVENT_MOUSE_MOTION => {
            if (self.mouse_wheel_pressed) {
                const x = event.motion.xrel * 0.1;
                const y = -event.motion.yrel * 0.1;

                if (self.shift_pressed) {
                    self.camera.moveForward(y * 0.1);
                    self.camera.moveRight(x * 0.1);
                } else {
                    self.camera.offsetYawPitch(x, y);
                }
            }
        },
        else => {},
    }

    return sdl.SDL_APP_CONTINUE;
}
