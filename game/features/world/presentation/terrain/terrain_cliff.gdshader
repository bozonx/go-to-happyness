shader_type spatial;
render_mode cull_back, diffuse_burley, specular_schlick_ggx;

// Vertical faces of class 5–7 (design_docs/core/terrain_materials.md §3, §7.2).
//
// A face is never drawn with the material on top of the column — grass on a sheer
// wall reads as a rendering bug — so the mesher hands each wall vertex the layer
// of its AUTO-ROCK kind, taken from `TerrainMaterialCatalog.cliff_material_of`.
// The layer travels in COLOR.r because it is flat per quad and needs no
// interpolation to be correct.
//
// Triplanar lives in this shader and not as a branch in the ground one: 95% of a
// map is flat ground, and a branch would make every one of those fragments pay
// for a wall it is not.

uniform sampler2DArray surface_textures : source_color, filter_linear_mipmap, repeat_enable;
uniform float tile_size = 2.0;
// Faces are the same textures seen edge-on; a touch darker reads as shadowed rock
// without a second texture set.
uniform float face_shade = 0.86;
uniform float full_smoothing : hint_range(0.0, 1.0) = 0.0;
uniform float edge_rounding : hint_range(0.0, 1.0) = 0.0;
uniform float edge_bevel : hint_range(0.0, 1.0) = 0.0;
// 0 = Textured, 1 = Matte/Clay, 2 = Simple
uniform float render_mode_idx : hint_range(0.0, 2.0) = 0.0;

varying vec3 world_position;
varying vec3 world_normal;
varying vec3 smooth_world_normal;
varying vec3 smooth_view_normal;
varying float layer_index;
varying vec4 bevel_view_0;
varying vec4 bevel_view_1;
varying vec4 bevel_view_2;
varying vec4 bevel_view_3;

void vertex() {
	vec3 smooth_normal = normalize(COLOR.gba * 2.0 - 1.0);
	world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	world_normal = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
	smooth_world_normal = normalize((MODEL_MATRIX * vec4(smooth_normal, 0.0)).xyz);
	smooth_view_normal = normalize(MODELVIEW_NORMAL_MATRIX * smooth_normal);
	bevel_view_0 = vec4(normalize(MODELVIEW_NORMAL_MATRIX * mix(NORMAL, CUSTOM0.xyz, CUSTOM0.w)), CUSTOM0.w);
	bevel_view_1 = vec4(normalize(MODELVIEW_NORMAL_MATRIX * mix(NORMAL, CUSTOM1.xyz, CUSTOM1.w)), CUSTOM1.w);
	bevel_view_2 = vec4(normalize(MODELVIEW_NORMAL_MATRIX * mix(NORMAL, CUSTOM2.xyz, CUSTOM2.w)), CUSTOM2.w);
	bevel_view_3 = vec4(normalize(MODELVIEW_NORMAL_MATRIX * mix(NORMAL, CUSTOM3.xyz, CUSTOM3.w)), CUSTOM3.w);
	layer_index = floor(COLOR.r * 255.0 + 0.5);
}

