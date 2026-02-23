@vertex
fn vs_main(@builtin(vertex_index) vertex_index: u32) -> @builtin(position) vec4<f32> {
    let vertex_id = vertex_index % 3u;
    let x = f32(i32(vertex_id & 1u) << 2u) - 1.0;
    let y = f32(i32((vertex_id >> 1u) & 1u) << 2u) - 1.0;
    return vec4<f32>(x, y, 0.0, 1.0);
}

@group(0) @binding(0) var<uniform> params: Params;

struct Params {
    time: f32,
    resolution: vec2<f32>,
};

fn bark_color(pos: vec3<f32>) -> vec3<f32> {
    return vec3<f32>(0.294, 0.216, 0.15); // #4b3726
}

fn sphere(ro: vec3<f32>, rd: vec3<f32>, center: vec3<f32>, radius: f32) -> f32 {
    let oc = ro - center;
    let a = dot(rd, rd);
    let b = 2.0 * dot(oc, rd);
    let c = dot(oc, oc) - radius * radius;
    let discriminant = b * b - 4.0 * a * c;
    if (discriminant < 0.0) {
        return -1.0;
    }
    return (-b - sqrt(discriminant)) / (2.0 * a);
}

fn cylinder(ro: vec3<f32>, rd: vec3<f32>, height: f32, radius: f32) -> f32 {
    let ca = vec3<f32>(0.0, 0.0, 0.0);
    let cb = vec3<f32>(0.0, height, 0.0);

    let oc = ro - ca;
    let a = rd.x * rd.x + rd.z * rd.z;
    let b = 2.0 * (oc.x * rd.x + oc.z * rd.z);
    let c = oc.x * oc.x + oc.z * oc.z - radius * radius;
    let discriminant = b * b - 4.0 * a * c;

    if (discriminant < 0.0) {
        return -1.0;
    }

    let t = (-b - sqrt(discriminant)) / (2.0 * a);
    let y = ro.y + t * rd.y;
    if (y > 0.0 && y < height) {
        return t;
    }
    return -1.0;
}

