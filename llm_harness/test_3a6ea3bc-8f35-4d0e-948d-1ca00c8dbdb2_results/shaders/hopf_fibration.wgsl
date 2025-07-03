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
const TAU = 6.28318530718;
const MAX_STEPS = 128;
const MIN_DIST = 0.001;
const MAX_DIST = 100.0;
const TUBE_RADIUS = 0.08;

// HSV to RGB conversion
fn hsv_to_rgb(h: f32, s: f32, v: f32) -> vec3<f32> {
  let c = v * s;
  let h_prime = (h * 6.0) % 6.0;
  let x = c * (1.0 - abs((h_prime % 2.0) - 1.0));
  let m = v - c;
  
  var rgb: vec3<f32>;
  if (h_prime < 1.0) {
    rgb = vec3<f32>(c, x, 0.0);
  } else if (h_prime < 2.0) {
    rgb = vec3<f32>(x, c, 0.0);
  } else if (h_prime < 3.0) {
    rgb = vec3<f32>(0.0, c, x);
  } else if (h_prime < 4.0) {
    rgb = vec3<f32>(0.0, x, c);
  } else if (h_prime < 5.0) {
    rgb = vec3<f32>(x, 0.0, c);
  } else {
    rgb = vec3<f32>(c, 0.0, x);
  }
  
  return rgb + vec3<f32>(m);
}

// Stereographic projection from S3 to R3
fn stereo_project(z0: vec2<f32>, z1: vec2<f32>) -> vec3<f32> {
  let x1 = z0.x;
  let x2 = z0.y;
  let x3 = z1.x;
  let x4 = z1.y;
  
  let denom = 1.0 - x4;
  if (abs(denom) < 0.0001) {
    return vec3<f32>(0.0, 0.0, 1000.0); // Point at infinity
  }
  
  return vec3<f32>(x1, x2, x3) / denom;
}

// Generate point on torus in S3 for given latitude and parameters
fn torus_point(latitude: f32, phi: f32, theta: f32) -> vec3<f32> {
  let cos_lat = cos(latitude);
  let sin_lat = sin(latitude);
  
  // From the Hopf fibration inverse
  // For a point (2z0*conj(z1), |z0|^2 - |z1|^2) on S2
  // We need |z0|^2 + |z1|^2 = 1
  
  let r = sqrt((1.0 + sin_lat) * 0.5);  // |z0|
  let s = sqrt((1.0 - sin_lat) * 0.5);  // |z1|
  
  let z0 = vec2<f32>(r * cos(phi * 0.5 + theta), r * sin(phi * 0.5 + theta));
  let z1 = vec2<f32>(s * cos(phi * 0.5 - theta), s * sin(phi * 0.5 - theta));
  
  return stereo_project(z0, z1);
}

// Distance to torus tube
fn torus_sdf(p: vec3<f32>, latitude: f32) -> f32 {
  var min_dist = MAX_DIST;
  
  // Sample the torus parametrically
  for (var i = 0; i < 32; i++) {
    let phi = f32(i) * TAU / 32.0;
    
    for (var j = 0; j < 16; j++) {
      let theta = f32(j) * TAU / 16.0;
      let torus_p = torus_point(latitude, phi, theta);
      
      let d = length(p - torus_p) - TUBE_RADIUS;
      min_dist = min(min_dist, d);
    }
  }
  
  return min_dist;
}

// Main SDF combining all three tori
fn scene_sdf(p: vec3<f32>) -> vec4<f32> {
  let d1 = torus_sdf(p, PI / 3.0);      // 60 degrees
  let d2 = torus_sdf(p, PI / 2.0);      // 0 degrees  
  let d3 = torus_sdf(p, 2.0 * PI / 3.0); // -60 degrees
  
  var min_dist = d1;
  var material = 1.0;
  
  if (d2 < min_dist) {
    min_dist = d2;
    material = 2.0;
  }
  
  if (d3 < min_dist) {
    min_dist = d3;
    material = 3.0;
  }
  
  return vec4<f32>(min_dist, material, 0.0, 0.0);
}

// Get color for a point on the torus based on phi parameter
fn get_torus_color(p: vec3<f32>, material: f32) -> vec3<f32> {
  var latitude: f32;
  if (material < 1.5) {
    latitude = PI / 3.0;
  } else if (material < 2.5) {
    latitude = PI / 2.0;
  } else {
    latitude = 2.0 * PI / 3.0;
  }
  
  // Find closest phi parameter
  var min_dist = MAX_DIST;
  var closest_phi = 0.0;
  
  for (var i = 0; i < 64; i++) {
    let phi = f32(i) * TAU / 64.0;
    
    for (var j = 0; j < 16; j++) {
      let theta = f32(j) * TAU / 16.0;
      let torus_p = torus_point(latitude, phi, theta);
      
      let d = length(p - torus_p);
      if (d < min_dist) {
        min_dist = d;
        closest_phi = phi;
      }
    }
  }
  
  let hue = closest_phi / TAU;
  return hsv_to_rgb(hue, 0.8, 0.9);
}

