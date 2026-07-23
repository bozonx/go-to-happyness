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

// --- static art-direction knobs --------------------------------------------
uniform float u_cloud_scale = 1.55;     // bigger = smaller cloud cells
uniform vec2 u_wind = vec2(0.006, 0.002);
uniform float u_edge_softness = 0.07;   // lower = harder, crisp anime cartoon edges
uniform float u_coverage_clear = 0.46;  // threshold when sunny (few clouds)
uniform float u_coverage_storm = 0.18;  // threshold when overcast (full sheet)
uniform float u_shadow_step = 0.055;    // self-shadow march distance
uniform vec3 u_cloud_lit_clear : source_color = vec3(1.0, 0.965, 0.86);
uniform vec3 u_cloud_mid_clear : source_color = vec3(0.70, 0.84, 0.95);
uniform vec3 u_cloud_shadow_clear : source_color = vec3(0.30, 0.50, 0.72);
uniform vec3 u_cloud_lit_storm : source_color = vec3(0.55, 0.58, 0.63);
uniform vec3 u_cloud_mid_storm : source_color = vec3(0.40, 0.44, 0.50);
uniform vec3 u_cloud_shadow_storm : source_color = vec3(0.26, 0.29, 0.34);
uniform vec3 u_cloud_lit_night : source_color = vec3(0.20, 0.25, 0.36);
uniform vec3 u_cloud_mid_night : source_color = vec3(0.12, 0.16, 0.25);
uniform vec3 u_cloud_shadow_night : source_color = vec3(0.055, 0.075, 0.13);

// --- anime-specific controls -----------------------------------------------
uniform float u_cirrus_amount : hint_range(0.0, 1.0) = 0.16; // high streaky wind clouds
uniform float u_toon_banding : hint_range(0.0, 1.0) = 0.88; // 0 = linear lerp, 1 = sharp anime steps

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

// High-altitude cirrus wind streaks layer
float cirrus_field(vec2 uv) {
	vec2 streaked_uv = vec2(uv.x * 0.35 + uv.y * 1.6, uv.y * 3.8);
	float n = fbm(streaked_uv + u_wind * u_time * 0.4);
	return smoothstep(0.52, 0.76, n);
}

// A deliberately sparse, stable star field. It belongs in the sky material so
// the weather rig can fade it with twilight and cloud cover.
float star_layer(vec2 uv, float scale, float threshold, float time_offset) {
	uv *= scale;
	vec2 cell = floor(uv);
	vec2 local = fract(uv) - 0.5;
	float seed = hash21(cell);
	vec2 point = vec2(hash21(cell + 3.1), hash21(cell + 9.7)) - 0.5;
	float radius = mix(0.010, 0.027, step(0.987, seed));
	float twinkle = 0.88 + sin(u_time * 0.75 + seed * 31.0 + time_offset) * u_star_twinkle;
	float star = 1.0 - smoothstep(radius, radius * 2.5, length(local - point));
	return star * step(threshold, seed) * twinkle;
}

float star_field(vec3 dir) {
	vec2 uv = dir.xz / max(dir.y + 1.15, 0.18) * 85.0;
	float bright = star_layer(uv, 1.0, mix(0.982, 0.957, u_star_density), 0.0);
	float fine = star_layer(uv + 17.3, 1.73, mix(0.992, 0.973, u_star_density), 1.7);
	return bright + fine * 0.58;
}

