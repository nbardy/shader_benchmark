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

// Ray structure
struct Ray {
  origin: vec3<f32>,
  direction: vec3<f32>,
};

// Hit information
struct HitInfo {
  hit: bool,
  t: f32,
  point: vec3<f32>,
  normal: vec3<f32>,
  material_id: u32,
};

// Material constants
const MATERIAL_NONE: u32 = 0u;
const MATERIAL_GLASS: u32 = 1u;
const MATERIAL_RED_SPHERE: u32 = 2u;
const MATERIAL_GROUND: u32 = 3u;

// Glass properties
const GLASS_IOR: f32 = 1.52;
const GLASS_TRANSMISSION: f32 = 0.95;
const GLASS_TINT: vec3<f32> = vec3<f32>(0.98, 0.988, 1.0);

// Sphere geometry
const OUTER_RADIUS: f32 = 1.0;
const INNER_RADIUS: f32 = 0.85;
const RED_SPHERE_RADIUS: f32 = 0.6;

// Lighting
const LIGHT_DIR: vec3<f32> = normalize(vec3<f32>(-0.7, 0.7, -0.7));
const LIGHT_COLOR: vec3<f32> = vec3<f32>(1.0, 0.98, 0.95) * 3.0;
const AMBIENT: vec3<f32> = vec3<f32>(0.1, 0.1, 0.12) * 0.1;

// Camera setup
const CAMERA_POS: vec3<f32> = vec3<f32>(2.0, 1.0, 2.0);
const CAMERA_TARGET: vec3<f32> = vec3<f32>(0.0, 0.0, 0.0);

// Ray-sphere intersection
fn intersect_sphere(ray: Ray, center: vec3<f32>, radius: f32) -> f32 {
  let oc = ray.origin - center;
  let a = dot(ray.direction, ray.direction);
  let b = 2.0 * dot(oc, ray.direction);
  let c = dot(oc, oc) - radius * radius;
  let discriminant = b * b - 4.0 * a * c;
  
  if (discriminant < 0.0) {
    return -1.0;
  }
  
  let sqrt_d = sqrt(discriminant);
  let t1 = (-b - sqrt_d) / (2.0 * a);
  let t2 = (-b + sqrt_d) / (2.0 * a);
  
  if (t1 > 0.001) {
    return t1;
  } else if (t2 > 0.001) {
    return t2;
  }
  
  return -1.0;
}

// Ray-plane intersection (ground)
fn intersect_ground(ray: Ray) -> f32 {
  let plane_y = -1.5;
  if (abs(ray.direction.y) < 0.0001) {
    return -1.0;
  }
  
  let t = (plane_y - ray.origin.y) / ray.direction.y;
  if (t > 0.001) {
    return t;
  }
  
  return -1.0;
}

// Scene intersection
fn intersect_scene(ray: Ray) -> HitInfo {
  var hit: HitInfo;
  hit.hit = false;
  hit.t = 1e30;
  
  // Red inner sphere
  let t_red = intersect_sphere(ray, vec3<f32>(0.0), RED_SPHERE_RADIUS);
  if (t_red > 0.0 && t_red < hit.t) {
    hit.hit = true;
    hit.t = t_red;
    hit.point = ray.origin + t_red * ray.direction;
    hit.normal = normalize(hit.point);
    hit.material_id = MATERIAL_RED_SPHERE;
  }
  
  // Glass outer sphere
  let t_outer = intersect_sphere(ray, vec3<f32>(0.0), OUTER_RADIUS);
  if (t_outer > 0.0 && t_outer < hit.t) {
    hit.hit = true;
    hit.t = t_outer;
    hit.point = ray.origin + t_outer * ray.direction;
    hit.normal = normalize(hit.point);
    hit.material_id = MATERIAL_GLASS;
  }
  
  // Glass inner sphere (from outside)
  let t_inner = intersect_sphere(ray, vec3<f32>(0.0), INNER_RADIUS);
  if (t_inner > 0.0 && t_inner < hit.t) {
    let hit_point = ray.origin + t_inner * ray.direction;
    // Check if we're hitting from outside the glass
    if (length(ray.origin) > INNER_RADIUS) {
      hit.hit = true;
      hit.t = t_inner;
      hit.point = hit_point;
      hit.normal = -normalize(hit_point); // Inward normal for inner surface
      hit.material_id = MATERIAL_GLASS;
    }
  }
  
  // Ground plane
  let t_ground = intersect_ground(ray);
  if (t_ground > 0.0 && t_ground < hit.t) {
    hit.hit = true;
    hit.t = t_ground;
    hit.point = ray.origin + t_ground * ray.direction;
    hit.normal = vec3<f32>(0.0, 1.0, 0.0);
    hit.material_id = MATERIAL_GROUND;
  }
  
  return hit;
}

