shader_type canvas_item;

void fragment() {
	vec2 uv = UV;
	float vig = smoothstep(0.28, 0.98, distance(uv, vec2(0.46, 0.42)));
	float scan = 0.07 * sin(uv.y * 920.0 + TIME * 8.0);
	float band = 0.10 * step(0.92, fract(uv.y * 1.7 + TIME * 0.13));
	float drip = smoothstep(0.78, 1.0, uv.y) * (0.16 + 0.08 * sin(uv.x * 40.0 + TIME));
	float corner = pow(max(uv.x, 1.0 - uv.x) * max(uv.y, 1.0 - uv.y), 0.35) * 0.2;
	COLOR = vec4(0.16, 0.02, 0.02, vig * 0.62 + scan + band + drip + corner);
}