void fragment() {
	float edge_mask = floor(UV2.x + 0.0001);
	vec2 dimensions = vec2(fract(UV2.x) * 100.0, UV2.y);
	vec4 edge_enabled = vec4(
		mod(edge_mask, 2.0), mod(floor(edge_mask / 2.0), 2.0),
		mod(floor(edge_mask / 4.0), 2.0), mod(floor(edge_mask / 8.0), 2.0)
	);
	vec4 edge_distances = vec4(UV.y * dimensions.y, (1.0 - UV.x) * dimensions.x, (1.0 - UV.y) * dimensions.y, UV.x * dimensions.x);
	vec4 eligible_distances = edge_distances + (vec4(1.0) - edge_enabled) * 10000.0;
	float eligible_edge_distance = min(min(eligible_distances.x, eligible_distances.y), min(eligible_distances.z, eligible_distances.w));
	// Cliff polygons are taller and visually coarser than top cells. Give their
	// bevel twice the reach of the ground band, otherwise the same UI value is
	// almost invisible on rock while already reading clearly on grass.
	float rounding_radius = max(edge_rounding * tile_size * 0.5, 0.0001);
	float rounded_band = 1.0 - smoothstep(0.0, rounding_radius, eligible_edge_distance);
	float bevel_band = 1.0 - step(rounding_radius, eligible_edge_distance);
	float second_edge_distance = min(
		min(max(eligible_distances.x, eligible_distances.y), max(eligible_distances.x, eligible_distances.z)),
		min(max(eligible_distances.x, eligible_distances.w), min(max(eligible_distances.y, eligible_distances.z), min(max(eligible_distances.y, eligible_distances.w), max(eligible_distances.z, eligible_distances.w))))
	);
	float corner_amount = 1.0 - smoothstep(0.0, rounding_radius, second_edge_distance);
	// No fake rounded joint where two eligible edges meet (inside or 90° corner).
	float corner_fade = 1.0 - corner_amount;
	float edge_band = mix(rounded_band, bevel_band, edge_bevel) * corner_fade * step(0.001, edge_rounding);
	float normal_blend = max(edge_band, full_smoothing);
	vec4 bevel_normal = bevel_view_0;
	float bevel_distance = edge_distances.x + (1.0 - edge_enabled.x) * 10000.0;
	if (edge_distances.y + (1.0 - edge_enabled.y) * 10000.0 < bevel_distance) { bevel_normal = bevel_view_1; bevel_distance = edge_distances.y + (1.0 - edge_enabled.y) * 10000.0; }
	if (edge_distances.z + (1.0 - edge_enabled.z) * 10000.0 < bevel_distance) { bevel_normal = bevel_view_2; bevel_distance = edge_distances.z + (1.0 - edge_enabled.z) * 10000.0; }
	if (edge_distances.w + (1.0 - edge_enabled.w) * 10000.0 < bevel_distance) { bevel_normal = bevel_view_3; }
	vec3 edge_target_view = mix(smooth_view_normal, bevel_normal.xyz, edge_bevel * bevel_normal.w);
	NORMAL = normalize(mix(NORMAL, edge_target_view, normal_blend));
	vec3 bevel_world_normal = normalize((INV_VIEW_MATRIX * vec4(bevel_normal.xyz, 0.0)).xyz);
	vec3 edge_target_world = mix(smooth_world_normal, bevel_world_normal, edge_bevel * bevel_normal.w);
	vec3 blend = abs(normalize(mix(world_normal, edge_target_world, normal_blend)));
	// A hard triplanar exponent redraws a polygonal seam in the texture after the
	// lighting normal has been rounded. Relax it only inside the rounded band.
	float triplanar_sharpness = mix(4.0, 1.35, normal_blend);
	blend = pow(blend, vec3(triplanar_sharpness));
	blend /= max(blend.x + blend.y + blend.z, 0.0001);

	vec3 uv = world_position / tile_size;
	vec3 x_plane = texture(surface_textures, vec3(uv.zy, layer_index)).rgb;
	vec3 y_plane = texture(surface_textures, vec3(uv.xz, layer_index)).rgb;
	vec3 z_plane = texture(surface_textures, vec3(uv.xy, layer_index)).rgb;

	if (render_mode_idx > 0.5 && render_mode_idx < 1.5) {
		// Mode 1: Matte / Clay - cliff face shade.
		ALBEDO = vec3(0.55, 0.54, 0.52);
		ROUGHNESS = 0.98;
		SPECULAR = 0.1;
	} else {
		ALBEDO = (x_plane * blend.x + y_plane * blend.y + z_plane * blend.z) * face_shade;
		ROUGHNESS = 0.98;
		SPECULAR = 0.1;
	}
}
