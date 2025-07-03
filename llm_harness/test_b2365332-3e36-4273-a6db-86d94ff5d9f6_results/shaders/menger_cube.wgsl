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
const MAX_ITERATIONS = 4;
const MAX_STEPS = 200;
const MIN_DISTANCE = 0.0001;
const MAX_DISTANCE = 50.0;

// Time simulation for rotation
fn get_time() -> f32 {
  return 0.5; // Static time for consistent rendering
}

// 3D rotation matrices
fn rotate_x(angle: f32) -> mat3x3<f32> {
  let c = cos(angle);
  let s = sin(angle);
  return mat3x3<f32>(
    vec3<f32>(1.0, 0.0, 0.0),
    vec3<f32>(0.0, c, -s),
    vec3<f32>(0.0, s, c)
  );
}

fn rotate_y(angle: f32) -> mat3x3<f32> {
  let c = cos(angle);
  let s = sin(angle);
  return mat3x3<f32>(
    vec3<f32>(c, 0.0, s),
    vec3<f32>(0.0, 1.0, 0.0),
    vec3<f32>(-s, 0.0, c)
  );
}

fn rotate_z(angle: f32) -> mat3x3<f32> {
  let c = cos(angle);
  let s = sin(angle);
  return mat3x3<f32>(
    vec3<f32>(c, -s, 0.0),
    vec3<f32>(s, c, 0.0),
    vec3<f32>(0.0, 0.0, 1.0)
  );
}

// Box SDF
fn box_sdf(p: vec3<f32>, b: vec3<f32>) -> f32 {
  let q = abs(p) - b;
  return length(max(q, vec3<f32>(0.0))) + min(max(q.x, max(q.y, q.z)), 0.0);
}

// Cross SDF for making holes
fn cross_sdf(p: vec3<f32>, size: f32) -> f32 {
  let da = box_sdf(p, vec3<f32>(size, size / 3.0, size));
  let db = box_sdf(p, vec3<f32>(size / 3.0, size, size));
  let dc = box_sdf(p, vec3<f32>(size / 3.0, size, size / 3.0));
  return min(da, min(db, dc));
}

// Menger cube SDF with proper iteration-based construction
fn menger_sdf(p: vec3<f32>) -> vec2<f32> {
  var pos = p;
  var scale = 1.0;
  var dist = box_sdf(pos, vec3<f32>(1.0));
  var iteration = 0.0;
  
  for (var i = 0; i < MAX_ITERATIONS; i++) {
    // Scale position for next iteration
    pos = pos * 3.0;
    scale = scale * 3.0;
    
    // Create the cross pattern holes
    let cross_size = 1.0;
    let hole = cross_sdf(pos, cross_size);
    
    // Subtract holes from the current structure
    dist = max(dist, -hole / scale);
    
    // Fold the space to create the recursive pattern
    pos = abs(pos);
    if (pos.x < pos.y) {
      let temp = pos.x;
      pos.x = pos.y;
      pos.y = temp;
    }
    if (pos.x < pos.z) {
      let temp = pos.x;
      pos.x = pos.z;
      pos.z = temp;
    }
    if (pos.y < pos.z) {
      let temp = pos.y;
      pos.y = pos.z;
      pos.z = temp;
    }
    
    pos = pos - vec3<f32>(2.0, 2.0, 2.0);
    
    if (pos.x < 0.0) { pos.x = -pos.x; }
    if (pos.y < 0.0) { pos.y = -pos.y; }
    if (pos.z < 0.0) { pos.z = -pos.z; }
    
    iteration = f32(i);
  }
  
  return vec2<f32>(dist, iteration);
}

// Alternative Menger implementation using the mathematical definition
fn menger_sdf_v2(p: vec3<f32>) -> vec2<f32> {
  var pos = p;
  var d = box_sdf(pos, vec3<f32>(1.0));
  var iteration = 0.0;
  var scale = 1.0;
  
  for (var i = 0; i < MAX_ITERATIONS; i++) {
    let a = (pos * scale + 1.0);
    let r = floor(a);
    let c = a - r - 0.5;
    
    scale = scale * 3.0;
    pos = c;
    
    // Check if we're in a hole position
    let hole_mask = step(1.0, abs(c.x)) + step(1.0, abs(c.y)) + step(1.0, abs(c.z));
    
    if (hole_mask > 1.5) {
      d = max(d, -(length(c) - 0.3) / scale);
    }
    
    iteration = f32(i);
  }
  
  return vec2<f32>(d, iteration);
}

