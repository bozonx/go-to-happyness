shader_type canvas_item;
render_mode blend_add;

// Camera-lens artifacts only. The sun itself belongs to sky_clouds.gdshader;
// keeping this shader empty at its centre prevents a second sun from appearing.
uniform vec2 u_sun_screen_pos = vec2(0.5);
uniform float u_intensity : hint_range(0.0, 1.0) = 0.0;
uniform float u_aspect = 1.0;
uniform vec4 u_sun_color : source_color = vec4(1.0, 0.95, 0.82, 1.0);

vec2 aspect_delta(vec2 uv, vec2 center) {
	vec2 delta = uv - center;
	delta.x *= u_aspect;
	return delta;
}

float ghost(vec2 uv, vec2 center, float radius, float softness) {
	float distance_to_center = length(aspect_delta(uv, center)) / radius;
	return pow(max(1.0 - distance_to_center, 0.0), softness);
}

void fragment() {
	vec2 uv = SCREEN_UV;
	vec2 center = u_sun_screen_pos;
	vec2 to_screen_center = vec2(0.5) - center;
	vec2 sun_delta = aspect_delta(uv, center);

	// Leave the physical sky sun untouched: no disc or glow is painted here.
	float center_cutout = smoothstep(0.018, 0.050, length(sun_delta));
	vec3 color = vec3(0.0);

	// A short, subtle anamorphic streak near the sun, with a clean centre.
	float streak = exp(-abs(sun_delta.y) * 145.0) * exp(-abs(sun_delta.x) * 5.5);
	color += mix(u_sun_color.rgb, vec3(0.78, 0.88, 1.0), 0.3) * streak * 0.075 * center_cutout;

	// Sparse internal reflections along the sun-to-camera-centre axis.
	float warm_ghost = ghost(uv, center + to_screen_center * 0.35, 0.019, 2.4);
	float cool_ghost = ghost(uv, center + to_screen_center * 0.68, 0.028, 3.0);
	float faint_ghost = ghost(uv, center + to_screen_center * 1.05, 0.016, 2.8);
	color += vec3(1.0, 0.72, 0.38) * warm_ghost * 0.20;
	color += vec3(0.48, 0.70, 1.0) * cool_ghost * 0.13;
	color += vec3(1.0, 0.88, 0.62) * faint_ghost * 0.08;

	float alpha = clamp(max(max(color.r, color.g), color.b) * u_intensity, 0.0, 0.38);
	COLOR = vec4(color * u_intensity, alpha);
}
