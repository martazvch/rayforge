#version 460

layout(location = 0) in vec2 fragTexCoord;
layout(location = 0) out vec4 outColor;

layout(std140, set = 1, binding = 0) uniform CameraBlock {
    vec2 resolution;
    vec2 _pad;
    vec3 cam_pos;
    float fov;
    mat3 cam_rot;
};

struct SDFObject {
    vec3 position;
    uint sdf_type;
    vec4 params;
    vec3 color;
    uint operation;
    float smooth_factor;
    float _pad[3];
};

layout(std430, set = 0, binding = 0) readonly buffer SceneBlock {
    uint object_count;
    uint _pad2[3];
    SDFObject objects[];
};

#define MAX_STEPS 100
#define MAX_DIST 100.0
#define SURF_DIST 0.001

// Types SDF
#define SDF_SPHERE 0
#define SDF_BOX 1
#define SDF_TORUS 2
#define SDF_CYLINDER 3

// Opérations
#define OP_NONE 0
#define OP_UNION 1
#define OP_SUBTRACT 2
#define OP_INTERSECT 3
#define OP_SMOOTH_UNION 4
#define OP_SMOOTH_SUBTRACT 5
#define OP_SMOOTH_INTERSECT 6

// ===== Structure pour distance + matériau =====

struct SceneInfo {
    float dist;
    int material;
};

// ===== Signed Distance Functions =====

float sdSphere(vec3 p, float r) {
    return length(p) - r;
}

float sdBox(vec3 p, vec3 b) {
    vec3 q = abs(p) - b;
    return length(max(q, 0.0)) + min(max(q.x, max(q.y, q.z)), 0.0);
}

float sdTorus(vec3 p, vec2 t) {
    vec2 q = vec2(length(p.xz) - t.x, p.y);
    return length(q) - t.y;
}

float sdCylinder(vec3 p, vec2 h) {
    vec2 d = abs(vec2(length(p.xz), p.y)) - h;
    return min(max(d.x, d.y), 0.0) + length(max(d, 0.0));
}

// ===== Smooth Operations =====

float smoothUnion(float d1, float d2, float k) {
    float h = clamp(0.5 + 0.5 * (d2 - d1) / k, 0.0, 1.0);
    return mix(d2, d1, h) - k * h * (1.0 - h);
}

float smoothSubtraction(float d1, float d2, float k) {
    float h = clamp(0.5 - 0.5 * (d2 + d1) / k, 0.0, 1.0);
    return mix(d2, -d1, h) + k * h * (1.0 - h);
}

float smoothIntersection(float d1, float d2, float k) {
    float h = clamp(0.5 - 0.5 * (d2 - d1) / k, 0.0, 1.0);
    return mix(d2, d1, h) + k * h * (1.0 - h);
}

// ===== Evaluate SDF Object =====

float evaluateSDF(SDFObject obj, vec3 p) {
    vec3 local_p = p - obj.position;
    
    if (obj.sdf_type == SDF_SPHERE) {
        return sdSphere(local_p, obj.params.x);
    } else if (obj.sdf_type == SDF_BOX) {
        return sdBox(local_p, obj.params.xyz);
    } else if (obj.sdf_type == SDF_TORUS) {
        return sdTorus(local_p, obj.params.xy);
    } else if (obj.sdf_type == SDF_CYLINDER) {
        return sdCylinder(local_p, obj.params.xy);
    }
    
    return 1000.0; // Invalid
}


// ===== Apply Operation =====

float applyOperation(float d1, float d2, uint op, float k) {
    if (op == OP_UNION) {
        return min(d1, d2);
    } else if (op == OP_SUBTRACT) {
        return max(-d1, d2);
    } else if (op == OP_INTERSECT) {
        return max(d1, d2);
    } else if (op == OP_SMOOTH_UNION) {
        return smoothUnion(d1, d2, k);
    } else if (op == OP_SMOOTH_SUBTRACT) {
        return smoothSubtraction(d1, d2, k);
    } else if (op == OP_SMOOTH_INTERSECT) {
        return smoothIntersection(d1, d2, k);
    }
    
    return d2; // Default: no operation
}


// ===== Get Object Color =====

vec3 getObjectColor(int material) {
    if (material == 0) {
        return vec3(0.0); // Ground (sera remplacé par la grille)
    }
    
    int obj_index = material - 1;
    if (obj_index >= 0 && obj_index < int(object_count)) {
        return objects[obj_index].color;
    }
    
    return vec3(0.7); // Default gray
}

// ===== Scene Definition avec matériaux =====

