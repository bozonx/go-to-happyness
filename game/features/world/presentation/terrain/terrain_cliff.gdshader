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

varying vec3 world_position;
varying vec3 world_normal;
varying vec3 smooth_world_normal;
varying vec3 smooth_view_normal;
varying float layer_index;

void vertex() {
	vec3 smooth_normal = normalize(COLOR.gba * 2.0 - 1.0);
	world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	world_normal = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
	smooth_world_normal = normalize((MODEL_MATRIX * vec4(smooth_normal, 0.0)).xyz);
	smooth_view_normal = normalize(MODELVIEW_NORMAL_MATRIX * smooth_normal);
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
	float eligible_edge_distance = min(min(edge_distances.x + (1.0 - edge_enabled.x) * 10000.0, edge_distances.y + (1.0 - edge_enabled.y) * 10000.0), min(edge_distances.z + (1.0 - edge_enabled.z) * 10000.0, edge_distances.w + (1.0 - edge_enabled.w) * 10000.0));
	float rounding_radius = max(edge_rounding * tile_size * 0.25, 0.0001);
	float edge_band = (1.0 - smoothstep(0.0, rounding_radius, eligible_edge_distance)) * step(0.001, edge_rounding);
	float normal_blend = max(edge_band, full_smoothing);
	NORMAL = normalize(mix(NORMAL, smooth_view_normal, normal_blend));
	vec3 blend = abs(normalize(mix(world_normal, smooth_world_normal, normal_blend)));
	blend = pow(blend, vec3(4.0));
	blend /= max(blend.x + blend.y + blend.z, 0.0001);

	vec3 uv = world_position / tile_size;
	vec3 x_plane = texture(surface_textures, vec3(uv.zy, layer_index)).rgb;
	vec3 y_plane = texture(surface_textures, vec3(uv.xz, layer_index)).rgb;
	vec3 z_plane = texture(surface_textures, vec3(uv.xy, layer_index)).rgb;

	ALBEDO = (x_plane * blend.x + y_plane * blend.y + z_plane * blend.z) * face_shade;
	ROUGHNESS = 0.98;
	SPECULAR = 0.1;
}
