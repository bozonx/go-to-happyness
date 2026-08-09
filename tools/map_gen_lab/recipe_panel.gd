extends PanelContainer

## The recipe as live controls (procedural_map_generation.md §7.1).
##
## Every parameter of §3 is here, grouped the way the document groups them, and
## touching any of them regenerates the whole map — there is no incremental
## generation and there is not meant to be. The panel is authored as a `.tscn`
## (AGENTS.md "Static editor UI is authored as .tscn"); this script only binds it
## to `MapRecipe` in both directions.
##
## It reads and writes a `MapRecipe` rather than a dictionary on purpose: the
## validation and the shape presets of §3.3 are the recipe's own, so a panel that
## built raw JSON would be a second place where "an archipelago is not 80 % land"
## has to be known.

signal recipe_changed
signal generate_requested
signal seed_changed(value: int)
signal preset_selected(path: String)
signal save_requested

const SHAPES: Array[StringName] = [
	MapRecipe.SHAPE_CONTINENT, MapRecipe.SHAPE_COAST, MapRecipe.SHAPE_BIG_ISLAND,
	MapRecipe.SHAPE_ARCHIPELAGO, MapRecipe.SHAPE_INLAND,
]
const BORDER_KINDS: Array[StringName] = MapRecipe.BORDER_KINDS
const HYPSOMETRY: Array[StringName] = MapRecipe.HYPSOMETRY_IDS
const RIVER_SOURCES: Array[StringName] = [
	MapRecipe.RIVER_SOURCE_MOUNTAINS, MapRecipe.RIVER_SOURCE_LAKES, MapRecipe.RIVER_SOURCE_SPRINGS,
]
const LAKE_PREFER: Array[StringName] = [
	MapRecipe.LAKE_PREFER_BASINS, MapRecipe.LAKE_PREFER_MOUNTAINS, MapRecipe.LAKE_PREFER_COAST,
]
const LATITUDES: Array[StringName] = MapRecipe.LATITUDE_IDS

## Materials worth comparing an angle of repose against (§2.3). Stone is the one
## content recipes use; the others exist so the same map can be seen slumping.
const REPOSE_MATERIALS: Array[StringName] = [
	TerrainMaterialCatalog.STONE, TerrainMaterialCatalog.GRAVEL,
	TerrainMaterialCatalog.DIRT, TerrainMaterialCatalog.SAND,
]

var _preset_paths: Array[String] = []
## True while the panel is being filled from a recipe, so writing the controls
## does not look like the author turning forty knobs one after another.
var _loading := false


func _ready() -> void:
	_fill_options(%Shape, SHAPES)
	_fill_options(%HypsometryPicker, HYPSOMETRY)
	_fill_options(%ReposeOverride, REPOSE_MATERIALS)
	_fill_options(%RiverSource, RIVER_SOURCES)
	_fill_options(%LakePrefer, LAKE_PREFER)
	_fill_options(%Latitude, LATITUDES)
	for side: String in ["BorderNorth", "BorderEast", "BorderSouth", "BorderWest"]:
		_fill_options(get_node("%%%s" % side), BORDER_KINDS)
	for control: Node in _value_controls():
		# The latitude picker has its own handler below: it has to move the numbers
		# it stands for BEFORE anything regenerates, and the blanket connection here
		# would fire first with the old ones.
		if control == %Latitude:
			continue
		if control is SpinBox:
			(control as SpinBox).value_changed.connect(func(_value: float) -> void: _emit_changed())
		elif control is OptionButton:
			(control as OptionButton).item_selected.connect(func(_index: int) -> void: _emit_changed())
		elif control is CheckBox:
			(control as CheckBox).toggled.connect(func(_pressed: bool) -> void: _emit_changed())
	# Picking a band moves the two numbers it stands for. Without this, changing
	# "temperate" to "tropical" leaves 12 °C in the box and the recipe refuses
	# itself — correct (§3.3) and useless as an interaction.
	%Latitude.item_selected.connect(_on_latitude_selected)
	%SeedField.text_submitted.connect(func(text: String) -> void: seed_changed.emit(int(text)))
	%SeedRandom.pressed.connect(func() -> void: seed_changed.emit(randi() % 1000000))
	%SeedNext.pressed.connect(func() -> void: seed_changed.emit(int(%SeedField.text) + 1))
	%SeedPrevious.pressed.connect(func() -> void: seed_changed.emit(int(%SeedField.text) - 1))
	%SeedCopy.pressed.connect(func() -> void: DisplayServer.clipboard_set(%SeedField.text))
	%GenerateButton.pressed.connect(func() -> void: generate_requested.emit())
	%SaveButton.pressed.connect(func() -> void: save_requested.emit())
	%PresetPicker.item_selected.connect(_on_preset_selected)


func set_presets(paths: Array[String]) -> void:
	_preset_paths = paths
	%PresetPicker.clear()
	for path: String in paths:
		%PresetPicker.add_item(path.get_file().replace(".gdmapgen.json", ""))


