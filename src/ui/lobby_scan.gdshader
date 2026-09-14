shader_type canvas_item;

void fragment() {
	float y = FRAGCOORD.y;
	float band = 0.018 * step(0.62, fract(y * 0.28 + TIME * 1.6));
	float sweep = 0.025 * smoothstep(0.0, 0.04, abs(fract(y * 0.0018 + TIME * 0.07) - 0.5));
	float grain = fract(sin(dot(FRAGCOORD.xy + TIME * 50.0, vec2(12.9898, 78.233))) * 43758.5453);
	COLOR = vec4(0.55, 0.66, 0.72, band + sweep + grain * 0.012);
}
