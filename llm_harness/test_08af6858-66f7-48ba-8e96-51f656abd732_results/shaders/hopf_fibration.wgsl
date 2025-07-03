// Vertex shader - full-screen triangle
struct VertexOut {
  @builtin(position) pos : vec4<f32>,
};

@vertex
fn main_vs(@builtin(vertex_index) vid : u32) -> VertexOut {
  var xy : vec2<f32>;
  if (vid == 0u) {
    xy = vec2<f32>(-1.0, -3.0);
  } else if (vid == 1u) {
    xy = vec2<f32>( 3.0,  1.0);
  } else {
    xy = vec2<f32>(-1.0,  1.0);
  }
  var o : VertexOut;
  o.pos = vec4<f32>(xy, 0.0, 1.0);
  return o;
}

// Constants
const PI = 3.14159265359;
const TWO_PI = 6.28318530718;
const EPS = 0.001;
const TUBE_RADIUS = 0.02;
const MAX_STEPS = 200;
const MAX_DIST = 20.0;

// HSV to RGB conversion
fn hsv_to_rgb(h: f32, s: f32, v: f32) -> vec3<f32> {
    let c = v * s;
    let x = c * (1.0 - abs(((h * 6.0) % 2.0) - 1.0));
    let m = v - c;
    
    var rgb = vec3<f32>(0.0);
    let h6 = h * 6.0;
    
    if (h6 < 1.0) {
        rgb = vec3<f32>(c, x, 0.0);
    } else if (h6 < 2.0) {
        rgb = vec3<f32>(x, c, 0.0);
    } else if (h6 < 3.0) {
        rgb = vec3<f32>(0.0, c, x);
    } else if (h6 < 4.0) {
        rgb = vec3<f32>(0.0, x, c);
    } else if (h6 < 5.0) {
        rgb = vec3<f32>(x, 0.0, c);
    } else {
        rgb = vec3<f32>(c, 0.0, x);
    }
    
    return rgb + m;
}

// Complex number operations
fn cmul(a: vec2<f32>, b: vec2<f32>) -> vec2<f32> {
    return vec2<f32>(a.x * b.x - a.y * b.y, a.x * b.y + a.y * b.x);
}

fn cconj(z: vec2<f32>) -> vec2<f32> {
    return vec2<f32>(z.x, -z.y);
}

// Hopf map: S^3 -> S^2
fn hopf_map(z0: vec2<f32>, z1: vec2<f32>) -> vec3<f32> {
    let w = 2.0 * cmul(z0, cconj(z1));
    let x = dot(z0, z0) - dot(z1, z1);
    return vec3<f32>(w, x);
}

// Inverse Hopf map for a given base point and fiber parameter
fn hopf_inverse(base_point: vec3<f32>, t: f32) -> vec4<f32> {
    // Convert base point from Cartesian to complex form
    let w = vec2<f32>(base_point.x, base_point.y);
    let x = base_point.z;
    
    // Parametrize the fiber
    let phase = vec2<f32>(cos(t), sin(t));
    
    // Construct preimage point on S^3
    let alpha = sqrt(0.5 * (1.0 + x));
    let beta = sqrt(0.5 * (1.0 - x));
    
    var z0: vec2<f32>;
    var z1: vec2<f32>;
    
    if (alpha > EPS) {
        z0 = alpha * phase;
        if (beta > EPS) {
            z1 = beta * cmul(w / length(w), cconj(phase));
        } else {
            z1 = vec2<f32>(0.0);
        }
    } else {
        z0 = vec2<f32>(0.0);
        z1 = phase;
    }
    
    return vec4<f32>(z0, z1);
}

// Stereographic projection from S^3 to R^3
fn stereographic_proj(p: vec4<f32>) -> vec3<f32> {
    if (p.w > 0.999) {
        return vec3<f32>(0.0, 0.0, 1000.0); // Point at infinity
    }
    let denom = 1.0 - p.w;
    return vec3<f32>(p.x / denom, p.y / denom, p.z / denom);
}

// Get base point for the three latitude circles
fn get_base_point(loop_id: i32, phi: f32) -> vec3<f32> {
    var theta: f32;
    if (loop_id == 0) {
        theta = PI / 3.0; // 60 degrees
    } else if (loop_id == 1) {
        theta = PI / 2.0; // 0 degrees (equator)
    } else {
        theta = 2.0 * PI / 3.0; // -60 degrees
    }
    
    return vec3<f32>(
        sin(theta) * cos(phi),
        sin(theta) * sin(phi),
        cos(theta)
    );
}

// Distance to a torus fiber
fn fiber_distance(pos: vec3<f32>, loop_id: i32, phi: f32, t: f32) -> f32 {
    let base_point = get_base_point(loop_id, phi);
    let s3_point = hopf_inverse(base_point, t);
    let fiber_point = stereographic_proj(s3_point);
    return length(pos - fiber_point) - TUBE_RADIUS;
}

// Find minimum distance to all three tori
fn scene_distance(pos: vec3<f32>) -> vec4<f32> {
    var min_dist = MAX_DIST;
    var closest_loop = 0;
    var closest_phi = 0.0;
    
    let phi_steps = 64;
    let t_steps = 32;
    
    for (var loop_id = 0; loop_id < 3; loop_id++) {
        for (var phi_i = 0; phi_i < phi_steps; phi_i++) {
            let phi = f32(phi_i) / f32(phi_steps) * TWO_PI;
            
            for (var t_i = 0; t_i < t_steps; t_i++) {
                let t = f32(t_i) / f32(t_steps) * TWO_PI;
                let d = fiber_distance(pos, loop_id, phi, t);
                
                if (d < min_dist) {
                    min_dist = d;
                    closest_loop = loop_id;
                    closest_phi = phi;
                }
            }
        }
    }
    
    return vec4<f32>(min_dist, f32(closest_loop), closest_phi, 0.0);
}

