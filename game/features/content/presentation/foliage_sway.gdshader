shader_type spatial;
render_mode cull_disabled;

// Растительность, которую шевелит ветер мира.
//
// Ветер — глобальный параметр мира (`world_environment.md` §9), и единственный
// его владелец — `WorldWind`. Шейдер читает глобальные uniform'ы, а не свои
// копии: иначе у флага, травы террейна и куста было бы три разных ветра, и
// разошлись бы они не сразу, а в тот момент, когда кто-то один поправит формулу.
global uniform vec2 world_wind_direction;
global uniform float world_wind_strength;

uniform vec4 albedo_color : source_color = vec4(0.3, 0.5, 0.25, 1.0);
uniform float roughness_value : hint_range(0.0, 1.0) = 1.0;

// Насколько сильно гнётся именно этот материал. У листвы — единица, у ствола
// материал просто другой: качать ствол вместе с кроной означало бы дерево из
// резины.
uniform float sway_amount : hint_range(0.0, 2.0) = 1.0;
// Модельная координата корня и высота, на которой изгиб достигает максимума.
// Благодаря им травинка гнётся от земли, а не съезжает целиком.
uniform float sway_pivot_y = -0.5;
uniform float sway_full_height = 1.0;
uniform float sway_speed = 1.6;

void vertex() {
	// Фаза от мировой позиции объекта: соседние кусты не должны качаться
	// синхронно, иначе поляна выглядит как одна анимированная декорация.
	vec3 model_origin = MODEL_MATRIX[3].xyz;
	float phase = model_origin.x * 0.7 + model_origin.z * 0.9;

	float bend = clamp((VERTEX.y - sway_pivot_y) / max(sway_full_height, 0.001), 0.0, 1.0);
	bend *= bend;

	// Две несоразмерные синусоиды вместо одной: ровное качание читается как
	// механизм, а не как ветер.
	float gust = sin(TIME * sway_speed + phase) * 0.75
		+ sin(TIME * sway_speed * 0.37 + phase * 1.7) * 0.25;

	float amplitude = sway_amount * world_wind_strength * bend * 0.35;
	VERTEX.xz += world_wind_direction * gust * amplitude;
}

void fragment() {
	// Цвет экземпляра. У одиночного объекта COLOR равен белому, и множитель
	// ничего не меняет; у массового слоя материал один на тысячу деревьев, и
	// разноцветными их делает `MultiMesh.set_instance_color` — иначе вариация
	// стоила бы материала на дерево (`ScatterMeshBaker`).
	ALBEDO = albedo_color.rgb * COLOR.rgb;
	ROUGHNESS = roughness_value;
}
