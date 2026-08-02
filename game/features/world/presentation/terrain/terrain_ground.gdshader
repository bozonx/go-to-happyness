shader_type spatial;
render_mode cull_back, diffuse_burley, specular_schlick_ggx;

// Top surface of the terrain (design_docs/core/terrain_materials.md §7.2, §7.3).
//
// The fragment takes four taps of the INDEX MAP around its position, unrolls each
// into a layer of the one texture array, and mixes them BY THE HEIGHT MAP in the
// alpha channel rather than by distance. That is what makes grass grow through
// the cracks of stone at a brush boundary instead of producing a muddy gradient.
//
// Two properties of the scheme matter more than the look:
//   * painting a material writes one texel — no remesh, ever (§7.5);
//   * adding a material changes the LENGTH of the layer array and nothing else.
//
// UVs are world XZ, so tops need no UV attribute and the greedy-merged quads of
// the mesher tile seamlessly whatever size they were merged to.

uniform sampler2DArray surface_textures : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2DArray surface_normals : hint_normal, filter_linear_mipmap, repeat_enable;
// Indices, therefore nearest. A linearly filtered index is a different material.
uniform sampler2D index_map : filter_nearest, repeat_disable;
uniform sampler2D detail_map : filter_nearest, repeat_disable;
// Stored material+variant -> packed Texture2DArray layer.
uniform sampler2D layer_lookup_map : filter_nearest, repeat_disable;
uniform sampler2D simple_layer_lookup_map : filter_nearest, repeat_disable;
// Built coverage over the ground (map_editor.md §5.2.1): R is the catalog index,
// G is the coverage's own wear. Indices again, therefore nearest.
uniform sampler2D coverage_map : filter_nearest, repeat_disable;
// One texel per catalog index: RGB the surface colour, A how completely it hides
// the ground. A separate row, so adding a surface changes its LENGTH and nothing else.
uniform sampler2D coverage_palette : filter_nearest, repeat_disable;
uniform float coverage_capacity = 8.0;

uniform float board_cells = 96.0;
uniform float cell_size = 1.0;
uniform float material_count = 14.0;
uniform float variant_capacity = 16.0;
// Metres of world per texture tile.
uniform float tile_size = 2.0;
// How sharply the height map wins over the bilinear weight. Low values fade,
// high values interlock; 0.18 keeps the boundary readable at this camera height.
uniform float blend_sharpness = 0.18;
// Independent visual treatments. Full smoothing replaces normals everywhere;
// edge rounding keeps planes flat and changes only a configurable border band.
uniform float full_smoothing : hint_range(0.0, 1.0) = 0.0;
uniform float edge_rounding : hint_range(0.0, 1.0) = 0.0;
// 0 makes a curved normal transition; 1 makes a constant-width flat bevel.
uniform float edge_bevel : hint_range(0.0, 1.0) = 0.0;

// 0 = Full (Textured + Grass), 1 = Textured, 2 = Matte/Clay, 3 = Simple
uniform float render_mode_idx : hint_range(0.0, 3.0) = 0.0;

uniform vec3 snow_colour : source_color = vec3(0.88, 0.91, 0.96);
uniform vec3 wear_tint : source_color = vec3(0.52, 0.44, 0.33);

varying vec3 world_position;
varying vec3 smooth_view_normal;
varying vec4 bevel_view_0;
varying vec4 bevel_view_1;
varying vec4 bevel_view_2;
varying vec4 bevel_view_3;

