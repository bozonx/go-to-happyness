shader_type spatial;
render_mode cull_disabled, depth_prepass_alpha, diffuse_lambert, specular_disabled, world_vertex_coords;

// Crossed cards provide the silhouette; this shader only animates their existing
// vertices. Godot spatial shaders do not manufacture geometry, so thousands of
// clumps stay one chunk-local MultiMesh draw instead.

uniform sampler2D grass_texture : source_color, filter_linear_mipmap, repeat_disable;
uniform float atlas_columns = 1.0;
uniform vec2 wind_direction = vec2(0.86, 0.5);
uniform float wind_strength : hint_range(0.0, 1.0) = 0.32;
uniform float sway_metres : hint_range(0.0, 0.35) = 0.14;
uniform vec3 grass_tint : source_color = vec3(0.82, 0.9, 0.72);

varying float atlas_column;

void vertex() {
	atlas_column = floor(INSTANCE_CUSTOM.r * max(atlas_columns - 1.0, 0.0) + 0.5);
	float height_weight = (1.0 - UV.y) * (1.0 - UV.y);
	vec2 axis = normalize(wind_direction + vec2(0.0001, 0.0));
	float phase = dot(VERTEX.xz, vec2(0.71, 1.13)) + TIME * (1.6 + wind_strength);
	float gust = sin(phase) * 0.65 + sin(phase * 2.17 + 1.4) * 0.35;
	VERTEX.xz += axis * gust * sway_metres * wind_strength * height_weight;
	// Upward-facing foliage normals keep both sides of a crossed card lit alike.
	NORMAL = vec3(0.0, 1.0, 0.0);
}

void fragment() {
	vec2 atlas_uv = vec2((UV.x + atlas_column) / atlas_columns, UV.y);
	vec4 texel = texture(grass_texture, atlas_uv);
	ALBEDO = texel.rgb * grass_tint;
	ROUGHNESS = 0.92;
	ALPHA = texel.a;
	ALPHA_SCISSOR_THRESHOLD = 0.5;
}