// Fresnel reflectance (Schlick's approximation)
fn fresnel(cos_theta: f32, n1: f32, n2: f32) -> f32 {
  let r0 = pow((n1 - n2) / (n1 + n2), 2.0);
  return r0 + (1.0 - r0) * pow(1.0 - cos_theta, 5.0);
}

// Refract ray
fn refract_ray(incident: vec3<f32>, normal: vec3<f32>, eta: f32) -> vec3<f32> {
  let cos_i = -dot(normal, incident);
  let sin_t2 = eta * eta * (1.0 - cos_i * cos_i);
  
  if (sin_t2 >= 1.0) {
    // Total internal reflection
    return reflect(incident, normal);
  }
  
  let cos_t = sqrt(1.0 - sin_t2);
  return eta * incident + (eta * cos_i - cos_t) * normal;
}

// Environment color (gradient background)
fn get_environment_color(dir: vec3<f32>) -> vec3<f32> {
  let t = (dir.y + 1.0) * 0.5;
  return mix(vec3<f32>(0.875, 0.875, 0.875), vec3<f32>(1.0, 1.0, 1.0), t);
}

// Red sphere material with emission
fn shade_red_sphere(hit_point: vec3<f32>, normal: vec3<f32>, view_dir: vec3<f32>) -> vec3<f32> {
  let base_color = vec3<f32>(0.8, 0.0, 0.0);
  let emission = vec3<f32>(1.0, 0.2, 0.2) * 2.0;
  
  // Simple diffuse lighting
  let diffuse = max(0.0, dot(normal, -LIGHT_DIR));
  let lighting = base_color * (LIGHT_COLOR * diffuse + AMBIENT);
  
  // Add subsurface scattering effect
  let subsurface = pow(max(0.0, dot(-normal, view_dir)), 2.0) * 0.3;
  let subsurface_color = vec3<f32>(1.0, 0.3, 0.3) * subsurface;
  
  return lighting + emission + subsurface_color;
}

// Ground material with reflections
fn shade_ground(hit_point: vec3<f32>, normal: vec3<f32>, view_dir: vec3<f32>) -> vec3<f32> {
  let base_color = vec3<f32>(0.7, 0.7, 0.7);
  let diffuse = max(0.0, dot(normal, -LIGHT_DIR));
  
  // Simple checkerboard pattern
  let pattern = step(0.5, fract((hit_point.x + hit_point.z) * 2.0));
  let color = mix(base_color * 0.8, base_color, pattern);
  
  return color * (LIGHT_COLOR * diffuse + AMBIENT);
}

