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

// 4D rotation matrices for animation
fn rot4D_XY(angle: f32) -> mat4x4<f32> {
  let c = cos(angle);
  let s = sin(angle);
  return mat4x4<f32>(
    vec4<f32>(c, -s, 0.0, 0.0),
    vec4<f32>(s, c, 0.0, 0.0),
    vec4<f32>(0.0, 0.0, 1.0, 0.0),
    vec4<f32>(0.0, 0.0, 0.0, 1.0)
  );
}

fn rot4D_ZW(angle: f32) -> mat4x4<f32> {
  let c = cos(angle);
  let s = sin(angle);
  return mat4x4<f32>(
    vec4<f32>(1.0, 0.0, 0.0, 0.0),
    vec4<f32>(0.0, 1.0, 0.0, 0.0),
    vec4<f32>(0.0, 0.0, c, -s),
    vec4<f32>(0.0, 0.0, s, c)
  );
}

// 4D Menger cube distance function
fn menger4D(p4: vec4<f32>, iterations: i32) -> f32 {
  var pos = p4;
  var scale = 1.0;
  var offset = 1.0;
  
  // Initial bounds check for tesseract
  var d = max(max(abs(pos.x), abs(pos.y)), max(abs(pos.z), abs(pos.w))) - 1.0;
  if (d > 0.0) {
    return d;
  }
  
  for (var i = 0; i < iterations; i++) {
    // Scale up to examine detail
    pos = pos * 3.0;
    scale = scale * 3.0;
    
    // Apply Menger hole pattern in 4D
    // Count how many coordinates are in the "middle third"
    var middle_count = 0;
    var temp_pos = abs(pos);
    
    // Check each coordinate for middle third position
    if (temp_pos.x > 1.0 && temp_pos.x < 2.0) {
      middle_count += 1;
    }
    if (temp_pos.y > 1.0 && temp_pos.y < 2.0) {
      middle_count += 1;
    }
    if (temp_pos.z > 1.0 && temp_pos.z < 2.0) {
      middle_count += 1;
    }
    if (temp_pos.w > 1.0 && temp_pos.w < 2.0) {
      middle_count += 1;
    }
    
    // Remove points where 3 or more coordinates are in middle third
    if (middle_count >= 3) {
      return -1.0; // Inside removed region
    }
    
    // Apply 4D cross removal pattern
    var cross_removal = false;
    
    // XY-ZW cross
    if (temp_pos.x > 1.0 && temp_pos.x < 2.0 && 
        temp_pos.y > 1.0 && temp_pos.y < 2.0 &&
        temp_pos.z > 1.0 && temp_pos.z < 2.0) {
      cross_removal = true;
    }
    if (temp_pos.x > 1.0 && temp_pos.x < 2.0 && 
        temp_pos.y > 1.0 && temp_pos.y < 2.0 &&
        temp_pos.w > 1.0 && temp_pos.w < 2.0) {
      cross_removal = true;
    }
    if (temp_pos.z > 1.0 && temp_pos.z < 2.0 && 
        temp_pos.w > 1.0 && temp_pos.w < 2.0 &&
        temp_pos.x > 1.0 && temp_pos.x < 2.0) {
      cross_removal = true;
    }
    if (temp_pos.z > 1.0 && temp_pos.z < 2.0 && 
        temp_pos.w > 1.0 && temp_pos.w < 2.0 &&
        temp_pos.y > 1.0 && temp_pos.y < 2.0) {
      cross_removal = true;
    }
    
    if (cross_removal) {
      return -1.0; // Inside removed region
    }
    
    // Fold space for next iteration
    pos = vec4<f32>(
      pos.x - 3.0 * round(pos.x / 3.0),
      pos.y - 3.0 * round(pos.y / 3.0),
      pos.z - 3.0 * round(pos.z / 3.0),
      pos.w - 3.0 * round(pos.w / 3.0)
    );
  }
  
  // Final distance to tesseract
  var final_d = max(max(abs(pos.x), abs(pos.y)), max(abs(pos.z), abs(pos.w))) - 1.0;
  return final_d / scale;
}

