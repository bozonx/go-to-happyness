class_name MapRecipe
extends RefCounted

## A parsed and validated map-generation recipe
## (design_docs/engine/procedural_map_generation.md §3).
##
## The recipe is DATA, not code: a `*.gdmapgen.json` file whose every parameter is
## a named property of the finished map rather than a knob of the algorithm that
## produced it (§3.1). `land_fraction` is "62 % of the board is land", not "put a
## threshold at 0.62 on a noise field" — the solver in `Hypsometry` and
## `LandmassField` is what turns the target into thresholds.
##
## Parsing is deliberately strict. A composition preset (`landmass.shape`) both
## seeds the remaining parameters and CONSTRAINS them, and a request that
## contradicts itself is rejected with a reason instead of being clamped into
## something the author did not ask for (§3.3). Everything expensive downstream
## may therefore assume a coherent recipe.

const FORMAT_VERSION := 1
const KIND := &"map_generator"
const GENERATOR_VERSION := 1

const SHAPE_CONTINENT := &"continent"
const SHAPE_COAST := &"coast"
const SHAPE_BIG_ISLAND := &"big_island"
const SHAPE_ARCHIPELAGO := &"archipelago"
const SHAPE_INLAND := &"inland"

const BORDER_OCEAN := &"ocean"
const BORDER_MOUNTAIN_WALL := &"mountain_wall"
const BORDER_PLATEAU := &"plateau"
const BORDER_OPEN := &"open"

const HYPSOMETRY_PLAINS_WITH_PEAKS := &"plains_with_peaks"
const HYPSOMETRY_ROLLING := &"rolling"
const HYPSOMETRY_PLATEAU := &"plateau"
const HYPSOMETRY_BOWL := &"bowl"
const HYPSOMETRY_ALPINE := &"alpine"

const SIDES: Array[StringName] = [&"north", &"east", &"south", &"west"]

const MIN_BOARD := 32
const MAX_BOARD := 256

## Per composition preset: the default land share and the band it may be moved
## inside. `inland` has no sea at all, `archipelago` stops being an archipelago
## above a third of the board — those are the limits §3.3 refuses to clamp.
const SHAPE_PRESETS: Dictionary = {
	SHAPE_CONTINENT: {"land_fraction": 0.62, "min": 0.35, "max": 0.88, "islands": 6, "allows_ocean_border": true},
	SHAPE_COAST: {"land_fraction": 0.55, "min": 0.30, "max": 0.75, "islands": 3, "allows_ocean_border": true},
	SHAPE_BIG_ISLAND: {"land_fraction": 0.45, "min": 0.18, "max": 0.62, "islands": 2, "allows_ocean_border": true},
	SHAPE_ARCHIPELAGO: {"land_fraction": 0.25, "min": 0.05, "max": 0.35, "islands": 14, "allows_ocean_border": true},
	SHAPE_INLAND: {"land_fraction": 1.0, "min": 0.9, "max": 1.0, "islands": 0, "allows_ocean_border": false},
}

const HYPSOMETRY_IDS: Array[StringName] = [
	HYPSOMETRY_PLAINS_WITH_PEAKS, HYPSOMETRY_ROLLING, HYPSOMETRY_PLATEAU,
	HYPSOMETRY_BOWL, HYPSOMETRY_ALPINE,
]

const BORDER_KINDS: Array[StringName] = [
	BORDER_OCEAN, BORDER_MOUNTAIN_WALL, BORDER_PLATEAU, BORDER_OPEN,
]

const LATITUDE_POLAR := &"polar"
const LATITUDE_BOREAL := &"boreal"
const LATITUDE_TEMPERATE := &"temperate"
const LATITUDE_SUBTROPICAL := &"subtropical"
const LATITUDE_TROPICAL := &"tropical"

## Per latitude band: the mean temperature of the land it stands for, how much
## colder its northern edge is than its southern one, and how far an author may
## move the mean before the band stops being that band. The last column is what
## makes "tropical at −20 °C" a refusal rather than a clamp (§3.3): a name that
## can mean anything is not a parameter.
const LATITUDE_PRESETS: Dictionary = {
	LATITUDE_POLAR: {"temperature": -8.0, "span": 5.0, "tolerance": 8.0},
	LATITUDE_BOREAL: {"temperature": 3.0, "span": 6.0, "tolerance": 8.0},
	LATITUDE_TEMPERATE: {"temperature": 12.0, "span": 6.0, "tolerance": 9.0},
	LATITUDE_SUBTROPICAL: {"temperature": 20.0, "span": 5.0, "tolerance": 8.0},
	LATITUDE_TROPICAL: {"temperature": 26.0, "span": 3.0, "tolerance": 7.0},
}

