shader_type canvas_item;

uniform vec4 scarf_color : source_color = vec4(0.243, 0.878, 0.949, 1.0);

void fragment() {
	vec4 c = texture(TEXTURE, UV);
	float maxc = max(c.r, max(c.g, c.b));
	float minc = min(c.r, min(c.g, c.b));
	float sat = maxc > 0.001 ? (maxc - minc) / maxc : 0.0;
	bool scarf = c.a > 0.08
		&& sat > 0.28
		&& c.b > 0.32
		&& c.g > 0.32
		&& c.r < 0.62
		&& c.b > c.r + 0.06
		&& c.g > c.r + 0.04;
	float lum = dot(c.rgb, vec3(0.22, 0.55, 0.23));
	vec3 tinted = scarf_color.rgb * mix(0.55, 1.15, clamp(lum * 1.2, 0.0, 1.0));
	COLOR = vec4(mix(c.rgb, tinted, scarf ? 1.0 : 0.0), c.a);
}
