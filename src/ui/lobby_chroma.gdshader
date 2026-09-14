shader_type canvas_item;

void fragment() {
	vec4 c = texture(TEXTURE, UV);
	bool keyed = c.g > 0.42 && c.g > c.r + 0.16 && c.g > c.b + 0.10;
	if (keyed) {
		c.a = 0.0;
	}
	COLOR = c;
}