// Main Menger cube SDF using cross subtraction method
fn menger_cube_sdf(p: vec3<f32>) -> vec2<f32> {
  var d = box_sdf(p, vec3<f32>(1.0));
  var iteration = 0.0;
  var scale = 1.0;
  
  for (var i = 0; i < MAX_ITERATIONS; i++) {
    scale = scale / 3.0;
    
    // Create cross-shaped holes
    let cross1 = max(
      box_sdf(p, vec3<f32>(1.0, scale, scale)),
      box_sdf(p, vec3<f32>(scale, 1.0, scale))
    );
    let cross2 = box_sdf(p, vec3<f32>(scale, scale, 1.0));
    let cross = min(cross1, cross2);
    
    d = max(d, -cross);
    
    // Recursive subdivision
    var q = abs(p);
    q = q - scale * 2.0;
    p = sign(p) * max(q, vec3<f32>(0.0));
    
    iteration = f32(i);
  }
  
  return vec2<f32>(d, iteration);
}

// Ray marching
fn ray_march(ro: vec3<f32>, rd: vec3<f32>) -> vec4<f32> {
  var t = 0.0;
  var iteration = 0.0;
  
  for (var i = 0; i < MAX_STEPS; i++) {
    let pos = ro + t * rd;
    let result = menger_cube_sdf(pos);
    let d = result.x;
    iteration = result.y;
    
    if (d < MIN_DISTANCE) {
      return vec4<f32>(pos, iteration);
    }
    
    t += d;
    if (t > MAX_DISTANCE) {
      break;
    }
  }
  
  return vec4<f32>(0.0, 0.0, 0.0, -1.0);
}

// Calculate normal using finite differences
fn calculate_normal(p: vec3<f32>) -> vec3<f32> {
  let eps = vec2<f32>(MIN_DISTANCE, 0.0);
  return normalize(vec3<f32>(
    menger_cube_sdf(p + eps.xyy).x - menger_cube_sdf(p - eps.xyy).x,
    menger_cube_sdf(p + eps.yxy).x - menger_cube_sdf(p - eps.yxy).x,
    menger_cube_sdf(p + eps.yyx).x - menger_cube_sdf(p - eps.yyx).x
  ));
}

// Multi-light setup
fn calculate_lighting(pos: vec3<f32>, normal: vec3<f32>, view_dir: vec3<f32>, iteration: f32) -> vec3<f32> {
  // Key light (upper-left-front)
  let key_light = normalize(vec3<f32>(-0.5, 0.8, 1.0));
  let key_intensity = max(dot(normal, key_light), 0.0);
  
  // Fill light (lower-right)
  let fill_light = normalize(vec3<f32>(0.7, -0.3, 0.5));
  let fill_intensity = max(dot(normal, fill_light), 0.0) * 0.6;
  
  // Rim light (behind)
  let rim_light = normalize(vec3<f32>(0.0, 0.2, -1.0));
  let rim_intensity = max(dot(normal, rim_light), 0.0) * 0.4;
  
  // Specular highlights
  let reflect_dir = reflect(-key_light, normal);
  let specular = pow(max(dot(view_dir, reflect_dir), 0.0), 32.0) * 0.5;
  
  // Ambient lighting
  let ambient = 0.1;
  
  let total_lighting = ambient + key_intensity + fill_intensity + rim_intensity + specular;
  return vec3<f32>(total_lighting);
}