// Ray marching
fn ray_march(ro: vec3<f32>, rd: vec3<f32>) -> vec4<f32> {
  var t = 0.0;
  
  for (var i = 0; i < MAX_STEPS; i++) {
    let p = ro + t * rd;
    let result = scene_sdf(p);
    let d = result.x;
    
    if (d < MIN_DIST) {
      return vec4<f32>(t, result.y, 0.0, 1.0);
    }
    
    if (t > MAX_DIST) {
      break;
    }
    
    t += d * 0.5; // Conservative step
  }
  
  return vec4<f32>(-1.0, 0.0, 0.0, 0.0);
}

// Calculate normal using gradient
fn calc_normal(p: vec3<f32>) -> vec3<f32> {
  let eps = 0.001;
  let h = vec2<f32>(eps, 0.0);
  return normalize(vec3<f32>(
    scene_sdf(p + h.xyy).x - scene_sdf(p - h.xyy).x,
    scene_sdf(p + h.yxy).x - scene_sdf(p - h.yxy).x,
    scene_sdf(p + h.yyx).x - scene_sdf(p - h.yyx).x
  ));
}

// Simple sphere SDF for the reference S2
fn sphere_sdf(p: vec3<f32>, center: vec3<f32>, radius: f32) -> f32 {
  return length(p - center) - radius;
}

@fragment
fn main_fs(@builtin(position) pos : vec4<f32>) -> @location(0) vec4<f32> {
  let resolution = vec2<f32>(1600.0, 1600.0);
  let uv = (pos.xy - resolution * 0.5) / resolution.y;
  
  // Camera setup
  let camera_pos = vec3<f32>(8.0, 6.0, 10.0);
  let look_at = vec3<f32>(0.0, 0.0, 0.0);
  let up = vec3<f32>(0.0, 1.0, 0.0);
  
  let forward = normalize(look_at - camera_pos);
  let right = normalize(cross(forward, up));
  let camera_up = cross(right, forward);
  
  let ray_dir = normalize(forward + uv.x * right + uv.y * camera_up);
  
  // Check for reference sphere first (lower right)
  let sphere_center = vec3<f32>(4.0, -3.0, 2.0);
  let sphere_radius = 1.5;
  let sphere_t = length(camera_pos - sphere_center);
  
  if (uv.x > 0.3 && uv.y < -0.3) {
    let sphere_ray_dir = normalize(sphere_center - camera_pos + vec3<f32>(uv.x * 2.0, uv.y * 2.0, 0.0));
    let sphere_d = sphere_sdf(camera_pos + sphere_ray_dir * sphere_t, sphere_center, sphere_radius);
    
    if (sphere_d < 0.1) {
      // Draw reference sphere with latitude lines
      let p = normalize((camera_pos + sphere_ray_dir * sphere_t) - sphere_center);
      let lat = asin(p.z);
      
      // Check if on one of the three reference latitudes
      if (abs(lat - PI/6.0) < 0.05) {  // 30 degrees
        let phi = atan2(p.y, p.x);
        let hue = (phi + PI) / TAU;
        return vec4<f32>(hsv_to_rgb(hue, 0.8, 0.9), 1.0);
      } else if (abs(lat) < 0.05) {  // 0 degrees
        let phi = atan2(p.y, p.x);
        let hue = (phi + PI) / TAU;
        return vec4<f32>(hsv_to_rgb(hue, 0.8, 0.9), 1.0);
      } else if (abs(lat + PI/6.0) < 0.05) {  // -30 degrees
        let phi = atan2(p.y, p.x);
        let hue = (phi + PI) / TAU;
        return vec4<f32>(hsv_to_rgb(hue, 0.8, 0.9), 1.0);
      } else {
        return vec4<f32>(0.7, 0.7, 0.7, 0.3);  // Translucent grey
      }
    }
  }
  
  // Ray march the main scene
  let march_result = ray_march(camera_pos, ray_dir);
  
  if (march_result.w > 0.0) {
    let hit_point = camera_pos + ray_dir * march_result.x;
    let normal = calc_normal(hit_point);
    let material = march_result.y;
    
    // Get material color
    let base_color = get_torus_color(hit_point, material);
    
    // Simple Phong shading
    let light_dir = normalize(vec3<f32>(1.0, 1.0, 1.0));
    let view_dir = normalize(camera_pos - hit_point);
    let reflect_dir = reflect(-light_dir, normal);
    
    let ambient = 0.2;
    let diffuse = max(0.0, dot(normal, light_dir)) * 0.6;
    let specular = pow(max(0.0, dot(view_dir, reflect_dir)), 32.0) * 0.2;
    
    let final_color = base_color * (ambient + diffuse) + vec3<f32>(specular);
    
    return vec4<f32>(final_color, 1.0);
  }
  
  // White background
  return vec4<f32>(1.0, 1.0, 1.0, 1.0);
}