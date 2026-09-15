shader_type canvas_item;

uniform vec4 body_color : source_color = vec4(0.96, 0.76, 0.09, 1.0);

void fragment() {
	vec4 c = texture(TEXTURE, UV);
	float maxc = max(c.r, max(c.g, c.b));
	float minc = min(c.r, min(c.g, c.b));
	float sat = maxc > 0.001 ? (maxc - minc) / maxc : 0.0;
	bool paint = c.a > 0.08
		&& sat > 0.35
		&& c.r > 0.52
		&& c.g > 0.40
		&& c.b < 0.38
		&& c.r > c.b + 0.22
		&& c.g > c.b + 0.12;
	float lum = dot(c.rgb, vec3(0.22, 0.55, 0.23));
	vec3 tinted = body_color.rgb * mix(0.55, 1.18, clamp(lum * 1.15, 0.0, 1.0));
	COLOR = vec4(mix(c.rgb, tinted, paint ? 1.0 : 0.0), c.a);
}
