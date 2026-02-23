@group(0) @binding(0) var<uniform> params: Params;

struct Params {
    time: f32,
    resolution: vec2<f32>,
};

// Helper function to calculate Archimedes spiral coordinates
fn archimedes_spiral(theta: f32) -> vec2<f32> {
  let r = theta / 3.14159265359;
  return vec2<f32>(r * cos(theta), r * sin(theta));
}

// Helper function for distance calculation
fn distance(a: vec2<f32>, b: vec2<f32>) -> f32 {
    return length(a - b);
}

@vertex
fn vs_main(@builtin(vertex_index) vertex_index: u32) -> @builtin(position) vec4<f32> {
    let vertex_id = vertex_index % 3u;
    let x = f32(i32(vertex_id & 1u) << 2u) - 1.0;
    let y = f32(i32((vertex_id >> 1u) & 1u) << 2u) - 1.0;
    return vec4<f32>(x, y, 0.0, 1.0);
}

@fragment
fn fs_main(@builtin(position) pos: vec4<f32>) -> @location(0) vec4<f32> {
    let uv = pos.xy / params.resolution;
    let center = vec2<f32>(0.5, 0.5);
    let dist_to_center = distance(uv, center);

    // Background color (aged papyrus)
    let background_color = vec3<f32>(0.96078, 0.90196, 0.82745);

    // Spiral color (deep blue ink)
    let spiral_color = vec3<f32>(0.11765, 0.19608, 0.38824);
    
    var final_color = background_color;
    
    // Draw spiral
    let num_turns: f32 = 4.0;
    let max_theta: f32 = num_turns * 6.28318530718; // 2 * PI * num_turns

    let spiral_width: f32 = 0.004;

    for (var i: f32 = 0.0; i < max_theta; i = i + 0.01) {
      let spiral_point = archimedes_spiral(i);
      let screen_spiral_point = spiral_point * 0.15 + center;
        
      let dist_to_spiral = distance(uv, screen_spiral_point);
      if (dist_to_spiral < spiral_width) {
          final_color = spiral_color;
      }
    }
    
    // Angle Trisection
    let angle_aob_degrees: f32 = 60.0;
    let angle_aob_radians: f32 = angle_aob_degrees * 3.14159265359 / 180.0;
    
    let radius_oc: f32 = 0.2;  // Radius of the arc OC
    
    let point_c = vec2<f32>(center.x + radius_oc * cos(0.0), 
                             center.y + radius_oc * sin(0.0)); //C is on the right
    
    let radius_op: f32 = radius_oc / 3.0;  //OP = 1/3 OC
    
    var found_point_p: bool = false;
    var point_p: vec2<f32> = vec2<f32>(0.0);
    
    for(var j: f32 = 0.0; j < max_theta; j = j + 0.01){
        let temp_spiral_point = archimedes_spiral(j);
        let screen_spiral_point = temp_spiral_point * 0.15 + center;
        
        if(abs(distance(center, screen_spiral_point) - radius_op) < 0.002){
            point_p = screen_spiral_point;
            found_point_p = true;
            break; //Found P
        }
    }
    
    if(found_point_p){
        let gold_color = vec3<f32>(0.831, 0.686, 0.216);
        
        // Draw line from center to P
        let dist_to_line_center_p = distance_to_line(uv, center, point_p);
        if(dist_to_line_center_p < 0.002){
            final_color = gold_color;
        }
        
        //Draw OC circle
        let dist_to_circle_oc: f32 = abs(distance(uv, center) - radius_oc);
        if(dist_to_circle_oc < 0.002){
            final_color = gold_color;
        }
        
        //Draw line OB
        let point_b_x = center.x + radius_oc;
        let point_b= vec2<f32>(point_b_x,center.y);

        let dist_to_line_center_b = distance_to_line(uv, center, point_b);
                if(dist_to_line_center_b < 0.002){
            final_color = gold_color;
        }        
    }

    var animated_theta: f32 = params.time * 0.5;// Slow down
    animated_theta = animated_theta % max_theta;

    let animated_spiral_point = archimedes_spiral(animated_theta);
    let animated_screen_spiral_point = animated_spiral_point * 0.15 + center;
    let animation_point_size: f32 = 0.008;
    if (distance(uv, animated_screen_spiral_point) < animation_point_size){
        final_color = vec3<f32>(1.0, 0.0, 0.0); // Show animation point
    }
    
    return vec4<f32>(final_color, 1.0);
}

fn distance_to_line(p: vec2<f32>, a: vec2<f32>, b: vec2<f32>) -> f32 {
    let pa = p - a;
    let ba = b - a;
    let h = clamp(dot(pa, ba) / dot(ba, ba), 0.0, 1.0);
    return length(pa - ba * h);
}