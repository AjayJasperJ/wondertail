shader_type spatial;
render_mode unshaded, cull_disabled, blend_add, depth_draw_never;
uniform vec4 tint : source_color = vec4(0.3, 0.9, 1.0, 1.0);
void fragment() {
    float core = pow(max(0.0, 1.0 - abs(UV.x - 0.5) * 2.0), 3.0);
    float height_fade = smoothstep(0.0, 0.7, UV.y);
    float pulse = 0.75 + 0.25 * sin(TIME * 2.2 + UV.y * 8.0);
    ALBEDO = tint.rgb;
    ALPHA = core * height_fade * pulse * 0.38;
}