const LATITUDE_IDS: Array[StringName] = [
	LATITUDE_POLAR, LATITUDE_BOREAL, LATITUDE_TEMPERATE, LATITUDE_SUBTROPICAL, LATITUDE_TROPICAL,
]

const RIVER_SOURCE_MOUNTAINS := &"mountains"
const RIVER_SOURCE_LAKES := &"lakes"
const RIVER_SOURCE_SPRINGS := &"springs"

const LAKE_PREFER_BASINS := &"basins"
const LAKE_PREFER_MOUNTAINS := &"mountains"
const LAKE_PREFER_COAST := &"coast"

var id := "lab_temperate"
var format_version := FORMAT_VERSION
var generator_version := GENERATOR_VERSION
var seed := 0

var board_size := 96

## side -> {"kind": StringName, "height": int, "thickness": int}
var border: Dictionary = {}
var ocean_level := -2

var shape: StringName = SHAPE_CONTINENT
var land_fraction := 0.62
var coast_ruggedness := 0.45
var island_count := 6
var shelf_width := 4

var land_mean_height := 6
var land_max_height := 48
var hypsometry: StringName = HYPSOMETRY_PLAINS_WITH_PEAKS
var roughness := 0.3
var terrace_bias := 0.5
## Debug knob of the laboratory only (§2.3): settles the WHOLE board at the angle
## of repose of one material, so a shape can be compared against itself under soft
## soil and under rock. It says nothing about what the map is made of — that is
## `base_material` and the surface stage below. The two used to be one field, and
## because the commit wrote it into every column, a knob for comparing shapes was
## also the only thing deciding the ground of every generated map.
var repose_override: StringName = TerrainMaterialCatalog.STONE

## Surface layer (§5.2, layer 3). `paint_surface` off leaves the whole board as
## `base_material`, which is what the shape-only laboratory wants.
var paint_surface := true
var base_material: StringName = TerrainMaterialCatalog.GRASS

## Climate (layer 2, §11.1). Every field is a property of the finished map: the
## two means are targets the solver hits on any seed, and the rest describe where
## the weather comes from. `land_mean_temperature` is measured over the land
## inside the frame, at whatever height it happens to be — not "at sea level",
## which is not a number anyone can read off a map.
var latitude: StringName = LATITUDE_TEMPERATE
var land_mean_temperature := 12.0
## °C between the southern edge of the board and the northern one.
var temperature_span := 6.0
## °C lost per height step. The treeline, the bare rock on a summit and the snow
## on top of it are all consequences of this one number.
var lapse_rate := 0.6
var land_mean_moisture := 0.5
## Bearing the prevailing wind blows FROM, in degrees; 0 is a northerly.
var wind_direction := 270.0
## 0…1 — how thoroughly a range dries the ground behind it.
var rain_shadow := 0.6
## Cells over which the sea wets the land behind the coast.
var coastal_reach := 12.0

## Biomes (layer 3, §11.2). Only Earth biomes exist; the field is here so a lunar
## or martian palette can be added without the generator learning what a planet
## is, and so a recipe that asks for one gets a refusal instead of a green Mars.
var biome_origin: StringName = BiomeCatalog.ORIGIN_EARTH

## Each entry: count, length, orientation, orientation_jitter, peak_height (Array
## of two), peaks_per_range, flank_steepness, foothills, passes.
var mountain_ranges: Array[Dictionary] = []
var solitary_peaks: Dictionary = {"count": 0, "height": [18, 30], "flank_steepness": 0.9}

var river_count := 3
var river_width: Array[int] = [1, 4]
var river_meander := 0.5
var river_incision := 2
var river_source: StringName = RIVER_SOURCE_MOUNTAINS
var river_delta := true
var river_tributaries := 2

var lake_count: Array[int] = [2, 5]
var lake_size: Array[int] = [12, 400]
var lake_depth: Array[int] = [1, 6]
var lake_prefer: StringName = LAKE_PREFER_BASINS
var lakes_connect_to_rivers := true

