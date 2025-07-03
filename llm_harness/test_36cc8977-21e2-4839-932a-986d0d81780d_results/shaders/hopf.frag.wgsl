// Fragment shader for the Hopf fibration visualization

@fragment
fn main_fs(@location(0) color: vec3<f32>) -> @location(0) vec4<f32> {
  return vec4<f32>(color, 1.0);
}