// Estimate normal using finite differences
fn estimate_normal(pos: vec3<f32>) -> vec3<f32> {
    let h = EPS;
    let grad_x = scene_distance(pos + vec3<f32>(h, 0.0, 0.0)).x - 
                 scene_distance(pos - vec3<f32>(h, 0.0, 0.0)).x;
    let grad_y = scene_distance(pos + vec3<f32>(0.0, h, 0.0)).x - 
                 scene_distance(pos - vec3<f32>(0.0, h, 0.0)).x;
    let grad_z = scene_distance(pos + vec3<f32>(0.0, 0.0, h)).x - 
                 scene_distance(pos - vec3<f32>(0.0, 0.0, h)).x;
    return normalize(vec3<f32>(grad_x, grad_y, grad_z));
}

// Raymarching
fn raymarch(ray_origin: vec3<f32>, ray_dir: vec3<f32>) -> vec4<f32> {
    var t = 0.0;
    var info = vec4<f32>(0.0);
    
    for (var i = 0; i < MAX_STEPS; i++) {
        let pos = ray_origin + t * ray_dir;
        info = scene_distance(pos);
        
        if (info.x < EPS) {
            return vec4<f32>(t, info.yzw);
        }
        
        if (t > MAX_DIST) {
            break;
        }
        
        t += max(info.x * 0.5, EPS);
    }
    
    return vec4<f32>(-1.0, 0.0, 0.0, 0.0);
}

// Phong shading
fn phong_shading(pos: vec3<f32>, normal: vec3<f32>, view_dir: vec3<f32>, 
                color: vec3<f32>) -> vec3<f32> {
    let light_dir = normalize(vec3<f32>(1.0, 1.0, 2.0));
    
    // Ambient
    let ambient = 0.2 * color;
    
    // Diffuse
    let diffuse = max(dot(normal, light_dir), 0.0) * color;
    
    // Specular
    let reflect_dir = reflect(-light_dir, normal);
    let spec = pow(max(dot(view_dir, reflect_dir), 0.0), 32.0);
    let specular = vec3<f32>(0.3) * spec;
    
    return ambient + 0.6 * diffuse + specular;
}

// Draw reference sphere with base loops
fn draw_reference_sphere(uv: vec2<f32>) -> vec3<f32> {
    let sphere_center = vec2<f32>(0.8, -0.8);
    let sphere_radius = 0.15;
    let d = length(uv - sphere_center);
    
    if (d > sphere_radius) {
        return vec3<f32>(0.0);
    }
    
    // Map to sphere surface
    let x = (uv.x - sphere_center.x) / sphere_radius;
    let y = (uv.y - sphere_center.y) / sphere_radius;
    let z_sq = 1.0 - x*x - y*y;
    
    if (z_sq < 0.0) {
        return vec3<f32>(0.5); // Sphere body
    }
    
    let z = sqrt(z_sq);
    let sphere_pos = vec3<f32>(x, y, z);
    
    // Convert to spherical coordinates
    let theta = acos(sphere_pos.z);
    let phi = atan2(sphere_pos.y, sphere_pos.x);
    
    // Check if close to any of the three latitude lines
    let lat_60 = abs(theta - PI/3.0) < 0.05;
    let lat_0 = abs(theta - PI/2.0) < 0.05;
    let lat_neg60 = abs(theta - 2.0*PI/3.0) < 0.05;
    
    if (lat_60 || lat_0 || lat_neg60) {
        let hue = (phi + PI) / TWO_PI;
        return hsv_to_rgb(hue, 0.8, 1.0);
    }
    
    return vec3<f32>(0.7); // Sphere body
}

@fragment
fn main_fs(@builtin(position) pos : vec4<f32>) -> @location(0) vec4<f32> {
    let resolution = vec2<f32>(1600.0, 1600.0);
    let uv = (pos.xy - 0.5 * resolution) / min(resolution.x, resolution.y);
    
    // Camera setup
    let camera_pos = vec3<f32>(3.0, 3.0, 3.0);
    let camera_target = vec3<f32>(0.0, 0.0, 0.0);
    let camera_up = vec3<f32>(0.0, 0.0, 1.0);
    
    let w = normalize(camera_target - camera_pos);
    let u = normalize(cross(w, camera_up));
    let v = cross(u, w);
    
    let ray_dir = normalize(uv.x * u + uv.y * v + 2.0 * w);
    
    // Raymarch the scene
    let march_result = raymarch(camera_pos, ray_dir);
    
    var final_color = vec3<f32>(1.0); // White background
    
    // Draw reference sphere
    let ref_color = draw_reference_sphere(uv);
    if (length(ref_color) > 0.1) {
        final_color = ref_color;
    }
    
    // Draw main tori
    if (march_result.x > 0.0) {
        let hit_pos = camera_pos + march_result.x * ray_dir;
        let normal = estimate_normal(hit_pos);
        
        let loop_id = i32(march_result.y);
        let phi = march_result.z;
        
        // Color based on phi (position around base loop)
        let hue = phi / TWO_PI;
        let base_color = hsv_to_rgb(hue, 0.8, 1.0);
        
        // Apply Phong shading
        final_color = phong_shading(hit_pos, normal, -ray_dir, base_color);
    }
    
    return vec4<f32>(final_color, 1.0);
}