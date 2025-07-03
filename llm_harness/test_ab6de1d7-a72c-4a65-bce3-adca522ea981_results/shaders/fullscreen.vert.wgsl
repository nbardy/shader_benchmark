// A single triangle covering the viewport.
struct VertexOut {
  @builtin(position) pos : vec4<f32>,
};

@vertex
fn main_vs(@builtin(vertex_index) vid : u32) -> VertexOut {
  let xy = array<vec2<f32>, 3>(
      vec2<f32>(-1.0, -3.0),
      vec2<f32>( 3.0,  1.0),
      vec2<f32>(-1.0,  1.0),
  )[vid];
  var o : VertexOut;
  o.pos = vec4<f32>(xy, 0.0, 1.0);
  return o;
}