shader_type canvas_item;
render_mode blend_add;

uniform vec2 u_sun_screen_pos;   // sun position in screen UV space [0..1]
uniform float u_intensity;        // overall flare intensity [0..1], driven by sun visibility
uniform float u_aspect = 1.0;
uniform vec4 u_sun_color : source_color = vec4(1.0, 0.88, 0.62, 1.0);
uniform float u_time;

vec2 aspect_delta(vec2 uv, vec2 center) {
	vec2 d = uv - center;
	d.x *= u_aspect;
	return d;
}

float soft_disc(vec2 uv, vec2 center, float radius, float feather) {
	float dist = length(aspect_delta(uv, center));
	return 1.0 - smoothstep(radius, radius + feather, dist);
}

float soft_glow(vec2 uv, vec2 center, float radius, float power) {
	float dist = length(aspect_delta(uv, center));
	float glow = radius / max(dist, 0.0001);
	return pow(clamp(glow, 0.0, 1.0), power);
}

float ray_burst(vec2 uv, vec2 center, float scale) {
	vec2 d = aspect_delta(uv, center) * scale;
	float angle = atan(d.y, d.x);
	float dist = length(d);
	float diagonal = pow(abs(cos(angle * 4.0)), 18.0);
	float vertical = pow(abs(cos(angle * 2.0)), 34.0) * 0.35;
	float falloff = exp(-dist * 0.9);
	return (diagonal + vertical) * falloff;
}

float halo(vec2 uv, vec2 center, float radius, float thickness) {
	float dist = length(aspect_delta(uv, center));
	return smoothstep(radius + thickness, radius, dist) * smoothstep(radius - thickness, radius, dist);
}

float round_ghost(vec2 uv, vec2 center, float size, float softness) {
	vec2 d = aspect_delta(uv, center) / size;
	float dist = length(d);
	return pow(clamp(1.0 - dist, 0.0, 1.0), softness);
}

void fragment() {
	vec2 uv = SCREEN_UV;
	vec2 center = u_sun_screen_pos;
	vec2 screen_center = vec2(0.5);
	vec2 dir = screen_center - center;
	vec3 sun_tint = u_sun_color.rgb;

	vec3 color = vec3(0.0);

	float disc = soft_disc(uv, center, 0.012, 0.014);
	float inner_glow = soft_glow(uv, center, 0.065, 1.65);
	float outer_glow = soft_glow(uv, center, 0.18, 3.2);
	float rays = ray_burst(uv, center, 6.5) * 0.10;
	color += sun_tint * disc * 1.5;
	color += sun_tint * inner_glow * 0.50;
	color += mix(sun_tint, vec3(1.0, 0.96, 0.86), 0.35) * outer_glow * 0.22;
	color += vec3(1.0, 0.91, 0.70) * rays;

	// Keep only faint internal reflections. Strong hexagonal ghosts read as a
	// camera artifact instead of sunlight in this painterly settlement view.
	for (int i = 1; i <= 3; i++) {
		float t = float(i) / 4.0;
		vec2 ghost_pos = center + dir * t;
		float size = 0.032 + float(i) * 0.018;
		float ghost = round_ghost(uv, ghost_pos, size, 3.4 + float(i));
		vec3 ghost_color = mix(vec3(1.0, 0.76, 0.45), vec3(0.55, 0.72, 1.0), float(i % 2));
		color += ghost_color * ghost * 0.055;
	}

	float warm_ring = halo(uv, center + dir * 0.22, 0.105, 0.018);
	float cool_ring = halo(uv, center + dir * 0.46, 0.055, 0.012);
	color += vec3(1.0, 0.75, 0.42) * warm_ring * 0.075;
	color += vec3(0.55, 0.74, 1.0) * cool_ring * 0.045;

	vec2 streak_d = aspect_delta(uv, center);
	float horizontal = exp(-abs(streak_d.y) * 55.0) * exp(-abs(streak_d.x) * 1.45);
	color += mix(sun_tint, vec3(0.72, 0.84, 1.0), 0.25) * horizontal * 0.055;

	float alpha = clamp(max(max(color.r, color.g), color.b) * u_intensity, 0.0, 0.85);
	COLOR = vec4(color * u_intensity, alpha);
}
