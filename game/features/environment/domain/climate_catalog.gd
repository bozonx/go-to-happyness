class_name ClimateCatalog
extends RefCounted

## The climate profiles this build ships with, plus whatever a pack registers
## (`world_environment.md` §5).
##
## They are entries in a table rather than scripts, which is the whole point: a
## polar or tropical world is a different set of numbers on one curve, so adding
## one costs a dictionary and no code. Pack-owned profiles arrive through
## `register` with the same shape `from_dict` reads, exactly like the world asset
## catalog waits for its JSON format rather than inventing a second loose-file
## source.

const BUILT_IN: Dictionary = {
	&"temperate": {
		"display_name": "Умеренный",
		"mean_temperature": 7.0,
		"seasonal_amplitude": 14.0,
		"diurnal_amplitude": 6.5,
		"snow_temperature": 1.0,
		"weather_patterns": ["clear", "fair", "cloudy", "overcast", "rain", "storm"],
	},
	&"polar": {
		"display_name": "Полярный",
		"mean_temperature": -11.0,
		"seasonal_amplitude": 19.0,
		"diurnal_amplitude": 3.5,
		"reference_latitude": 72.0,
		"snow_temperature": 2.0,
		"growth_optimum": 11.0,
		"growth_span": 11.0,
		"weather_patterns": ["clear", "cloudy", "overcast", "snowfall", "storm"],
	},
	&"tropical": {
		"display_name": "Тропический",
		# Two seasons, not four: the reason season boundaries belong to the profile
		# and not to a global enum.
		"mean_temperature": 26.0,
		"seasonal_amplitude": 3.0,
		"diurnal_amplitude": 5.0,
		"reference_latitude": 9.0,
		"snow_temperature": -60.0,
		"growth_optimum": 27.0,
		"growth_span": 14.0,
		"seasons": [
			{"id": "dry", "start_day": 305},
			{"id": "wet", "start_day": 121},
		],
		"weather_patterns": ["clear", "fair", "cloudy", "rain", "storm"],
	},
	&"airless": {
		"display_name": "Безвоздушный",
		# No weather at all: one pattern, no precipitation, a brutal diurnal swing
		# and no snow chance. Expressed entirely in the same fields.
		"mean_temperature": -40.0,
		"seasonal_amplitude": 4.0,
		"diurnal_amplitude": 90.0,
		"snow_temperature": -300.0,
		"growth_optimum": 0.0,
		"growth_span": 0.01,
		"weather_patterns": ["vacuum"],
	},
}

static var _registered: Dictionary = {}


static func register(profile: ClimateProfile) -> void:
	if profile == null or profile.id.is_empty():
		return
	_registered[profile.id] = profile


static func clear_registered() -> void:
	_registered.clear()


static func has_profile(profile_id: StringName) -> bool:
	return _registered.has(profile_id) or BUILT_IN.has(profile_id)


static func ids() -> Array[StringName]:
	var result: Array[StringName] = []
	for key: StringName in BUILT_IN:
		result.append(key)
	for key: StringName in _registered:
		if not result.has(key):
			result.append(key)
	return result


## Always answers with a profile. A map naming a climate this build does not have
## gets the default one and a warning, because a world with no climate has no
## time of year either — there is nothing sensible to fall back to but the
## temperate curve.
static func profile(profile_id: StringName) -> ClimateProfile:
	if _registered.has(profile_id):
		return _registered[profile_id]
	if BUILT_IN.has(profile_id):
		var source: Dictionary = (BUILT_IN[profile_id] as Dictionary).duplicate(true)
		source["id"] = String(profile_id)
		var built := ClimateProfile.from_dict(source)
		_registered[profile_id] = built
		return built
	if profile_id != ClimateProfile.DEFAULT_ID and not profile_id.is_empty():
		push_warning("[environment] неизвестный климат %s, взят %s" % [profile_id, ClimateProfile.DEFAULT_ID])
	return profile(ClimateProfile.DEFAULT_ID)
