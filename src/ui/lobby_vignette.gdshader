shader_type canvas_item;

void fragment() {
	vec2 uv = UV;
	float vig = smoothstep(0.28, 0.98, distance(uv, vec2(0.46, 0.42)));
	float scan = 0.012 * sin(uv.y * 920.0 + TIME * 8.0);
	float corner = pow(max(uv.x, 1.0 - uv.x) * max(uv.y, 1.0 - uv.y), 0.35) * 0.08;
	COLOR = vec4(0.04, 0.07, 0.10, vig * 0.38 + scan + corner);
}
