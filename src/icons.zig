const c = @import("c");
const gui = c.gui;
const sdl = c.sdl;
const Texture = @import("Texture.zig");

const folder = "assets/icons/";

pub const size = 16;
pub const size_vec: gui.ImVec2 = .{ .x = size, .y = size };

pub var eye: Texture = undefined;
pub var eye_closed: Texture = undefined;
pub var camera: Texture = undefined;
pub var fullscreen: Texture = undefined;

pub var union_op: Texture = undefined;
pub var subtract_op: Texture = undefined;
pub var intersect_op: Texture = undefined;

pub var sphere: Texture = undefined;
pub var cube: Texture = undefined;
pub var cylinder: Texture = undefined;
pub var torus: Texture = undefined;

pub var object: Texture = undefined;

pub var reset: Texture = undefined;
pub var trash: Texture = undefined;
pub var rename: Texture = undefined;

pub fn init(device: *sdl.SDL_GPUDevice) void {
    eye = .load(device, folder ++ "eye.png");
    eye_closed = .load(device, folder ++ "eye-closed.png");
    camera = .load(device, folder ++ "camera.png");
    fullscreen = .load(device, folder ++ "fullscreen.png");

    union_op = .load(device, folder ++ "union.png");
    subtract_op = .load(device, folder ++ "subtract.png");
    intersect_op = .load(device, folder ++ "intersect.png");

    sphere = .load(device, folder ++ "circle.png");
    cube = .load(device, folder ++ "cube.png");
    cylinder = .load(device, folder ++ "cylinder.png");
    torus = .load(device, folder ++ "torus.png");

    object = .load(device, folder ++ "object.png");
    reset = .load(device, folder ++ "reset.png");
    trash = .load(device, folder ++ "trash.png");
    rename = .load(device, folder ++ "rename.png");
}
