shader_type canvas_item;

uniform vec2 u_sun_screen_pos;   // sun position in screen UV space [0..1]
uniform float u_intensity;        // overall flare intensity [0..1], driven by sun visibility
uniform float u_time;

// Star burst (anamorphic streak) near the sun position
float star_burst(vec2 uv, vec2 center, float scale) {
	vec2 d = (uv - center) * scale;
	float angle = atan(d.y, d.x);
	float dist = length(d);
	// Two perpendicular sine waves create a cross-shaped streak
	float streak = abs(sin(angle * 2.0)) * 0.5 + abs(cos(angle * 2.0)) * 0.5;
	streak = pow(streak, 8.0);
	float falloff = 1.0 / (dist * dist + 0.005);
	return streak * falloff * 0.04;
}

// Simple circular halo
float halo(vec2 uv, vec2 center, float radius, float thickness) {
	float dist = length(uv - center);
	float ring = smoothstep(radius + thickness, radius, dist) * smoothstep(radius - thickness, radius, dist);
	return ring;
}

// Hexagonal ghost (lens aperture shape)
float hex_ghost(vec2 uv, vec2 center, float size) {
	vec2 d = (uv - center) / size;
	float dist = length(d);
	if (dist > 1.0) return 0.0;
	float angle = atan(d.y, d.x);
	float hex = 0.5 + 0.5 * cos(angle * 6.0);
	hex = pow(hex, 3.0);
	float falloff = (1.0 - dist) * (1.0 - dist);
	return hex * falloff * 0.3;
}

void fragment() {
	vec2 uv = SCREEN_UV;
	vec2 center = u_sun_screen_pos;
	vec2 screen_center = vec2(0.5);
	vec2 dir = screen_center - center;

	float flare = 0.0;
	vec3 color = vec3(0.0);

	// Core glow at sun position
	float core = 1.0 / (length(uv - center) * length(uv - center) + 0.002);
	core = clamp(core * 0.003, 0.0, 1.5);
	color += vec3(1.0, 0.85, 0.6) * core;
	flare += core;

	// Star burst
	float star = star_burst(uv, center, 8.0);
	color += vec3(1.0, 0.9, 0.7) * star;
	flare += star;

	// Series of ghosts along the line from sun to screen center
	for (int i = 1; i <= 6; i++) {
		float t = float(i) / 7.0;
		vec2 ghost_pos = center + dir * t;
		float size = 0.03 + float(i) * 0.015;
		float ghost = hex_ghost(uv, ghost_pos, size);
		// Alternate warm and cool tint per ghost
		vec3 ghost_color = mix(vec3(1.0, 0.7, 0.4), vec3(0.4, 0.6, 1.0), fract(t * 3.0));
		color += ghost_color * ghost * 0.5;
		flare += ghost * 0.3;
	}

	// Halo rings
	float h1 = halo(uv, center + dir * 0.15, 0.08, 0.015);
	float h2 = halo(uv, center + dir * 0.35, 0.05, 0.01);
	color += vec3(1.0, 0.8, 0.5) * h1 * 0.4;
	color += vec3(0.5, 0.7, 1.0) * h2 * 0.3;
	flare += h1 * 0.2 + h2 * 0.15;

	// Anamorphic horizontal streak through sun position
	vec2 streak_d = uv - center;
	float streak_h = 1.0 / (abs(streak_d.y) * 30.0 + 0.01) * 1.0 / (abs(streak_d.x) * 2.0 + 0.5);
	streak_h = clamp(streak_h * 0.02, 0.0, 0.8);
	color += vec3(0.8, 0.9, 1.0) * streak_h;
	flare += streak_h * 0.2;

	// Apply intensity and screen blend
	float alpha = clamp(flare * u_intensity, 0.0, 1.0);
	COLOR = vec4(color * u_intensity, alpha);
}