var flat_fraction_min := 0.35
var largest_land_component_min := 0.9
var cliff_fraction_max := 0.12
var land_fraction_tolerance := 0.03
## Share of the desert that may stand under a LAKE (§11.1.3). Rivers and the sea
## are exempt on purpose: a Nile crossing a desert and a lagoon on its coast are
## both real, a chain of ponds in the dunes is not.
var desert_lake_fraction_max := 0.02

var errors: Array[String] = []


func is_valid() -> bool:
	return errors.is_empty()


func has_mountains() -> bool:
	for entry: Dictionary in mountain_ranges:
		if int(entry.get("count", 0)) > 0:
			return true
	return int(solitary_peaks.get("count", 0)) > 0


func has_ocean_border() -> bool:
	for side: StringName in SIDES:
		if border_kind(side) == BORDER_OCEAN:
			return true
	return false


func border_kind(side: StringName) -> StringName:
	var entry: Dictionary = border.get(side, {})
	return entry.get("kind", BORDER_OPEN)


func border_height(side: StringName) -> int:
	var entry: Dictionary = border.get(side, {})
	return int(entry.get("height", 26))


func border_thickness(side: StringName) -> int:
	var entry: Dictionary = border.get(side, {})
	return int(entry.get("thickness", 6))


## The recipe as it will be written back — every field explicit, so the lab can
## round-trip an edited recipe without the defaults quietly changing under it.
func to_dictionary() -> Dictionary:
	var border_out: Dictionary = {}
	for side: StringName in SIDES:
		var entry: Dictionary = {"kind": String(border_kind(side))}
		if border_kind(side) == BORDER_MOUNTAIN_WALL or border_kind(side) == BORDER_PLATEAU:
			entry["height"] = border_height(side)
			entry["thickness"] = border_thickness(side)
		border_out[String(side)] = entry
	border_out["ocean_level"] = ocean_level
	return {
		"format_version": format_version,
		"kind": String(KIND),
		"id": id,
		"generator_version": generator_version,
		"seed": seed,
		"board": {"size": board_size},
		"border": border_out,
		"landmass": {
			"shape": String(shape),
			"land_fraction": land_fraction,
			"coast_ruggedness": coast_ruggedness,
			"island_count": island_count,
			"shelf_width": shelf_width,
		},
		"elevation": {
			"land_mean_height": land_mean_height,
			"land_max_height": land_max_height,
			"hypsometry": String(hypsometry),
			"roughness": roughness,
			"terrace_bias": terrace_bias,
			"repose_override": String(repose_override),
			"paint_surface": paint_surface,
			"base_material": String(base_material),
		},
		"climate": {
			"latitude": String(latitude),
			"land_mean_temperature": land_mean_temperature,
			"temperature_span": temperature_span,
			"lapse_rate": lapse_rate,
			"land_mean_moisture": land_mean_moisture,
			"wind_direction": wind_direction,
			"rain_shadow": rain_shadow,
			"coastal_reach": coastal_reach,
		},
		"biomes": {"origin": String(biome_origin)},
		"mountains": {
			"ranges": mountain_ranges.duplicate(true),
			"solitary_peaks": solitary_peaks.duplicate(true),
		},
		"rivers": {
			"count": river_count,
			"width": river_width.duplicate(),
			"meander": river_meander,
			"incision": river_incision,
			"source": String(river_source),
			"delta": river_delta,
			"tributaries": river_tributaries,
		},
		"lakes": {
			"count": lake_count.duplicate(),
			"size": lake_size.duplicate(),
			"depth": lake_depth.duplicate(),
			"prefer": String(lake_prefer),
			"connect_to_rivers": lakes_connect_to_rivers,
		},
		"targets": {
			"flat_fraction_min": flat_fraction_min,
			"largest_land_component_min": largest_land_component_min,
			"cliff_fraction_max": cliff_fraction_max,
			"land_fraction_tolerance": land_fraction_tolerance,
			"desert_lake_fraction_max": desert_lake_fraction_max,
		},
	}


