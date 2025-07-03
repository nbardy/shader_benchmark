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

// Constants for ray marching
const MAX_STEPS = 128;
const MIN_DIST = 0.001;
const MAX_DIST = 100.0;
const EPSILON = 0.0005;
const MAX_ITERATIONS = 4;

// Menger cube distance field with 4 iterations
fn menger_sdf(p: vec3<f32>) -> f32 {
  var pos = p;
  var scale = 1.0;
  var d = length(max(abs(pos) - vec3<f32>(1.0), vec3<f32>(0.0))) - 0.0;
  
  for (var i = 0; i < MAX_ITERATIONS; i++) {
    var a = (pos * 3.0 + 1.0) % 2.0 - 1.0;
    scale = scale / 3.0;
    
    var r = 1.0 - 3.0 * abs(a);
    var c = cross_pattern(a / scale) * scale;
    d = max(d, c);
    
    pos = a;
  }
  
  return d;
}

// Cross pattern for Menger cube holes
fn cross_pattern(p: vec3<f32>) -> f32 {
  var pos = abs(p);
  var da = max(pos.y, pos.z) - 0.333;
  var db = max(pos.z, pos.x) - 0.333;
  var dc = max(pos.x, pos.y) - 0.333;
  return min(da, min(db, dc));
}

// Rotation matrix around Y axis
fn rot_y(angle: f32) -> mat3x3<f32> {
  let c = cos(angle);
  let s = sin(angle);
  return mat3x3<f32>(
    vec3<f32>(c, 0.0, s),
    vec3<f32>(0.0, 1.0, 0.0),
    vec3<f32>(-s, 0.0, c)
  );
}

// Rotation matrix around X axis
fn rot_x(angle: f32) -> mat3x3<f32> {
  let c = cos(angle);
  let s = sin(angle);
  return mat3x3<f32>(
    vec3<f32>(1.0, 0.0, 0.0),
    vec3<f32>(0.0, c, -s),
    vec3<f32>(0.0, s, c)
  );
}

// Scene SDF with rotated Menger cube
fn scene_sdf(p: vec3<f32>) -> f32 {
  var pos = p;
  // Apply rotations to show 3D structure
  pos = rot_y(0.6) * pos;
  pos = rot_x(0.3) * pos;
  return menger_sdf(pos);
}

// Calculate normal using finite differences
fn calc_normal(p: vec3<f32>) -> vec3<f32> {
  let e = vec2<f32>(EPSILON, 0.0);
  return normalize(vec3<f32>(
    scene_sdf(p + e.xyy) - scene_sdf(p - e.xyy),
    scene_sdf(p + e.yxy) - scene_sdf(p - e.yxy),
    scene_sdf(p + e.yyx) - scene_sdf(p - e.yyx)
  ));
}

// Ray marching
fn ray_march(ray_origin: vec3<f32>, ray_dir: vec3<f32>) -> f32 {
  var depth = 0.0;
  
  for (var i = 0; i < MAX_STEPS; i++) {
    let pos = ray_origin + depth * ray_dir;
    let dist = scene_sdf(pos);
    
    if (dist < EPSILON) {
      return depth;
    }
    
    depth += dist;
    if (depth >= MAX_DIST) {
      break;
    }
  }
  
  return MAX_DIST;
}

// Calculate color based on depth/iteration level
fn get_material_color(p: vec3<f32>, normal: vec3<f32>) -> vec3<f32> {
  var pos = p;
  pos = rot_x(-0.3) * pos;
  pos = rot_y(-0.6) * pos;
  
  var scale = 1.0;
  var level = 0;
  
  // Find which iteration level this point belongs to
  for (var i = 0; i < MAX_ITERATIONS; i++) {
    var a = (pos * 3.0 + 1.0) % 2.0 - 1.0;
    scale = scale / 3.0;
    
    if (length(a) > 0.5) {
      level = i;
      break;
    }
    pos = a;
  }
  
  // Color gradient based on iteration level
  if (level == 0) {
    return vec3<f32>(0.102, 0.137, 0.494); // Deep blue
  } else if (level == 1) {
    return vec3<f32>(0.157, 0.208, 0.576); // Blue
  } else if (level == 2) {
    return vec3<f32>(0.224, 0.286, 0.671); // Light blue
  } else if (level == 3) {
    return vec3<f32>(0.149, 0.776, 0.855); // Cyan
  } else {
    return vec3<f32>(1.0, 1.0, 1.0); // White
  }
}

// Three-point lighting calculation
fn calculate_lighting(p: vec3<f32>, normal: vec3<f32>, view_dir: vec3<f32>) -> f32 {
  // Key light (upper-left-front)
  let key_light = normalize(vec3<f32>(-2.0, 3.0, 4.0));
  let key_intensity = max(0.0, dot(normal, key_light)) * 0.7;
  
  // Fill light (lower-right)
  let fill_light = normalize(vec3<f32>(2.0, -1.0, 2.0));
  let fill_intensity = max(0.0, dot(normal, fill_light)) * 0.3;
  
  // Rim light (from behind)
  let rim_light = normalize(vec3<f32>(0.0, 1.0, -2.0));
  let rim_intensity = max(0.0, dot(normal, rim_light)) * 0.4;
  
  // Ambient lighting
  let ambient = 0.2;
  
  // Specular reflection
  let reflect_dir = reflect(-key_light, normal);
  let spec = pow(max(0.0, dot(view_dir, reflect_dir)), 32.0) * 0.5;
  
  return key_intensity + fill_intensity + rim_intensity + ambient + spec;
}

// Fragment shader - Menger cube ray tracer
@fragment
fn main_fs(@builtin(position) pos : vec4<f32>) -> @location(0) vec4<f32> {
  let resolution = 1600.0;
  let uv = (pos.xy - resolution * 0.5) / resolution;
  
  // Camera setup
  let camera_pos = vec3<f32>(0.0, 0.0, 4.5);
  let look_at = vec3<f32>(0.0, 0.0, 0.0);
  let up = vec3<f32>(0.0, 1.0, 0.0);
  
  // Create camera rays
  let forward = normalize(look_at - camera_pos);
  let right = normalize(cross(forward, up));
  let camera_up = cross(right, forward);
  
  let ray_dir = normalize(
    uv.x * right + 
    uv.y * camera_up + 
    1.5 * forward
  );
  
  // Ray march to find intersection
  let depth = ray_march(camera_pos, ray_dir);
  
  if (depth >= MAX_DIST) {
    // Background gradient
    let t = uv.y * 0.5 + 0.5;
    let bg_top = vec3<f32>(0.051, 0.067, 0.090);    // #0d1117
    let bg_bottom = vec3<f32>(0.129, 0.149, 0.176); // #21262d
    let bg_color = mix(bg_bottom, bg_top, t);
    return vec4<f32>(bg_color, 1.0);
  }
  
  // Calculate surface properties
  let hit_pos = camera_pos + depth * ray_dir;
  let normal = calc_normal(hit_pos);
  let view_dir = normalize(camera_pos - hit_pos);
  
  // Get material color and apply lighting
  let base_color = get_material_color(hit_pos, normal);
  let lighting = calculate_lighting(hit_pos, normal, view_dir);
  
  // Add some metallic reflection
  let metallic = 0.3;
  let final_color = base_color * lighting + metallic * pow(lighting, 2.0);
  
  // Simple bloom effect on bright edges
  let edge_factor = 1.0 - abs(dot(normal, view_dir));
  let bloom = pow(edge_factor, 3.0) * 0.2;
  
  return vec4<f32>(final_color + bloom, 1.0);
}