// Color gradient based on iteration level
fn get_iteration_color(iteration: f32) -> vec3<f32> {
  // Color scheme as specified
  let colors = array<vec3<f32>, 5>(
    vec3<f32>(0.102, 0.137, 0.494), // Level 0: Deep blue #1a237e
    vec3<f32>(0.157, 0.208, 0.576), // Level 1: Blue #283593
    vec3<f32>(0.224, 0.286, 0.671), // Level 2: Light blue #3949ab
    vec3<f32>(0.149, 0.776, 0.855), // Level 3: Cyan #26c6da
    vec3<f32>(1.0, 1.0, 1.0)        // Level 4+: White #ffffff
  );
  
  let idx = i32(min(iteration, 4.0));
  let t = fract(iteration);
  
  if (idx >= 4) {
    return colors[4];
  }
  
  return mix(colors[idx], colors[idx + 1], t);
}

// Soft shadows
fn calculate_shadow(pos: vec3<f32>, light_dir: vec3<f32>) -> f32 {
  var t = 0.01;
  var shadow = 1.0;
  let k = 8.0; // Shadow softness
  
  for (var i = 0; i < 32; i++) {
    let sample_pos = pos + t * light_dir;
    let d = menger_cube_sdf(sample_pos).x;
    
    if (d < MIN_DISTANCE) {
      return 0.1;
    }
    
    shadow = min(shadow, k * d / t);
    t += d;
    
    if (t > 5.0) {
      break;
    }
  }
  
  return max(shadow, 0.1);
}

// Main fragment shader
@fragment
fn main_fs(@builtin(position) pos : vec4<f32>) -> @location(0) vec4<f32> {
  // Normalize coordinates to [-1, 1]
  let resolution = vec2<f32>(1600.0, 1600.0); // Target resolution
  let uv = (pos.xy - resolution * 0.5) / min(resolution.x, resolution.y);
  
  // Camera setup with dynamic perspective
  let time = get_time();
  let camera_pos = vec3<f32>(3.5, 2.8, 4.2);
  let look_at = vec3<f32>(0.0, 0.0, 0.0);
  let up = vec3<f32>(0.0, 1.0, 0.0);
  
  // Camera matrices
  let forward = normalize(look_at - camera_pos);
  let right = normalize(cross(forward, up));
  let camera_up = cross(right, forward);
  
  // Ray direction with field of view
  let fov = 0.8;
  let ray_dir = normalize(forward + uv.x * right * fov + uv.y * camera_up * fov);
  
  // Apply rotation to the fractal
  let rotation = rotate_x(0.2) * rotate_y(0.3) * rotate_z(0.1);
  let rotated_ray_dir = rotation * ray_dir;
  let rotated_camera_pos = rotation * camera_pos;
  
  // Ray march the scene
  let hit = ray_march(rotated_camera_pos, rotated_ray_dir);
  
  // Background gradient
  let bg_color = mix(
    vec3<f32>(0.051, 0.067, 0.090), // #0d1117 (top)
    vec3<f32>(0.129, 0.149, 0.176), // #21262d (bottom)
    uv.y * 0.5 + 0.5
  );
  
  if (hit.w < 0.0) {
    return vec4<f32>(bg_color, 1.0);
  }
  
  // Lighting calculations
  let hit_pos = hit.xyz;
  let normal = calculate_normal(hit_pos);
  let view_dir = normalize(rotated_camera_pos - hit_pos);
  let iteration = hit.w;
  
  // Get material color based on iteration
  let material_color = get_iteration_color(iteration);
  
  // Calculate lighting
  let lighting = calculate_lighting(hit_pos, normal, view_dir, iteration);
  
  // Shadow calculation for key light
  let key_light = normalize(vec3<f32>(-0.5, 0.8, 1.0));
  let shadow = calculate_shadow(hit_pos + normal * 0.001, key_light);
  
  // Final color composition
  var color = material_color * lighting * shadow;
  
  // Metallic/crystalline appearance enhancement
  let fresnel = pow(1.0 - max(dot(view_dir, normal), 0.0), 2.0);
  color = mix(color, vec3<f32>(1.0), fresnel * 0.2);
  
  // Subtle bloom effect on edges
  let edge_glow = pow(fresnel, 8.0) * 0.3;
  color += vec3<f32>(edge_glow);
  
  // Gamma correction and tone mapping
  color = pow(color, vec3<f32>(0.8)); // Slight gamma adjustment
  color = color / (1.0 + color); // Simple tone mapping
  
  return vec4<f32>(color, 1.0);
}