shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back, diffuse_burley, specular_schlick_ggx;

uniform sampler2D albedo_texture : source_color, filter_nearest;

instance uniform vec4 skin_color : source_color = vec4(0.94, 0.75, 0.60, 1.0);
instance uniform vec4 shirt_color : source_color = vec4(0.52, 0.55, 0.63, 1.0);
instance uniform vec4 pants_color : source_color = vec4(0.31, 0.32, 0.37, 1.0);
instance uniform vec4 hair_color : source_color = vec4(0.21, 0.22, 0.23, 1.0);

void fragment() {
	vec4 tex_color = texture(albedo_texture, UV);
	
	// Color matching thresholds (distance in RGB space)
	// 1. Skin tones (Peach #f1976e, Beige #f1c09a, Dark brown #af6142)
	if (distance(tex_color.rgb, vec3(0.945, 0.592, 0.431)) < 0.05 ||
		distance(tex_color.rgb, vec3(0.945, 0.753, 0.604)) < 0.05 ||
		distance(tex_color.rgb, vec3(0.686, 0.380, 0.259)) < 0.05) {
		tex_color.rgb = skin_color.rgb;
	}
	// 2. Shirt colors (Blue/Grey shades #868ba2, #81869f)
	else if (distance(tex_color.rgb, vec3(0.525, 0.545, 0.635)) < 0.05 ||
			 distance(tex_color.rgb, vec3(0.505, 0.525, 0.623)) < 0.05) {
		tex_color.rgb = shirt_color.rgb;
	}
	// 3. Pants/Shoes (Dark grey #505260, #525563)
	else if (distance(tex_color.rgb, vec3(0.313, 0.321, 0.376)) < 0.05 ||
			 distance(tex_color.rgb, vec3(0.321, 0.333, 0.388)) < 0.05) {
		tex_color.rgb = pants_color.rgb;
	}
	// 4. Hair/Accent colors (Grey/Dark slate #37393c, #4a4552)
	else if (distance(tex_color.rgb, vec3(0.215, 0.223, 0.235)) < 0.05 ||
			 distance(tex_color.rgb, vec3(0.290, 0.270, 0.321)) < 0.05) {
		tex_color.rgb = hair_color.rgb;
	}

	ALBEDO = tex_color.rgb;
}
