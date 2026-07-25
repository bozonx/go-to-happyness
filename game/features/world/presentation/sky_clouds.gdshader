shader_type sky;
render_mode use_debanding;

// Anime & Ghibli-styled procedural sky and clouds.
// Features:
// 1. High-altitude cirrus wind streaks (anime atmospheric lines).
// 2. Multi-stage domain-warped FBM for rounded cumulus "cauliflower" lobes.
// 3. Stepped anime toon shading (Highlight, Midtone, Soft Ambient Shadow).
// 4. Directional self-shadowing & warm sun rim highlights on cloud edges.

// --- driven from GDScript ---------------------------------------------------
uniform vec3 u_horizon_color : source_color = vec3(0.56, 0.84, 0.95);
// Middle band of a three-point gradient. The gameplay camera looks down about fifty
// degrees, so the visible sky is roughly dir.y in [0, 0.35]: a two-point gradient
// spends its whole range above the frame and leaves the played band flat. This colour
// is what the player actually sees most of the time.
uniform vec3 u_mid_color : source_color = vec3(0.25, 0.62, 0.89);
uniform vec3 u_zenith_color : source_color = vec3(0.12, 0.39, 0.81);
uniform vec3 u_sun_color : source_color = vec3(1.0, 0.95, 0.82);
uniform vec3 u_horizon_glow_color : source_color = vec3(1.0, 0.52, 0.25); // sunset scatter tint
uniform float u_overcast : hint_range(0.0, 1.0) = 0.0;
uniform float u_solar_intensity : hint_range(0.0, 1.0) = 1.0;
uniform float u_sun_visibility : hint_range(0.0, 1.0) = 1.0;
uniform float u_night_factor : hint_range(0.0, 1.0) = 0.0;
// How close the sun is to the horizon on either side, 1.0 at dawn/dusk. Drives the
// anti-solar twilight bands, which exist only while the sun is just below the horizon.
uniform float u_twilight : hint_range(0.0, 1.0) = 0.0;
uniform float u_star_visibility : hint_range(0.0, 1.0) = 0.0;
uniform float u_star_density : hint_range(0.0, 1.0) = 0.72;
uniform float u_star_twinkle : hint_range(0.0, 1.0) = 0.16;
// Rotation of the whole celestial sphere, in radians, driven by the game clock. The
// star field and the Milky Way are sampled in this rotated frame, so the night sky
// turns slowly around a tilted pole instead of hanging fixed above the settlement.
uniform float u_star_rotation = 0.0;
// Real elapsed seconds, kept separate from u_time. u_time counts game minutes, which
// run tens of times faster than the wall clock: driving the twinkle from it made the
// whole field strobe several times a second instead of breathing.
uniform float u_star_time = 0.0;
// HDR overdrive so the filmic tonemap and glow bloom the disc. Restrained on
// purpose: pushed higher, the bloom swallows the disc's edge and the sun becomes a
// featureless white smear several times its own size.
uniform float u_sun_disc_energy = 2.4;
uniform float u_time = 0.0;
// Direction toward the sun, supplied by GDScript so the disc, the moon phase and the
// screen-space glare all agree on one vector even after the light's energy reaches
// zero at night (where LIGHT0 can no longer be relied upon).
uniform vec3 u_sun_dir = vec3(0.0, 1.0, 0.0);
// Angular radii in radians, driven from GDScript. Both swell noticeably near the
// horizon: the stylised "moon illusion" that makes sunrise and moonrise read as
// events rather than as a dot crossing the sky.
uniform float u_sun_angular_radius = 0.046;
uniform float u_moon_angular_radius = 0.060;
// Disc presence is separate from illumination energy. The old shader multiplied the
// disc by u_solar_intensity, which fades to zero exactly at the horizon and erased
// the sun during the golden hour.
uniform float u_sun_disc_visibility : hint_range(0.0, 1.0) = 1.0;
// Scattering energy that survives twilight, so halos and the horizon band stay lit
// while the sun sits on the horizon.
uniform float u_sky_light_energy : hint_range(0.0, 1.0) = 1.0;
// Brightness the unlit side of the moon keeps. Deliberately high: the phase is a
// painterly cue here, never a real eclipse of half the disc.
uniform float u_moon_earthshine : hint_range(0.0, 1.0) = 0.38;
// How much of the disc the sun lights, as the cosine-like axis of the phase:
// +1 full, 0 half, -1 new. Authored from the synodic cycle rather than measured
// from the arcs, because both bodies here travel a narrow band of azimuths where
// the true elongation never leaves "almost full".
uniform float u_moon_phase_axis : hint_range(-1.0, 1.0) = 1.0;
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
// Integrated wind displacement supplied by the deterministic weather clock.
// Keeping displacement separate from the current wind vector prevents cloud jumps
// when a new daily bearing or a new wind strength blends in.
uniform vec2 u_wind_offset = vec2(0.0);
uniform vec2 u_wind_direction = vec2(1.0, 0.0);
uniform float u_edge_softness = 0.07;   // lower = harder, crisp anime cartoon edges
uniform float u_coverage_clear = 0.46;  // threshold when sunny (few clouds)
uniform float u_coverage_storm = 0.18;  // threshold when overcast (full sheet)
uniform float u_cumulus_amount : hint_range(0.0, 1.0) = 1.0;
uniform float u_elongated_amount : hint_range(0.0, 1.0) = 0.0;
uniform float u_storm_amount : hint_range(0.0, 1.0) = 0.0;
// Grey, flat "murk" atmosphere. Decoupled from cloud coverage: broken fair-weather
// clouds keep a saturated blue sky, and the grey haze/darkening only arrives with a
// storm front (or an almost fully sealed ceiling). Drives all desaturation.
uniform float u_murk : hint_range(0.0, 1.0) = 0.0;
// Slow morph clock so cloud silhouettes form and dissolve over time instead of only
// scrolling rigidly with the wind.
uniform float u_cloud_evolve = 0.0;
uniform float u_shadow_step = 0.055;    // self-shadow march distance
// Anime contrast comes from the sky being saturated while the cloud body is almost
// colourless: the midtone is nearly white, and all of the cloud's chroma is spent in
// a small, deeply cool shadow. Painting the midtone blue, as before, put the cloud in
// the same pastel family as the sky and flattened the whole frame.
uniform vec3 u_cloud_lit_clear : source_color = vec3(1.0, 0.985, 0.95);
// Far enough below the lit band to be a distinct step — at 0.90 it was so close to
// white that the three paint bands collapsed into two and cloud interiors went flat —
// but still nearly neutral, so the body does not drift back toward sky blue.
uniform vec3 u_cloud_mid_clear : source_color = vec3(0.815, 0.862, 0.94);
uniform vec3 u_cloud_shadow_clear : source_color = vec3(0.50, 0.58, 0.84);
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
	// A slowly wandering warp makes the cauliflower masses swell and erode over time
	// instead of sliding past as a rigid printed sheet.
	vec2 evolve = vec2(u_cloud_evolve, u_cloud_evolve * 0.63);
	vec2 q = vec2(
		fbm(uv * 0.68 + evolve),
		fbm(uv * 0.68 + vec2(5.2, 1.3) - evolve * 0.5)
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

// High-altitude cirrus. Painted as fibres rather than as a smear: a sparse family
// mask puts them in a few bands of the sky instead of everywhere, a cross-wind warp
// bends each band into the hooked "mare's tail" that makes cirrus recognisable, and a
// narrow density window keeps the individual strands crisp. The previous version was
// one wide-windowed noise stretched along the wind, which read as blur, not as cloud.
float cirrus_field(vec2 uv, float amount) {
	vec2 wind_axis = normalize(u_wind_direction);
	vec2 cross_axis = vec2(-wind_axis.y, wind_axis.x);
	vec2 wind_uv = vec2(dot(uv, wind_axis), dot(uv, cross_axis));
	float evolve = u_cloud_evolve * 0.8;
	// Which parts of the sky carry cirrus at all. Long along the wind, narrow across
	// it, so the answer is bands rather than blobs.
	float family_seed = fbm(vec2(wind_uv.x * 0.16, wind_uv.y * 0.62) + vec2(31.0, 7.0) + evolve * 0.5);
	float family = smoothstep(0.44, 0.70, family_seed);
	if (family <= 0.001) {
		return 0.0;
	}
	// The warp is sampled at a lower frequency than the fibres it displaces, which is
	// what curves whole groups of strands together instead of jittering each one.
	float warp = fbm(vec2(wind_uv.x * 0.30, wind_uv.y * 0.85) + vec2(5.0, 2.0) + evolve);
	vec2 fibre_uv = vec2(
		wind_uv.x * 0.30 + (warp - 0.5) * 1.5,
		wind_uv.y * 6.2 + (warp - 0.5) * 2.6
	);
	float strands = fbm(fibre_uv);
	float fine = fbm(fibre_uv * vec2(1.35, 2.15) + vec2(17.0, 3.0));
	float body = strands * 0.70 + fine * 0.30;
	// Denser weather thickens the strands by lowering the threshold; the window itself
	// stays narrow so they never turn back into a wash.
	float dissolve_threshold = mix(0.60, 0.45, smoothstep(0.06, 1.0, amount));
	float mask = smoothstep(dissolve_threshold, dissolve_threshold + 0.11, body);
	// Feathered along the wind: cirrus fades out at the trailing end of a band rather
	// than stopping at an edge.
	float feather = smoothstep(0.0, 0.35, family);
	return mask * feather;
}

// Thin, elongated mid-altitude islands. Unlike cirrus they retain a soft body,
// but their stretched coordinate frame prevents them from reading as another
// family of round cumulus puffs.
float elongated_cloud_field(vec2 uv, float amount) {
	vec2 wind_axis = normalize(u_wind_direction);
	vec2 cross_axis = vec2(-wind_axis.y, wind_axis.x);
	vec2 wind_uv = vec2(dot(uv, wind_axis), dot(uv, cross_axis));
	// Thinner across the wind and broken up harder than before: at a low cross-wind
	// frequency with a wide density window these came out as flat round blobs, which
	// the near-white cloud palette then turned into paper cut-outs.
	vec2 stretched = vec2(wind_uv.x * 0.26 + wind_uv.y * 0.16, wind_uv.y * 2.60);
	vec2 ev = vec2(u_cloud_evolve * 0.5, u_cloud_evolve * 0.3);
	float family = fbm(uv * 0.20 + vec2(8.0, 17.0) + ev);
	float family_mask = smoothstep(0.48, 0.68, family);
	float broad = fbm(stretched * 0.72 + vec2(14.0, 3.0) + ev);
	float breakup = fbm(stretched * 1.48 + vec2(2.0, 11.0) - ev);
	float ribbons = broad * 0.70 + breakup * 0.30;
	float dissolve_threshold = mix(0.54, 0.32, smoothstep(0.06, 1.0, amount));
	return smoothstep(dissolve_threshold, dissolve_threshold + 0.14, ribbons)
		* mix(0.55, 1.0, family_mask);
}

// --- night sky ---------------------------------------------------------------
// The celestial pole the sky turns around. Tilted, so the rotation reads as an arc
// across the night rather than as a pinwheel overhead.
// All three are authored unit length, so the rotation and the dot products below need
// no normalisation at runtime.
// The pole sits low, about twenty-five degrees up. With it overhead the sky turned
// like a pinwheel — stars near the zenith crawling, stars at the horizon racing — and
// read as every star drifting on its own. Low, the whole visible dome slides one way.
const vec3 CELESTIAL_POLE = vec3(0.556, 0.424, 0.715);
// Great circle of the Milky Way, and the direction of its bright core.
const vec3 MILKY_WAY_AXIS = vec3(0.82, 0.24, 0.52);
const vec3 MILKY_WAY_CORE = vec3(-0.46, 0.34, 0.82);
const float STAR_GRID = 40.0;

vec3 rotate_about(vec3 v, vec3 axis, float angle) {
	float c = cos(angle);
	float s = sin(angle);
	return v * c + cross(axis, v) * s + axis * dot(axis, v) * (1.0 - c);
}

// Cube-face parameterisation of a direction. The old star field projected dir.xz by
// dir.y, which sheared every star toward the horizon and pinned the field to the
// world. A cube map has no pole singularity, so stars stay round wherever they are
// and the whole sphere can be rotated as one.
vec3 cube_face_coords(vec3 d) {
	vec3 a = abs(d);
	if (a.x >= a.y && a.x >= a.z) {
		return vec3(vec2(d.z, d.y) / a.x, d.x > 0.0 ? 0.0 : 1.0);
	}
	if (a.y >= a.z) {
		return vec3(vec2(d.x, d.z) / a.y, d.y > 0.0 ? 2.0 : 3.0);
	}
	return vec3(vec2(d.x, d.y) / a.z, d.z > 0.0 ? 4.0 : 5.0);
}

// One grid, but every star draws a magnitude from a steep power curve. That single
// curve produces the hierarchy a hand-painted sky has — a wash of faint pinpricks, a
// scattering of medium ones, a handful of bright anchors — and radius, twinkle and
// diffraction all follow from it, instead of being tuned per layer.
vec3 star_field(vec3 rotated_dir) {
	vec3 face = cube_face_coords(rotated_dir);
	// Offsetting per face decorrelates the six grids, so the seams carry no pattern.
	vec2 uv = face.xy * STAR_GRID + vec2(face.z * 37.3, face.z * 17.9);
	// Size of one pixel in grid units. A star drawn smaller than a pixel cannot be
	// resolved: it flickers on and off as the sky rotates it across the sampling grid.
	// Measured on the face coordinates, which are continuous inside a face; the clamp
	// discards the spikes at the face seams and behind the camera.
	float pixel = clamp(length(fwidth(face.xy)) * STAR_GRID, 0.0, 0.5);
	vec2 cell = floor(uv);
	vec2 local = fract(uv) - 0.5;
	float seed = hash21(cell);
	float threshold = mix(0.955, 0.865, u_star_density);
	if (seed < threshold) {
		return vec3(0.0);
	}
	// Kept inside the cell so a star near an edge is never clipped in half.
	vec2 point = (vec2(hash21(cell + 3.1), hash21(cell + 9.7)) - 0.5) * 0.84;
	float mag = pow(hash21(cell + vec2(5.3, 1.9)), 5.0);
	float radius = mix(0.011, 0.034, mag);
	float brightness = mix(0.14, 1.0, mag);
	// Only the bright stars are allowed to breathe, and slowly: a whole field of
	// twinkling pinpricks reads as noise rather than as a sky.
	float twinkle = 1.0 + sin(u_star_time * 0.6 + seed * 31.0) * u_star_twinkle * mag * mag;
	vec2 offset = local - point;
	float distance_to_star = length(offset);
	// Never drawn thinner than a pixel, and dimmed by the *area* it had to be spread
	// over, so the light it contributes stays put as the sky turns. This is what stops
	// the field from scintillating. Conserving it linearly instead inflated every
	// sub-pixel star into a visible blob and turned the sky back into uniform noise.
	float draw_radius = max(radius, pixel * 0.8);
	float spread = radius / draw_radius;
	float energy = spread * spread;
	float star = 1.0 - smoothstep(draw_radius * 0.45, draw_radius * 2.6, distance_to_star);
	// A faint diffraction cross on the few brightest stars. It is what makes an
	// anchor star read as a star rather than as a dot, and it costs two smoothsteps.
	float cross_amount = smoothstep(0.62, 1.0, mag);
	if (cross_amount > 0.001) {
		// The arms are kept a pixel thick for the same reason as the disc.
		float arm = draw_radius * 7.0;
		float arm_width = draw_radius * 0.9;
		float horizontal = (1.0 - smoothstep(0.0, arm, abs(offset.x))) * (1.0 - smoothstep(0.0, arm_width, abs(offset.y)));
		float vertical = (1.0 - smoothstep(0.0, arm, abs(offset.y))) * (1.0 - smoothstep(0.0, arm_width, abs(offset.x)));
		star += (horizontal + vertical) * cross_amount * 0.32;
	}
	// Per-star colour temperature: a few warm amber stars among cool blue-white
	// ones keep the field from looking like uniform pixels.
	float ctemp = hash21(cell + vec2(4.7, 12.3));
	vec3 tint = mix(vec3(1.0, 0.82, 0.66), vec3(0.72, 0.83, 1.0), smoothstep(0.0, 0.65, ctemp));
	return tint * star * energy * brightness * twinkle;
}

// Seam-free noise over a direction: two planar projections averaged. A single
// projection (or an atan-based one) leaves a visible meridian through the band.
float sphere_noise(vec3 d, float scale, vec2 offset) {
	return (fbm(d.xy * scale + offset) + fbm(d.zy * scale + offset.yx + vec2(11.0, 2.0))) * 0.5;
}

// A mottled band rather than a smooth smear: bright clumps of unresolved stars, and
// dark dust rifts multiplied through them. The rifts are what make it read as the
// Milky Way instead of as a soft glow across the sky.
vec3 milky_way(vec3 rotated_dir) {
	float band = 1.0 - smoothstep(0.0, 0.32, abs(dot(rotated_dir, MILKY_WAY_AXIS)));
	if (band <= 0.001) {
		return vec3(0.0);
	}
	band = pow(band, 1.7);
	float coarse = sphere_noise(rotated_dir, 4.6, vec2(3.0, 7.0));
	float fine = sphere_noise(rotated_dir, 10.4, vec2(21.0, 5.0));
	float clumps = smoothstep(0.34, 0.76, coarse * 0.68 + fine * 0.32);
	float rifts = smoothstep(0.28, 0.58, sphere_noise(rotated_dir, 2.4, vec2(9.0, 15.0)));
	float density = band * (0.22 + clumps * 0.95) * mix(0.18, 1.0, rifts);
	// The core is denser and warmer, which gives the band a direction to read along.
	float core = smoothstep(0.45, 0.98, dot(rotated_dir, MILKY_WAY_CORE));
	vec3 tint = mix(vec3(0.40, 0.48, 0.74), vec3(0.74, 0.63, 0.55), core * 0.75);
	return tint * density * (1.0 + core * 0.85);
}

void sky() {
	vec3 dir = normalize(EYEDIR);
	float horizon = dir.y;

	// --- base sky gradient ---
	// Three points, with the first transition deliberately low: the pale horizon
	// colour is spent within the first ten degrees, so the band the gameplay camera
	// actually frames is the saturated middle blue, and the deep zenith is reserved
	// for the top of the sky where it belongs.
	float low_grad = smoothstep(0.0, 0.22, horizon);
	float high_grad = smoothstep(0.18, 0.70, horizon);
	vec3 sky_col = mix(u_horizon_color, u_mid_color, low_grad);
	sky_col = mix(sky_col, u_zenith_color, high_grad);

	// --- atmospheric horizon haze / morning fog ---
	// A soft band hugs the horizon; a slow drifting low-frequency noise breaks it
	// into banks of mist rather than a flat gradient, so the dawn haze reads as
	// ground fog. Densest right at the horizon, thinning upward.
	float fog_profile = pow(1.0 - clamp(horizon / 0.55, 0.0, 1.0), 2.2);
	float fog_tex = fbm(dir.xz / max(horizon + 0.32, 0.32) * 2.3 + u_wind_offset * 4.0);
	float fog_amount = fog_profile * u_haze_strength * (0.62 + fog_tex * 0.7);
	sky_col = mix(sky_col, u_haze_color, clamp(fog_amount, 0.0, 1.0));

	float star_visibility = u_star_visibility * (1.0 - smoothstep(0.30, 0.86, u_overcast) * 0.94);

	// Stars and the Milky Way share one slowly turning celestial frame, so they hold
	// their positions relative to each other while the sky rotates through the night.
	vec3 star_dir = rotate_about(dir, CELESTIAL_POLE, u_star_rotation);

	sky_col += milky_way(star_dir) * smoothstep(0.05, 0.36, horizon) * star_visibility * 0.14;

	// Individual clouds mask stars later in the final sky blend. Keep a small
	// global contribution at partial cover so stars remain visible through gaps.
	vec3 stars = star_field(star_dir) * smoothstep(0.04, 0.32, horizon);
	sky_col += stars * star_visibility * 2.5;

	vec3 sun_dir = normalize(u_sun_dir);
	if (dot(u_sun_dir, u_sun_dir) < 0.001) {
		sun_dir = LIGHT0_ENABLED ? normalize(LIGHT0_DIRECTION) : vec3(0.0, 1.0, 0.0);
	}

// A crisp painted disc plus its atmospheric glow. The disc edge is built in angle
// space rather than in cosine space, so it stays equally sharp at any radius; the
// previous cosine threshold spread the edge over three degrees and turned the sun
// into a soft white blot.
	float sun_amt = max(dot(dir, sun_dir), 0.0);
	float sun_angle = acos(clamp(dot(dir, sun_dir), -1.0, 1.0));
	// "Clear" for warm light / halos / toon crispness is about murk, not cloud count:
	// a sky full of fair-weather cumulus still catches golden sunset light.
	float clear_sky = 1.0 - u_murk;

	// Redden the disc and scattering near horizon. A gentle curve pushes the disc
	// into gold sooner as the sun drops, so sunrise/sunset read warm without the
	// noon sun turning a sickly yellow.
	// The gold arrives well before the sun reaches the horizon. A tighter window made
	// the golden hour read as a white blowout with a thin warm line under it.
	float sun_low = 1.0 - smoothstep(0.0, 0.50, sun_dir.y);
	float sun_gold = pow(sun_low, 0.7);
	vec3 warm_sun = mix(u_sun_color, u_horizon_glow_color, sun_gold);

	// The disc keeps one flat body so it never becomes a white smear: noon burns
	// close to white, and the low sun holds a saturated gold. HDR energy is what
	// blooms it through the environment's glow pass.
	float sun_edge = u_sun_angular_radius * 0.06;
	float sun_disc = 1.0 - smoothstep(u_sun_angular_radius - sun_edge, u_sun_angular_radius + sun_edge, sun_angle);
	vec3 disc_color = mix(warm_sun, vec3(1.0, 0.985, 0.94), 0.45 * (1.0 - sun_gold));
	// The low sun is also a dimmer sun. At full noon energy every channel of a gold
	// disc clears the tonemap's shoulder and the sunset hands back a white dot.
	float disc_energy = u_sun_disc_energy * mix(1.0, 0.52, sun_gold);
	sky_col += disc_color * sun_disc * u_sun_disc_visibility * disc_energy * u_sun_visibility;
	// A tight corona hugging the rim keeps the hard edge from looking cut out,
	// without inflating the disc itself.
	float corona = exp(-max(sun_angle - u_sun_angular_radius, 0.0) / (u_sun_angular_radius * 0.28));
	corona *= 1.0 - sun_disc;
	sky_col += warm_sun * corona * 0.45 * u_sun_disc_visibility * u_sun_visibility * clear_sky;

	// Mie scattering halo — broader and warmer when the sun sits low. Driven by the
	// twilight-aware energy so the golden hour keeps its glow after the direct light
	// curve has already reached zero.
	float halo_strength = mix(0.15, 0.72, sun_low);
	float halo_visibility = mix(0.25, 1.0, u_sun_visibility);
	sky_col += warm_sun * pow(sun_amt, 6.0) * halo_strength * clear_sky * u_sky_light_energy * halo_visibility;
	// A soft wide golden bloom hugging the low sun adds the anime sunrise glow. Kept
	// modest: as an additive term it raises luminance faster than chroma, and pushed
	// harder it turns the whole golden hour into a white blowout under the tonemap.
	sky_col += warm_sun * pow(sun_amt, 2.2) * sun_low * 0.08 * clear_sky * u_sky_light_energy * halo_visibility;

	// Warm band along horizon at sunrise/sunset. Weighted by azimuth: the warm zone
	// belongs around the sun, and the far side of the sky must stay blue or lilac.
	// An unweighted band, as before, wrapped the whole horizon in sunset at once and
	// left the dusk with no direction in it.
	vec2 view_bearing = length(dir.xz) > 0.001 ? normalize(dir.xz) : vec2(1.0, 0.0);
	vec2 sun_bearing = length(sun_dir.xz) > 0.001 ? normalize(sun_dir.xz) : vec2(1.0, 0.0);
	float toward_sun = dot(view_bearing, sun_bearing);
	float solar_side = smoothstep(-0.35, 0.85, toward_sun);
	// Mixed in rather than added: the warm zone has to become orange, not merely
	// brighter. Adding it lifted the luminance into the tonemap's shoulder, where the
	// sunset lost its colour exactly where it was strongest.
	float horizon_band = pow(1.0 - abs(dir.y), 4.5);
	float warm_band = horizon_band * sun_low * solar_side * clear_sky * u_sky_light_energy;
	sky_col = mix(sky_col, u_horizon_glow_color, clamp(warm_band * 1.35, 0.0, 1.0));

	// --- anti-solar twilight: the Earth's shadow and the Belt of Venus ---
	// Opposite a setting sun the planet's own shadow rises as a dusty blue-grey wedge,
	// with a band of pink scatter riding on top of it. It is the single most
	// recognisable thing about dusk and costs only two height windows.
	float anti_solar = smoothstep(0.15, -0.65, toward_sun);
	float twilight_band = u_twilight * anti_solar * clear_sky;
	if (twilight_band > 0.001) {
		float earth_shadow = 1.0 - smoothstep(0.0, 0.095, horizon);
		float venus_belt = smoothstep(0.03, 0.115, horizon) * (1.0 - smoothstep(0.115, 0.30, horizon));
		sky_col = mix(sky_col, vec3(0.17, 0.21, 0.36), earth_shadow * twilight_band * 0.60);
		sky_col += vec3(1.0, 0.60, 0.64) * venus_belt * twilight_band * 0.26;
	}

	// --- night moon ---
	// A soft disc opposite the sun, with a tight inner glow and a faint wide halo.
	// The surface is procedural: no texture sampler, just FBM "maria" and a gentle
	// spherical shade. Gated by u_moon_energy so it only appears after dusk.
	if (u_moon_energy > 0.001) {
		vec3 moon_dir = normalize(u_moon_dir);
		float moon_angle = acos(clamp(dot(dir, moon_dir), -1.0, 1.0));
		float moon_edge = u_moon_angular_radius * 0.05;
		float moon_disc = 1.0 - smoothstep(u_moon_angular_radius - moon_edge, u_moon_angular_radius + moon_edge, moon_angle);
		// Disc-local coordinates via a tangent frame around the moon direction.
		// dot(dir, tangent) ~= the small angular offset, so muv spans [-1,1] across
		// the disc once divided by its angular radius.
		vec3 moon_t = normalize(cross(moon_dir, vec3(0.0, 1.0, 0.0)));
		vec3 moon_b = cross(moon_dir, moon_t);
		vec2 muv = vec2(dot(dir, moon_t), dot(dir, moon_b)) / u_moon_angular_radius;
		float mr = min(length(muv), 1.0);
		// Dark maria patches plus a whisper of finer relief. The face is painted
		// flat: brightening the centre for "volume" is what made the moon read as a
		// glowing ball instead of the flat disc a painted sky wants.
		float maria = fbm(muv * 1.5 + vec2(4.0, 2.0));
		float relief = fbm(muv * 5.5 + vec2(11.0, 7.0));
		float surface = 1.0 - smoothstep(0.52, 0.74, maria) * 0.45;
		surface -= (relief - 0.5) * 0.14;
		surface = clamp(surface, 0.42, 1.0);
		// Phase. Which way the terminator faces is taken from where the sun actually
		// is, so the crescent can never point away from it; how much of the disc is
		// lit comes from the synodic cycle.
		float sphere_z = sqrt(max(1.0 - mr * mr, 0.0));
		vec2 sun_in_plane = vec2(dot(sun_dir, moon_t), dot(sun_dir, moon_b));
		float in_plane_length = length(sun_in_plane);
		vec2 lit_axis = in_plane_length > 0.001 ? sun_in_plane / in_plane_length : vec2(1.0, 0.0);
		float phase_axis = clamp(u_moon_phase_axis, -1.0, 1.0);
		float lit_dot = dot(muv, lit_axis) * sqrt(max(1.0 - phase_axis * phase_axis, 0.0))
			+ sphere_z * phase_axis;
		// A soft terminator keeps the shading painterly, and the earthshine floor
		// means the unlit limb stays clearly visible at every phase.
		float phase_lit = smoothstep(-0.13, 0.19, lit_dot);
		float face_light = mix(u_moon_earthshine, 1.0, phase_lit);
		// The shadowed limb also cools rather than only darkening, which is what makes
		// the phase read at this low a contrast.
		vec3 shaded_tint = mix(vec3(0.72, 0.80, 1.06), vec3(1.0), phase_lit);
		vec3 moon_face = u_moon_color * surface * face_light * shaded_tint;
		// Two tight glow terms. The old broad pow(moon_amt, 7.0) term only fell to
		// half its value twenty-five degrees out, wrapping the moon in a haze the
		// size of a quarter of the sky.
		float moon_glow = exp(-max(moon_angle - u_moon_angular_radius, 0.0) / (u_moon_angular_radius * 0.5)) * 0.22;
		moon_glow += exp(-moon_angle / (u_moon_angular_radius * 3.4)) * 0.05;
		moon_glow *= 1.0 - moon_disc;
		sky_col += (moon_face * moon_disc * 2.4 + u_moon_color * moon_glow) * u_moon_energy * clear_sky;
	}

	// --- sky projection ---
	// Adding a height offset instead of clamping the denominator keeps the
	// projection continuous. This prevents long horizontal bands near the
	// horizon while preserving the feeling of a cloud ceiling.
	float ceil_mask = smoothstep(0.02, 0.10, horizon);
	vec2 projected_uv = dir.xz / max(horizon + 0.28, 0.28);
	vec2 uv = projected_uv * u_cloud_scale + u_wind_offset;

	// --- High-altitude cirrus streaks layer ---
	if (u_cirrus_amount > 0.001) {
		// Its own, much flatter projection. Sharing the low ceiling map dragged the
		// streaks radially outward from the projection centre, which is what turned
		// them into the fan of smears spreading from the zenith.
		vec2 cirrus_uv = dir.xz / max(horizon + 0.85, 0.85) * u_cloud_scale * 2.6;
		// The highest layer rides the fastest wind.
		cirrus_uv += u_wind_offset * 2.4;
		float cirrus_mask = cirrus_field(cirrus_uv, u_cirrus_amount);
		vec3 cirrus_col = mix(u_cloud_lit_clear, sky_col, 0.28);
		// Cirrus belongs to the daytime blue sky. It fades out through dusk so it
		// never smudges over the night star field, where it only adds noise.
		float cirrus_day = 1.0 - u_night_factor;
		float cirrus_tail_fade = smoothstep(0.0, 0.14, u_cirrus_amount);
		float cirrus_alpha = cirrus_mask * cirrus_tail_fade * ceil_mask * clear_sky * cirrus_day * 0.55;
		sky_col = mix(sky_col, cirrus_col, cirrus_alpha);
	}

	// --- Mid-altitude elongated fair-weather layer ---
	if (u_elongated_amount > 0.001) {
		// Flatter than the cumulus ceiling but not as flat as the cirrus sheet, which
		// keeps the ribbons from fanning radially out of the projection centre.
		vec2 elongated_uv = dir.xz / max(horizon + 0.58, 0.58);
		elongated_uv *= u_cloud_scale * 1.45;
		// Mid-altitude ribbons: medium wind, between the fast cirrus and slow cumulus.
		elongated_uv += u_wind_offset * 1.7;
		float elongated_mask = elongated_cloud_field(elongated_uv, u_elongated_amount);
		// The ribbon interior is lit and its thinning edges keep the cool midtone, so
		// the layer has depth of its own instead of one flat value across every shape.
		float elongated_core = smoothstep(0.18, 0.88, elongated_mask);
		vec3 elongated_day = mix(u_cloud_mid_clear, u_cloud_lit_clear, 0.28 + elongated_core * 0.62);
		// A whisper of grain, for the same reason the cumulus carry painted detail.
		float elongated_grain = fbm(elongated_uv * 3.4 + vec2(7.0, 13.0));
		elongated_day *= 0.95 + elongated_grain * 0.10;
		vec3 elongated_storm = mix(u_cloud_mid_storm, u_cloud_lit_storm, 0.30);
		vec3 elongated_col = mix(elongated_day, elongated_storm, u_murk);
		elongated_col = mix(elongated_col, u_cloud_mid_night, u_night_factor);
		float elongated_sunset = sun_low * (1.0 - u_night_factor) * (1.0 - u_overcast * 0.55);
		elongated_col = mix(elongated_col, warm_sun, elongated_sunset * 0.28);
		float elongated_tail_fade = smoothstep(0.0, 0.14, u_elongated_amount);
		float elongated_alpha = elongated_mask * elongated_tail_fade * ceil_mask;
		// Night keeps only the big cumulus masses readable; thin ribbons all but vanish.
		elongated_alpha *= mix(0.78, 0.05, u_night_factor) * (1.0 - u_storm_amount * 0.72);
		sky_col = mix(sky_col, elongated_col, elongated_alpha);
	}

	// --- Main cumulus clouds layer ---
	// Cumulus remains on its own higher, softer ceiling. The larger height
	// offset removes the horizontal stretching of the old low cloud plane while
	// remaining seamless at the horizon and zenith.
	vec2 cumulus_projected_uv = dir.xz / max(horizon + 0.55, 0.55);
	vec2 cumulus_uv = cumulus_projected_uv * u_cloud_scale * 1.6;
	// Low, heavy cumulus drifts slowest; its body morphs mainly through u_cloud_evolve.
	cumulus_uv += u_wind_offset;
	float projected_n = layered_cloud_field(cumulus_uv);
	vec3 tower_dir = normalize(dir + vec3(u_wind_offset.x * 0.12, 0.0, u_wind_offset.y * 0.12));
	// Towering fair-weather cumulus persist at any coverage; only a storm ceiling
	// dissolves them into the flat sheet.
	float tower_weather = 1.0 - smoothstep(0.55, 0.92, u_storm_amount);
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
	// Layer amount changes the density threshold first, eroding silhouettes from
	// their edges and breaking them into islands. Alpha only fades during the
	// final tail so disappearing clouds retain body instead of becoming ghosts.
	float cumulus_dissolve = pow(1.0 - u_cumulus_amount, 1.4);
	float shape_coverage = coverage + cumulus_dissolve * 0.22;
	float density = smoothstep(shape_coverage, shape_coverage + clear_edge, n_banked);
	density *= smoothstep(0.0, 0.14, u_cumulus_amount);
	// The solid, sealed ceiling belongs to the storm front alone. Fair-weather cover,
	// however high, stays a field of separate cumulus with blue gaps between them.
	float ceiling_amount = smoothstep(0.08, 0.96, u_storm_amount) * 0.94;
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
	// Steeper than before: the gradient of the density field is the only relief these
	// clouds have, and a shallow normal wastes it.
	vec3 cloud_normal = normalize(vec3(-gradient_x * 1.85, 0.94, -gradient_y * 1.85));
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
		occ += smoothstep(shape_coverage, shape_coverage + u_edge_softness, s);
	}
	occ /= 3.0;
	float dome_light = max(dot(cloud_normal, cloud_light_dir), 0.0);
	// Weighted toward the surface normal and away from the constant fill. A small
	// isolated cumulus casts almost nothing onto itself, so when the shading leaned on
	// the self-shadow march its whole body landed above the shadow band and it read as
	// a flat white cut-out. The normal is the one cue every cloud has.
	float dome_strength = mix(0.46, 0.30, u_night_factor);
	float shadow_relief = mix(0.22, 0.10, u_night_factor);
	float ambient_fill = mix(0.10, 0.24, u_night_factor);
	float lit = clamp(dome_light * dome_strength + (1.0 - occ) * shadow_relief + ambient_fill, 0.0, 1.0);
	// Two octaves of painted grain. Perturbing lit just before the toon bands is what
	// makes the band boundaries ragged and hand-drawn instead of geometrically clean.
	float painted_detail = fbm(cumulus_uv * 3.6 + vec2(13.2, 2.7)) * 0.62
		+ fbm(cumulus_uv * 7.8 + vec2(2.4, 19.6)) * 0.38;
	float detail_strength = mix(0.15, 0.04, u_night_factor);
	lit = clamp(lit + (painted_detail - 0.5) * detail_strength * density, 0.0, 1.0);
	float lobe_core = smoothstep(shape_coverage + 0.025, shape_coverage + 0.17, n);
	float inner_billows = cellular_billow(cumulus_uv * 1.58 + vec2(4.1, 9.3));
	// A finer billow family carves sub-lobes inside the big cauliflower masses, so a
	// cloud reads as a cluster of rounded bulges rather than as one smooth dome.
	float fine_billows = cellular_billow(cumulus_uv * 2.95 + vec2(21.0, 5.4));
	float lobe_light = mix(0.16, 0.055, u_night_factor);
	float fine_lobe_strength = mix(0.085, 0.03, u_night_factor);
	lit = clamp(
		lit + lobe_core * lobe_light
			+ (inner_billows - 0.5) * 0.055 * density
			+ (fine_billows - 0.5) * fine_lobe_strength * density,
		0.0,
		1.0
	);
	lit -= smoothstep(0.48, 0.95, horizon) * density * mix(0.08, 0.025, u_night_factor);
	// Only genuine murk flattens the dome shading into a dull ceiling.
	lit = mix(lit, lit * 0.55 + 0.25, u_murk);

	float weather_darkness = max(u_murk, u_storm_amount);
	vec3 cloud_lit = mix(u_cloud_lit_clear, u_cloud_lit_storm, weather_darkness);
	vec3 cloud_mid = mix(u_cloud_mid_clear, u_cloud_mid_storm, weather_darkness);
	vec3 cloud_shadow = mix(u_cloud_shadow_clear, u_cloud_shadow_storm, weather_darkness);
	// Moonlight is cool and restrained: clouds remain readable but do not turn
	// into bright daytime masses that erase the night sky.
	float night_cloud_mix = u_night_factor;
	cloud_lit = mix(cloud_lit, u_cloud_lit_night, night_cloud_mix);
	cloud_mid = mix(cloud_mid, u_cloud_mid_night, night_cloud_mix);
	cloud_shadow = mix(cloud_shadow, u_cloud_shadow_night, night_cloud_mix);

	// Three controllable paint bands: cool shadow, blue midtone, warm white.
	// The bands are pushed down so the near-white midtone owns most of the cloud body
	// and the saturated shadow keeps to a small area under the lobes. A large shadow
	// at this chroma would tint the whole cloud blue again.
	float shadow_mid_soft = smoothstep(0.18, 0.56, lit);
	float mid_lit_soft = smoothstep(0.36, 0.82, lit);
	float shadow_mid_toon = smoothstep(0.28, 0.36, lit);
	float mid_lit_toon = smoothstep(0.56, 0.64, lit);
	float band_strength = u_toon_banding * clear_sky * mix(1.0, 0.18, u_night_factor);
	float shadow_mid = mix(shadow_mid_soft, shadow_mid_toon, band_strength);
	float mid_lit = mix(mid_lit_soft, mid_lit_toon, band_strength);
	vec3 cloud_col = mix(cloud_shadow, cloud_mid, shadow_mid);
	cloud_col = mix(cloud_col, cloud_lit, mid_lit);

	// Warm sun-kissed rim & edge highlight on lit borders facing sun. Twilight
	// retains cloud illumination after the direct-light curve reaches zero at
	// the horizon, then fades it before deep night.
	float edge_mask = smoothstep(shape_coverage - 0.04, shape_coverage + 0.05, n)
		* (1.0 - smoothstep(shape_coverage + 0.08, shape_coverage + 0.22, n));
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
		sunset_face * mix(0.66, 0.46, u_murk)
	);
	// Restrained by day: the daytime cloud body should stay neutral white, with warmth
	// arriving only as the sun drops.
	float warm_midtone_strength = mix(0.03, 0.12, sun_low);
	cloud_col += warm_sun * (mid_lit * warm_midtone_strength + rim * warm_rim_strength)
		* mix(1.0, 0.58, u_murk) * cloud_sun_energy;

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
