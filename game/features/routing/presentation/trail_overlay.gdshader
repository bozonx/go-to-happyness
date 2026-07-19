shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never;

uniform sampler2D trail_map : filter_linear;
uniform vec4 trail_color : source_color = vec4(0.72, 0.60, 0.39, 1.0);

void fragment() {
	float strength = texture(trail_map, UV).r;
	float alpha = smoothstep(0.05, 0.42, strength) * 0.68;
	ALBEDO = trail_color.rgb;
	ROUGHNESS = 1.0;
	ALPHA = alpha;
}
