shader_type spatial;
render_mode diffuse_burley;
varying vec3 world_pos;
float hash(vec2 p) {
    vec2 q = fract(p * vec2(0.1031, 0.1030));
    q += dot(q, q.yx + 33.33);
    return fract((q.x + q.y) * q.x);
}
float smooth_noise(vec2 p) {
    vec2 cell = floor(p);
    vec2 f = fract(p);
    f = f * f * (3.0 - 2.0 * f);
    return mix(mix(hash(cell), hash(cell + vec2(1.0, 0.0)), f.x),
               mix(hash(cell + vec2(0.0, 1.0)), hash(cell + vec2(1.0)), f.x), f.y);
}
void vertex() { world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz; }
void fragment() {
    float mottling = smooth_noise(world_pos.xz * 0.7);
    float grain = smooth_noise(world_pos.xz * 12.0);
    ALBEDO = COLOR.rgb * (0.93 + mottling * 0.1 + grain * 0.035);
    ROUGHNESS = 0.9;
}
