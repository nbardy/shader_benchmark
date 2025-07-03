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

// Fragment shader - Hopf fibration visualisation
@fragment
fn main_fs(@builtin(position) pos : vec4<f32>) -> @location(0) vec4<f32> {
  // TODO: Implement the Hopf fibration visualisation here
  return vec4<f32>(1.0, 0.0, 0.0, 1.0); // Placeholder red color
}