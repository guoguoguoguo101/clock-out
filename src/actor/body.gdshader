shader_type canvas_item;

uniform vec4 body_color : source_color = vec4(0.145, 0.149, 0.173, 1.0);

void fragment() {
	vec4 c = texture(TEXTURE, UV);
	float lum = dot(c.rgb, vec3(0.22, 0.55, 0.23));
	float maxc = max(c.r, max(c.g, c.b));
	float minc = min(c.r, min(c.g, c.b));
	float sat = maxc > 0.001 ? (maxc - minc) / maxc : 0.0;
	bool body = c.a > 0.08 && lum < 0.42 && sat < 0.28;
	vec3 tinted = body_color.rgb * mix(0.55, 1.12, clamp(lum / 0.34, 0.0, 1.0));
	COLOR = vec4(mix(c.rgb, tinted, body ? 1.0 : 0.0), c.a);
}
