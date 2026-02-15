#version 460

layout(location = 0) in vec2 fragTexCoord;
layout(location = 0) out vec4 outColor;

layout(std140, set = 3, binding = 0) uniform CameraBlock {
    vec2 resolution;
    vec2 _pad;
    vec3 cam_pos;
    float fov;
    mat3 cam_rot;
};

struct SDFObject {
    mat4 transform;
    vec4 params;
    uint kind;
    uint op;
    float smooth_factor;
    float scale;
    vec3 color;
    bool visible;
    uint obj_id;
    float _pad[3];
};

layout(std430, set = 2, binding = 0) readonly buffer SceneBlock {
    uint object_count;
    uint _pad2[3];
    SDFObject objects[];
};

#define MAX_STEPS 80
#define SHADOW_STEPS 80
#define MAX_DIST 100.0
#define SURF_DIST 0.001

#define SDF_SPHERE 0
#define SDF_BOX 1
#define SDF_CYLINDER 2
#define SDF_TORUS 3

#define OP_NONE 0
#define OP_UNION 1
#define OP_SUBTRACT 2
#define OP_INTERSECT 3

struct SceneInfo {
    float dist;
    uint index;
};

// Shapes
float sdSphere(vec3 p, float r) {
    return length(p) - r;
}

float sdBox(vec3 p, vec3 b, float r) {
    vec3 q = abs(p) - b + r;
    return length(max(q, 0.0)) + min(max(q.x, max(q.y, q.z)), 0.0) - r;
}

float sdCylinder(vec3 p, vec2 h) {
    vec2 d = abs(vec2(length(p.xz), p.y)) - h;
    return min(max(d.x, d.y), 0.0) + length(max(d, 0.0));
}

float sdTorus(vec3 p, vec2 t) {
    vec2 q = vec2(length(p.xz) - t.x, p.y);
    return length(q) - t.y;
}

// Operations
float unionOp(float d1, float d2, float k) {
    if (k < 0.0001) return min(d1, d2);

    float h = clamp(0.5 + 0.5 * (d2 - d1) / k, 0.0, 1.0);
    return mix(d2, d1, h) - k * h * (1.0 - h);
}

float subtraction(float d1, float d2, float k) {
    if (k < 0.0001) return max(-d1, d2);

    float h = clamp(0.5 - 0.5 * (d2 + d1) / k, 0.0, 1.0);
    return mix(d2, -d1, h) + k * h * (1.0 - h);
}

float intersection(float d1, float d2, float k) {
    if (k < 0.0001) return max(d1, d2);

    float h = clamp(0.5 - 0.5 * (d2 - d1) / k, 0.0, 1.0);
    return mix(d2, d1, h) + k * h * (1.0 - h);
}

float evaluateSDF(SDFObject obj, vec3 p) {
    vec3 local_p = mat3(obj.transform) * (p - obj.transform[3].xyz) / obj.scale;

    if (obj.kind == SDF_SPHERE)   return sdSphere(local_p, obj.params.x) * obj.scale;
    if (obj.kind == SDF_BOX)      return sdBox(local_p, obj.params.xyz, obj.params.w) * obj.scale;
    if (obj.kind == SDF_CYLINDER) return sdCylinder(local_p, obj.params.xy) * obj.scale;
    if (obj.kind == SDF_TORUS)    return sdTorus(local_p, obj.params.xy) * obj.scale;
    return 0;
}

float applyOperation(float d1, float d2, uint op, float k) {
    if (op == OP_UNION)     return unionOp(d1, d2, k);
    if (op == OP_SUBTRACT)  return subtraction(d1, d2, k);
    if (op == OP_INTERSECT) return intersection(d1, d2, k);

    // op == none
    return d1;
}

SceneInfo getDist(vec3 p) {
    float result_dist = MAX_DIST;
    uint index = 0;
    uint obj_id = 0;

    if (object_count == 0) {
        return SceneInfo(MAX_DIST, 0);
    }

    uint current_obj = objects[0].obj_id;
    float group_dist = MAX_DIST;
    uint group_index = 0;

    // TODO: condition on 128 could be CPU side
    for (uint i = 0; i < object_count && i < 128; ++i) {
        SDFObject obj = objects[i];

        // New object group → finalize previous group with union
        if (obj.obj_id != current_obj) {
            if (group_dist < result_dist) {
                result_dist = group_dist;
                index = group_index;
            }
            current_obj = obj.obj_id;
            group_dist = MAX_DIST;
        }

        if (!obj.visible) {
            continue;
        }

        float d = evaluateSDF(obj, p);

        float prev = group_dist;
        group_dist = applyOperation(d, group_dist, obj.op, obj.smooth_factor);
        if (group_dist < prev) {
            group_index = i;
        }
    }

    // Finalize last group
    if (group_dist < result_dist) {
        result_dist = group_dist;
        index = group_index;
    }

    return SceneInfo(result_dist, index);
}

