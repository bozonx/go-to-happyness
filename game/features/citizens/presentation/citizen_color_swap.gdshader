shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back, diffuse_burley, specular_schlick_ggx;

uniform sampler2D albedo_texture : source_color, filter_nearest;

instance uniform vec4 skin_color : source_color = vec4(0.94, 0.75, 0.60, 1.0);
instance uniform vec4 shirt_color : source_color = vec4(0.52, 0.55, 0.63, 1.0);
instance uniform vec4 pants_color : source_color = vec4(0.31, 0.32, 0.37, 1.0);
instance uniform vec4 hair_color : source_color = vec4(0.21, 0.22, 0.23, 1.0);

// Per-unit toggles (1 = recolour that channel, 0 = keep the baked texture colour).
// Professions keep their uniform (clothing off); the hero keeps everything but skin.
instance uniform float swap_skin = 1.0;
instance uniform float swap_shirt = 1.0;
instance uniform float swap_pants = 1.0;
instance uniform float swap_hair = 1.0;

void fragment() {
	vec4 tex_color = texture(albedo_texture, UV);
	
	// Determine column index (0 to 15)
	int col = int(UV.x * 16.0);
	
	vec3 target_color;
	bool replace = false;
	
	if (col >= 10 && col <= 15) {
		target_color = skin_color.rgb;
		replace = swap_skin > 0.5;
	} else if (col == 2 || col == 3 || col == 6 || col == 7) {
		target_color = shirt_color.rgb;
		replace = swap_shirt > 0.5;
	} else if (col == 4 || col == 5) {
		target_color = pants_color.rgb;
		replace = swap_pants > 0.5;
	} else if (col == 0 || col == 1) {
		target_color = hair_color.rgb;
		replace = swap_hair > 0.5;
	}
	
	if (replace) {
		float shade = max(max(tex_color.r, tex_color.g), tex_color.b);
		tex_color.rgb = target_color * shade;
	}
	
	ALBEDO = tex_color.rgb;
}
