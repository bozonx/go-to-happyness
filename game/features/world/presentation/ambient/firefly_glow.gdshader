shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, fog_disabled, skip_vertex_transform;

uniform float glow_strength = 3.2;

void vertex() {
	vec3 center = (MODELVIEW_MATRIX * vec4(0.0, 0.0, 0.0, 1.0)).xyz;
	VERTEX = center + vec3(VERTEX.x, VERTEX.y, 0.0);
}

void fragment() {
	vec2 centered_uv = UV * 2.0 - 1.0;
	float distance_from_center = length(centered_uv);
	float halo = smoothstep(1.0, 0.0, distance_from_center);
	float core = smoothstep(0.22, 0.0, distance_from_center);
	float alpha = COLOR.a * pow(halo, 1.7);
	vec3 warm_color = COLOR.rgb;
	ALBEDO = warm_color * (0.25 + core * 0.75);
	EMISSION = warm_color * glow_strength * (halo * 0.75 + core * 2.4) * COLOR.a;
	ALPHA = alpha;
}
