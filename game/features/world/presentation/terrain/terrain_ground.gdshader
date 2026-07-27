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
// Indices, therefore nearest. A linearly filtered index is a different material.
uniform sampler2D index_map : filter_nearest, repeat_disable;
uniform sampler2D detail_map : filter_nearest, repeat_disable;

uniform float board_cells = 96.0;
uniform float cell_size = 1.0;
uniform float max_variants = 4.0;
// Metres of world per texture tile.
uniform float tile_size = 2.0;
// How sharply the height map wins over the bilinear weight. Low values fade,
// high values interlock; 0.18 keeps the boundary readable at this camera height.
uniform float blend_sharpness = 0.18;
// 0 keeps authored facets; 1 interpolates the averaged vertex normals. Only
// lighting changes: VERTEX and therefore the rendered silhouette stay intact.
uniform float visual_smoothing : hint_range(0.0, 1.0) = 0.0;

uniform vec3 snow_colour : source_color = vec3(0.88, 0.91, 0.96);
uniform vec3 wear_tint : source_color = vec3(0.52, 0.44, 0.33);

varying vec3 world_position;

void vertex() {
	vec3 smooth_normal = normalize(COLOR.rgb * 2.0 - 1.0);
	NORMAL = normalize(mix(NORMAL, smooth_normal, visual_smoothing));
	world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

// Map coordinate of a cell centre, in the 0..1 space of the two surface maps.
vec2 map_uv_of_cell(vec2 cell) {
	return (cell + vec2(board_cells * 0.5) + vec2(0.5)) / board_cells;
}

void fragment() {
	vec2 tile_uv = world_position.xz / tile_size;

	// Sample positions are cell CENTRES, so the four taps around a fragment are
	// the four columns whose surfaces actually meet at that point.
	vec2 centred = world_position.xz / cell_size - vec2(0.5);
	vec2 base = floor(centred);
	vec2 f = centred - base;

	vec4 samples[4];
	vec4 details[4];
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
		float layer = material_index * max_variants + variant;

		vec4 texel = texture(surface_textures, vec3(tile_uv, layer));
		float bilinear = mix(1.0 - f.x, f.x, offset.x) * mix(1.0 - f.y, f.y, offset.y);

		samples[i] = texel;
		details[i] = detail;
		heights[i] = texel.a;
		weights[i] = bilinear;
		highest = max(highest, texel.a + bilinear);
	}

	// Height-based blend (§7.3): only the taps within `blend_sharpness` of the
	// tallest contribution survive, so the seam follows the texture's own relief.
	vec3 albedo = vec3(0.0);
	vec3 detail_sum = vec3(0.0);
	float total = 0.0;
	for (int i = 0; i < 4; i++) {
		float weight = max(heights[i] + weights[i] - highest + blend_sharpness, 0.0);
		albedo += samples[i].rgb * weight;
		detail_sum += details[i].gba * weight;
		total += weight;
	}
	albedo /= max(total, 0.0001);
	detail_sum /= max(total, 0.0001);

	float wear = detail_sum.x;                 // 0 .. 1, three stored levels
	float snow = detail_sum.y;                 // 0 .. 1, four stored depths

	// Wear is the ground being rubbed bare: less colour, more soil. Snow lies on
	// top of whatever that ended up being.
	albedo = mix(albedo, wear_tint, wear * 0.45);
	albedo = mix(albedo, snow_colour, smoothstep(0.0, 0.7, snow));

	ALBEDO = albedo;
	ROUGHNESS = mix(0.95, 0.75, snow);
	SPECULAR = 0.15;
}