## Points the picker at a preset without asking for it to be loaded again. The
## batch run needs it: a photograph whose panel names a different preset than the
## map in it is worse than no caption at all.
func show_preset(path: String) -> void:
	var index := _preset_paths.find(path)
	if index >= 0:
		%PresetPicker.selected = index


func show_seed(value: int) -> void:
	%SeedField.text = str(value)


## Fills the controls from a recipe. Used when a preset is loaded and when the
## recipe corrected something the author typed.
func load_recipe(recipe: MapRecipe) -> void:
	_loading = true
	%BoardSize.value = recipe.board_size
	%OceanLevel.value = recipe.ocean_level
	%BorderNorth.selected = maxi(BORDER_KINDS.find(recipe.border_kind(&"north")), 0)
	%BorderEast.selected = maxi(BORDER_KINDS.find(recipe.border_kind(&"east")), 0)
	%BorderSouth.selected = maxi(BORDER_KINDS.find(recipe.border_kind(&"south")), 0)
	%BorderWest.selected = maxi(BORDER_KINDS.find(recipe.border_kind(&"west")), 0)
	%BorderHeight.value = recipe.border_height(&"east")
	%BorderThickness.value = recipe.border_thickness(&"east")

	%Shape.selected = maxi(SHAPES.find(recipe.shape), 0)
	%LandFraction.value = recipe.land_fraction
	%CoastRuggedness.value = recipe.coast_ruggedness
	%IslandCount.value = recipe.island_count
	%ShelfWidth.value = recipe.shelf_width

	%MeanHeight.value = recipe.land_mean_height
	%MaxHeight.value = recipe.land_max_height
	%HypsometryPicker.selected = maxi(HYPSOMETRY.find(recipe.hypsometry), 0)
	%Roughness.value = recipe.roughness
	%TerraceBias.value = recipe.terrace_bias
	%ReposeOverride.selected = maxi(REPOSE_MATERIALS.find(recipe.repose_override), 0)

	var spec: Dictionary = recipe.mountain_ranges[0] if not recipe.mountain_ranges.is_empty() else {}
	%RangeCount.value = int(spec.get("count", 0))
	%RangeLength.value = float(spec.get("length", 0.7))
	%Orientation.value = float(spec.get("orientation", 0.0))
	%OrientationJitter.value = float(spec.get("orientation_jitter", 15.0))
	%PeaksPerRange.value = int(spec.get("peaks_per_range", 4))
	var peak_height: Array = spec.get("peak_height", [30, 48])
	%PeakMin.value = int(peak_height[0])
	%PeakMax.value = int(peak_height[1])
	%FlankSteepness.value = float(spec.get("flank_steepness", 0.8))
	%Foothills.value = int(spec.get("foothills", 8))
	%Passes.value = int(spec.get("passes", 2))
	%SolitaryCount.value = int(recipe.solitary_peaks.get("count", 0))

	%RiverCount.value = recipe.river_count
	%RiverWidthMin.value = recipe.river_width[0]
	%RiverWidthMax.value = recipe.river_width[1]
	%RiverMeander.value = recipe.river_meander
	%RiverIncision.value = recipe.river_incision
	%RiverSource.selected = maxi(RIVER_SOURCES.find(recipe.river_source), 0)
	%RiverTributaries.value = recipe.river_tributaries
	%RiverDelta.button_pressed = recipe.river_delta

	%LakeCountMin.value = recipe.lake_count[0]
	%LakeCountMax.value = recipe.lake_count[1]
	%LakeSizeMin.value = recipe.lake_size[0]
	%LakeSizeMax.value = recipe.lake_size[1]
	%LakeDepthMin.value = recipe.lake_depth[0]
	%LakeDepthMax.value = recipe.lake_depth[1]
	%LakePrefer.selected = maxi(LAKE_PREFER.find(recipe.lake_prefer), 0)
	%LakeConnect.button_pressed = recipe.lakes_connect_to_rivers

	%FlatFractionMin.value = recipe.flat_fraction_min
	%LandComponentMin.value = recipe.largest_land_component_min
	%CliffFractionMax.value = recipe.cliff_fraction_max

	%Latitude.selected = maxi(LATITUDES.find(recipe.latitude), 0)
	%MeanTemperature.value = recipe.land_mean_temperature
	%TemperatureSpan.value = recipe.temperature_span
	%LapseRate.value = recipe.lapse_rate
	%MeanMoisture.value = recipe.land_mean_moisture
	%WindDirection.value = recipe.wind_direction
	%RainShadow.value = recipe.rain_shadow
	%CoastalReach.value = recipe.coastal_reach
	%DesertLakeMax.value = recipe.desert_lake_fraction_max
	_loading = false


