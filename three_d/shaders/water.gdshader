shader_type spatial;
render_mode cull_disabled;
uniform vec4 shallow_color : source_color = vec4(0.23, 0.65, 0.67, 1.0);
uniform vec4 deep_color : source_color = vec4(0.035, 0.22, 0.32, 1.0);
uniform float water_extent = 4.5;
uniform float foam_strength = 0.8;
varying vec3 local_position;
void vertex() {
 local_position = VERTEX;
 VERTEX.y += sin(VERTEX.x * 2.8 + TIME * 1.7) * cos(VERTEX.z * 2.1 + TIME) * 0.045;
}
void fragment() {
 float radius = length(local_position.xz) / water_extent;
 float ripple = sin(local_position.x * 8.0 + TIME * 2.0) * cos(local_position.z * 6.0 - TIME * 1.4);
 float foam = smoothstep(0.88, 1.0, radius + ripple * 0.018);
 ALBEDO = mix(mix(deep_color.rgb, shallow_color.rgb, clamp(radius, 0.0, 1.0)), vec3(0.77, 0.92, 0.86), foam * foam_strength);
 ROUGHNESS = 0.22;
 METALLIC = 0.12;
 NORMAL_MAP = vec3(0.5 + ripple * 0.06, 0.5 + sin(local_position.z * 7.0 + TIME) * 0.05, 1.0);
}
