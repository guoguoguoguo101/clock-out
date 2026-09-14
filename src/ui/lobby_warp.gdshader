shader_type canvas_item;

uniform float amp = 0.014;
uniform float speed = 2.2;
uniform float chroma = 0.0;

void fragment() {
	vec2 uv = UV;
	uv.x += sin(UV.y * 26.0 + TIME * speed) * amp;
	uv.y += cos(UV.x * 18.0 + TIME * (speed * 0.7)) * amp * 0.45;
	uv = clamp(uv, vec2(0.001), vec2(0.999));
	vec4 base = texture(TEXTURE, uv);
	if (chroma > 0.001) {
		base.r = texture(TEXTURE, uv + vec2(chroma, 0.0)).r;
		base.b = texture(TEXTURE, uv - vec2(chroma, 0.0)).b;
	}
	COLOR *= base;
}
