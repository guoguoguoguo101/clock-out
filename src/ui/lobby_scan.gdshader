shader_type canvas_item;

void fragment() {
	float y = FRAGCOORD.y;
	float band = 0.07 * step(0.62, fract(y * 0.28 + TIME * 1.6));
	float sweep = 0.10 * smoothstep(0.0, 0.04, abs(fract(y * 0.0018 + TIME * 0.07) - 0.5));
	float grain = fract(sin(dot(FRAGCOORD.xy + TIME * 50.0, vec2(12.9898, 78.233))) * 43758.5453);
	COLOR = vec4(0.78, 0.18, 0.12, band + sweep + grain * 0.045);
}
