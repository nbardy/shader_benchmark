// Hopf Fibration Visualization - Vertex and Fragment Shaders

struct VertexOut {
    @builtin(position) pos : vec4<f32>,
    @location(0) uv : vec2<f32>,
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
    o.uv = xy * 0.5 + 0.5;
    return o;
}

// Constants
const PI = 3.14159265359;
const TUBE_RADIUS = 0.02;
const NUM_FIBRE_POINTS = 512u;
const NUM_BASE_POINTS = 128u;

// HSV to RGB conversion
fn hsv_to_rgb(h: f32, s: f32, v: f32) -> vec3<f32> {
    let c = v * s;
    let x = c * (1.0 - abs((h * 6.0) % 2.0 - 1.0));
    let m = v - c;
    
    var rgb: vec3<f32>;
    let h_sector = floor(h * 6.0);
    
    if (h_sector < 1.0) {
        rgb = vec3<f32>(c, x, 0.0);
    } else if (h_sector < 2.0) {
        rgb = vec3<f32>(x, c, 0.0);
    } else if (h_sector < 3.0) {
        rgb = vec3<f32>(0.0, c, x);
    } else if (h_sector < 4.0) {
        rgb = vec3<f32>(0.0, x, c);
    } else if (h_sector < 5.0) {
        rgb = vec3<f32>(x, 0.0, c);
    } else {
        rgb = vec3<f32>(c, 0.0, x);
    }
    
    return rgb + m;
}

// Stereographic projection from S3 to R3
fn stereographic_projection(p: vec4<f32>) -> vec3<f32> {
    let denom = 1.0 - p.w;
    if (abs(denom) < 1e-6) {
        return vec3<f32>(0.0, 0.0, 1000.0); // Point at infinity
    }
    return vec3<f32>(p.x, p.y, p.z) / denom;
}

// Convert spherical coordinates to Cartesian for S2
fn spherical_to_cartesian(theta: f32, phi: f32) -> vec3<f32> {
    return vec3<f32>(
        sin(theta) * cos(phi),
        sin(theta) * sin(phi),
        cos(theta)
    );
}

// Convert S2 point to complex + real representation
fn s2_to_complex_real(p: vec3<f32>) -> vec3<f32> {
    // For S2 = {(z,x) | |z|^2 + x^2 = 1}, we have z = p.x + i*p.y, x = p.z
    return vec3<f32>(p.x, p.y, p.z);
}

// Compute preimage point on S3 for given base point and fiber parameter
fn hopf_preimage(base_complex_real: vec3<f32>, t: f32) -> vec4<f32> {
    let z_re = base_complex_real.x;
    let z_im = base_complex_real.y;
    let x = base_complex_real.z;
    
    // Solve for z0, z1 such that Hopf map gives the base point
    // |z0|^2 + |z1|^2 = 1
    // 2*z0*conj(z1) = z_re + i*z_im
    // |z0|^2 - |z1|^2 = x
    
    let z_mag_sq = z_re * z_re + z_im * z_im;
    
    // From the constraints:
    let z0_mag_sq = (1.0 + x) * 0.5;
    let z1_mag_sq = (1.0 - x) * 0.5;
    
    if (z0_mag_sq < 0.0 || z1_mag_sq < 0.0) {
        return vec4<f32>(0.0, 0.0, 0.0, 0.0);
    }
    
    let z0_mag = sqrt(z0_mag_sq);
    let z1_mag = sqrt(z1_mag_sq);
    
    // Parameterize the fiber with angle t
    let z0 = vec2<f32>(z0_mag * cos(t), z0_mag * sin(t));
    
    var z1: vec2<f32>;
    if (z0_mag < 1e-6) {
        z1 = vec2<f32>(z1_mag, 0.0);
    } else {
        // From 2*z0*conj(z1) = z_re + i*z_im
        let temp = vec2<f32>(z_re, z_im) / (2.0 * z0_mag * z1_mag);
        z1 = vec2<f32>(
            temp.x * z0.x + temp.y * z0.y,
            temp.x * z0.y - temp.y * z0.x
        ) * z1_mag;
    }
    
    return vec4<f32>(z0.x, z0.y, z1.x, z1.y);
}

// Distance from ray to tube around fiber
fn distance_to_fiber_tube(ray_origin: vec3<f32>, ray_dir: vec3<f32>, 
                         base_point: vec3<f32>, fiber_color: vec3<f32>) -> f32 {
    var min_dist = 1000.0;
    
    // Sample points along the fiber
    for (var i = 0u; i < NUM_FIBRE_POINTS; i++) {
        let t = f32(i) * 2.0 * PI / f32(NUM_FIBRE_POINTS);
        let s3_point = hopf_preimage(base_point, t);
        let r3_point = stereographic_projection(s3_point);
        
        // Distance from ray to point
        let to_point = r3_point - ray_origin;
        let proj_length = dot(to_point, ray_dir);
        
        if (proj_length > 0.0) {
            let closest_on_ray = ray_origin + proj_length * ray_dir;
            let dist_to_fiber = length(closest_on_ray - r3_point);
            min_dist = min(min_dist, dist_to_fiber);
        }
    }
    
    return min_dist;
}

