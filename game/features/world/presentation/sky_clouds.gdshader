shader_type sky;
render_mode use_debanding;

// Anime & Ghibli-styled procedural sky and clouds.
// Features:
// 1. High-altitude cirrus wind streaks (anime atmospheric lines).
// 2. Multi-stage domain-warped FBM for rounded cumulus "cauliflower" lobes.
// 3. Stepped anime toon shading (Highlight, Midtone, Soft Ambient Shadow).
// 4. Directional self-shadowing & warm sun rim highlights on cloud edges.

// --- driven from GDScript ---------------------------------------------------
uniform vec3 u_horizon_color : source_color = vec3(0.48, 0.75, 0.88);
uniform vec3 u_zenith_color : source_color = vec3(0.20, 0.48, 0.78);
uniform vec3 u_sun_color : source_color = vec3(1.0, 0.95, 0.82);
uniform vec3 u_horizon_glow_color : source_color = vec3(1.0, 0.52, 0.25); // sunset scatter tint
uniform float u_overcast : hint_range(0.0, 1.0) = 0.0;
uniform float u_solar_intensity : hint_range(0.0, 1.0) = 1.0;
uniform float u_sun_visibility : hint_range(0.0, 1.0) = 1.0;
uniform float u_night_factor : hint_range(0.0, 1.0) = 0.0;
uniform float u_star_visibility : hint_range(0.0, 1.0) = 0.0;
uniform float u_star_density : hint_range(0.0, 1.0) = 0.72;
uniform float u_star_twinkle : hint_range(0.0, 1.0) = 0.16;
uniform float u_sun_disc_energy = 6.0;  // HDR overdrive so filmic tonemap + glow bloom the disc
uniform float u_time = 0.0;
// Night moon: direction is placed opposite the sun's azimuth by GDScript, energy
// rises with the night so it only lights the sky after dusk.
uniform vec3 u_moon_dir = vec3(0.35, 0.55, -0.76);
uniform vec3 u_moon_color : source_color = vec3(0.72, 0.80, 0.96);
uniform float u_moon_energy : hint_range(0.0, 1.0) = 0.0;
// Atmospheric horizon haze / morning band. Colour is driven warm at dawn/dusk,
// pale blue-white by day; strength fades to zero at deep night.
uniform vec3 u_haze_color : source_color = vec3(0.82, 0.88, 0.93);
uniform float u_haze_strength : hint_range(0.0, 1.0) = 0.45;

// --- static art-direction knobs --------------------------------------------
uniform float u_cloud_scale = 1.55;     // bigger = smaller cloud cells
uniform vec2 u_wind = vec2(0.006, 0.002);
uniform float u_edge_softness = 0.07;   // lower = harder, crisp anime cartoon edges
uniform float u_coverage_clear = 0.46;  // threshold when sunny (few clouds)
uniform float u_coverage_storm = 0.18;  // threshold when overcast (full sheet)
uniform float u_shadow_step = 0.055;    // self-shadow march distance
uniform vec3 u_cloud_lit_clear : source_color = vec3(1.0, 0.985, 0.95);
uniform vec3 u_cloud_mid_clear : source_color = vec3(0.70, 0.84, 0.95);
uniform vec3 u_cloud_shadow_clear : source_color = vec3(0.38, 0.56, 0.73);
uniform vec3 u_cloud_lit_storm : source_color = vec3(0.55, 0.58, 0.63);
uniform vec3 u_cloud_mid_storm : source_color = vec3(0.40, 0.44, 0.50);
uniform vec3 u_cloud_shadow_storm : source_color = vec3(0.26, 0.29, 0.34);
uniform vec3 u_cloud_lit_night : source_color = vec3(0.18, 0.22, 0.31);
uniform vec3 u_cloud_mid_night : source_color = vec3(0.135, 0.17, 0.245);
uniform vec3 u_cloud_shadow_night : source_color = vec3(0.095, 0.125, 0.19);

