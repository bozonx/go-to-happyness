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
uniform float u_sun_disc_energy = 6.0;  // HDR overdrive so filmic tonemap + glow bloom the disc

// --- static art-direction knobs --------------------------------------------
uniform float u_cloud_scale = 1.15;     // bigger = smaller cloud cells
uniform vec2 u_wind = vec2(0.006, 0.002);
uniform float u_edge_softness = 0.10;   // lower = harder, crisp anime cartoon edges
uniform float u_coverage_clear = 0.50;  // threshold when sunny (few clouds)
uniform float u_coverage_storm = 0.14;  // threshold when overcast (full sheet)
uniform float u_shadow_step = 0.055;    // self-shadow march distance
uniform vec3 u_cloud_lit_clear : source_color = vec3(1.0, 0.98, 0.95);
uniform vec3 u_cloud_shadow_clear : source_color = vec3(0.55, 0.64, 0.78);
uniform vec3 u_cloud_lit_storm : source_color = vec3(0.55, 0.58, 0.63);
uniform vec3 u_cloud_shadow_storm : source_color = vec3(0.26, 0.29, 0.34);

// --- anime-specific controls -----------------------------------------------
uniform float u_cirrus_amount : hint_range(0.0, 1.0) = 0.4; // high streaky wind clouds
uniform float u_toon_banding : hint_range(0.0, 1.0) = 0.75; // 0 = linear lerp, 1 = sharp anime steps

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

// Domain-warped density -> rounded billowy "cauliflower" anime cumulus lobes.
float cloud_field(vec2 uv) {
	vec2 q = vec2(fbm(uv * 0.75 + vec2(0.0, 0.0)), fbm(uv * 0.75 + vec2(5.2, 1.3)));
	vec2 r = vec2(fbm(uv + 1.15 * q + vec2(1.7, 9.2)), fbm(uv + 1.15 * q + vec2(8.3, 2.8)));
	float n = fbm(uv + 1.3 * r);
	return pow(n, 1.1); // slightly accentuate peaks for puffy anime tops
}

// High-altitude cirrus wind streaks layer
float cirrus_field(vec2 uv) {
	vec2 streaked_uv = vec2(uv.x * 0.35 + uv.y * 1.6, uv.y * 3.8);
	float n = fbm(streaked_uv + u_wind * TIME * 0.4);
	return smoothstep(0.52, 0.76, n);
}

void sky() {
	vec3 dir = normalize(EYEDIR);
	float horizon = dir.y;

	// --- base sky gradient ---
	float grad = smoothstep(0.0, 0.65, horizon);
	vec3 sky_col = mix(u_horizon_color, u_zenith_color, grad);

	vec3 sun_dir = LIGHT0_ENABLED ? normalize(LIGHT0_DIRECTION) : vec3(0.0, 1.0, 0.0);

	// Soft sun disc + halo. Fades in storms.
	float sun_amt = max(dot(dir, sun_dir), 0.0);
	float clear_sky = 1.0 - u_overcast;

	// Redden the disc and scattering near horizon.
	float sun_low = 1.0 - smoothstep(0.0, 0.35, sun_dir.y);
	vec3 warm_sun = mix(u_sun_color, u_horizon_glow_color, sun_low);

	// HDR sun disc + layered glow
	float disc = smoothstep(0.9986, 0.99965, sun_amt);
	float inner = pow(sun_amt, 220.0);
	sky_col += warm_sun * disc * u_solar_intensity * u_sun_disc_energy;
	sky_col += warm_sun * inner * 0.6 * u_solar_intensity * u_sun_disc_energy;

	// Mie scattering halo
	float halo_strength = mix(0.14, 0.55, sun_low);
	sky_col += warm_sun * pow(sun_amt, 6.0) * halo_strength * clear_sky * u_solar_intensity;

	// Warm band along horizon at sunrise/sunset
	float horizon_band = pow(1.0 - abs(dir.y), 6.0);
	sky_col += u_horizon_glow_color * horizon_band * sun_low * 0.35 * clear_sky * u_solar_intensity;

	// --- sky projection ---
	float ceil_mask = smoothstep(0.08, 0.34, horizon);
	vec2 uv = dir.xz / max(horizon, 0.16);
	uv = uv * u_cloud_scale + u_wind * TIME;

	// --- High-altitude cirrus streaks layer ---
	if (u_cirrus_amount > 0.001) {
		float cirrus_mask = cirrus_field(uv * 0.85);
		vec3 cirrus_col = mix(u_cloud_lit_clear, sky_col, 0.35);
		float cirrus_alpha = cirrus_mask * u_cirrus_amount * ceil_mask * clear_sky * 0.45;
		sky_col = mix(sky_col, cirrus_col, cirrus_alpha);
	}

	// --- Main cumulus clouds layer ---
	float n = cloud_field(uv);
	float coverage = mix(u_coverage_clear, u_coverage_storm, u_overcast);
	float density = smoothstep(coverage, coverage + u_edge_softness, n);

	// Fake volume / directional self-shadowing
	vec2 sun2d = length(sun_dir.xz) > 0.001 ? normalize(sun_dir.xz) : vec2(0.0, 1.0);
	float occ = 0.0;
	for (int i = 1; i <= 3; i++) {
		float s = cloud_field(uv + sun2d * u_shadow_step * float(i));
		occ += smoothstep(coverage, coverage + u_edge_softness, s);
	}
	occ /= 3.0;
	float lit = clamp(1.0 - occ, 0.0, 1.0);
	lit = mix(lit, lit * 0.55 + 0.25, u_overcast);

	// Anime Toon Stepping for light/shadow
	float continuous_lit = lit;
	float stepped_lit = smoothstep(0.2, 0.5, lit) * 0.5 + smoothstep(0.65, 0.85, lit) * 0.5;
	lit = mix(continuous_lit, stepped_lit, u_toon_banding * clear_sky);

	vec3 cloud_lit = mix(u_cloud_lit_clear, u_cloud_lit_storm, u_overcast);
	vec3 cloud_shadow = mix(u_cloud_shadow_clear, u_cloud_shadow_storm, u_overcast);
	vec3 cloud_col = mix(cloud_shadow, cloud_lit, lit);

	// Warm sun-kissed rim & edge highlight on lit borders facing sun
	float edge_mask = smoothstep(0.01, 0.15, density) * (1.0 - smoothstep(0.35, 0.85, density));
	float rim = pow(sun_amt, 2.5) * edge_mask * lit;
	cloud_col += warm_sun * (lit * 0.18 + rim * 0.4) * clear_sky * u_solar_intensity;

	float alpha = density * ceil_mask;
	COLOR = mix(sky_col, cloud_col, alpha);
}

