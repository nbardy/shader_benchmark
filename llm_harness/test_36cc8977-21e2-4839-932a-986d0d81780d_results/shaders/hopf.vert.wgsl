// Vertex shader for the Hopf fibration visualization

struct VertexOut {
  @builtin(position) position: vec4<f32>,
  @location(0) color: vec3<f32>,
};

@vertex
fn main_vs(@builtin(vertex_index) vid: u32) -> VertexOut {
  // Determine the base loop index from the vertex ID
  let loop_index = vid / 2000u;
  let loop_theta: f32 = select(
    select(
      PI / 3.0,  // Loop A
      PI / 2.0,  // Loop B
      2.0 * PI / 3.0  // Loop C
    ),
    loop_index
  );

  // Compute the base loop coordinates
  let loop_phi = (f32(vid % 2000u) / 1000.0) * 2.0 * PI;
  let x = sin(loop_theta) * cos(loop_phi);
  let y = sin(loop_theta) * sin(loop_phi);
  let z = cos(loop_theta);

  // Compute the fibre coordinates
  let fibre_theta = (loop_phi / (2.0 * PI)) * 2.0 * PI;
  let fibre_phi = (f32(vid % 2u) - 0.5) * PI;
  let fibre_x = sin(fibre_theta) * cos(fibre_phi);
  let fibre_y = sin(fibre_theta) * sin(fibre_phi);
  let fibre_z = cos(fibre_theta);

  // Combine the base loop and fibre coordinates
  let pos_x = x * sqrt(1.0 - fibre_z * fibre_z / 2.0) + fibre_x * fibre_z;
  let pos_y = y * sqrt(1.0 - fibre_z * fibre_z / 2.0) + fibre_y * fibre_z;
  let pos_z = z + fibre_z * sqrt(2.0) / 2.0;

  // Output vertex data
  var output: VertexOut;
  output.position = vec4<f32>(pos_x, pos_y, pos_z, 1.0);
  output.color = vec3<f32>(loop_phi / (2.0 * PI), 1.0, 1.0);
  return output;
}