// Stereographic projection from 4D to 3D
fn stereographic_project(p4: vec4<f32>) -> vec3<f32> {
  let epsilon = 0.001;
  let w_safe = max(p4.w, -1.0 + epsilon);
  let denom = 1.0 - w_safe;
  if (abs(denom) < epsilon) {
    // Handle singularity at north pole
    return vec3<f32>(p4.x, p4.y, p4.z) * 100.0;
  }
  return vec3<f32>(p4.x, p4.y, p4.z) / denom;
}

// Inverse stereographic projection
fn inverse_stereographic(p3: vec3<f32>) -> vec4<f32> {
  let r_sq = dot(p3, p3);
  let denom = r_sq + 1.0;
  return vec4<f32>(
    2.0 * p3.x / denom,
    2.0 * p3.y / denom,
    2.0 * p3.z / denom,
    (r_sq - 1.0) / denom
  );
}

// Distance function for the intersection
fn hyper_menger_sphere_distance(p3: vec3<f32>, time: f32) -> f32 {
  // Apply 4D rotations for animation
  let rot1 = rot4D_XY(time * 0.2);
  let rot2 = rot4D_ZW(time * 0.15);
  
  // Convert 3D point back to 4D via inverse stereographic projection
  var p4 = inverse_stereographic(p3);
  
  // Apply 4D rotations
  p4 = rot1 * p4;
  p4 = rot2 * p4;
  
  // Check if point is on 3-sphere (should be by construction, but verify)
  let sphere_constraint = abs(dot(p4, p4) - 1.0);
  if (sphere_constraint > 0.01) {
    return 1000.0; // Far from surface
  }
  
  // Scale for better visualization
  p4 = p4 * 1.5;
  
  // Compute 4D Menger distance
  let menger_dist = menger4D(p4, 4);
  
  if (menger_dist < 0.0) {
    return 1000.0; // Inside removed region
  }
  
  return menger_dist * 0.3; // Scale factor for visualization
}

// Ray marching
fn ray_march(ro: vec3<f32>, rd: vec3<f32>, time: f32) -> vec2<f32> {
  var t = 0.0;
  var min_dist = 1000.0;
  
  for (var i = 0; i < 128; i++) {
    let p = ro + t * rd;
    let d = hyper_menger_sphere_distance(p, time);
    min_dist = min(min_dist, d);
    
    if (d < 0.001) {
      return vec2<f32>(t, 1.0); // Hit
    }
    
    if (t > 20.0) {
      break;
    }
    
    t += d * 0.8; // Conservative step
  }
  
  return vec2<f32>(t, 0.0); // Miss
}

// Calculate normal using finite differences
fn calculate_normal(p: vec3<f32>, time: f32) -> vec3<f32> {
  let eps = 0.001;
  let dx = vec3<f32>(eps, 0.0, 0.0);
  let dy = vec3<f32>(0.0, eps, 0.0);
  let dz = vec3<f32>(0.0, 0.0, eps);
  
  let grad_x = hyper_menger_sphere_distance(p + dx, time) - hyper_menger_sphere_distance(p - dx, time);
  let grad_y = hyper_menger_sphere_distance(p + dy, time) - hyper_menger_sphere_distance(p - dy, time);
  let grad_z = hyper_menger_sphere_distance(p + dz, time) - hyper_menger_sphere_distance(p - dz, time);
  
  return normalize(vec3<f32>(grad_x, grad_y, grad_z));
}

// Get w-coordinate for coloring
fn get_w_coordinate(p3: vec3<f32>, time: f32) -> f32 {
  let rot1 = rot4D_XY(time * 0.2);
  let rot2 = rot4D_ZW(time * 0.15);
  
  var p4 = inverse_stereographic(p3);
  p4 = rot1 * p4;
  p4 = rot2 * p4;
  
  return p4.w;
}

