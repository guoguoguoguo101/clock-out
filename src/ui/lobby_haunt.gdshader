shader_type canvas_item;

uniform float flicker = 1.0;
uniform float glitch = 0.0;
uniform float scan = 0.12;

void fragment() {
	vec2 uv = UV;
	float slice = step(0.94, fract(TIME * 11.0 + uv.y * 3.0));
	uv.x += sin(uv.y * 48.0 + TIME * 9.0) * (0.0012 + glitch * 0.012);
	uv.y += slice * glitch * 0.03;
	uv = clamp(uv, vec2(0.0), vec2(1.0));
	float ca = 0.0018 + glitch * 0.008;
	vec4 c;
	c.r = texture(TEXTURE, uv + vec2(ca, 0.0)).r;
	c.g = texture(TEXTURE, uv).g;
	c.b = texture(TEXTURE, uv - vec2(ca, 0.0)).b;
	c.a = texture(TEXTURE, uv).a;
	float line = 0.86 + scan * sin(uv.y * 640.0 + TIME * 7.0);
	c.rgb *= line * mix(0.78, 1.05, flicker);
	c.rgb = mix(c.rgb, vec3(c.g * 0.9, c.g, c.g * 0.75), 0.08 + glitch * 0.2);
	COLOR = c;
}