static func from_json_path(path: String) -> MapRecipe:
	var recipe := MapRecipe.new()
	if not FileAccess.file_exists(path):
		recipe.errors.append("recipe file not found: %s" % path)
		return recipe
	var text := FileAccess.get_file_as_string(path)
	var parsed: Variant = JSON.parse_string(text)
	if typeof(parsed) != TYPE_DICTIONARY:
		recipe.errors.append("recipe is not a JSON object: %s" % path)
		return recipe
	return from_dictionary(parsed as Dictionary)


static func default_recipe() -> MapRecipe:
	return from_dictionary({})


static func from_dictionary(source: Dictionary) -> MapRecipe:
	var recipe := MapRecipe.new()
	recipe._parse(source)
	recipe._validate()
	return recipe


# --- Parsing ------------------------------------------------------------------

func _parse(source: Dictionary) -> void:
	format_version = int(source.get("format_version", FORMAT_VERSION))
	generator_version = int(source.get("generator_version", GENERATOR_VERSION))
	id = String(source.get("id", id))
	seed = int(source.get("seed", 0))
	if source.has("kind") and StringName(source["kind"]) != KIND:
		errors.append("kind must be \"%s\"" % KIND)

	var board: Dictionary = source.get("board", {})
	board_size = int(board.get("size", board_size))

	_parse_border(source.get("border", {}))
	_parse_landmass(source.get("landmass", {}))
	_parse_elevation(source.get("elevation", {}))
	_parse_climate(source.get("climate", {}))
	_parse_biomes(source.get("biomes", {}))
	_parse_mountains(source.get("mountains", {}))
	_parse_rivers(source.get("rivers", {}))
	_parse_lakes(source.get("lakes", {}))
	_parse_targets(source.get("targets", {}))


func _parse_border(source: Dictionary) -> void:
	ocean_level = int(source.get("ocean_level", ocean_level))
	for side: StringName in SIDES:
		var raw: Variant = source.get(String(side), {"kind": String(BORDER_OCEAN)})
		var entry: Dictionary = raw if typeof(raw) == TYPE_DICTIONARY else {}
		var kind := StringName(entry.get("kind", BORDER_OPEN))
		if not BORDER_KINDS.has(kind):
			errors.append("border.%s.kind: unknown value \"%s\"" % [side, kind])
			kind = BORDER_OPEN
		border[side] = {
			"kind": kind,
			"height": maxi(1, int(entry.get("height", 26))),
			"thickness": maxi(1, int(entry.get("thickness", 6))),
		}


func _parse_landmass(source: Dictionary) -> void:
	shape = StringName(source.get("shape", shape))
	if not SHAPE_PRESETS.has(shape):
		errors.append("landmass.shape: unknown preset \"%s\"" % shape)
		shape = SHAPE_CONTINENT
	var preset: Dictionary = SHAPE_PRESETS[shape]
	land_fraction = float(source.get("land_fraction", preset["land_fraction"]))
	coast_ruggedness = clampf(float(source.get("coast_ruggedness", coast_ruggedness)), 0.0, 1.0)
	island_count = maxi(0, int(source.get("island_count", preset["islands"])))
	shelf_width = maxi(0, int(source.get("shelf_width", shelf_width)))


func _parse_elevation(source: Dictionary) -> void:
	land_mean_height = int(source.get("land_mean_height", land_mean_height))
	land_max_height = int(source.get("land_max_height", land_max_height))
	hypsometry = StringName(source.get("hypsometry", hypsometry))
	if not HYPSOMETRY_IDS.has(hypsometry):
		errors.append("elevation.hypsometry: unknown curve \"%s\"" % hypsometry)
		hypsometry = HYPSOMETRY_PLAINS_WITH_PEAKS
	roughness = clampf(float(source.get("roughness", roughness)), 0.0, 1.0)
	terrace_bias = clampf(float(source.get("terrace_bias", terrace_bias)), 0.0, 1.0)
	repose_override = StringName(source.get("repose_override", repose_override))
	if TerrainMaterialCatalog.index_of(repose_override) < 0:
		errors.append("elevation.repose_override: unknown material \"%s\"" % repose_override)
		repose_override = TerrainMaterialCatalog.STONE
	paint_surface = bool(source.get("paint_surface", paint_surface))
	base_material = StringName(source.get("base_material", base_material))
	if TerrainMaterialCatalog.index_of(base_material) < 0:
		errors.append("elevation.base_material: unknown material \"%s\"" % base_material)
		base_material = TerrainMaterialCatalog.GRASS