void sky() {
	vec3 dir = normalize(EYEDIR);
	float horizon = dir.y;

	// --- base sky gradient ---
	float grad = smoothstep(0.0, 0.48, horizon);
	vec3 sky_col = mix(u_horizon_color, u_zenith_color, grad);
	float stars = star_field(dir) * smoothstep(0.04, 0.32, horizon);
	// Individual clouds mask stars later in the final sky blend. Keep a small
	// global contribution at partial cover so stars remain visible through gaps.
	float star_visibility = u_star_visibility * (1.0 - u_overcast * 0.68);
	sky_col += vec3(0.68, 0.79, 1.0) * stars * star_visibility * 2.5;

	vec3 sun_dir = LIGHT0_ENABLED ? normalize(LIGHT0_DIRECTION) : vec3(0.0, 1.0, 0.0);

// A single soft sun disc plus its atmospheric glow. The disc deliberately uses
// one continuous profile: a separate bright core would read as a second, small
// sun inside the larger glow.
	float sun_amt = max(dot(dir, sun_dir), 0.0);
	float clear_sky = 1.0 - u_overcast;

	// Redden the disc and scattering near horizon.
	float sun_low = 1.0 - smoothstep(0.0, 0.35, sun_dir.y);
	vec3 warm_sun = mix(u_sun_color, u_horizon_glow_color, sun_low);

	// HDR disc blooms through the environment's glow pass, while remaining one
	// visual body rather than a screen-space flare laid over the sky.
	float sun_disc = smoothstep(0.9968, 0.99965, sun_amt);
	sky_col += warm_sun * sun_disc * u_solar_intensity * u_sun_disc_energy * u_sun_visibility;

	// Mie scattering halo
	float halo_strength = mix(0.14, 0.55, sun_low);
	float halo_visibility = mix(0.25, 1.0, u_sun_visibility);
	sky_col += warm_sun * pow(sun_amt, 6.0) * halo_strength * clear_sky * u_solar_intensity * halo_visibility;

	// Warm band along horizon at sunrise/sunset
	float horizon_band = pow(1.0 - abs(dir.y), 6.0);
	sky_col += u_horizon_glow_color * horizon_band * sun_low * 0.35 * clear_sky * u_solar_intensity;

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
		float cirrus_alpha = cirrus_mask * u_cirrus_amount * ceil_mask * clear_sky * 0.28;
		sky_col = mix(sky_col, cirrus_col, cirrus_alpha);
	}

	// --- Main cumulus clouds layer ---
	// Cumulus remains on its own higher, softer ceiling. The larger height
	// offset removes the horizontal stretching of the old low cloud plane while
	// remaining seamless at the horizon and zenith.
	vec2 cumulus_projected_uv = dir.xz / max(horizon + 0.55, 0.55);
	vec2 cumulus_uv = cumulus_projected_uv * u_cloud_scale * 1.6;
	cumulus_uv += vec2(u_wind.x * u_time * 2.4, u_wind.y * u_time * 0.55);
	float n = cloud_field(cumulus_uv);
	float coverage_curve = pow(u_overcast, 0.55);
	float coverage = mix(u_coverage_clear, u_coverage_storm, coverage_curve);
	// Clear weather piles a dense cumulus "bank" low on the sky that thins to open
	// blue overhead; overcast keeps its uniform grey ceiling untouched. Rather
	// than only lowering the threshold (which can't invent clouds where the noise
	// is empty) the bank adds body near the horizon so every azimuth is filled.
	float bank = 1.0 - smoothstep(0.04, 0.50, horizon);
	float n_banked = n + bank * clear_sky * 0.40;
	float clear_edge = mix(u_edge_softness, u_edge_softness * 0.6, clear_sky);
	float density = smoothstep(coverage, coverage + clear_edge, n_banked);
	// At the end of the scale, merge the cumulus into a broad, textured ceiling
	// rather than leaving isolated cartoon blobs over a supposedly covered sky.
	float ceiling_amount = smoothstep(0.55, 0.90, u_overcast);
	float ceiling_texture = 0.72 + fbm(cumulus_uv * 0.38 + vec2(31.0, 9.0)) * 0.22;
	density = max(density, ceiling_amount * ceiling_texture);

	// Density gradients act as a cheap surface normal. Together with a short
	// directional shadow march they produce lit domes and cool undersides.
	float normal_step = 0.035;
	float gradient_x = cloud_field(cumulus_uv + vec2(normal_step, 0.0)) - cloud_field(cumulus_uv - vec2(normal_step, 0.0));
	float gradient_y = cloud_field(cumulus_uv + vec2(0.0, normal_step)) - cloud_field(cumulus_uv - vec2(0.0, normal_step));
	vec3 cloud_normal = normalize(vec3(-gradient_x * 2.1, 0.94, -gradient_y * 2.1));
	vec2 sun2d = length(sun_dir.xz) > 0.001 ? normalize(sun_dir.xz) : vec2(0.0, 1.0);
	vec3 cloud_light_dir = normalize(vec3(sun2d.x, max(sun_dir.y, 0.18), sun2d.y));
	float occ = 0.0;
	for (int i = 1; i <= 3; i++) {
		float s = cloud_field(cumulus_uv + sun2d * u_shadow_step * float(i));
		occ += smoothstep(coverage, coverage + u_edge_softness, s);
	}
	occ /= 3.0;
	float dome_light = max(dot(cloud_normal, cloud_light_dir), 0.0);
	float lit = clamp(dome_light * 0.44 + (1.0 - occ) * 0.40 + 0.08, 0.0, 1.0);
	float painted_detail = fbm(cumulus_uv * 3.6 + vec2(13.2, 2.7));
	lit = clamp(lit + (painted_detail - 0.5) * 0.12 * density, 0.0, 1.0);
	float lobe_core = smoothstep(coverage + 0.025, coverage + 0.17, n);
	float inner_billows = cellular_billow(cumulus_uv * 1.58 + vec2(4.1, 9.3));
	lit = clamp(lit + lobe_core * 0.22 + (inner_billows - 0.5) * 0.05 * density, 0.0, 1.0);
	lit -= smoothstep(0.48, 0.95, horizon) * density * 0.16;
	lit = mix(lit, lit * 0.55 + 0.25, u_overcast);

	vec3 cloud_lit = mix(u_cloud_lit_clear, u_cloud_lit_storm, u_overcast);
	vec3 cloud_mid = mix(u_cloud_mid_clear, u_cloud_mid_storm, u_overcast);
	vec3 cloud_shadow = mix(u_cloud_shadow_clear, u_cloud_shadow_storm, u_overcast);
	// Moonlight is cool and restrained: clouds remain readable but do not turn
	// into bright daytime masses that erase the night sky.
	float night_cloud_mix = smoothstep(0.12, 0.82, u_star_visibility);
	cloud_lit = mix(cloud_lit, u_cloud_lit_night, night_cloud_mix);
	cloud_mid = mix(cloud_mid, u_cloud_mid_night, night_cloud_mix);
	cloud_shadow = mix(cloud_shadow, u_cloud_shadow_night, night_cloud_mix);

	// Three controllable paint bands: cool shadow, blue midtone, warm white.
	float shadow_mid_soft = smoothstep(0.12, 0.62, lit);
	float mid_lit_soft = smoothstep(0.42, 0.92, lit);
	float shadow_mid_toon = smoothstep(0.31, 0.39, lit);
	float mid_lit_toon = smoothstep(0.67, 0.75, lit);
	float band_strength = u_toon_banding * clear_sky;
	float shadow_mid = mix(shadow_mid_soft, shadow_mid_toon, band_strength);
	float mid_lit = mix(mid_lit_soft, mid_lit_toon, band_strength);
	vec3 cloud_col = mix(cloud_shadow, cloud_mid, shadow_mid);
	cloud_col = mix(cloud_col, cloud_lit, mid_lit);

	// Warm sun-kissed rim & edge highlight on lit borders facing sun
	float edge_mask = smoothstep(coverage - 0.04, coverage + 0.05, n)
		* (1.0 - smoothstep(coverage + 0.08, coverage + 0.22, n));
	float sun_facing = max(dot(cloud_normal, cloud_light_dir), 0.0);
	float rim = edge_mask * sun_facing;
	cloud_col += warm_sun * (mid_lit * 0.12 + rim * 0.48) * clear_sky * u_solar_intensity;

	// Far clouds dissolve into atmospheric blue instead of becoming stretched
	// opaque lines at the horizon.
	float horizon_haze = 1.0 - smoothstep(0.02, 0.15, horizon);
	cloud_col = mix(cloud_col, sky_col, horizon_haze * 0.42);
	float alpha = density * ceil_mask * mix(0.38, 1.0, 1.0 - horizon_haze);
	COLOR = mix(sky_col, cloud_col, alpha);
}