SceneInfo getDist(vec3 p) {
    // Ground
    float result_dist = p.y + 0.01;
    int result_mat = 0;

    for (uint i = 0; i < object_count && i < 128; ++i) {
        SDFObject obj = objects[i];
        float obj_dist = evaluateSDF(obj, p);

        if (i == 0 && obj.operation == OP_NONE) {
            // Premier objet, remplace le ground
            result_dist = obj_dist;
            result_mat = int(i + 1);
        } else {
            // Appliquer l'opération
            float prev_dist = result_dist;
            result_dist = applyOperation(obj_dist, result_dist, obj.operation, obj.smooth_factor);

            // Changer le matériau si cet objet est le plus proche
            if (result_dist == obj_dist || (obj.operation == OP_SMOOTH_UNION && obj_dist < prev_dist)) {
                result_mat = int(i + 1);
            }
        }
    }

    return SceneInfo(result_dist, result_mat);
}

// ===== Normal Calculation =====

vec3 getNormal(vec3 p) {
    vec2 e = vec2(0.001, 0.0);
    float d = getDist(p).dist;
    vec3 n = d - vec3(
        getDist(p - e.xyy).dist,
        getDist(p - e.yxy).dist,
        getDist(p - e.yyx).dist
    );
    return normalize(n);
}

// ===== Raymarching avec matériaux =====

SceneInfo rayMarch(vec3 ro, vec3 rd) {
    float dO = 0.0;
    int material = 0;
    
    for(int i = 0; i < MAX_STEPS; i++) {
        vec3 p = ro + rd * dO;
        SceneInfo info = getDist(p);
        dO += info.dist;
        material = info.material;
        
        if(dO > MAX_DIST || abs(info.dist) < SURF_DIST) break;
    }
    
    return SceneInfo(dO, material);
}

// ===== Lighting =====

float getLight(vec3 p) {
    vec3 lightPos = vec3(5.0, 5.0, -5.0);
    vec3 l = normalize(lightPos - p);
    vec3 n = getNormal(p);
    
    float dif = clamp(dot(n, l), 0.0, 1.0);
    
    // Soft shadows
    SceneInfo shadowInfo = rayMarch(p + n * SURF_DIST * 2.0, l);
    if(shadowInfo.dist < length(lightPos - p)) {
        dif *= 0.3;
    }
    
    return dif;
}

// ===== Grille style Blender =====

vec3 getGridColorAA(vec3 p) {
    vec2 coord = p.xz;
    
    // Dérivées pour l'antialiasing
    vec2 dx = dFdx(coord);
    vec2 dy = dFdy(coord);
    vec2 derivative = abs(vec2(length(vec2(dx.x, dy.x)), length(vec2(dx.y, dy.y))));
    
    vec2 grid = abs(fract(coord - 0.5) - 0.5) / (derivative * 2.0);
    float line = min(grid.x, grid.y);
    
    vec3 bg = vec3(0.15, 0.15, 0.18);
    vec3 grid_col = vec3(0.3, 0.3, 0.35);
    
    float grid_smooth = 1.0 - min(line, 1.0);
    vec3 color = mix(bg, grid_col, grid_smooth);
    
    // Axes
    if (abs(p.z) < 0.025) color = vec3(0.8, 0.2, 0.2);
    if (abs(p.x) < 0.025) color = vec3(0.2, 0.4, 0.8);
    
    return color;
}

// ===== Main Fragment Shader =====

void main() {
    // 1. UV normalisés
    vec2 uv = fragTexCoord * 2.0 - 1.0;

    // 2. Aspect ratio (à ajuster selon votre fenêtre)
    uv.x *= 800.0 / 600.0;
    
    // 3. FOV
    float fov_factor = tan(radians(fov * 0.5));
    uv *= fov_factor;
    
    // 4. Direction du rayon avec rotation caméra
    vec3 rd_local = vec3(uv.x, uv.y, 1.0);
    vec3 rd = normalize(cam_rot * rd_local);
    
    // 5. Position caméra
    vec3 ro = cam_pos;
    
    // 6. Raymarching
    SceneInfo info = rayMarch(ro, rd);
    
    // 7. Coloring
    vec3 col = vec3(0.0);
    
    if(info.dist < MAX_DIST) {
        vec3 p = ro + rd * info.dist;
        float light = getLight(p);
        vec3 baseColor;
        
        if (info.material == 0) {
            // Ground - grille style Blender
            baseColor = getGridColorAA(p);
        } else {
            baseColor = getObjectColor(info.material);
        }
        
        // Éclairage différent selon le matériau
        if (info.material == 0) {
            // Sol: moins affecté par l'éclairage, plus constant
            col = baseColor * (0.7 + 0.3 * light);
        } else {
            // Objets: éclairage dynamique complet
            col = baseColor * light;
            // Ambient light pour éviter le noir total
            col += baseColor * 0.1;
        }
        
        // Ambient occlusion subtile
        col += vec3(0.03, 0.03, 0.05);
    }
    else {
        // Sky gradient
        col = mix(vec3(0.5, 0.7, 1.0), vec3(0.2, 0.3, 0.5), uv.y * 0.5 + 0.5);
    }
    
    // 8. Gamma correction
    col = pow(col, vec3(0.4545));

    outColor = vec4(col, 1.0);
}
