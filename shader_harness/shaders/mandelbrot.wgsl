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

// Fragment shader - Mandelbrot set
@fragment
fn main_fs(@builtin(position) pos : vec4<f32>) -> @location(0) vec4<f32> {
  let c = vec2<f32>(
      (pos.x - 512.0) / 512.0 * 3.0 - 2.0,
      (pos.y - 512.0) / 512.0 * 3.0 - 1.5
  );
  var z = vec2<f32>(0.0);
  var i = 0u;
  loop {
    if (i >= 100u || dot(z, z) > 4.0) { break; }
    z = vec2<f32>(
      z.x * z.x - z.y * z.y + c.x,
      2.0 * z.x * z.y + c.y
    );
    i = i + 1u;
  }
  let t = f32(i) / 100.0;
  return vec4<f32>(vec3<f32>(t), 1.0);
}