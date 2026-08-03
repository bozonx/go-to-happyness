class_name WeatherPatternCatalog
extends RefCounted

## Weather patterns this build ships with, plus whatever a pack registers
## (`world_environment.md` §7).
##
## Note what is *not* here: warming, cooling, harvest weather, a raid storm. Those
## are games' words for a day, and a game maps them onto these names from its own
## side. Everything in this table is describable by looking up at the sky.

const BUILT_IN: Dictionary = {
	&"clear": {
		"display_name": "Ясно",
		"cloud_base": 0.10, "cloud_variation": 0.09,
		"wind_base_strength": 0.26, "wind_gust_amount": 0.16,
		"precipitation_chance": 0.0,
	},
	&"fair": {
		"display_name": "Переменная облачность",
		"cloud_base": 0.26, "cloud_variation": 0.20,
		"wind_base_strength": 0.34, "wind_gust_amount": 0.22,
		"precipitation_chance": 0.0,
	},
	&"cloudy": {
		"display_name": "Облачно",
		"cloud_base": 0.50, "cloud_variation": 0.18,
		"wind_base_strength": 0.45, "wind_gust_amount": 0.24,
		"precipitation_chance": 0.0,
	},
	&"overcast": {
		"display_name": "Пасмурно",
		"cloud_base": 0.72, "cloud_variation": 0.14,
		"wind_base_strength": 0.44, "wind_gust_amount": 0.20,
		# A grey day that may or may not deliver. The band between 0 and 1 is what
		# makes "возможны осадки" expressible without a second pattern.
		"precipitation_chance": 0.35,
		"storm_scale": 0.55,
		"precipitation_min_duration": 120,
	},
	&"rain": {
		"display_name": "Дождь",
		"cloud_base": 0.30, "cloud_variation": 0.18,
		"wind_base_strength": 0.50, "wind_gust_amount": 0.24,
		"precipitation_chance": 1.0,
		"storm_scale": 0.85,
	},
	&"storm": {
		"display_name": "Гроза",
		"cloud_base": 0.42, "cloud_variation": 0.22,
		"wind_base_strength": 0.66, "wind_gust_amount": 0.30,
		"precipitation_chance": 1.0,
		"storm_scale": 1.0,
		"precipitation_min_duration": 120,
	},
	&"snowfall": {
		# Deliberately not "the snow pattern": what falls is decided by temperature
		# (§10). This is the calm, heavy-sky day snow tends to arrive on, and in a
		# warm climate the very same pattern delivers rain.
		"display_name": "Снегопад",
		"cloud_base": 0.62, "cloud_variation": 0.12,
		"wind_base_strength": 0.30, "wind_gust_amount": 0.14,
		"precipitation_chance": 0.85,
		"storm_scale": 0.62,
		"precipitation_min_duration": 240,
	},
	&"vacuum": {
		"display_name": "Без атмосферы",
		"cloud_base": 0.0, "cloud_variation": 0.0,
		"wind_base_strength": 0.0, "wind_gust_amount": 0.0,
		"precipitation_chance": 0.0,
		"storm_scale": 0.0,
	},
}

static var _registered: Dictionary = {}


static func register(pattern: WeatherPattern) -> void:
	if pattern == null or pattern.id.is_empty():
		return
	_registered[pattern.id] = pattern


static func clear_registered() -> void:
	_registered.clear()


static func has_pattern(pattern_id: StringName) -> bool:
	return _registered.has(pattern_id) or BUILT_IN.has(pattern_id)


static func ids() -> Array[StringName]:
	var result: Array[StringName] = []
	for key: StringName in BUILT_IN:
		result.append(key)
	for key: StringName in _registered:
		if not result.has(key):
			result.append(key)
	return result


static func pattern(pattern_id: StringName) -> WeatherPattern:
	if _registered.has(pattern_id):
		return _registered[pattern_id]
	if BUILT_IN.has(pattern_id):
		var source: Dictionary = (BUILT_IN[pattern_id] as Dictionary).duplicate(true)
		source["id"] = String(pattern_id)
		var built := WeatherPattern.from_dict(source)
		_registered[pattern_id] = built
		return built
	if pattern_id != WeatherPattern.DEFAULT_ID and not pattern_id.is_empty():
		push_warning("[environment] неизвестный погодный паттерн %s, взят %s" % [pattern_id, WeatherPattern.DEFAULT_ID])
	return pattern(WeatherPattern.DEFAULT_ID)


## The patterns a climate may roll, resolved to records. A profile that names
## none gets the whole table.
static func patterns_for(profile: ClimateProfile) -> Array[WeatherPattern]:
	var result: Array[WeatherPattern] = []
	var wanted := profile.weather_patterns if profile != null and not profile.weather_patterns.is_empty() else ids()
	for pattern_id: StringName in wanted:
		result.append(pattern(pattern_id))
	return result
