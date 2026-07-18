shader_type sky;
render_mode use_debanding;

// Cartoon-realistic procedural clouds.
// Rounded puffy shapes (domain-warped value noise + hard coverage remap) with a
// fake directional self-shadow toward the sun for volume. Weather is a single
// knob: u_overcast (0 = clear puffs, 1 = overcast rain sheet), driven from
// _update_daylight() so it transitions smoothly with the existing weather state.

// --- driven from GDScript ---------------------------------------------------
uniform vec3 u_horizon_color : source_color = vec3(0.47, 0.66, 0.77);
uniform vec3 u_zenith_color : source_color = vec3(0.28, 0.48, 0.66);
uniform vec3 u_sun_color : source_color = vec3(1.0, 0.95, 0.82);
uniform float u_overcast : hint_range(0.0, 1.0) = 0.0;
uniform float u_solar_intensity : hint_range(0.0, 1.0) = 1.0;

// --- static art-direction knobs --------------------------------------------
uniform float u_cloud_scale = 1.6;      // bigger = smaller cloud cells
uniform vec2 u_wind = vec2(0.006, 0.002);
uniform float u_edge_softness = 0.16;   // lower = harder, more cartoon edges
uniform float u_coverage_clear = 0.52;  // threshold when sunny (few clouds)
uniform float u_coverage_storm = 0.14;  // threshold when overcast (full sheet)
uniform float u_shadow_step = 0.055;    // self-shadow march distance
uniform vec3 u_cloud_lit_clear : source_color = vec3(1.0, 0.99, 0.96);
uniform vec3 u_cloud_shadow_clear : source_color = vec3(0.62, 0.68, 0.78);
uniform vec3 u_cloud_lit_storm : source_color = vec3(0.55, 0.58, 0.63);
uniform vec3 u_cloud_shadow_storm : source_color = vec3(0.26, 0.29, 0.34);

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

// Domain-warped density -> the rounded "cauliflower" bulges.
float cloud_field(vec2 uv) {
	float warp = fbm(uv * 0.7 + vec2(11.3, 5.7));
	return fbm(uv + warp * 0.6);
}

void sky() {
	vec3 dir = normalize(EYEDIR);
	float horizon = dir.y;

	// --- base sky gradient ---
	float grad = smoothstep(0.0, 0.65, horizon);
	vec3 sky_col = mix(u_horizon_color, u_zenith_color, grad);

	// Direction toward the sun (LIGHT0 is the scene DirectionalLight).
	vec3 sun_dir = LIGHT0_ENABLED ? normalize(-LIGHT0_DIRECTION) : vec3(0.0, 1.0, 0.0);

	// Soft sun disc + halo (subtle; lens flare handles the rest). Fades in storms.
	float sun_amt = max(dot(dir, sun_dir), 0.0);
	float clear_sky = 1.0 - u_overcast;
	sky_col += u_sun_color * pow(sun_amt, 900.0) * u_solar_intensity;
	sky_col += u_sun_color * pow(sun_amt, 8.0) * 0.12 * clear_sky * u_solar_intensity;

	// --- clouds live on a virtual ceiling; project view dir onto it ---
	float ceil_mask = smoothstep(0.02, 0.22, horizon); // hide seam at horizon
	vec2 uv = dir.xz / max(horizon, 0.10);
	uv = uv * u_cloud_scale + u_wind * TIME;

	float n = cloud_field(uv);
	float coverage = mix(u_coverage_clear, u_coverage_storm, u_overcast);
	float density = smoothstep(coverage, coverage + u_edge_softness, n);

	// Fake volume: sample toward the sun; more occlusion there = darker underside.
	vec2 sun2d = length(sun_dir.xz) > 0.001 ? normalize(sun_dir.xz) : vec2(0.0, 1.0);
	float occ = 0.0;
	for (int i = 1; i <= 3; i++) {
		float s = cloud_field(uv + sun2d * u_shadow_step * float(i));
		occ += smoothstep(coverage, coverage + u_edge_softness, s);
	}
	occ /= 3.0;
	float lit = clamp(1.0 - occ, 0.0, 1.0);
	lit = mix(lit, lit * 0.55 + 0.25, u_overcast); // storms are flatter, low contrast

	vec3 cloud_lit = mix(u_cloud_lit_clear, u_cloud_lit_storm, u_overcast);
	vec3 cloud_shadow = mix(u_cloud_shadow_clear, u_cloud_shadow_storm, u_overcast);
	vec3 cloud_col = mix(cloud_shadow, cloud_lit, lit);

	// Warm sun-kissed rim on lit edges (only when sunny).
	cloud_col += u_sun_color * lit * density * 0.18 * clear_sky * u_solar_intensity;

	float alpha = density * ceil_mask;
	COLOR = mix(sky_col, cloud_col, alpha);
}
