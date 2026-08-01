shader_type spatial;
render_mode cull_disabled, diffuse_burley, specular_schlick_ggx, depth_draw_never;

// The surface of one water body (design_docs/core/grid_terrain_system.md §9.5, §9.6).
//
// One shader for every kind of liquid the game has. Sea, river, lake, pond and
// lava differ by the uniforms below, which come straight off `WaterBody`, and ice
// is a STATE of the same surface rather than a second material: freezing flips
// `frozen` and nothing else — no remesh, no new geometry, exactly as §9.6 asks.
//
// Waves are amplitude × wind, and the wind is the global one every other
// weather-driven system already reads (§9.5). That is why the sea storms during a
// thunderstorm without a single new state anywhere.
//
// The mesh carries what varies per cell in COLOR:
//   r — depth in metres, for the shallow-to-deep gradient and the alpha ramp;
//   g — distance to the nearest dry cell, 0 at the bank and 1 well offshore.
// Both are baked at mesh time because both are derived from data that only
// changes when an author edits, and the fragment must not read the height field.

uniform vec3 water_colour : source_color = vec3(0.13, 0.32, 0.45);
uniform vec3 deep_colour : source_color = vec3(0.03, 0.11, 0.19);
uniform vec3 foam_colour : source_color = vec3(0.88, 0.94, 0.97);
uniform vec3 ice_colour : source_color = vec3(0.74, 0.85, 0.92);
uniform vec3 emission_colour : source_color = vec3(0.0, 0.0, 0.0);

// Metres of wave, before the wind multiplier.
uniform float wave_amplitude = 0.05;
// Wind, as the weather state reports it: a direction on the board and a 0–1
// strength. Waves and foam both scale with it (§9.5).
uniform vec2 wind_direction = vec2(1.0, 0.0);
uniform float wind_strength = 0.4;
uniform float foam_strength = 0.4;
// Depth in metres at which the water reads as fully deep.
uniform float depth_fade = 2.0;
// Width of the shore band in metres.
uniform float shore_width = 1.2;
uniform float opacity = 0.82;
// 0 open water, 1 ice. A state of the cell, not a different material (§9.6).
uniform float frozen = 0.0;
// Lava does not fade with depth and lights its own banks.
uniform float emission_energy = 0.0;
uniform float roughness_value = 0.06;

varying float depth_metres;
varying float shore_distance;
varying vec3 world_position;
varying float flow_direction_index;
varying float flow_strength;

// Two crossing waves rather than one, so the surface never shows the single
// stripe direction a lone sine gives at this camera angle.
float wave_height(vec2 position, float time) {
	vec2 primary = normalize(wind_direction + vec2(0.0001, 0.0));
	vec2 secondary = vec2(-primary.y, primary.x);
	float a = sin(dot(position, primary) * 1.7 + time * 1.4);
	float b = sin(dot(position, secondary) * 1.1 - time * 0.9);
	return a * 0.6 + b * 0.4;
}

void vertex() {
	depth_metres = COLOR.r;
	shore_distance = COLOR.g;
	flow_direction_index = floor(COLOR.b * 8.0 + 0.5);
	flow_strength = COLOR.a;
	world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	// Ice does not move, and shallow water moves less than deep: a wave with the
	// full amplitude at the bank would lift the surface through the ground.
	float shallow = clamp(depth_metres / max(depth_fade, 0.01), 0.0, 1.0);
	float amplitude = wave_amplitude * clamp(wind_strength, 0.15, 1.0) * shallow * (1.0 - frozen);
	VERTEX.y += wave_height(world_position.xz, TIME) * amplitude;
}

void fragment() {
	float deep = clamp(depth_metres / max(depth_fade, 0.01), 0.0, 1.0);
	vec3 liquid = mix(water_colour, deep_colour, deep);

	// Foam rides the bank, and the wind decides how much of it there is — the same
	// multiplier the waves use, so a calm lake has a clean edge and a storm surf.
	float shore = 1.0 - clamp(shore_distance / max(shore_width, 0.01), 0.0, 1.0);
	float ripple = 0.5 + 0.5 * sin(dot(world_position.xz, normalize(wind_direction + vec2(0.0001, 0.0))) * 3.1 + TIME * 2.2);
	float foam = shore * shore * foam_strength * clamp(wind_strength, 0.2, 1.0) * (0.6 + 0.4 * ripple);
	liquid = mix(liquid, foam_colour, clamp(foam, 0.0, 1.0) * (1.0 - frozen));

	// Authored river flow is rendered as small travelling foam crests.  Each
	// cell supplies its own compass direction and strength, so a bend visibly
	// turns rather than inheriting the weather wind.  The repeated tapered marks
	// read like miniature whitecaps moving down the channel.
	if (flow_strength > 0.01 && frozen < 0.5) {
		float direction_angle = flow_direction_index * 0.78539816339;
		vec2 flow_direction = vec2(sin(direction_angle), -cos(direction_angle));
		vec2 lateral_direction = vec2(-flow_direction.y, flow_direction.x);
		float current_level = flow_strength * 3.0;
		// Deliberately separated speeds: strength 1 is slow, 2 is a clear middle,
		// and 3 is a fast current rather than a tiny linear increment.
		float speed = 0.12;
		if (current_level > 2.1) {
			speed = 1.60;
		} else if (current_level > 1.1) {
			speed = 0.65;
		}
		float along = dot(world_position.xz, flow_direction) - TIME * speed;
		float crest = smoothstep(0.76, 0.96, sin(along * 8.0) * 0.5 + 0.5);
		float taper = 1.0 - smoothstep(0.08, 0.30, abs(fract(along * 1.25) - 0.5));
		float across = abs(fract(dot(world_position.xz, lateral_direction) * 1.2) - 0.5);
		float width = 1.0 - smoothstep(0.10, 0.31, across);
		// This never drops to zero: every flowing cell always retains a readable
		// downstream pattern, with brighter animated crests travelling over it.
		float continuous_ripple = (0.18 + 0.10 * (0.5 + 0.5 * sin(along * 5.0))) * flow_strength;
		float whitecap = continuous_ripple + taper * width * 0.12 * flow_strength + crest * taper * width * (0.16 + flow_strength * 0.45);
		liquid = mix(liquid, foam_colour, whitecap * (1.0 - frozen));
	}

	// Ice: the same surface, opaque, matt and pale, with the water still readable
	// through the thin edges near the bank.
	vec3 solid = mix(ice_colour, ice_colour * 0.82, deep);
	ALBEDO = mix(liquid, solid, frozen);

	float liquid_alpha = mix(0.55, opacity, deep);
	ALPHA = mix(liquid_alpha, 0.97, frozen);
	ROUGHNESS = mix(roughness_value, 0.55, frozen);
	METALLIC = mix(0.1, 0.0, frozen);
	SPECULAR = mix(0.6, 0.35, frozen);
	EMISSION = emission_colour * emission_energy;
}