void vertex() {
	vec3 smooth_normal = normalize(COLOR.rgb * 2.0 - 1.0);
	smooth_view_normal = normalize(MODELVIEW_NORMAL_MATRIX * smooth_normal);
	bevel_view_0 = vec4(normalize(MODELVIEW_NORMAL_MATRIX * mix(NORMAL, CUSTOM0.xyz, CUSTOM0.w)), CUSTOM0.w);
	bevel_view_1 = vec4(normalize(MODELVIEW_NORMAL_MATRIX * mix(NORMAL, CUSTOM1.xyz, CUSTOM1.w)), CUSTOM1.w);
	bevel_view_2 = vec4(normalize(MODELVIEW_NORMAL_MATRIX * mix(NORMAL, CUSTOM2.xyz, CUSTOM2.w)), CUSTOM2.w);
	bevel_view_3 = vec4(normalize(MODELVIEW_NORMAL_MATRIX * mix(NORMAL, CUSTOM3.xyz, CUSTOM3.w)), CUSTOM3.w);
	world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

// Map coordinate of a cell centre, in the 0..1 space of the two surface maps.
vec2 map_uv_of_cell(vec2 cell) {
	return (cell + vec2(board_cells * 0.5) + vec2(0.5)) / board_cells;
}

// Derivative-built tangent frame keeps the same ground texture and normal map
// attached to horizontal tops and ramps without authoring a second ramp asset.
mat3 cotangent_frame(vec3 normal_world, vec3 position_world, vec2 texture_uv) {
	vec3 dp1 = dFdx(position_world);
	vec3 dp2 = dFdy(position_world);
	vec2 duv1 = dFdx(texture_uv);
	vec2 duv2 = dFdy(texture_uv);
	vec3 dp2_perp = cross(dp2, normal_world);
	vec3 dp1_perp = cross(normal_world, dp1);
	vec3 tangent = dp2_perp * duv1.x + dp1_perp * duv2.x;
	vec3 bitangent = dp2_perp * duv1.y + dp1_perp * duv2.y;
	float inverse_scale = inversesqrt(max(max(dot(tangent, tangent), dot(bitangent, bitangent)), 0.00001));
	return mat3(tangent * inverse_scale, bitangent * inverse_scale, normal_world);
}

void fragment() {
	float edge_mask = floor(UV2.x + 0.0001);
	// UV2 carries the quad's size in CELLS so the four mask bits always own the
	// integer part, whatever `cell_size` the map chose. Back to metres here.
	vec2 dimensions = vec2(fract(UV2.x) * 100.0, UV2.y) * cell_size;
	vec4 edge_enabled = vec4(
		mod(edge_mask, 2.0), mod(floor(edge_mask / 2.0), 2.0),
		mod(floor(edge_mask / 4.0), 2.0), mod(floor(edge_mask / 8.0), 2.0)
	);
	vec4 edge_distances = vec4(UV.y * dimensions.y, (1.0 - UV.x) * dimensions.x, (1.0 - UV.y) * dimensions.y, UV.x * dimensions.x);
	vec4 eligible_distances = edge_distances + (vec4(1.0) - edge_enabled) * 10000.0;
	float eligible_edge_distance = min(min(eligible_distances.x, eligible_distances.y), min(eligible_distances.z, eligible_distances.w));
	float rounding_radius = max(edge_rounding * cell_size * 0.5, 0.0001);
	float rounded_band = 1.0 - smoothstep(0.0, rounding_radius, eligible_edge_distance);
	float bevel_band = 1.0 - step(rounding_radius, eligible_edge_distance);
	// The second closest eligible edge is within the band only at a corner. A
	// normal-only bevel cannot form a credible mitre there, so leave both inside
	// and right-angle corners hard rather than lighting a fake square facet.
	float second_edge_distance = min(
		min(max(eligible_distances.x, eligible_distances.y), max(eligible_distances.x, eligible_distances.z)),
		min(max(eligible_distances.x, eligible_distances.w), min(max(eligible_distances.y, eligible_distances.z), min(max(eligible_distances.y, eligible_distances.w), max(eligible_distances.z, eligible_distances.w))))
	);
	float corner_amount = 1.0 - smoothstep(0.0, rounding_radius, second_edge_distance);
	float corner_fade = 1.0 - corner_amount;
	float edge_band = mix(rounded_band, bevel_band, edge_bevel) * corner_fade * step(0.001, edge_rounding);
	float normal_blend = max(edge_band, full_smoothing);
	vec4 bevel_normal = bevel_view_0;
	float bevel_distance = edge_distances.x + (1.0 - edge_enabled.x) * 10000.0;
	if (edge_distances.y + (1.0 - edge_enabled.y) * 10000.0 < bevel_distance) { bevel_normal = bevel_view_1; bevel_distance = edge_distances.y + (1.0 - edge_enabled.y) * 10000.0; }
	if (edge_distances.z + (1.0 - edge_enabled.z) * 10000.0 < bevel_distance) { bevel_normal = bevel_view_2; bevel_distance = edge_distances.z + (1.0 - edge_enabled.z) * 10000.0; }
	if (edge_distances.w + (1.0 - edge_enabled.w) * 10000.0 < bevel_distance) { bevel_normal = bevel_view_3; }
	vec3 edge_target = mix(smooth_view_normal, bevel_normal.xyz, edge_bevel * bevel_normal.w);
	NORMAL = normalize(mix(NORMAL, edge_target, normal_blend));
	vec2 tile_uv = world_position.xz / tile_size;

	// Sample positions are cell CENTRES, so the four taps around a fragment are
	// the four columns whose surfaces actually meet at that point.
	vec2 centred = world_position.xz / cell_size - vec2(0.5);
	vec2 base = floor(centred);
	vec2 f = centred - base;

	vec4 samples[4];
	vec3 normal_samples[4];
	vec4 details[4];
	vec4 coverages[4];
	float weights[4];
	float heights[4];
	float highest = -1.0;

	for (int i = 0; i < 4; i++) {
		vec2 offset = vec2(float(i & 1), float((i >> 1) & 1));
		vec2 cell = base + offset;
		vec2 uv = map_uv_of_cell(cell);
		float material_index = floor(texture(index_map, uv).r * 255.0 + 0.5);
		vec4 detail = texture(detail_map, uv);
		float variant = floor(detail.r * 15.0 + 0.5);
		vec2 lookup_uv = vec2(
			(variant + 0.5) / variant_capacity,
			(material_index + 0.5) / material_count
		);
		float layer = (render_mode_idx > 2.5)
			? floor(texture(simple_layer_lookup_map, lookup_uv).r * 255.0 + 0.5)
			: floor(texture(layer_lookup_map, lookup_uv).r * 255.0 + 0.5);

		vec4 texel = texture(surface_textures, vec3(tile_uv, layer));
		float bilinear = mix(1.0 - f.x, f.x, offset.x) * mix(1.0 - f.y, f.y, offset.y);

		// The coverage of the same column, resolved to a colour here so the tap
		// blends with its neighbours by the same weights the ground does. A cell
		// with no coverage contributes alpha 0 and changes nothing.
		vec2 coverage_texel = texture(coverage_map, uv).rg;
		float coverage_index = floor(coverage_texel.r * 255.0 + 0.5);
		vec4 coverage_entry = texture(coverage_palette, vec2((coverage_index + 0.5) / coverage_capacity, 0.5));
		coverage_entry.a *= step(0.5, coverage_index);
		// Coverage wears the same way ground does: a rutted road shows its soil.
		coverage_entry.rgb = mix(coverage_entry.rgb, wear_tint, coverage_texel.g * 0.45);

		samples[i] = texel;
		normal_samples[i] = texture(surface_normals, vec3(tile_uv, layer)).rgb;
		details[i] = detail;
		coverages[i] = coverage_entry;
		heights[i] = texel.a;
		weights[i] = bilinear;
		highest = max(highest, texel.a + bilinear);
	}

	// Height-based blend (§7.3): only the taps within `blend_sharpness` of the
	// tallest contribution survive, so the seam follows the texture's own relief.
	vec3 albedo = vec3(0.0);
	vec3 normal_map = vec3(0.0);
	vec3 detail_sum = vec3(0.0);
	vec3 coverage_colour = vec3(0.0);
	float coverage_amount = 0.0;
	float total = 0.0;
	for (int i = 0; i < 4; i++) {
		float weight = max(heights[i] + weights[i] - highest + blend_sharpness, 0.0);
		albedo += samples[i].rgb * weight;
		normal_map += normal_samples[i] * weight;
		detail_sum += details[i].gba * weight;
		coverage_colour += coverages[i].rgb * coverages[i].a * weight;
		coverage_amount += coverages[i].a * weight;
		total += weight;
	}
	albedo /= max(total, 0.0001);
	normal_map = normalize(normal_map / max(total, 0.0001) * 2.0 - 1.0);
	detail_sum /= max(total, 0.0001);
	coverage_colour /= max(coverage_amount, 0.0001);
	coverage_amount /= max(total, 0.0001);

	if (render_mode_idx > 2.5) {
		// Mode 3: Simple - simplified shader textures without normal map noise
		normal_map = vec3(0.0, 0.0, 1.0);
	}

	float wear = detail_sum.x;                 // 0 .. 1, three stored levels
	float snow = detail_sum.y;                 // 0 .. 1, four stored depths
	normal_map = normalize(mix(normal_map, vec3(0.0, 0.0, 1.0), smoothstep(0.0, 0.75, snow)));

	// Wear is the ground being rubbed bare: less colour, more soil. Snow lies on
	// top of whatever that ended up being.
	albedo = mix(albedo, wear_tint, wear * 0.45);
	// Built coverage lies OVER the ground and is a surface in its own right, so it
	// replaces what is under it instead of tinting it — the same rule routing
	// follows when it prices a paved cell without charging the mud beneath.
	albedo = mix(albedo, coverage_colour, coverage_amount);
	albedo = mix(albedo, snow_colour, smoothstep(0.0, 0.7, snow));
	// Large-scale colour drift breaks the remaining repetition without changing
	// material identity or adding another texture lookup.
	if (render_mode_idx < 1.5) {
		float macro_noise = (sin(world_position.x * 0.19 + world_position.z * 0.07)
			+ sin(world_position.z * 0.23 - world_position.x * 0.05)) * 0.5;
		albedo *= 0.98 + macro_noise * 0.025;
	}

	vec3 geometric_world_normal = normalize((INV_VIEW_MATRIX * vec4(NORMAL, 0.0)).xyz);
	vec3 detailed_world_normal = normalize(cotangent_frame(geometric_world_normal, world_position, tile_uv) * normal_map);
	NORMAL = normalize((VIEW_MATRIX * vec4(detailed_world_normal, 0.0)).xyz);

	if (render_mode_idx > 1.5 && render_mode_idx < 2.5) {
		// Mode 2: Matte / Clay - neutral flat surface for inspecting slopes & geometry.
		ALBEDO = vec3(0.42, 0.42, 0.44);
		ROUGHNESS = 0.95;
		SPECULAR = 0.15;
	} else {
		ALBEDO = albedo;
		ROUGHNESS = mix(0.95, 0.75, snow);
		SPECULAR = 0.15;
	}
}