## The latitude band seeds the two temperature fields the way `landmass.shape`
## seeds the land share: name the climate and get a coherent one, or state the
## numbers and have them checked against the name.
func _parse_climate(source: Dictionary) -> void:
	latitude = StringName(source.get("latitude", latitude))
	if not LATITUDE_PRESETS.has(latitude):
		errors.append("climate.latitude: unknown band \"%s\"" % latitude)
		latitude = LATITUDE_TEMPERATE
	var preset: Dictionary = LATITUDE_PRESETS[latitude]
	land_mean_temperature = float(source.get("land_mean_temperature", preset["temperature"]))
	temperature_span = maxf(0.0, float(source.get("temperature_span", preset["span"])))
	lapse_rate = clampf(float(source.get("lapse_rate", lapse_rate)), 0.0, 4.0)
	land_mean_moisture = clampf(float(source.get("land_mean_moisture", land_mean_moisture)), 0.0, 1.0)
	wind_direction = fposmod(float(source.get("wind_direction", wind_direction)), 360.0)
	rain_shadow = clampf(float(source.get("rain_shadow", rain_shadow)), 0.0, 1.0)
	coastal_reach = maxf(1.0, float(source.get("coastal_reach", coastal_reach)))


func _parse_biomes(source: Dictionary) -> void:
	biome_origin = StringName(source.get("origin", biome_origin))


func _parse_mountains(source: Dictionary) -> void:
	mountain_ranges.clear()
	var raw_ranges: Array = source.get("ranges", [])
	for raw: Variant in raw_ranges:
		if typeof(raw) != TYPE_DICTIONARY:
			continue
		var entry: Dictionary = raw
		mountain_ranges.append({
			"count": maxi(0, int(entry.get("count", 1))),
			"length": clampf(float(entry.get("length", 0.7)), 0.05, 1.5),
			"orientation": float(entry.get("orientation", 0.0)),
			"orientation_jitter": maxf(0.0, float(entry.get("orientation_jitter", 15.0))),
			"peak_height": _int_pair(entry.get("peak_height", [24, 40])),
			"peaks_per_range": maxi(1, int(entry.get("peaks_per_range", 4))),
			"flank_steepness": clampf(float(entry.get("flank_steepness", 0.7)), 0.0, 1.0),
			"foothills": maxi(0, int(entry.get("foothills", 8))),
			"passes": maxi(0, int(entry.get("passes", 2))),
		})
	var peaks: Dictionary = source.get("solitary_peaks", {})
	solitary_peaks = {
		"count": maxi(0, int(peaks.get("count", 0))),
		"height": _int_pair(peaks.get("height", [18, 30])),
		"flank_steepness": clampf(float(peaks.get("flank_steepness", 0.9)), 0.0, 1.0),
	}


func _parse_rivers(source: Dictionary) -> void:
	river_count = maxi(0, int(source.get("count", river_count)))
	river_width = _int_pair(source.get("width", river_width))
	river_meander = clampf(float(source.get("meander", river_meander)), 0.0, 1.0)
	river_incision = maxi(1, int(source.get("incision", river_incision)))
	river_source = StringName(source.get("source", river_source))
	river_delta = bool(source.get("delta", river_delta))
	river_tributaries = maxi(0, int(source.get("tributaries", river_tributaries)))


func _parse_lakes(source: Dictionary) -> void:
	lake_count = _int_pair(source.get("count", lake_count))
	lake_size = _int_pair(source.get("size", lake_size))
	lake_depth = _int_pair(source.get("depth", lake_depth))
	lake_prefer = StringName(source.get("prefer", lake_prefer))
	lakes_connect_to_rivers = bool(source.get("connect_to_rivers", lakes_connect_to_rivers))


func _parse_targets(source: Dictionary) -> void:
	flat_fraction_min = float(source.get("flat_fraction_min", flat_fraction_min))
	largest_land_component_min = float(source.get("largest_land_component_min", largest_land_component_min))
	cliff_fraction_max = float(source.get("cliff_fraction_max", cliff_fraction_max))
	land_fraction_tolerance = float(source.get("land_fraction_tolerance", land_fraction_tolerance))
	desert_lake_fraction_max = float(source.get("desert_lake_fraction_max", desert_lake_fraction_max))


