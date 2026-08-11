class_name EnvironmentContentLoader
extends RefCounted

## Registers pack-authored environment records without making the content index
## depend on the environment feature. Files live under a pack's `climates/` and
## `weather/` folders and use explicit suffixes so unrelated JSON is ignored.

const CLIMATE_SUFFIX := ".gdclimate.json"
const WEATHER_SUFFIX := ".gdweather.json"


static func register_all(index: ContentIndex = null) -> Array[String]:
	var errors: Array[String] = []
	var source := index if index != null else ContentIndex.shared()
	ClimateCatalog.clear_registered()
	WeatherPatternCatalog.clear_registered()
	# Weather first across every pack: a climate may reference a pattern from a
	# dependency whose pack happens to sort after its own.
	for pack: ContentPack in source.content_packs():
		_register_folder(pack.root_path.path_join("weather"), WEATHER_SUFFIX, false, pack.source, errors)
	for pack: ContentPack in source.content_packs():
		_register_folder(pack.root_path.path_join("climates"), CLIMATE_SUFFIX, true, pack.source, errors)
	return errors


static func _register_folder(root: String, suffix: String, climate: bool, source: StringName, errors: Array[String]) -> void:
	if not DirAccess.dir_exists_absolute(root):
		return
	for path: String in _files_recursively(root, suffix):
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
		if not (parsed is Dictionary):
			errors.append("Некорректное описание окружения: %s" % path)
			continue
		if climate:
			var validation := _validate_climate(parsed as Dictionary)
			if not validation.is_empty():
				errors.append("%s: %s" % [path, ", ".join(validation)])
				continue
			var profile := ClimateProfile.from_dict(parsed as Dictionary)
			if profile.id.is_empty():
				errors.append("Климат без id: %s" % path)
			else:
				profile.id = ContentId.runtime_key(source, profile.id)
				for index in range(profile.weather_patterns.size()):
					var pattern_id := profile.weather_patterns[index]
					if not WeatherPatternCatalog.has_pattern(pattern_id):
						profile.weather_patterns[index] = ContentId.runtime_key(source, pattern_id)
					if not WeatherPatternCatalog.has_pattern(profile.weather_patterns[index]):
						errors.append("%s: неизвестный погодный паттерн %s" % [path, pattern_id])
				ClimateCatalog.register(profile)
		else:
			var validation := _validate_weather(parsed as Dictionary)
			if not validation.is_empty():
				errors.append("%s: %s" % [path, ", ".join(validation)])
				continue
			var pattern := WeatherPattern.from_dict(parsed as Dictionary)
			if pattern.id.is_empty():
				errors.append("Погодный паттерн без id: %s" % path)
			else:
				pattern.id = ContentId.runtime_key(source, pattern.id)
				WeatherPatternCatalog.register(pattern)


static func _validate_weather(source: Dictionary) -> Array[String]:
	var errors: Array[String] = []
	if String(source.get("id", "")).strip_edges().is_empty():
		errors.append("пустой id")
	for field: String in [
		"cloud_base", "cloud_variation", "wind_base_strength", "wind_gust_amount",
		"precipitation_chance", "storm_scale",
	]:
		if source.has(field) and (float(source[field]) < 0.0 or float(source[field]) > 1.0):
			errors.append("%s вне диапазона 0..1" % field)
	var earliest := int(source.get("precipitation_earliest", 6 * 60))
	var latest := int(source.get("precipitation_latest_end", 24 * 60))
	var duration := int(source.get("precipitation_min_duration", 180))
	if earliest < 0 or earliest >= 24 * 60:
		errors.append("precipitation_earliest вне суток")
	if latest <= 0 or latest > 24 * 60:
		errors.append("precipitation_latest_end вне суток")
	if duration <= 0 or earliest + duration > latest:
		errors.append("невозможное окно осадков")
	return errors


static func _validate_climate(source: Dictionary) -> Array[String]:
	var errors: Array[String] = []
	if String(source.get("id", "")).strip_edges().is_empty():
		errors.append("пустой id")
	var days := int(source.get("days_per_year", 365))
	if days <= 0:
		errors.append("days_per_year должен быть положительным")
	if float(source.get("snow_transition", 2.5)) <= 0.0:
		errors.append("snow_transition должен быть положительным")
	if float(source.get("growth_span", 17.0)) <= 0.0:
		errors.append("growth_span должен быть положительным")
	var seasons: Variant = source.get("seasons", null)
	if source.has("seasons") and (not (seasons is Array) or (seasons as Array).is_empty()):
		errors.append("seasons должен содержать хотя бы один сезон")
	elif seasons is Array:
		var seen: Dictionary = {}
		for entry: Variant in seasons as Array:
			if not (entry is Dictionary):
				errors.append("сезон должен быть объектом")
				continue
			var season_id := String((entry as Dictionary).get("id", ""))
			var start_day := int((entry as Dictionary).get("start_day", 0))
			if season_id.is_empty() or seen.has(season_id):
				errors.append("пустой или повторный id сезона")
			seen[season_id] = true
			if start_day < 1 or start_day > days:
				errors.append("start_day сезона вне года")
	var patterns: Variant = source.get("weather_patterns", null)
	if source.has("weather_patterns") and not (patterns is Array):
		errors.append("weather_patterns должен быть массивом")
	elif patterns is Array:
		for pattern: Variant in patterns as Array:
			if String(pattern).strip_edges().is_empty():
				errors.append("weather_patterns содержит пустой id")
	return errors


static func _files_recursively(root: String, suffix: String) -> Array[String]:
	var result: Array[String] = []
	for file: String in DirAccess.get_files_at(root):
		if file.ends_with(suffix):
			result.append(root.path_join(file))
	for directory: String in DirAccess.get_directories_at(root):
		result.append_array(_files_recursively(root.path_join(directory), suffix))
	return result