// https://iquilezles.org/articles/normalsSDF/
vec3 getNormal(vec3 p) {
    const float e = 0.001;
    const vec2 k = vec2(1.0, -1.0);
    return normalize(
        k.xyy * getDist(p + k.xyy * e).dist +
        k.yyx * getDist(p + k.yyx * e).dist +
        k.yxy * getDist(p + k.yxy * e).dist +
        k.xxx * getDist(p + k.xxx * e).dist
    );
}

SceneInfo rayMarch(vec3 ro, vec3 rd, float maxDist) {
    float dO = 0.0;
    uint index = 0;

    for (int i = 0; i < MAX_STEPS; i++) {
        vec3 p = ro + rd * dO;
        SceneInfo info = getDist(p);
        dO += info.dist;
        index = info.index;
        if (dO > maxDist || abs(info.dist) < SURF_DIST) break;
    }

    return SceneInfo(dO, index);
}

// Marches from the point where light is casted to the light source
float shadowMarch(vec3 ro, vec3 rd, float maxDist) {
    float dO = 0.0;
    for (int i = 0; i < SHADOW_STEPS; i++) {
        float d = getDist(ro + rd * dO).dist;
        dO += d;
        if (dO > maxDist || d < SURF_DIST) break;
    }
    return dO;
}

// Lambertian diffuse
// This is Lambert's cosine law: the brightness of a surface is proportional to the cosine of the angle between the
// surface normal n and the light direction l.
//
// Geometrically: dot(n, l) = |n| · |l| · cos(θ). Since both are unit vectors, it simplifies to cos(θ). When the surface
//  faces the light head-on (θ = 0°), cos = 1.0 (full brightness). At a grazing angle (θ = 90°), cos = 0.0 (no light).
// We clamp to avoid negative values for surfaces facing away.
float getLight(vec3 p) {
    vec3 lightPos = vec3(5.0, 5.0, -5.0);
    vec3 l = normalize(lightPos - p);
    vec3 n = getNormal(p);

    float dif = clamp(dot(n, l), 0.0, 1.0);

    // We cast a second ray from the surface point toward the light. If this ray hits any SDF
    // geometry before reaching lightDist, the point is in shadow.
    float lightDist = length(lightPos - p);

    // Raymarching doesn't stop exactly on the surface. It stops when abs(info.dist) < SURF_DIST (0.001), meaning p could be
    // up to 0.001 units inside the geometry. If you start the shadow ray at p, here's what happens:
    // The fix: push the origin outward along the surface normal n by 2 × SURF_DIST:

    // new origin = p + n * 0.002

    // Why 2×? Because p could be up to SURF_DIST inside the surface. Moving 1 × SURF_DIST along the normal might just
    // barely reach the surface. 2× guarantees we're clearly outside, so the first getDist() call in the shadow march
    // returns a value > SURF_DIST and doesn't false-trigger.

    //              n (normal)
    //              ↑
    //              |  ← 0.002 offset
    // surface ─────●──────────
    //              p (could be 0.001 below)
    float shadow = shadowMarch(p + n * SURF_DIST * 2.0, l, lightDist);
    if (shadow < lightDist) {
        // In reality, occluded surfaces still receive indirect light from bounces
        // Using 0.3 fakes a soft ambient fill rather than making shadows pitch black
        dif *= 0.3;
    }

    return dif;
}