static func _int_pair(raw: Variant) -> Array[int]:
	if typeof(raw) == TYPE_ARRAY and (raw as Array).size() >= 2:
		var values: Array = raw
		var low := int(values[0])
		var high := int(values[1])
		return [mini(low, high), maxi(low, high)] as Array[int]
	if typeof(raw) == TYPE_FLOAT or typeof(raw) == TYPE_INT:
		return [int(raw), int(raw)] as Array[int]
	return [0, 0] as Array[int]


# --- Validation ---------------------------------------------------------------

## Contradictions are refused here, before any expensive stage runs (§9). The
## rule is the one from §3.3: a request the preset cannot satisfy gets a reason,
## never a silent clamp.
func _validate() -> void:
	if format_version != FORMAT_VERSION:
		errors.append("format_version %d is not supported (expected %d)" % [format_version, FORMAT_VERSION])
	if board_size < MIN_BOARD or board_size > MAX_BOARD:
		errors.append("board.size %d is outside %d…%d" % [board_size, MIN_BOARD, MAX_BOARD])
	if board_size % 2 != 0:
		errors.append("board.size must be even so the board stays centred on the origin")

	var preset: Dictionary = SHAPE_PRESETS.get(shape, SHAPE_PRESETS[SHAPE_CONTINENT])
	if land_fraction < float(preset["min"]) - 0.0001 or land_fraction > float(preset["max"]) + 0.0001:
		errors.append("landmass.land_fraction %.2f is outside %.2f…%.2f allowed by shape \"%s\"" % [
			land_fraction, preset["min"], preset["max"], shape,
		])
	if not bool(preset["allows_ocean_border"]) and has_ocean_border():
		errors.append("shape \"%s\" has no sea, so no border side may be \"ocean\"" % shape)

	if land_mean_height <= TerrainGrid.MIN_HEIGHT or land_max_height > TerrainGrid.MAX_HEIGHT:
		errors.append("elevation heights must stay inside %d…%d" % [TerrainGrid.MIN_HEIGHT, TerrainGrid.MAX_HEIGHT])
	if land_max_height <= land_mean_height:
		errors.append("elevation.land_max_height must be above land_mean_height")
	if land_mean_height <= ocean_level:
		errors.append("elevation.land_mean_height must be above border.ocean_level")

	for side: StringName in SIDES:
		if border_kind(side) != BORDER_MOUNTAIN_WALL and border_kind(side) != BORDER_PLATEAU:
			continue
		if border_thickness(side) * 2 >= board_size:
			errors.append("border.%s.thickness %d does not fit on a %d board" % [side, border_thickness(side), board_size])
		if land_mean_height + border_height(side) > TerrainGrid.MAX_HEIGHT:
			errors.append("border.%s crest would exceed the height range" % side)

	var band: Dictionary = LATITUDE_PRESETS.get(latitude, LATITUDE_PRESETS[LATITUDE_TEMPERATE])
	if absf(land_mean_temperature - float(band["temperature"])) > float(band["tolerance"]) + 0.0001:
		errors.append("climate.land_mean_temperature %.1f is more than %.0f °C from the \"%s\" band (%.1f)" % [
			land_mean_temperature, band["tolerance"], latitude, band["temperature"],
		])
	if biome_origin != BiomeCatalog.ORIGIN_EARTH:
		errors.append("biomes.origin \"%s\": only Earth biomes exist" % biome_origin)

	if river_count > 0 and river_incision > land_mean_height - ocean_level:
		errors.append("rivers.incision %d cuts below the sea over the whole land" % river_incision)
	if not [RIVER_SOURCE_MOUNTAINS, RIVER_SOURCE_LAKES, RIVER_SOURCE_SPRINGS].has(river_source):
		errors.append("rivers.source: unknown value \"%s\"" % river_source)
	if not [LAKE_PREFER_BASINS, LAKE_PREFER_MOUNTAINS, LAKE_PREFER_COAST].has(lake_prefer):
		errors.append("lakes.prefer: unknown value \"%s\"" % lake_prefer)
	if river_source == RIVER_SOURCE_MOUNTAINS and river_count > 0 and not has_mountains():
		errors.append("rivers.source is \"mountains\" but the recipe has no mountains")