// --- anime-specific controls -----------------------------------------------
uniform float u_cirrus_amount : hint_range(0.0, 1.0) = 0.16; // high streaky wind clouds
uniform float u_toon_banding : hint_range(0.0, 1.0) = 0.58; // night fades this toward soft moonlit gradients

// ---------------------------------------------------------------------------
float hash21(vec2 p) {
	p = fract(p * vec2(123.34, 345.45));
	p += dot(p, p + 34.345);
	return fract(p.x * p.y);
}

float value_noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f); // smooth -> rounded lobes
	float a = hash21(i);
	float b = hash21(i + vec2(1.0, 0.0));
	float c = hash21(i + vec2(0.0, 1.0));
	float d = hash21(i + vec2(1.0, 1.0));
	return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

float fbm(vec2 p) {
	float sum = 0.0;
	float amp = 0.5;
	for (int i = 0; i < 4; i++) {
		sum += amp * value_noise(p);
		p *= 2.02;
		amp *= 0.5;
	}
	return sum;
}

// Rounded cellular peaks create the hand-painted "cauliflower" lobes that
// ordinary FBM lacks. The output is high in the centre of each random cell.
float cellular_billow(vec2 p) {
	vec2 cell = floor(p);
	vec2 local = fract(p);
	float nearest = 2.0;
	for (int y = -1; y <= 1; y++) {
		for (int x = -1; x <= 1; x++) {
			vec2 neighbour = vec2(float(x), float(y));
			vec2 sample_cell = cell + neighbour;
			vec2 point = vec2(
				hash21(sample_cell + vec2(7.1, 3.7)),
				hash21(sample_cell + vec2(19.3, 11.8))
			);
			nearest = min(nearest, length(neighbour + point - local));
		}
	}
	return 1.0 - smoothstep(0.18, 0.78, nearest);
}

// A low-frequency family mask keeps broad openings of blue sky, while several
// sizes of cellular billows build an irregular cauliflower silhouette. Unlike
// stamped primitives, every family remains organic and non-repeating.
float cloud_field(vec2 uv) {
	vec2 q = vec2(
		fbm(uv * 0.68 + vec2(0.0, 0.0)),
		fbm(uv * 0.68 + vec2(5.2, 1.3))
	);
	float macro = fbm(uv * 0.30 + q * 0.48);
	float large_billows = cellular_billow(uv * 0.72 + q * 0.58);
	float medium_billows = cellular_billow(uv * 1.18 + q * 0.92 + vec2(3.7, 8.1));
	float detail = fbm(uv * 2.45 + q * 1.28);
	float family = smoothstep(0.40, 0.66, macro);
	float body = macro * 0.34
		+ large_billows * 0.44
		+ medium_billows * 0.16
		+ detail * 0.06;
	return body * mix(0.26, 1.0, family);
}

// A second, finer family breaks the primary cloud bank into a readable
// hierarchy: broad hero masses, medium cauliflower lobes, and a few detached
// satellites. It fades out toward overcast weather, where a continuous ceiling
// is more believable than a collection of small fair-weather puffs.
float layered_cloud_field(vec2 uv) {
	float primary = cloud_field(uv);
	float satellites = cloud_field(uv * 1.62 + vec2(7.4, -3.1));
	float satellite_cut = mix(0.20, 0.36, smoothstep(0.42, 0.88, u_overcast));
	return max(primary, satellites - satellite_cut);
}

// Projected cloud ceilings naturally prefer long horizontal banks. A sparse
// azimuth/elevation field supplies the vertical hero silhouettes seen in
// summer cumulus: broad grounded bases, irregular cauliflower crowns, and open
// sky between families. It is spherical, so the shape remains stable when the
// camera looks toward the horizon instead of stretching with the ceiling map.
float tower_cloud_field(vec3 direction) {
	float height = max(direction.y, 0.0);
	vec2 bearing = direction.xz / max(length(direction.xz), 0.001);
	float family_seed = fbm(bearing * 1.35 + vec2(0.0, 4.0));
	float family = smoothstep(0.48, 0.67, family_seed);
	float crown_seed = fbm(bearing * 2.10 + vec2(5.0, 2.0));
	float crown_height = mix(0.20, 0.64, pow(crown_seed, 1.65));
	float base = smoothstep(0.015, 0.075, height);
	float crown = 1.0 - smoothstep(crown_height - 0.055, crown_height + 0.035, height);
	float along = dot(bearing, normalize(vec2(0.82, 0.57)));
	float across = dot(bearing, normalize(vec2(-0.57, 0.82)));
	float billows = cellular_billow(vec2(along * 3.15 + across * 0.72, height * 7.2) + vec2(1.7, 9.4));
	float erosion = fbm(vec2(across * 5.4 + along, height * 9.0) + vec2(12.0, 3.0));
	float body = 0.50 + billows * 0.31 + erosion * 0.12;
	return family * base * crown * body;
}

