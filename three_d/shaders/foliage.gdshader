shader_type spatial;
render_mode cull_disabled;
uniform vec4 tint : source_color = vec4(0.25, 0.5, 0.35, 1.0);
void vertex() {
 float sway = sin(TIME * 1.3 + NODE_POSITION_WORLD.x * 0.3 + VERTEX.y) * 0.035;
 VERTEX.x += sway * max(0.0, VERTEX.y + 0.4);
}
void fragment() {
 ALBEDO = tint.rgb;
 ROUGHNESS = 0.9;
}