// Color based on w-coordinate
fn get_color(w: f32) -> vec3<f32> {
  // w ranges from -1 to 1
  let t = (w + 1.0) * 0.5; // Normalize to [0,1]
  
  // Color interpolation
  let color1 = vec3<f32>(0.29, 0.08, 0.55); // Dark purple (#4a148c)
  let color2 = vec3<f32>(1.0, 0.34, 0.13);  // Deep orange (#ff5722)
  let color3 = vec3<f32>(1.0, 0.92, 0.23);   // Bright yellow (#ffeb3b)
  
  if (t < 0.5) {
    return mix(color1, color2, t * 2.0);
  } else {
    return mix(color2, color3, (t - 0.5) * 2.0);
  }
}

// Lighting calculation
fn calculate_lighting(pos: vec3<f32>, normal: vec3<f32>, view_dir: vec3<f32>, color: vec3<f32>) -> vec3<f32> {
  // Multiple light sources
  let light1_dir = normalize(vec3<f32>(1.0, 1.0, 0.5));
  let light2_dir = normalize(vec3<f32>(-0.5, -0.5, 1.0));
  
  // Ambient
  let ambient = color * 0.3;
  
  // Diffuse
  let diff1 = max(dot(normal, light1_dir), 0.0) * 0.6;
  let diff2 = max(dot(normal, light2_dir), 0.0) * 0.4;
  let diffuse = color * (diff1 + diff2);
  
  // Specular
  let reflect1 = reflect(-light1_dir, normal);
  let reflect2 = reflect(-light2_dir, normal);
  let spec1 = pow(max(dot(view_dir, reflect1), 0.0), 32.0) * 0.5;
  let spec2 = pow(max(dot(view_dir, reflect2), 0.0), 32.0) * 0.3;
  let specular = vec3<f32>(1.0) * (spec1 + spec2);
  
  return ambient + diffuse + specular;
}

@fragment
fn main_fs(@builtin(position) pos : vec4<f32>) -> @location(0) vec4<f32> {
  let resolution = vec2<f32>(1600.0, 1600.0);
  let uv = (pos.xy - resolution * 0.5) / resolution.y;
  let time = 0.0; // Static for now, could be animated
  
  // Camera setup
  let camera_pos = vec3<f32>(0.0, 0.0, 3.0);
  let camera_target = vec3<f32>(0.0, 0.0, 0.0);
  let camera_up = vec3<f32>(0.0, 1.0, 0.0);
  
  // Camera rotation for better view
  let angle = 0.3;
  let rotated_pos = vec3<f32>(
    camera_pos.x * cos(angle) - camera_pos.z * sin(angle),
    camera_pos.y,
    camera_pos.x * sin(angle) + camera_pos.z * cos(angle)
  );
  
  // Ray setup
  let forward = normalize(camera_target - rotated_pos);
  let right = normalize(cross(forward, camera_up));
  let up = cross(right, forward);
  
  let rd = normalize(forward + uv.x * right * 0.8 + uv.y * up * 0.8);
  let ro = rotated_pos;
  
  // Ray march
  let march_result = ray_march(ro, rd, time);
  let t = march_result.x;
  let hit = march_result.y;
  
  // Background gradient
  let bg_color = mix(
    vec3<f32>(0.05, 0.28, 0.63), // Dark blue
    vec3<f32>(0.0, 0.0, 0.0),    // Black
    length(uv)
  );
  
  if (hit < 0.5) {
    return vec4<f32>(bg_color, 1.0);
  }
  
  // Shading
  let hit_pos = ro + t * rd;
  let normal = calculate_normal(hit_pos, time);
  let w_coord = get_w_coordinate(hit_pos, time);
  let base_color = get_color(w_coord);
  
  let view_dir = normalize(-rd);
  let final_color = calculate_lighting(hit_pos, normal, view_dir, base_color);
  
  // Apply transparency and enhance the glow
  let alpha = 0.8;
  let glow = pow(max(dot(normal, view_dir), 0.0), 2.0) * 0.3;
  let enhanced_color = final_color + vec3<f32>(glow);
  
  // Tone mapping
  let tone_mapped = enhanced_color / (enhanced_color + vec3<f32>(1.0));
  
  return vec4<f32>(tone_mapped, alpha);
}