shader_type canvas_item;
render_mode blend_add;

// Camera-lens artifacts only. The sun itself belongs to sky_clouds.gdshader;
// keeping this shader empty at its centre prevents a second sun from appearing.
//
// Two independent strengths, because the two halves of a flare behave differently:
//   * u_veil_intensity  — atmospheric scatter around the sun. Survives the sun
//     leaving the frame, which is the normal case for this game's downward camera:
//     a sun just past the top edge still washes warm light down the screen.
//   * u_intensity       — the placed artifacts (spikes, streak, ring, ghosts). These
//     need the sun to actually be on screen, and bloom as it nears the centre.
uniform vec2 u_sun_screen_pos = vec2(0.5);
uniform float u_intensity : hint_range(0.0, 1.25) = 0.0;
uniform float u_veil_intensity : hint_range(0.0, 1.25) = 0.0;
uniform float u_aspect = 1.0;
uniform vec4 u_sun_color : source_color = vec4(1.0, 0.95, 0.82, 1.0);
uniform float u_halo_strength : hint_range(0.0, 2.0) = 1.0;
uniform float u_streak_strength : hint_range(0.0, 2.0) = 1.0;
uniform float u_spike_strength : hint_range(0.0, 2.0) = 1.0;
uniform float u_ghost_strength : hint_range(0.0, 2.0) = 1.0;
// Screen radius of the sky disc, in the same aspect-corrected units the distances
// below use (1.0 == viewport height). GDScript derives it from the disc's angular
// radius and the camera FOV, so every artifact scales with the sun as it swells at
// the horizon, and the cut-out keeps tracking the disc through zooms.
uniform float u_disc_radius : hint_range(0.0, 0.5) = 0.02;
// Slow rotation of the starburst arms, so the flare breathes instead of sitting
// welded to the screen.
uniform float u_time = 0.0;

vec2 aspect_delta(vec2 uv, vec2 center) {
	vec2 delta = uv - center;
	delta.x *= u_aspect;
	return delta;
}

float blob(vec2 uv, vec2 center, float radius, float softness) {
	float distance_to_center = length(aspect_delta(uv, center)) / radius;
	return pow(max(1.0 - distance_to_center, 0.0), softness);
}

void fragment() {
	vec2 uv = SCREEN_UV;
	vec2 center = u_sun_screen_pos;
	vec2 to_screen_center = vec2(0.5) - center;
	vec2 sun_delta = aspect_delta(uv, center);
	float sun_distance = length(sun_delta);
	float radius = max(u_disc_radius, 0.004);

	// Leave the physical sky sun untouched. This is only the light around it; the
	// cut-out prevents a second, brighter disc from appearing on top of the first.
	float center_cutout = smoothstep(radius * 0.85, radius * 1.9, sun_distance);

	vec3 warm = mix(u_sun_color.rgb, vec3(1.0, 0.78, 0.52), 0.22);
	vec3 cool = mix(u_sun_color.rgb, vec3(0.74, 0.86, 1.0), 0.40);

	// --- veil: scattered light, the part that survives an off-screen sun ---------
	// Two lobes rather than one. The tight lobe gives the sun a bright seat; the
	// broad one carries warmth far across the frame, which is what actually reads
	// when the sun sits just outside the view.
	float veil_tight = exp(-sun_distance / (radius * 1.5));
	float veil_broad = exp(-sun_distance / (radius * 4.5));
	// A third lobe measured in absolute screen units rather than in disc radii. This
	// is the one that matters at the default gameplay pitch, where the camera looks
	// far enough down that no sky is in frame at all: the sun sits above the top edge
	// and only a wash this wide still reaches across the picture.
	float veil_wash = exp(-sun_distance / 0.55);
	vec3 veil = warm * (veil_tight * 0.22 + veil_broad * 0.07 + veil_wash * 0.09) * u_halo_strength;

	// --- placed artifacts -------------------------------------------------------
	vec3 artifacts = vec3(0.0);

	// A soft six-armed starburst. Painted skies wear sparkle better than they wear
	// camera optics, so this carries most of the flare's character.
	float angle = atan(sun_delta.y, sun_delta.x);
	float arms = pow(abs(cos(angle * 3.0 + u_time * 0.03)), 14.0);
	// A second, offset set at half strength keeps the star from looking mechanical.
	arms += pow(abs(cos(angle * 3.0 + u_time * 0.03 + 0.5236)), 20.0) * 0.45;
	float spike_reach = exp(-sun_distance / (radius * 2.6));
	artifacts += mix(warm, vec3(1.0), 0.45) * arms * spike_reach * 0.16 * u_spike_strength;

	// One restrained horizontal anamorphic streak.
	float streak = exp(-abs(sun_delta.y) / (radius * 0.30)) * exp(-abs(sun_delta.x) / (radius * 6.0));
	artifacts += mix(warm, cool, 0.35) * streak * 0.16 * u_streak_strength;

	// Iris ring: one wide, faint circle out along the sun-to-centre axis, with a
	// gentle warm-to-cool shift across its width. Deliberately low contrast — this
	// is a hint of an optic, not a photographic reproduction of one.
	vec2 ring_center = center + to_screen_center * 1.25;
	float ring_distance = length(aspect_delta(uv, ring_center));
	float ring_radius = 0.155;
	float ring = exp(-pow((ring_distance - ring_radius) / 0.045, 2.0));
	vec3 ring_color = mix(
		vec3(1.0, 0.72, 0.52),
		vec3(0.62, 0.82, 1.0),
		smoothstep(ring_radius - 0.05, ring_radius + 0.05, ring_distance)
	);
	artifacts += ring_color * ring * 0.05 * u_ghost_strength;

	// Internal reflections along the sun-to-centre axis. Kept soft and few: a long
	// chain of hard blobs is what makes a flare read as stock camera footage.
	artifacts += vec3(1.0, 0.80, 0.55) * blob(uv, center + to_screen_center * 0.42, 0.034, 2.4) * 0.10 * u_ghost_strength;
	artifacts += vec3(0.66, 0.82, 1.0) * blob(uv, center + to_screen_center * 0.78, 0.046, 2.8) * 0.07 * u_ghost_strength;
	artifacts += vec3(1.0, 0.90, 0.70) * blob(uv, center + to_screen_center * 1.52, 0.026, 2.6) * 0.05 * u_ghost_strength;

	vec3 color = veil * u_veil_intensity + artifacts * u_intensity;

	// With blend_add, a low alpha attenuates the RGB contribution again. Keep it
	// opaque; the visibility curves above are already applied exactly once.
	COLOR = vec4(color * center_cutout, 1.0);
}