// Main ray tracing function
fn trace_ray(initial_ray: Ray, max_depth: u32) -> vec3<f32> {
  var ray = initial_ray;
  var color = vec3<f32>(0.0);
  var attenuation = vec3<f32>(1.0);
  
  for (var depth = 0u; depth < max_depth; depth++) {
    let hit = intersect_scene(ray);
    
    if (!hit.hit) {
      color += attenuation * get_environment_color(ray.direction);
      break;
    }
    
    let view_dir = -ray.direction;
    
    if (hit.material_id == MATERIAL_RED_SPHERE) {
      let emitted = shade_red_sphere(hit.point, hit.normal, view_dir);
      color += attenuation * emitted;
      break; // Red sphere doesn't reflect much
    }
    
    if (hit.material_id == MATERIAL_GROUND) {
      let surface_color = shade_ground(hit.point, hit.normal, view_dir);
      color += attenuation * surface_color * 0.9; // Ground absorption
      
      // Reflect for next bounce
      ray.origin = hit.point + hit.normal * 0.001;
      ray.direction = reflect(ray.direction, hit.normal);
      attenuation *= 0.1; // Ground reflectivity
      continue;
    }
    
    if (hit.material_id == MATERIAL_GLASS) {
      let cos_theta = abs(dot(hit.normal, view_dir));
      let is_entering = dot(hit.normal, view_dir) > 0.0;
      
      let n1 = select(GLASS_IOR, 1.0, is_entering);
      let n2 = select(1.0, GLASS_IOR, is_entering);
      let eta = n1 / n2;
      
      let fresnel_factor = fresnel(cos_theta, n1, n2);
      
      // For simplicity, we'll do refraction most of the time
      // and add some reflection contribution
      if (depth < max_depth - 1u) {
        // Refraction ray
        let normal = select(-hit.normal, hit.normal, is_entering);
        let refracted = refract_ray(ray.direction, normal, eta);
        
        ray.origin = hit.point - normal * 0.001;
        ray.direction = refracted;
        attenuation *= GLASS_TINT * GLASS_TRANSMISSION;
        
        // Add slight reflection contribution for first few bounces
        if (depth < 2u && fresnel_factor > 0.1) {
          let reflect_ray = Ray(
            hit.point + hit.normal * 0.001,
            reflect(ray.direction, hit.normal)
          );
          let reflect_color = trace_ray(reflect_ray, max_depth - depth - 1u);
          color += attenuation * reflect_color * fresnel_factor * 0.3;
        }
      } else {
        break;
      }
    }
  }
  
  return color;
}

// Create camera ray
fn get_camera_ray(uv: vec2<f32>) -> Ray {
  let forward = normalize(CAMERA_TARGET - CAMERA_POS);
  let right = normalize(cross(forward, vec3<f32>(0.0, 1.0, 0.0)));
  let up = cross(right, forward);
  
  let fov = 45.0 * 3.14159265 / 180.0;
  let aspect = 1.0;
  let scale = tan(fov * 0.5);
  
  let ray_dir = normalize(
    forward + 
    (uv.x * 2.0 - 1.0) * right * scale * aspect +
    (uv.y * 2.0 - 1.0) * up * scale
  );
  
  return Ray(CAMERA_POS, ray_dir);
}

// Tone mapping
fn tone_map(color: vec3<f32>) -> vec3<f32> {
  // Simple ACES-like tone mapping
  let a = 2.51;
  let b = 0.03;
  let c = 2.43;
  let d = 0.59;
  let e = 0.14;
  return clamp((color * (a * color + b)) / (color * (c * color + d) + e), vec3<f32>(0.0), vec3<f32>(1.0));
}

// Fragment shader - Ray tracing
@fragment
fn main_fs(@builtin(position) pos : vec4<f32>) -> @location(0) vec4<f32> {
  // Convert screen coordinates to UV
  let resolution = vec2<f32>(1600.0, 1600.0); // Target resolution
  let uv = pos.xy / resolution;
  
  // Multi-sampling for anti-aliasing
  var color = vec3<f32>(0.0);
  let samples = 2u;
  let inv_samples = 1.0 / f32(samples * samples);
  
  for (var x = 0u; x < samples; x++) {
    for (var y = 0u; y < samples; y++) {
      let offset = (vec2<f32>(f32(x), f32(y)) + 0.5) / f32(samples) - 0.5;
      let sample_uv = uv + offset / resolution;
      
      let ray = get_camera_ray(sample_uv);
      let sample_color = trace_ray(ray, 8u);
      color += sample_color * inv_samples;
    }
  }
  
  // Tone mapping and gamma correction
  color = tone_map(color);
  color = pow(color, vec3<f32>(1.0 / 2.2)); // Gamma correction
  
  return vec4<f32>(color, 1.0);
}