shader_type canvas_item;
render_mode blend_add;

// Camera-lens artifacts only. The sun itself belongs to sky_clouds.gdshader;
// keeping this shader empty at its centre prevents a second sun from appearing.
//
// Deliberately free of lens ghosts: internal-reflection blobs read as cinematic
// camera optics, which fights a hand-painted sky. What remains is atmospheric —
// a veil of scattered light and one restrained streak.
uniform vec2 u_sun_screen_pos = vec2(0.5);
uniform float u_intensity : hint_range(0.0, 1.25) = 0.0;
uniform float u_aspect = 1.0;
uniform vec4 u_sun_color : source_color = vec4(1.0, 0.95, 0.82, 1.0);
uniform float u_halo_strength : hint_range(0.0, 2.0) = 1.0;
uniform float u_streak_strength : hint_range(0.0, 2.0) = 1.0;
// Screen radius of the sky disc, in the same aspect-corrected units the distances
// below use (1.0 == viewport height). GDScript derives it from the disc's angular
// radius and the camera FOV, so the cut-out tracks the disc when the sun swells at
// the horizon or the camera zooms. A hardcoded radius drifted off the disc and
// exposed either a second sun or a dark ring around the first.
uniform float u_disc_radius : hint_range(0.0, 0.5) = 0.02;

vec2 aspect_delta(vec2 uv, vec2 center) {
	vec2 delta = uv - center;
	delta.x *= u_aspect;
	return delta;
}

void fragment() {
	vec2 uv = SCREEN_UV;
	vec2 center = u_sun_screen_pos;
	vec2 sun_delta = aspect_delta(uv, center);

	// Leave the physical sky sun untouched. This is only its broad lens veil;
	// the cut-out prevents it from looking like a second sun disc.
	float sun_distance = length(sun_delta);
	float center_cutout = smoothstep(u_disc_radius * 0.85, u_disc_radius * 1.9, sun_distance);
	vec3 color = vec3(0.0);
	// The veil scales with the disc so a swollen horizon sun carries a wider glow.
	float veil = exp(-sun_distance / max(u_disc_radius * 1.15, 0.004)) * center_cutout;
	color += mix(u_sun_color.rgb, vec3(1.0, 0.78, 0.52), 0.15) * veil * 0.16 * u_halo_strength;

	// A restrained horizontal anamorphic streak near the sun.
	float streak = exp(-abs(sun_delta.y) * 92.0) * exp(-abs(sun_delta.x) * 6.2);
	color += mix(u_sun_color.rgb, vec3(0.86, 0.92, 1.0), 0.22) * streak * 0.14 * center_cutout * u_streak_strength;

	// With blend_add, a low alpha attenuates the RGB contribution again. Keep it
	// opaque and apply the animated visibility exactly once.
	COLOR = vec4(color * u_intensity, 1.0);
}
