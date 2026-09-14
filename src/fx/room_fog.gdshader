shader_type canvas_item;

uniform vec4 hole = vec4(520.0, 780.0, 1200.0, 700.0);
uniform vec2 map_size = vec2(2560.0, 1520.0);
uniform float softness = 70.0;
uniform float ink_alpha = 0.96;
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
	vec3 ink = mix(vec3(0.008, 0.009, 0.014), vec3(0.09, 0.015, 0.016), threat * 0.7);
	float edge = smoothstep(-36.0, 0.0, inside);
	float outside_a = mix(ink_alpha, 0.48, edge);
	float vig = 1.0 - smoothstep(6.0, softness, max(inside, 0.0));
	float inside_a = vig * mix(0.40, 0.72, threat) + n * grain * (0.14 + threat * 0.22);
	inside_a += threat * 0.12 * (0.5 + 0.5 * sin(TIME * 2.2));
	inside_a = clamp(inside_a, 0.0, 0.94);
	float a = mix(outside_a, inside_a, step(0.0, inside));
	COLOR = vec4(ink, a);
}
