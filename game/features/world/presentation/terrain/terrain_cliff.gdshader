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
uniform float visual_smoothing : hint_range(0.0, 1.0) = 0.0;

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
	vec2 edge_metres = min(UV, vec2(1.0) - UV) * UV2;
	float edge_band = 1.0 - smoothstep(0.0, tile_size * 0.25, min(edge_metres.x, edge_metres.y));
	float full_surface = smoothstep(0.9, 1.0, visual_smoothing);
	float normal_blend = mix(visual_smoothing * edge_band, visual_smoothing, full_surface);
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
