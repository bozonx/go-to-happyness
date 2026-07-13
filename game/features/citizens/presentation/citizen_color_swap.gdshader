shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back, diffuse_burley, specular_schlick_ggx;

uniform sampler2D albedo_texture : source_color, filter_nearest;

instance uniform vec4 skin_color : source_color = vec4(0.94, 0.75, 0.60, 1.0);
instance uniform vec4 shirt_color : source_color = vec4(0.52, 0.55, 0.63, 1.0);
instance uniform vec4 pants_color : source_color = vec4(0.31, 0.32, 0.37, 1.0);
instance uniform vec4 hair_color : source_color = vec4(0.21, 0.22, 0.23, 1.0);

vec3 rgb2hsv(vec3 c) {
	vec4 K = vec4(0.0, -1.0 / 3.0, 2.0 / 3.0, -1.0);
	vec4 p = mix(vec4(c.bg, K.wz), vec4(c.gb, K.xy), step(c.b, c.g));
	vec4 q = mix(mix(vec4(p.xyw, c.r), vec4(c.r, p.yzx), step(p.x, c.r)), p, step(p.x, c.r));

	float d = q.x - min(q.w, q.y);
	float e = 1.0e-10;
	return vec3(abs(q.z + (q.w - q.y) / (6.0 * d + e)), d / (q.x + e), q.x);
}

vec3 hsv2rgb(vec3 c) {
	vec4 K = vec4(1.0, 2.0 / 3.0, 1.0 / 3.0, 3.0);
	vec3 p = abs(fract(c.xxx + K.xyz) * 6.0 - K.www);
	return c.z * mix(K.xxx, clamp(p - K.xxx, 0.0, 1.0), c.y);
}

void fragment() {
	vec4 tex_color = texture(albedo_texture, UV);
	
	// Determine column index (0 to 15)
	int col = int(UV.x * 16.0);
	
	vec3 target_color;
	bool replace = false;
	
	if (col >= 10 && col <= 15) {
		target_color = skin_color.rgb;
		replace = true;
	} else if (col == 2 || col == 3 || col == 6 || col == 7) {
		target_color = shirt_color.rgb;
		replace = true;
	} else if (col == 4 || col == 5) {
		target_color = pants_color.rgb;
		replace = true;
	} else if (col == 0 || col == 1) {
		target_color = hair_color.rgb;
		replace = true;
	}
	
	if (replace) {
		vec3 original_hsv = rgb2hsv(tex_color.rgb);
		vec3 target_hsv = rgb2hsv(target_color);
		// Keep the original Value (brightness) for shading
		vec3 final_hsv = vec3(target_hsv.x, target_hsv.y, original_hsv.z);
		tex_color.rgb = hsv2rgb(final_hsv);
	}
	
	ALBEDO = tex_color.rgb;
}
