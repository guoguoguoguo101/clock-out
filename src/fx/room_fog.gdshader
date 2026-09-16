shader_type canvas_item;

uniform vec4 hole = vec4(896.0, 1152.0, 1760.0, 928.0);
uniform vec2 map_size = vec2(4096.0, 2816.0);
uniform float softness = 90.0;
uniform float ink_alpha = 0.22;
uniform float threat = 0.0;
uniform float grain = 0.18;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

void fragment() {
	vec2 p = UV * map_size;
	vec2 bmin = hole.xy;
	vec2 bmax = hole.xy + hole.zw;
	float dx = min(p.x - bmin.x, bmax.x - p.x);
	float dy = min(p.y - bmin.y, bmax.y - p.y);
	float inside = min(dx, dy);
	float n = hash(floor(p * 0.55) + floor(TIME * 14.0));
	vec3 ink = mix(vec3(0.86, 0.90, 0.91), vec3(0.92, 0.78, 0.72), threat * 0.45);
	float edge = smoothstep(-36.0, 0.0, inside);
	float outside_a = mix(ink_alpha, 0.08, edge);
	float vig = 1.0 - smoothstep(6.0, softness, max(inside, 0.0));
	float inside_a = vig * mix(0.04, 0.16, threat) + n * grain * (0.04 + threat * 0.08);
	inside_a += threat * 0.12 * (0.5 + 0.5 * sin(TIME * 2.2));
	inside_a = clamp(inside_a, 0.0, 0.94);
	float a = mix(outside_a, inside_a, step(0.0, inside));
	COLOR = vec4(ink, a);
}
