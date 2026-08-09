class_name ClimateProfile
extends RefCounted

## The climate of a world, as data (`world_environment.md` §5).
##
## A season is not four sets of content and not an enum the code branches on: it
## is **one scalar curve over the day of year**. Temperate, polar, tropical and
## airless differ by the offset, the amplitude and the boundaries of that curve,
## never by a new branch of logic. That is why this is a record with numbers in
## it rather than a script per climate — a pack declares its own by writing the
## numbers down.
##
## The season *name* is a caption for UI, scenario conditions and content
## selection, derived from the curve rather than causing it. Nothing renders or
## decides by name where it can read the temperature or the snow chance.

const DEFAULT_ID := &"temperate"

var id: StringName = DEFAULT_ID
var display_name := "Умеренный"

## Length of the year. Deliberately not a constant 365: a world with a short year
## is a game where the season turns within one session, and a hard constant
## closes that game forever.
var days_per_year := 365
## Day of year the annual curve peaks at. Everything else follows from it, so a
## world whose summer sits elsewhere needs no second field.
var warmest_day := 202
## Mean annual temperature at `reference_latitude`, in degrees.
var mean_temperature := 7.0
## Half of the peak-to-peak annual swing at `reference_latitude`.
var seasonal_amplitude := 14.0
## Half of the peak-to-peak daily swing, before cloud cover damps it.
var diurnal_amplitude := 6.5
## The latitude the two temperature numbers above were authored for. Maps further
## from the equator get a colder mean and a wider swing without the author
## restating the profile.
var reference_latitude := 54.0
## Degrees lost per world unit of height (§6, term four).
var lapse_rate := 0.035
## Precipitation falls as snow below this; `snow_transition` is the band the
## rain/snow mix crosses over, so a day near the threshold changes gradually.
var snow_temperature := 1.0
var snow_transition := 2.5
## Vegetation growth peaks at `growth_optimum` and stops `growth_span` away from
## it. Stage 2 consumes this; stage 1 only has to publish it (§19).
var growth_optimum := 19.0
var growth_span := 17.0
## An airless profile has no fog or atmospheric precipitation effects.
var has_atmosphere := true
## Season boundaries as `[{"id": StringName, "start_day": int}, ...]`. The profile
## declares them because a tropical climate has two and not four.
var seasons: Array[Dictionary] = [
	{"id": &"winter", "start_day": 335},
	{"id": &"spring", "start_day": 60},
	{"id": &"summer", "start_day": 152},
	{"id": &"autumn", "start_day": 244},
]
## Weather patterns this climate may roll, most-likely first. Empty means "every
## registered pattern", which is what a pack gets before it narrows the list.
var weather_patterns: Array[StringName] = []


static func from_dict(source: Dictionary) -> ClimateProfile:
	var profile := ClimateProfile.new()
	profile.id = StringName(source.get("id", profile.id))
	profile.display_name = String(source.get("display_name", profile.display_name))
	profile.days_per_year = maxi(1, int(source.get("days_per_year", profile.days_per_year)))
	profile.warmest_day = int(source.get("warmest_day", profile.warmest_day))
	profile.mean_temperature = float(source.get("mean_temperature", profile.mean_temperature))
	profile.seasonal_amplitude = float(source.get("seasonal_amplitude", profile.seasonal_amplitude))
	profile.diurnal_amplitude = float(source.get("diurnal_amplitude", profile.diurnal_amplitude))
	profile.reference_latitude = float(source.get("reference_latitude", profile.reference_latitude))
	profile.lapse_rate = float(source.get("lapse_rate", profile.lapse_rate))
	profile.snow_temperature = float(source.get("snow_temperature", profile.snow_temperature))
	profile.snow_transition = maxf(0.01, float(source.get("snow_transition", profile.snow_transition)))
	profile.growth_optimum = float(source.get("growth_optimum", profile.growth_optimum))
	profile.growth_span = maxf(0.01, float(source.get("growth_span", profile.growth_span)))
	profile.has_atmosphere = bool(source.get("has_atmosphere", profile.has_atmosphere))
	var raw_seasons: Variant = source.get("seasons", null)
	if raw_seasons is Array and not (raw_seasons as Array).is_empty():
		var parsed: Array[Dictionary] = []
		for entry: Variant in raw_seasons as Array:
			if not (entry is Dictionary):
				continue
			var season := entry as Dictionary
			parsed.append({
				"id": StringName(season.get("id", "")),
				"start_day": int(season.get("start_day", 1)),
			})
		if not parsed.is_empty():
			profile.seasons = parsed
	var raw_patterns: Variant = source.get("weather_patterns", null)
	if raw_patterns is Array:
		var patterns: Array[StringName] = []
		for entry: Variant in raw_patterns as Array:
			patterns.append(StringName(entry))
		profile.weather_patterns = patterns
	return profile