fn scene(ro: vec3<f32>, rd: vec3<f32>) -> vec4<f32> {
    var depth = 1e9f32;
    var normal = vec3<f32>(0.0);
    var color = vec3<f32>(0.0);

    let trunk_height = 1.0;
    let trunk_radius = 0.08;
    let trunk_t = cylinder(ro, rd, trunk_height, trunk_radius);
    if (trunk_t > 0.0 && trunk_t < depth) {
        depth = trunk_t;
        normal = normalize(vec3<f32>(ro.x + trunk_t * rd.x, 0.0, ro.z + trunk_t * rd.z));
        color = bark_color(ro + trunk_t * rd);
    }

    let pi = 3.14159265359;
    let split_angle = pi / 4.0; // 45 degrees
    let rotation_angle = pi * 35.0 / 180.0; // 35 degrees

    let length_scale = 0.7;
    let radius_scale = 0.6;

    fn branch(ro_in: vec3<f32>, rd_in: vec3<f32>, height: f32, radius: f32, level: i32, parent_transform: mat3x3<f32>, offset:vec3<f32>) -> vec4<f32> {
        var current_depth = 1e9f32;
        var current_normal = vec3<f32>(0.0);
        var current_color = vec3<f32>(0.0);
        
        let local_ro = parent_transform * ro_in + offset;
        let local_rd = parent_transform * rd_in;

        let t = cylinder(local_ro, local_rd, height, radius);
        if (t > 0.0 && t < current_depth) {
            current_depth = t;
            current_normal = normalize(vec3<f32>(local_ro.x + t * local_rd.x, 0.0, local_ro.z + t * local_rd.z));
            current_color = bark_color(local_ro + t * local_rd);

            if (level > 0) {
                 let child_height = height * length_scale;
                let child_radius = radius * radius_scale;
                let branch_offset = vec3<f32>(0.0,height,0.0); // Move branch to top of the current cylinder
                let rotation_matrix1 = mat3x3<f32>(
                    vec3<f32>(1.0, 0.0, 0.0),
                    vec3<f32>(0.0, cos(split_angle), -sin(split_angle)),
                    vec3<f32>(0.0, sin(split_angle), cos(split_angle))
                );
                let rotation_matrix2 = mat3x3<f32>(
                    vec3<f32>(cos(rotation_angle), 0.0, sin(rotation_angle)),
                    vec3<f32>(0.0, 1.0, 0.0),
                    vec3<f32>(-sin(rotation_angle), 0.0, cos(rotation_angle))
                );                
               let child_transform1 = rotation_matrix2 * rotation_matrix1;

                let result1 = branch(ro_in, rd_in, child_height, child_radius, level - 1, parent_transform * child_transform1, offset + branch_offset * parent_transform[1]);

                let rotation_matrix3 = mat3x3<f32>(
                    vec3<f32>(1.0, 0.0, 0.0),
                    vec3<f32>(0.0, cos(-split_angle), -sin(-split_angle)),
                    vec3<f32>(0.0, sin(-split_angle), cos(-split_angle))
                );

                let rotation_matrix4 = mat3x3<f32>(
                    vec3<f32>(cos(-rotation_angle), 0.0, sin(-rotation_angle)),
                    vec3<f32>(0.0, 1.0, 0.0),
                    vec3<f32>(-sin(-rotation_angle), 0.0, cos(-rotation_angle))
                                      );

               let child_transform2 = rotation_matrix4 * rotation_matrix3;

                let result2 = branch(ro_in, rd_in, child_height, child_radius, level - 1, parent_transform * child_transform2, offset + branch_offset * parent_transform[1]);
                if(result1.w < current_depth){
                    current_depth = result1.w;
                    current_normal = result1.xyz;
                }
                if(result2.w < current_depth){
                    current_depth = result2.w;
                    current_normal = result2.xyz;
                }
               
            }
        }
        
        return vec4<f32>(current_normal, current_depth);
    }

    let initial_transform = mat3x3<f32>(
      vec3<f32>(1.0, 0.0, 0.0),
      vec3<f32>(0.0, 1.0, 0.0),
      vec3<f32>(0.0, 0.0, 1.0)
    );
   
    let result = branch(ro, rd, trunk_height, trunk_radius, 7, initial_transform, vec3<f32>(0.0,0.0,0.0));

   if(result.w < depth) {
        depth = result.w;
        normal = result.xyz;
        color = bark_color(ro + depth * rd);
   }

    if (depth == 1e9f32) {
        // Background
        let t = (rd.y + 1.0) * 0.5;
        let zenith_color = vec3<f32>(0.843, 0.925, 1.0); // #d7ecff
        let horizon_color = vec3<f32>(1.0, 1.0, 1.0);   // #ffffff
        return vec4<f32>(mix(horizon_color, zenith_color, t), 1.0);
    }

    // Lighting
    let light_key_dir = normalize(vec3<f32>(3.0, -5.0, 5.0) - (ro + depth * rd));
    let light_fill_dir = normalize(vec3<f32>(-2.0, -6.0, 4.0) - (ro + depth * rd));
    let light_rim_dir = normalize(vec3<f32>(0.0, 0.0, 6.0) - (ro + depth * rd));

    let key_intensity = max(0.0, dot(normal, light_key_dir));
    let fill_intensity = max(0.0, dot(normal, light_fill_dir)) * 0.4;
    let rim_intensity = max(0.0, dot(normal, light_rim_dir)) * 0.3;

    let ambient = 0.1;
    let total_intensity = ambient + key_intensity + fill_intensity + rim_intensity;

    return vec4<f32>(color * total_intensity, 1.0);
}

@fragment
fn fs_main(@builtin(position) pos: vec4<f32>) -> @location(0) vec4<f32> {
    let uv = (pos.xy / params.resolution - 0.5) * 2.0;

    let camera_pos = vec3<f32>(3.0, -6.0, 2.5);
    let target = vec3<f32>(0.0, 0.0, 0.0);
    let up = vec3<f32>(0.0, 0.0, 1.0);

    let fov = 40.0 * 3.14159265359 / 180.0;
    let aspect = params.resolution.x / params.resolution.y;
    let near = 0.1;

    let f = 1.0 / tan(fov / 2.0);
    let cam_z = normalize(camera_pos - target);
    let cam_x = normalize(cross(up, cam_z));
    let cam_y = cross(cam_z, cam_x);

    let rd = normalize(cam_x * uv.x * aspect + cam_y * uv.y - cam_z * f);

    return scene(camera_pos, rd);
}