// Main raymarching function
fn raymarch_hopf_fibers(ray_origin: vec3<f32>, ray_dir: vec3<f32>) -> vec4<f32> {
    var closest_dist = 1000.0;
    var final_color = vec3<f32>(0.0);
    var hit = false;
    
    // Define the three base loops
    let loops = array<f32, 3>(PI/3.0, PI/2.0, 2.0*PI/3.0); // theta values for the loops
    
    for (var loop_idx = 0u; loop_idx < 3u; loop_idx++) {
        let theta = loops[loop_idx];
        
        // Sample points along the base loop
        for (var j = 0u; j < NUM_BASE_POINTS; j++) {
            let phi = f32(j) * 2.0 * PI / f32(NUM_BASE_POINTS);
            let base_s2 = spherical_to_cartesian(theta, phi);
            let base_complex_real = s2_to_complex_real(base_s2);
            
            // Color based on phi (hue wheel)
            let hue = phi / (2.0 * PI);
            let fiber_color = hsv_to_rgb(hue, 0.8, 0.9);
            
            let dist_to_tube = distance_to_fiber_tube(ray_origin, ray_dir, base_complex_real, fiber_color);
            
            if (dist_to_tube < TUBE_RADIUS && dist_to_tube < closest_dist) {
                closest_dist = dist_to_tube;
                final_color = fiber_color;
                hit = true;
            }
        }
    }
    
    if (hit) {
        // Simple shading based on distance
        let intensity = 1.0 - (closest_dist / TUBE_RADIUS);
        return vec4<f32>(final_color * intensity, 1.0);
    }
    
    return vec4<f32>(0.0, 0.0, 0.0, 0.0);
}

// Render small reference sphere
fn render_reference_sphere(ray_origin: vec3<f32>, ray_dir: vec3<f32>, sphere_center: vec3<f32>) -> vec4<f32> {
    let sphere_radius = 0.3;
    let to_sphere = ray_origin - sphere_center;
    let a = dot(ray_dir, ray_dir);
    let b = 2.0 * dot(to_sphere, ray_dir);
    let c = dot(to_sphere, to_sphere) - sphere_radius * sphere_radius;
    let discriminant = b * b - 4.0 * a * c;
    
    if (discriminant < 0.0) {
        return vec4<f32>(0.0);
    }
    
    let t1 = (-b - sqrt(discriminant)) / (2.0 * a);
    let t2 = (-b + sqrt(discriminant)) / (2.0 * a);
    
    if (t1 > 0.0) {
        let hit_point = ray_origin + t1 * ray_dir;
        let normal = normalize(hit_point - sphere_center);
        
        // Convert to spherical coordinates for coloring
        let theta = acos(normal.z);
        let phi = atan2(normal.y, normal.x);
        
        // Check if point is on one of the reference loops
        let loops = array<f32, 3>(PI/3.0, PI/2.0, 2.0*PI/3.0);
        for (var i = 0u; i < 3u; i++) {
            if (abs(theta - loops[i]) < 0.05) {
                let hue = (phi + PI) / (2.0 * PI);
                let color = hsv_to_rgb(hue, 0.8, 0.9);
                return vec4<f32>(color, 0.8);
            }
        }
        
        // Gray sphere surface
        return vec4<f32>(0.5, 0.5, 0.5, 0.3);
    }
    
    return vec4<f32>(0.0);
}

@fragment
fn main_fs(@builtin(position) pos : vec4<f32>) -> @location(0) vec4<f32> {
    let resolution = 1600.0;
    let uv = (pos.xy - 0.5 * resolution) / resolution;
    
    // Camera setup
    let camera_pos = vec3<f32>(3.0, 2.0, 4.0);
    let camera_target = vec3<f32>(0.0, 0.0, 0.0);
    let camera_up = vec3<f32>(0.0, 0.0, 1.0);
    
    let w = normalize(camera_target - camera_pos);
    let u = normalize(cross(w, camera_up));
    let v = cross(u, w);
    
    let ray_dir = normalize(uv.x * u + uv.y * v + 2.0 * w);
    let ray_origin = camera_pos;
    
    // Background
    var final_color = vec4<f32>(1.0, 1.0, 1.0, 1.0);
    
    // Render reference sphere
    let sphere_center = vec3<f32>(2.0, -1.5, -1.0);
    let sphere_color = render_reference_sphere(ray_origin, ray_dir, sphere_center);
    if (sphere_color.a > 0.0) {
        final_color = mix(final_color, sphere_color, sphere_color.a);
    }
    
    // Render Hopf fibers
    let fiber_color = raymarch_hopf_fibers(ray_origin, ray_dir);
    if (fiber_color.a > 0.0) {
        final_color = mix(final_color, fiber_color, fiber_color.a);
    }
    
    return final_color;
}