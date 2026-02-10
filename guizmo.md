 Context

 The rayforge editor needs interactive 3D gizmos for manipulating selected objects and visualizing camera orientation.
  We'll implement these from scratch using the existing ImDrawList + projection infrastructure, keeping everything in
 pure Zig with no external dependencies.

 ---
 New file: src/editor/Gizmo.zig

 This is the core of the implementation — a self-contained module handling all gizmo rendering and interaction.

 State

 // Interaction state
 active_axis: ?Axis = null,    // currently being dragged
 hovered_axis: ?Axis = null,   // mouse is hovering over
 drag_start_t: f32 = 0,        // axis parameter at drag start
 drag_start_angle: f32 = 0,    // angle at drag start (rotation mode)
 drag_start_scale_dist: f32 = 0, // distance at drag start (scale mode)
 initial_value: m.Vec3 = .zero,  // position/rotation/scale at drag start

 const Axis = enum { x, y, z };

 Translation gizmo

 Drawing: For each axis (X=red, Y=green, Z=blue):
 1. Project object center and center + axis * gizmo_length to screen using Projection.worldToScreen()
 2. Scale gizmo_length proportionally to camera distance so gizmo has constant screen size
 3. Draw a line with ImDrawList_AddLineEx() + a small filled triangle tip with ImDrawList_AddTriangleFilled()
 4. Highlight the hovered axis brighter

 Hit detection: For each projected axis line, compute the distance from mouse position to the 2D line segment. The
 closest axis under a threshold (~8px) is hovered_axis.

 Dragging (closest-point-on-axis technique):
 1. On mouse click when hovered_axis != null: record active_axis, compute initial parameter t along the 3D axis using
 ray-line closest point, store initial_value = sdf.position
 2. On mouse drag: compute new t using current mouse ray → delta_t = new_t - drag_start_t → sdf.position =
 initial_value + axis_dir * delta_t
 3. On mouse release: clear active_axis

 Ray-line closest point math (camera already provides screenToRay()):
 Axis line: P + t*A  (P = object center, A = unit axis direction)
 Mouse ray:  O + s*D  (O = camera.pos, D = normalized ray from screenToRay)
 t = (dot(A,w)*dot(D,D) - dot(D,w)*dot(A,D)) / (dot(A,A)*dot(D,D) - dot(A,D)^2)
 where w = P - O

 Rotation gizmo

 Drawing: For each axis, draw a circle (arc of ~32 segments) in the plane perpendicular to that axis, projected to
 screen. Only draw the half facing the camera (back-face cull segments).

 Hit detection: Distance from mouse to the nearest circle arc segment.

 Dragging: On drag, compute the angle of the mouse position relative to the object center in the rotation plane. Delta
  angle = current - start angle. Apply to obj.properties.rotation component in degrees.

 Scale gizmo

 Drawing: Same axis lines as translate, but with small squares at the ends instead of arrow tips. Draw with
 ImDrawList_AddRectFilled().

 Hit detection: Same line-distance check as translate.

 Dragging: Measure mouse distance from object screen center along the axis screen direction. Ratio of current/start
 distance gives scale factor. Apply to obj.properties.scale component.

 Orientation overlay (upper-right corner)

 Drawing: In a fixed 128×128 region at top-right of viewport:
 1. Compute a "view rotation only" matrix (camera's view matrix with translation zeroed)
 2. Project unit axis endpoints (±1,0,0), (0,±1,0), (0,0,±1) through this rotation to get screen directions
 3. Draw from a center point: 3 colored lines for +X, +Y, +Z (shorter/dimmer lines for negative axes)
 4. Draw axis labels ("X", "Y", "Z") at the positive endpoints using ImDrawList_AddText()
 5. Depth-sort the axes so the frontmost draws last (on top)

 Click detection: If mouse clicks within the overlay region, check proximity to each axis label. If close to one, snap
  camera to that axis view by setting camera.yaw/camera.pitch to the corresponding values:
 - +X view: yaw=0, pitch=0
 - -X view: yaw=π, pitch=0
 - +Y view: yaw=-π/2, pitch=π/2-ε
 - -Y view: yaw=-π/2, pitch=-π/2+ε
 - +Z view: yaw=-π/2, pitch=0
 - -Z view: yaw=π/2, pitch=0

 Then call camera.orbit().

 ---
 Modified files

 src/editor/Editor.zig

 - Add gizmo: Gizmo field (initialized in init())
 - In render(), call self.gizmo.render(...) between viewport.render() and drawBoundingBox()
 - render() also calls the orientation overlay: self.gizmo.renderOrientationCube(...)
 - After gizmo render, store whether gizmo is active into state

 src/editor/State.zig

 - Add gizmo_active: bool field (default false)
 - Already has gizmo_mode: GizmoMode with translate/rotate/scale — reuse this

 src/EventLoop.zig

 - Gate camera controls: wrap zoom/orbit/pan/selection in if (!self.gizmo_active) checks
 - Add gizmo_active: bool field, set from Editor.render() each frame

 src/Camera.zig

 - No structural changes needed
 - screenToRay(), getLookAt(), orbit() all reused as-is

 src/math.zig

 - Add helper: pointToLineSegmentDist2D(point, a, b) -> f32 for gizmo hit testing
 - Add helper: closestPointOnAxis(axis_origin, axis_dir, ray_origin, ray_dir) -> f32 returning the parameter t

 ---
 Rendering order in Editor.render()

 newFrame()
 Layout.render()
 viewport.render()             -- 3D scene texture
 gizmo.renderOrientationCube() -- orientation overlay (upper-right)
 gizmo.render()                -- manipulation gizmo on selected object
 drawBoundingBox()             -- selection bounding box
 ImGui_Render()

 Gizmo draws on the foreground draw list (same as bounding box) so it appears on top of the 3D viewport.

 ---
 Verification

 1. zig build — compiles without errors (no new dependencies)
 2. zig build run:
   - Orientation cube visible in upper-right corner of viewport, rotates with camera
   - Click axis label → camera snaps to that axis view
   - Select an object → gizmo handles appear at object center
   - Translate mode: 3 colored arrows, drag to move object along axis
   - Rotate mode: 3 colored circles, drag to rotate object
   - Scale mode: 3 colored lines with boxes, drag to scale
   - Properties panel updates in real-time during drag
   - Camera orbit/pan/zoom doesn't conflict with gizmo interaction
   - Gizmo scales with camera distance (constant screen size)
