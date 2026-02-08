const sdl = @import("c").sdl;
const Texture = @import("Texture.zig");

const folder = "assets/icons/";

pub const size = 16;

pub var eye: Texture = undefined;
pub var eye_closed: Texture = undefined;
pub var camera: Texture = undefined;
pub var fullscreen: Texture = undefined;

pub var sphere: Texture = undefined;
pub var cube: Texture = undefined;
pub var cylinder: Texture = undefined;
pub var torus: Texture = undefined;

pub fn init(device: *sdl.SDL_GPUDevice) void {
    eye = .load(device, folder ++ "eye.png");
    eye_closed = .load(device, folder ++ "eye-closed.png");
    camera = .load(device, folder ++ "camera.png");
    fullscreen = .load(device, folder ++ "fullscreen.png");

    sphere = .load(device, folder ++ "sphere.png");
    cube = .load(device, folder ++ "cube.png");
    cylinder = .load(device, folder ++ "cylinder.png");
    torus = .load(device, folder ++ "torus.png");
}
