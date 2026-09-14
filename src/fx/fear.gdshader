shader_type canvas_item;

uniform float grain = 0.22;
uniform float vignette = 0.42;
uniform float threat = 0.0;
uniform float scan = 0.12;
uniform vec4 tint : source_color = vec4(0.12, 0.02, 0.02, 1.0);

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453);
}

void fragment() {
	vec2 uv = UV;
	float n = hash(floor(uv * vec2(320.0, 180.0)) + floor(TIME * 18.0));
	float d = distance(uv, vec2(0.5, 0.48));
	float vig = smoothstep(0.28, 0.98, d);
	float lines = step(0.55, fract(uv.y * 180.0 + TIME * 1.4));
	float pulse = 0.5 + 0.5 * sin(TIME * 2.6);
	float a = vig * vignette * (0.62 + threat * 0.78);
	a += n * grain * (0.18 + threat * 0.34);
	a += lines * scan * (0.10 + threat * 0.16);
	a += threat * pulse * 0.09;
	vec3 col = mix(vec3(0.02, 0.02, 0.03), tint.rgb, threat * 0.9);
	COLOR = vec4(col, clamp(a, 0.0, 0.88));
}
