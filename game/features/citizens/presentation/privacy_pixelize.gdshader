shader_type spatial;
render_mode unshaded, cull_disabled, depth_test_disabled, blend_mix;

uniform sampler2D screen_texture : hint_screen_texture, repeat_disable;
uniform float pixel_size : hint_range(4.0, 256.0) = 24.0;
uniform float edge_softness : hint_range(0.0, 0.5) = 0.1;

void vertex() {
	// Keep the overlay at the citizen's position but always face the camera.
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(
		INV_VIEW_MATRIX[0],
		INV_VIEW_MATRIX[1],
		INV_VIEW_MATRIX[2],
		MODEL_MATRIX[3]
	);
}

void fragment() {
	vec2 tex_size = vec2(textureSize(screen_texture, 0));
	vec2 block = vec2(pixel_size) / tex_size;
	vec2 snapped_uv = floor(SCREEN_UV / block) * block + block * 0.5;
	vec4 pixelated = textureLod(screen_texture, snapped_uv, 0.0);

	float mask_x = smoothstep(0.0, edge_softness, UV.x) * smoothstep(1.0, 1.0 - edge_softness, UV.x);
	float mask_y = smoothstep(0.0, edge_softness, UV.y) * smoothstep(1.0, 1.0 - edge_softness, UV.y);
	float mask = mask_x * mask_y;

	ALBEDO = pixelated.rgb;
	ALPHA = mask;
}
