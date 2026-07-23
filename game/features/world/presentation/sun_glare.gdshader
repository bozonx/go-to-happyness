shader_type canvas_item;
render_mode blend_add;

// Camera-lens artifacts only. The sun itself belongs to sky_clouds.gdshader;
// keeping this shader empty at its centre prevents a second sun from appearing.
uniform vec2 u_sun_screen_pos = vec2(0.5);
uniform float u_intensity : hint_range(0.0, 1.25) = 0.0;
uniform float u_aspect = 1.0;
uniform vec4 u_sun_color : source_color = vec4(1.0, 0.95, 0.82, 1.0);
uniform float u_halo_strength : hint_range(0.0, 2.0) = 1.0;
uniform float u_streak_strength : hint_range(0.0, 2.0) = 1.0;
uniform float u_ghost_strength : hint_range(0.0, 2.0) = 1.0;

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

	// Leave the physical sky sun untouched. This is only its broad lens veil;
	// the small cut-out prevents it from looking like a second sun disc.
	float sun_distance = length(sun_delta);
	float center_cutout = smoothstep(0.012, 0.038, sun_distance);
	vec3 color = vec3(0.0);
	float veil = exp(-sun_distance * 18.0) * center_cutout;
	color += mix(u_sun_color.rgb, vec3(1.0, 0.78, 0.52), 0.15) * veil * 0.24 * u_halo_strength;

	// A restrained horizontal anamorphic streak near the sun.
	float streak = exp(-abs(sun_delta.y) * 92.0) * exp(-abs(sun_delta.x) * 6.2);
	color += mix(u_sun_color.rgb, vec3(0.86, 0.92, 1.0), 0.22) * streak * 0.14 * center_cutout * u_streak_strength;

	// Internal reflections along the sun-to-camera-centre axis.
	float warm_ghost = ghost(uv, center + to_screen_center * 0.35, 0.034, 2.2);
	float cool_ghost = ghost(uv, center + to_screen_center * 0.68, 0.045, 2.7);
	float faint_ghost = ghost(uv, center + to_screen_center * 1.05, 0.027, 2.5);
	color += vec3(1.0, 0.78, 0.52) * warm_ghost * 0.22 * u_ghost_strength;
	color += vec3(0.72, 0.84, 1.0) * cool_ghost * 0.12 * u_ghost_strength;
	color += vec3(1.0, 0.90, 0.72) * faint_ghost * 0.09 * u_ghost_strength;

	// With blend_add, a low alpha attenuates the RGB contribution again. Keep it
	// opaque and apply the animated visibility exactly once.
	COLOR = vec4(color * u_intensity, 1.0);
}
