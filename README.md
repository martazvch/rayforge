# Rayforge

Rayforge is a 3D modeling software using only [SDF](https://iquilezles.org/articles/distfunctions) with [raymarching](https://en.wikipedia.org/wiki/Ray_marching) rendering.
It is written in [Zig](https://ziglang.org/) and uses [SDL3_gpu](https://wiki.libsdl.org/SDL3/FrontPage) for 3D rendering and [ImGui](https://github.com/ocornut/imgui) for the UI.

https://github.com/martazvch/rayforge/tree/main/docs/Showcase.png

----

The editor is lacking a lot of functionnalities but you can already work with the scene tree view and move objects around with the guizmos.

It currently only supports the following primitives:
- Sphere
- Cube
- Cylinder
- Torus

And the operations:
- Union
- Difference
- Intersection

Only basic properties are implemented:
- Transform
- Operation smooth factor
- Basic material (plain color)

----

In the futur, I'd like to implement lots of different stuff like:
- Modifiers (like in Blender)
- Transform inheritance from parents
- More complex material
- Animations
- Scripting
- aRaycast renderer for final render
- ...