vec4 getGridColorAA(vec3 p) {
    vec2 coord = p.xz;
    float camDist = length(cam_pos - p);

    // Single distance fade for everything
    float distFade = 1.0 - smoothstep(40.0, 90.0, camDist);

    // These are hardware intrinsics. The GPU runs fragments in 2x2 quads. dFdx(coord) gives you the difference in coord
    // between the current pixel and its horizontal neighbor. dFdy(coord) gives the vertical neighbor difference.
    vec2 dx = dFdx(coord);
    vec2 dy = dFdy(coord);
    // For each world-space axis (x and z), this computes how many world units one pixel spans. That changes with distance
    // and perspective — far-away grid cells are many world units per pixel, nearby ones are a fraction. By dividing the
    // grid distance by this, we get grid lines that are always exactly ~1 pixel wide regardless of distance, which is why
    // the grid doesn't flicker or alias.
    vec2 derivative = abs(vec2(length(vec2(dx.x, dy.x)), length(vec2(dx.y, dy.y))));

    // Line width: 1.5px close up, thins to 0.5px at distance
    float lineWidth = mix(1.5, 0.5, smoothstep(5.0, 40.0, camDist));
    // Step by step for one axis (say coord.x = 3.7):
    // 1. fract(coord.x - 0.5) = fract(3.2) = 0.2 — maps to [0, 1) repeating at every integer
    // 2. - 0.5 = -0.3 — maps to [-0.5, 0.5), centered on grid lines
    // 3. abs() = 0.3 — distance to the nearest integer grid line (range [0, 0.5])
    // 4. / (derivative * 2.0) — normalizes to pixel units. If derivative = 0.01 (one pixel spans 0.01 world units), then
    // 0.3 / 0.02 = 15 means "15 pixels away from grid line"
    vec2 grid = abs(fract(coord - 0.5) - 0.5) / (derivative * lineWidth);
    // Values < 1.0 are within ~1 pixel of a grid line. min(grid.x, grid.y) picks whichever axis is closer to a grid line
    float line = min(grid.x, grid.y);
    // Alpha: 1.0 on line, 0.0 between lines
    float alpha = 1.0 - min(line, 1.0);

    // Kill grid when lines become sub-pixel (this fixes the halo).
    // derivative.x = how many world units one pixel spans horizontally.
    // When that approaches 0.5, grid lines (spaced 1.0 apart) are ~2px wide
    // and start merging. At 1.0+, every pixel contains a grid line → solid color.
    float pixelSize = max(derivative.x, derivative.y);
    alpha *= 1.0 - smoothstep(0.25, 0.5, pixelSize);
    alpha *= distFade;

    vec3 color = vec3(0.35, 0.35, 0.4);

    // Axes — thick fixed width, no derivatives at all
    float xAxis = smoothstep(0.04, 0.008, abs(coord.y));
    float zAxis = smoothstep(0.04, 0.008, abs(coord.x));

    if (xAxis > 0.0) {
        color = vec3(0.9, 0.15, 0.15);
    }
    if (zAxis > 0.0) {
        color = vec3(0.15, 0.4, 0.9);
    }

    return vec4(color, alpha);
}

void main() {
    vec2 uv = fragTexCoord * 2.0 - 1.0;
    uv.x *= resolution.x / resolution.y;

    float fov_factor = tan(fov * 0.5);
    uv *= fov_factor;

    vec3 rd = normalize(cam_rot * vec3(uv.x, uv.y, 1.0));
    vec3 ro = cam_pos;

    // Compute grid plane intersection before raymarching
    // A plane at y = 0 has the implicit equation y = 0. A ray is defined as P(t) = ro + t · rd
    // Setting the y-component to zero:
    // ro.y + t · rd.y = 0
    // t = -ro.y / rd.y
    float gridT = MAX_DIST + 1.0;
    if (abs(rd.y) > 1e-6) {
        float t = -ro.y / rd.y;
        // If t > 0, the intersection is in front of the camera. If rd.y ≈ 0, the ray is parallel to the plane (no hit)
        // This is an exact analytical solution — no marching, no iteration, just one division
        if (t > 0.0) gridT = t;
    }

    // Cap raymarch at grid plane
    // without the ground plane in the SDF, rays aimed at the floor
    // marched all 100 steps to MAX_DIST before giving up.
    // Now they stop at gridT (often just a few units), saving ~90% of steps.
    SceneInfo info = rayMarch(ro, rd, MAX_DIST);

    vec3 col = vec3(0.15, 0.15, 0.18);

    if (info.dist < MAX_DIST) {
        vec3 p = ro + rd * info.dist;
        float light = getLight(p);
        vec3 baseColor = objects[info.index].color;

        col = baseColor * light + baseColor * 0.1;
        // Ambient occlusion
        col += vec3(0.03, 0.03, 0.05);
        // Gamma correction
        col = pow(col, vec3(0.4545));
    }

    // Draws the grid only if nearest to cam then object
    if (info.dist > gridT && gridT <= MAX_DIST) {
        vec3 p = ro + rd * gridT;
        vec4 grid = getGridColorAA(p);
        col = mix(col, grid.rgb, grid.a);
    }

    outColor = vec4(col, 1.0);
}