// High-altitude cirrus wind streaks layer
float cirrus_field(vec2 uv) {
	vec2 streaked_uv = vec2(uv.x * 0.35 + uv.y * 1.6, uv.y * 3.8);
	float n = fbm(streaked_uv + u_wind * u_time * 0.4);
	return smoothstep(0.52, 0.76, n);
}

// A deliberately sparse, stable star field. It belongs in the sky material so
// the weather rig can fade it with twilight and cloud cover.
vec3 star_layer(vec2 uv, float scale, float threshold, float time_offset) {
	uv *= scale;
	vec2 cell = floor(uv);
	vec2 local = fract(uv) - 0.5;
	float seed = hash21(cell);
	vec2 point = vec2(hash21(cell + 3.1), hash21(cell + 9.7)) - 0.5;
	float radius = mix(0.010, 0.027, step(0.987, seed));
	float twinkle = 0.88 + sin(u_time * 0.75 + seed * 31.0 + time_offset) * u_star_twinkle;
	float star = 1.0 - smoothstep(radius, radius * 2.5, length(local - point));
	float bright = star * step(threshold, seed) * twinkle;
	// Per-star colour temperature: a few warm amber stars among cool blue-white
	// ones keep the field from looking like uniform pixels.
	float ctemp = hash21(cell + vec2(4.7, 12.3));
	vec3 tint = mix(vec3(1.0, 0.82, 0.66), vec3(0.72, 0.83, 1.0), smoothstep(0.0, 0.65, ctemp));
	return tint * bright;
}

vec3 star_field(vec3 dir) {
	vec2 uv = dir.xz / max(dir.y + 1.15, 0.18) * 85.0;
	vec3 bright = star_layer(uv, 1.0, mix(0.982, 0.957, u_star_density), 0.0);
	vec3 fine = star_layer(uv + 17.3, 1.73, mix(0.992, 0.973, u_star_density), 1.7);
	return bright + fine * 0.58;
}