## The recipe the controls currently describe. It goes through
## `MapRecipe.from_dictionary`, so the panel gets the same validation and the same
## refusals as a recipe read from a file.
func build_recipe(id: String, seed_value: int) -> MapRecipe:
	var ranges: Array = []
	if int(%RangeCount.value) > 0:
		ranges.append({
			"count": int(%RangeCount.value),
			"length": float(%RangeLength.value),
			"orientation": float(%Orientation.value),
			"orientation_jitter": float(%OrientationJitter.value),
			"peak_height": [int(%PeakMin.value), int(%PeakMax.value)],
			"peaks_per_range": int(%PeaksPerRange.value),
			"flank_steepness": float(%FlankSteepness.value),
			"foothills": int(%Foothills.value),
			"passes": int(%Passes.value),
		})
	return MapRecipe.from_dictionary({
		"format_version": MapRecipe.FORMAT_VERSION,
		"kind": String(MapRecipe.KIND),
		"id": id,
		"seed": seed_value,
		"board": {"size": int(%BoardSize.value)},
		"border": {
			"north": _border_entry(%BorderNorth),
			"east": _border_entry(%BorderEast),
			"south": _border_entry(%BorderSouth),
			"west": _border_entry(%BorderWest),
			"ocean_level": int(%OceanLevel.value),
		},
		"landmass": {
			"shape": String(SHAPES[%Shape.selected]),
			"land_fraction": float(%LandFraction.value),
			"coast_ruggedness": float(%CoastRuggedness.value),
			"island_count": int(%IslandCount.value),
			"shelf_width": int(%ShelfWidth.value),
		},
		"elevation": {
			"land_mean_height": int(%MeanHeight.value),
			"land_max_height": int(%MaxHeight.value),
			"hypsometry": String(HYPSOMETRY[%HypsometryPicker.selected]),
			"roughness": float(%Roughness.value),
			"terrace_bias": float(%TerraceBias.value),
			"repose_override": String(REPOSE_MATERIALS[%ReposeOverride.selected]),
		},
		"climate": {
			"latitude": String(LATITUDES[%Latitude.selected]),
			"land_mean_temperature": float(%MeanTemperature.value),
			"temperature_span": float(%TemperatureSpan.value),
			"lapse_rate": float(%LapseRate.value),
			"land_mean_moisture": float(%MeanMoisture.value),
			"wind_direction": float(%WindDirection.value),
			"rain_shadow": float(%RainShadow.value),
			"coastal_reach": float(%CoastalReach.value),
		},
		"mountains": {
			"ranges": ranges,
			"solitary_peaks": {
				"count": int(%SolitaryCount.value),
				"height": [maxi(int(%PeakMin.value) / 2, 1), maxi(int(%PeakMax.value) / 2, 2)],
				"flank_steepness": float(%FlankSteepness.value),
			},
		},
		"rivers": {
			"count": int(%RiverCount.value),
			"width": [int(%RiverWidthMin.value), int(%RiverWidthMax.value)],
			"meander": float(%RiverMeander.value),
			"incision": int(%RiverIncision.value),
			"source": String(RIVER_SOURCES[%RiverSource.selected]),
			"delta": %RiverDelta.button_pressed,
			"tributaries": int(%RiverTributaries.value),
		},
		"lakes": {
			"count": [int(%LakeCountMin.value), int(%LakeCountMax.value)],
			"size": [int(%LakeSizeMin.value), int(%LakeSizeMax.value)],
			"depth": [int(%LakeDepthMin.value), int(%LakeDepthMax.value)],
			"prefer": String(LAKE_PREFER[%LakePrefer.selected]),
			"connect_to_rivers": %LakeConnect.button_pressed,
		},
		"targets": {
			"flat_fraction_min": float(%FlatFractionMin.value),
			"largest_land_component_min": float(%LandComponentMin.value),
			"cliff_fraction_max": float(%CliffFractionMax.value),
			"desert_lake_fraction_max": float(%DesertLakeMax.value),
		},
	})


func _border_entry(picker: OptionButton) -> Dictionary:
	return {
		"kind": String(BORDER_KINDS[picker.selected]),
		"height": int(%BorderHeight.value),
		"thickness": int(%BorderThickness.value),
	}


func _fill_options(picker: OptionButton, values: Array[StringName]) -> void:
	picker.clear()
	for value: StringName in values:
		picker.add_item(String(value))


func _value_controls() -> Array[Node]:
	var controls: Array[Node] = []
	_collect_controls(%Shape.get_parent().get_parent(), controls)
	return controls


func _collect_controls(root: Node, into: Array[Node]) -> void:
	for child: Node in root.get_children():
		if child is SpinBox or child is OptionButton or child is CheckBox:
			into.append(child)
		else:
			_collect_controls(child, into)


func _emit_changed() -> void:
	if _loading:
		return
	recipe_changed.emit()


func _on_latitude_selected(index: int) -> void:
	var band: Dictionary = MapRecipe.LATITUDE_PRESETS[LATITUDES[clampi(index, 0, LATITUDES.size() - 1)]]
	_loading = true
	%MeanTemperature.value = float(band["temperature"])
	%TemperatureSpan.value = float(band["span"])
	_loading = false
	_emit_changed()


func _on_preset_selected(index: int) -> void:
	if index >= 0 and index < _preset_paths.size():
		preset_selected.emit(_preset_paths[index])