func to_dict() -> Dictionary:
	return {
		"id": String(id),
		"display_name": display_name,
		"days_per_year": days_per_year,
		"warmest_day": warmest_day,
		"mean_temperature": mean_temperature,
		"seasonal_amplitude": seasonal_amplitude,
		"diurnal_amplitude": diurnal_amplitude,
		"reference_latitude": reference_latitude,
		"lapse_rate": lapse_rate,
		"snow_temperature": snow_temperature,
		"snow_transition": snow_transition,
		"growth_optimum": growth_optimum,
		"growth_span": growth_span,
		"has_atmosphere": has_atmosphere,
		"seasons": seasons.duplicate(true),
		"weather_patterns": weather_patterns.map(func(entry: StringName) -> String: return String(entry)),
	}


## Wraps any day into `1..days_per_year`, so callers may hand over a raw sum.
func wrap_day(day_of_year: int) -> int:
	return posmod(day_of_year - 1, days_per_year) + 1


## Fraction of the year elapsed, `0.0` on day one.
func year_phase(day_of_year: int) -> float:
	return float(wrap_day(day_of_year) - 1) / float(days_per_year)


## The annual temperature curve — the one thing the season actually *is* (§5).
##
## Southern latitudes get the same curve half a year out of phase, which is why
## the hemisphere needs no flag anywhere else in the system.
func seasonal_temperature(day_of_year: int, latitude: float) -> float:
	var effective_day := wrap_day(day_of_year)
	if latitude < 0.0:
		effective_day = wrap_day(effective_day + days_per_year / 2)
	var phase := float(effective_day - warmest_day) / float(days_per_year) * TAU
	var distance := absf(latitude) - absf(reference_latitude)
	# Further from the equator: colder on average and a wider swing. Both follow
	# from one number so a map only has to state where it is.
	var mean := mean_temperature - distance * 0.32
	var amplitude := seasonal_amplitude * clampf(1.0 + distance * 0.012, 0.15, 2.2)
	return mean + cos(phase) * amplitude


## Where in its own season the day sits, `0.0` at the boundary that opened it and
## approaching `1.0` at the next. Content and UI use it for "deep winter" versus
## "the very start of spring"; nothing mechanical branches on it.
func season_phase(day_of_year: int) -> float:
	var ordered := _ordered_seasons()
	if ordered.size() < 2:
		return year_phase(day_of_year)
	var day := wrap_day(day_of_year)
	var index := _season_index(day, ordered)
	var start := int(ordered[index]["start_day"])
	var next_start := int(ordered[(index + 1) % ordered.size()]["start_day"])
	var length := posmod(next_start - start, days_per_year)
	if length <= 0:
		length = days_per_year
	var elapsed := posmod(day - start, days_per_year)
	return clampf(float(elapsed) / float(length), 0.0, 1.0)


func season_at(day_of_year: int) -> StringName:
	var ordered := _ordered_seasons()
	if ordered.is_empty():
		return &""
	return StringName(ordered[_season_index(wrap_day(day_of_year), ordered)]["id"])


## Probability that precipitation falls as snow rather than rain, from the
## temperature alone. The old `is_cold` flag could not express the band where a
## shower turns over during the day (§10).
func snow_chance(temperature: float) -> float:
	return clampf(
		(snow_temperature + snow_transition - temperature) / (snow_transition * 2.0),
		0.0,
		1.0
	)


## Vegetation growth, `0..1`. Published in stage 1, consumed in stage 2 (§19).
func growth_rate(temperature: float) -> float:
	var distance := absf(temperature - growth_optimum)
	return clampf(1.0 - distance / growth_span, 0.0, 1.0)


func _ordered_seasons() -> Array[Dictionary]:
	var ordered := seasons.duplicate(true)
	ordered.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return int(a["start_day"]) < int(b["start_day"]))
	var result: Array[Dictionary] = []
	for entry: Variant in ordered:
		result.append(entry as Dictionary)
	return result


## Index of the season a day falls in: the last boundary at or before it, wrapping
## into the previous year's final season for days before the earliest boundary.
func _season_index(day: int, ordered: Array[Dictionary]) -> int:
	var index := ordered.size() - 1
	for i in range(ordered.size()):
		if day >= int(ordered[i]["start_day"]):
			index = i
		else:
			break
	if day < int(ordered[0]["start_day"]):
		index = ordered.size() - 1
	return index