void sky() {
	vec3 dir = normalize(EYEDIR);
	float horizon = dir.y;

	// --- base sky gradient ---
	float grad = smoothstep(0.0, 0.48, horizon);
	vec3 sky_col = mix(u_horizon_color, u_zenith_color, grad);

	// --- atmospheric horizon haze / morning fog ---
	// A soft band hugs the horizon; a slow drifting low-frequency noise breaks it
	// into banks of mist rather than a flat gradient, so the dawn haze reads as
	// ground fog. Densest right at the horizon, thinning upward.
	float fog_profile = pow(1.0 - clamp(horizon / 0.55, 0.0, 1.0), 2.2);
	float fog_tex = fbm(dir.xz / max(horizon + 0.32, 0.32) * 2.3 + u_wind * u_time * 4.0);
	float fog_amount = fog_profile * u_haze_strength * (0.62 + fog_tex * 0.7);
	sky_col = mix(sky_col, u_haze_color, clamp(fog_amount, 0.0, 1.0));

	float star_visibility = u_star_visibility * (1.0 - u_overcast * 0.68);

	// --- Milky Way: a faint textured band along a great circle, denser overhead ---
	vec3 mw_axis = normalize(vec3(0.82, 0.24, 0.52));
	float mw_dist = abs(dot(dir, mw_axis));
	float mw_band = (1.0 - smoothstep(0.0, 0.34, mw_dist)) * smoothstep(0.06, 0.4, horizon);
	float mw_tex = fbm(dir.xz / max(dir.y + 0.5, 0.2) * 5.5 + vec2(3.0, 7.0));
	sky_col += vec3(0.40, 0.48, 0.72) * mw_band * (0.045 + mw_tex * 0.075) * star_visibility;

	// Individual clouds mask stars later in the final sky blend. Keep a small
	// global contribution at partial cover so stars remain visible through gaps.
	vec3 stars = star_field(dir) * smoothstep(0.04, 0.32, horizon);
	sky_col += stars * star_visibility * 2.5;

	vec3 sun_dir = LIGHT0_ENABLED ? normalize(LIGHT0_DIRECTION) : vec3(0.0, 1.0, 0.0);

// A single soft sun disc plus its atmospheric glow. The disc deliberately uses
// one continuous profile: a separate bright core would read as a second, small
// sun inside the larger glow.
	float sun_amt = max(dot(dir, sun_dir), 0.0);
	float clear_sky = 1.0 - u_overcast;

	// Redden the disc and scattering near horizon. A gentle curve pushes the disc
	// into gold sooner as the sun drops, so sunrise/sunset read warm without the
	// noon sun turning a sickly yellow.
	float sun_low = 1.0 - smoothstep(0.0, 0.35, sun_dir.y);
	float sun_gold = pow(sun_low, 0.7);
	vec3 warm_sun = mix(u_sun_color, u_horizon_glow_color, sun_gold);

	// HDR disc blooms through the environment's glow pass, while remaining one
	// visual body rather than a screen-space flare laid over the sky.
	float sun_disc = smoothstep(0.9968, 0.99965, sun_amt);
	sky_col += warm_sun * sun_disc * u_solar_intensity * u_sun_disc_energy * u_sun_visibility;

	// Mie scattering halo — broader and warmer when the sun sits low.
	float halo_strength = mix(0.15, 0.72, sun_low);
	float halo_visibility = mix(0.25, 1.0, u_sun_visibility);
	sky_col += warm_sun * pow(sun_amt, 6.0) * halo_strength * clear_sky * u_solar_intensity * halo_visibility;
	// A soft wide golden bloom hugging the low sun adds the anime sunrise glow.
	sky_col += warm_sun * pow(sun_amt, 2.2) * sun_low * 0.14 * clear_sky * u_solar_intensity * halo_visibility;

	// Warm band along horizon at sunrise/sunset
	float horizon_band = pow(1.0 - abs(dir.y), 6.0);
	sky_col += u_horizon_glow_color * horizon_band * sun_low * 0.35 * clear_sky * u_solar_intensity;

	// --- night moon ---
	// A soft disc opposite the sun, with a tight inner glow and a faint wide halo.
	// The surface is procedural: no texture sampler, just FBM "maria" and a gentle
	// spherical shade. Gated by u_moon_energy so it only appears after dusk.
	if (u_moon_energy > 0.001) {
		vec3 moon_dir = normalize(u_moon_dir);
		float moon_amt = max(dot(dir, moon_dir), 0.0);
		float moon_disc = smoothstep(0.99719, 0.99928, moon_amt);
		// Disc-local coordinates via a tangent frame around the moon direction.
		// dot(dir, tangent) ~= the small angular offset, so muv spans [-1,1] across
		// the disc once divided by its angular radius.
		vec3 moon_t = normalize(cross(moon_dir, vec3(0.0, 1.0, 0.0)));
		vec3 moon_b = cross(moon_dir, moon_t);
		vec2 muv = vec2(dot(dir, moon_t), dot(dir, moon_b)) / 0.075;
		float mr = length(muv);
		float sphere = sqrt(max(1.0 - mr * mr, 0.0)); // limb darkening for volume
		// Dark maria patches plus a whisper of finer relief.
		float maria = fbm(muv * 1.5 + vec2(4.0, 2.0));
		float relief = fbm(muv * 5.5 + vec2(11.0, 7.0));
		float surface = 1.0 - smoothstep(0.52, 0.74, maria) * 0.45;
		surface -= (relief - 0.5) * 0.14;
		surface = clamp(surface, 0.42, 1.0);
		vec3 moon_face = u_moon_color * surface * mix(0.80, 1.06, sphere);
		float moon_glow = pow(moon_amt, 120.0) * 0.30 + pow(moon_amt, 7.0) * 0.04;
		sky_col += (moon_face * moon_disc * 2.6 + u_moon_color * moon_glow) * u_moon_energy * clear_sky;
	}

	// --- sky projection ---
	// Adding a height offset instead of clamping the denominator keeps the
	// projection continuous. This prevents long horizontal bands near the
	// horizon while preserving the feeling of a cloud ceiling.
	float ceil_mask = smoothstep(0.02, 0.10, horizon);
	vec2 projected_uv = dir.xz / max(horizon + 0.28, 0.28);
	vec2 uv = projected_uv * u_cloud_scale + u_wind * u_time;

	// --- High-altitude cirrus streaks layer ---
	if (u_cirrus_amount > 0.001) {
		float cirrus_mask = cirrus_field(uv * 0.85);
		vec3 cirrus_col = mix(u_cloud_lit_clear, sky_col, 0.35);
		// Cirrus belongs to the daytime blue sky. It fades out through dusk so it
		// never smudges over the night star field, where it only adds noise.
		float cirrus_day = 1.0 - u_night_factor;
		float cirrus_alpha = cirrus_mask * u_cirrus_amount * ceil_mask * clear_sky * cirrus_day * 0.28;
		sky_col = mix(sky_col, cirrus_col, cirrus_alpha);
	}

	// --- Main cumulus clouds layer ---
	// Cumulus remains on its own higher, softer ceiling. The larger height
	// offset removes the horizontal stretching of the old low cloud plane while
	// remaining seamless at the horizon and zenith.
	vec2 cumulus_projected_uv = dir.xz / max(horizon + 0.55, 0.55);
	vec2 cumulus_uv = cumulus_projected_uv * u_cloud_scale * 1.6;
	cumulus_uv += vec2(u_wind.x * u_time * 2.4, u_wind.y * u_time * 0.55);
	float projected_n = layered_cloud_field(cumulus_uv);
	vec3 tower_dir = normalize(dir + vec3(u_wind.x * u_time * 0.12, 0.0, u_wind.y * u_time * 0.12));
	float tower_weather = 1.0 - smoothstep(0.74, 0.96, u_overcast);
	float tower_n = tower_cloud_field(tower_dir) * tower_weather;
	float n = max(projected_n, tower_n);
	float coverage_curve = pow(u_overcast, 0.55);
	float coverage = mix(u_coverage_clear, u_coverage_storm, coverage_curve);
	// A restrained distant bank anchors clouds at the horizon without filling
	// every azimuth. Fair-weather presets keep generous blue openings; the bank
	// only grows as the forecast approaches genuinely cloudy conditions.
	float bank = 1.0 - smoothstep(0.04, 0.50, horizon);
	float bank_weather = smoothstep(0.24, 0.68, u_overcast);
	float bank_variation = smoothstep(0.38, 0.72, fbm(cumulus_uv * 0.24 + vec2(19.0, 4.0)));
	float bank_strength = mix(0.13, 0.07, u_night_factor) * bank_weather * bank_variation;
	float n_banked = n + bank * bank_strength;
	float clear_edge = mix(u_edge_softness, u_edge_softness * 0.6, clear_sky);
	clear_edge *= mix(1.0, 1.35, u_night_factor);
	float density = smoothstep(coverage, coverage + clear_edge, n_banked);
	// At the end of the scale, merge the cumulus into a broad, textured ceiling
	// rather than leaving isolated cartoon blobs over a supposedly covered sky.
	float ceiling_amount = smoothstep(0.72, 0.94, u_overcast);
	float ceiling_texture = 0.72 + fbm(cumulus_uv * 0.38 + vec2(31.0, 9.0)) * 0.22;
	density = max(density, ceiling_amount * ceiling_texture);

	// Density gradients act as a cheap surface normal. Together with a short
	// directional shadow march they produce lit domes and cool undersides.
	float normal_step = 0.035;
	float projected_gradient_x = layered_cloud_field(cumulus_uv + vec2(normal_step, 0.0)) - layered_cloud_field(cumulus_uv - vec2(normal_step, 0.0));
	float projected_gradient_y = layered_cloud_field(cumulus_uv + vec2(0.0, normal_step)) - layered_cloud_field(cumulus_uv - vec2(0.0, normal_step));
	float tower_step = 0.012;
	float tower_gradient_x = tower_cloud_field(normalize(tower_dir + vec3(tower_step, 0.0, 0.0))) * tower_weather
		- tower_n;
	float tower_gradient_y = tower_cloud_field(normalize(tower_dir + vec3(0.0, tower_step, 0.0))) * tower_weather
		- tower_n;
	float tower_dominance = smoothstep(projected_n - 0.02, projected_n + 0.08, tower_n);
	float gradient_x = mix(projected_gradient_x, tower_gradient_x * 2.2, tower_dominance);
	float gradient_y = mix(projected_gradient_y, tower_gradient_y * 2.2, tower_dominance);
	vec3 cloud_normal = normalize(vec3(-gradient_x * 1.35, 0.94, -gradient_y * 1.35));
	vec2 sun2d = length(sun_dir.xz) > 0.001 ? normalize(sun_dir.xz) : vec2(0.0, 1.0);
	vec3 sun_cloud_light_dir = normalize(vec3(sun2d.x, max(sun_dir.y, 0.18), sun2d.y));
	vec2 moon2d = length(u_moon_dir.xz) > 0.001 ? normalize(u_moon_dir.xz) : vec2(0.0, 1.0);
	vec3 moon_cloud_light_dir = normalize(vec3(moon2d.x, max(u_moon_dir.y, 0.20), moon2d.y));
	// The moon becomes the primary light at night. Previously the hidden sun
	// continued to carve the cloud interiors while moonlight only drew a rim,
	// producing dark rings with bright outlines.
	vec3 cloud_light_dir = normalize(mix(sun_cloud_light_dir, moon_cloud_light_dir, u_night_factor));
	vec2 cloud_light_2d = length(cloud_light_dir.xz) > 0.001 ? normalize(cloud_light_dir.xz) : vec2(0.0, 1.0);
	float occ = 0.0;
	for (int i = 1; i <= 3; i++) {
		float s = layered_cloud_field(cumulus_uv + cloud_light_2d * u_shadow_step * float(i));
		occ += smoothstep(coverage, coverage + u_edge_softness, s);
	}
	occ /= 3.0;
	float dome_light = max(dot(cloud_normal, cloud_light_dir), 0.0);
	float dome_strength = mix(0.34, 0.24, u_night_factor);
	float shadow_relief = mix(0.26, 0.10, u_night_factor);
	float ambient_fill = mix(0.18, 0.28, u_night_factor);
	float lit = clamp(dome_light * dome_strength + (1.0 - occ) * shadow_relief + ambient_fill, 0.0, 1.0);
	float painted_detail = fbm(cumulus_uv * 3.6 + vec2(13.2, 2.7));
	float detail_strength = mix(0.09, 0.025, u_night_factor);
	lit = clamp(lit + (painted_detail - 0.5) * detail_strength * density, 0.0, 1.0);
	float lobe_core = smoothstep(coverage + 0.025, coverage + 0.17, n);
	float inner_billows = cellular_billow(cumulus_uv * 1.58 + vec2(4.1, 9.3));
	float lobe_light = mix(0.16, 0.055, u_night_factor);
	lit = clamp(lit + lobe_core * lobe_light + (inner_billows - 0.5) * 0.035 * density, 0.0, 1.0);
	lit -= smoothstep(0.48, 0.95, horizon) * density * mix(0.08, 0.025, u_night_factor);
	lit = mix(lit, lit * 0.55 + 0.25, u_overcast);

	vec3 cloud_lit = mix(u_cloud_lit_clear, u_cloud_lit_storm, u_overcast);
	vec3 cloud_mid = mix(u_cloud_mid_clear, u_cloud_mid_storm, u_overcast);
	vec3 cloud_shadow = mix(u_cloud_shadow_clear, u_cloud_shadow_storm, u_overcast);
	// Moonlight is cool and restrained: clouds remain readable but do not turn
	// into bright daytime masses that erase the night sky.
	float night_cloud_mix = u_night_factor;
	cloud_lit = mix(cloud_lit, u_cloud_lit_night, night_cloud_mix);
	cloud_mid = mix(cloud_mid, u_cloud_mid_night, night_cloud_mix);
	cloud_shadow = mix(cloud_shadow, u_cloud_shadow_night, night_cloud_mix);

	// Three controllable paint bands: cool shadow, blue midtone, warm white.
	float shadow_mid_soft = smoothstep(0.12, 0.62, lit);
	float mid_lit_soft = smoothstep(0.42, 0.92, lit);
	float shadow_mid_toon = smoothstep(0.31, 0.39, lit);
	float mid_lit_toon = smoothstep(0.67, 0.75, lit);
	float band_strength = u_toon_banding * clear_sky * mix(1.0, 0.18, u_night_factor);
	float shadow_mid = mix(shadow_mid_soft, shadow_mid_toon, band_strength);
	float mid_lit = mix(mid_lit_soft, mid_lit_toon, band_strength);
	vec3 cloud_col = mix(cloud_shadow, cloud_mid, shadow_mid);
	cloud_col = mix(cloud_col, cloud_lit, mid_lit);

	// Warm sun-kissed rim & edge highlight on lit borders facing sun. Twilight
	// retains cloud illumination after the direct-light curve reaches zero at
	// the horizon, then fades it before deep night.
	float edge_mask = smoothstep(coverage - 0.04, coverage + 0.05, n)
		* (1.0 - smoothstep(coverage + 0.08, coverage + 0.22, n));
	float sun_facing = max(dot(cloud_normal, cloud_light_dir), 0.0);
	float rim = edge_mask * mix(0.24, 1.0, sun_facing);
	float twilight_cloud_light = sun_low * (1.0 - u_night_factor) * 0.9;
	float cloud_sun_energy = max(u_solar_intensity, twilight_cloud_light);
	float warm_rim_strength = mix(0.30, 0.78, sun_low);
	float sunset_face = sun_low * (1.0 - u_night_factor)
		* (0.28 + (1.0 - occ) * 0.42 + sun_facing * 0.30);
	vec3 sunset_cloud = cloud_col * vec3(0.84, 0.68, 0.74) + warm_sun * 0.58;
	cloud_col = mix(
		cloud_col,
		sunset_cloud,
		sunset_face * mix(0.66, 0.46, u_overcast)
	);
	float warm_midtone_strength = mix(0.055, 0.12, sun_low);
	cloud_col += warm_sun * (mid_lit * warm_midtone_strength + rim * warm_rim_strength)
		* mix(1.0, 0.58, u_overcast) * cloud_sun_energy;

	// Cool moonlight rim on the cloud tops at night gives the dark masses a
	// silver edge. Keep it restrained because moonlight already drives the main
	// cloud shading above.
	if (u_moon_energy > 0.001) {
		float moon_facing = max(dot(cloud_normal, moon_cloud_light_dir), 0.0);
		float moon_rim = edge_mask * moon_facing;
		cloud_col += u_moon_color * (moon_rim * 0.16 + mid_lit * 0.035) * moon_facing * u_moon_energy * clear_sky;
	}

	// Far clouds dissolve into atmospheric blue instead of becoming stretched
	// opaque lines at the horizon.
	float horizon_haze = 1.0 - smoothstep(0.02, 0.15, horizon);
	cloud_col = mix(cloud_col, sky_col, horizon_haze * 0.42);
	float alpha = density * ceil_mask * mix(0.38, 1.0, 1.0 - horizon_haze);
	alpha *= mix(1.0, 0.84, u_night_factor);
	COLOR = mix(sky_col, cloud_col, alpha);
}
