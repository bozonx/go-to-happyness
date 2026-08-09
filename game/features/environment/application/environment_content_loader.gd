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
	for pack: ContentPack in source.content_packs():
		_register_folder(pack.root_path.path_join("weather"), WEATHER_SUFFIX, false, pack.source, errors)
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
			var profile := ClimateProfile.from_dict(parsed as Dictionary)
			if profile.id.is_empty():
				errors.append("Климат без id: %s" % path)
			else:
				profile.id = ContentId.runtime_key(source, profile.id)
				for index in range(profile.weather_patterns.size()):
					var pattern_id := profile.weather_patterns[index]
					if not WeatherPatternCatalog.has_pattern(pattern_id):
						profile.weather_patterns[index] = ContentId.runtime_key(source, pattern_id)
				ClimateCatalog.register(profile)
		else:
			var pattern := WeatherPattern.from_dict(parsed as Dictionary)
			if pattern.id.is_empty():
				errors.append("Погодный паттерн без id: %s" % path)
			else:
				pattern.id = ContentId.runtime_key(source, pattern.id)
				WeatherPatternCatalog.register(pattern)


static func _files_recursively(root: String, suffix: String) -> Array[String]:
	var result: Array[String] = []
	for file: String in DirAccess.get_files_at(root):
		if file.ends_with(suffix):
			result.append(root.path_join(file))
	for directory: String in DirAccess.get_directories_at(root):
		result.append_array(_files_recursively(root.path_join(directory), suffix))
	return result
